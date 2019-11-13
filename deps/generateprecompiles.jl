# To figure out what should be precompiled, run this script, then move
# precompile_Plots.jl in precompiles_path (see below) to src/precompile.jl

using SnoopCompile

log_path = joinpath(tempdir(), "compiles.log")
precompiles_path = joinpath(tempdir(), "precompile")

# run examples with GR backend, logging what needs to be compiled
SnoopCompile.@snoopc log_path begin
    using Plots
    Plots.test_examples(:gr, disp=true)
end

# precompile calls containing the following strings are dropped
blacklist = [
    # functions defined in examples
    "PlotExampleModule",
    # the following are not visible to Plots, only its dependencies
    "CategoricalArrays",
    "FixedPointNumbers",
    "SparseArrays"
]

data = SnoopCompile.read(log_path)
pc = SnoopCompile.parcel(reverse!(data[2]), blacklist=blacklist)
SnoopCompile.write(precompiles_path, pc)
