# LittleEphemeris.jl

LittleEfemeris es un paquete resultante de un Trabajo de Fin de Grado de Ingeniería Informática. Este paquete se utiliza para calcular las coordenas y las velocidades de los cuerpos celestes especificados, mediante a interpolación en nodos de Chebyshev. También se utiliza para hacer una gestión ágil de ficheros de coeficientes.

## Instalación

```julia
julia> using Pkg
julia> Pkg.add("LittleEphemeris")
```

## Ficheros necesarios

Para que este paquete requiere ciertos archivos para su funcionamiento estos ficheros son:

 - Al menos un fichero LSK (LeapSeconds Kernel). Estos ficheros se pueden encontrar [aquí](https://naif.jpl.nasa.gov/pub/naif/generic_kernels/lsk/). El que ha sido usado a lo largo de la creación de este paquete ha sido el fichero [naif0012.tls](https://naif.jpl.nasa.gov/pub/naif/generic_kernels/lsk/naif0012.tls). 
 - El fichero SPK con las efemerides de los cuerpos deseados en los instantes deseados. Se pueden encontrar ficheros SPK [aquí](https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/). El que ha sido usado a lo largo de la creación de este paquete ha sido el fichero [de440.bsp](https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/planets/de440.bsp).
 - Un fichero CSV que contiene una única columna con los intervalos de los tiempos, en formato ET.
 - Un fichero JSON con los datos de los cuerpos que nos interesan. Como por ejemplo:

```JSON
{
    "firstDate": -1.42007472e10,
    "lastDate": 2.05140816e10,
    "numberOfDays": 32,
    "bodyData": [
        {
            "bodyID": 3,
            "bodyName": "EARTH BARYCENTER",
            "numberOfSets": 2,
            "numberOfCoeffs": 13
        },
        {
            "bodyID": 4,
            "bodyName": "MARS BARYCENTER",
            "numberOfSets": 1,
            "numberOfCoeffs": 11
        }
    ]
}
```

Esta información ha sido sacada del servidor FTP de la NASA: ftp://ssd.jpl.nasa.gov. Más especificamente del fichero que se encuentra en la ruta: ftp://ssd.jpl.nasa.gov/pub/eph/planets/ascii/de440/header.440.

Todos estos ficheros se pueden generar automaticamente de la siguiente manera:

```julia
using LittleEphemeris
generate_files("./data/")
```

Este proceso puede tardar un poco ya que es necesario descargar varios ficheros de coeficientes para extraer la información de los intervalos de tiempo.

## Primeros pasos

Una vez generados los ficheros lo primero es cargar los kernels para poder 

```julia
using SPICE
furnsh("data/naif0012.tls", "data/de440.bsp")
```

Despues para calcular el estado de un cuerpo en un instante de tiempo deseado es necesario generar un fichero de coeficientes.

```julia
ID_list = [3, 4]
time_interval = (utc2et("2022-01-01T12:00:00"), utc2et("2023-01-01T00:00:00"))
time_interval_list = fill(time_interval, 2)

create_coeffs_file("data/coeffs.json", "data/coeffs.csv", ID_list, time_interval_list, "header_data.json", "data/time.csv")
```

Una vez creado el fichero de coeficientes podemos generar una estructura del tipo BodyCoeffs para calcular el estado del cuerpo deseado.

```julia
Earth = BodyCoeffs("data/coeffs.json", "data/coeffs.csv", 3, time_interval);
t = utc2et("2022-05-17T10:45:00")

Earth(t)
```