# https://github.com/sisl/PGFPlots.jl

# significant contributions by: @pkofod

# --------------------------------------------------------------------------------------
# COV_EXCL_START
const _pgfplots_linestyles = KW(
    :solid => "solid",
    :dash => "dashed",
    :dot => "dotted",
    :dashdot => "dashdotted",
    :dashdotdot => "dashdotdotted",
)

const _pgfplots_markers = KW(
    :none => "none",
    :cross => "+",
    :xcross => "x",
    :+ => "+",
    :x => "x",
    :utriangle => "triangle*",
    :dtriangle => "triangle*",
    :circle => "*",
    :rect => "square*",
    :star5 => "star",
    :star6 => "asterisk",
    :diamond => "diamond*",
    :pentagon => "pentagon*",
    :hline => "-",
    :vline => "|",
)

const _pgfplots_legend_pos = KW(
    :bottomleft => "south west",
    :bottomright => "south east",
    :topright => "north east",
    :topleft => "north west",
    :outertopright => "outer north east",
)

const _pgf_series_extrastyle = KW(
    :steppre => "const plot mark right",
    :stepmid => "const plot mark mid",
    :steppost => "const plot",
    :sticks => "ycomb",
    :ysticks => "ycomb",
    :xsticks => "xcomb",
)

# PGFPlots uses the anchors to define orientations for example to align left
# one needs to use the right edge as anchor
const _pgf_annotation_halign = KW(:center => "", :left => "right", :right => "left")

const _pgf_framestyles = [:box, :axes, :origin, :zerolines, :grid, :none]
const _pgf_framestyle_defaults = Dict(:semi => :box)
function pgf_framestyle(style::Symbol)
    if style in _pgf_framestyles
        return style
    else
        default_style = get(_pgf_framestyle_defaults, style, :axes)
        @warn "Framestyle :$style is not (yet) supported by the PGFPlots backend. :$default_style was cosen instead."
        default_style
    end
end

# --------------------------------------------------------------------------------------

# takes in color,alpha, and returns color and alpha appropriate for pgf style
function pgf_color(c::Colorant)
    cstr = @sprintf "{rgb,1:red,%.8f;green,%.8f;blue,%.8f}" red(c) green(c) blue(c)
    return cstr, alpha(c)
end

function pgf_color(grad::ColorGradient)
    # Can't handle ColorGradient here, fallback to defaults.
    cstr = @sprintf "{rgb,1:red,%.8f;green,%.8f;blue,%.8f}" 0.0 0.60560316 0.97868012
    return cstr, 1
end

# Generates a colormap for pgfplots based on a ColorGradient
pgf_colormap(grad::ColorGradient) = join(
    map(c -> @sprintf("rgb=(%.8f,%.8f,%.8f)", red(c), green(c), blue(c)), grad.colors),
    ", ",
)

pgf_thickness_scaling(plt::Plot) = plt[:thickness_scaling]
pgf_thickness_scaling(sp::Subplot) = pgf_thickness_scaling(sp.plt)
pgf_thickness_scaling(series) = pgf_thickness_scaling(series[:subplot])

function pgf_fillstyle(plotattributes, i = 1)
    cstr, a = pgf_color(get_fillcolor(plotattributes, i))
    fa = get_fillalpha(plotattributes, i)
    if fa !== nothing
        a = fa
    end
    return "fill = $cstr, fill opacity=$a"
end

function pgf_linestyle(linewidth::Real, color, α = 1, linestyle = "solid")
    cstr, a = pgf_color(plot_color(color, α))
    return """
    color = $cstr,
    draw opacity = $a,
    line width = $linewidth,
    $(get(_pgfplots_linestyles, linestyle, "solid"))"""
end

function pgf_linestyle(plotattributes, i = 1)
    lw = pgf_thickness_scaling(plotattributes) * get_linewidth(plotattributes, i)
    lc = get_linecolor(plotattributes, i)
    la = get_linealpha(plotattributes, i)
    ls = get_linestyle(plotattributes, i)
    return pgf_linestyle(lw, lc, la, ls)
end

function pgf_font(fontsize, thickness_scaling = 1, font = "\\selectfont")
    fs = fontsize * thickness_scaling
    return string("{\\fontsize{", fs, " pt}{", 1.3fs, " pt}", font, "}")
end

function pgf_marker(plotattributes, i = 1)
    shape = _cycle(plotattributes[:markershape], i)
    cstr, a = pgf_color(
        plot_color(get_markercolor(plotattributes, i), get_markeralpha(plotattributes, i)),
    )
    cstr_stroke, a_stroke = pgf_color(
        plot_color(
            get_markerstrokecolor(plotattributes, i),
            get_markerstrokealpha(plotattributes, i),
        ),
    )
    return string(
        "mark = $(get(_pgfplots_markers, shape, "*")),\n",
        "mark size = $(pgf_thickness_scaling(plotattributes) * 0.5 * _cycle(plotattributes[:markersize], i)),\n",
        plotattributes[:seriestype] === :scatter ? "only marks,\n" : "",
        "mark options = {
            color = $cstr_stroke, draw opacity = $a_stroke,
            fill = $cstr, fill opacity = $a,
            line width = $(pgf_thickness_scaling(plotattributes) * _cycle(plotattributes[:markerstrokewidth], i)),
            rotate = $(shape === :dtriangle ? 180 : 0),
            $(get(_pgfplots_linestyles, _cycle(plotattributes[:markerstrokestyle], i), "solid"))
        }",
    )
end

function pgf_add_annotation!(o, x, y, val, thickness_scaling = 1)
    # Construct the style string.
    # Currently supports color and orientation
    cstr, a = pgf_color(val.font.color)
    return push!(
        o,
        PGFPlots.Plots.Node(
            val.str, # Annotation Text
            x,
            y,
            style = """
            $(get(_pgf_annotation_halign, val.font.halign, "")),
            color=$cstr, draw opacity=$(convert(Float16, a)),
            rotate=$(val.font.rotation),
            font=$(pgf_font(val.font.pointsize, thickness_scaling))
            """,
        ),
    )
end

# --------------------------------------------------------------------------------------

function pgf_series(sp::Subplot, series::Series)
    plotattributes = series.plotattributes
    st = plotattributes[:seriestype]
    series_collection = PGFPlots.Plot[]

    # function args
    args = if st === :contour
        plotattributes[:z].surf, plotattributes[:x], plotattributes[:y]
    elseif RecipesPipeline.is3d(st)
        plotattributes[:x], plotattributes[:y], plotattributes[:z]
    elseif st === :straightline
        straightline_data(series)
    elseif st === :shape
        shape_data(series)
    elseif ispolar(sp)
        theta, r = plotattributes[:x], plotattributes[:y]
        rad2deg.(theta), r
    else
        plotattributes[:x], plotattributes[:y]
    end

    # PGFPlots can't handle non-Vector?
    # args = map(a -> if typeof(a) <: AbstractVector && typeof(a) != Vector
    #         collect(a)
    #     else
    #         a
    #     end, args)

    if st in (:contour, :histogram2d)
        style = []
        kw = KW()
        push!(style, pgf_linestyle(plotattributes))
        push!(style, pgf_marker(plotattributes))
        push!(style, "forget plot")

        kw[:style] = join(style, ',')
        func = if st === :histogram2d
            PGFPlots.Histogram2
        else
            kw[:labels] = series[:contour_labels]
            kw[:levels] = series[:levels]
            PGFPlots.Contour
        end
        push!(series_collection, func(args...; kw...))

    else
        # series segments
        segments = iter_segments(series)
        for (i, rng) in enumerate(segments)
            style = []
            kw = KW()
            push!(style, pgf_linestyle(plotattributes, i))
            push!(style, pgf_marker(plotattributes, i))

            if st === :shape
                push!(style, pgf_fillstyle(plotattributes, i))
            end

            # add to legend?
            if i == 1 && sp[:legend_position] !== :none && should_add_to_legend(series)
                if plotattributes[:fillrange] !== nothing
                    push!(style, "forget plot")
                    push!(series_collection, pgf_fill_legend_hack(plotattributes, args))
                else
                    kw[:legendentry] = plotattributes[:label]
                    if st === :shape # || plotattributes[:fillrange] !== nothing
                        push!(style, "area legend")
                    end
                end
            else
                push!(style, "forget plot")
            end

            seg_args = (arg[rng] for arg in args)

            # include additional style, then add to the kw
            if haskey(_pgf_series_extrastyle, st)
                push!(style, _pgf_series_extrastyle[st])
            end
            kw[:style] = join(style, ',')

            # add fillrange
            if series[:fillrange] !== nothing && st !== :shape
                push!(
                    series_collection,
                    pgf_fillrange_series(
                        series,
                        i,
                        _cycle(series[:fillrange], rng),
                        seg_args...,
                    ),
                )
            end

            # build/return the series object
            func = if st === :path3d
                PGFPlots.Linear3
            elseif st === :scatter
                PGFPlots.Scatter
            else
                PGFPlots.Linear
            end
            push!(series_collection, func(seg_args...; kw...))
        end
    end
    return series_collection
end

function pgf_fillrange_series(series, i, fillrange, args...)
    st = series[:seriestype]
    style = []
    kw = KW()
    push!(style, "line width = 0")
    push!(style, "draw opacity = 0")
    push!(style, pgf_fillstyle(series, i))
    push!(style, pgf_marker(series, i))
    push!(style, "forget plot")
    if haskey(_pgf_series_extrastyle, st)
        push!(style, _pgf_series_extrastyle[st])
    end
    kw[:style] = join(style, ',')
    func = RecipesPipeline.is3d(series) ? PGFPlots.Linear3 : PGFPlots.Linear
    return func(pgf_fillrange_args(fillrange, args...)...; kw...)
end

function pgf_fillrange_args(fillrange, x, y)
    n = length(x)
    x_fill = [x; x[n:-1:1]; x[1]]
    y_fill = [y; _cycle(fillrange, n:-1:1); y[1]]
    return x_fill, y_fill
end

function pgf_fillrange_args(fillrange, x, y, z)
    n = length(x)
    x_fill = [x; x[n:-1:1]; x[1]]
    y_fill = [y; y[n:-1:1]; x[1]]
    z_fill = [z; _cycle(fillrange, n:-1:1); z[1]]
    return x_fill, y_fill, z_fill
end

function pgf_fill_legend_hack(plotattributes, args)
    style = []
    kw = KW()
    push!(style, pgf_linestyle(plotattributes, 1))
    push!(style, pgf_marker(plotattributes, 1))
    push!(style, pgf_fillstyle(plotattributes, 1))
    push!(style, "area legend")
    kw[:legendentry] = plotattributes[:label]
    kw[:style] = join(style, ',')
    st = plotattributes[:seriestype]
    func = if st === :path3d
        PGFPlots.Linear3
    elseif st === :scatter
        PGFPlots.Scatter
    else
        PGFPlots.Linear
    end
    return func(([arg[1]] for arg in args)...; kw...)
end

# ----------------------------------------------------------------

function pgf_axis(sp::Subplot, letter)
    axis = sp[get_attr_symbol(letter, :axis)]
    style = []
    kw = KW()

    # turn off scaled ticks
    push!(style, "scaled $(letter) ticks = false")

    # set to supported framestyle
    framestyle = pgf_framestyle(sp[:framestyle])

    # axis guide
    kw[get_attr_symbol(letter, :label)] = Plots.get_guide(axis)

    # axis label position
    labelpos = ""
    if letter === :x && axis[:guide_position] === :top
        labelpos = "at={(0.5,1)},above,"
    elseif letter === :y && axis[:guide_position] === :right
        labelpos = "at={(1,0.5)},below,"
    end

    # Add label font
    cstr, α = pgf_color(plot_color(axis[:guidefontcolor]))
    push!(
        style,
        string(
            letter,
            "label style = {",
            labelpos,
            "font = ",
            pgf_font(axis[:guidefontsize], pgf_thickness_scaling(sp)),
            ", color = ",
            cstr,
            ", draw opacity = ",
            α,
            ", rotate = ",
            axis[:guidefontrotation],
            "}",
        ),
    )

    # flip/reverse?
    axis[:flip] && push!(style, "$letter dir=reverse")

    # scale
    scale = axis[:scale]
    if scale in (:log2, :ln, :log10)
        kw[get_attr_symbol(letter, :mode)] = "log"
        scale === :ln || push!(style, "log basis $letter=$(scale === :log2 ? 2 : 10)")
    end

    # ticks on or off
    if axis[:ticks] in (nothing, false, :none) || framestyle === :none
        push!(style, "$(letter)majorticks=false")
    end

    # grid on or off
    if axis[:grid] && framestyle !== :none
        push!(style, "$(letter)majorgrids = true")
    else
        push!(style, "$(letter)majorgrids = false")
    end

    # limits
    # TODO: support zlims
    if letter !== :z
        lims =
            ispolar(sp) && letter === :x ? rad2deg.(axis_limits(sp, :x)) :
            axis_limits(sp, letter)
        kw[get_attr_symbol(letter, :min)] = lims[1]
        kw[get_attr_symbol(letter, :max)] = lims[2]
    end

    if !(axis[:ticks] in (nothing, false, :none, :native)) && framestyle !== :none
        ticks = get_ticks(sp, axis)
        #pgf plot ignores ticks with angle below 90 when xmin = 90 so shift values
        tick_values =
            ispolar(sp) && letter === :x ? [rad2deg.(ticks[1])[3:end]..., 360, 405] :
            ticks[1]
        push!(style, string(letter, "tick = {", join(tick_values, ","), "}"))
        if axis[:showaxis] && axis[:scale] in (:ln, :log2, :log10) && axis[:ticks] === :auto
            # wrap the power part of label with }
            tick_labels = Vector{String}(undef, length(ticks[2]))
            for (i, label) in enumerate(ticks[2])
                base, power = split(label, "^")
                power = string("{", power, "}")
                tick_labels[i] = string(base, "^", power)
            end
            push!(
                style,
                string(letter, "ticklabels = {\$", join(tick_labels, "\$,\$"), "\$}"),
            )
        elseif axis[:showaxis]
            tick_labels =
                ispolar(sp) && letter === :x ? [ticks[2][3:end]..., "0", "45"] : ticks[2]
            if axis[:formatter] in (:scientific, :auto)
                tick_labels = string.("\$", convert_sci_unicode.(tick_labels), "\$")
                tick_labels = replace.(tick_labels, Ref("×" => "\\times"))
            end
            push!(style, string(letter, "ticklabels = {", join(tick_labels, ","), "}"))
        else
            push!(style, string(letter, "ticklabels = {}"))
        end
        push!(
            style,
            string(
                letter,
                "tick align = ",
                (axis[:tick_direction] === :out ? "outside" : "inside"),
            ),
        )
        cstr, α = pgf_color(plot_color(axis[:tickfontcolor]))
        push!(
            style,
            string(
                letter,
                "ticklabel style = {font = ",
                pgf_font(axis[:tickfontsize], pgf_thickness_scaling(sp)),
                ", color = ",
                cstr,
                ", draw opacity = ",
                α,
                ", rotate = ",
                axis[:tickfontrotation],
                "}",
            ),
        )
        push!(
            style,
            string(
                letter,
                " grid style = {",
                pgf_linestyle(
                    pgf_thickness_scaling(sp) * axis[:gridlinewidth],
                    axis[:foreground_color_grid],
                    axis[:gridalpha],
                    axis[:gridstyle],
                ),
                "}",
            ),
        )
    end

    # framestyle
    if framestyle in (:axes, :origin)
        axispos = framestyle === :axes ? "left" : "middle"
        if axis[:draw_arrow]
            push!(style, string("axis ", letter, " line = ", axispos))
        else
            # the * after line disables the arrow at the axis
            push!(style, string("axis ", letter, " line* = ", axispos))
        end
    end

    if framestyle === :zerolines
        push!(style, string("extra ", letter, " ticks = 0"))
        push!(style, string("extra ", letter, " tick labels = "))
        push!(
            style,
            string(
                "extra ",
                letter,
                " tick style = {grid = major, major grid style = {",
                pgf_linestyle(
                    pgf_thickness_scaling(sp),
                    axis[:foreground_color_border],
                    1.0,
                ),
                "}}",
            ),
        )
    end

    if !axis[:showaxis]
        push!(style, "separate axis lines")
    end
    if !axis[:showaxis] || framestyle in (:zerolines, :grid, :none)
        push!(style, string(letter, " axis line style = {draw opacity = 0}"))
    else
        push!(
            style,
            string(
                letter,
                " axis line style = {",
                pgf_linestyle(
                    pgf_thickness_scaling(sp),
                    axis[:foreground_color_border],
                    1.0,
                ),
                "}",
            ),
        )
    end

    # return the style list and KW args
    return style, kw
end

# ----------------------------------------------------------------

function _update_plot_object(plt::Plot{PGFPlotsBackend})
    plt.o = PGFPlots.Axis[]
    # Obtain the total height of the plot by extracting the maximal bottom
    # coordinate from the bounding box.
    total_height = bottom(bbox(plt.layout))

    for sp in plt.subplots
        # first build the PGFPlots.Axis object
        style = ["unbounded coords=jump"]
        kw = KW()

        # add to style/kw for each axis
        for letter in (:x, :y, :z)
            if letter !== :z || RecipesPipeline.is3d(sp)
                axisstyle, axiskw = pgf_axis(sp, letter)
                append!(style, axisstyle)
                merge!(kw, axiskw)
            end
        end

        # bounding box values are in mm
        # note: bb origin is top-left, pgf is bottom-left
        # A round on 2 decimal places should be enough precision for 300 dpi
        # plots.
        bb = bbox(sp)
        push!(
            style,
            """
                xshift = $(left(bb).value)mm,
                yshift = $(round((total_height - (bottom(bb))).value, digits = 2))mm,
                axis background/.style={fill=$(pgf_color(sp[:background_color_inside])[1])}
            """,
        )
        kw[:width] = "$(width(bb).value)mm"
        kw[:height] = "$(height(bb).value)mm"

        if sp[:title] != ""
            kw[:title] = "$(sp[:title])"
            cstr, α = pgf_color(plot_color(sp[:titlefontcolor]))
            push!(
                style,
                string(
                    "title style = {font = ",
                    pgf_font(sp[:titlefontsize], pgf_thickness_scaling(sp)),
                    ", color = ",
                    cstr,
                    ", draw opacity = ",
                    α,
                    ", rotate = ",
                    sp[:titlefontrotation],
                    "}",
                ),
            )
        end

        if get_aspect_ratio(sp) in (1, :equal)
            kw[:axisEqual] = "true"
        end

        legpos = sp[:legend_position]
        if haskey(_pgfplots_legend_pos, legpos)
            kw[:legendPos] = _pgfplots_legend_pos[legpos]
        end
        cstr, bg_alpha = pgf_color(plot_color(sp[:legend_background_color]))
        fg_alpha = alpha(plot_color(sp[:legend_foreground_color]))

        push!(
            style,
            string(
                "legend style = {",
                pgf_linestyle(
                    pgf_thickness_scaling(sp),
                    sp[:legend_foreground_color],
                    fg_alpha,
                    "solid",
                ),
                ",",
                "fill = $cstr,",
                "fill opacity = $bg_alpha,",
                "text opacity = $(alpha(plot_color(sp[:legend_font_color]))),",
                "font = ",
                pgf_font(sp[:legend_font_pointsize], pgf_thickness_scaling(sp)),
                "}",
            ),
        )

        if any(s[:seriestype] === :contour for s in series_list(sp))
            kw[:view] = "{0}{90}"
            kw[:colorbar] = !(sp[:colorbar] in (:none, :off, :hide, false))
        elseif RecipesPipeline.is3d(sp)
            azim, elev = sp[:camera]
            kw[:view] = "{$(azim)}{$(elev)}"
        end

        axisf = PGFPlots.Axis
        if sp[:projection] === :polar
            axisf = PGFPlots.PolarAxis
            #make radial axis vertical
            kw[:xmin] = 90
            kw[:xmax] = 450
        end

        # Search series for any gradient. In case one series uses a gradient set
        # the colorbar and colomap.
        # The reasoning behind doing this on the axis level is that pgfplots
        # colorbar seems to only works on axis level and needs the proper colormap for
        # correctly displaying it.
        # It's also possible to assign the colormap to the series itself but
        # then the colormap needs to be added twice, once for the axis and once for the
        # series.
        # As it is likely that all series within the same axis use the same
        # colormap this should not cause any problem.
        for series in series_list(sp)
            for col in (:markercolor, :fillcolor, :linecolor)
                if typeof(series.plotattributes[col]) == ColorGradient
                    push!(
                        style,
                        "colormap={plots}{$(pgf_colormap(series.plotattributes[col]))}",
                    )

                    if sp[:colorbar] === :none
                        kw[:colorbar] = "false"
                    else
                        kw[:colorbar] = "true"
                    end
                    # goto is needed to break out of col and series for
                    @goto colorbar_end
                end
            end
        end
        @label colorbar_end

        push!(style, "colorbar style={title=$(sp[:colorbar_title])}")
        o = axisf(; style = join(style, ","), kw...)

        # add the series object to the PGFPlots.Axis
        for series in series_list(sp)
            push!.(Ref(o), pgf_series(sp, series))

            # add series annotations
            anns = series[:series_annotations]
            for (xi, yi, str, fnt) in EachAnn(anns, series[:x], series[:y])
                pgf_add_annotation!(
                    o,
                    xi,
                    yi,
                    PlotText(str, fnt),
                    pgf_thickness_scaling(series),
                )
            end
        end

        # add the annotations
        for ann in sp[:annotations]
            pgf_add_annotation!(
                o,
                locate_annotation(sp, ann...)...,
                pgf_thickness_scaling(sp),
            )
        end

        # add the PGFPlots.Axis to the list
        push!(plt.o, o)
    end
    return
end

_show(io::IO, mime::MIME"image/svg+xml", plt::Plot{PGFPlotsBackend}) = show(io, mime, plt.o)

function _show(io::IO, mime::MIME"application/pdf", plt::Plot{PGFPlotsBackend})
    # prepare the object
    pgfplt = PGFPlots.plot(plt.o)

    # save a pdf
    fn = tempname() * ".pdf"
    PGFPlots.save(PGFPlots.PDF(fn), pgfplt)

    # read it into io
    write(io, read(open(fn), String))

    # cleanup
    return PGFPlots.cleanup(plt.o)
end

function _show(io::IO, mime::MIME"application/x-tex", plt::Plot{PGFPlotsBackend})
    fn = tempname() * ".tex"
    PGFPlots.save(
        fn,
        backend_object(plt),
        include_preamble = plt.attr[:tex_output_standalone],
    )
    return write(io, read(open(fn), String))
end

function _display(plt::Plot{PGFPlotsBackend})
    # prepare the object
    pgfplt = PGFPlots.plot(plt.o)

    # save an svg
    fn = string(tempname(), ".svg")
    PGFPlots.save(PGFPlots.SVG(fn), pgfplt)

    # show it
    open_browser_window(fn)

    # cleanup
    return PGFPlots.cleanup(plt.o)
end

# COV_EXCL_STOP
