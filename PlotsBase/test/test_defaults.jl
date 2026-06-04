const PLOTSBASE_DEFAULTS = Dict(:theme => :wong2, :fontfamily => :palantino)
PlotsBase._plots_theme_defaults()

@testset "Loading theme" begin
    pl = plot(1:5)
    @test pl[1][1][:seriescolor] == RGBA(colorant"black")
    @test PlotsBase.guidefont(pl[1][:xaxis]).family == "palantino"
end

empty!(PLOTSBASE_DEFAULTS)
PlotsBase._plots_theme_defaults()

@testset "default" begin
    default(fillrange = 0)
    @test PlotsBase._series_defaults[:fillrange] == 0
    pl = plot(1:5)
    @test pl[1][1][:fillrange] == 0
    @test_nowarn default(legendfont = font(5))
    pl = plot(1:5)
    @test pl[1][:legend_font_pointsize] == 5
    default()
end

@testset "Legend defaults" begin
    pl = plot()
    @test pl[1][:legend_font_family] == "sans-serif"
    @test pl[1][:legend_font_pointsize] == 8
    @test pl[1][:legend_font_halign] ≡ :hcenter
    @test pl[1][:legend_font_valign] ≡ :vcenter
    @test pl[1][:legend_font_rotation] == 0.0
    @test pl[1][:legend_font_color] == RGB{Colors.N0f8}(0.0, 0.0, 0.0)
    @test pl[1][:legend_position] ≡ :best
    @test pl[1][:legend_title] ≡ nothing
    @test pl[1][:legend_title_font_family] == "sans-serif"
    @test pl[1][:legend_title_font_pointsize] == 11
    @test pl[1][:legend_title_font_halign] ≡ :hcenter
    @test pl[1][:legend_title_font_valign] ≡ :vcenter
    @test pl[1][:legend_title_font_rotation] == 0.0
    @test pl[1][:legend_title_font_color] == RGB{Colors.N0f8}(0.0, 0.0, 0.0)
    @test pl[1][:legend_background_color] == RGBA{Float64}(1.0, 1.0, 1.0, 1.0)
    @test pl[1][:legend_foreground_color] == RGB{Colors.N0f8}(0.0, 0.0, 0.0)
end

@testset "Legend API" begin
    pl = plot(;
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
    @test pl[1][:legend_font_family] == "serif"
    @test pl[1][:legend_font_pointsize] == 12
    @test pl[1][:legend_font_halign] ≡ :left
    @test pl[1][:legend_font_valign] ≡ :top
    @test pl[1][:legend_font_rotation] == 1.0
    @test pl[1][:legend_font_color] ≡ :red
    @test pl[1][:legend_position] ≡ :outertopleft
    @test pl[1][:legend_title] == "The legend"
    @test pl[1][:legend_title_font_family] == "helvetica"
    @test pl[1][:legend_title_font_pointsize] == 3
    @test pl[1][:legend_title_font_halign] ≡ :right
    @test pl[1][:legend_title_font_valign] ≡ :bottom
    @test pl[1][:legend_title_font_rotation] == -5.2
    @test pl[1][:legend_title_font_color] ≡ :blue
    @test pl[1][:legend_background_color] == RGBA{Float64}(0.0, 1.0, 1.0, 1.0)
    @test pl[1][:legend_foreground_color] ==
        RGBA{Float64}(0.0, 0.5019607843137255, 0.0, 1.0)

    #remember settings
    plot(legend_font_pointsize = 20)
    sp = plot!(label = "R")[1]
    @test PlotsBase.legendfont(sp).pointsize == 20

    #setting whole font
    sp = plot(
        1:5,
        legendfont = font(12),
        legend_font_halign = :left,
        foreground_color_subplot = :red,
    )[1]
    @test PlotsBase.legendfont(sp).pointsize == 12
    @test PlotsBase.legendfont(sp).halign ≡ :left
    # match mechanism
    @test sp[:legend_font_color] == colorant"black"
    @test PlotsBase.legendfont(sp).color == colorant"black"
    @test sp[:foreground_color_subplot] == RGBA(colorant"red")

    # magic invocation
    @test_nowarn sp = plot(; legendfont = 12)[1]
    @test sp[:legend_font_pointsize] == 12
    @test PlotsBase.legendfont(sp).pointsize == 12
end

@testset "Colorbar defaults and API" begin
    sp = plot()[1]
    @test sp[:colorbar_tickfontfamily] == "sans-serif"
    @test sp[:colorbar_tickfontsize] == 8
    @test sp[:colorbar_tickfonthalign] ≡ :hcenter
    @test sp[:colorbar_tickfontvalign] ≡ :vcenter
    @test sp[:colorbar_tickfontrotation] == 0.0
    @test sp[:colorbar_tickfontcolor] == RGB{Colors.N0f8}(0.0, 0.0, 0.0)
    @test sp[:colorbar_tickcolor] == RGB{Colors.N0f8}(0.0, 0.0, 0.0)
    @test sp[:colorbar_ticklinewidth] == 1
    @test sp[:colorbar_bordercolor] == RGB{Colors.N0f8}(0.0, 0.0, 0.0)
    @test sp[:colorbar_borderlinewidth] == 0
    @test sp[:colorbar_width] ≡ :auto
    @test sp[:colorbar_height] ≡ :auto
    @test PlotsBase.colorbartickfont(sp).pointsize == 8
    @test PlotsBase.colorbartickfont(sp).halign ≡ :hcenter

    sp = heatmap(
        reshape(1:4, 2, 2);
        cb_tickfont = (10, :red, 30.0),
        cb_tickcolor = :blue,
        cbar_ticklinewidth = 2,
        colorkey_bordercolor = :green,
        cb_borderlinewidth = 3,
        cbar_width = 0.04,
        colorkey_height = 0.7,
    )[1]
    @test sp[:colorbar_tickfontsize] == 10
    @test sp[:colorbar_tickfontcolor] == colorant"red"
    @test sp[:colorbar_tickfontrotation] == 30.0
    @test PlotsBase.plot_color(sp[:colorbar_tickcolor]) == RGBA(colorant"blue")
    @test sp[:colorbar_ticklinewidth] == 2
    @test PlotsBase.plot_color(sp[:colorbar_bordercolor]) == RGBA(colorant"green")
    @test sp[:colorbar_borderlinewidth] == 3
    @test sp[:colorbar_width] == 0.04
    @test sp[:colorbar_height] == 0.7

    @test_nowarn sp = heatmap(reshape(1:4, 2, 2); colorbar_tickfont = 12)[1]
    @test PlotsBase.colorbartickfont(sp).pointsize == 12
end
