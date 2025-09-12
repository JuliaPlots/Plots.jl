# https://plot.ly/javascript/getting-started

_plotly_framestyle(style::Symbol) =
if style in (:box, :axes, :zerolines, :grid, :none)
    style
else
    default_style = get((semi = :box, origin = :zerolines), style, :axes)
    @warn "Framestyle :$style is not supported by Plotly and PlotlyJS. :$default_style was chosen instead."
    default_style
end

# --------------------------------------------------------------------------------------

using UUIDs

# ----------------------------------------------------------------

function labelfunc(scale::Symbol, backend::PlotlyBackend)
    texfunc = labelfunc_tex(scale)
    return x -> begin
        tex_x = texfunc(x)
        sup_x = replace(tex_x, r"\^{(.*)}" => s"<sup>\1</sup>")
        # replace dash with \minus (U+2212)
        replace(sup_x, "-" => "−")
    end
end

plotly_font(font::Font, color = font.color) = KW(
    :family => font.family,
    :size => round(Int, 1.4font.pointsize),
    :color => rgba_string(color),
)

plotly_annotation_dict(x, y, val; xref = "paper", yref = "paper") =
    KW(:text => val, :xref => xref, :x => x, :yref => yref, :y => y, :showarrow => false)

plotly_annotation_dict(x, y, z, val; xref = "paper", yref = "paper", zref = "paper") = KW(
    :text => val,
    :xref => xref,
    :x => x,
    :yref => yref,
    :y => y,
    :zref => zref,
    :z => z,
    :showarrow => false,
)

plotly_annotation_dict(x, y, ptxt::PlotText; xref = "paper", yref = "paper") = merge(
    plotly_annotation_dict(x, y, ptxt.str; xref = xref, yref = yref),
    KW(
        :font => plotly_font(ptxt.font),
        :xanchor => ptxt.font.halign === :hcenter ? :center : ptxt.font.halign,
        :yanchor => ptxt.font.valign === :vcenter ? :middle : ptxt.font.valign,
        :rotation => -ptxt.font.rotation,
    ),
)

plotly_annotation_dict(
    x,
    y,
    z,
    ptxt::PlotText;
    xref = "paper",
    yref = "paper",
    zref = "paper",
) = merge(
    plotly_annotation_dict(x, y, z, ptxt.str; xref = xref, yref = yref, zref = zref),
    KW(
        :font => plotly_font(ptxt.font),
        :xanchor => ptxt.font.halign === :hcenter ? :center : ptxt.font.halign,
        :yanchor => ptxt.font.valign === :vcenter ? :middle : ptxt.font.valign,
        :rotation => -ptxt.font.rotation,
    ),
)

plotly_scale(scale::Symbol) = scale === :log10 ? "log" : "-"

function shrink_by(lo, sz, ratio)
    amt = 0.5(1 - ratio) * sz
    return lo + amt, sz - 2amt
end

function plotly_apply_aspect_ratio(sp::Subplot, plotarea, pcts)
    if (aspect_ratio = get_aspect_ratio(sp)) !== :none
        aspect_ratio === :equal && (aspect_ratio = 1.0)
        xmin, xmax = axis_limits(sp, :x)
        ymin, ymax = axis_limits(sp, :y)
        want_ratio = ((xmax - xmin) / (ymax - ymin)) / aspect_ratio
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
    return pcts
end

# this method gets the start/end in percentage of the canvas for this axis direction
function plotly_domain(sp::Subplot)
    figw, figh = sp.plt[:size]
    pcts = bbox_to_pcts(sp.plotarea, figw * px, figh * px)
    pcts = plotly_apply_aspect_ratio(sp, sp.plotarea, pcts)
    x_domain = [pcts[1], pcts[1] + pcts[3]]
    y_domain = [pcts[2], pcts[2] + pcts[4]]
    if hascolorbar(sp)
        subplot_width = pcts[3]
        colorbar_fractional_size = 0.25
        colorbar_width = subplot_width * colorbar_fractional_size
        x_domain[2] = x_domain[2] - colorbar_width
    end
    return x_domain, y_domain
end

function plotly_axis(axis, sp, anchor = nothing, domain = nothing)
    letter = axis[:letter]
    framestyle = sp[:framestyle]
    ax = KW(
        :visible => framestyle !== :none,
        :title => Plots.get_guide(axis),
        :showgrid => axis[:grid],
        :gridcolor =>
            rgba_string(plot_color(axis[:foreground_color_grid], axis[:gridalpha])),
        :gridwidth => axis[:gridlinewidth],
        :zeroline => framestyle === :zerolines,
        :zerolinecolor => rgba_string(axis[:foreground_color_axis]),
        :showline => framestyle in (:box, :axes) && axis[:showaxis],
        :linecolor => rgba_string(plot_color(axis[:foreground_color_axis])),
        :ticks =>
            axis[:tick_direction] === :out ? "outside" :
            axis[:tick_direction] === :in ? "inside" : "",
        :mirror => framestyle === :box,
        :showticklabels => axis[:showaxis],
    )
    anchor === nothing || (ax[:anchor] = anchor)
    domain === nothing || (ax[:domain] = domain)

    ax[:tickangle] = -axis[:rotation]
    ax[:type] = plotly_scale(axis[:scale])
    lims = axis_limits(sp, letter)

    if axis[:ticks] !== :native || axis[:lims] !== :auto
        ax[:range] = map(RecipesPipeline.scale_func(axis[:scale]), lims)
    end

    if !(axis[:ticks] in (nothing, :none, false))
        ax[:titlefont] = plotly_font(guidefont(axis))
        ax[:tickfont] = plotly_font(tickfont(axis))
        ax[:tickcolor] =
            framestyle in (:zerolines, :grid) || !axis[:showaxis] ?
            rgba_string(invisible()) : rgb_string(axis[:foreground_color_axis])
        ax[:linecolor] = rgba_string(axis[:foreground_color_axis])

        # ticks
        if axis[:ticks] !== :native
            ticks = get_ticks(sp, axis)
            ttype = ticksType(ticks)
            if ttype === :ticks
                ax[:tickmode] = "array"
                ax[:tickvals] = ticks
            elseif ttype === :ticks_and_labels
                ax[:tickmode] = "array"
                ax[:tickvals], ax[:ticktext] = ticks
            end
        end
    else
        ax[:showticklabels] = false
        ax[:showgrid] = false
    end

    # flip
    axis[:flip] && (ax[:range] = reverse(ax[:range]))

    return ax
end

function plotly_polaraxis(sp::Subplot, axis::Axis)
    ax = KW(:visible => axis[:showaxis], :showline => axis[:grid])

    if axis[:letter] === :x
        ax[:range] = rad2deg.(axis_limits(sp, :x))
    else
        ax[:range] = axis_limits(sp, :y)
        ax[:orientation] = -90
    end
    return ax
end

function plotly_layout(plt::Plot)
    plotattributes_out = KW()

    w, h = plt[:size]
    plotattributes_out[:width], plotattributes_out[:height] = w, h
    plotattributes_out[:paper_bgcolor] = rgba_string(plt[:background_color_outside])
    plotattributes_out[:margin] = KW(:l => 0, :b => 20, :r => 0, :t => 20)

    plotattributes_out[:annotations] = KW[]

    multiple_subplots = length(plt.subplots) > 1

    for sp in plt.subplots
        spidx = multiple_subplots ? sp[:subplot_index] : ""
        x_idx, y_idx = multiple_subplots ? plotly_link_indicies(plt, sp) : ("", "")

        # add an annotation for the title
        if sp[:title] != ""
            bb = plotarea(sp)
            tpos = sp[:titlelocation]
            if tpos === :left
                xmm, ymm = left(bb), top(bbox(sp))
                halign, valign = :left, :top
            elseif tpos === :center
                xmm, ymm = 0.5(left(bb) + right(bb)), top(bbox(sp))
                halign, valign = :hcenter, :top
            elseif tpos === :right
                xmm, ymm = right(bb), top(bbox(sp))
                halign, valign = :right, :top
            else
                xmm = left(bb) + tpos[1] * width(bb)
                # inverting to make consistent with GR
                ymm = bottom(bb) - tpos[2] * height(bb)
                halign, valign = sp[:titlefonthalign], sp[:titlefontvalign]
            end
            titlex, titley = xy_mm_to_pcts(xmm, ymm, w * px, h * px)
            title_font = font(titlefont(sp), halign = halign, valign = valign)
            push!(
                plotattributes_out[:annotations],
                plotly_annotation_dict(titlex, titley, text(sp[:title], title_font)),
            )
        end

        plotattributes_out[:plot_bgcolor] = rgba_string(sp[:background_color_inside])

        # set to supported framestyle
        sp[:framestyle] = _plotly_framestyle(sp[:framestyle])

        if ispolar(sp)
            plotattributes_out[Symbol("angularaxis$(spidx)")] =
                plotly_polaraxis(sp, sp[:xaxis])
            plotattributes_out[Symbol("radialaxis$(spidx)")] =
                plotly_polaraxis(sp, sp[:yaxis])
        else
            x_domain, y_domain = plotly_domain(sp)
            if RecipesPipeline.is3d(sp)
                azim = sp[:camera][1] - 90 #convert azimuthal to match GR behaviour
                theta = 90 - sp[:camera][2] #spherical coordinate angle from z axis
                plotattributes_out[Symbol(:scene, spidx)] = KW(
                    :domain => KW(:x => x_domain, :y => y_domain),
                    Symbol("xaxis$(spidx)") => plotly_axis(sp[:xaxis], sp),
                    Symbol("yaxis$(spidx)") => plotly_axis(sp[:yaxis], sp),
                    Symbol("zaxis$(spidx)") => plotly_axis(sp[:zaxis], sp),

                    #2.6 multiplier set camera eye such that whole plot can be seen
                    :camera => KW(
                        :eye => KW(
                            :x => 2.6cosd(azim) * sind(theta),
                            :y => 2.6sind(azim) * sind(theta),
                            :z => 2.6cosd(theta),
                        ),
                        :projection => (
                            auto = "orthographic",  # we choose to unify backends by using a default "orthographic" proj when `:auto`
                            ortho = "orthographic",
                            orthographic = "orthographic",
                            persp = "perspective",
                            perspective = "perspective",
                        )[sp[:projection_type]],
                    ),
                )
            else
                plotattributes_out[Symbol("xaxis$(x_idx)")] =
                    plotly_axis(sp[:xaxis], sp, string("y", y_idx), x_domain)
                # don't allow yaxis to be reupdated/reanchored in a linked subplot
                if spidx == y_idx
                    plotattributes_out[Symbol("yaxis$(y_idx)")] =
                        plotly_axis(sp[:yaxis], sp, string("x", x_idx), y_domain)
                end
            end
        end

        # legend
        plotly_add_legend!(plotattributes_out, sp)

        # annotations
        for ann in sp[:annotations]
            append!(
                plotattributes_out[:annotations],
                KW[
                    plotly_annotation_dict(
                        locate_annotation(sp, ann...)...;
                        xref = "x$(x_idx)",
                        yref = "y$(y_idx)",
                    ),
                ],
            )
        end
        # series_annotations
        for series in series_list(sp)
            anns = series[:series_annotations]
            for (xi, yi, str, fnt) in EachAnn(anns, series[:x], series[:y])
                push!(
                    plotattributes_out[:annotations],
                    plotly_annotation_dict(
                        xi,
                        yi,
                        PlotText(str, fnt);
                        xref = "x$(x_idx)",
                        yref = "y$(y_idx)",
                    ),
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

        ispolar(sp) && (plotattributes_out[:direction] = "counterclockwise")

        plotattributes_out
    end

    # turn off hover if nothing's using it
    if all(series -> series.plotattributes[:hover] in (false, :none), plt.series_list)
        plotattributes_out[:hovermode] = "none"
    end

    return plotattributes_out =
        recursive_merge(plotattributes_out, plt.attr[:extra_plot_kwargs])
end

function plotly_add_legend!(plotattributes_out::KW, sp::Subplot)
    plotattributes_out[:showlegend] = sp[:legend_position] !== :none
    legend_position = plotly_legend_pos(sp[:legend_position])
    sp[:legend_position] === :none && return
    return plotattributes_out[:legend] = KW(
        :bgcolor => rgba_string(sp[:legend_background_color]),
        :bordercolor => rgba_string(sp[:legend_foreground_color]),
        :borderwidth => 1,
        :traceorder => "normal",
        :xanchor => legend_position.xanchor,
        :yanchor => legend_position.yanchor,
        :font => plotly_font(legendfont(sp)),
        :tracegroupgap => 0,
        :x => legend_position.coords[1],
        :y => legend_position.coords[2],
        :title => KW(
            :text => sp[:legend_title] === nothing ? "" : string(sp[:legend_title]),
            :font => plotly_font(legendtitlefont(sp)),
        ),
    )
end

#! format: off
plotly_legend_position_mapping = let center = 0.5,
    xcenter = 0.55, ycenter = 0.52,
    xleft = 0.07, xright = 1.0,
    ybot = 0.07, ytop = 1.0,
    youtertop = 1.1, youterbot = -0.15,
    xouterright = 1.05, xouterleft = -0.15
    (
        right = (coords = [xright, ycenter], xanchor = "right", yanchor = "middle"),
        left = (coords = [xleft, ycenter], xanchor = "left", yanchor = "middle"),
        top = (coords = [xcenter, ytop], xanchor = "center", yanchor = "top"),
        bottom = (coords = [xcenter, ybot], xanchor = "center", yanchor = "bottom"),
        bottomleft = (coords = [xleft, ybot], xanchor = "left", yanchor = "bottom"),
        bottomright = (coords = [xright, ybot], xanchor = "right", yanchor = "bottom"),
        topright = (coords = [xright, ytop], xanchor = "right", yanchor = "top"),
        topleft = (coords = [xleft, ytop], xanchor = "left", yanchor = "top"),
        outertop = (coords = [center, youtertop], xanchor = "upper", yanchor = "middle"),
        outerbottom = (coords = [center, youterbot], xanchor = "lower", yanchor = "middle"),
        outerleft = (coords = [xouterleft, center], xanchor = "left", yanchor = "top"),
        outerright = (coords = [xouterright, center], xanchor = "right", yanchor = "top"),
        outertopleft = (coords = [xouterleft, ytop], xanchor = "upper", yanchor = "left"),
        outertopright = (
            coords = [xouterright, ytop],
            xanchor = "upper",
            yanchor = "right",
        ),
        outerbottomleft = (
            coords = [xouterleft, ybot],
            xanchor = "lower",
            yanchor = "left",
        ),
        outerbottomright = (
            coords = [xouterright, ybot],
            xanchor = "lower",
            yanchor = "right",
        ),
        default = (coords = [xright, ytop], xanchor = "auto", yanchor = "auto"),
    )
end
#! format: on

plotly_legend_pos(pos::Symbol) =
    get(plotly_legend_position_mapping, pos, plotly_legend_position_mapping.default)

plotly_legend_pos(v::Tuple{S, T}) where {S <: Real, T <: Real} =
    (coords = v, xanchor = "left", yanchor = "top")

plotly_legend_pos(theta::Real) = plotly_legend_pos((theta, :inner))

function plotly_legend_pos(v::Tuple{S, Symbol}) where {S <: Real}
    (s, c) = sincosd(v[1])
    xanchors = ["left", "center", "right"]
    yanchors = ["bottom", "middle", "top"]

    if v[2] === :inner
        rect = 0.07, 0.5, 1.0, 0.07, 0.52, 1.0
        xanchor = xanchors[legend_anchor_index(c)]
        yanchor = yanchors[legend_anchor_index(s)]
    else
        rect = -0.15, 0.5, 1.05, -0.15, 0.52, 1.1
        xanchor = xanchors[4 - legend_anchor_index(c)]
        yanchor = yanchors[4 - legend_anchor_index(s)]
    end
    return (
        coords = legend_pos_from_angle(v[1], rect...),
        xanchor = xanchor,
        yanchor = yanchor,
    )
end

plotly_layout_json(plt::Plot) = JSON.json(plotly_layout(plt), 4)

plotly_colorscale(cg::ColorGradient, α = nothing) =
    map(v -> [v, rgba_string(plot_color(cg.colors[v], α))], cg.values)
plotly_colorscale(c::AbstractVector{<:Colorant}, α = nothing) =
if length(c) == 1
    [[0.0, rgba_string(plot_color(c[1], α))], [1.0, rgba_string(plot_color(c[1], α))]]
else
    vals = range(0.0, stop = 1.0, length = length(c))
    map(i -> [vals[i], rgba_string(plot_color(c[i], α))], eachindex(c))
end

function plotly_colorscale(cg::PlotUtils.CategoricalColorGradient, α = nothing)
    n = length(cg)
    cinds = repeat(1:n, inner = 2)
    vinds = vcat((i:(i + 1) for i in 1:n)...)
    return map(
        i -> [cg.values[vinds[i]], rgba_string(plot_color(color_list(cg)[cinds[i]], α))],
        eachindex(cinds),
    )
end
plotly_colorscale(c, α = nothing) = plotly_colorscale(_as_gradient(c), α)

get_plotly_marker(k, def) = get(
    (
        rect = "square",
        xcross = "x",
        x = "x",
        utriangle = "triangle-up",
        dtriangle = "triangle-down",
        star5 = "star-triangle-up",
        vline = "line-ns",
        hline = "line-ew",
    ),
    k,
    def,
)

# find indicies of axes to which the subplot links to
function plotly_link_indicies(plt::Plot, sp::Subplot)
    if plt[:link] in (:x, :y, :both)
        x_idx = sp[:xaxis].sps[1][:subplot_index]
        y_idx = sp[:yaxis].sps[1][:subplot_index]
    else
        x_idx = y_idx = sp[:subplot_index]
    end
    return x_idx, y_idx
end

# the Shape contructor will automatically close the shape. since we need it closed,
# we split by NaNs and then construct/destruct the shapes to get the closed coords
function plotly_close_shapes(x, y)
    xs, ys = nansplit(x), nansplit(y)
    for i in eachindex(xs)
        shape = Shape(xs[i], ys[i])
        xs[i], ys[i] = coords(shape)
    end
    return nanvcat(xs), nanvcat(ys)
end

function plotly_data(series::Series, letter::Symbol, data)
    axis = series[:subplot][get_attr_symbol(letter, :axis)]

    data = if axis[:ticks] === :native && data !== nothing
        plotly_native_data(axis, data)
    else
        data
    end

    return if series[:seriestype] in (:heatmap, :contour, :surface, :wireframe, :mesh3d)
        handle_surface(data)
    else
        plotly_data(data)
    end
end
plotly_data(v) = v !== nothing ? collect(v) : v
plotly_data(v::AbstractArray) = v
plotly_data(surf::Surface) = surf.surf
plotly_data(v::AbstractArray{R}) where {R <: Rational} = float(v)

plotly_native_data(axis::Axis, a::Surface) = Surface(plotly_native_data(axis, a.surf))
plotly_native_data(axis::Axis, data::AbstractArray) =
if !isempty(axis[:discrete_values])
    map(
        xi -> axis[:discrete_values][searchsortedfirst(axis[:continuous_values], xi)],
        data,
    )
elseif axis[:formatter] in (datetimeformatter, dateformatter, timeformatter)
    plotly_convert_to_datetime(data, axis[:formatter])
else
    data
end

plotly_convert_to_datetime(x::AbstractArray, formatter::Function) =
if formatter == datetimeformatter
    map(xi -> isfinite(xi) ? replace(formatter(xi), "T" => " ") : missing, x)
elseif formatter == dateformatter
    map(xi -> isfinite(xi) ? replace(formatter(xi), "T" => " ") : missing, x)
elseif formatter == timeformatter
    map(xi -> isfinite(xi) ? string(Dates.today(), " ", formatter(xi)) : missing, x)
else
    error(
        "Invalid DateTime formatter. Expected Plots.datetime/date/time formatter but got $formatter",
    )
end

#ensures that a gradient is called if a single color is supplied where a gradient is needed (e.g. if a series recipe defines marker_z)
as_gradient(grad::ColorGradient, α) = grad
as_gradient(grad, α) = cgrad(alpha = α)

# get a dictionary representing the series params (plotattributes is the Plots-dict, plotattributes_out is the Plotly-dict)
function plotly_series(plt::Plot, series::Series)
    sp = series[:subplot]
    clims = get_clims(sp, series)

    (st = series[:seriestype]) === :shape && return plotly_series_shapes(plt, series, clims)

    plotattributes_out = KW()

    # these are the axes that the series should be mapped to
    if RecipesPipeline.is3d(sp)
        spidx = length(plt.subplots) > 1 ? sp[:subplot_index] : ""
        plotattributes_out[:xaxis] = "x$spidx"
        plotattributes_out[:yaxis] = "y$spidx"
        plotattributes_out[:zaxis] = "z$spidx"
        plotattributes_out[:scene] = "scene$spidx"
    else
        x_idx, y_idx = length(plt.subplots) > 1 ? plotly_link_indicies(plt, sp) : ("", "")
        plotattributes_out[:xaxis] = "x$(x_idx)"
        plotattributes_out[:yaxis] = "y$(y_idx)"
    end
    plotattributes_out[:showlegend] = should_add_to_legend(series)

    if st === :straightline
        x, y = straightline_data(series, 100)
        z = series[:z]
    else
        x, y, z = series[:x], series[:y], series[:z]
    end

    x, y, z = (
        plotly_data(series, letter, data) for
            (letter, data) in zip((:x, :y, :z), (x, y, z))
    )

    plotattributes_out[:name] = series[:label]

    isscatter = st in (:scatter, :scatter3d, :scattergl)
    hasmarker = isscatter || series[:markershape] !== :none
    hasline = st in (:path, :path3d, :straightline)
    hasfillrange =
        st in (:path, :scatter, :scattergl, :straightline) &&
        (isa(series[:fillrange], AbstractVector) || isa(series[:fillrange], Tuple))

    plotattributes_out[:colorbar] = plotly_colorbar(sp)

    if is_2tuple(clims) && all(!isnan, clims)
        plotattributes_out[:zmin], plotattributes_out[:zmax] = clims
    end

    # set the "type"
    if st in (:path, :scatter, :scattergl, :straightline, :path3d, :scatter3d)
        return plotly_series_segments(series, plotattributes_out, x, y, z, clims)

    elseif st === :heatmap
        x = heatmap_edges(x, sp[:xaxis][:scale])
        y = heatmap_edges(y, sp[:yaxis][:scale])
        plotattributes_out[:type] = "heatmap"
        plotattributes_out[:x], plotattributes_out[:y], plotattributes_out[:z] = x, y, z
        plotattributes_out[:colorscale] =
            plotly_colorscale(series[:fillcolor], series[:fillalpha])
        plotattributes_out[:showscale] = hascolorbar(sp)

    elseif st === :contour
        filled = isfilledcontour(series)
        plotattributes_out[:type] = "contour"
        plotattributes_out[:x], plotattributes_out[:y], plotattributes_out[:z] = x, y, z
        plotattributes_out[:contours] = KW(
            :coloring => filled ? "fill" : "lines",
            :showlabels => series[:contour_labels] == true,
        )
        # Plotly does not support arbitrary sets of contours
        # (https://github.com/plotly/plotly.js/issues/4503)
        # so we distinguish AbstractRanges and AbstractVectors
        let levels = series[:levels]
            if levels isa AbstractRange
                plotattributes_out[:contours][:start] = first(levels)
                plotattributes_out[:contours][:end] = last(levels)
                plotattributes_out[:contours][:size] = step(levels)
            elseif levels isa AVec
                levels_range =
                    range(first(levels), stop = last(levels), length = length(levels))
                plotattributes_out[:contours][:start] = first(levels_range)
                plotattributes_out[:contours][:end] = last(levels_range)
                plotattributes_out[:contours][:size] = step(levels_range)
                @warn """
                setting arbitrary contour levels with Plotly backend is not supported;
                use a range to set equally-spaced contours or an integer to set the
                approximate number of contours with the keyword `levels`.
                Setting levels to $(levels_range)
                """
            elseif levels isa Integer
                plotattributes_out[:ncontours] = levels + 2
            end
        end
        plotattributes_out[:colorscale] =
            plotly_colorscale(series[:linecolor], series[:linealpha])
        plotattributes_out[:showscale] = hascolorbar(sp) && hascolorbar(series)

    elseif st in (:surface, :wireframe)
        plotattributes_out[:type] = "surface"
        plotattributes_out[:x], plotattributes_out[:y], plotattributes_out[:z] = x, y, z
        if st === :wireframe
            plotattributes_out[:hidesurface] = true
            wirelines = KW(
                :show => true,
                :color =>
                    rgba_string(plot_color(series[:linecolor], series[:linealpha])),
                :highlightwidth => series[:linewidth],
            )
            plotattributes_out[:contours] =
                KW(:x => wirelines, :y => wirelines, :z => wirelines)
            plotattributes_out[:showscale] = false
        else
            plotattributes_out[:colorscale] =
                plotly_colorscale(series[:fillcolor], series[:fillalpha])
            plotattributes_out[:opacity] = series[:fillalpha]
            if series[:fill_z] !== nothing
                plotattributes_out[:surfacecolor] = handle_surface(series[:fill_z])
            end
            plotattributes_out[:showscale] = hascolorbar(sp)
        end
    elseif st === :mesh3d
        plotattributes_out[:type] = "mesh3d"
        plotattributes_out[:x], plotattributes_out[:y], plotattributes_out[:z] = x, y, z

        if series[:connections] !== nothing
            if typeof(series[:connections]) <: Tuple{Array, Array, Array}
                # 0-based indexing
                i, j, k = series[:connections]
                if !(length(i) == length(j) == length(k))
                    throw(
                        ArgumentError(
                            "Argument connections must consist of equally sized arrays.",
                        ),
                    )
                end
                plotattributes_out[:i] = i
                plotattributes_out[:j] = j
                plotattributes_out[:k] = k
            elseif typeof(series[:connections]) <: AbstractVector{NTuple{3, Int}}
                # 1-based indexing
                i, j, k = broadcast(
                    i -> [inds[i] - 1 for inds in series[:connections]],
                    (1, 2, 3),
                )
                plotattributes_out[:i] = i
                plotattributes_out[:j] = j
                plotattributes_out[:k] = k
            else
                throw(
                    ArgumentError(
                        "Argument connections has to be either a tuple of three arrays (0-based indexing)
                         or an AbstractVector{NTuple{3,Int}} (1-based indexing).",
                    ),
                )
            end
        end
        plotattributes_out[:colorscale] =
            plotly_colorscale(series[:fillcolor], series[:fillalpha])
        plotattributes_out[:color] =
            rgba_string(plot_color(series[:fillcolor], series[:fillalpha]))
        plotattributes_out[:opacity] = series[:fillalpha]
        if series[:fill_z] !== nothing
            plotattributes_out[:surfacecolor] = handle_surface(series[:fill_z])
        end
        plotattributes_out[:showscale] = hascolorbar(sp)
    else
        @warn "Plotly: seriestype $st isn't supported."
        return KW()
    end

    # add "marker"
    if hasmarker
        inds = eachindex(x)
        plotattributes_out[:marker] = KW(
            :symbol =>
                get_plotly_marker(series[:markershape], string(series[:markershape])),
            # :opacity => series[:markeralpha],
            :size => 2_cycle(series[:markersize], inds),
            :color =>
                rgba_string.(
                plot_color.(
                    get_markercolor.(series, inds),
                    get_markeralpha.(series, inds),
                ),
            ),
            :line => KW(
                :color =>
                    rgba_string.(
                    plot_color.(
                        get_markerstrokecolor.(series, inds),
                        get_markerstrokealpha.(series, inds),
                    ),
                ),
                :width => _cycle(series[:markerstrokewidth], inds),
            ),
        )
    end

    plotly_polar!(plotattributes_out, series)
    plotly_adjust_hover_label!(plotattributes_out, series[:hover])

    return [merge(plotattributes_out, series[:extra_kwargs])]
end

function plotly_colorbar(sp::Subplot)
    x_domain, y_domain = plotly_domain(sp)
    plot_attribute = KW(
        :title => sp[:colorbar_title],
        :y => mean(y_domain),
        :len => diff(y_domain)[1],
        :x => x_domain[2],
    )
    return plot_attribute
end

function plotly_series_shapes(plt::Plot, series::Series, clims)
    plotattributes_outs = KW[]
    i = 1
    # these are the axes that the series should be mapped to
    x_idx, y_idx = plotly_link_indicies(plt, series[:subplot])
    plotattributes_base = KW(
        :xaxis => "x$(x_idx)",
        :yaxis => "y$(y_idx)",
        :name => series[:label],
        :legendgroup => series[:label],
    )

    for (xs, ys) in zip(nansplit(series[:x]), nansplit(series[:y]))

        # to draw polygons, we actually draw lines with fill
        plotattributes_out = merge(
            plotattributes_base,
            KW(
                :type => "scatter",
                :mode => "lines",
                :x => xs,
                :y => ys,
                :fill => "tozeroy",
                :fillcolor => rgba_string(
                    plot_color(get_fillcolor(series, clims, i), get_fillalpha(series, i)),
                ),
            ),
        )
        if series[:markerstrokewidth] > 0
            plotattributes_out[:line] = KW(
                :color => rgba_string(
                    plot_color(get_linecolor(series, clims, i), get_linealpha(series, i)),
                ),
                :width => get_linewidth(series, i),
                :dash => string(get_linestyle(series, i)),
            )
        end
        plotattributes_out[:showlegend] = i == 1 ? should_add_to_legend(series) : false
        plotly_polar!(plotattributes_out, series)
        plotly_adjust_hover_label!(plotattributes_out, _cycle(series[:hover], i))
        push!(plotattributes_outs, merge(plotattributes_out, series[:extra_kwargs]))
        i += 1
    end
    if series[:fill_z] !== nothing
        push!(plotattributes_outs, plotly_colorbar_hack(series, plotattributes_base, :fill))
    elseif series[:line_z] !== nothing
        push!(plotattributes_outs, plotly_colorbar_hack(series, plotattributes_base, :line))
    elseif series[:marker_z] !== nothing
        push!(
            plotattributes_outs,
            plotly_colorbar_hack(series, plotattributes_base, :marker),
        )
    end
    return plotattributes_outs
end

function plotly_series_segments(series::Series, plotattributes_base::KW, x, y, z, clims)
    st = series[:seriestype]
    sp = series[:subplot]
    isscatter = st in (:scatter, :scatter3d, :scattergl)
    hasmarker = isscatter || series[:markershape] !== :none
    hasline = st in (:path, :path3d, :straightline)
    hasfillrange =
        st in (:path, :scatter, :scattergl, :straightline) &&
        (isa(series[:fillrange], AbstractVector) || isa(series[:fillrange], Tuple))

    segments = collect(series_segments(series, st))
    plotattributes_outs = fill(KW(), (hasfillrange ? 2 : 1) * length(segments))

    needs_scatter_fix = !isscatter && hasmarker && !any(isnan, y) && length(segments) > 1

    for (k, segment) in enumerate(segments)
        i, rng = segment.attr_index, segment.range

        plotattributes_out = deepcopy(plotattributes_base)
        plotattributes_out[:showlegend] = k == 1 ? should_add_to_legend(series) : false
        plotattributes_out[:legendgroup] = series[:label]

        # set the type
        if st in (:path, :scatter, :scattergl, :straightline)
            plotattributes_out[:type] = st === :scattergl ? "scattergl" : "scatter"
            plotattributes_out[:mode] = if hasmarker
                hasline ? "lines+markers" : "markers"
            else
                hasline ? "lines" : "none"
            end
            if series[:fillrange] == true ||
                    series[:fillrange] == 0 ||
                    isa(series[:fillrange], Tuple)
                plotattributes_out[:fill] = "tozeroy"
                plotattributes_out[:fillcolor] = rgba_string(
                    plot_color(get_fillcolor(series, clims, i), get_fillalpha(series, i)),
                )
            elseif typeof(series[:fillrange]) <: Union{AbstractVector{<:Real}, Real}
                plotattributes_out[:fill] = "tonexty"
                plotattributes_out[:fillcolor] = rgba_string(
                    plot_color(get_fillcolor(series, clims, i), get_fillalpha(series, i)),
                )
            elseif !(series[:fillrange] in (false, nothing))
                @warn "fillrange ignored... plotly only supports filling to zero and to a vector of values. fillrange: $(series[:fillrange])"
            end
            plotattributes_out[:x], plotattributes_out[:y] = x[rng], y[rng]

        elseif st in (:path3d, :scatter3d)
            plotattributes_out[:type] = "scatter3d"
            plotattributes_out[:mode] = if hasmarker
                hasline ? "lines+markers" : "markers"
            else
                hasline ? "lines" : "none"
            end
            plotattributes_out[:x], plotattributes_out[:y], plotattributes_out[:z] =
                x[rng], y[rng], z[rng]
        end

        # add "marker"
        if hasmarker
            mcolor = rgba_string(
                plot_color(get_markercolor(series, clims, i), get_markeralpha(series, i)),
            )
            mcolor_next = if (mz = series[:marker_z]) !== nothing && i < length(mz)
                plot_color(
                    get_markercolor(series, clims, i + 1),
                    get_markeralpha(series, i + 1),
                ) |> rgba_string
            else
                mcolor
            end
            lcolor = rgba_string(
                plot_color(
                    get_markerstrokecolor(series, i),
                    get_markerstrokealpha(series, i),
                ),
            )
            lcolor_next =
                plot_color(
                get_markerstrokecolor(series, i + 1),
                get_markerstrokealpha(series, i + 1),
            ) |> rgba_string

            plotattributes_out[:marker] = KW(
                :symbol => get_plotly_marker(
                    _cycle(series[:markershape], i),
                    string(_cycle(series[:markershape], i)),
                ),
                # :opacity => needs_scatter_fix ? [1, 0] : 1,
                :size => 2_cycle(series[:markersize], i),
                :color => needs_scatter_fix ? [mcolor, mcolor_next] : mcolor,
                :line => KW(
                    :color => needs_scatter_fix ? [lcolor, lcolor_next] : lcolor,
                    :width => _cycle(series[:markerstrokewidth], i),
                ),
            )
        end

        # add "line"
        if hasline
            plotattributes_out[:line] = KW(
                :color => rgba_string(
                    plot_color(get_linecolor(series, clims, i), get_linealpha(series, i)),
                ),
                :width => get_linewidth(series, i),
                :shape => if st === :steppre
                    "vh"
                elseif st === :stepmid
                    "hvh"
                elseif st === :steppost
                    "hv"
                else
                    "linear"
                end,
                :dash => string(get_linestyle(series, i)),
            )
        end

        plotly_polar!(plotattributes_out, series)
        plotly_adjust_hover_label!(plotattributes_out, _cycle(series[:hover], rng))

        if hasfillrange
            # if hasfillrange is true, return two dictionaries (one for original
            # series, one for series being filled to) instead of one
            plotattributes_out_fillrange = deepcopy(plotattributes_out)
            plotattributes_out_fillrange[:showlegend] = false
            # if fillrange is provided as real or tuple of real, expand to array
            if typeof(series[:fillrange]) <: Real
                plotattributes_out[:fillrange] = fill(series[:fillrange], length(rng))
            elseif typeof(series[:fillrange]) <: Tuple
                f1 =
                    (fr1 = series[:fillrange][1]) |> typeof <: Real ?
                    fill(fr1, length(rng)) : fr1[rng]
                f2 =
                    (fr2 = series[:fillrange][2]) |> typeof <: Real ?
                    fill(fr2, length(rng)) : fr2[rng]
                plotattributes_out[:fillrange] = (f1, f2)
            end
            if isa(series[:fillrange], AbstractVector)
                plotattributes_out_fillrange[:y] = series[:fillrange][rng]
                delete!(plotattributes_out_fillrange, :fill)
                delete!(plotattributes_out_fillrange, :fillcolor)
            else
                # if fillrange is a tuple with upper and lower limit, plotattributes_out_fillrange
                # is the series that will do the filling
                plotattributes_out_fillrange[:x], plotattributes_out_fillrange[:y] =
                    concatenate_fillrange(x[rng], series[:fillrange])
                plotattributes_out_fillrange[:line][:width] = 0
                delete!(plotattributes_out, :fill)
                delete!(plotattributes_out, :fillcolor)
            end

            plotattributes_outs[(2k - 1):(2k)] =
                [plotattributes_out_fillrange, plotattributes_out]
        else
            plotattributes_outs[k] = plotattributes_out
        end
        plotattributes_outs[k] = merge(plotattributes_outs[k], series[:extra_kwargs])
    end

    if series[:line_z] !== nothing
        push!(plotattributes_outs, plotly_colorbar_hack(series, plotattributes_base, :line))
    elseif series[:fill_z] !== nothing
        push!(plotattributes_outs, plotly_colorbar_hack(series, plotattributes_base, :fill))
    elseif series[:marker_z] !== nothing
        push!(
            plotattributes_outs,
            plotly_colorbar_hack(series, plotattributes_base, :marker),
        )
    end

    return plotattributes_outs
end

function plotly_colorbar_hack(series::Series, plotattributes_base::KW, sym::Symbol)
    plotattributes_out = deepcopy(plotattributes_base)
    cmin, cmax = get_clims(series[:subplot])
    plotattributes_out[:showlegend] = false
    plotattributes_out[:type] = RecipesPipeline.is3d(series) ? :scatter3d : :scatter
    plotattributes_out[:hoverinfo] = :none
    plotattributes_out[:mode] = :markers
    plotattributes_out[:x], plotattributes_out[:y] = [series[:x][1]], [series[:y][1]]
    if RecipesPipeline.is3d(series)
        plotattributes_out[:z] = [series[:z][1]]
    end
    # zrange = zmax == zmin ? 1 : zmax - zmin # if all marker_z values are the same, plot all markers same color (avoids division by zero in next line)
    plotattributes_out[:marker] = KW(
        :size => 1.0e-10,
        :opacity => 1.0e-10,
        :color => [0.5],
        :cmin => cmin,
        :cmax => cmax,
        :colorscale => plotly_colorscale(series[Symbol("$(sym)color")], 1),
        :showscale => hascolorbar(series[:subplot]),
    )
    return plotattributes_out
end

plotly_polar!(plotattributes_out::KW, series::Series) =
if ispolar(series[:subplot])  # convert polar plots x/y to theta/radius
    theta, r = pop!(plotattributes_out, :x), pop!(plotattributes_out, :y)
    plotattributes_out[:theta] = rad2deg.(theta)
    plotattributes_out[:r] = r
    plotattributes_out[:type] = :scatterpolar
end

function plotly_adjust_hover_label!(plotattributes_out::KW, hover)
    if hover === nothing
        return
    elseif all(in([:none, false]), hover)
        plotattributes_out[:hoverinfo] = "none"
    elseif any(!isnothing, hover)
        plotattributes_out[:hoverinfo] = "text"
        plotattributes_out[:text] = hover
    end
    return nothing
end

# get a list of dictionaries, each representing the series params
function plotly_series(plt::Plot)
    isempty(plt.series_list) && return KW[]
    return reduce(vcat, plotly_series(plt, series) for series in plt.series_list)
end

# get json string for a list of dictionaries, each representing the series params
plotly_series_json(plt::Plot) = JSON.json(plotly_series(plt), 4)

# ----------------------------------------------------------------

html_head(plt::Plot{PlotlyBackend}) = plotly_html_head(plt)
html_body(plt::Plot{PlotlyBackend}) = plotly_html_body(plt)

plotly_url() =
if _use_local_dependencies[]
    _plotly_data_url()
else
    "https://cdn.plot.ly/$_plotly_min_js_filename"
end

function plotly_html_head(plt::Plot)
    plotly = plotly_url()

    include_mathjax = get(plt[:extra_plot_kwargs], :include_mathjax, "")

    mathjax_file = if include_mathjax != "cdn"
        "file://" * include_mathjax
    else
        "https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.7/MathJax.js?config=TeX-MML-AM_CHTML"
    end

    mathjax_head = if isempty(include_mathjax)
        ""
    else
        "<script src=\"$mathjax_file\"></script>\n\t\t"
    end

    return if isijulia()
        mathjax_head
    else
        "$mathjax_head<script src=$(repr(plotly))></script>"
    end
end

function plotly_html_body(plt, style = nothing)
    if style === nothing
        w, h = plt[:size]
        style = "width:$(w)px;height:$(h)px;"
    end

    requirejs_prefix = requirejs_suffix = ""
    if isijulia()
        # require.js adds .js automatically
        plotly_no_ext = plotly_url() |> splitext |> first

        requirejs_prefix = """
            requirejs.config({
                paths: {
                    plotly: '$(plotly_no_ext)'
                }
            });
            require(['plotly'], function (Plotly) {
        """
        requirejs_suffix = "});"
    end

    unique_tag = "id_$(replace(string(UUIDs.uuid4()), '-' => '_'))"

    html = """
        <div id=\"$unique_tag\" style=\"$style\"></div>
        <script>
        ;(()=> {
        function plots_jl_plotly_$unique_tag() {
            $(requirejs_prefix)
            $(js_body(plt, unique_tag))
            $(requirejs_suffix)
        }
        let plotlyloader = window.document.createElement("script")
        let src="https://requirejs.org/docs/release/$(Plots._requirejs_version)/minified/require.js"
        plotlyloader.addEventListener("load", plots_jl_plotly_$unique_tag);
        plotlyloader.src = src
        document.querySelector("#$unique_tag").appendChild(plotlyloader)
        })()
        </script>
    """
    return html
end

js_body(plt::Plot, unique_tag) =
    "Plotly.newPlot('$unique_tag', $(plotly_series_json(plt)), $(plotly_layout_json(plt)));"

plotly_show_js(io::IO, plot::Plot) =
    JSON.print(io, Dict(:data => plotly_series(plot), :layout => plotly_layout(plot)))

# ----------------------------------------------------------------

Base.showable(::MIME"application/prs.juno.plotpane+html", plt::Plot{PlotlyBackend}) = true

_show(io::IO, ::MIME"application/vnd.plotly.v1+json", plot::Plot{PlotlyBackend}) =
    plotly_show_js(io, plot)

_show(io::IO, ::MIME"text/html", plt::Plot{PlotlyBackend}) = write(io, embeddable_html(plt))

_display(plt::Plot{PlotlyBackend}) = standalone_html_window(plt)
