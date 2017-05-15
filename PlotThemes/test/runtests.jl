using PlotThemes
using Base.Test

@test in(:sand, keys(PlotThemes._themes))
@test in(:sand_grad, PlotUtils.cgradients(:misc))
