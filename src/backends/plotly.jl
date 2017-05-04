
# https://plot.ly/javascript/getting-started

const _plotly_attr = merge_with_base_supported([
    :annotations,
    :background_color_legend, :background_color_inside, :background_color_outside,
    :foreground_color_legend, :foreground_color_guide,
    # :foreground_color_grid, :foreground_color_axis,
    :foreground_color_text, :foreground_color_border,
    :foreground_color_title,
    :label,
    :seriescolor, :seriesalpha,
    :linecolor, :linestyle, :linewidth, :linealpha,
    :markershape, :markercolor, :markersize, :markeralpha,
    :markerstrokewidth, :markerstrokecolor, :markerstrokealpha, :markerstrokestyle,
    :fillrange, :fillcolor, :fillalpha,
    :bins,
    :title, :title_location, :titlefont,
    :window_title,
    :guide, :lims, :ticks, :scale, :flip, :rotation,
    :tickfont, :guidefont, :legendfont,
    :grid, :legend, :colorbar, :colorbar_title,
    :marker_z, :fill_z, :levels,
    :ribbon, :quiver,
    :orientation,
    # :overwrite_figure,
    :polar,
    :normalize, :weights,
    # :contours,
    :aspect_ratio,
    :hover,
    :inset_subplots,
    :bar_width,
    :clims,
  ])

const _plotly_seriestype = [
    :path, :scatter, :bar, :pie, :heatmap,
    :contour, :surface, :wireframe, :path3d, :scatter3d, :shape, :scattergl,
]
const _plotly_style = [:auto, :solid, :dash, :dot, :dashdot]
const _plotly_marker = [
    :none, :auto, :circle, :rect, :diamond, :utriangle, :dtriangle,
    :cross, :xcross, :pentagon, :hexagon, :octagon, :vline, :hline
]
const _plotly_scale = [:identity, :log10]
is_subplot_supported(::PlotlyBackend) = true
# is_string_supported(::PlotlyBackend) = true


# --------------------------------------------------------------------------------------

function add_backend_string(::PlotlyBackend)
    """
    Pkg.build("Plots")
    """
end


const _plotly_js_path = joinpath(dirname(@__FILE__), "..", "..", "deps", "plotly-latest.min.js")
const _plotly_js_path_remote = "https://cdn.plot.ly/plotly-latest.min.js"

function _initialize_backend(::PlotlyBackend; kw...)
  @eval begin
    import JSON

    _js_code = open(readstring, _plotly_js_path, "r")

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


# ----------------------------------------------------------------

const _plotly_legend_pos = KW(
    :right => [1., 0.5],
    :left => [0., 0.5],
    :top => [0.5, 1.],
    :bottom => [0.5, 0.],
    :bottomleft => [0., 0.],
    :bottomright => [1., 0.],
    :topright => [1., 1.],
    :topleft => [0., 1.]
    )

plotly_legend_pos(pos::Symbol) = get(_plotly_legend_pos, pos, [1.,1.])
plotly_legend_pos{S<:Real, T<:Real}(v::Tuple{S,T}) = v

function plotly_font(font::Font, color = font.color)
    KW(
        :family => font.family,
        :size   => round(Int, font.pointsize*1.4),
        :color  => rgba_string(color),
    )
end


function plotly_annotation_dict(x, y, val; xref="paper", yref="paper")
    KW(
        :text => val,
        :xref => xref,
        :x => x,
        :yref => xref,
        :y => y,
        :showarrow => false,
    )
end

function plotly_annotation_dict(x, y, ptxt::PlotText; xref="paper", yref="paper")
    merge(plotly_annotation_dict(x, y, ptxt.str; xref=xref, yref=yref), KW(
        :font => plotly_font(ptxt.font),
        :xanchor => ptxt.font.halign == :hcenter ? :center : ptxt.font.halign,
        :yanchor => ptxt.font.valign == :vcenter ? :middle : ptxt.font.valign,
        :rotation => -ptxt.font.rotation,
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
#         :arrowcolor => rgba_string(d[:linecolor]),
#         :xref => "x",
#         :yref => "y",
#         :arrowsize => 10a.headwidth,
#         # :arrowwidth => a.headlength,
#         :arrowwidth => 0.1,
#     )
# end

function plotly_scale(scale::Symbol)
    if scale == :log10
        "log"
    else
        "-"
    end
end

function shrink_by(lo, sz, ratio)
    amt = 0.5 * (1.0 - ratio) * sz
    lo + amt, sz - 2amt
end

function plotly_apply_aspect_ratio(sp::Subplot, plotarea, pcts)
    aspect_ratio = sp[:aspect_ratio]
    if aspect_ratio != :none
        if aspect_ratio == :equal
            aspect_ratio = 1.0
        end
        xmin,xmax = axis_limits(sp[:xaxis])
        ymin,ymax = axis_limits(sp[:yaxis])
        want_ratio = ((xmax-xmin) / (ymax-ymin)) / aspect_ratio
        parea_ratio = width(plotarea) / height(plotarea)
        if want_ratio > parea_ratio
            # need to shrink y
            ratio = parea_ratio / want_ratio
            pcts[2], pcts[4] = shrink_by(pcts[2], pcts[4], ratio)
        elseif want_ratio < parea_ratio
            # need to shrink x
            ratio = want_ratio / parea_ratio
            pcts[1], pcts[3] = shrink_by(pcts[1], pcts[3], ratio)
        end
        pcts
    end
    pcts
end


# this method gets the start/end in percentage of the canvas for this axis direction
function plotly_domain(sp::Subplot, letter)
    figw, figh = sp.plt[:size]
    pcts = bbox_to_pcts(sp.plotarea, figw*px, figh*px)
    pcts = plotly_apply_aspect_ratio(sp, sp.plotarea, pcts)
    i1,i2 = (letter == :x ? (1,3) : (2,4))
    [pcts[i1], pcts[i1]+pcts[i2]]
end


function plotly_axis(axis::Axis, sp::Subplot)
    letter = axis[:letter]
    ax = KW(
        :title      => axis[:guide],
        :showgrid   => sp[:grid],
        :zeroline   => false,
        :ticks      => "inside",
    )

    if letter in (:x,:y)
        ax[:domain] = plotly_domain(sp, letter)
        ax[:anchor] = "$(letter==:x ? :y : :x)$(plotly_subplot_index(sp))"
    end

    ax[:tickangle] = -axis[:rotation]

    if !(axis[:ticks] in (nothing, :none))
        ax[:titlefont] = plotly_font(axis[:guidefont], axis[:foreground_color_guide])
        ax[:type] = plotly_scale(axis[:scale])
        ax[:tickfont] = plotly_font(axis[:tickfont], axis[:foreground_color_text])
        ax[:tickcolor] = rgba_string(axis[:foreground_color_border])
        ax[:linecolor] = rgba_string(axis[:foreground_color_border])

        # lims
        lims = axis[:lims]
        if lims != :auto && limsType(lims) == :limits
            ax[:range] = map(scalefunc(axis[:scale]), lims)
        end

        # flip
        if axis[:flip]
            ax[:autorange] = "reversed"
        end

        # ticks
        ticks = get_ticks(axis)
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

function plotly_layout(plt::Plot)
    d_out = KW()

    w, h = plt[:size]
    d_out[:width], d_out[:height] = w, h
    d_out[:paper_bgcolor] = rgba_string(plt[:background_color_outside])
    d_out[:margin] = KW(:l=>0, :b=>0, :r=>0, :t=>20)

    d_out[:annotations] = KW[]

    for sp in plt.subplots
        spidx = plotly_subplot_index(sp)


        # add an annotation for the title... positioned horizontally relative to plotarea,
        # but vertically just below the top of the subplot bounding box
        if sp[:title] != ""
            bb = plotarea(sp)
            tpos = sp[:title_location]
            xmm = if tpos == :left
                left(bb)
            elseif tpos == :right
                right(bb)
            else
                0.5 * (left(bb) + right(bb))
            end
            titlex, titley = xy_mm_to_pcts(xmm, top(bbox(sp)), w*px, h*px)
            titlefont = font(sp[:titlefont], :top, sp[:foreground_color_title])
            push!(d_out[:annotations], plotly_annotation_dict(titlex, titley, text(sp[:title], titlefont)))
        end

        d_out[:plot_bgcolor] = rgba_string(sp[:background_color_inside])

        # if any(is3d, seriesargs)
        if is3d(sp)
            d_out[:scene] = KW(
                Symbol("xaxis$spidx") => plotly_axis(sp[:xaxis], sp),
                Symbol("yaxis$spidx") => plotly_axis(sp[:yaxis], sp),
                Symbol("zaxis$spidx") => plotly_axis(sp[:zaxis], sp),
            )
        else
            d_out[Symbol("xaxis$spidx")] = plotly_axis(sp[:xaxis], sp)
            d_out[Symbol("yaxis$spidx")] = plotly_axis(sp[:yaxis], sp)
        end

        # legend
        d_out[:showlegend] = sp[:legend] != :none
        xpos,ypos = plotly_legend_pos(sp[:legend])
        if sp[:legend] != :none
            d_out[:legend] = KW(
                :bgcolor  => rgba_string(sp[:background_color_legend]),
                :bordercolor => rgba_string(sp[:foreground_color_legend]),
                :font     => plotly_font(sp[:legendfont], sp[:foreground_color_legend]),
                :x => xpos,
                :y => ypos
            )
        end

        # annotations
        append!(d_out[:annotations], KW[plotly_annotation_dict(ann...; xref = "x$spidx", yref = "y$spidx") for ann in sp[:annotations]])

        # series_annotations
        for series in series_list(sp)
            anns = series[:series_annotations]
            for (xi,yi,str,fnt) in EachAnn(anns, series[:x], series[:y])
                push!(d_out[:annotations], plotly_annotation_dict(
                    xi,
                    yi,
                    PlotText(str,fnt); xref = "x$spidx", yref = "y$spidx")
                )
            end
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

        if ispolar(sp)
            d_out[:direction] = "counterclockwise"
        end

        d_out
    end

    # turn off hover if nothing's using it
    if all(series -> series.d[:hover] in (false,:none), plt.series_list)
        d_out[:hovermode] = "none"
    end

    d_out
end

function plotly_layout_json(plt::Plot)
    JSON.json(plotly_layout(plt))
end


function plotly_colorscale(grad::ColorGradient, α)
    [[grad.values[i], rgb_string(grad.colors[i])] for i in 1:length(grad.colors)]
end
plotly_colorscale(c, α) = plotly_colorscale(cgrad(alpha=α), α)
# plotly_colorscale(c, alpha = nothing) = plotly_colorscale(cgrad(), alpha)


const _plotly_markers = KW(
    :rect       => "square",
    :xcross     => "x",
    :x          => "x",
    :utriangle  => "triangle-up",
    :dtriangle  => "triangle-down",
    :star5      => "star-triangle-up",
    :vline      => "line-ns",
    :hline      => "line-ew",
)

function plotly_subplot_index(sp::Subplot)
    spidx = sp[:subplot_index]
    spidx == 1 ? "" : spidx
end


# the Shape contructor will automatically close the shape. since we need it closed,
# we split by NaNs and then construct/destruct the shapes to get the closed coords
function plotly_close_shapes(x, y)
    xs, ys = nansplit(x), nansplit(y)
    for i=1:length(xs)
        shape = Shape(xs[i], ys[i])
        xs[i], ys[i] = coords(shape)
    end
    nanvcat(xs), nanvcat(ys)
end

plotly_data(v) = collect(v)
plotly_data(surf::Surface) = surf.surf
plotly_data{R<:Rational}(v::AbstractArray{R}) = float(v)

plotly_surface_data(series::Series, a::AbstractVector) = a
plotly_surface_data(series::Series, a::AbstractMatrix) = transpose_z(series, a, false)
plotly_surface_data(series::Series, a::Surface) = plotly_surface_data(series, a.surf)

#ensures that a gradient is called if a single color is supplied where a gradient is needed (e.g. if a series recipe defines marker_z)
as_gradient(grad::ColorGradient, α) = grad
as_gradient(grad, α) = cgrad(alpha = α)

# allows passing a ColorGradient where a single color is expected - the other backends allow this
PlotUtils.rgba_string(cg::ColorGradient) = rgba_string(cg[1])

# get a dictionary representing the series params (d is the Plots-dict, d_out is the Plotly-dict)
function plotly_series(plt::Plot, series::Series)
    st = series[:seriestype]
    if st == :shape
        return plotly_series_shapes(plt, series)
    end

    sp = series[:subplot]
    d_out = KW()

    # these are the axes that the series should be mapped to
    spidx = plotly_subplot_index(sp)
    d_out[:xaxis] = "x$spidx"
    d_out[:yaxis] = "y$spidx"
    d_out[:showlegend] = should_add_to_legend(series)

    x, y = plotly_data(series[:x]), plotly_data(series[:y])
    d_out[:name] = series[:label]

    isscatter = st in (:scatter, :scatter3d, :scattergl)
    hasmarker = isscatter || series[:markershape] != :none
    hasline = st in (:path, :path3d)

    # for surface types, set the data
    if st in (:heatmap, :contour, :surface, :wireframe)
        for letter in [:x,:y,:z]
            d_out[letter] = plotly_surface_data(series, series[letter])
        end
    end

    d_out[:colorbar] = KW(:title => sp[:colorbar_title])

    clims = sp[:clims]
    if is_2tuple(clims)
        d_out[:zmin], d_out[:zmax] = clims
    end

    # set the "type"
    if st in (:path, :scatter, :scattergl)
        d_out[:type] = st==:scattergl ? "scattergl" : "scatter"
        d_out[:mode] = if hasmarker
            hasline ? "lines+markers" : "markers"
        else
            hasline ? "lines" : "none"
        end
        if series[:fillrange] == true || series[:fillrange] == 0
            d_out[:fill] = "tozeroy"
            d_out[:fillcolor] = rgba_string(series[:fillcolor])
        elseif !(series[:fillrange] in (false, nothing))
            warn("fillrange ignored... plotly only supports filling to zero. fillrange: $(series[:fillrange])")
        end
        d_out[:x], d_out[:y] = x, y

    elseif st == :bar
        d_out[:type] = "bar"
        d_out[:x], d_out[:y], d_out[:orientation] = if isvertical(series)
            x, y, "v"
        else
            y, x, "h"
        end
        d_out[:marker] = KW(:color => rgba_string(series[:fillcolor]))

    elseif st == :heatmap
        d_out[:type] = "heatmap"
        # d_out[:x], d_out[:y], d_out[:z] = series[:x], series[:y], transpose_z(series, series[:z].surf, false)
        d_out[:colorscale] = plotly_colorscale(series[:fillcolor], series[:fillalpha])

    elseif st == :contour
        d_out[:type] = "contour"
        # d_out[:x], d_out[:y], d_out[:z] = series[:x], series[:y], transpose_z(series, series[:z].surf, false)
        # d_out[:showscale] = series[:colorbar] != :none
        d_out[:ncontours] = series[:levels]
        d_out[:contours] = KW(:coloring => series[:fillrange] != nothing ? "fill" : "lines")
        d_out[:colorscale] = plotly_colorscale(series[:linecolor], series[:linealpha])

    elseif st in (:surface, :wireframe)
        d_out[:type] = "surface"
        # d_out[:x], d_out[:y], d_out[:z] = series[:x], series[:y], transpose_z(series, series[:z].surf, false)
        if st == :wireframe
            d_out[:hidesurface] = true
            wirelines = KW(
                :show => true,
                :color => rgba_string(series[:linecolor]),
                :highlightwidth => series[:linewidth],
            )
            d_out[:contours] = KW(:x => wirelines, :y => wirelines, :z => wirelines)
        else
            d_out[:colorscale] = plotly_colorscale(series[:fillcolor], series[:fillalpha])
            if series[:fill_z] != nothing
                d_out[:surfacecolor] = plotly_surface_data(series, series[:fill_z])
            end
        end

    elseif st == :pie
        d_out[:type] = "pie"
        d_out[:labels] = pie_labels(sp, series)
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
        d_out[:z] = plotly_data(series[:z])

    else
        warn("Plotly: seriestype $st isn't supported.")
        return KW()
    end

    # add "marker"
    if hasmarker
        d_out[:marker] = KW(
            :symbol => get(_plotly_markers, series[:markershape], string(series[:markershape])),
            # :opacity => series[:markeralpha],
            :size => 2 * series[:markersize],
            # :color => rgba_string(series[:markercolor]),
            :line => KW(
                :color => rgba_string(series[:markerstrokecolor]),
                :width => series[:markerstrokewidth],
            ),
        )

        # gotta hack this (for now?) since plotly can't handle rgba values inside the gradient
        d_out[:marker][:color] = if series[:marker_z] == nothing
            rgba_string(series[:markercolor])
        else
            # grad = ColorGradient(series[:markercolor], alpha=series[:markeralpha])
            grad = as_gradient(series[:markercolor], series[:markeralpha])
            zmin, zmax = extrema(series[:marker_z])
            zrange = zmax == zmin ? 1 : zmax - zmin # if all marker_z values are the same, plot all markers same color (avoids division by zero in next line)
            [rgba_string(grad[(zi - zmin) / zrange]) for zi in series[:marker_z]]
        end
    end

    # add "line"
    if hasline
        d_out[:line] = KW(
            :color => rgba_string(series[:linecolor]),
            :width => series[:linewidth],
            :shape => if st == :steppre
                "vh"
            elseif st == :steppost
                "hv"
            else
                "linear"
            end,
            :dash => string(series[:linestyle]),
            # :dash => "solid",
        )
    end

    plotly_polar!(d_out, series)
    plotly_hover!(d_out, series[:hover])

    [d_out]
end

function plotly_series_shapes(plt::Plot, series::Series)
    d_outs = []

    # TODO: create a d_out for each polygon
    # x, y = series[:x], series[:y]

    # these are the axes that the series should be mapped to
    spidx = plotly_subplot_index(series[:subplot])
    base_d = KW()
    base_d[:xaxis] = "x$spidx"
    base_d[:yaxis] = "y$spidx"
    base_d[:name] = series[:label]
    # base_d[:legendgroup] = series[:label]

    x, y = plotly_data(series[:x]), plotly_data(series[:y])
    for (i,rng) in enumerate(iter_segments(x,y))
        length(rng) < 2 && continue

        # to draw polygons, we actually draw lines with fill
        d_out = merge(base_d, KW(
            :type => "scatter",
            :mode => "lines",
            :x => vcat(x[rng], x[rng[1]]),
            :y => vcat(y[rng], y[rng[1]]),
            :fill => "tozeroy",
            :fillcolor => rgba_string(_cycle(series[:fillcolor], i)),
        ))
        if series[:markerstrokewidth] > 0
            d_out[:line] = KW(
                :color => rgba_string(_cycle(series[:linecolor], i)),
                :width => series[:linewidth],
                :dash => string(series[:linestyle]),
            )
        end
        d_out[:showlegend] = i==1 ? should_add_to_legend(series) : false
        plotly_polar!(d_out, series)
        plotly_hover!(d_out, _cycle(series[:hover], i))
        push!(d_outs, d_out)
    end
    d_outs
end

function plotly_polar!(d_out::KW, series::Series)
    # convert polar plots x/y to theta/radius
    if ispolar(series[:subplot])
        d_out[:t] = rad2deg(pop!(d_out, :x))
        d_out[:r] = pop!(d_out, :y)
    end
end

function plotly_hover!(d_out::KW, hover)
    # hover text
    if hover in (:none, false)
        d_out[:hoverinfo] = "none"
    elseif hover != nothing
        d_out[:hoverinfo] = "text"
        d_out[:text] = hover
    end
end

# get a list of dictionaries, each representing the series params
function plotly_series_json(plt::Plot)
    slist = []
    for series in plt.series_list
        append!(slist, plotly_series(plt, series))
    end
    JSON.json(slist)
    # JSON.json(map(series -> plotly_series(plt, series), plt.series_list))
end

# ----------------------------------------------------------------

const _use_remote = Ref(false)

function html_head(plt::Plot{PlotlyBackend})
    jsfilename = _use_remote[] ? _plotly_js_path_remote : _plotly_js_path
    # "<script src=\"$(joinpath(dirname(@__FILE__),"..","..","deps","plotly-latest.min.js"))\"></script>"
    "<script src=\"$jsfilename\"></script>"
end

function html_body(plt::Plot{PlotlyBackend}, style = nothing)
    if style == nothing
        w, h = plt[:size]
        style = "width:$(w)px;height:$(h)px;"
    end
    uuid = Base.Random.uuid4()
    html = """
        <div id=\"$(uuid)\" style=\"$(style)\"></div>
        <script>
        PLOT = document.getElementById('$(uuid)');
        Plotly.plot(PLOT, $(plotly_series_json(plt)), $(plotly_layout_json(plt)));
        </script>
    """
    html
end

function js_body(plt::Plot{PlotlyBackend}, uuid)
    js = """
          PLOT = document.getElementById('$(uuid)');
          Plotly.plot(PLOT, $(plotly_series_json(plt)), $(plotly_layout_json(plt)));
    """
end


# ----------------------------------------------------------------


function _show(io::IO, ::MIME"image/png", plt::Plot{PlotlyBackend})
    # show_png_from_html(io, plt)
    error("png output from the plotly backend is not supported.  Please use plotlyjs instead.")
end

function _show(io::IO, ::MIME"image/svg+xml", plt::Plot{PlotlyBackend})
    write(io, html_head(plt) * html_body(plt))
end

function _display(plt::Plot{PlotlyBackend})
    standalone_html_window(plt)
end
