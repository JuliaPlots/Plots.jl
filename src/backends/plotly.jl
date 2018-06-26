
# https://plot.ly/javascript/getting-started

@require Revise begin
    Revise.track(Plots, joinpath(Pkg.dir("Plots"), "src", "backends", "plotly.jl"))
end

const _plotly_attr = merge_with_base_supported([
    :annotations,
    :background_color_legend, :background_color_inside, :background_color_outside,
    :foreground_color_legend, :foreground_color_guide,
    :foreground_color_grid, :foreground_color_axis,
    :foreground_color_text, :foreground_color_border,
    :foreground_color_title,
    :label,
    :seriescolor, :seriesalpha,
    :linecolor, :linestyle, :linewidth, :linealpha,
    :markershape, :markercolor, :markersize, :markeralpha,
    :markerstrokewidth, :markerstrokecolor, :markerstrokealpha, :markerstrokestyle,
    :fillrange, :fillcolor, :fillalpha,
    :bins,
    :title, :title_location,
    :titlefontfamily, :titlefontsize, :titlefonthalign, :titlefontvalign,
    :titlefontcolor,
    :legendfontfamily, :legendfontsize, :legendfontcolor,
    :tickfontfamily, :tickfontsize, :tickfontcolor,
    :guidefontfamily, :guidefontsize, :guidefontcolor,
    :window_title,
    :guide, :lims, :ticks, :scale, :flip, :rotation,
    :tickfont, :guidefont, :legendfont,
    :grid, :gridalpha, :gridlinewidth,
    :legend, :colorbar, :colorbar_title,
    :marker_z, :fill_z, :line_z, :levels,
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
    :framestyle,
    :tick_direction,
    :camera,
    :contour_labels,
  ])

const _plotly_seriestype = [
    :path, :scatter, :pie, :heatmap,
    :contour, :surface, :wireframe, :path3d, :scatter3d, :shape, :scattergl,
    :straightline
]
const _plotly_style = [:auto, :solid, :dash, :dot, :dashdot]
const _plotly_marker = [
    :none, :auto, :circle, :rect, :diamond, :utriangle, :dtriangle,
    :cross, :xcross, :pentagon, :hexagon, :octagon, :vline, :hline
]
const _plotly_scale = [:identity, :log10]
is_subplot_supported(::PlotlyBackend) = true
# is_string_supported(::PlotlyBackend) = true
const _plotly_framestyles = [:box, :axes, :zerolines, :grid, :none]
const _plotly_framestyle_defaults = Dict(:semi => :box, :origin => :zerolines)
function _plotly_framestyle(style::Symbol)
    if style in _plotly_framestyles
        return style
    else
        default_style = get(_plotly_framestyle_defaults, style, :axes)
        warn("Framestyle :$style is not supported by Plotly and PlotlyJS. :$default_style was cosen instead.")
        default_style
    end
end


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
plotly_legend_pos(v::Tuple{S,T}) where {S<:Real, T<:Real} = v

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
        :yref => yref,
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


function plotly_axis(plt::Plot, axis::Axis, sp::Subplot)
    letter = axis[:letter]
    framestyle = sp[:framestyle]
    ax = KW(
        :visible    => framestyle != :none,
        :title      => axis[:guide],
        :showgrid   => axis[:grid],
        :gridcolor  => rgba_string(plot_color(axis[:foreground_color_grid], axis[:gridalpha])),
        :gridwidth  => axis[:gridlinewidth],
        :zeroline   => framestyle == :zerolines,
        :zerolinecolor => rgba_string(axis[:foreground_color_axis]),
        :showline   => framestyle in (:box, :axes) && axis[:showaxis],
        :linecolor  => rgba_string(plot_color(axis[:foreground_color_axis])),
        :ticks      => axis[:tick_direction] == :out ? "outside" : "inside",
        :mirror     => framestyle == :box,
        :showticklabels => axis[:showaxis],
    )

    if letter in (:x,:y)
        ax[:domain] = plotly_domain(sp, letter)
        if is3d(sp)
            # don't link 3d axes for synchronized interactivity
            x_idx = y_idx = sp[:subplot_index]
        else
            x_idx, y_idx = plotly_link_indicies(plt, sp)
        end
        ax[:anchor] = "$(letter==:x ? "y$(y_idx)" : "x$(x_idx)")"
    end

    ax[:tickangle] = -axis[:rotation]
    ax[:type] = plotly_scale(axis[:scale])
    lims = axis_limits(axis)

    if axis[:ticks] != :native || axis[:lims] != :auto
        ax[:range] = map(scalefunc(axis[:scale]), lims)
    end

    if !(axis[:ticks] in (nothing, :none, false))
        ax[:titlefont] = plotly_font(guidefont(axis))
        ax[:tickfont] = plotly_font(tickfont(axis))
        ax[:tickcolor] = framestyle in (:zerolines, :grid) || !axis[:showaxis] ? rgba_string(invisible()) : rgb_string(axis[:foreground_color_axis])
        ax[:linecolor] = rgba_string(axis[:foreground_color_axis])

        # flip
        if axis[:flip]
            ax[:autorange] = "reversed"
        end

        # ticks
        if axis[:ticks] != :native
            ticks = get_ticks(axis)
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

function plotly_polaraxis(axis::Axis)
    ax = KW(
        :visible => axis[:showaxis],
        :showline => axis[:grid],
    )

    if axis[:letter] == :x
        ax[:range] = rad2deg.(axis_limits(axis))
    else
        ax[:range] = axis_limits(axis)
        ax[:orientation] = -90
    end

    ax
end

function plotly_layout(plt::Plot)
    d_out = KW()

    w, h = plt[:size]
    d_out[:width], d_out[:height] = w, h
    d_out[:paper_bgcolor] = rgba_string(plt[:background_color_outside])
    d_out[:margin] = KW(:l=>0, :b=>20, :r=>0, :t=>20)

    d_out[:annotations] = KW[]

    multiple_subplots = length(plt.subplots) > 1

    for sp in plt.subplots
        spidx = multiple_subplots ? sp[:subplot_index] : ""
        x_idx, y_idx = multiple_subplots ? plotly_link_indicies(plt, sp) : ("", "")
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
            title_font = font(titlefont(sp), :top)
            push!(d_out[:annotations], plotly_annotation_dict(titlex, titley, text(sp[:title], title_font)))
        end

        d_out[:plot_bgcolor] = rgba_string(sp[:background_color_inside])

        # set to supported framestyle
        sp[:framestyle] = _plotly_framestyle(sp[:framestyle])

        # if any(is3d, seriesargs)
        if is3d(sp)
            azim = sp[:camera][1] - 90 #convert azimuthal to match GR behaviour
            theta = 90 - sp[:camera][2] #spherical coordinate angle from z axis
            d_out[:scene] = KW(
                Symbol("xaxis$(spidx)") => plotly_axis(plt, sp[:xaxis], sp),
                Symbol("yaxis$(spidx)") => plotly_axis(plt, sp[:yaxis], sp),
                Symbol("zaxis$(spidx)") => plotly_axis(plt, sp[:zaxis], sp),

                #2.6 multiplier set camera eye such that whole plot can be seen
                :camera => KW(
                    :eye => KW(
                        :x => cosd(azim)*sind(theta)*2.6,
                        :y => sind(azim)*sind(theta)*2.6,
                        :z => cosd(theta)*2.6,
                    ),
                ),
            )
        elseif ispolar(sp)
            d_out[Symbol("angularaxis$(spidx)")] = plotly_polaraxis(sp[:xaxis])
            d_out[Symbol("radialaxis$(spidx)")] = plotly_polaraxis(sp[:yaxis])
        else
            d_out[Symbol("xaxis$(x_idx)")] = plotly_axis(plt, sp[:xaxis], sp)
            # don't allow yaxis to be reupdated/reanchored in a linked subplot
            spidx == y_idx ? d_out[Symbol("yaxis$(y_idx)")] = plotly_axis(plt, sp[:yaxis], sp) : nothing
        end

        # legend
        d_out[:showlegend] = sp[:legend] != :none
        xpos,ypos = plotly_legend_pos(sp[:legend])
        if sp[:legend] != :none
            d_out[:legend] = KW(
                :bgcolor  => rgba_string(sp[:background_color_legend]),
                :bordercolor => rgba_string(sp[:foreground_color_legend]),
                :font     => plotly_font(legendfont(sp)),
                :tracegroupgap => 0,
                :x => xpos,
                :y => ypos
            )
        end

        # annotations
        for ann in sp[:annotations]
            append!(d_out[:annotations], KW[plotly_annotation_dict(locate_annotation(sp, ann...)...; xref = "x$(x_idx)", yref = "y$(y_idx)")])
        end
        # series_annotations
        for series in series_list(sp)
            anns = series[:series_annotations]
            for (xi,yi,str,fnt) in EachAnn(anns, series[:x], series[:y])
                push!(d_out[:annotations], plotly_annotation_dict(
                    xi,
                    yi,
                    PlotText(str,fnt); xref = "x$(x_idx)", yref = "y$(y_idx)")
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
    [[grad.values[i], rgba_string(plot_color(grad.colors[i], α))] for i in 1:length(grad.colors)]
end
plotly_colorscale(c, α) = plotly_colorscale(cgrad(alpha=α), α)
function plotly_colorscale(c::AbstractVector{<:RGBA}, α)
    if length(c) == 1
        return [[0.0, rgba_string(plot_color(c[1], α))], [1.0, rgba_string(plot_color(c[1], α))]]
    else
        vals = linspace(0.0, 1.0, length(c))
        return [[vals[i], rgba_string(plot_color(c[i], α))] for i in eachindex(c)]
    end
end
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

# find indicies of axes to which the supblot links to
function plotly_link_indicies(plt::Plot, sp::Subplot)
    if plt[:link] in (:x, :y, :both)
        x_idx = sp[:xaxis].sps[1][:subplot_index]
        y_idx = sp[:yaxis].sps[1][:subplot_index]
    else
        x_idx = y_idx = sp[:subplot_index]
    end
    x_idx, y_idx
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

function plotly_data(series::Series, letter::Symbol, data)
    axis = series[:subplot][Symbol(letter, :axis)]

    data = if axis[:ticks] == :native && data != nothing
        plotly_native_data(axis, data)
    else
       data
    end

    if series[:seriestype] in (:heatmap, :contour, :surface, :wireframe)
        plotly_surface_data(series, data)
    else
        plotly_data(data)
    end
end
plotly_data(v) = v != nothing ? collect(v) : v
plotly_data(surf::Surface) = surf.surf
plotly_data(v::AbstractArray{R}) where {R<:Rational} = float(v)

plotly_surface_data(series::Series, a::AbstractVector) = a
plotly_surface_data(series::Series, a::AbstractMatrix) = transpose_z(series, a, false)
plotly_surface_data(series::Series, a::Surface) = plotly_surface_data(series, a.surf)

function plotly_native_data(axis::Axis, data::AbstractArray)
    if !isempty(axis[:discrete_values])
        construct_categorical_data(data, axis)
    elseif axis[:formatter] in (datetimeformatter, dateformatter, timeformatter)
        plotly_convert_to_datetime(data, axis[:formatter])
    else
        data
    end
end
plotly_native_data(axis::Axis, a::Surface) = Surface(plotly_native_data(axis, a.surf))

function plotly_convert_to_datetime(x::AbstractArray, formatter::Function)
    if formatter == datetimeformatter
        map(xi -> replace(formatter(xi), "T", " "), x)
    elseif formatter == dateformatter
        map(xi -> string(formatter(xi), " 00:00:00"), x)
    elseif formatter == timeformatter
        map(xi -> string(Dates.Date(Dates.now()), " ", formatter(xi)), x)
    else
        error("Invalid DateTime formatter. Expected Plots.datetime/date/time formatter but got $formatter")
    end
end
#ensures that a gradient is called if a single color is supplied where a gradient is needed (e.g. if a series recipe defines marker_z)
as_gradient(grad::ColorGradient, α) = grad
as_gradient(grad, α) = cgrad(alpha = α)

# get a dictionary representing the series params (d is the Plots-dict, d_out is the Plotly-dict)
function plotly_series(plt::Plot, series::Series)
    st = series[:seriestype]
    if st == :shape
        return plotly_series_shapes(plt, series)
    end

    sp = series[:subplot]
    d_out = KW()

    # these are the axes that the series should be mapped to
    x_idx, y_idx = plotly_link_indicies(plt, sp)
    d_out[:xaxis] = "x$(x_idx)"
    d_out[:yaxis] = "y$(y_idx)"
    d_out[:showlegend] = should_add_to_legend(series)

    if st == :straightline
        x, y = straightline_data(series)
        z = series[:z]
    else
        x, y, z  = series[:x], series[:y], series[:z]
    end

    x, y, z = (plotly_data(series, letter, data)
        for (letter, data) in zip((:x, :y, :z), (x, y, z))
    )

    d_out[:name] = series[:label]

    isscatter = st in (:scatter, :scatter3d, :scattergl)
    hasmarker = isscatter || series[:markershape] != :none
    hasline = st in (:path, :path3d, :straightline)
    hasfillrange = st in (:path, :scatter, :scattergl, :straightline) &&
        (isa(series[:fillrange], AbstractVector) || isa(series[:fillrange], Tuple))

    d_out[:colorbar] = KW(:title => sp[:colorbar_title])

    clims = sp[:clims]
    if is_2tuple(clims)
        d_out[:zmin], d_out[:zmax] = clims
    end

    # set the "type"
    if st in (:path, :scatter, :scattergl, :straightline, :path3d, :scatter3d)
        return plotly_series_segments(series, d_out, x, y, z)

    elseif st == :heatmap
        x = heatmap_edges(x, sp[:xaxis][:scale])
        y = heatmap_edges(y, sp[:yaxis][:scale])
        d_out[:type] = "heatmap"
        d_out[:x], d_out[:y], d_out[:z] = x, y, z
        d_out[:colorscale] = plotly_colorscale(series[:fillcolor], series[:fillalpha])
        d_out[:showscale] = hascolorbar(sp)

    elseif st == :contour
        d_out[:type] = "contour"
        d_out[:x], d_out[:y], d_out[:z] = x, y, z
        # d_out[:showscale] = series[:colorbar] != :none
        d_out[:ncontours] = series[:levels]
        d_out[:contours] = KW(:coloring => series[:fillrange] != nothing ? "fill" : "lines", :showlabels => series[:contour_labels] == true)
        d_out[:colorscale] = plotly_colorscale(series[:linecolor], series[:linealpha])
        d_out[:showscale] = hascolorbar(sp)

    elseif st in (:surface, :wireframe)
        d_out[:type] = "surface"
        d_out[:x], d_out[:y], d_out[:z] = x, y, z
        if st == :wireframe
            d_out[:hidesurface] = true
            wirelines = KW(
                :show => true,
                :color => rgba_string(plot_color(series[:linecolor], series[:linealpha])),
                :highlightwidth => series[:linewidth],
            )
            d_out[:contours] = KW(:x => wirelines, :y => wirelines, :z => wirelines)
            d_out[:showscale] = false
        else
            d_out[:colorscale] = plotly_colorscale(series[:fillcolor], series[:fillalpha])
            d_out[:opacity] = series[:fillalpha]
            if series[:fill_z] != nothing
                d_out[:surfacecolor] = plotly_surface_data(series, series[:fill_z])
            end
            d_out[:showscale] = hascolorbar(sp)
        end

    elseif st == :pie
        d_out[:type] = "pie"
        d_out[:labels] = pie_labels(sp, series)
        d_out[:values] = y
        d_out[:hoverinfo] = "label+percent+name"

    else
        warn("Plotly: seriestype $st isn't supported.")
        return KW()
    end

    # add "marker"
    if hasmarker
        inds = eachindex(x)
        d_out[:marker] = KW(
            :symbol => get(_plotly_markers, series[:markershape], string(series[:markershape])),
            # :opacity => series[:markeralpha],
            :size => 2 * _cycle(series[:markersize], inds),
            :color => rgba_string.(plot_color.(get_markercolor.(series, inds), get_markeralpha.(series, inds))),
            :line => KW(
                :color => rgba_string.(plot_color.(get_markerstrokecolor.(series, inds), get_markerstrokealpha.(series, inds))),
                :width => _cycle(series[:markerstrokewidth], inds),
            ),
        )
    end

    plotly_polar!(d_out, series)
    plotly_hover!(d_out, series[:hover])

    return [d_out]
end

function plotly_series_shapes(plt::Plot, series::Series)
    segments = iter_segments(series)
    d_outs = Vector{KW}(length(segments))

    # TODO: create a d_out for each polygon
    # x, y = series[:x], series[:y]

    # these are the axes that the series should be mapped to
    x_idx, y_idx = plotly_link_indicies(plt, series[:subplot])
    d_base = KW(
        :xaxis => "x$(x_idx)",
        :yaxis => "y$(y_idx)",
        :name => series[:label],
        :legendgroup => series[:label],
    )

    x, y = (plotly_data(series, letter, data)
        for (letter, data) in zip((:x, :y), shape_data(series))
    )

    for (i,rng) in enumerate(segments)
        length(rng) < 2 && continue

        # to draw polygons, we actually draw lines with fill
        d_out = merge(d_base, KW(
            :type => "scatter",
            :mode => "lines",
            :x => vcat(x[rng], x[rng[1]]),
            :y => vcat(y[rng], y[rng[1]]),
            :fill => "tozeroy",
            :fillcolor => rgba_string(plot_color(get_fillcolor(series, i), get_fillalpha(series, i))),
        ))
        if series[:markerstrokewidth] > 0
            d_out[:line] = KW(
                :color => rgba_string(plot_color(get_linecolor(series, i), get_linealpha(series, i))),
                :width => get_linewidth(series, i),
                :dash => string(get_linestyle(series, i)),
            )
        end
        d_out[:showlegend] = i==1 ? should_add_to_legend(series) : false
        plotly_polar!(d_out, series)
        plotly_hover!(d_out, _cycle(series[:hover], i))
        d_outs[i] = d_out
    end
    if series[:fill_z] != nothing
        push!(d_outs, plotly_colorbar_hack(series, d_base, :fill))
    elseif series[:line_z] != nothing
        push!(d_outs, plotly_colorbar_hack(series, d_base, :line))
    elseif series[:marker_z] != nothing
        push!(d_outs, plotly_colorbar_hack(series, d_base, :marker))
    end
    d_outs
end

function plotly_series_segments(series::Series, d_base::KW, x, y, z)
    st = series[:seriestype]
    sp = series[:subplot]
    isscatter = st in (:scatter, :scatter3d, :scattergl)
    hasmarker = isscatter || series[:markershape] != :none
    hasline = st in (:path, :path3d, :straightline)
    hasfillrange = st in (:path, :scatter, :scattergl, :straightline) &&
        (isa(series[:fillrange], AbstractVector) || isa(series[:fillrange], Tuple))

    segments = iter_segments(series)
    d_outs = Vector{KW}((hasfillrange ? 2 : 1 ) * length(segments))

    for (i,rng) in enumerate(segments)
        !isscatter && length(rng) < 2 && continue

        d_out = deepcopy(d_base)
        d_out[:showlegend] = i==1 ? should_add_to_legend(series) : false
        d_out[:legendgroup] = series[:label]

        # set the type
        if st in (:path, :scatter, :scattergl, :straightline)
            d_out[:type] = st==:scattergl ? "scattergl" : "scatter"
            d_out[:mode] = if hasmarker
                hasline ? "lines+markers" : "markers"
            else
                hasline ? "lines" : "none"
            end
            if series[:fillrange] == true || series[:fillrange] == 0 || isa(series[:fillrange], Tuple)
                d_out[:fill] = "tozeroy"
                d_out[:fillcolor] = rgba_string(plot_color(get_fillcolor(series, i), get_fillalpha(series, i)))
            elseif typeof(series[:fillrange]) <: Union{AbstractVector{<:Real}, Real}
                d_out[:fill] = "tonexty"
                d_out[:fillcolor] = rgba_string(plot_color(get_fillcolor(series, i), get_fillalpha(series, i)))
            elseif !(series[:fillrange] in (false, nothing))
                warn("fillrange ignored... plotly only supports filling to zero and to a vector of values. fillrange: $(series[:fillrange])")
            end
            d_out[:x], d_out[:y] = x[rng], y[rng]

        elseif st in (:path3d, :scatter3d)
            d_out[:type] = "scatter3d"
            d_out[:mode] = if hasmarker
                hasline ? "lines+markers" : "markers"
            else
                hasline ? "lines" : "none"
            end
            d_out[:x], d_out[:y], d_out[:z] = x[rng], y[rng], z[rng]
        end

        # add "marker"
        if hasmarker
            d_out[:marker] = KW(
                :symbol => get(_plotly_markers, _cycle(series[:markershape], i), string(_cycle(series[:markershape], i))),
                # :opacity => series[:markeralpha],
                :size => 2 * _cycle(series[:markersize], i),
                :color => rgba_string(plot_color(get_markercolor(series, i), get_markeralpha(series, i))),
                :line => KW(
                    :color => rgba_string(plot_color(get_markerstrokecolor(series, i), get_markerstrokealpha(series, i))),
                    :width => _cycle(series[:markerstrokewidth], i),
                ),
            )
        end

        # add "line"
        if hasline
            d_out[:line] = KW(
                :color => rgba_string(plot_color(get_linecolor(series, i), get_linealpha(series, i))),
                :width => get_linewidth(series, i),
                :shape => if st == :steppre
                    "vh"
                elseif st == :steppost
                    "hv"
                else
                    "linear"
                end,
                :dash => string(get_linestyle(series, i)),
            )
        end

        plotly_polar!(d_out, series)
        plotly_hover!(d_out, _cycle(series[:hover], rng))

        if hasfillrange
            # if hasfillrange is true, return two dictionaries (one for original
            # series, one for series being filled to) instead of one
            d_out_fillrange = deepcopy(d_out)
            d_out_fillrange[:showlegend] = false
            # if fillrange is provided as real or tuple of real, expand to array
            if typeof(series[:fillrange]) <: Real
                series[:fillrange] = fill(series[:fillrange], length(rng))
            elseif typeof(series[:fillrange]) <: Tuple
                f1 = typeof(series[:fillrange][1]) <: Real ? fill(series[:fillrange][1], length(rng)) : series[:fillrange][1][rng]
                f2 = typeof(series[:fillrange][2]) <: Real ? fill(series[:fillrange][2], length(rng)) : series[:fillrange][2][rng]
                series[:fillrange] = (f1, f2)
            end
            if isa(series[:fillrange], AbstractVector)
                d_out_fillrange[:y] = series[:fillrange][rng]
                delete!(d_out_fillrange, :fill)
                delete!(d_out_fillrange, :fillcolor)
            else
                # if fillrange is a tuple with upper and lower limit, d_out_fillrange
                # is the series that will do the filling
                fillrng = Tuple(series[:fillrange][i][rng] for i in 1:2)
                d_out_fillrange[:x], d_out_fillrange[:y] = concatenate_fillrange(x[rng], fillrng)
                d_out_fillrange[:line][:width] = 0
                delete!(d_out, :fill)
                delete!(d_out, :fillcolor)
            end

            d_outs[(2 * i - 1):(2 * i)] = [d_out_fillrange, d_out]
        else
            d_outs[i] = d_out
        end
    end

    if series[:line_z] != nothing
        push!(d_outs, plotly_colorbar_hack(series, d_base, :line))
    elseif series[:fill_z] != nothing
        push!(d_outs, plotly_colorbar_hack(series, d_base, :fill))
    elseif series[:marker_z] != nothing
        push!(d_outs, plotly_colorbar_hack(series, d_base, :marker))
    end

    d_outs
end

function plotly_colorbar_hack(series::Series, d_base::KW, sym::Symbol)
    d_out = deepcopy(d_base)
    cmin, cmax = get_clims(series[:subplot])
    d_out[:showlegend] = false
    d_out[:type] = is3d(series) ? :scatter3d : :scatter
    d_out[:hoverinfo] = :none
    d_out[:mode] = :markers
    d_out[:x], d_out[:y] = [series[:x][1]], [series[:y][1]]
    if is3d(series)
        d_out[:z] = [series[:z][1]]
    end
    # zrange = zmax == zmin ? 1 : zmax - zmin # if all marker_z values are the same, plot all markers same color (avoids division by zero in next line)
    d_out[:marker] = KW(
        :size => 0,
        :opacity => 0,
        :color => [0.5],
        :cmin => cmin,
        :cmax => cmax,
        :colorscale => plotly_colorscale(series[Symbol("$(sym)color")], 1),
        :showscale => hascolorbar(series[:subplot]),
    )
    return d_out
end


function plotly_polar!(d_out::KW, series::Series)
    # convert polar plots x/y to theta/radius
    if ispolar(series[:subplot])
        theta, r = filter_radial_data(pop!(d_out, :x), pop!(d_out, :y), axis_limits(series[:subplot][:yaxis]))
        d_out[:t] = rad2deg.(theta)
        d_out[:r] = r
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
function plotly_series(plt::Plot)
    slist = []
    for series in plt.series_list
        append!(slist, plotly_series(plt, series))
    end
    slist
end

# get json string for a list of dictionaries, each representing the series params
plotly_series_json(plt::Plot) = JSON.json(plotly_series(plt))

# ----------------------------------------------------------------

const _use_remote = Ref(false)

function html_head(plt::Plot{PlotlyBackend})
    jsfilename = _use_remote[] ? _plotly_js_path_remote : ("file://" * _plotly_js_path)
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


function _show(io::IO, ::MIME"text/html", plt::Plot{PlotlyBackend})
    write(io, html_head(plt) * html_body(plt))
end

function _display(plt::Plot{PlotlyBackend})
    standalone_html_window(plt)
end
