
# https://plot.ly/javascript/getting-started

function _initialize_backend(::PlotlyBackend; kw...)
  @eval begin
    import JSON
    JSON._print(io::IO, state::JSON.State, dt::Union{Date,DateTime}) = print(io, '"', dt, '"')

    _js_path = Pkg.dir("Plots", "deps", "plotly-latest.min.js")
    _js_code = open(readall, _js_path, "r")

    # borrowed from https://github.com/plotly/plotly.py/blob/2594076e29584ede2d09f2aa40a8a195b3f3fc66/plotly/offline/offline.py#L64-L71 c/o @spencerlyon2
    _js_script = """
        <script type='text/javascript'>
            define('plotly', function(require, exports, module) {
                $(_js_code)
            });
            require(['plotly'], function(Plotly) {
                window.Plotly = Plotly;
            });
        </script>
    """

    # if we're in IJulia call setupnotebook to load js and css
    if isijulia()
        display("text/html", _js_script)
    end

    # if isatom()
    #     import Atom
    #     Atom.@msg evaljs(_js_code)
    # end

  end
  # TODO: other initialization
end

# ---------------------------------------------------------------------------

function _create_plot(pkg::PlotlyBackend; kw...)
  d = Dict{Symbol,Any}(kw)
  # TODO: create the window/canvas/context that is the plot within the backend (call it `o`)
  # TODO: initialize the plot... title, xlabel, bgcolor, etc
  Plot(nothing, pkg, 0, d, Dict[])
end


function _add_series(::PlotlyBackend, plt::Plot; kw...)
  d = Dict{Symbol,Any}(kw)
  # TODO: add one series to the underlying package
  push!(plt.seriesargs, d)
  plt
end

function _add_annotations{X,Y,V}(plt::Plot{PlotlyBackend}, anns::AVec{@compat(Tuple{X,Y,V})})
  # set or add to the annotation_list
  if haskey(plt.plotargs, :annotation_list)
    append!(plt.plotargs[:annotation_list], anns)
  else
    plt.plotargs[:annotation_list] = anns
  end
end

# ----------------------------------------------------------------

function _before_update_plot(plt::Plot{PlotlyBackend})
end

# TODO: override this to update plot items (title, xlabel, etc) after creation
function _update_plot(plt::Plot{PlotlyBackend}, d::Dict)
end

function _update_plot_pos_size(plt::AbstractPlot{PlotlyBackend}, d::Dict)
end

# ----------------------------------------------------------------

# accessors for x/y data

function Base.getindex(plt::Plot{PlotlyBackend}, i::Int)
  d = plt.seriesargs[i]
  d[:x], d[:y]
end

function Base.setindex!(plt::Plot{PlotlyBackend}, xy::Tuple, i::Integer)
  d = plt.seriesargs[i]
  d[:x], d[:y] = xy
  plt
end

# ----------------------------------------------------------------

function _create_subplot(subplt::Subplot{PlotlyBackend}, isbefore::Bool)
  # TODO: build the underlying Subplot object.  this is where you might layout the panes within a GUI window, for example
  true
end

function _expand_limits(lims, plt::Plot{PlotlyBackend}, isx::Bool)
  # TODO: call expand limits for each plot data
end

function _remove_axis(plt::Plot{PlotlyBackend}, isx::Bool)
  # TODO: if plot is inner subplot, might need to remove ticks or axis labels
end

# ----------------------------------------------------------------

# TODO:
# _plotDefaults[:yrightlabel]       = ""
# _plotDefaults[:xlims]             = :auto
# _plotDefaults[:ylims]             = :auto
# _plotDefaults[:xticks]            = :auto
# _plotDefaults[:yticks]            = :auto
# _plotDefaults[:xscale]            = :identity
# _plotDefaults[:yscale]            = :identity
# _plotDefaults[:xflip]             = false
# _plotDefaults[:yflip]             = false

function plotlyfont(font::Font, color = font.color)
  Dict{Symbol,Any}(
      :family => font.family,
      :size   => round(Int, font.pointsize*1.4),
      :color  => webcolor(color),
    )
end

function get_annotation_dict(x, y, val::Union{AbstractString,Symbol})
  Dict{Symbol,Any}(
      :text => val,
      :xref => "x",
      :x => x,
      :yref => "y",
      :y => y,
      :showarrow => false,
    )
end

function get_annotation_dict(x, y, ptxt::PlotText)
  merge(get_annotation_dict(x, y, ptxt.str), Dict{Symbol,Any}(
      :font => plotlyfont(ptxt.font),
      :xanchor => ptxt.font.halign == :hcenter ? :center : ptxt.font.halign,
      :yanchor => ptxt.font.valign == :vcenter ? :middle : ptxt.font.valign,
      :rotation => ptxt.font.rotation,
    ))
end

function plotlyscale(scale::Symbol)
  if scale == :log10
    "log"
  else
    "-"
  end
end

use_axis_field(ticks) = !(ticks in (nothing, :none))

tickssym(isx::Bool) = symbol((isx ? "x" : "y") * "ticks")
limssym(isx::Bool) = symbol((isx ? "x" : "y") * "lims")
flipsym(isx::Bool) = symbol((isx ? "x" : "y") * "flip")
scalesym(isx::Bool) = symbol((isx ? "x" : "y") * "scale")
labelsym(isx::Bool) = symbol((isx ? "x" : "y") * "label")

function plotlyaxis(d::Dict, isx::Bool)
  ax = Dict{Symbol,Any}(
      :title      => d[labelsym(isx)],
      :showgrid   => d[:grid],
      :zeroline   => false,
    )

  fgcolor = webcolor(d[:foreground_color])
  tsym = tickssym(isx)

  if use_axis_field(d[tsym])
    ax[:titlefont] = plotlyfont(d[:guidefont], fgcolor)
    ax[:type] = plotlyscale(d[scalesym(isx)])
    ax[:tickfont] = plotlyfont(d[:tickfont], fgcolor)
    ax[:tickcolor] = fgcolor
    ax[:linecolor] = fgcolor

    # xlims
    lims = d[limssym(isx)]
    if lims != :auto && limsType(lims) == :limits
      ax[:range] = lims
    end

    # xflip
    if d[flipsym(isx)]
      ax[:autorange] = "reversed"
    end

    # xticks
    ticks = d[tsym]
    if ticks != :auto
      ttype = ticksType(ticks)
      if ttype == :ticks
        ax[:tickmode] = "array"
        ax[:tickvals] = ticks
      elseif ttype == :ticks_and_labels
        ax[:tickmode] = "array"
        ax[:tickvals], ax[:ticktext] = ticks
      end
    end

    ax
  else
    ax[:showticklabels] = false
    ax[:showgrid] = false
  end

  ax
end

# function get_plot_json(plt::Plot{PlotlyBackend})
#   d = plt.plotargs
function plotly_layout(d::Dict)
  d_out = Dict{Symbol,Any}()

  bgcolor = webcolor(d[:background_color])
  fgcolor = webcolor(d[:foreground_color])

  # set the fields for the plot
  d_out[:title] = d[:title]
  d_out[:titlefont] = plotlyfont(d[:guidefont], fgcolor)
  d_out[:margin] = Dict{Symbol,Any}(:l=>35, :b=>30, :r=>8, :t=>20)
  d_out[:plot_bgcolor] = bgcolor
  d_out[:paper_bgcolor] = bgcolor

  # TODO: x/y axis tick values/labels
  d_out[:xaxis] = plotlyaxis(d, true)
  d_out[:yaxis] = plotlyaxis(d, false)

  # legend
  d_out[:showlegend] = d[:legend] != :none
  if d[:legend] != :none
    d_out[:legend] = Dict{Symbol,Any}(
        :bgcolor  => bgcolor,
        :bordercolor => fgcolor,
        :font     => plotlyfont(d[:legendfont]),
      )
  end

  # annotations
  anns = get(d, :annotation_list, [])
  if !isempty(anns)
    d_out[:annotations] = [get_annotation_dict(ann...) for ann in anns]
  end

  d_out
end

function get_plot_json(plt::Plot{PlotlyBackend})
  JSON.json(plotly_layout(plt.plotargs))
end


function plotly_colorscale(grad::ColorGradient, alpha = nothing)
  [[grad.values[i], webcolor(grad.colors[i], alpha)] for i in 1:length(grad.colors)]
end
plotly_colorscale(c, alpha = nothing) = plotly_colorscale(ColorGradient(:bluesreds), alpha)

const _plotly_markers = Dict{Symbol,Any}(
    :rect       => "square",
    :xcross     => "x",
    :utriangle  => "triangle-up",
    :dtriangle  => "triangle-down",
    :star5      => "star-triangle-up",
    :vline      => "line-ns",
    :hline      => "line-ew",
  )

# get a dictionary representing the series params (d is the Plots-dict, d_out is the Plotly-dict)
function plotly_series(d::Dict; plot_index = nothing)
  d_out = Dict{Symbol,Any}()

  x, y = collect(d[:x]), collect(d[:y])
  d_out[:name] = d[:label]

  lt = d[:linetype]
  isscatter = lt in (:scatter, :scatter3d)
  hasmarker = isscatter || d[:markershape] != :none
  hasline = !isscatter

  # set the "type"
  if lt in (:line, :path, :scatter, :steppre, :steppost)
    d_out[:type] = "scatter"
    d_out[:mode] = if hasmarker
      hasline ? "lines+markers" : "markers"
    else
      hasline ? "lines" : "none"
    end
    if d[:fillrange] == true || d[:fillrange] == 0
      d_out[:fill] = "tozeroy"
      d_out[:fillcolor] = webcolor(d[:fillcolor], d[:fillalpha])
    elseif !(d[:fillrange] in (false, nothing))
      warn("fillrange ignored... plotly only supports filling to zero. fillrange: $(d[:fillrange])")
    end
    d_out[:x], d_out[:y] = x, y

  elseif lt == :bar
    d_out[:type] = "bar"
    d_out[:x], d_out[:y] = x, y

  elseif lt == :hist2d
    d_out[:type] = "histogram2d"
    d_out[:x], d_out[:y] = x, y
    if isa(d[:nbins], Tuple)
      xbins, ybins = d[:nbins]
    else
      xbins = ybins = d[:nbins]
    end
    d_out[:nbinsx] = xbins
    d_out[:nbinsy] = ybins

  elseif lt in (:hist, :density)
    d_out[:type] = "histogram"
    isvert = d[:orientation] in (:vertical, :v, :vert)
    d_out[isvert ? :x : :y] = y
    d_out[isvert ? :nbinsx : :nbinsy] = d[:nbins]
    if lt == :density
      d_out[:histnorm] = "probability density"
    end

  elseif lt == :heatmap
    d_out[:type] = "heatmap"
    d_out[:x], d_out[:y] = x, y
    d_out[:z] = d[:z].surf
    d_out[:colorscale] = plotly_colorscale(d[:fillcolor], d[:fillalpha])

  elseif lt == :contour
    d_out[:type] = "contour"
    d_out[:x], d_out[:y] = x, y
    d_out[:z] = d[:z].surf
    # d_out[:showscale] = d[:colorbar] != :none
    d_out[:ncontours] = d[:levels]
    d_out[:contours] = Dict{Symbol,Any}(:coloring => d[:fillrange] != nothing ? "fill" : "lines")
    d_out[:colorscale] = plotly_colorscale(d[:linecolor], d[:linealpha])

  elseif lt in (:surface, :wireframe)
    d_out[:type] = "surface"
    d_out[:x], d_out[:y] = x, y
    d_out[:z] = d[:z].surf
    d_out[:colorscale] = plotly_colorscale(d[:fillcolor], d[:fillalpha])

  elseif lt == :pie
    d_out[:type] = "pie"
    d_out[:labels] = x
    d_out[:values] = y
    d_out[:hoverinfo] = "label+percent+name"

  elseif lt in (:path3d, :scatter3d)
    d_out[:type] = "scatter3d"
    d_out[:mode] = if hasmarker
      hasline ? "lines+markers" : "markers"
    else
      hasline ? "lines" : "none"
    end
    d_out[:x], d_out[:y] = x, y
    d_out[:z] = collect(d[:z])

  else
    warn("Plotly: linetype $lt isn't supported.")
    return Dict{Symbol,Any}()
  end

  # add "marker"
  if hasmarker
    d_out[:marker] = Dict{Symbol,Any}(
        :symbol => get(_plotly_markers, d[:markershape], string(d[:markershape])),
        :opacity => d[:markeralpha],
        :size => 2 * d[:markersize],
        :color => webcolor(d[:markercolor], d[:markeralpha]),
        :line => Dict{Symbol,Any}(
            :color => webcolor(d[:markerstrokecolor], d[:markerstrokealpha]),
            :width => d[:markerstrokewidth],
          ),
      )

    # gotta hack this (for now?) since plotly can't handle rgba values inside the gradient
    if d[:zcolor] != nothing
      # d_out[:marker][:color] = d[:zcolor]
      # d_out[:marker][:colorscale] = plotly_colorscale(d[:markercolor], d[:markeralpha])
      # d_out[:showscale] = true
      grad = ColorGradient(d[:markercolor], alpha=d[:markeralpha])
      zmin, zmax = extrema(d[:zcolor])
      d_out[:marker][:color] = [webcolor(getColorZ(grad, (zi - zmin) / (zmax - zmin))) for zi in d[:zcolor]]
    end

  end

  # add "line"
  if hasline
    d_out[:line] = Dict{Symbol,Any}(
        :color => webcolor(d[:linecolor], d[:linealpha]),
        :width => d[:linewidth],
        :shape => if lt == :steppre
          "vh"
        elseif lt == :steppost
          "hv"
        else
          "linear"
        end,
        :dash => string(d[:linestyle]),
        # :dash => "solid",
      )
  end

  # # for subplots, we need to add the xaxis/yaxis fields
  # if plot_index != nothing
  #   d_out[:xaxis] = "x$(plot_index)"
  #   d_out[:yaxis] = "y$(plot_index)"
  # end

  d_out
end

# get a list of dictionaries, each representing the series params
function get_series_json(plt::Plot{PlotlyBackend})
  JSON.json(map(plotly_series, plt.seriesargs))
end

function get_series_json(subplt::Subplot{PlotlyBackend})
  ds = Dict[]
  for (i,plt) in enumerate(subplt.plts)
    for d in plt.seriesargs
      push!(ds, plotly_series(d, plot_index = i))
    end
  end
  JSON.json(ds)
end

# ----------------------------------------------------------------

function html_head(plt::AbstractPlot{PlotlyBackend})
  "<script src=\"$(Pkg.dir("Plots","deps","plotly-latest.min.js"))\"></script>"
end

function html_body(plt::Plot{PlotlyBackend}, style = nothing)
  if style == nothing
    w, h = plt.plotargs[:size]
    style = "width:$(w)px;height:$(h)px;"
  end
  uuid = Base.Random.uuid4()
  html = """
    <div id=\"$(uuid)\" style=\"$(style)\"></div>
    <script>
      PLOT = document.getElementById('$(uuid)');
      Plotly.plot(PLOT, $(get_series_json(plt)), $(get_plot_json(plt)));
    </script>
  """
  # @show html
  html
end

function js_body(plt::Plot{PlotlyBackend}, uuid)
    js = """
          PLOT = document.getElementById('$(uuid)');
          Plotly.plot(PLOT, $(get_series_json(plt)), $(get_plot_json(plt)));
    """
end


function html_body(subplt::Subplot{PlotlyBackend})
  w, h = subplt.plts[1].plotargs[:size]
  html = ["<div style=\"width:$(w)px;height:$(h)px;\">"]
  nr = nrows(subplt.layout)
  ph = h / nr

  for r in 1:nr
    push!(html, "<div style=\"clear:both;\">")

    nc = ncols(subplt.layout, r)
    pw = w / nc

    for c in 1:nc
      plt = subplt[r,c]
      push!(html, html_body(plt, "float:left; width:$(pw)px; height:$(ph)px;"))
    end

    push!(html, "</div>")
  end
  push!(html, "</div>")

  join(html)
end


# ----------------------------------------------------------------

function Base.writemime(io::IO, ::MIME"image/png", plt::AbstractPlot{PlotlyBackend})
  warn("todo: png")
end

function Base.writemime(io::IO, ::MIME"text/html", plt::AbstractPlot{PlotlyBackend})
    write(io, html_head(plt) * html_body(plt))
    # write(io, html_body(plt))
end

function Base.display(::PlotsDisplay, plt::AbstractPlot{PlotlyBackend})
  standalone_html_window(plt)
end

# function Base.display(::PlotsDisplay, plt::Subplot{PlotlyBackend})
#   # TODO: display/show the subplot
# end
