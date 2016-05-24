
# https://plot.ly/javascript/getting-started

supportedArgs(::PlotlyBackend) = [
    :annotations,
    :background_color, :foreground_color, :color_palette,
    # :background_color_legend, :background_color_inside, :background_color_outside,
    # :foreground_color_legend, :foreground_color_grid, :foreground_color_axis,
    #     :foreground_color_text, :foreground_color_border,
    :group,
    :label,
    :seriestype,
    :seriescolor, :seriesalpha,
    :linecolor, :linestyle, :linewidth, :linealpha,
    :markershape, :markercolor, :markersize, :markeralpha,
    :markerstrokewidth, :markerstrokecolor, :markerstrokealpha,
    :fillrange, :fillcolor, :fillalpha,
    :bins,
    :n, :nc, :nr, :layout,
    # :smooth,
    :title, :window_title, :show, :size,
    :x, :xguide, :xlims, :xticks, :xscale, :xflip, :xrotation,
    :y, :yguide, :ylims, :yticks, :yscale, :yflip, :yrotation,
    :z, :zguide, :zlims, :zticks, :zscale, :zflip, :zrotation,
    :z,
    :tickfont, :guidefont, :legendfont,
    :grid, :legend, :colorbar,
    :marker_z, :levels,
    :xerror, :yerror,
    :ribbon, :quiver,
    :orientation,
    # :overwrite_figure,
    :polar,
    # :normalize, :weights, :contours, :aspect_ratio
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

# function _create_plot(pkg::PlotlyBackend, d::KW)
#   # TODO: create the window/canvas/context that is the plot within the backend (call it `o`)
#   # TODO: initialize the plot... title, xlabel, bgcolor, etc
#   Plot(nothing, pkg, 0, d, KW[])
# end


# function _series_added(::PlotlyBackend, plt::Plot, d::KW)
#   # TODO: add one series to the underlying package
#   push!(plt.seriesargs, d)
#   plt
# end

# function _add_annotations{X,Y,V}(plt::Plot{PlotlyBackend}, anns::AVec{@compat(Tuple{X,Y,V})})
#   # set or add to the annotation_list
#   if haskey(plt.attr, :annotation_list)
#     append!(plt.attr[:annotation_list], anns)
#   else
#     plt.attr[:annotation_list] = anns
#   end
# end

# ----------------------------------------------------------------

# function _before_update_plot(plt::Plot{PlotlyBackend})
# end
#
# # TODO: override this to update plot items (title, xlabel, etc) after creation
# function _update_plot(plt::Plot{PlotlyBackend}, d::KW)
# end

# function _update_plot_pos_size(plt::AbstractPlot{PlotlyBackend}, d::KW)
# end

# ----------------------------------------------------------------

# accessors for x/y data

# function getxy(plt::Plot{PlotlyBackend}, i::Int)
#   d = plt.seriesargs[i]
#   d[:x], d[:y]
# end
#
# function setxy!{X,Y}(plt::Plot{PlotlyBackend}, xy::Tuple{X,Y}, i::Integer)
#   d = plt.seriesargs[i]
#   d[:x], d[:y] = xy
#   plt
# end

# ----------------------------------------------------------------

# function _create_subplot(subplt::Subplot{PlotlyBackend}, isbefore::Bool)
#   # TODO: build the underlying Subplot object.  this is where you might layout the panes within a GUI window, for example
#   true
# end

# function _expand_limits(lims, plt::Plot{PlotlyBackend}, isx::Bool)
#   # TODO: call expand limits for each plot data
# end
#
# function _remove_axis(plt::Plot{PlotlyBackend}, isx::Bool)
#   # TODO: if plot is inner subplot, might need to remove ticks or axis labels
# end

# ----------------------------------------------------------------

function plotlyfont(font::Font, color = font.color)
    KW(
        :family => font.family,
        :size   => round(Int, font.pointsize*1.4),
        :color  => webcolor(color),
    )
end

function get_annotation_dict(x, y, val::Union{AbstractString,Symbol})
    KW(
        :text => val,
        :xref => "x",
        :x => x,
        :yref => "y",
        :y => y,
        :showarrow => false,
    )
end

function get_annotation_dict(x, y, ptxt::PlotText)
    merge(get_annotation_dict(x, y, ptxt.str), KW(
        :font => plotlyfont(ptxt.font),
        :xanchor => ptxt.font.halign == :hcenter ? :center : ptxt.font.halign,
        :yanchor => ptxt.font.valign == :vcenter ? :middle : ptxt.font.valign,
        :rotation => ptxt.font.rotation,
    ))
end

# function get_annotation_dict_for_arrow(d::KW, xyprev::Tuple, xy::Tuple, a::Arrow)
#     xdiff = xyprev[1] - xy[1]
#     ydiff = xyprev[2] - xy[2]
#     dist = sqrt(xdiff^2 + ydiff^2)
#     KW(
#         :showarrow => true,
#         :x => xy[1],
#         :y => xy[2],
#         # :ax => xyprev[1] - xy[1],
#         # :ay => xy[2] - xyprev[2],
#         # :ax => 0,
#         # :ay => -40,
#         :ax => 10xdiff / dist,
#         :ay => -10ydiff / dist,
#         :arrowcolor => webcolor(d[:linecolor], d[:linealpha]),
#         :xref => "x",
#         :yref => "y",
#         :arrowsize => 10a.headwidth,
#         # :arrowwidth => a.headlength,
#         :arrowwidth => 0.1,
#     )
# end

function plotlyscale(scale::Symbol)
    if scale == :log10
        "log"
    else
        "-"
    end
end

use_axis_field(ticks) = !(ticks in (nothing, :none))

# tickssym(letter) = symbol(letter * "ticks")
# limssym(letter) = symbol(letter * "lims")
# flipsym(letter) = symbol(letter * "flip")
# scalesym(letter) = symbol(letter * "scale")
# labelsym(letter) = symbol(letter * "label")
# rotationsym(letter) = symbol(letter * "rotation")

function plotlyaxis(axis::Axis, sp::Subplot{PlotlyBackend})
    letter = axis[:letter]
    d = axis.d
    ax = KW(
        :title      => d[:guide],
        :showgrid   => sp.attr[:grid],
        :zeroline   => false,
    )

    # fgcolor = webcolor(d[:foreground_color])
    # tsym = tickssym(letter)

    rot = d[:rotation]
    if rot != 0
        ax[:tickangle] = rot
    end

    if use_axis_field(d[:ticks])
        ax[:titlefont] = plotlyfont(d[:guidefont], webcolor(d[:foreground_color_guide]))
        ax[:type] = plotlyscale(d[:scale])
        ax[:tickfont] = plotlyfont(d[:tickfont], webcolor(d[:foreground_color_text]))
        ax[:tickcolor] = webcolor(d[:foreground_color_border])
        ax[:linecolor] = webcolor(d[:foreground_color_border])

        # lims
        lims = d[:lims]
        if lims != :auto && limsType(lims) == :limits
            ax[:range] = lims
        end

        # flip
        if d[:flip]
            ax[:autorange] = "reversed"
        end

        # ticks
        ticks = d[:ticks]
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
    else
        ax[:showticklabels] = false
        ax[:showgrid] = false
    end

    ax
end

# function get_plot_json(plt::Plot{PlotlyBackend})
#   d = plt.attr
# function plotly_layout(d::KW, seriesargs::AVec{KW})
function plotly_layout(plt::Plot{PlotlyBackend})
    d_out = KW()

    # for now, we only support 1 subplot
    if length(plt.subplots) > 1
        warn("Subplots not supported yet")
    end
    sp = plt.subplots[1]

    d_out[:width], d_out[:height] = plt.attr[:size]

    # set the fields for the plot
    d_out[:title] = sp.attr[:title]
    d_out[:titlefont] = plotlyfont(sp.attr[:titlefont], webcolor(sp.attr[:foreground_color_title]))

    # TODO: use subplot positioning logic
    d_out[:margin] = KW(:l=>35, :b=>30, :r=>8, :t=>20)

    d_out[:plot_bgcolor] = webcolor(sp.attr[:background_color_inside])
    d_out[:paper_bgcolor] = webcolor(plt.attr[:background_color_outside])

    # TODO: x/y axis tick values/labels

    # if any(is3d, seriesargs)
    if is3d(sp)
        d_out[:scene] = KW(
            :xaxis => plotlyaxis(sp.attr[:xaxis], sp),
            :yaxis => plotlyaxis(sp.attr[:yaxis], sp),
            :xzxis => plotlyaxis(sp.attr[:zaxis], sp),
        )
    else
        d_out[:xaxis] = plotlyaxis(sp.attr[:xaxis], sp)
        d_out[:yaxis] = plotlyaxis(sp.attr[:yaxis], sp)
    end

    # legend
    d_out[:showlegend] = sp.attr[:legend] != :none
    if sp.attr[:legend] != :none
        d_out[:legend] = KW(
            :bgcolor  => webcolor(sp.attr[:background_color_legend]),
            :bordercolor => webcolor(sp.attr[:foreground_color_legend]),
            :font     => plotlyfont(sp.attr[:legendfont]),
        )
    end

    # if haskey(plt.attr, :annotation_list)
    #   append!(plt.attr[:annotation_list], anns)
    # else
    #   plt.attr[:annotation_list] = anns
    # end

    # annotations
    anns = get(sp.attr, :annotations, [])
    d_out[:annotations] = if isempty(anns)
        KW[]
    else
        KW[get_annotation_dict(ann...) for ann in anns]
    end

    # # arrows
    # for sargs in seriesargs
    #     a = sargs[:arrow]
    #     if sargs[:seriestype] in (:path, :line) && typeof(a) <: Arrow
    #         add_arrows(sargs[:x], sargs[:y]) do xyprev, xy
    #             push!(d_out[:annotations], get_annotation_dict_for_arrow(sargs, xyprev, xy, a))
    #         end
    #     end
    # end
    # dumpdict(d_out,"",true)
    # @show d_out[:annotations]

    if ispolar(sp)
        d_out[:direction] = "counterclockwise"
    end

    d_out
end

function get_plot_json(plt::Plot{PlotlyBackend})
    JSON.json(plotly_layout(plt))
end


function plotly_colorscale(grad::ColorGradient, alpha = nothing)
    [[grad.values[i], webcolor(grad.colors[i], alpha)] for i in 1:length(grad.colors)]
end
plotly_colorscale(c, alpha = nothing) = plotly_colorscale(default_gradient(), alpha)

const _plotly_markers = KW(
    :rect       => "square",
    :xcross     => "x",
    :utriangle  => "triangle-up",
    :dtriangle  => "triangle-down",
    :star5      => "star-triangle-up",
    :vline      => "line-ns",
    :hline      => "line-ew",
)

# get a dictionary representing the series params (d is the Plots-dict, d_out is the Plotly-dict)
function plotly_series(plt::Plot{PlotlyBackend}, series::Series)
    d = series.d
    d_out = KW()

    x, y = collect(d[:x]), collect(d[:y])
    d_out[:name] = d[:label]

    st = d[:seriestype]
    isscatter = st in (:scatter, :scatter3d)
    hasmarker = isscatter || d[:markershape] != :none
    hasline = !isscatter

    # set the "type"
    if st in (:line, :path, :scatter, :steppre, :steppost)
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

    elseif st == :bar
        d_out[:type] = "bar"
        d_out[:x], d_out[:y] = x, y

    elseif st == :hist2d
        d_out[:type] = "histogram2d"
        d_out[:x], d_out[:y] = x, y
        if isa(d[:bins], Tuple)
            xbins, ybins = d[:bins]
        else
            xbins = ybins = d[:bins]
        end
        d_out[:nbinsx] = xbins
        d_out[:nbinsy] = ybins

    elseif st in (:hist, :density)
        d_out[:type] = "histogram"
        isvert = isvertical(d)
        d_out[isvert ? :x : :y] = y
        d_out[isvert ? :nbinsx : :nbinsy] = d[:bins]
        if st == :density
            d_out[:histnorm] = "probability density"
        end

    elseif st == :heatmap
        d_out[:type] = "heatmap"
        d_out[:x], d_out[:y] = x, y
        d_out[:z] = d[:z].surf
        d_out[:colorscale] = plotly_colorscale(d[:fillcolor], d[:fillalpha])

    elseif st == :contour
        d_out[:type] = "contour"
        d_out[:x], d_out[:y] = x, y
        d_out[:z] = d[:z].surf
        # d_out[:showscale] = d[:colorbar] != :none
        d_out[:ncontours] = d[:levels]
        d_out[:contours] = KW(:coloring => d[:fillrange] != nothing ? "fill" : "lines")
        d_out[:colorscale] = plotly_colorscale(d[:linecolor], d[:linealpha])

    elseif st in (:surface, :wireframe)
        d_out[:type] = "surface"
        d_out[:x], d_out[:y] = x, y
        d_out[:z] = d[:z].surf
        d_out[:colorscale] = plotly_colorscale(d[:fillcolor], d[:fillalpha])

    elseif st == :pie
        d_out[:type] = "pie"
        d_out[:labels] = x
        d_out[:values] = y
        d_out[:hoverinfo] = "label+percent+name"

    elseif st in (:path3d, :scatter3d)
        d_out[:type] = "scatter3d"
        d_out[:mode] = if hasmarker
            hasline ? "lines+markers" : "markers"
        else
            hasline ? "lines" : "none"
        end
        d_out[:x], d_out[:y] = x, y
        d_out[:z] = collect(d[:z])

    else
        warn("Plotly: seriestype $st isn't supported.")
        return KW()
    end

    # add "marker"
    if hasmarker
        d_out[:marker] = KW(
            :symbol => get(_plotly_markers, d[:markershape], string(d[:markershape])),
            :opacity => d[:markeralpha],
            :size => 2 * d[:markersize],
            :color => webcolor(d[:markercolor], d[:markeralpha]),
            :line => KW(
                :color => webcolor(d[:markerstrokecolor], d[:markerstrokealpha]),
                :width => d[:markerstrokewidth],
            ),
        )

        # gotta hack this (for now?) since plotly can't handle rgba values inside the gradient
        if d[:marker_z] != nothing
            # d_out[:marker][:color] = d[:marker_z]
            # d_out[:marker][:colorscale] = plotly_colorscale(d[:markercolor], d[:markeralpha])
            # d_out[:showscale] = true
            grad = ColorGradient(d[:markercolor], alpha=d[:markeralpha])
            zmin, zmax = extrema(d[:marker_z])
            d_out[:marker][:color] = [webcolor(getColorZ(grad, (zi - zmin) / (zmax - zmin))) for zi in d[:marker_z]]
        end
    end

    # add "line"
    if hasline
        d_out[:line] = KW(
            :color => webcolor(d[:linecolor], d[:linealpha]),
            :width => d[:linewidth],
            :shape => if st == :steppre
                "vh"
            elseif st == :steppost
                "hv"
            else
                "linear"
            end,
            :dash => string(d[:linestyle]),
            # :dash => "solid",
        )
    end

    # convert polar plots x/y to theta/radius
    if ispolar(d[:subplot])
        d_out[:t] = rad2deg(pop!(d_out, :x))
        d_out[:r] = pop!(d_out, :y)
    end

    d_out
end

# get a list of dictionaries, each representing the series params
function get_series_json(plt::Plot{PlotlyBackend})
    JSON.json(map(series -> plotly_series(plt, series), plt.series_list))
end

# ----------------------------------------------------------------

function html_head(plt::AbstractPlot{PlotlyBackend})
    "<script src=\"$(Pkg.dir("Plots","deps","plotly-latest.min.js"))\"></script>"
end

function html_body(plt::Plot{PlotlyBackend}, style = nothing)
    if style == nothing
        w, h = plt.attr[:size]
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
    html
end

function js_body(plt::Plot{PlotlyBackend}, uuid)
    js = """
          PLOT = document.getElementById('$(uuid)');
          Plotly.plot(PLOT, $(get_series_json(plt)), $(get_plot_json(plt)));
    """
end


# ----------------------------------------------------------------

function Base.writemime(io::IO, ::MIME"image/png", plt::AbstractPlot{PlotlyBackend})
    writemime_png_from_html(io, plt)
end

function Base.writemime(io::IO, ::MIME"text/html", plt::AbstractPlot{PlotlyBackend})
    write(io, html_head(plt) * html_body(plt))
end

function Base.display(::PlotsDisplay, plt::AbstractPlot{PlotlyBackend})
  standalone_html_window(plt)
end
