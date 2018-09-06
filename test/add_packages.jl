using Pkg

# need this to use Conda
# ENV["PYTHON"] = ""

to_add = [
    # PackageSpec(url="https://github.com/JuliaStats/KernelDensity.jl.git"),
    PackageSpec(name="PlotUtils", rev="master"),
    PackageSpec(name="RecipesBase", rev="master"),
    # PackageSpec(name="Blink", rev="master"),
    # PackageSpec(name="Rsvg", rev="master"),
    # PackageSpec(name="PlotlyJS", rev="master"),
    # PackageSpec(name="VisualRegressionTests", rev="master"),
    # PackageSpec("PyPlot"),
    # PackageSpec("InspectDR"),
]

if isinteractive()
    Pkg.develop(PackageSpec(url="https://github.com/JuliaPlots/PlotReferenceImages.jl.git"))
    append!(to_add, [
        PackageSpec(name="FileIO"),
        PackageSpec(name="ImageMagick"),
        PackageSpec(name="UnicodePlots"),
        PackageSpec(name="VisualRegressionTests"),
        PackageSpec(name="Gtk"),
        # PlotlyJS:
        # PackageSpec(name="PlotlyJS"),
        # PackageSpec(name="Blink"),
        # PackageSpec(name="ORCA"),
        # PyPlot:
        # PackageSpec(name="PyPlot"),
        # PackageSpec(name="PyCall"),
        # PackageSpec(name="LaTeXStrings"),
    ])
else
    push!(to_add, PackageSpec(url="https://github.com/JuliaPlots/PlotReferenceImages.jl.git"))
end

Pkg.add(to_add)

Pkg.build("ImageMagick")
# Pkg.build("GR")
# Pkg.build("Blink")
# import Blink
# Blink.AtomShell.install()
# Pkg.build("PyPlot")
