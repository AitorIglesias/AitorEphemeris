# LittleEphemeris.jl

LittleEphemeris es un paquete de Julia que permite realizar una gestión de Efemérides de manera ágil. El uso de este paquete es para personas que no necesiten bases de datos de Efemérides tan grandes como las que encontramos hoy en día, es decir, personas que necesitan una base de datos más específica, con menos cuerpos y para un intervalo de tiempo más reducido.

Este paquete, entre otras cosas, permite crear un fichero de polinomios que interpolan las coordenadas de posición y de velocidad de diferentes cuerpos en diferentes intervalos de tiempo para después poder evaluar estos polinomios en los instantes de tiempo deseados, ya sea directamente desde el fichero de polinomios o construyendo un objeto que almacene los polinomios y llamando a un método que evalúa los polinomios en el instante de tiempo deseado.

## Instalación del paquete

El paquete LittleEphemeris puede ser fácilmente instalado con los siguientes comandos de Julia:

```julia
julia> using Pkg
julia> Pkg.add("LittleEphemeris")
```

## Descarga de ficheros necesarios

Para que el paquete LittleEphemeris sea capaz de generar un fichero de polinomios necesita algunos ficheros, los cuales son:

- Un fichero de gestión de Efemérides también conocido como fichero SPK (Spacecraft and Planet Ephemeris Kernel). De este fichero se sacan los valores en los nodos para realizar interpolación polinómica y generar los polinomios.
- Un fichero LSK (Leapseconds Kernel), este fichero puede ser utilizado para realizar transformaciones entre formatos de tiempo.
- Un fichero CSV con una columna con los intervalos de tiempo que utiliza el fichero SPK descargado. Este fichero se utiliza para generar polinomios en los mismos intervalos de tiempo que utiliza el fichero SPK descargado.
- Un fichero JSON con los parámetros de los polinomios interpoladores contenidos en los ficheros SPK. Este fichero sirve para conocer el grado de los polinomios y el número de polinomios contenidos en cada intervalo.

Si bien estos ficheros pueden ser generados manualmente, el paquete LittleEphemeris, tiene implementada una funcionalidad para generar estos ficheros. Es necesario mencionar que esta funcionalidad puede tardar algunos minutos y el tiempo que tarde dependerá de la conexión a internet que posea el equipo que esté ejecutando el programa. Para ejecutar la funcionalidad se deben escribir los siguientes comandos de Julia:

```julia
julia> using LittleEphemeris
julia> generate_files("./data/")
```

Mediante estos comandos se generarán los ficheros mencionados anteriormente en una carpeta llamada data. El fichero JSON contiene únicamente datos de los baricentros de los planetas del sistema solar, junto con datos del baricentro de Plutón, datos del Sol y de la Luna. Si se quisieran generar polinomios de otros cuerpos o polinomios de los mismo cuerpos con un grado diferente, habría que modificar este fichero manualmente.

Este es un ejemplo de un pequeño fichero de datos de polinomios (no es el fichero que genera la función generate\_files):

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

Si se quisiera añadir por ejemplo dos cuerpos, el primero el baricentro de la Tierra con 32 coeficientes y el segundo la Tierra con 16 coeficientes, el fichero quedaría así:

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
        },
        {
            "bodyID": 3,
            "bodyName": "EARTH BARYCENTER 2",
            "numberOfSets": 2,
            "numberOfCoeffs": 32
        },
        {
            "bodyID": 399,
            "bodyName": "EARTH",
            "numberOfSets": 2,
            "numberOfCoeffs": 16
        }
    ]
}
```

No es recomendable modificar los parámetros firstDate, lastDate y numberOfDays, ya que estos están para evitar errores. Además, se pueden tener dos cuerpos con la misma ID ya que esta es utilizada para llamar a una función del paquete SPICE.jl. Sin embargo, para que el software del paquete LittleEphemeris funcione de la manera deseada en esta situación, se deberán usar las funciones para la generación del fichero de coeficientes refiriéndose al nombre del cuerpo en vez de a la ID. Por ello se le deben dar distintos nombres a ambos cuerpos.

## Generación de una tabla de coeficientes

Una vez se tienen los ficheros necesarios, se pueden generar los polinomios deseados. Para ello existe la función generate\_coeffs, que devuelve una tabla de polinomios. Sin embargo, para utilizar esta función, primero es necesario cargar los Kernels descargados anteriormente, si bien esto podría hacerlo la función que genera los coeficientes. Esto tiene algunos inconvenientes, los cuales son:

- Los Kernels tardan bastante en cargarse por lo que el programa para generar los coeficientes tardaría más de lo necesario.
- No hay manera de comprobar si un Kernel específico está cargado, por lo que en caso de llamar al programa generate\_files varias veces, este cargaría varias veces los Kernels.

Para evitar estos inconvenientes se ha decidido que los Kernels sean cargados con anterioridad. Para ello se puede hacer uso del paquete SPICE.jl puesto que el paquete LittleEphemeris no contiene esta funcionalidad. Para ello se deben ejecutar los siguientes comandos:

```julia
julia> using SPICE
julia> furnsh("data/naif0012.tls", "data/de440.bsp")
```

El método furnsh cargará los Kernels indicados. Si se desean cargar varios Kernels es recomendable indicarlos todos en la misma llamada, por cuestiones de eficiencia.

Una vez cargados los Kernels se puede llamar a la función generate\_coeffs. Esta función no depende del fichero JSON, pues el usuario indica cómo son los polinomios que desea. He aquí un ejemplo de cómo obtener los polinomios del baricentro de la Tierra para el año 2022:

```julia
# Intervalo de tiempo al que pertenecen los polinomios
et_0 = utc2et("2022-01-01T12:00:00")
et_end = utc2et("2023-01-01T12:00:00")

# Parámetros de los polinomios
ID = 3 # ID del baricentro de la Tierra
n_coeffs = 16 # Número de coeficientes del polinomio que se desea
n_sets = 2 # Número de polinomios en cada intervalo de tiempo contenido en el fichero de intervalos de tiempo

time_vec, x, y, z, vx, vy, vz = generate_coeffs(et_0, et_end, (ID, n_coeffs, n_sets), "data/time.csv")
```

La primera función utilizada, utc2et, es una función propia del paquete SPICE.jl, que permite transformar del formato de tiempo UTC al formato de tiempo ET. El paquete LittleEphemris trabaja exclusivamente con el formato de tiempo ET, sin embargo, no tiene un método que realice transformaciones entre formatos de tiempo, es por ello que si se tienen los instantes de tiempo en un formato distinto al formato ET, será necesario hacer uso de otras aplicaciones para realizar esta transformación.

generate\_coeffs devolverá un vector con los intervalos de tiempos de los polinomios generados junto a seis matrices. Cada una de estas matrices corresponderán a una coordenada, siendo las tres primeras las coordenadas de posición y las tres últimas las coordenadas de velocidad. Cada fila de estas matrices es un polinomio, más específicamente el polinomio interpolador para el intervalo de tiempo correspondiente en el vector de intervalos de tiempo. La matriz tendrá tantas columnas como coeficientes, por lo que cada uno de los elementos de la matriz corresponde a un coeficiente.

Sin embargo, puesto que los datos están almacenados en variables, es necesario generarlos cada vez que van a ser usados. El proceso es bastante rápido por lo que no supone un gran inconveniente. Aun así es más cómodo tener estos datos en un fichero. Por ello, LittleEphemeris proporciona las funcionalidades explicadas en las siguientes secciones de este anexo.

## Generación de un fichero de coeficientes

Para generar ficheros de coeficientes al igual que para generar una tabla de coeficientes es necesario tener cargados los Kernels. Una vez cargados, se puede generar un fichero de coeficientes de manera bastante sencilla con la función create\_coeffs\_file. Un ejemplo del uso de la función sería el siguiente:

```julia
ID_list = [1, 3] # ID de los cuerpos (también funciona con los nombres de los cuerpos)
time_interval = (utc2et("2022-01-01T12:00:00"), utc2et("2022-02-01T00:00:00"))
time_interval_list = fill(time_interval, 2)

create_coeffs_file("data/coeffs.json", "data/coeffs.csv", ID_list, time_interval_list, "data/header_data.json", "data/time.csv")
```

Para llamar a esta función es necesario que los cuerpos indicados estén ordenados de manera ascendente respecto a las IDs de dichos cuerpos. Esto debido a que el programa que genera la tabla no los ordenará y el algoritmo de búsqueda del fichero que utiliza el paquete LittleEphemeris da por hecho que están ordenados, debido a cuestiones de eficiencia. Esta función genera un fichero de coeficientes y un fichero de información correspondiente al fichero de coeficientes.

El fichero de coeficientes está en formato CSV, es decir, es un fichero que almacena tablas. La tabla encontrada en estos ficheros siempre tendrá 8 columnas, debido a que todos los polinomios tiene un número de coeficientes igual a una potencia de dos y como poco tienen 8 coeficientes, esto debido a cuestiones de eficiencia.

El fichero de coeficientes está dividido en tantas secciones como cuerpos se le hayan indicado a la función create\_coeffs\_file, es decir, los cuerpos de secciones son los mismos que los indicados en el vector. Dentro de cada sección hay tantas subsecciones como intervalos de tiempo. En cada una de estas subsecciones hay seis polinomios de Chebyshev, los tres primeros sirven para calcular las coordenadas de la posición del cuerpo en el instante específico, mientras que los tres últimos sirven para calcular las coordenadas de la velocidad del cuerpo en el instante específico.

El fichero de información generado por la función, es necesario para poder interpretar de manera adecuada el fichero de coeficientes. Este fichero es del tipo JSON y contienen una lista en la que cada elemento contiene
los siguientes datos:

- La ID del cuerpo.
- El nombre del cuerpo.
- El número de polinomios que interpolan el estado de ese cuerpo.
- El número de coeficientes que tiene cada polinomio.
- Un vector con los intervalos de tiempo correspondientes a los polinomios.

Este sería el fichero JSON generado por el código anterior:

```JSON
[
    {
        "bodyID": 1,
        "bodyName": "MERCURY BARYCENTER",
        "numberOfPolynomials": 8,
        "numberOfCoeffs": 16,
        "timeIntervals": [
            6.932304e8,
            6.939216e8,
            6.946128e8,
            6.95304e8,
            6.959952e8,
            6.966864e8,
            6.973776e8,
            6.980688e8,
            6.9876e8
        ]
    },
    {
        "bodyID": 3,
        "bodyName": "EARTH BARYCENTER",
        "numberOfPolynomials": 4,
        "numberOfCoeffs": 16,
        "timeIntervals": [
            6.932304e8,
            6.946128e8,
            6.959952e8,
            6.973776e8,
            6.9876e8
        ]
    }
]
```

## Generar fichero de coeficientes a partir de un fichero de coeficientes

Las siguientes funcionalidades no necesitarán los ficheros generados por la función generate\_files, por lo que si ya ha sido creado un fichero de coeficientes con la información necesaria, estos ficheros pueden ser eliminados. Aún así se recomienda mantener el fichero LSK para realizar transformaciones entre los distintos formatos de tiempo.

Una funcionalidad que proporciona LittleEphemeris es la de crear un fichero de coeficientes más pequeño a partir de un fichero de coeficientes. Esto puede resultar útil si se quieren evaluar únicamente ciertos cuerpos, pero se quiere tener información sobre más cuerpos para trabajar con esta información en el futuro. Para utilizar esta funcionalidad se debe usar la función generate\_subfile de la siguiente manera:

```julia
ID_list = [3] # ID de los cuerpos (también funciona con los nombres de los cuerpos)
time_interval = (utc2et("2022-01-01T12:00:00"), utc2et("2022-02-01T00:00:00"))
time_interval_list = fill(time_interval, 1)

generate_subfile("data/coeffs_subfile.json", "data/coeffs_subfile.csv", ID_list, time_interval_list, "data/coeffs.json", "data/coeffs.csv")
```

Esta función es igual a la función create\_coeffs\_file solo que no necesita ficheros adicionales a los ficheros de coeficientes generados por el paquete LittleEphemeris. Además, únicamente copia datos de otro fichero, es decir, no tiene que generar polinomios, por ello, es mucho más rápido que la función create\_coeffs\_file.

## Evaluar un fichero de coeficientes

Para poder darle uso a un fichero de coeficientes, el paquete LittleEphemeris proporciona la funcionalidad de evaluar los polinomios de este fichero para los instantes de tiempo deseados. Para ello hay que hacer uso de la función eval\_coeffs\_file, esta función permite evaluar los polinomios de un cuerpo en varios instantes de tiempo. Este es un ejemplo de como usar la función eval\_coeffs\_file:

```julia
ID = 3
et_0 = utc2et("2022-01-01T12:00:00")
et_end = utc2et("2022-02-01T12:00:00")

x, y, z, vx, vy, vz = eval_coeffs_file("data/coeffs.json", "data/coeffs.csv", ID, [et_0:10000:et_end])
```

## Objeto de coeficientes de un cuerpo

Para finalizar es posible que se desee trabajar únicamente con un cuerpo. Por ello LittleEphemeris tiene la funcionalidad de generar un objeto de coeficientes de un cuerpo a partir de un fichero de coeficientes. De esta manera se puede tener la información cargada en memoria y así evaluar los polinomios de una manera más ágil. Este objeto tiene se puede crear mediante a su constructora:

```julia
ID = 3
time_interval = (utc2et("2022-01-01T12:00:00"), utc2et("2022-02-01T00:00:00"))

Earth = BodyCoeffs("data/coeffs.json", "data/coeffs.csv", ID, time_interval)
```

Evaluar estos objetos es de lo más sencillo puesto que solo es necesario indicarle el instante de tiempo en el que se quiere evaluar, de la siguiente manera:

```julia
t = utc2et("2022-01-107T00:00:00")
Earth(t)
```