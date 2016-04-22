
supportedAxes(::AbstractBackend) = [:left]
supportedTypes(::AbstractBackend) = []
supportedStyles(::AbstractBackend) = [:solid]
supportedMarkers(::AbstractBackend) = [:none]
supportedScales(::AbstractBackend) = [:identity]
subplotSupported(::AbstractBackend) = false
stringsSupported(::AbstractBackend) = false

supportedAxes() = supportedAxes(backend())
supportedTypes() = supportedTypes(backend())
supportedStyles() = supportedStyles(backend())
supportedMarkers() = supportedMarkers(backend())
supportedScales() = supportedScales(backend())
subplotSupported() = subplotSupported(backend())
stringsSupported() = stringsSupported(backend())


# --------------------------------------------------------------------------------------


supportedArgs(::GadflyBackend) = [
    :annotation,
    :background_color, :foreground_color, :color_palette,
    :group,
    :label,
    :linetype,
    :linecolor, :linestyle, :linewidth, :linealpha,
    :markershape, :markercolor, :markersize, :markeralpha,
    :markerstrokewidth, :markerstrokecolor, :markerstrokealpha,
    :fillrange, :fillcolor, :fillalpha,
    :nbins,
    :n, :nc, :nr, :layout,
    :smooth,
    :title, :windowtitle, :show, :size,
    :x, :xlabel, :xlims, :xticks, :xscale, :xflip,
    :y, :ylabel, :ylims, :yticks, :yscale, :yflip,
    # :z, :zlabel, :zlims, :zticks, :zscale, :zflip,
    :z,
    :tickfont, :guidefont, :legendfont,
    :grid, :legend, :colorbar,
    :marker_z, :levels,
    :xerror, :yerror,
    :ribbon, :quiver,
    :orientation,
  ]
supportedAxes(::GadflyBackend) = [:auto, :left]
supportedTypes(::GadflyBackend) = [
        :none, :line, :path, :steppre, :steppost, :sticks,
        :scatter, :hist2d, :hexbin, :hist,
        :bar, :box, :violin, :quiver,
        :hline, :vline, :contour, :shape
    ]
supportedStyles(::GadflyBackend) = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]
supportedMarkers(::GadflyBackend) = vcat(_allMarkers, Shape)
supportedScales(::GadflyBackend) = [:identity, :ln, :log2, :log10, :asinh, :sqrt]
subplotSupported(::GadflyBackend) = true


# --------------------------------------------------------------------------------------


supportedArgs(::ImmerseBackend) = supportedArgs(GadflyBackend())
supportedAxes(::ImmerseBackend) = supportedAxes(GadflyBackend())
supportedTypes(::ImmerseBackend) = supportedTypes(GadflyBackend())
supportedStyles(::ImmerseBackend) = supportedStyles(GadflyBackend())
supportedMarkers(::ImmerseBackend) = supportedMarkers(GadflyBackend())
supportedScales(::ImmerseBackend) = supportedScales(GadflyBackend())
subplotSupported(::ImmerseBackend) = true

# --------------------------------------------------------------------------------------



supportedArgs(::PyPlotBackend) = [
    :annotation,
    :background_color, :foreground_color, :color_palette,
    :group,
    :label,
    :linetype,
    :linecolor, :linestyle, :linewidth, :linealpha,
    :markershape, :markercolor, :markersize, :markeralpha,
    :markerstrokewidth, :markerstrokecolor, :markerstrokealpha,
    :fillrange, :fillcolor, :fillalpha,
    :nbins,
    :n, :nc, :nr, :layout,
    :smooth,
    :title, :windowtitle, :show, :size,
    :x, :xlabel, :xlims, :xticks, :xscale, :xflip,
    :y, :ylabel, :ylims, :yticks, :yscale, :yflip,
    :axis, :yrightlabel,
    :z, :zlabel, :zlims, :zticks, :zscale, :zflip,
    :z,
    :tickfont, :guidefont, :legendfont,
    :grid, :legend, :colorbar,
    :marker_z, :levels,
    :xerror, :yerror,
    :ribbon, :quiver,
    :orientation,
    :overwrite_figure,
    :polar,
  ]
supportedAxes(::PyPlotBackend) = _allAxes
supportedTypes(::PyPlotBackend) = [
        :none, :line, :path, :steppre, :steppost, :shape,
        :scatter, :hist2d, :hexbin, :hist, :density,
        :bar, :box, :violin, :quiver,
        :hline, :vline, :heatmap,
        :contour, :path3d, :scatter3d, :surface, :wireframe
    ]
supportedStyles(::PyPlotBackend) = [:auto, :solid, :dash, :dot, :dashdot]
supportedMarkers(::PyPlotBackend) = vcat(_allMarkers, Shape)
supportedScales(::PyPlotBackend) = [:identity, :ln, :log2, :log10]
subplotSupported(::PyPlotBackend) = true


# --------------------------------------------------------------------------------------



supportedArgs(::GRBackend) = [
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
    :marker_z,  # only supported for scatter/scatter3d
    :tickfont,
    :guidefont,
    :legendfont,
    :grid,
    # :surface,
    :nlevels,
    :fillalpha,
    :linealpha,
    :markeralpha,
    :xerror,
    :yerror,
    :ribbon,
    :quiver,
    :orientation,
  ]
supportedAxes(::GRBackend) = _allAxes
supportedTypes(::GRBackend) = [:none, :line, :path, :steppre, :steppost, :sticks,
                               :scatter, :hist2d, :hexbin, :hist, :density, :bar,
                               :hline, :vline, :contour, :heatmap, :path3d, :scatter3d, :surface,
                               :wireframe, :ohlc, :pie]
supportedStyles(::GRBackend) = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]
supportedMarkers(::GRBackend) = vcat(_allMarkers, Shape)
supportedScales(::GRBackend) = [:identity, :log10]
subplotSupported(::GRBackend) = true


# --------------------------------------------------------------------------------------



supportedArgs(::QwtBackend) = [
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
supportedTypes(::QwtBackend) = [:none, :line, :path, :steppre, :steppost, :sticks, :scatter, :hist2d, :hexbin, :hist, :bar, :hline, :vline]
supportedMarkers(::QwtBackend) = [:none, :auto, :rect, :ellipse, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star5, :star8, :hexagon]
supportedScales(::QwtBackend) = [:identity, :log10]
subplotSupported(::QwtBackend) = true


# --------------------------------------------------------------------------------------


supportedArgs(::UnicodePlotsBackend) = [
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
supportedAxes(::UnicodePlotsBackend) = [:auto, :left]
supportedTypes(::UnicodePlotsBackend) = [:none, :line, :path, :steppre, :steppost, :sticks, :scatter, :hist2d, :hexbin, :hist, :bar, :hline, :vline]
supportedStyles(::UnicodePlotsBackend) = [:auto, :solid]
supportedMarkers(::UnicodePlotsBackend) = [:none, :auto, :ellipse]
supportedScales(::UnicodePlotsBackend) = [:identity]
subplotSupported(::UnicodePlotsBackend) = true




# --------------------------------------------------------------------------------------


supportedArgs(::WinstonBackend) = [
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
supportedAxes(::WinstonBackend) = [:auto, :left]
supportedTypes(::WinstonBackend) = [:none, :line, :path, :sticks, :scatter, :hist, :bar]
supportedStyles(::WinstonBackend) = [:auto, :solid, :dash, :dot, :dashdot]
supportedMarkers(::WinstonBackend) = [:none, :auto, :rect, :ellipse, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star5]
supportedScales(::WinstonBackend) = [:identity, :log10]
subplotSupported(::WinstonBackend) = false


# --------------------------------------------------------------------------------------



supportedArgs(::BokehBackend) = [
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
supportedAxes(::BokehBackend) = [:auto, :left]
supportedTypes(::BokehBackend) = [:none, :path, :scatter] #,:steppre, :steppost, :sticks, :hist2d, :hexbin, :hist, :bar, :hline, :vline, :contour]
supportedStyles(::BokehBackend) = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]
supportedMarkers(::BokehBackend) = [:none, :auto, :ellipse, :rect, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star5] #vcat(_allMarkers, Shape)
supportedScales(::BokehBackend) = [:identity, :ln] #, :ln, :log2, :log10, :asinh, :sqrt]
subplotSupported(::BokehBackend) = false


# --------------------------------------------------------------------------------------

supportedArgs(::PlotlyBackend) = [
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
    :marker_z,
    :tickfont,
    :guidefont,
    :legendfont,
    :grid,
    :levels,
    :xerror,
    :yerror,
    :ribbon,
    :quiver,
    :orientation,
    :polar,
  ]
supportedAxes(::PlotlyBackend) = [:auto, :left]
supportedTypes(::PlotlyBackend) = [:none, :line, :path, :scatter, :steppre, :steppost,
                                   :hist2d, :hist, :density, :bar, :contour, :surface, :path3d, :scatter3d,
                                   :pie, :heatmap] #,, :sticks, :hexbin, :hline, :vline]
supportedStyles(::PlotlyBackend) = [:auto, :solid, :dash, :dot, :dashdot]
supportedMarkers(::PlotlyBackend) = [:none, :auto, :ellipse, :rect, :diamond, :utriangle, :dtriangle, :cross, :xcross,
                                     :pentagon, :hexagon, :octagon, :vline, :hline] #vcat(_allMarkers, Shape)
supportedScales(::PlotlyBackend) = [:identity, :log10] #, :ln, :log2, :log10, :asinh, :sqrt]
subplotSupported(::PlotlyBackend) = true
stringsSupported(::PlotlyBackend) = true


# --------------------------------------------------------------------------------------

supportedArgs(::PlotlyJSBackend) = [
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
    :marker_z,
    :tickfont,
    :guidefont,
    :legendfont,
    :grid,
    :levels,
    :xerror,
    :yerror,
    :ribbon,
    :quiver,
    :orientation,
    :polar,
  ]
supportedAxes(::PlotlyJSBackend) = [:auto, :left]
supportedTypes(::PlotlyJSBackend) = [:none, :line, :path, :scatter, :steppre, :steppost,
                                   :hist2d, :hist, :density, :bar, :contour, :surface, :path3d, :scatter3d,
                                   :pie, :heatmap] #,, :sticks, :hexbin, :hline, :vline]
supportedStyles(::PlotlyJSBackend) = [:auto, :solid, :dash, :dot, :dashdot]
supportedMarkers(::PlotlyJSBackend) = [:none, :auto, :ellipse, :rect, :diamond, :utriangle, :dtriangle, :cross, :xcross,
                                     :pentagon, :hexagon, :octagon, :vline, :hline] #vcat(_allMarkers, Shape)
supportedScales(::PlotlyJSBackend) = [:identity, :log10] #, :ln, :log2, :log10, :asinh, :sqrt]
subplotSupported(::PlotlyJSBackend) = true
stringsSupported(::PlotlyJSBackend) = true

# --------------------------------------------------------------------------------------

supportedArgs(::GLVisualizeBackend) = [
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
     :linetype
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
supportedAxes(::GLVisualizeBackend) = [:auto, :left]
supportedTypes(::GLVisualizeBackend) = [:surface] #, :path, :scatter ,:steppre, :steppost, :sticks, :heatmap, :hexbin, :hist, :bar, :hline, :vline, :contour]
supportedStyles(::GLVisualizeBackend) = [:auto, :solid] #, :dash, :dot, :dashdot, :dashdotdot]
supportedMarkers(::GLVisualizeBackend) = [:none, :auto, :ellipse] #, :rect, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star5] #vcat(_allMarkers, Shape)
supportedScales(::GLVisualizeBackend) = [:identity] #, :log, :log2, :log10, :asinh, :sqrt]
subplotSupported(::GLVisualizeBackend) = false

# --------------------------------------------------------------------------------------

supportedArgs(::PGFPlotsBackend) = [
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
supportedAxes(::PGFPlotsBackend) = [:auto, :left]
supportedTypes(::PGFPlotsBackend) = [:contour] #, :path, :scatter ,:steppre, :steppost, :sticks, :hist2d, :hexbin, :hist, :bar, :hline, :vline, :contour]
supportedStyles(::PGFPlotsBackend) = [:auto, :solid] #, :dash, :dot, :dashdot, :dashdotdot]
supportedMarkers(::PGFPlotsBackend) = [:none, :auto, :ellipse] #, :rect, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star5] #vcat(_allMarkers, Shape)
supportedScales(::PGFPlotsBackend) = [:identity] #, :log, :log2, :log10, :asinh, :sqrt]
subplotSupported(::PGFPlotsBackend) = false
