
# https://github.com/bokeh/Bokeh.jl


function _initialize_backend(::BokehBackend; kw...)
  @eval begin
    warn("Bokeh is no longer supported... many features will likely be broken.")
    import Bokeh
    export Bokeh
  end
end

# make255(x) = round(Int, 255 * x)

# function bokehcolor(c::Colorant)
#   @sprintf("rgba(%d, %d, %d, %1.3f)", [make255(f(c)) for f in [red,green,blue]]..., alpha(c))
# end
# bokehcolor(cs::ColorScheme) = bokehcolor(getColor(cs))


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
  lt = d[:linetype]
  mt = d[:markershape]
  if lt == :scatter && mt == :none
    mt = :ellipse
  end

  # if we have a marker, use that
  if lt == :scatter || mt != :none
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

function _create_plot(pkg::BokehBackend, d::KW)
  # TODO: create the window/canvas/context that is the plot within the backend (call it `o`)
  # TODO: initialize the plot... title, xlabel, bgcolor, etc

  datacolumns = Bokeh.BokehDataSet[]
  tools = Bokeh.tools()
  filename = tempname() * ".html"
  title = d[:title]
  w, h = d[:size]
  xaxis_type = d[:xscale] == :log10 ? :log : :auto
  yaxis_type = d[:yscale] == :log10 ? :log : :auto
  # legend = d[:legend] ? xxxx : nothing
  legend = nothing
  extra_args = KW()  # TODO: we'll put extra settings (xlim, etc) here
  bplt = Bokeh.Plot(datacolumns, tools, filename, title, w, h, xaxis_type, yaxis_type, legend) #, extra_args)

  Plot(bplt, pkg, 0, d, KW[])
end


function _add_series(::BokehBackend, plt::Plot, d::KW)
  bdata = Dict{Symbol, Vector}(:x => collect(d[:x]), :y => collect(d[:y]))

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

  push!(plt.seriesargs, d)
  plt
end

# ----------------------------------------------------------------

# TODO: override this to update plot items (title, xlabel, etc) after creation
function _update_plot(plt::Plot{BokehBackend}, d::KW)
end

function _update_plot_pos_size(plt::AbstractPlot{BokehBackend}, d::KW)
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

function _add_annotations{X,Y,V}(plt::Plot{BokehBackend}, anns::AVec{@compat(Tuple{X,Y,V})})
  for ann in anns
    # TODO: add the annotation to the plot
  end
end

# ----------------------------------------------------------------

function _create_subplot(subplt::Subplot{BokehBackend}, isbefore::Bool)
  # TODO: build the underlying Subplot object.  this is where you might layout the panes within a GUI window, for example

end


function _expand_limits(lims, plt::Plot{BokehBackend}, isx::Bool)
  # TODO: call expand limits for each plot data
end

function _remove_axis(plt::Plot{BokehBackend}, isx::Bool)
  # TODO: if plot is inner subplot, might need to remove ticks or axis labels
end

# ----------------------------------------------------------------

function Base.writemime(io::IO, ::MIME"image/png", plt::AbstractPlot{BokehBackend})
  # TODO: write a png to io
  warn("mime png not implemented")
end

function Base.display(::PlotsDisplay, plt::Plot{BokehBackend})
  Bokeh.showplot(plt.o)
end

function Base.display(::PlotsDisplay, plt::Subplot{BokehBackend})
  # TODO: display/show the subplot
end
