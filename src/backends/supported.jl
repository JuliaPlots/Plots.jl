
supportedArgs(::GadflyPackage) = [
    :annotation,
    # :axis,
    :background_color,
    :color,
    :color_palette,
    :fillrange,
    :fillcolor,
    :fillopacity,
    :foreground_color,
    :group,
    :label,
    :layout,
    :legend,
    :linestyle,
    :linetype,
    :linewidth,
    :lineopacity,
    :markershape,
    :markercolor,
    :markersize,
    :markeropacity,
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
    :tickfont,
    :guidefont,
    :legendfont,
    :grid,
    :surface,
    :nlevels,
  ]
supportedAxes(::GadflyPackage) = [:auto, :left]
supportedTypes(::GadflyPackage) = [:none, :line, :path, :steppre, :steppost, :sticks, :scatter, :heatmap, :hexbin, :hist, :bar, :hline, :vline, :contour]
supportedStyles(::GadflyPackage) = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]
supportedMarkers(::GadflyPackage) = vcat(_allMarkers, Shape)
supportedScales(::GadflyPackage) = [:identity, :log, :log2, :log10, :asinh, :sqrt]


# --------------------------------------------------------------------------------------


supportedArgs(::ImmersePackage) = supportedArgs(GadflyPackage())
supportedAxes(::ImmersePackage) = supportedAxes(GadflyPackage())
supportedTypes(::ImmersePackage) = supportedTypes(GadflyPackage())
supportedStyles(::ImmersePackage) = supportedStyles(GadflyPackage())
supportedMarkers(::ImmersePackage) = supportedMarkers(GadflyPackage())
supportedScales(::ImmersePackage) = supportedScales(GadflyPackage())

# --------------------------------------------------------------------------------------



supportedArgs(::PyPlotPackage) = [
    :annotation,
    :axis,
    :background_color,
    :color,
    :color_palette,
    :fillrange,
    :fillcolor,
    :foreground_color,
    :group,
    :label,
    :layout,
    :legend,
    :linestyle,
    :linetype,
    :linewidth,
    :markershape,
    :markercolor,
    :markersize,
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
    :tickfont,
    :guidefont,
    :legendfont,
    :grid,
    :surface,
    :nlevels,
    :fillopacity,
    :lineopacity,
    :markeropacity,
  ]
supportedAxes(::PyPlotPackage) = _allAxes
supportedTypes(::PyPlotPackage) = [:none, :line, :path, :steppre, :steppost, :sticks, :scatter, :heatmap, :hexbin, :hist, :bar, :hline, :vline, :contour]
supportedStyles(::PyPlotPackage) = [:auto, :solid, :dash, :dot, :dashdot]
# supportedMarkers(::PyPlotPackage) = [:none, :auto, :rect, :ellipse, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star5, :hexagon]
supportedMarkers(::PyPlotPackage) = vcat(_allMarkers, Shape)
supportedScales(::PyPlotPackage) = [:identity, :log, :log2, :log10]
subplotSupported(::PyPlotPackage) = true


# --------------------------------------------------------------------------------------



supportedArgs(::QwtPackage) = [
    :annotation,
    # :args,
    :axis,
    :background_color,
    :color,
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
supportedTypes(::QwtPackage) = [:none, :line, :path, :steppre, :steppost, :sticks, :scatter, :heatmap, :hexbin, :hist, :bar, :hline, :vline]
supportedMarkers(::QwtPackage) = [:none, :auto, :rect, :ellipse, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star5, :star8, :hexagon]
supportedScales(::QwtPackage) = [:identity, :log10]


# --------------------------------------------------------------------------------------


supportedArgs(::UnicodePlotsPackage) = [
    # :annotation,
    # :args,
    # :axis,
    # :background_color,
    # :color,
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
supportedTypes(::UnicodePlotsPackage) = [:none, :line, :path, :steppost, :sticks, :scatter, :heatmap, :hexbin, :hist, :bar, :hline, :vline]
supportedStyles(::UnicodePlotsPackage) = [:auto, :solid]
supportedMarkers(::UnicodePlotsPackage) = [:none, :auto, :ellipse]
supportedScales(::UnicodePlotsPackage) = [:identity]




# --------------------------------------------------------------------------------------


supportedArgs(::WinstonPackage) = [
    :annotation,
    # :args,
    # :axis,
    # :background_color,
    :color,
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