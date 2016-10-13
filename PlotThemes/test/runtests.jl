using PlotThemes
using Base.Test

@test haskey(PlotThemes._themes, :sand)
@test haskey(PlotUtils._gradients, :sand_grad)
