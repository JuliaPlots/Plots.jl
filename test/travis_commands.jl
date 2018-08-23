using Pkg

# need this to use Conda
# ENV["PYTHON"] = ""

Pkg.add([
    PackageSpec("ImageMagick"),
    # PackageSpec("GR"),
    PackageSpec(url="https://github.com/JuliaPlots/PlotReferenceImages.jl.git"),
    PackageSpec("StatPlots"),
    # PackageSpec(url="https://github.com/JuliaStats/KernelDensity.jl.git"),
    PackageSpec(name="PlotUtils", rev="master"),
    PackageSpec(name="RecipesBase", rev="master"),
    # PackageSpec(name="Blink", rev="master"),
    # PackageSpec(name="Rsvg", rev="master"),
    # PackageSpec(name="PlotlyJS", rev="master"),
    # PackageSpec(name="VisualRegressionTests", rev="master"),
    # PackageSpec("PyPlot"),
    # PackageSpec("InspectDR"),
])

Pkg.build("ImageMagick")
# Pkg.build("GR")
# Pkg.build("Blink")
# import Blink
# Blink.AtomShell.install()
# Pkg.build("PyPlot")

Pkg.test("Plots"; coverage=false)
