
# https://plot.ly/javascript/getting-started

# ---------------------------------------------------------------------------

function _create_plot(pkg::PlotlyPackage; kw...)
  d = Dict(kw)
  # TODO: create the window/canvas/context that is the plot within the backend (call it `o`)
  # TODO: initialize the plot... title, xlabel, bgcolor, etc
  Plot(nothing, pkg, 0, d, Dict[])
end


function _add_series(::PlotlyPackage, plt::Plot; kw...)
  d = Dict(kw)
  # TODO: add one series to the underlying package
  push!(plt.seriesargs, d)
  plt
end

function _add_annotations{X,Y,V}(plt::Plot{PlotlyPackage}, anns::AVec{@compat(Tuple{X,Y,V})})
  for ann in anns
    # TODO: add the annotation to the plot
  end
end

# ----------------------------------------------------------------

function _before_update_plot(plt::Plot{PlotlyPackage})
end

# TODO: override this to update plot items (title, xlabel, etc) after creation
function _update_plot(plt::Plot{PlotlyPackage}, d::Dict)
end

function _update_plot_pos_size(plt::PlottingObject{PlotlyPackage}, d::Dict)
end

# ----------------------------------------------------------------

# accessors for x/y data

function Base.getindex(plt::Plot{PlotlyPackage}, i::Int)
  series = plt.o.lines[i]
  series.x, series.y
end

function Base.setindex!(plt::Plot{PlotlyPackage}, xy::Tuple, i::Integer)
  series = plt.o.lines[i]
  series.x, series.y = xy
  plt
end

# ----------------------------------------------------------------

function _create_subplot(subplt::Subplot{PlotlyPackage})
  # TODO: build the underlying Subplot object.  this is where you might layout the panes within a GUI window, for example
end

function _expand_limits(lims, plt::Plot{PlotlyPackage}, isx::Bool)
  # TODO: call expand limits for each plot data
end

function _remove_axis(plt::Plot{PlotlyPackage}, isx::Bool)
  # TODO: if plot is inner subplot, might need to remove ticks or axis labels
end

# ----------------------------------------------------------------


# _plotDefaults[:title]             = ""
# _plotDefaults[:xlabel]            = ""
# _plotDefaults[:ylabel]            = ""
# _plotDefaults[:yrightlabel]       = ""
# _plotDefaults[:legend]            = true
# _plotDefaults[:background_color]  = colorant"white"
# _plotDefaults[:foreground_color]  = :auto
# _plotDefaults[:xlims]             = :auto
# _plotDefaults[:ylims]             = :auto
# _plotDefaults[:xticks]            = :auto
# _plotDefaults[:yticks]            = :auto
# _plotDefaults[:xscale]            = :identity
# _plotDefaults[:yscale]            = :identity
# _plotDefaults[:xflip]             = false
# _plotDefaults[:yflip]             = false
# _plotDefaults[:size]              = (600,400)
# _plotDefaults[:pos]               = (0,0)
# _plotDefaults[:windowtitle]       = "Plots.jl"
# _plotDefaults[:show]              = false
# _plotDefaults[:layout]            = nothing
# _plotDefaults[:n]                 = -1
# _plotDefaults[:nr]                = -1
# _plotDefaults[:nc]                = -1
# _plotDefaults[:color_palette]     = :auto
# _plotDefaults[:link]              = false
# _plotDefaults[:linkx]             = false
# _plotDefaults[:linky]             = false
# _plotDefaults[:linkfunc]          = nothing
# _plotDefaults[:tickfont]          = font(8)
# _plotDefaults[:guidefont]         = font(11)
# _plotDefaults[:legendfont]        = font(8)
# _plotDefaults[:grid]              = true


function get_plot_html(plt::Plot{PlotlyPackage})
  d = plt.plotargs
  d_out = Dict()

  # TODO: set the fields for the plot
  d_out[:title] = d[:title]
  d_out[:width], d_out[:height] = d[:size]
  # d_out[:margin] = 0
  d_out[:showlegend] = d[:legend]
  d_out[:paper_bgcolor] = d_out[:plot_bgcolor] = plotlycolor(d[:background_color])
  d_out[:titlefont] = plotlyfont(d[:guidefont])

  JSON.json(d_out)
end

# _seriesDefaults[:axis]            = :left
# _seriesDefaults[:label]           = "AUTO"
# _seriesDefaults[:linetype]        = :path
# _seriesDefaults[:linestyle]       = :solid
# _seriesDefaults[:linewidth]       = 1
# _seriesDefaults[:linecolor]       = :auto
# _seriesDefaults[:linealpha]       = nothing
# _seriesDefaults[:fillrange]       = nothing   # ribbons, areas, etc
# _seriesDefaults[:fillcolor]       = :match
# _seriesDefaults[:fillalpha]       = nothing
# _seriesDefaults[:markershape]     = :none
# _seriesDefaults[:markercolor]     = :match
# _seriesDefaults[:markeralpha]     = nothing
# _seriesDefaults[:markersize]      = 6
# _seriesDefaults[:markerstrokestyle] = :solid
# _seriesDefaults[:markerstrokewidth] = 1
# _seriesDefaults[:markerstrokecolor] = :match
# _seriesDefaults[:markerstrokealpha] = nothing
# _seriesDefaults[:nbins]           = 30               # number of bins for heatmaps and hists
# _seriesDefaults[:smooth]          = false               # regression line?
# _seriesDefaults[:group]           = nothing           # groupby vector
# _seriesDefaults[:annotation]      = nothing           # annotation tuple(s)... (x,y,annotation)
# _seriesDefaults[:x]               = nothing
# _seriesDefaults[:y]               = nothing
# _seriesDefaults[:z]               = nothing           # depth for contour, surface, etc
# _seriesDefaults[:zcolor]          = nothing           # value for color scale
# _seriesDefaults[:surface]         = nothing
# _seriesDefaults[:nlevels]         = 15

function get_series_html(plt::Plot{PlotlyPackage})
  JSON.json([begin
    d_out = Dict()

    # TODO: set the fields for each series
    for k in (:x, :y)
      d_out[k] = collect(d[k])
    end
    
    d_out
  end for d in plt.seriesargs])
end

# ----------------------------------------------------------------

function html_head(plt::Plot{PlotlyPackage})
  "<script src=\"$(Pkg.dir("Plots","deps","plotly-latest.min.js"))\"></script>"
end

function html_body(plt::Plot{PlotlyPackage})
  w, h = plt.plotargs[:size]

  # # TODO: get the real ones
  # seriesargs = [Dict(:x => collect(1:5), :y => rand(5))]
  # plotargs = Dict(:margin => 0)

  # series_html = JSON.json(seriesargs)
  # plot_html = JSON.json(plotargs)

  """
    <div id=\"myplot\" style=\"width:$(w)px;height:$(h)px;\"></div>
    <script>
      PLOT = document.getElementById('myplot');
      Plotly.plot(PLOT, $(get_series_html(plt)), $(get_plot_html(plt)));
    </script>
  """
end


# ----------------------------------------------------------------


function Base.writemime(io::IO, ::MIME"image/png", plt::PlottingObject{PlotlyPackage})
  # TODO: write a png to io
end

function Base.display(::PlotsDisplay, plt::Plot{PlotlyPackage})
  standalone_html_window(plt)
end

function Base.display(::PlotsDisplay, plt::Subplot{PlotlyPackage})
  # TODO: display/show the subplot
end
