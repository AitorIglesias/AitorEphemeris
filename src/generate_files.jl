export generate_files

struct BodyStruct

    bodyID::Int32
    bodyName::String
    numberOfSets::Int32
    numberOfCoeffs::Int32

end

struct HeaderStruct
    
    firstDate::Float64
    lastDate::Float64
    numberOfDays::Int32

    bodyData::Vector{BodyStruct}

end

# kernels paths
const LSK = "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/lsk/naif0012.tls"
const SPK = "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/planets/de440.bsp"
# Chebyshev coefficients paths and file names
const files_path = "ftp://ssd.jpl.nasa.gov/pub/eph/planets/ascii/de440/"
const header_name = "header.440"
const file_list = ["ascp01550.440", "ascp01650.440", "ascp01750.440", "ascp01850.440", "ascp01950.440", "ascp02050.440", "ascp02150.440", "ascp02250.440", "ascp02350.440", "ascp02450.440", "ascp02550.440"]

# Nombres de los cuerpos celestes
const body_name_list =
    ["MERCURY BARYCENTER", "VENUS BARYCENTER", "EARTH BARYCENTER", "MARS BARYCENTER",
    "JUPITER BARYCENTER", "SATURN BARYCENTER", "URANUS BARYCENTER", "NEPTUNE BARYCENTER",
    "PLUTO BARYCENTER", "MOON", "SUN", "librations of the Earth", "mutations of the Moon", "???", "???"]
# IDs de los cuerpos celestes
const body_ID_list =
    [1, 2, 3, 4, 5, 6, 7, 8, 9, 301, 10, 2147483647, 2147483647, 2147483647, 2147483647]

function generate_files(path="./"::String)
    ####################
    # Download kernels #
    ####################
    # LSK Kernel
    println("Downloading LSK kernel...")
    download(LSK, "naif0012.tls")
    println("LSK Kernel successfully downloaded.")
    # Load leap seconds kernel
    furnsh("naif0012.tls")
    # SPK Kernel
    println("Downloading SPK kernel...")
    download(SPK, "de440.bsp")
    println("SPK Kernel successfully downloaded.")

    ###################
    # Get Header data #
    ###################

    # Download Header
    println("Downloading Header file...")
    download((files_path * header_name), header_name)
    println("Header file successfully downloaded.")

    println("Reading " * header_name)

    # Numero de cuerpos
    n_bodies = length(body_name_list)

    # Se guardan los datos en un diccionario para posteriormente generar un JSON
    body_data = Vector{BodyStruct}(undef, n_bodies)

    # Abrimos el fichero
    header = open(header_name, "r")
    header_str = read(header, String)
    # Cerramos el fichero
    close(header)

    # Obtenemos el número de coeficientes
    n_coeffs_per_block = parse(Int32, match(r"(NCOEFF=\s\d+[^\s])", header_str)[1][9:end])
    
    # Obtenemos la información del GROUP 30
    regex30 = r"(GROUP(\s)+1030[^G]+)"
    g30data = match(regex30, header_str)[1]
    # Obtenemos la fecha inicial y final
    regexDates = r"(\d{7}\.\d{2})"
    dates = []
    for m in eachmatch(regexDates, g30data)
        et_date = unitim(parse(Float64, m[1]), "JED", "ET")
        append!(dates, et_date)
    end
    # Obtenemos el número de días que abarca cada bloque
    regexdays = r"(\d+\.\n)"
    days = parse(Int32, match(regexdays, g30data)[1][1:end-2])

    # Obtenemos la información del GROUP 50
    regex50 = r"(GROUP(\s)+1050[^G]+)"
    g50lines = match(regex50, header_str)[1]
    # Obtenemos las 3 lineas
    lines = []
    for m in eachmatch(r"(\n.+\d.+[^\n])", g50lines)
        push!(lines, m.match[2:end])
    end
    # Obtenemos el número de coeficientes y el número de sets de los cuerpos
    bodies_n_coeffs = parse.(Int32, filter(x -> x != "", split(lines[2], " ")))
    bodies_n_sets = parse.(Int32, filter(x -> x != "", split(lines[3], " ")))

    # Generar los diccionarios
    for i in 1:n_bodies
        body_data[i] = 
            BodyStruct(body_ID_list[i], body_name_list[i], bodies_n_sets[i], bodies_n_coeffs[i])
    end

    println("Generating .json file with the header data...")

    # dictionary to write
    header_data = HeaderStruct(dates[1], dates[2], days, body_data)

    # pass data as a json string (how it shall be displayed in a file)
    stringdata = JSON.json(header_data)

    # write the file with the stringdata variable information
    open("header_data.json", "w") do f
            write(f, stringdata)
    end

    println("header_data.json file successfully generated.")

    # Eliminamos el fichero
    println("Removing " * header_name * " file...")
    rm(header_name)
    println(header_name * " file successfully removed.")

    #####################
    # Generate time csv #
    #####################

    time_df = DataFrame(x1 = Float64[])

    for file_name in file_list
        # Download Chebyshev coefficients
        println("Downloading " * file_name * " file...")
        download((files_path * file_name), file_name)
        println(file_name * " file successfully downloaded.")

        println("Reading " * file_name * " file...")

        # Abrimos el fichero
        f = open(file_name, "r")
        # Guardamos el contenido en un String
        str = read(f, String)
        # Cerramos el fichero
        close(f)

        # Obtenemos todos los coeficientes del fichero
        all_coeffs = filter(x -> 22 <= length(x) <= 24, split(str, " "))
        # Número de coeficientes totales
        n_coeffs = length(all_coeffs)
        # Número de bloques en el fichero
        n_blocks = Int32(n_coeffs/n_coeffs_per_block)
        # Vector en el que guardaremos los intervalos de tiempo
        time_vec = Vector{Float64}(undef, n_blocks+1)


        println("Saving information from file" * file_name * "...")

        # Diccionario para pasar los números de formato Fortran a formato Julia, además de quitar el \n
        f2jDict = Dict("D" => "e", "\n" => "")
        # Guardamos unicamente los intervalos de tiempo
        index = 0
        for i in 1:n_blocks
            index = (i-1)*n_coeffs_per_block +1
            time_vec[i] = parse(Float64, replace(all_coeffs[index], r"D|\n" => e -> f2jDict[e]))
        end
        time_vec[end] = parse(Float64, replace(all_coeffs[index+1], r"D|\n" => e -> f2jDict[e]))

        # Transformamos de formato JDTDB a formato ET
        if file_name == file_list[1]
            time_vec = unitim.(time_vec[:], "JDTDB", "ET")
        else
            time_vec = unitim.(time_vec[3:end], "JDTDB", "ET")
        end

        # Guardamos la información en el DataFrame
        aux_df = DataFrame(x1 = time_vec)
        append!(time_df, aux_df)

        println("Information successfully saved.")

        # Eliminamos el fichero
        println("Removing " * file_name * " file...")
        rm(file_name)
        println(file_name * " file successfully removed.")

    end

    println("Generating time.csv file...")

    # Generamos el CSV
    CSV.write("time.csv", time_df)

    println("time.csv file successfully generated.")

end