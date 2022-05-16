export BodyCoeffs

"""
*BodyCoeffs*

Estructura de coeficientes de un cuerpo

 - `bodyID::Int`: ID del cuerpo.
 - `bodyName::String`: Nombre del cuerpo.
 - `numberOfPolynomials::Int`: Numero de polinomios.
 - `numberOfCoeffs::Int`: Número de coeficientes en cada polinomio.
 - `timeIntervals::Vector{FloatType}`: Vector de intervalos de tiempo.
 - `x_coeffs::Matrix{FloatType}`: Matriz de coeficientes de las coordenadas en el eje x.
 - `y_coeffs::Matrix{FloatType}`: Matriz de coeficientes de las coordenadas en el eje y.
 - `z_coeffs::Matrix{FloatType}`: Matriz de coeficientes de las coordenadas en el eje z.
 - `vx_coeffs::Matrix{FloatType}`: Matriz de coeficientes de la velocidad en el eje x.
 - `vy_coeffs::Matrix{FloatType}`: Matriz de coeficientes de la velocidad en el eje y.
 - `vz_coeffs::Matrix{FloatType}`: Matriz de coeficientes de la velocidad en el eje z.
"""
struct BodyCoeffs{FloatType}

    bodyID::Int # ID del cuerpo
    bodyName::String # Nombre del cuerpo
    numberOfPolynomials::Int # Numero de polinomios
    numberOfCoeffs::Int # Número de coeficientes en cada polinomio

    timeIntervals::Vector{FloatType} # Vector de intervalos de tiempo
    
    x_coeffs::Matrix{FloatType} # Matriz de coeficientes de las coordenadas en el eje x
    y_coeffs::Matrix{FloatType} # Matriz de coeficientes de las coordenadas en el eje y
    z_coeffs::Matrix{FloatType} # Matriz de coeficientes de las coordenadas en el eje z

    vx_coeffs::Matrix{FloatType} # Matriz de coeficientes de la velocidad en el eje x
    vy_coeffs::Matrix{FloatType} # Matriz de coeficientes de la velocidad en el eje y
    vz_coeffs::Matrix{FloatType} # Matriz de coeficientes de la velocidad en el eje z

end

"""
*BodyCoeffs*

Constructora del objeto.

# Argumentos de entrada.
 - `info_file_path::String`: Ruta del fichero de información.
 - `file_path::String`: Ruta del fichero de coeficientes.
 - `body::Union{Int, String}`: ID o Nombre del cuerpo.
 - `tspan::Tuple{Float64, Float64}`: Intervalo de tiempo al que pertenecen los polinomios.

# Argumentos de salida.
 - `bc::BodyCoeffs{Float64}`: Objeto de coeficientes del cuerpo especificado
"""
function BodyCoeffs(info_file_path::String, file_path::String, body::Union{Int, String}, tspan::Tuple{Float64, Float64})

    # Obtenemos la información del fichero
    coeffs_info, coeffs_table = get_table_from_file(info_file_path, file_path, body, tspan)
    n_poly = coeffs_info.numberOfPolynomials
    n_coeffs = coeffs_info.numberOfCoeffs

    # Vectores de coeficientes
    x_coeffs = Matrix{Float64}(undef, n_poly, n_coeffs)
    y_coeffs = Matrix{Float64}(undef, n_poly, n_coeffs)
    z_coeffs = Matrix{Float64}(undef, n_poly, n_coeffs)
    vx_coeffs = Matrix{Float64}(undef, n_poly, n_coeffs)
    vy_coeffs = Matrix{Float64}(undef, n_poly, n_coeffs)
    vz_coeffs = Matrix{Float64}(undef, n_poly, n_coeffs)
    coeffs = [x_coeffs, y_coeffs, z_coeffs, vx_coeffs, vy_coeffs, vz_coeffs]

    # Guardamos los coeficientes
    line = 0
    for poly_index in 1:n_poly
        for coord_index in 1:6
            i = 1
            for coeff_line_index in 1:div(n_coeffs,8)
                line += 1
                coeffs[coord_index][poly_index,i:i+7] = Vector(coeffs_table[line,:])
                i += 8
            end
        end
    end
    
    # Creamos el objeto
    bc = BodyCoeffs{Float64}(
        coeffs_info.bodyID,
        coeffs_info.bodyName,
        coeffs_info.numberOfPolynomials,
        coeffs_info.numberOfCoeffs,
        coeffs_info.timeIntervals,       
        x_coeffs,
        y_coeffs,
        z_coeffs,
        vx_coeffs,
        vy_coeffs,
        vz_coeffs)
    
    return bc
end

"""
*BodyCoeffs*

Metodo del objeto que permite calcular las coordenadas y/o las velocidades del cuerpo especificado en el instante de tiempo especificado.

# Argumentos de entrada
 - `t::Float64`: Instante de cuerpo en el que se quieren conocer las coordenadas y/o velocidades del cuerpo.
 - `code::Int`: Integer que indica los parametros de salida. Por defecto code = 3.
    - code = 1: Devuelve el vector de las coordenadas.
    - code = 2: Devuelve el vector de las velocidades.
    - code = 3: Devuelve el vector de las coordenadas y las velocidades.

# Argumentos de salida
 - `res::Vector{Float64}`: Vector con las coordenadas y/o las velocidades del cuerpo especificado en el instante de tiempo especificado.
"""
function (body_coeffs::BodyCoeffs)(t::Float64, code=3::Int)

    # Índice del polinomo
    index = findlast(x -> x <= t, boddy_coeffs.timeIntervals)
    tspan = (boddy_coeffs.timeIntervals[index], boddy_coeffs.timeIntervals[index+1])

    # Vector  resultado
    len = 0
    code == 3 ? len = 6 : len = 3
    res = Vector{Float64}(undef, len)

    i = 0
    # Evaluamos los coeficientes de las coordenadas
    if code != 2
        res[i+1] = ChebyshevEval(boddy_coeffs.x_coeffs[index], t, tspan)
        res[i+2] = ChebyshevEval(boddy_coeffs.y_coeffs[index], t, tspan)
        res[i+3] = ChebyshevEval(boddy_coeffs.z_coeffs[index], t, tspan)
        i = 3
    end

    # Evaluamos los coeficientes de las velocidades
    if code != 1
        res[i+1] = ChebyshevEval(boddy_coeffs.x_coeffs[index], t, tspan)
        res[i+2] = ChebyshevEval(boddy_coeffs.y_coeffs[index], t, tspan)
        res[i+3] = ChebyshevEval(boddy_coeffs.z_coeffs[index], t, tspan)
    end

    return res

end