
# https://github.com/bokeh/Bokeh.jl


supportedArgs(::BokehBackend) = [
    # :annotations,
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
    :seriescolor, :seriesalpha,
    :linestyle,
    :seriestype,
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
    # :bins,
    # :nc,
    # :nr,
    # :pos,
    # :smooth,
    # :show,
    :size,
    :title,
    # :windowtitle,
    :x,
    # :xguide,
    # :xlims,
    # :xticks,
    :y,
    # :yguide,
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



function _initialize_backend(::BokehBackend; kw...)
  @eval begin
    warn("Bokeh is no longer supported... many features will likely be broken.")
    import Bokeh
    export Bokeh
  end
end


const _glyphtypes = KW(
    :ellipse    => :Circle,
    :rect       => :Square,
    :diamond    => :Diamond,
    :utriangle  => :Triangle,
    :dtriangle  => :InvertedTriangle,
    # :pentagon   =>
    # :hexagon    =>
    # :heptagon   =>
    # :octagon    =>
    :cross      => :Cross,
    :xcross     => :X,
    :star5      => :Asterisk,
  )


function bokeh_glyph_type(d::KW)
  st = d[:seriestype]
  mt = d[:markershape]
  if st == :scatter && mt == :none
    mt = :ellipse
  end

  # if we have a marker, use that
  if st == :scatter || mt != :none
    return _glyphtypes[mt]
  end

  # otherwise return a line
  return :Line
end

function get_stroke_vector(linestyle::Symbol)
  dash = 12
  dot = 3
  gap = 2
  linestyle == :solid && return Int[]
  linestyle == :dash && return Int[dash, gap]
  linestyle == :dot && return Int[dot, gap]
  linestyle == :dashdot && return Int[dash, gap, dot, gap]
  linestyle == :dashdotdot && return Int[dash, gap, dot, gap, dot, gap]
  error("unsupported linestyle: ", linestyle)
end

# ---------------------------------------------------------------------------

# function _create_plot(pkg::BokehBackend, d::KW)
function _create_backend_figure(plt::Plot{BokehBackend})
  # TODO: create the window/canvas/context that is the plot within the backend (call it `o`)
  # TODO: initialize the plot... title, xlabel, bgcolor, etc

  datacolumns = Bokeh.BokehDataSet[]
  tools = Bokeh.tools()
  filename = tempname() * ".html"
  title = plt.plotargs[:title]
  w, h = plt.plotargs[:size]
  xaxis_type = plt.plotargs[:xscale] == :log10 ? :log : :auto
  yaxis_type = plt.plotargs[:yscale] == :log10 ? :log : :auto
  # legend = plt.plotargs[:legend] ? xxxx : nothing
  legend = nothing
  extra_args = KW()  # TODO: we'll put extra settings (xlim, etc) here
  Bokeh.Plot(datacolumns, tools, filename, title, w, h, xaxis_type, yaxis_type, legend) #, extra_args)

  # Plot(bplt, pkg, 0, d, KW[])
end


# function _series_added(::BokehBackend, plt::Plot, d::KW)
function _series_added(plt::Plot{BokehBackend}, series::Series)
  bdata = Dict{Symbol, Vector}(:x => collect(series.d[:x]), :y => collect(series.d[:y]))

  glyph = Bokeh.Bokehjs.Glyph(
      glyphtype = bokeh_glyph_type(d),
      linecolor = webcolor(d[:linecolor]),  # shape's stroke or line color
      linewidth = d[:linewidth],          # shape's stroke width or line width
      fillcolor = webcolor(d[:markercolor]),
      size      = ceil(Int, d[:markersize] * 2.5),  # magic number 2.5 to keep in same scale as other backends
      dash      = get_stroke_vector(d[:linestyle])
    )

  legend = nothing  # TODO
  push!(plt.o.datacolumns, Bokeh.BokehDataSet(bdata, glyph, legend))

  # push!(plt.seriesargs, d)
  # plt
end

# ----------------------------------------------------------------

# TODO: override this to update plot items (title, xlabel, etc) after creation
function _update_plot(plt::Plot{BokehBackend}, d::KW)
end

# ----------------------------------------------------------------

# accessors for x/y data

# function getxy(plt::Plot{BokehBackend}, i::Int)
#   series = plt.o.datacolumns[i].data
#   series[:x], series[:y]
# end
#
# function setxy!(plt::Plot{BokehBackend}, xy::Tuple{X,Y}, i::Integer)
#   series = plt.o.datacolumns[i].data
#   series[:x], series[:y] = xy
#   plt
# end



# ----------------------------------------------------------------


# ----------------------------------------------------------------

function Base.writemime(io::IO, ::MIME"image/png", plt::AbstractPlot{BokehBackend})
  # TODO: write a png to io
  warn("mime png not implemented")
end

function Base.display(::PlotsDisplay, plt::Plot{BokehBackend})
  Bokeh.showplot(plt.o)
end

# function Base.display(::PlotsDisplay, plt::Subplot{BokehBackend})
#   # TODO: display/show the subplot
# end
