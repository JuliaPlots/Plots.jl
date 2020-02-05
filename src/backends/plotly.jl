
# https://plot.ly/javascript/getting-started

is_subplot_supported(::PlotlyBackend) = true
# is_string_supported(::PlotlyBackend) = true
const _plotly_framestyles = [:box, :axes, :zerolines, :grid, :none]
const _plotly_framestyle_defaults = Dict(:semi => :box, :origin => :zerolines)
function _plotly_framestyle(style::Symbol)
    if style in _plotly_framestyles
        return style
    else
        default_style = get(_plotly_framestyle_defaults, style, :axes)
        @warn("Framestyle :$style is not supported by Plotly and PlotlyJS. :$default_style was cosen instead.")
        default_style
    end
end


# --------------------------------------------------------------------------------------
const plotly_remote_file_path = "https://cdn.plot.ly/plotly-latest.min.js"


# if isatom()
#     import Atom
#     Atom.@msg evaljs(_js_code)
# end
using UUIDs

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

# function get_annotation_dict_for_arrow(plotattributes::KW, xyprev::Tuple, xy::Tuple, a::Arrow)
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
#         :arrowcolor => rgba_string(plotattributes[:linecolor]),
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
        xmin,xmax = axis_limits(sp, :x)
        ymin,ymax = axis_limits(sp, :y)
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
    lims = axis_limits(sp, letter)

    if axis[:ticks] != :native || axis[:lims] != :auto
        ax[:range] = map(scalefunc(axis[:scale]), lims)
    end

    if !(axis[:ticks] in (nothing, :none, false))
        ax[:titlefont] = plotly_font(guidefont(axis))
        ax[:tickfont] = plotly_font(tickfont(axis))
        ax[:tickcolor] = framestyle in (:zerolines, :grid) || !axis[:showaxis] ? rgba_string(invisible()) : rgb_string(axis[:foreground_color_axis])
        ax[:linecolor] = rgba_string(axis[:foreground_color_axis])

        # ticks
        if axis[:ticks] != :native
            ticks = get_ticks(sp, axis)
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

    # flip
    if axis[:flip]
        ax[:range] = reverse(ax[:range])
    end

    ax
end

function plotly_polaraxis(sp::Subplot, axis::Axis)
    ax = KW(
        :visible => axis[:showaxis],
        :showline => axis[:grid],
    )

    if axis[:letter] == :x
        ax[:range] = rad2deg.(axis_limits(sp, :x))
    else
        ax[:range] = axis_limits(sp, :y)
        ax[:orientation] = -90
    end

    ax
end

function plotly_layout(plt::Plot)
    plotattributes_out = KW()

    w, h = plt[:size]
    plotattributes_out[:width], plotattributes_out[:height] = w, h
    plotattributes_out[:paper_bgcolor] = rgba_string(plt[:background_color_outside])
    plotattributes_out[:margin] = KW(:l=>0, :b=>20, :r=>0, :t=>20)

    plotattributes_out[:annotations] = KW[]

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
            push!(plotattributes_out[:annotations], plotly_annotation_dict(titlex, titley, text(sp[:title], title_font)))
        end

        plotattributes_out[:plot_bgcolor] = rgba_string(sp[:background_color_inside])

        # set to supported framestyle
        sp[:framestyle] = _plotly_framestyle(sp[:framestyle])

        # if any(is3d, seriesargs)
        if is3d(sp)
            azim = sp[:camera][1] - 90 #convert azimuthal to match GR behaviour
            theta = 90 - sp[:camera][2] #spherical coordinate angle from z axis
            plotattributes_out[:scene] = KW(
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
            plotattributes_out[Symbol("angularaxis$(spidx)")] = plotly_polaraxis(sp, sp[:xaxis])
            plotattributes_out[Symbol("radialaxis$(spidx)")] = plotly_polaraxis(sp, sp[:yaxis])
        else
            plotattributes_out[Symbol("xaxis$(x_idx)")] = plotly_axis(plt, sp[:xaxis], sp)
            # don't allow yaxis to be reupdated/reanchored in a linked subplot
            spidx == y_idx ? plotattributes_out[Symbol("yaxis$(y_idx)")] = plotly_axis(plt, sp[:yaxis], sp) : nothing
        end

        # legend
        plotattributes_out[:showlegend] = sp[:legend] != :none
        xpos,ypos = plotly_legend_pos(sp[:legend])
        if sp[:legend] != :none
            plotattributes_out[:legend] = KW(
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
            append!(plotattributes_out[:annotations], KW[plotly_annotation_dict(locate_annotation(sp, ann...)...; xref = "x$(x_idx)", yref = "y$(y_idx)")])
        end
        # series_annotations
        for series in series_list(sp)
            anns = series[:series_annotations]
            for (xi,yi,str,fnt) in EachAnn(anns, series[:x], series[:y])
                push!(plotattributes_out[:annotations], plotly_annotation_dict(
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
        #             push!(plotattributes_out[:annotations], get_annotation_dict_for_arrow(sargs, xyprev, xy, a))
        #         end
        #     end
        # end

        if ispolar(sp)
            plotattributes_out[:direction] = "counterclockwise"
        end

        plotattributes_out
    end

    # turn off hover if nothing's using it
    if all(series -> series.plotattributes[:hover] in (false,:none), plt.series_list)
        plotattributes_out[:hovermode] = "none"
    end

    plotattributes_out
end

function plotly_layout_json(plt::Plot)
    JSON.json(plotly_layout(plt), 4)
end


function plotly_colorscale(grad::ColorGradient, α)
    [[grad.values[i], rgba_string(plot_color(grad.colors[i], α))] for i in eachindex(grad.colors)]
end
plotly_colorscale(c::Colorant,α) = plotly_colorscale(_as_gradient(c),α)
function plotly_colorscale(c::AbstractVector{<:RGBA}, α)
    if length(c) == 1
        return [[0.0, rgba_string(plot_color(c[1], α))], [1.0, rgba_string(plot_color(c[1], α))]]
    else
        vals = range(0.0, stop=1.0, length=length(c))
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
    for i=eachindex(xs)
        shape = Shape(xs[i], ys[i])
        xs[i], ys[i] = coords(shape)
    end
    nanvcat(xs), nanvcat(ys)
end

function plotly_data(series::Series, letter::Symbol, data)
    axis = series[:subplot][Symbol(letter, :axis)]

    data = if axis[:ticks] == :native && data !== nothing
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
plotly_data(v) = v !== nothing ? collect(v) : v
plotly_data(v::AbstractArray) = v
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
        map(xi -> replace(formatter(xi), "T" => " "), x)
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

# get a dictionary representing the series params (plotattributes is the Plots-dict, plotattributes_out is the Plotly-dict)
function plotly_series(plt::Plot, series::Series)
    st = series[:seriestype]

    sp = series[:subplot]
    clims = get_clims(sp, series)

    if st == :shape
        return plotly_series_shapes(plt, series, clims)
    end

    plotattributes_out = KW()

    # these are the axes that the series should be mapped to
    x_idx, y_idx = plotly_link_indicies(plt, sp)
    plotattributes_out[:xaxis] = "x$(x_idx)"
    plotattributes_out[:yaxis] = "y$(y_idx)"
    plotattributes_out[:showlegend] = should_add_to_legend(series)

    if st == :straightline
        x, y = straightline_data(series, 100)
        z = series[:z]
    else
        x, y, z  = series[:x], series[:y], series[:z]
    end

    x, y, z = (plotly_data(series, letter, data)
        for (letter, data) in zip((:x, :y, :z), (x, y, z))
    )

    plotattributes_out[:name] = series[:label]

    isscatter = st in (:scatter, :scatter3d, :scattergl)
    hasmarker = isscatter || series[:markershape] != :none
    hasline = st in (:path, :path3d, :straightline)
    hasfillrange = st in (:path, :scatter, :scattergl, :straightline) &&
        (isa(series[:fillrange], AbstractVector) || isa(series[:fillrange], Tuple))

    plotattributes_out[:colorbar] = KW(:title => sp[:colorbar_title])

    if is_2tuple(clims)
        plotattributes_out[:zmin], plotattributes_out[:zmax] = clims
    end

    # set the "type"
    if st in (:path, :scatter, :scattergl, :straightline, :path3d, :scatter3d)
        return plotly_series_segments(series, plotattributes_out, x, y, z, clims)

    elseif st == :heatmap
        x = heatmap_edges(x, sp[:xaxis][:scale])
        y = heatmap_edges(y, sp[:yaxis][:scale])
        plotattributes_out[:type] = "heatmap"
        plotattributes_out[:x], plotattributes_out[:y], plotattributes_out[:z] = x, y, z
        plotattributes_out[:colorscale] = plotly_colorscale(series[:fillcolor], series[:fillalpha])
        plotattributes_out[:showscale] = hascolorbar(sp)

    elseif st == :contour
        filled = isfilledcontour(series)
        plotattributes_out[:type] = "contour"
        plotattributes_out[:x], plotattributes_out[:y], plotattributes_out[:z] = x, y, z
        plotattributes_out[:ncontours] = series[:levels] + 2
        plotattributes_out[:contours] = KW(:coloring => filled ? "fill" : "lines", :showlabels => series[:contour_labels] == true)
        plotattributes_out[:colorscale] = plotly_colorscale(series[:linecolor], series[:linealpha])
        plotattributes_out[:showscale] = hascolorbar(sp) && hascolorbar(series)

    elseif st in (:surface, :wireframe)
        plotattributes_out[:type] = "surface"
        plotattributes_out[:x], plotattributes_out[:y], plotattributes_out[:z] = x, y, z
        if st == :wireframe
            plotattributes_out[:hidesurface] = true
            wirelines = KW(
                :show => true,
                :color => rgba_string(plot_color(series[:linecolor], series[:linealpha])),
                :highlightwidth => series[:linewidth],
            )
            plotattributes_out[:contours] = KW(:x => wirelines, :y => wirelines, :z => wirelines)
            plotattributes_out[:showscale] = false
        else
            plotattributes_out[:colorscale] = plotly_colorscale(series[:fillcolor], series[:fillalpha])
            plotattributes_out[:opacity] = series[:fillalpha]
            if series[:fill_z] !== nothing
                plotattributes_out[:surfacecolor] = plotly_surface_data(series, series[:fill_z])
            end
            plotattributes_out[:showscale] = hascolorbar(sp)
        end

    elseif st == :pie
        plotattributes_out[:type] = "pie"
        plotattributes_out[:labels] = pie_labels(sp, series)
        plotattributes_out[:values] = y
        plotattributes_out[:hoverinfo] = "label+percent+name"

    else
        @warn("Plotly: seriestype $st isn't supported.")
        return KW()
    end

    # add "marker"
    if hasmarker
        inds = eachindex(x)
        plotattributes_out[:marker] = KW(
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

    plotly_polar!(plotattributes_out, series)
    plotly_hover!(plotattributes_out, series[:hover])

    return [plotattributes_out]
end

function plotly_series_shapes(plt::Plot, series::Series, clims)
    segments = iter_segments(series)
    plotattributes_outs = Vector{KW}(undef, length(segments))

    # TODO: create a plotattributes_out for each polygon
    # x, y = series[:x], series[:y]

    # these are the axes that the series should be mapped to
    x_idx, y_idx = plotly_link_indicies(plt, series[:subplot])
    plotattributes_base = KW(
        :xaxis => "x$(x_idx)",
        :yaxis => "y$(y_idx)",
        :name => series[:label],
        :legendgroup => series[:label],
    )

    x, y = (plotly_data(series, letter, data)
        for (letter, data) in zip((:x, :y), shape_data(series, 100))
    )

    for (i,rng) in enumerate(segments)
        length(rng) < 2 && continue

        # to draw polygons, we actually draw lines with fill
        plotattributes_out = merge(plotattributes_base, KW(
            :type => "scatter",
            :mode => "lines",
            :x => vcat(x[rng], x[rng[1]]),
            :y => vcat(y[rng], y[rng[1]]),
            :fill => "tozeroy",
            :fillcolor => rgba_string(plot_color(get_fillcolor(series, clims, i), get_fillalpha(series, i))),
        ))
        if series[:markerstrokewidth] > 0
            plotattributes_out[:line] = KW(
                :color => rgba_string(plot_color(get_linecolor(series, clims, i), get_linealpha(series, i))),
                :width => get_linewidth(series, i),
                :dash => string(get_linestyle(series, i)),
            )
        end
        plotattributes_out[:showlegend] = i==1 ? should_add_to_legend(series) : false
        plotly_polar!(plotattributes_out, series)
        plotly_hover!(plotattributes_out, _cycle(series[:hover], i))
        plotattributes_outs[i] = plotattributes_out
    end
    if series[:fill_z] !== nothing
        push!(plotattributes_outs, plotly_colorbar_hack(series, plotattributes_base, :fill))
    elseif series[:line_z] !== nothing
        push!(plotattributes_outs, plotly_colorbar_hack(series, plotattributes_base, :line))
    elseif series[:marker_z] !== nothing
        push!(plotattributes_outs, plotly_colorbar_hack(series, plotattributes_base, :marker))
    end
    plotattributes_outs
end

function plotly_series_segments(series::Series, plotattributes_base::KW, x, y, z, clims)
    st = series[:seriestype]
    sp = series[:subplot]
    isscatter = st in (:scatter, :scatter3d, :scattergl)
    hasmarker = isscatter || series[:markershape] != :none
    hasline = st in (:path, :path3d, :straightline)
    hasfillrange = st in (:path, :scatter, :scattergl, :straightline) &&
        (isa(series[:fillrange], AbstractVector) || isa(series[:fillrange], Tuple))

    segments = iter_segments(series)
    plotattributes_outs = fill(KW(), (hasfillrange ? 2 : 1 ) * length(segments))

    for (i,rng) in enumerate(segments)
        plotattributes_out = deepcopy(plotattributes_base)
        plotattributes_out[:showlegend] = i==1 ? should_add_to_legend(series) : false
        plotattributes_out[:legendgroup] = series[:label]

        # set the type
        if st in (:path, :scatter, :scattergl, :straightline)
            plotattributes_out[:type] = st==:scattergl ? "scattergl" : "scatter"
            plotattributes_out[:mode] = if hasmarker
                hasline ? "lines+markers" : "markers"
            else
                hasline ? "lines" : "none"
            end
            if series[:fillrange] == true || series[:fillrange] == 0 || isa(series[:fillrange], Tuple)
                plotattributes_out[:fill] = "tozeroy"
                plotattributes_out[:fillcolor] = rgba_string(plot_color(get_fillcolor(series, clims, i), get_fillalpha(series, i)))
            elseif typeof(series[:fillrange]) <: Union{AbstractVector{<:Real}, Real}
                plotattributes_out[:fill] = "tonexty"
                plotattributes_out[:fillcolor] = rgba_string(plot_color(get_fillcolor(series, clims, i), get_fillalpha(series, i)))
            elseif !(series[:fillrange] in (false, nothing))
                @warn("fillrange ignored... plotly only supports filling to zero and to a vector of values. fillrange: $(series[:fillrange])")
            end
            plotattributes_out[:x], plotattributes_out[:y] = x[rng], y[rng]

        elseif st in (:path3d, :scatter3d)
            plotattributes_out[:type] = "scatter3d"
            plotattributes_out[:mode] = if hasmarker
                hasline ? "lines+markers" : "markers"
            else
                hasline ? "lines" : "none"
            end
            plotattributes_out[:x], plotattributes_out[:y], plotattributes_out[:z] = x[rng], y[rng], z[rng]
        end

        # add "marker"
        if hasmarker
            plotattributes_out[:marker] = KW(
                :symbol => get(_plotly_markers, _cycle(series[:markershape], i), string(_cycle(series[:markershape], i))),
                # :opacity => series[:markeralpha],
                :size => 2 * _cycle(series[:markersize], i),
                :color => rgba_string(plot_color(get_markercolor(series, clims, i), get_markeralpha(series, i))),
                :line => KW(
                    :color => rgba_string(plot_color(get_markerstrokecolor(series, i), get_markerstrokealpha(series, i))),
                    :width => _cycle(series[:markerstrokewidth], i),
                ),
            )
        end

        # add "line"
        if hasline
            plotattributes_out[:line] = KW(
                :color => rgba_string(plot_color(get_linecolor(series, clims, i), get_linealpha(series, i))),
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

        plotly_polar!(plotattributes_out, series)
        plotly_hover!(plotattributes_out, _cycle(series[:hover], rng))

        if hasfillrange
            # if hasfillrange is true, return two dictionaries (one for original
            # series, one for series being filled to) instead of one
            plotattributes_out_fillrange = deepcopy(plotattributes_out)
            plotattributes_out_fillrange[:showlegend] = false
            # if fillrange is provided as real or tuple of real, expand to array
            if typeof(series[:fillrange]) <: Real
                series[:fillrange] = fill(series[:fillrange], length(rng))
            elseif typeof(series[:fillrange]) <: Tuple
                f1 = typeof(series[:fillrange][1]) <: Real ? fill(series[:fillrange][1], length(rng)) : series[:fillrange][1][rng]
                f2 = typeof(series[:fillrange][2]) <: Real ? fill(series[:fillrange][2], length(rng)) : series[:fillrange][2][rng]
                series[:fillrange] = (f1, f2)
            end
            if isa(series[:fillrange], AbstractVector)
                plotattributes_out_fillrange[:y] = series[:fillrange][rng]
                delete!(plotattributes_out_fillrange, :fill)
                delete!(plotattributes_out_fillrange, :fillcolor)
            else
                # if fillrange is a tuple with upper and lower limit, plotattributes_out_fillrange
                # is the series that will do the filling
                fillrng = Tuple(series[:fillrange][i][rng] for i in 1:2)
                plotattributes_out_fillrange[:x], plotattributes_out_fillrange[:y] = concatenate_fillrange(x[rng], fillrng)
                plotattributes_out_fillrange[:line][:width] = 0
                delete!(plotattributes_out, :fill)
                delete!(plotattributes_out, :fillcolor)
            end

            plotattributes_outs[(2 * i - 1):(2 * i)] = [plotattributes_out_fillrange, plotattributes_out]
        else
            plotattributes_outs[i] = plotattributes_out
        end
    end

    if series[:line_z] !== nothing
        push!(plotattributes_outs, plotly_colorbar_hack(series, plotattributes_base, :line))
    elseif series[:fill_z] !== nothing
        push!(plotattributes_outs, plotly_colorbar_hack(series, plotattributes_base, :fill))
    elseif series[:marker_z] !== nothing
        push!(plotattributes_outs, plotly_colorbar_hack(series, plotattributes_base, :marker))
    end

    plotattributes_outs
end

function plotly_colorbar_hack(series::Series, plotattributes_base::KW, sym::Symbol)
    plotattributes_out = deepcopy(plotattributes_base)
    cmin, cmax = get_clims(series[:subplot])
    plotattributes_out[:showlegend] = false
    plotattributes_out[:type] = is3d(series) ? :scatter3d : :scatter
    plotattributes_out[:hoverinfo] = :none
    plotattributes_out[:mode] = :markers
    plotattributes_out[:x], plotattributes_out[:y] = [series[:x][1]], [series[:y][1]]
    if is3d(series)
        plotattributes_out[:z] = [series[:z][1]]
    end
    # zrange = zmax == zmin ? 1 : zmax - zmin # if all marker_z values are the same, plot all markers same color (avoids division by zero in next line)
    plotattributes_out[:marker] = KW(
        :size => 0,
        :opacity => 0,
        :color => [0.5],
        :cmin => cmin,
        :cmax => cmax,
        :colorscale => plotly_colorscale(series[Symbol("$(sym)color")], 1),
        :showscale => hascolorbar(series[:subplot]),
    )
    return plotattributes_out
end


function plotly_polar!(plotattributes_out::KW, series::Series)
    # convert polar plots x/y to theta/radius
    if ispolar(series[:subplot])
        theta, r = pop!(plotattributes_out, :x), pop!(plotattributes_out, :y)
        plotattributes_out[:t] = rad2deg.(theta)
        plotattributes_out[:r] = r
    end
end

function plotly_hover!(plotattributes_out::KW, hover)
    # hover text
    if hover in (:none, false)
        plotattributes_out[:hoverinfo] = "none"
    elseif hover !== nothing
        plotattributes_out[:hoverinfo] = "text"
        plotattributes_out[:text] = hover
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
plotly_series_json(plt::Plot) = JSON.json(plotly_series(plt), 4)

# ----------------------------------------------------------------

html_head(plt::Plot{PlotlyBackend}) = plotly_html_head(plt)
html_body(plt::Plot{PlotlyBackend}) = plotly_html_body(plt)

const ijulia_initialized = Ref(false)

function plotly_html_head(plt::Plot)
    local_file = ("file://" * plotly_local_file_path)
    plotly = use_local_dependencies[] ? local_file : plotly_remote_file_path
    if isijulia() && !ijulia_initialized[]
        # using requirejs seems to be key to load a js depency in IJulia!
        # https://requirejs.org/docs/start.html
        # https://github.com/JuliaLang/IJulia.jl/issues/345
        display("text/html", """
            <script type="text/javascript">
                requirejs([$(repr(plotly))], function(p) {
                    window.Plotly = p
                });
            </script>
        """)
        ijulia_initialized[] = true
    end
    return "<script src=$(repr(plotly))></script>"
end

function plotly_html_body(plt, style = nothing)
    if style === nothing
        w, h = plt[:size]
        style = "width:$(w)px;height:$(h)px;"
    end
    uuid = UUIDs.uuid4()
    html = """
        <div id=\"$(uuid)\" style=\"$(style)\"></div>
        <script>
        PLOT = document.getElementById('$(uuid)');
        Plotly.plot(PLOT, $(plotly_series_json(plt)), $(plotly_layout_json(plt)));
        </script>
    """
    html
end

function js_body(plt::Plot, uuid)
    js = """
        PLOT = document.getElementById('$(uuid)');
        Plotly.plot(PLOT, $(plotly_series_json(plt)), $(plotly_layout_json(plt)));
    """
end

function plotly_show_js(io::IO, plot::Plot)
    data = []
    for series in plot.series_list
        append!(data, plotly_series(plot, series))
    end
    layout = plotly_layout(plot)
    JSON.print(io, Dict(:data => data, :layout => layout))
end

# ----------------------------------------------------------------

Base.showable(::MIME"application/prs.juno.plotpane+html", plt::Plot{PlotlyBackend}) = true

function _show(io::IO, ::MIME"application/vnd.plotly.v1+json", plot::Plot{PlotlyBackend})
    plotly_show_js(io, plot)
end


function _show(io::IO, ::MIME"text/html", plt::Plot{PlotlyBackend})
    write(io, standalone_html(plt))
end


function _display(plt::Plot{PlotlyBackend})
    standalone_html_window(plt)
end
