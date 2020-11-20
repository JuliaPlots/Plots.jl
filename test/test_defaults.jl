using Plots, Test, Colors

const PLOTS_DEFAULTS = Dict(:theme => :wong2, :fontfamily => :palantino)
Plots.__init__()

@testset "Loading theme" begin
    pl = plot(1:5)
    @test pl[1][1][:seriescolor] == RGBA(colorant"black")
    @test guidefont(pl[1][:xaxis]).family == "palantino"
end

empty!(PLOTS_DEFAULTS)
Plots.__init__()

@testset "Legend defaults" begin
    p = plot()
    @test p[1][:legend_font_family] == "sans-serif"
    @test p[1][:legend_font_pointsize] == 8
    @test p[1][:legend_font_halign] == :hcenter
    @test p[1][:legend_font_valign] == :vcenter
    @test p[1][:legend_font_rotation] == 0.0
    @test p[1][:legend_font_color] == RGB{Colors.N0f8}(0.0,0.0,0.0)
    @test p[1][:legend_position] == :best
    @test p[1][:legend_title] == nothing
    @test p[1][:legend_title_font_family] == "sans-serif"
    @test p[1][:legend_title_font_pointsize] == 11
    @test p[1][:legend_title_font_halign] == :hcenter
    @test p[1][:legend_title_font_valign] == :vcenter
    @test p[1][:legend_title_font_rotation] == 0.0
    @test p[1][:legend_title_font_color] == RGB{Colors.N0f8}(0.0,0.0,0.0)
    @test p[1][:legend_background_color] == RGBA{Float64}(1.0,1.0,1.0,1.0)
    @test p[1][:legend_foreground_color] == RGB{Colors.N0f8}(0.0,0.0,0.0)
end # testset

@testset "Legend API" begin
    p = plot(;
        legendfontfamily = "serif",
        legendfontsize = 12,
        legendfonthalign = :left,
        legendfontvalign = :top,
        legendfontrotation = 1,
        legendfontcolor = :red,
        legend = :outertopleft,
        legendtitle = "The legend",
        legendtitlefontfamily = "helvetica",
        legendtitlefontsize = 3,
        legendtitlefonthalign = :right,
        legendtitlefontvalign = :bottom,
        legendtitlefontrotation = -5.2,
        legendtitlefontcolor = :blue,
        background_color_legend = :cyan,
        foreground_color_legend = :green,
    )
    @test p[1][:legend_font_family] == "serif"
    @test p[1][:legend_font_pointsize] == 12
    @test p[1][:legend_font_halign] == :left
    @test p[1][:legend_font_valign] == :top
    @test p[1][:legend_font_rotation] == 1.0
    @test_broken p[1][:legend_font_color] == RGB{Colors.N0f8}(1.0,0.0,0.0)
    # FIXME: this doesn't get set
    @test_broken p[1][:legend_position] == :outertopleft
    # FIXME: this doesn't get set
    @test_broken p[1][:legend_title] == "The legend"
    @test p[1][:legend_title_font_family] == "helvetica"
    # FIXME: this doesn't get set
    @test_broken p[1][:legend_title_font_pointsize] == 3
    @test p[1][:legend_title_font_halign] == :right
    @test p[1][:legend_title_font_valign] == :bottom
    @test p[1][:legend_title_font_rotation] == -5.2
    # This currently propagates "blue"
    @test_broken p[1][:legend_title_font_color] == RGB{Colors.N0f8}(0.0,0.0,1.0)
    @test p[1][:legend_background_color] == RGBA{Float64}(0.0,1.0,1.0,1.0)
    @test p[1][:legend_foreground_color] == RGBA{Float64}(0.0,0.5019607843137255,0.0,1.0)
end # testset
