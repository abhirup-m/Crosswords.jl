module Crosswords

using Distributed, TOML, ProgressMeter

include("helpers.jl")
include("gridOperations.jl")
include("runner.jl")

end
