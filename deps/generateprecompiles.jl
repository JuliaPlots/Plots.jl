# To figure out what should be precompiled, run this script, then move
# precompile_Plots.jl in precompiles_path (see below) to src/precompile.jl

# This script works by using SnoopCompile to log compilations that take place
# while running the examples on the GR backend. So SnoopCompile must be
# installed, and StatsPlots, RDatasets, and FileIO are also required for
# certain examples.

# If precompilation fails with an UndefVarError for a module, probably what is
# happening is that the module appears in the precompile statements, but is
# only visible to one of Plots' dependencies, and not Plots itself. Adding the
# module to the blacklist below will remove these precompile statements.

# Anonymous functions may appear in precompile statements as functions with
# hashes in their name. Those of the form "#something##kw" have to do with
# compiling functions with keyword arguments, and are named reproducibly, so
# can be kept. Others generally will not work. Currently, SnoopCompile includes
# some anonymous functions that not reproducible, but SnoopCompile PR #30
# (which looks about to be merged) will ensure that anonymous functions are
# actually defined before attempting to precompile them. Alternatively, we can
# keep only the keyword argument related anonymous functions by changing the
# regex that SnoopCompile uses to detect anonymous functions to
# r"#{1,2}[^\"#]+#{1,2}\d+" (see anonrex in SnoopCompile.jl). To exclude all
# precompile statements involving anonymous functions, "#" can also be added to
# the blacklist below.

using SnoopCompile

project_flag = string("--project=", joinpath(homedir(), ".julia", "dev", "Plots"))
log_path = joinpath(tempdir(), "compiles.log")
precompiles_path = joinpath(tempdir(), "precompile")

# run examples with GR backend, logging what needs to be compiled
SnoopCompile.@snoopc project_flag log_path begin
    using Plots
    Plots.test_examples(:gr)
    Plots.test_examples(:plotly, skip = Plots._backend_skips[:plotly])
end

# precompile calls containing the following strings are dropped
blacklist = [
    # functions defined in examples
    "PlotExampleModule",
    # the following are not visible to Plots, only its dependencies
    "CategoricalArrays",
    "FixedPointNumbers",
    "SparseArrays",
    r"#{1,2}[^\"#]+#{1,2}\d+",
]

data = SnoopCompile.read(log_path)
pc = SnoopCompile.parcel(reverse!(data[2]), blacklist=blacklist)
SnoopCompile.write(precompiles_path, pc)
