export generate_coeffs

const default_header_file_path = "data/header_data.json"
const default_time_file_path = "data/time.csv"

"""
*get_header_data*

Extrae información de un fichero JSON sobre el cuerpo deseado.

# Argumentos de entrada:
 - `body::Union{Int, String}`: ID o nombre del cuerpo del que se desea.
 - `file_path::String`: Ruta del fichero que contiene la información del cuerpo.

# Argumentos de salida:
 - `first_date::Float64`: Extremo izquierdo del primer intervalo de tiempo (en formato ET).
 - `last_date::Float64`: Extremo derecho del último intervalo de tiempo (en formato ET).
 - `n_days::Int`: Número de días que abarca cada intervalo.
 - `body_ID::Int`: ID del cuerpo deseado.
 - `body_name::String`: Nombre del cuerpo deseado.
 - `n_coeffs::Int`: Número de coeficientes que tiene cada polinomio de Chebyshev.
 - `n_sets::Int`: Número de polinomios de Chebyshev dentro de un intervalo.

@precondition: El fichero debe ser un fichero JSON cun un formato especifico.
"""
function get_header_data(body::Union{Int, String}, file_path=default_header_file_path::String)
    # Abrimos el fichero
    header_data = open(file_path, "r")
    # Generamos el diccionario
    header_dict = JSON.parse(header_data)
    # Cerramos el fichero
    close(header_data)
    # Obtenemos los datos generales
    first_date = header_dict["firstDate"]
    last_date = header_dict["lastDate"]
    n_days = header_dict["numberOfDays"]
    # Buscamos los datos del cuerpo solicitado
    index = 0
    try
        if typeof(body) == Int
            index = findall(x -> x["bodyID"] == body, header_dict["bodyData"])[1]
        else
            index = findall(x -> x["bodyName"] == body, header_dict["bodyData"])[1]
        end
    catch _
        error("That body isn't in the file")
    end
    body_dict = header_dict["bodyData"][index]   
    # Obtenemos los datos del cuerpo solicitado
    body_ID = body_dict["bodyID"]
    body_name = body_dict["bodyName"]
    n_coeffs = body_dict["numberOfCoeffs"]
    n_sets = body_dict["numberOfSets"]
    
    return (first_date, last_date, n_days, body_ID, body_name, n_coeffs, n_sets)
    
end

"""
*get_time_vector*

Devuelve un vector de fechas (en formato ET) contenidas en el fichero dado. Estas fechas corresponden a los intervalos de los
polinomios de Chebyshev.

# Argumentos de entrada:
 - `initial_date::Float64`: Fecha inicial, perteneciente al primer intervalo (en formato ET).
 - `final_date::Float64`: Fecha final, perteneciente al último intervalo (en formato ET).
 - `file_path::String`: Ruta del fichero de fechas.

# Argumentos de salida:
 - `time_vec::Vector{Float64}`: Vector de fechas (en formato ET).

@precondition: El fichero de intervalos de tiempo debe ser un fichero csv de una única columna.
"""
function get_time_vector(initial_date::Float64, final_date::Float64, file_path=default_time_file_path::String)
    
    # Cargamos el Data Frame
    df = CSV.read(file_path, DataFrame)
    
    # Leemos los valores de los intervalos que nos interesan
    time_vec = [.0; filter(x -> initial_date < x < final_date, df[:,1]); .0]
    
    # Añadimos los extremos
    index = findall(x -> x == time_vec[2], df[:,1])[1] - 1
    time_vec[1] = df[index,1]
    index = findall(x -> x == time_vec[end-1], df[:,1])[1] + 1
    time_vec[end] = df[index,1]
    
    return time_vec
    
end

"""
*ChebyshevNodes*

Dados el grado y el intervalo en el que queremos obtener los nodos de Chebyshev, esta función devuelve los nodos correspondientes.

# Argumentos de Entrada:
 - `N::Int32`: Grado de los nodos de Chebyshev
 - `tspan::Tuple{Float64, Float64}`: Intervalo en el que queremos los nodos de Chebysev.
# Argumentos de salida:
 - `tt::Vector{Float64}`: Vector de nodos de Chebyshev en el intervalo tspan.
"""
function ChebyshevNodes(N::Int32, tspan=(-1.,1.)::Tuple{Float64, Float64})
    thetas =  range(1,2N-1,step=2)/(2N)
    ta = tspan[1]
    tb = tspan[2]
    A = (ta+tb)/2
    B = (tb-ta)/2
    tt = Array{Float64}(undef,N)
    @. tt = A - B*cos(π*thetas)  # nodos de interpolación de Chebyshev
    return tt
end

"""
*ChebyshevCoeffs*

Dada una tabla con valores de la función que queremos aproximar en los nodos de Chebyshev devuelve los coeficientes del
polinomio interpolador.

# Argumentos de Entrada:
 - `ff::Vector{Float64}`: Tabla con componentes de la función que queremos aproximar en los nodos de Chebyshev en un intervalo.
# Argumentos de salida:
 - `hf::Vector{Float64}`: Vector de coeficientes del polinomio interpolador.
"""
function ChebyshevCoeffs(ff::Vector{Float64})
    N = length(ff)
    hf = dct(ff)*sqrt(2/N)
    return hf
end

"""
*generate_coeffs*

Genera los coeficientes de Chebyshev entre dos fechas dadas para un cuerpo especificado.

# Argumentos de Entrada:
- `initial_date::Float64`: Fecha inicial, perteneciente al primer intervalo (en formato ET).
- `final_date::Float64`: Fecha final, perteneciente al último intervalo (en formato ET).
 - `coeffs_info::Tuple{Int, Int, Int}`: Una tupla con la ID del cuerpo del que queremos obtener las Efemérides, número de
 coeficientes que queremos en nuestros polinomios y número de polinomios que queremos por intervalo.
 - `time_file_path::String`: Ruta del fichero de fechas.

# Argumentos de salida:
 - `time_vec::Vector{Float64}`: Vector de fechas (en formato ET).
 - `x::Matrix{Float64}`: Matriz de polinomios interpoladores de las posiciones del eje x. Cada fila es un polinomio, hay tantas
 columnas como coeficientes.
 - `y::Matrix{Float64}`: Matriz de polinomios interpoladores de las posiciones del eje y. Cada fila es un polinomio, hay tantas
 columnas como coeficientes.
 - `z::Matrix{Float64}`: Matriz de polinomios interpoladores de las posiciones del eje z. Cada fila es un polinomio, hay tantas
 columnas como coeficientes.
 - `vx::Matrix{Float64}`: Matriz de polinomios interpoladores de la velocidad en el eje x. Cada fila es un polinomio, hay tantas
 columnas como coeficientes.
 - `vy::Matrix{Float64}`: Matriz de polinomios interpoladores de la velocidad en el eje x. Cada fila es un polinomio, hay tantas
 columnas como coeficientes.
 - `vz::Matrix{Float64}`: Matriz de polinomios interpoladores de la velocidad en el eje x. Cada fila es un polinomio, hay tantas
 columnas como coeficientes.

@precondition: initial_date < final_date

@precondition: El fichero de intervalos de tiempo debe ser un fichero CSV de una única columna.
"""
function generate_coeffs(
    initial_date::Float64, final_date::Float64, coeffs_info::Tuple{Int, Int, Int}, 
    time_file_path=default_time_file_path::String)

    # Extraer información de coeffs_info
    (body_ID, n_coeffs, n_sets) = coeffs_info

    # Calculamos el número de coeficientes
    p = ceil(log(2, n_coeffs))
    k = Int32(2^p)

    # Obtenemos el vector con las fechas del fichero
    aux_time_vec = get_time_vector(initial_date, final_date, time_file_path)
    aux_time_vec_len = length(aux_time_vec)

    # Obtenemos los intervalos de los polinomios
    time_vec_len = (aux_time_vec_len-1)*n_sets+1
    time_vec = Vector{Float64}(undef, time_vec_len)

    index = 1
    midpoint = (aux_time_vec[2] - aux_time_vec[1])/n_sets
    for i in 1:aux_time_vec_len-1
        time_vec[index] = aux_time_vec[i]
        for j in 1:n_sets-1
            index += 1
            time_vec[index] = aux_time_vec[i] + (midpoint * j)
        end
        index += 1
    end
    time_vec[end] = aux_time_vec[end]

    # Generamos la matriz de nodos
    n_poly = time_vec_len-1
    chb_nodes = Matrix{Float64}(undef, n_poly, k)

    for i in 1:n_poly
        chb_nodes[i,:] = ChebyshevNodes(k, (time_vec[i], time_vec[i+1]))
    end

    # Matrices con los coeficientes
    x = Matrix{Float64}(undef, n_poly, k)
    y = Matrix{Float64}(undef, n_poly, k)
    z = Matrix{Float64}(undef, n_poly, k)
    vx = Matrix{Float64}(undef, n_poly, k)
    vy = Matrix{Float64}(undef, n_poly, k)
    vz = Matrix{Float64}(undef, n_poly, k)

    # Proceso de obtencion de valores de los coeficientes
    handle = nothing
    descr = nothing
    for i in 1:n_poly
        for j in 1:k
            # Obtenemos el descriptor de segmento
            handle, descr, _ = spksfs(body_ID, chb_nodes[i,j])
            # Obtenemos los valores en los nodos
            _, aux_vec, _ = spkpvn(handle, descr, chb_nodes[i,j])
            # Guardamos los valores en sus respectivas Matrices
            x[i,j] = aux_vec[1]
            y[i,j] = aux_vec[2]
            z[i,j] = aux_vec[3]
            vx[i,j] = aux_vec[4]
            vy[i,j] = aux_vec[5]
            vz[i,j] = aux_vec[6]
        end
        # Obtenemos los coeficientes
        x[i,:] = ChebyshevCoeffs(x[i,:])
        y[i,:] = ChebyshevCoeffs(y[i,:])
        z[i,:] = ChebyshevCoeffs(z[i,:])
        vx[i,:] = ChebyshevCoeffs(vx[i,:])
        vy[i,:] = ChebyshevCoeffs(vy[i,:])
        vz[i,:] = ChebyshevCoeffs(vz[i,:])
    end

    return time_vec, x, y, z, vx, vy, vz

end