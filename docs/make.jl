using LittleEphemeris
using Documenter

makedocs(
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
    ),
    sitename = "LittleEphemeris.jl",
    authors = "Aitor Iglesias",
    pages = [
        "Home" => "index.md",
        "API" => "api.md",
    ],
    doctest = false,
)

deploydocs(
    repo = "github.com/AitorIglesias/LittleEphemeris.git",
    target = "build",
)