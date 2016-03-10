
supportedAxes(::PlottingPackage) = [:left]
supportedTypes(::PlottingPackage) = []
supportedStyles(::PlottingPackage) = [:solid]
supportedMarkers(::PlottingPackage) = [:none]
supportedScales(::PlottingPackage) = [:identity]
subplotSupported(::PlottingPackage) = false
stringsSupported(::PlottingPackage) = false

supportedAxes() = supportedAxes(backend())
supportedTypes() = supportedTypes(backend())
supportedStyles() = supportedStyles(backend())
supportedMarkers() = supportedMarkers(backend())
supportedScales() = supportedScales(backend())
subplotSupported() = subplotSupported(backend())
stringsSupported() = stringsSupported(backend())


# --------------------------------------------------------------------------------------


supportedArgs(::GadflyPackage) = [
    :annotation,
    # :axis,
    :background_color,
    :linecolor,
    :color_palette,
    :fillrange,
    :fillcolor,
    :fillalpha,
    :foreground_color,
    :group,
    :label,
    :layout,
    :legend,
    :colorbar,
    :linestyle,
    :linetype,
    :linewidth,
    :linealpha,
    :markershape,
    :markercolor,
    :markersize,
    :markeralpha,
    :markerstrokewidth,
    :markerstrokecolor,
    :markerstrokealpha,
    # :markerstrokestyle,
    :n,
    :nbins,
    :nc,
    :nr,
    # :pos,
    :smooth,
    :show,
    :size,
    :title,
    :windowtitle,
    :x,
    :xlabel,
    :xlims,
    :xticks,
    :y,
    :ylabel,
    :ylims,
    # :yrightlabel,
    :yticks,
    :xscale,
    :yscale,
    :xflip,
    :yflip,
    :z,
    :zcolor,
    :tickfont,
    :guidefont,
    :legendfont,
    :grid,
    # :surface,
    :levels,
  ]
supportedAxes(::GadflyPackage) = [:auto, :left]
supportedTypes(::GadflyPackage) = [:none, :line, :path, :steppre, :steppost, :sticks,
                                   :scatter, :hist2d, :hexbin, :hist, :bar,
                                   :hline, :vline, :contour]
supportedStyles(::GadflyPackage) = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]
supportedMarkers(::GadflyPackage) = vcat(_allMarkers, Shape)
supportedScales(::GadflyPackage) = [:identity, :ln, :log2, :log10, :asinh, :sqrt]
subplotSupported(::GadflyPackage) = true


# --------------------------------------------------------------------------------------


supportedArgs(::ImmersePackage) = supportedArgs(GadflyPackage())
supportedAxes(::ImmersePackage) = supportedAxes(GadflyPackage())
supportedTypes(::ImmersePackage) = supportedTypes(GadflyPackage())
supportedStyles(::ImmersePackage) = supportedStyles(GadflyPackage())
supportedMarkers(::ImmersePackage) = supportedMarkers(GadflyPackage())
supportedScales(::ImmersePackage) = supportedScales(GadflyPackage())
subplotSupported(::ImmersePackage) = true

# --------------------------------------------------------------------------------------



supportedArgs(::PyPlotPackage) = [
    :annotation,
    :axis,
    :background_color,
    :linecolor,
    :color_palette,
    :fillrange,
    :fillcolor,
    :foreground_color,
    :group,
    :label,
    :layout,
    :legend,
    :colorbar,
    :linestyle,
    :linetype,
    :linewidth,
    :markershape,
    :markercolor,
    :markersize,
    :markerstrokewidth,
    :markerstrokecolor,
    :markerstrokealpha,
    # :markerstrokestyle,
    :n,
    :nbins,
    :nc,
    :nr,
    # :pos,
    :smooth,
    # :ribbon,
    :show,
    :size,
    :title,
    :windowtitle,
    :x,
    :xlabel,
    :xlims,
    :xticks,
    :y,
    :ylabel,
    :ylims,
    :yrightlabel,
    :yticks,
    :xscale,
    :yscale,
    :xflip,
    :yflip,
    :z,
    :zcolor,  # only supported for scatter/scatter3d
    :tickfont,
    :guidefont,
    :legendfont,
    :grid,
    # :surface,
    :levels,
    :fillalpha,
    :linealpha,
    :markeralpha,
    :overwrite_figure,
  ]
supportedAxes(::PyPlotPackage) = _allAxes
supportedTypes(::PyPlotPackage) = [:none, :line, :path, :steppre, :steppost, #:sticks,
                                   :scatter, :hist2d, :hexbin, :hist, :density, :bar,
                                   :hline, :vline, :contour, :path3d, :scatter3d, :surface, :wireframe, :heatmap]
supportedStyles(::PyPlotPackage) = [:auto, :solid, :dash, :dot, :dashdot]
# supportedMarkers(::PyPlotPackage) = [:none, :auto, :rect, :ellipse, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star5, :hexagon]
supportedMarkers(::PyPlotPackage) = vcat(_allMarkers, Shape)
supportedScales(::PyPlotPackage) = [:identity, :ln, :log2, :log10]
subplotSupported(::PyPlotPackage) = true


# --------------------------------------------------------------------------------------



supportedArgs(::GRPackage) = [
    :annotation,
    :axis,
    :background_color,
    :linecolor,
    :color_palette,
    :fillrange,
    :fillcolor,
    :foreground_color,
    :group,
    :label,
    :layout,
    :legend,
    :colorbar,
    :linestyle,
    :linetype,
    :linewidth,
    :markershape,
    :markercolor,
    :markersize,
    :markerstrokewidth,
    :markerstrokecolor,
    # :markerstrokestyle,
    :n,
    :nbins,
    :nc,
    :nr,
    # :pos,
    :smooth,
    # :ribbon,
    :show,
    :size,
    :title,
    :windowtitle,
    :x,
    :xlabel,
    :xlims,
    :xticks,
    :y,
    :ylabel,
    :ylims,
    :yrightlabel,
    :yticks,
    :xscale,
    :yscale,
    :xflip,
    :yflip,
    :z,
    :zcolor,  # only supported for scatter/scatter3d
    :tickfont,
    :guidefont,
    :legendfont,
    :grid,
    # :surface,
    :nlevels,
    :fillalpha,
    :linealpha,
    :markeralpha,
  ]
supportedAxes(::GRPackage) = _allAxes
supportedTypes(::GRPackage) = [:none, :line, :path, :steppre, :steppost, :sticks,
                               :scatter, :hist2d, :hexbin, :hist, :density, :bar,
                               :hline, :vline, :contour, :path3d, :scatter3d, :surface,
                               :wireframe, :ohlc, :pie]
supportedStyles(::GRPackage) = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]
supportedMarkers(::GRPackage) = vcat(_allMarkers, Shape)
supportedScales(::GRPackage) = [:identity, :log10]
subplotSupported(::GRPackage) = true


# --------------------------------------------------------------------------------------



supportedArgs(::QwtPackage) = [
    :annotation,
    # :args,
    :axis,
    :background_color,
    :linecolor,
    :color_palette,
    :fillrange,
    :fillcolor,
    :foreground_color,
    :group,
    # :heatmap_c,
    # :kwargs,
    :label,
    :layout,
    :legend,
    :linestyle,
    :linetype,
    :linewidth,
    :markershape,
    :markercolor,
    :markersize,
    # :markerstrokewidth,
    # :markerstrokecolor,
    # :markerstrokestyle,
    :n,
    :nbins,
    :nc,
    :nr,
    :pos,
    :smooth,
    # :ribbon,
    :show,
    :size,
    :title,
    :windowtitle,
    :x,
    :xlabel,
    :xlims,
    :xticks,
    :y,
    :ylabel,
    :ylims,
    :yrightlabel,
    :yticks,
    :xscale,
    :yscale,
    # :xflip,
    # :yflip,
    # :z,
  ]
supportedTypes(::QwtPackage) = [:none, :line, :path, :steppre, :steppost, :sticks, :scatter, :hist2d, :hexbin, :hist, :bar, :hline, :vline]
supportedMarkers(::QwtPackage) = [:none, :auto, :rect, :ellipse, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star5, :star8, :hexagon]
supportedScales(::QwtPackage) = [:identity, :log10]
subplotSupported(::QwtPackage) = true


# --------------------------------------------------------------------------------------


supportedArgs(::UnicodePlotsPackage) = [
    # :annotation,
    # :args,
    # :axis,
    # :background_color,
    # :linecolor,
    # :fill,
    # :foreground_color,
    :group,
    # :heatmap_c,
    # :kwargs,
    :label,
    # :layout,
    :legend,
    :linestyle,
    :linetype,
    # :linewidth,
    :markershape,
    # :markercolor,
    # :markersize,
    # :markerstrokewidth,
    # :markerstrokecolor,
    # :markerstrokestyle,
    # :n,
    :nbins,
    # :nc,
    # :nr,
    # :pos,
    # :reg,
    # :ribbon,
    :show,
    :size,
    :title,
    :windowtitle,
    :x,
    :xlabel,
    :xlims,
    # :xticks,
    :y,
    :ylabel,
    :ylims,
    # :yrightlabel,
    # :yticks,
    # :xscale,
    # :yscale,
    # :xflip,
    # :yflip,
    # :z,
  ]
supportedAxes(::UnicodePlotsPackage) = [:auto, :left]
supportedTypes(::UnicodePlotsPackage) = [:none, :line, :path, :steppre, :steppost, :sticks, :scatter, :hist2d, :hexbin, :hist, :bar, :hline, :vline]
supportedStyles(::UnicodePlotsPackage) = [:auto, :solid]
supportedMarkers(::UnicodePlotsPackage) = [:none, :auto, :ellipse]
supportedScales(::UnicodePlotsPackage) = [:identity]
subplotSupported(::UnicodePlotsPackage) = true




# --------------------------------------------------------------------------------------


supportedArgs(::WinstonPackage) = [
    :annotation,
    # :args,
    # :axis,
    # :background_color,
    :linecolor,
    :color_palette,
    :fillrange,
    :fillcolor,
    # :foreground_color,
    :group,
    # :heatmap_c,
    # :kwargs,
    :label,
    # :layout,
    :legend,
    :linestyle,
    :linetype,
    :linewidth,
    :markershape,
    :markercolor,
    :markersize,
    # :markerstrokewidth,
    # :markerstrokecolor,
    # :markerstrokestyle,
    # :n,
    :nbins,
    # :nc,
    # :nr,
    # :pos,
    :smooth,
    # :ribbon,
    :show,
    :size,
    :title,
    :windowtitle,
    :x,
    :xlabel,
    :xlims,
    # :xticks,
    :y,
    :ylabel,
    :ylims,
    # :yrightlabel,
    # :yticks,
    :xscale,
    :yscale,
    # :xflip,
    # :yflip,
    # :z,
  ]
supportedAxes(::WinstonPackage) = [:auto, :left]
supportedTypes(::WinstonPackage) = [:none, :line, :path, :sticks, :scatter, :hist, :bar]
supportedStyles(::WinstonPackage) = [:auto, :solid, :dash, :dot, :dashdot]
supportedMarkers(::WinstonPackage) = [:none, :auto, :rect, :ellipse, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star5]
supportedScales(::WinstonPackage) = [:identity, :log10]
subplotSupported(::WinstonPackage) = false


# --------------------------------------------------------------------------------------



supportedArgs(::BokehPackage) = [
    # :annotation,
    # :axis,
    # :background_color,
    :linecolor,
    # :color_palette,
    # :fillrange,
    # :fillcolor,
    # :fillalpha,
    # :foreground_color,
    :group,
    # :label,
    # :layout,
    # :legend,
    :linestyle,
    :linetype,
    :linewidth,
    # :linealpha,
    :markershape,
    :markercolor,
    :markersize,
    # :markeralpha,
    # :markerstrokewidth,
    # :markerstrokecolor,
    # :markerstrokestyle,
    # :n,
    # :nbins,
    # :nc,
    # :nr,
    # :pos,
    # :smooth,
    # :show,
    :size,
    :title,
    # :windowtitle,
    :x,
    # :xlabel,
    # :xlims,
    # :xticks,
    :y,
    # :ylabel,
    # :ylims,
    # :yrightlabel,
    # :yticks,
    # :xscale,
    # :yscale,
    # :xflip,
    # :yflip,
    # :z,
    # :tickfont,
    # :guidefont,
    # :legendfont,
    # :grid,
    # :surface,
    # :levels,
  ]
supportedAxes(::BokehPackage) = [:auto, :left]
supportedTypes(::BokehPackage) = [:none, :path, :scatter] #,:steppre, :steppost, :sticks, :hist2d, :hexbin, :hist, :bar, :hline, :vline, :contour]
supportedStyles(::BokehPackage) = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]
supportedMarkers(::BokehPackage) = [:none, :auto, :ellipse, :rect, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star5] #vcat(_allMarkers, Shape)
supportedScales(::BokehPackage) = [:identity, :ln] #, :ln, :log2, :log10, :asinh, :sqrt]
subplotSupported(::BokehPackage) = false


# --------------------------------------------------------------------------------------

supportedArgs(::PlotlyPackage) = [
    :annotation,
    # :axis,
    :background_color,
    :color_palette,
    :fillrange,
    :fillcolor,
    :fillalpha,
    :foreground_color,
    :group,
    :label,
    :layout,
    :legend,
    :linecolor,
    :linestyle,
    :linetype,
    :linewidth,
    :linealpha,
    :markershape,
    :markercolor,
    :markersize,
    :markeralpha,
    :markerstrokewidth,
    :markerstrokecolor,
    :markerstrokestyle,
    :n,
    :nbins,
    :nc,
    :nr,
    # :pos,
    # :smooth,
    :show,
    :size,
    :title,
    :windowtitle,
    :x,
    :xlabel,
    :xlims,
    :xticks,
    :y,
    :ylabel,
    :ylims,
    # :yrightlabel,
    :yticks,
    :xscale,
    :yscale,
    :xflip,
    :yflip,
    :z,
    :zcolor,
    :tickfont,
    :guidefont,
    :legendfont,
    :grid,
    :levels,
  ]
supportedAxes(::PlotlyPackage) = [:auto, :left]
supportedTypes(::PlotlyPackage) = [:none, :line, :path, :scatter, :steppre, :steppost,
                                   :hist2d, :hist, :density, :bar, :contour, :surface, :path3d, :scatter3d,
                                   :pie, :heatmap] #,, :sticks, :hexbin, :hline, :vline]
supportedStyles(::PlotlyPackage) = [:auto, :solid, :dash, :dot, :dashdot]
supportedMarkers(::PlotlyPackage) = [:none, :auto, :ellipse, :rect, :diamond, :utriangle, :dtriangle, :cross, :xcross,
                                     :pentagon, :hexagon, :octagon, :vline, :hline] #vcat(_allMarkers, Shape)
supportedScales(::PlotlyPackage) = [:identity, :log10] #, :ln, :log2, :log10, :asinh, :sqrt]
subplotSupported(::PlotlyPackage) = true
stringsSupported(::PlotlyPackage) = true


# --------------------------------------------------------------------------------------

supportedArgs(::PlotlyJSPackage) = [
    :annotation,
    # :axis,
    :background_color,
    :color_palette,
    :fillrange,
    :fillcolor,
    :fillalpha,
    :foreground_color,
    :group,
    :label,
    :layout,
    :legend,
    :linecolor,
    :linestyle,
    :linetype,
    :linewidth,
    :linealpha,
    :markershape,
    :markercolor,
    :markersize,
    :markeralpha,
    :markerstrokewidth,
    :markerstrokecolor,
    :markerstrokestyle,
    :n,
    :nbins,
    :nc,
    :nr,
    # :pos,
    # :smooth,
    :show,
    :size,
    :title,
    :windowtitle,
    :x,
    :xlabel,
    :xlims,
    :xticks,
    :y,
    :ylabel,
    :ylims,
    # :yrightlabel,
    :yticks,
    :xscale,
    :yscale,
    :xflip,
    :yflip,
    :z,
    :zcolor,
    :tickfont,
    :guidefont,
    :legendfont,
    :grid,
    :levels,
  ]
supportedAxes(::PlotlyJSPackage) = [:auto, :left]
supportedTypes(::PlotlyJSPackage) = [:none, :line, :path, :scatter, :steppre, :steppost,
                                   :hist2d, :hist, :density, :bar, :contour, :surface, :path3d, :scatter3d,
                                   :pie, :heatmap] #,, :sticks, :hexbin, :hline, :vline]
supportedStyles(::PlotlyJSPackage) = [:auto, :solid, :dash, :dot, :dashdot]
supportedMarkers(::PlotlyJSPackage) = [:none, :auto, :ellipse, :rect, :diamond, :utriangle, :dtriangle, :cross, :xcross,
                                     :pentagon, :hexagon, :octagon, :vline, :hline] #vcat(_allMarkers, Shape)
supportedScales(::PlotlyJSPackage) = [:identity, :log10] #, :ln, :log2, :log10, :asinh, :sqrt]
subplotSupported(::PlotlyJSPackage) = true
stringsSupported(::PlotlyJSPackage) = true

# --------------------------------------------------------------------------------------

supportedArgs(::GLVisualizePackage) = [
    # :annotation,
    # :axis,
    # :background_color,
    # :color_palette,
    # :fillrange,
    # :fillcolor,
    # :fillalpha,
    # :foreground_color,
    # :group,
    # :label,
    # :layout,
    # :legend,
    # :linecolor,
    # :linestyle,
    # :linetype,
    # :linewidth,
    # :linealpha,
    # :markershape,
    # :markercolor,
    # :markersize,
    # :markeralpha,
    # :markerstrokewidth,
    # :markerstrokecolor,
    # :markerstrokestyle,
    # :n,
    # :nbins,
    # :nc,
    # :nr,
    # :pos,
    # :smooth,
    # :show,
    # :size,
    # :title,
    # :windowtitle,
    # :x,
    # :xlabel,
    # :xlims,
    # :xticks,
    # :y,
    # :ylabel,
    # :ylims,
    # :yrightlabel,
    # :yticks,
    # :xscale,
    # :yscale,
    # :xflip,
    # :yflip,
    # :z,
    # :tickfont,
    # :guidefont,
    # :legendfont,
    # :grid,
    # :surface
    # :levels,
  ]
supportedAxes(::GLVisualizePackage) = [:auto, :left]
supportedTypes(::GLVisualizePackage) = [:contour] #, :path, :scatter ,:steppre, :steppost, :sticks, :hist2d, :hexbin, :hist, :bar, :hline, :vline, :contour]
supportedStyles(::GLVisualizePackage) = [:auto, :solid] #, :dash, :dot, :dashdot, :dashdotdot]
supportedMarkers(::GLVisualizePackage) = [:none, :auto, :ellipse] #, :rect, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star5] #vcat(_allMarkers, Shape)
supportedScales(::GLVisualizePackage) = [:identity] #, :log, :log2, :log10, :asinh, :sqrt]
subplotSupported(::GLVisualizePackage) = false

# --------------------------------------------------------------------------------------

supportedArgs(::PGFPlotsPackage) = [
    # :annotation,
    # :axis,
    # :background_color,
    # :color_palette,
    # :fillrange,
    # :fillcolor,
    # :fillalpha,
    # :foreground_color,
    # :group,
    # :label,
    # :layout,
    # :legend,
    # :linecolor,
    # :linestyle,
    # :linetype,
    # :linewidth,
    # :linealpha,
    # :markershape,
    # :markercolor,
    # :markersize,
    # :markeralpha,
    # :markerstrokewidth,
    # :markerstrokecolor,
    # :markerstrokestyle,
    # :n,
    # :nbins,
    # :nc,
    # :nr,
    # :pos,
    # :smooth,
    # :show,
    # :size,
    # :title,
    # :windowtitle,
    # :x,
    # :xlabel,
    # :xlims,
    # :xticks,
    # :y,
    # :ylabel,
    # :ylims,
    # :yrightlabel,
    # :yticks,
    # :xscale,
    # :yscale,
    # :xflip,
    # :yflip,
    # :z,
    # :tickfont,
    # :guidefont,
    # :legendfont,
    # :grid,
    # :surface
    # :levels,
  ]
supportedAxes(::PGFPlotsPackage) = [:auto, :left]
supportedTypes(::PGFPlotsPackage) = [:contour] #, :path, :scatter ,:steppre, :steppost, :sticks, :hist2d, :hexbin, :hist, :bar, :hline, :vline, :contour]
supportedStyles(::PGFPlotsPackage) = [:auto, :solid] #, :dash, :dot, :dashdot, :dashdotdot]
supportedMarkers(::PGFPlotsPackage) = [:none, :auto, :ellipse] #, :rect, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star5] #vcat(_allMarkers, Shape)
supportedScales(::PGFPlotsPackage) = [:identity] #, :log, :log2, :log10, :asinh, :sqrt]
subplotSupported(::PGFPlotsPackage) = false

