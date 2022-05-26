export create_coeffs_file
export generate_subfile
export add_coeffs
export eval_coeffs_file

struct CoefficientsInfo

    bodyID::Int # ID del cuerpo
    bodyName::String # Nombre del cuerpo
    numberOfPolynomials::Int # Numero de polinomios
    numberOfCoeffs::Int # Número de coeficientes en cada polinomio

    timeIntervals::Vector{Float64} # Vector de intervalos de tiempo

end

"""
*create_coeffs_table*

Trasnforma el formmato en el que estan los coeficientes para que se adapten al formato del CSV

# Argumentos de entrada:
 - `coeffs_info::CoefficientsInfo`: Estructura con información necesaria para generar la tabla
 - `coeffs_vector::Vector{Matrix{Float64}}`: Vector de matrices de polinomios de Chebysev

# Argumentos de salida
 - `coeffs_matrix::Matrix{Float64}`: Matriz de coeficientes en el formato adecuado
"""
function create_coeffs_table(coeffs_info::CoefficientsInfo, coeffs_vector::Vector{Matrix{Float64}})

    # Datos necesarios de la tabla
    lines_per_poly = div(coeffs_info.numberOfCoeffs, 8)
    n_coords = length(coeffs_vector)
    lines_in_table = lines_per_poly * coeffs_info.numberOfPolynomials * n_coords

    # Inicializamos la tabla
    coeffs_matrix = Matrix{Float64}(undef, lines_in_table, 8)

    # Guardamos los coeficientes de manera apropiada
    index = 0
    for poly_index in 1:coeffs_info.numberOfPolynomials
        for coord_index in 1:n_coords
            for line_index in 1:lines_per_poly
                index += 1
                range = ((8*(line_index-1)+1):(8*line_index))
                coeffs_matrix[index,:] = coeffs_vector[coord_index][poly_index,range]
            end
        end
    end

    return coeffs_matrix

end

"""
*create_coeffs_file*

Genera dos ficheros, un fichero CSV con los coeficientes y uno JSON con los datos de coefficients

# Argumentos de entrada
 - `coeffs_info_file_path::String`: Ruta del fichero de información que se quiere crear.
 - `coeffs_file_path::String`: Ruta del fichero de coeficientes que se quiere crear.
 - `body_vec::Union{Vector{Int} Vector{String}}`: Vector de IDs o de nombres de los cuerpos de los que se quieren obtener los
 coeficientes.
 - `time_interval_vec::Vector{Tuple{Float64, Float64}}`: Vector de intervalos de tiempo.
 - `header_file_path::String`: Ruta del fichero de información existente.
 - `time_file_path::String`: Ruta del fichero de intervalos de tiempo.

@precondition: La longitud del vector de cuerpos debe ser igual a la longitud del vector de intervalos de tiempos.

@precondition: El fichero de información (header) debe ser un fichero JSON cun un formato especifico.

@precondition: El fichero de intervalos de tiempo debe ser un fichero csv de una única columna.
"""
function create_coeffs_file(
    coeffs_info_file_path::String, coeffs_file_path::String,
    body_vec::Union{Vector{Int}, Vector{String}}, time_interval_vec::Vector{Tuple{Float64, Float64}},
    header_file_path=default_header_file_path::String, time_file_path=default_time_file_path::String)

    n_bodies = length(body_vec)

    if n_bodies != length(time_interval_vec)
        error("The number of bodies is different from the number of time intervals")
    end

    # Generamos fichero de información
    coeffs_info_vec = Vector{CoefficientsInfo}(undef, n_bodies)
    coeffs_table = Matrix{Float64}(undef, 0, 8)
    for i in 1:n_bodies
        # Datos de la iteración
        initial_date, final_date = time_interval_vec[i]
        body = body_vec[i]

        # Comprobamos que initial_date es menor que final_date
        if final_date < initial_date
            error("The initial date is higher than the final date.")
        end

        # Obtenemos los datos del header
        first_date, last_date, n_days, body_ID, body_name, n_coeffs, n_sets = get_header_data(body, header_file_path)

        # Comprobamos que los coeficientes esten dentro del rango.
        if initial_date < first_date || last_date < final_date
            error("Dates out of range.")
        end

        # Guardamos una tupla con la información del polinomio
        coeffs_info = (body_ID, n_coeffs, n_sets)
        # Llamamos al método principal 
        time_vec, x, y, z, vx, vy, vz = generate_coeffs(initial_date, final_date, coeffs_info, time_file_path)
        # Vector de coeficientes
        coeffs_vector = [x, y, z, vx, vy, vz]

        # Datos de la estructura
        n_poly, n_coeffs = size(x)
        # Guardamos la información en el vecotor
        coeffs_info_vec[i] = CoefficientsInfo(body_ID, body_name, n_poly, n_coeffs, time_vec)

        # Creamos la tabla de coeficientes de la iteración
        table = create_coeffs_table(coeffs_info_vec[i], coeffs_vector)
        # Guardamos los datos en la tabla
        coeffs_table = vcat(coeffs_table, table)
    end

    # Guardamos el fichero de información y 
    # pass data as a json string (how it shall be displayed in a file)
    stringdata = JSON.json(coeffs_info_vec)
    # write the file with the stringdata variable information
    open(coeffs_info_file_path, "w") do f
        write(f, stringdata)
    end
    # Guardamos los datos en el CSV
    df = DataFrame(coeffs_table, :auto)
    CSV.write(coeffs_file_path, df)

end

"""
*get_table_from_file*

Devuelve una tabla con los coeficientes del cuerpo especificado en el intervalo especificado y la información de la tabla.

# Argumentos de entrada
 - `info_file_path::String`: Ruta del fichero de información.
 - `file_path::String`: Ruta del fichero de coeficientes.
 - `body::Union{Int, String}`: ID o nombre del cuerpo del que desamos obtener la tabla.
 - `tspan::Tuple{Float64, Float64}`: Intervalo de tiempo de los polinomios que queremos obtener.

# Argumentos de salida
 - `ci::CoefficientsInfo`: Objeto con la información de la tabla.
 - `table::DataFrame`: Tabla de coeficientes.


@precondition: El fichero de información debe ser un fichero JSON con un formato especifico.

@precondition: El fichero de coeficientes debe ser un fichero csv con un formato especifico.
"""
function get_table_from_file(
    info_file_path::String, file_path::String,
    body::Union{Int, String}, tspan::Tuple{Float64, Float64})

    # Lectura de ficheros
    # Fichero de información
    coeffs_info = open(info_file_path, "r")
    # Generamos el vector de diccionarios
    coeffs_info_vec = JSON.parse(coeffs_info);
    # Fichero de coefficientes
    coeffs_df = CSV.read(file_path, DataFrame)

    # Intervalo de tiempo
    t0, tEnd = tspan

    # Lista de indices del objeto
    index_list = Vector{Int}(undef, 1)
    if typeof(body) == Int
        index_list = findall(x -> x["bodyID"] == body, coeffs_info_vec)
    else
        index_list = findall(x -> x["bodyName"] == body, coeffs_info_vec)
    end

    # Error en caso de que el cuerpo no esté en el fichero
    if length(index_list) == 0
        error("The body is not in the file.")
    end

    # Encontramos el indice al que pertenece el objeto
    body_dict = nothing
    i = 1
    found = false
    index = 0
    while i <= length(index_list) || !found
        index = index_list[i]
        t_vec = coeffs_info_vec[index]["timeIntervals"]
        if (t_vec[1] < t0 && tEnd < t_vec[end])
            body_dict = coeffs_info_vec[index]
            found = true
        end
        i += 1
    end

    # Los intervalos de tiempo indicados no esten en el fichero
    if(!found)
        error("Error the time range is not within the body's time range.")
    end

    # Calculamos cuantas lineas hasta el cuerpo deseado
    line = 1
    for j in 1:index-1
        line += coeffs_info_vec[j]["numberOfPolynomials"] * div(coeffs_info_vec[j]["numberOfCoeffs"], 8) * 6
    end

    # Índices de los polinomios
    i0 = findlast(x -> x <= t0, coeffs_info_vec[index]["timeIntervals"])
    iEnd = findlast(x -> x <= tEnd, coeffs_info_vec[index]["timeIntervals"])+1
    # Linea de los polinomios deseado
    line += (i0-1) * div(coeffs_info_vec[index]["numberOfCoeffs"], 8) * 6
    last_line = line + (iEnd-i0) * div(coeffs_info_vec[index]["numberOfCoeffs"], 8) * 6 - 1

    # Construimos el objeto de información
    ci = CoefficientsInfo(
        coeffs_info_vec[index]["bodyID"],
        coeffs_info_vec[index]["bodyName"],
        (iEnd-i0),
        coeffs_info_vec[index]["numberOfCoeffs"],
        coeffs_info_vec[index]["timeIntervals"][i0:iEnd])
    

    return ci, coeffs_df[line:last_line,:]

end

"""
*generate_subfile*

Partiendo de un fichero genera otro con los cuerpos indicados en los intervalos de tiempo indicados.

# Argumentos de entrada
 - `info_subfile_path::String`: Ruta del nuevo fichero de información.
 - `subfile_path::String`: Ruta del nuevo fichero de coeficientes.
 - `body_vec::Union{Vector{Int}, Vector{String}}`: Vector de IDs de los cuerpos o de los nombres de los cuerpo.
 - `time_interval_vec::Vector{Tuple{Float64, Float64}}`: Vector de intervalos de tiempo.
 - `info_main_file_path::String`: Ruta del fichero de información original.
 - `main_file_path::String`: Ruta del fichero de coeficientes original.
"""
function generate_subfile(
    info_subfile_path::String, subfile_path::String,
    body_vec::Union{Vector{Int}, Vector{String}}, time_interval_vec::Vector{Tuple{Float64, Float64}},
    info_main_file_path::String, main_file_path::String)

    # Vector de información
    coeffs_info_vec = Vector{CoefficientsInfo}(undef, length(body_vec))
    # Tabla de coeficientes
    coeffs_table = Matrix{Float64}(undef, 0, 8)
    df = DataFrame(coeffs_table, :auto)

    for i in 1:length(body_vec)
        coeffs_info, table = get_table_from_file(info_main_file_path, main_file_path, body_vec[i], time_interval_vec[i])
        # Guardamos la información de los coeficientes
        coeffs_info_vec[i] = coeffs_info
        # Guardamos los datos en la tabla
        df = vcat(df, table)
    end

    # Guardamos el fichero de información y 
    # pass data as a json string (how it shall be displayed in a file)
    stringdata = JSON.json(coeffs_info_vec)
    # write the file with the stringdata variable information
    open(info_subfile_path, "w") do f
        write(f, stringdata)
    end
    # Guardamos los datos en el CSV
    CSV.write(subfile_path, df)

end

"""
*add_coeffs*

Inserta de manera ordenada nuevos coeficientes a una tabla de coeficientes existente

# Argumentos de entrada:
 - `coeffs_info_vec::Vector{CoefficientsInfo}`: Vector de structuras de información de coeficientes.
 - `coeffs_table::Matrix{Float64}`: Tabla de coefficientes a la que queremos añadir los coeficientes
 - `coeffs_info::CoefficientsInfo`: Estructura de información de los nuevos coeficientes.
 - `coeffs_vector::Vector{Matrix{Float64}})`: Vector de los coeficientes que se quieren añadir.

# Argumentos de salida:
 - `new_coeffs_info_vec::Vector{CoefficientsInfo}`: Nuevo vector de información del fichero de coeficientes.
 - `table::Matrix{Float64}`: Nueva tabla de coeficientes

@precondition: Los coeficientes de la tabla existentes deberan estar ordenados segun sus IDs en orden ascendente. 
"""
function add_coeffs(
    coeffs_info_vec::Vector{CoefficientsInfo}, coeffs_table::Matrix{Float64},
    coeffs_info::CoefficientsInfo, coeffs_vector::Vector{Matrix{Float64}})

    # Dimensiones de la tabla actual
    n_rows, n_cols = size(coeffs_table)
    # Número de lineas que ocupan los nuevos coeficientes
    n_lines = (coeffs_info.numberOfPolynomials * div(coeffs_info.numberOfCoeffs, n_rows)) * 6

    # Creamos la tabla de coeficientes
    table = Matrix{Float64}(undef, n_rows + n_lines, n_cols)
    # Creamos el Vector de información de los coeficientes
    new_coeffs_info_vec = Vector{CoefficientsInfo}(undef, length(dict_vec)+1)

    # Calculamos las lineas que ocupan los coeficientes anteriores 
    i = 1
    line = 0
    while coeffs_info_vec[i].bodyID <= coeffs_info.bodyID
        new_coeffs_info_vec[i] = coeffs_info_vec[i]
        # Contamos las lineas que ocupa 
        line += (coeffs_info_aux.numberOfPolynomials * div(coeffs_info_aux.numberOfCoeffs, n_rows)) * 6
        i += 1
    end
    # Guardamos la nueva estructura
    new_coeffs_info_vec[i] = coeffs_info
    # Guardamos la información que falta
    new_coeffs_info_vec[i+1:end] = coeffs_info_vec[i:end]

    # Añadimos los coeficientes anteriores a la tabla
    table[1:line,:] = coeffs_table[1:line,:]
    # Guardamos los nuevos coeficientes de manera apropiada
    index = line
    for poly_index in 1:coeffs_info.numberOfPolynomials
        for coord_index in 1:n_coords
            for line_index in 1:lines_per_poly
                index += 1
                range = ((8*(line_index-1)+1):(8*line_index))
                table[index,:] = coeffs_vector[coord_index][poly_index,range]
            end
        end
    end
    # Guardamos los coeficientes que faltan
    table[index+1:end,:] = coeffs_table[line+1:end,:]

    return new_coeffs_info_vec, table

end

"""
*ChebyshevEval*: 

La siguiente función evalua el polinomio interpolador para una t dada en el intervalo indicado.

# Argumentos de Entrada:
  - `hf::Vector{Float64}`: Vector de coeficientes del polinomio interpolador.
  - `t::Float64`: instante en el que queremos evaluar el polinomio.
  - `tspan::Tuple{Float64, Float64}`: intervalo al que pertenece el polinomio interpolador.

  # Argumentos de salida:**
  - `f(t)::Float64`: siendo f la función que queremos interpolar.
"""
function ChebyshevEval(hf::Vector{Float64},t::Float64, tspan=(-1.,1.)::Tuple{Float64, Float64})
    # Algoritmo de Clenshaw
    N = length(hf)
    ta = tspan[1]
    tb = tspan[2]
    A = (ta+tb)/2
    B = (tb-ta)/2
    x = (A-t)/B
    x2 = 2*x
    b = 0.
    b_ = hf[N]
    for k in N-1:-1:2
        aux = hf[k] + x2*b_ - b
        b = b_
        b_ = aux
    end
    return sqrt(2)/2*hf[1] + x*b_ - b
end

"""
*eval_coeffs_file*

Evalua los coeficientes que se encuentran en un fichero especificado en los intervalos de tiempo especificados.

# Argumentos de entrada
 - `coeffs_info_file_path::String`: Ruta del fichero de información.
 - `coeffs_file_path::String`: Fichero de coeficientes.
 - `body::Union{Int, String}`: Cuerpo del que se quieren evaluar los cooeficientes.
 - `time_vector::Vector{Float64}`: Vector de instantes en los que se quiere evaluar los coeficientes.

# Argumentos de salida
 - `x::Vector{Float64}`: Vector de coordenas en el eje x.
 - `y::Vector{Float64}`: Vector de coordenas en el eje y.
 - `z::Vector{Float64}`: Vector de coordenas en el eje z.
 - `vx::Vector{Float64}`: Vector de velocidad en el eje x.
 - `vy::Vector{Float64}`: Vector de velocidad en el eje y.
 - `vz::Vector{Float64}`: Vector de velocidad en el eje z.

@precondition: el fichero de información debe ser un fichero JSON y tiene que estar en un formato específico.
"""
function eval_coeffs_file(
    coeffs_info_file_path::String, coeffs_file_path::String,
    body::Union{Int, String}, time_vector::Vector{Float64})

    # Fichero de información
    # Abrimos el fichero
    coeffs_info = open(coeffs_info_file_path, "r")
    # Generamos el vector de diccionarios
    coeffs_info_vec = JSON.parse(coeffs_info)
    # Fichero de coeficientes
    coeffs_df = CSV.read(coeffs_file_path, DataFrame)

    # Calculamos en que linea inicia el cuerpo deseado
    # Calculamos el indice del cuerpo deseado
    line = 1
    index = 1
    coeffs_info = coeffs_info_vec[index]
    while coeffs_info["bodyID"] != body && coeffs_info["bodyName"] != body
        line += Int(coeffs_info_vec[index]["numberOfPolynomials"] * (coeffs_info_vec[index]["numberOfCoeffs"]/8) * 6)
        index += 1
        coeffs_info = coeffs_info_vec[index]
    end

    # Datos del cuerpo deseado
    # Numero de polinomios
    n_poly = coeffs_info["numberOfPolynomials"]
    # Número de coeficientes del segundo planeta
    n_coeffs = coeffs_info["numberOfCoeffs"]
    # Número de lineas por cada polinomio del segundo planeta
    n_lines = n_coeffs/8
    # Vector de intervalos
    time_intervals = coeffs_info["timeIntervals"]
    # Número de intervalos
    n_intervals = length(time_intervals)-1
    # Número de nodos en los que queremos obtener las coordenadas
    n_nodes = length(time_vector)


    # Vectores de coordenadas
    x = Vector{Float64}(undef, n_nodes)
    y = Vector{Float64}(undef, n_nodes)
    z = Vector{Float64}(undef, n_nodes)
    vx = Vector{Float64}(undef, n_nodes)
    vy = Vector{Float64}(undef, n_nodes)
    vz = Vector{Float64}(undef, n_nodes)
    coords = [x, y, z, vx, vy, vz]

    # Evaluamos los nodos
    interval_index = 1
    for node_index in 1:n_nodes
        node = time_vector[node_index]
        # Obtenemos el intervalo de tiempo al que pertenece
        found = false
        while interval_index <= n_intervals && !found
            if time_intervals[interval_index] <= node <= time_intervals[interval_index+1]
                found = true
                poly_line = line
                # Realizamos el proceso para todos los ejes
                for coord_index in 1:6
                    # Obtenemos los coeficientes
                    hf = Vector{Float64}(undef, n_coeffs)
                    for line_index in 1:n_lines
                        range = Int(8*(line_index-1)+1):Int(line_index*8)
                        hf[range] = Vector(coeffs_df[Int(poly_line),:])
                        poly_line += 1
                    end
                    # Evaluamos los coeficientes
                    tspan = (time_intervals[interval_index], time_intervals[interval_index+1])
                    coords[coord_index][node_index] = ChebyshevEval(hf, node, tspan)
                end
            else
                line += n_lines * 6
                interval_index += 1
            end
        end
    end

    return x, y, z, vx, vy, vz

end