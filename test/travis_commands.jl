Pkg.clone("ImageMagick")
Pkg.build("ImageMagick")

Pkg.clone("GR")
Pkg.build("GR")

Pkg.clone("https://github.com/JuliaPlots/PlotReferenceImages.jl.git")

# Pkg.clone("https://github.com/JuliaStats/KernelDensity.jl.git")

Pkg.clone("StatPlots")

# Pkg.clone("https://github.com/JunoLab/Blink.jl.git")
# Pkg.build("Blink")
# import Blink
# Blink.AtomShell.install()
# Pkg.clone("https://github.com/spencerlyon2/PlotlyJS.jl.git")

# Pkg.checkout("RecipesBase")
Pkg.clone("VisualRegressionTests")

ENV["PYTHON"] = ""
Pkg.add("PyPlot")
Pkg.build("PyPlot")

Pkg.test("Plots"; coverage=false)
