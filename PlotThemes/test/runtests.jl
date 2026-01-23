using PlotThemes
using Test, PlotUtils

@testset "basics" begin
    @test :sand ∈ keys(PlotThemes._themes)

    palette = theme_palette(:wong)
    @test palette isa ColorPalette

    thm = PlotTheme(PlotThemes._dark; palette)
    @test thm isa PlotTheme

    add_theme(:custom, thm)
    @test theme_palette(:custom) == palette
end