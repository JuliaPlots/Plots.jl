# This script works around some problems with
# the automated testing infrastructure

import Pkg
Pkg.add("ImageMagick")
Pkg.build("ImageMagick")

if Sys.isapple()
    Pkg.add("QuartzImageIO")
end
Pkg.add("VisualRegressionTests")
Pkg.add("UnicodePlots")

# GR is currently a standard dep of Plots
# Pkg.develop("GR")
# Pkg.build("GR")

# Pkg.clone("https://github.com/JuliaStats/KernelDensity.jl.git")

# FIXME: pending working dependencies
# Pkg.develop("StatPlots")
# Pkg.add("RDatasets")

Pkg.develop("RecipesBase")
Pkg.develop("ColorVectorSpace")

Pkg.add("https://github.com/JuliaPlots/PlotReferenceImages.jl.git")

# Pkg.clone("Blink")
# Pkg.build("Blink")
# import Blink
# Blink.AtomShell.install()
# Pkg.add("Rsvg")
# Pkg.add("PlotlyJS")

# Pkg.checkout("RecipesBase")
# Pkg.clone("VisualRegressionTests")

# uncomment the following if CI tests pyplot backend:

# need this to use Conda
# ENV["PYTHON"] = ""
# Pkg.add("PyPlot")
# Pkg.build("PyPlot")

# Pkg.add("InspectDR")

# We want to run in the env we just set up, so we can't use Pkg.test()
# Pkg.test("Plots"; coverage=false)
include("runtests.jl")
