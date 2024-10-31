using LASDatasets

using ColorTypes
using FixedPointNumbers
using Random
using StaticArrays
using Test
using TypedTables

# fix random seed to avoid random errors
Random.seed!(0)

include("util.jl")
include("spatial_info.jl")
include("vlrs.jl")
include("points.jl")
include("header.jl")
include("dataset.jl")
include("file_io.jl")