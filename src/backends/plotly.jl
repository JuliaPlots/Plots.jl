
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


# _plotDefaults[:yrightlabel]       = ""
# _plotDefaults[:xlims]             = :auto
# _plotDefaults[:ylims]             = :auto
# _plotDefaults[:xticks]            = :auto
# _plotDefaults[:yticks]            = :auto
# _plotDefaults[:xscale]            = :identity
# _plotDefaults[:yscale]            = :identity
# _plotDefaults[:xflip]             = false
# _plotDefaults[:yflip]             = false

function plotlyfont(font::Font)
  Dict(
      :family => font.family,
      :size   => font.pointsize,
      :color  => webcolor(font.color),
    )
end

function plotlyscale(scale::Symbol)
  if scale == :log
    "log"
  else
    "-"
  end
end

function get_plot_html(plt::Plot{PlotlyPackage})
  d = plt.plotargs
  d_out = Dict()

  bgcolor = webcolor(d[:background_color])
  fgcolor = webcolor(d[:foreground_color])

  # TODO: set the fields for the plot
  d_out[:title] = d[:title]
  d_out[:titlefont] = plotlyfont(d[:guidefont])
  d_out[:width], d_out[:height] = d[:size]
  # d_out[:margin] = Dict(:l=>20, :b=>20, :r=>10, :t=>10)
  d_out[:margin] = Dict(:t=>20)
  d_out[:paper_bgcolor] = bgcolor
  d_out[:plot_bgcolor] = bgcolor
  
  # TODO: x/y axis tick values/labels
  # TODO: x/y axis range

  d_out[:xaxis] = Dict(
      :title      => d[:xlabel],
      :titlefont  => plotlyfont(d[:guidefont]),
      :type       => plotlyscale(d[:xscale]),
      :tickfont   => plotlyfont(d[:tickfont]),
      :tickcolor  => fgcolor,
      :linecolor  => fgcolor,
      :showgrid   => d[:grid],
    )
  d_out[:yaxis] = Dict(
      :title      => d[:ylabel],
      :titlefont  => plotlyfont(d[:guidefont]),
      :type       => plotlyscale(d[:yscale]),
      :tickfont   => plotlyfont(d[:tickfont]),
      :tickcolor  => fgcolor,
      :linecolor  => fgcolor,
      :showgrid   => d[:grid],
    )

  d_out[:showlegend] = d[:legend]
  if d[:legend]
    d_out[:legend] = Dict(
        :bgcolor  => bgcolor,
        :bordercolor => fgcolor,
        :font     => plotlyfont(d[:legendfont]),
        :yanchor  => "middle",
      )
  end

  # TODO: d_out[:annotations]

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

# supportedTypes(::PyPlotPackage) = [:none, :line, :path, :steppre, :steppost, :sticks,
#                                    :scatter, :heatmap, :hexbin, :hist, :density, :bar,
#                                    :hline, :vline, :contour, :path3d, :scatter3d]

function plotly_colorscale(grad::ColorGradient)
  [[grad.values[i], webcolor(grad.colors[i])] for i in 1:length(grad.colors)]
end
plotly_colorscale(c) = plotly_colorscale(ColorGradient(:bluesreds))

# get a dictionary representing the series params (d is the Plots-dict, d_out is the Plotly-dict)
function get_series_html(d::Dict)
  d_out = Dict()

  x, y = collect(d[:x]), collect(d[:y])
  # d_out[:x] = collect(d[:x])
  # d_out[:y] = collect(d[:y])
  d_out[:name] = d[:label]

  lt = d[:linetype]
  hasmarker = lt == :scatter || d[:markershape] != :none
  hasline = lt != :scatter

  # set the "type"
  if lt in (:line, :path, :scatter, :steppre, :steppost)
    d_out[:type] = "scatter"
    d_out[:mode] = if hasmarker
      hasline ? "lines+markers" : "markers"
    else
      hasline ? "lines" : "none"
    end
    d_out[:x], d_out[:y] = x, y
  elseif lt == :bar
    d_out[:type] = "bar"
    d_out[:x], d_out[:y] = x, y
  elseif lt == :heatmap
    d_out[:type] = "heatmap"
    d_out[:x], d_out[:y] = x, y
  elseif lt == :hist
    d_out[:type] = "histogram"
    isvert = d[:orientation] in (:vertical, :v, :vert)
    d_out[isvert ? :x : :y] = y
  elseif lt == :contour
    d_out[:type] = "contour"
    d_out[:x], d_out[:y] = x, y
    d_out[:z] = d[:z].surf
    # d_out[:showscale] = d[:legend]
    d_out[:ncontours] = d[:nlevels]
    d_out[:contours] = Dict(:coloring => d[:fillrange] != nothing ? "fill" : "lines")
    # TODO: colorscale: [[0, 'rgb(166,206,227)'], [0.25, 'rgb(31,120,180)'], [0.45, 'rgb(178,223,138)'], [0.65, 'rgb(51,160,44)'], [0.85, 'rgb(251,154,153)'], [1, 'rgb(227,26,28)']]
    d_out[:colorscale] = plotly_colorscale(d[:linecolor])
  elseif lt == :pie
    d_out[:type] = "pie"
    d_out[:labels] = x
    d_out[:values] = y
    d_out[:hoverinfo] = "label+percent+name"
  else
    error("Plotly: linetype $lt isn't supported.")
  end

  # add "marker"
  if hasmarker
    d_out[:marker] = Dict(
        # :symbol => "circle",
        # :opacity => d[:markeropacity],
        :size => d[:markersize],
        :color => webcolor(d[:markercolor], d[:markeralpha]),
        :line => Dict(
            :color => webcolor(d[:markerstrokecolor], d[:markerstrokealpha]),
            :width => d[:markerstrokewidth],
          ),
      )
    if d[:zcolor] != nothing
      d_out[:marker][:color] = d[:zcolor]
      d_out[:marker][:colorscale] = :RdBu # TODO: use the markercolor gradient
    end
  end

  # add "line"
  if hasline
    d_out[:line] = Dict(
        :color => webcolor(d[:linecolor], d[:linealpha]),
        :width => d[:linewidth],
        # :dash => "solid",
      )
  end

  d_out
end

# get a list of dictionaries, each representing the series params
function get_series_html(plt::Plot{PlotlyPackage})
  JSON.json(map(get_series_html, plt.seriesargs))
end

# ----------------------------------------------------------------

function html_head(plt::Plot{PlotlyPackage})
  "<script src=\"$(Pkg.dir("Plots","deps","plotly-latest.min.js"))\"></script>"
end

function html_body(plt::Plot{PlotlyPackage})
  w, h = plt.plotargs[:size]
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
  println("png")
end

function Base.writemime(io::IO, ::MIME"text/html", plt::PlottingObject{PlotlyPackage})
  println("html")
  html_head(plt) * html_body(plt)
end

function Base.display(::PlotsDisplay, plt::Plot{PlotlyPackage})
  standalone_html_window(plt)
end

function Base.display(::PlotsDisplay, plt::Subplot{PlotlyPackage})
  # TODO: display/show the subplot
end
