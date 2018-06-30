import Pkg
Pkg.add("ImageMagick")
Pkg.build("ImageMagick")

# Pkg.clone("GR")
# Pkg.build("GR")

# Pkg.clone("https://github.com/JuliaStats/KernelDensity.jl.git")

Pkg.clone("StatPlots")

Pkg.add("PlotUtils")
Pkg.develop("RecipesBase")

# Pkg.clone("Blink")
# Pkg.build("Blink")
# import Blink
# Blink.AtomShell.install()
# Pkg.add("Rsvg")
# Pkg.add("PlotlyJS")

# Pkg.checkout("RecipesBase")
# Pkg.clone("VisualRegressionTests")

# need this to use Conda
ENV["PYTHON"] = ""
Pkg.add("PyPlot")
Pkg.build("PyPlot")

# Pkg.add("InspectDR")

Pkg.test("Plots"; coverage=false)
