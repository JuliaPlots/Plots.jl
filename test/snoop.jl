import SnoopCompile

### Log the compiles
# This only needs to be run once (to generate "/tmp/plots_compiles.csv")

# SnoopCompile.@snoop "/tmp/plots_compiles.csv" begin
#     include(Pkg.dir("Plots", "test","runtests.jl"))
# end

# ----------------------------------------------------------

### Parse the compiles and generate precompilation scripts
# This can be run repeatedly to tweak the scripts

# IMPORTANT: we must have the module(s) defined for the parcelation
# step, otherwise we will get no precompiles for the Plots module
using Plots

data = SnoopCompile.read("/tmp/plots_compiles.csv")

# The Plots tests are run inside a module PlotsTest, so all
# the precompiles get credited to PlotsTest. Credit them to Plots instead.
subst = Dict("PlotsTests"=>"Plots")

# Blacklist helps fix problems:
# - MIME uses type-parameters with symbols like :image/png, which is
#   not parseable
blacklist = ["MIME"]

# Use these two lines if you want to create precompile functions for
# individual packages
pc, discards = SnoopCompile.parcel(data[end:-1:1,2], subst=subst, blacklist=blacklist)
SnoopCompile.write("/tmp/precompile", pc)

pdir = Pkg.dir("Plots")
run(`cp /tmp/precompile/precompile_Plots.jl $pdir/src/precompile.jl`)
