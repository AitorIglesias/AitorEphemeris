module AitorEphemeris

using JSON
using CSV
using DataFrames
using SPICE
using FFTW

inculde("generate_files.jl")
include("generate_coefficients.jl")
include("manage_coefficients.jl")
include("BodyCoeffs.jl")

end