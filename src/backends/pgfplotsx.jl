PGFPlotsX.print_tex(io::IO, data::Symbol) = PGFPlotsX.print_tex(io, string(data))

const _pgfplotsx_linestyles = KW(
    :solid => "solid",
    :dash => "dashed",
    :dot => "dotted",
    :dashdot => "dashdotted",
    :dashdotdot => "dashdotdotted",
)

const _pgfplotsx_markers = KW(
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
    :vline => "|"
)

const _pgfplotsx_legend_pos = KW(
    :bottomleft => "south west",
    :bottomright => "south east",
    :topright => "north east",
    :topleft => "north west",
    :outertopright => "outer north east",
)

const _pgfx_series_extrastyle = KW(
    :steppre => "const plot mark right",
    :stepmid => "const plot mark mid",
    :steppost => "const plot",
    :sticks => "ycomb",
    :ysticks => "ycomb",
    :xsticks => "xcomb",
)

const _pgfx_framestyles = [:box, :axes, :origin, :zerolines, :grid, :none]
const _pgfx_framestyle_defaults = Dict(:semi => :box)

# we use the anchors to define orientations for example to align left
# one needs to use the right edge as anchor
const _pgfx_annotation_halign = KW(
    :center => "",
    :left => "right",
    :right => "left"
)
## --------------------------------------------------------------------------------------
# Generates a colormap for pgfplots based on a ColorGradient
# TODO: maybe obsolete
function pgfx_colormap(grad::ColorGradient)
    join(map(grad.colors) do c
        @sprintf("rgb=(%.8f,%.8f,%.8f)", red(c), green(c), blue(c))
    end,"\n")
end

function pgfx_framestyle(style::Symbol)
    if style in _pgfx_framestyles
        return style
    else
        default_style = get(_pgfx_framestyle_defaults, style, :axes)
        @warn("Framestyle :$style is not (yet) supported by the PGFPlots backend. :$default_style was cosen instead.")
        default_style
    end
end

pgfx_thickness_scaling(plt::Plot) = plt[:thickness_scaling]
pgfx_thickness_scaling(sp::Subplot) = pgfx_thickness_scaling(sp.plt)
pgfx_thickness_scaling(series) = pgfx_thickness_scaling(series[:subplot])

function pgfx_fillstyle(plotattributes, i = 1)
    cstr = get_fillcolor(plotattributes, i)
    a = alpha(cstr)
    fa = get_fillalpha(plotattributes, i)
    if fa !== nothing
        a = fa
    end
    PGFPlotsX.Options("fill" => cstr, "fill opacity" => a)
end

function pgfx_linestyle(linewidth::Real, color, α = 1, linestyle = "solid")
    cstr = plot_color(color, α)
    a = alpha(cstr)
    return PGFPlotsX.Options(
        "color" => cstr,
        "draw opacity" => a,
        "line width" => linewidth,
        get(_pgfplotsx_linestyles, linestyle, "solid") => nothing
    )
end

function pgfx_linestyle(plotattributes, i = 1)
    lw = pgfx_thickness_scaling(plotattributes) * get_linewidth(plotattributes, i)
    lc = get_linecolor(plotattributes, i)
    la = get_linealpha(plotattributes, i)
    ls = get_linestyle(plotattributes, i)
    return pgfx_linestyle(lw, lc, la, ls)
end

function pgfx_font(fontsize, thickness_scaling = 1, font = "\\selectfont")
    fs = fontsize * thickness_scaling
    return string("{\\fontsize{", fs, " pt}{", 1.3fs, " pt}", font, "}")
end

function pgfx_marker(plotattributes, i = 1)
    shape = _cycle(plotattributes[:markershape], i)
    cstr = plot_color(get_markercolor(plotattributes, i), get_markeralpha(plotattributes, i))
    a = alpha(cstr)
    cstr_stroke = plot_color(get_markerstrokecolor(plotattributes, i), get_markerstrokealpha(plotattributes, i))
    a_stroke = alpha(cstr_stroke)
    return PGFPlotsX.Options(
        "mark" => get(_pgfplotsx_markers, shape, "*"),
        "mark size" => pgfx_thickness_scaling(plotattributes) * 0.5 * _cycle(plotattributes[:markersize], i),
        "mark options" => PGFPlotsX.Options(
            "color" => cstr_stroke,
            "draw opacity" => a_stroke,
            "fill" => cstr,
            "fill opacity" => a,
            "line width" => pgfx_thickness_scaling(plotattributes) * _cycle(plotattributes[:markerstrokewidth], i),
            "rotate" => (shape == :dtriangle ? 180 : 0),
            get(_pgfplotsx_linestyles, _cycle(plotattributes[:markerstrokestyle], i), "solid") => nothing
            )
    )
end

function pgfx_add_annotation!(o, x, y, val, thickness_scaling = 1)
    # Construct the style string.
    # Currently supports color and orientation
    cstr = val.font.color
    a = alpha(cstr)
    push!(o, ["\\node",
        PGFPlotsX.Options(
            get(_pgfx_annotation_halign,val.font.halign,"") => nothing,
            "color" => cstr,
            "draw opacity" => convert(Float16, a),
            "rotate" => val.font.rotation,
            "font" => pgfx_font(val.font.pointsize, thickness_scaling)
        ),
        " at ",
        PGFPlotsX.Coordinate(x, y),
        "{$(val.str).};"
    ])
end
## --------------------------------------------------------------------------------------
# TODO: translate these if needed
function pgf_series(sp::Subplot, series::Series)
    plotattributes = series.plotattributes
    st = plotattributes[:seriestype]
    series_collection = PGFPlotsX.Plot[]

    # function args
    args = if st == :contour
        plotattributes[:z].surf, plotattributes[:x], plotattributes[:y]
    elseif is3d(st)
        plotattributes[:x], plotattributes[:y], plotattributes[:z]
    elseif st == :straightline
        straightline_data(series)
    elseif st == :shape
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
        func = if st == :histogram2d
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

            if st == :shape
                push!(style, pgf_fillstyle(plotattributes, i))
            end

            # add to legend?
            if i == 1 && sp[:legend] != :none && should_add_to_legend(series)
                if plotattributes[:fillrange] !== nothing
                    push!(style, "forget plot")
                    push!(series_collection, pgf_fill_legend_hack(plotattributes, args))
                else
                    kw[:legendentry] = plotattributes[:label]
                    if st == :shape # || plotattributes[:fillrange] !== nothing
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
            if series[:fillrange] !== nothing && st != :shape
                push!(series_collection, pgf_fillrange_series(series, i, _cycle(series[:fillrange], rng), seg_args...))
            end

            # build/return the series object
            func = if st == :path3d
                PGFPlots.Linear3
            elseif st == :scatter
                PGFPlots.Scatter
            else
                PGFPlots.Linear
            end
            push!(series_collection, func(seg_args...; kw...))
        end
    end
    series_collection
end

function pgfx_fillrange_series(series, i, fillrange, args...)
    st = series[:seriestype]
    opt = PGFPlotsX.Options()
    push!(opt, "line width" => 0)
    push!(opt, "draw opacity" => 0)
    opt = merge(opt, pgfx_fillstyle(series, i))
    opt = merge(opt, pgfx_marker(series, i))
    push!(opt, "forget plot" => nothing)
    if haskey(_pgfx_series_extrastyle, st)
        push!(opt, _pgfx_series_extrastyle[st] => nothing)
    end
    func = is3d(series) ? PGFPlotsX.Plot3 : PGFPlotsX.Plot
    return func(opt, PGFPlotsX.Coordinates(pgfx_fillrange_args(fillrange, args...)...))
end

function pgfx_fillrange_args(fillrange, x, y)
    n = length(x)
    x_fill = [x; x[n:-1:1]; x[1]]
    y_fill = [y; _cycle(fillrange, n:-1:1); y[1]]
    return x_fill, y_fill
end

function pgfx_fillrange_args(fillrange, x, y, z)
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
    func = if st == :path3d
        PGFPlots.Linear3
    elseif st == :scatter
        PGFPlots.Scatter
    else
        PGFPlots.Linear
    end
    return func(([arg[1]] for arg in args)...; kw...)
end

# --------------------------------------------------------------------------------------
function pgfx_axis!(opt::PGFPlotsX.Options, sp::Subplot, letter)
    axis = sp[Symbol(letter,:axis)]

    # turn off scaled ticks
    push!(opt, "scaled $(letter) ticks" => "false",
        string(letter,:label) => axis[:guide],
    )

    # set to supported framestyle
    framestyle = pgfx_framestyle(sp[:framestyle])

    # axis label position
    labelpos = ""
    if letter == :x && axis[:guide_position] == :top
        labelpos = "at={(0.5,1)},above,"
    elseif letter == :y && axis[:guide_position] == :right
        labelpos = "at={(1,0.5)},below,"
    end

    # Add label font
    cstr = plot_color(axis[:guidefontcolor])
    α = alpha(cstr)
    push!(opt, string(letter, "label style") => PGFPlotsX.Options(
        labelpos => nothing,
        "font" => pgfx_font(axis[:guidefontsize], pgfx_thickness_scaling(sp)),
        "color" => cstr,
        "draw opacity" => α,
        "rotate" => axis[:guidefontrotation],
        )
    )

    # flip/reverse?
    axis[:flip] && push!(opt, "$letter dir" => "reverse")

    # scale
    scale = axis[:scale]
    if scale in (:log2, :ln, :log10)
        push!(opt, string(letter,:mode) => "log")
        scale == :ln || push!(opt, "log basis $letter" => "$(scale == :log2 ? 2 : 10)")
    end

    # ticks on or off
    if axis[:ticks] in (nothing, false, :none) || framestyle == :none
        push!(opt, "$(letter)majorticks" => "false")
    end

    # grid on or off
    if axis[:grid] && framestyle != :none
        push!(opt, "$(letter)majorgrids" => "true")
    else
        push!(opt, "$(letter)majorgrids" => "false")
    end

    # limits
    # TODO: support zlims
    if letter != :z
        lims = ispolar(sp) && letter == :x ? rad2deg.(axis_limits(sp, :x)) : axis_limits(sp, letter)
        push!( opt,
            string(letter,:min) => lims[1],
            string(letter,:max) => lims[2]
        )
    end

    if !(axis[:ticks] in (nothing, false, :none, :native)) && framestyle != :none
        ticks = get_ticks(sp, axis)
        #pgf plot ignores ticks with angle below 90 when xmin = 90 so shift values
        tick_values = ispolar(sp) && letter == :x ? [rad2deg.(ticks[1])[3:end]..., 360, 405] : ticks[1]
        push!(opt, string(letter, "tick") => string("{", join(tick_values,","), "}"))
        if axis[:showaxis] && axis[:scale] in (:ln, :log2, :log10) && axis[:ticks] == :auto
            # wrap the power part of label with }
            tick_labels = Vector{String}(undef, length(ticks[2]))
            for (i, label) in enumerate(ticks[2])
                base, power = split(label, "^")
                power = string("{", power, "}")
                tick_labels[i] = string(base, "^", power)
            end
            push!(opt, string(letter, "ticklabels") => string("{\$", join(tick_labels,"\$,\$"), "\$}"))
        elseif axis[:showaxis]
            tick_labels = ispolar(sp) && letter == :x ? [ticks[2][3:end]..., "0", "45"] : ticks[2]
            if axis[:formatter] in (:scientific, :auto)
                tick_labels = string.("\$", convert_sci_unicode.(tick_labels), "\$")
                tick_labels = replace.(tick_labels, Ref("×" => "\\times"))
            end
            push!(opt, string(letter, "ticklabels") => string("{", join(tick_labels,","), "}"))
        else
            push!(opt, string(letter, "ticklabels") => "{}")
        end
        push!(opt, string(letter, "tick align") => (axis[:tick_direction] == :out ? "outside" : "inside"))
        cstr = plot_color(axis[:tickfontcolor])
        α = alpha(cstr)
        push!(opt, string(letter, "ticklabel style") => PGFPlotsX.Options(
                "font" => pgfx_font(axis[:tickfontsize], pgfx_thickness_scaling(sp)),
                "color" => cstr,
                "draw opacity" => α,
                "rotate" => axis[:tickfontrotation]
            )
        )
        push!(opt, string(letter, " grid style") => pgfx_linestyle(pgfx_thickness_scaling(sp) * axis[:gridlinewidth], axis[:foreground_color_grid], axis[:gridalpha], axis[:gridstyle])
        )
    end

    # framestyle
    if framestyle in (:axes, :origin)
        axispos = framestyle == :axes ? "left" : "middle"
        if axis[:draw_arrow]
            push!(opt, string("axis ", letter, " line") => axispos)
        else
            # the * after line disables the arrow at the axis
            push!(opt, string("axis ", letter, " line*") => axispos)
        end
    end

    if framestyle == :zerolines
        push!(opt, string("extra ", letter, " ticks") => "0")
        push!(opt, string("extra ", letter, " tick labels") => "")
        push!(opt, string("extra ", letter, " tick style") => PGFPlotsX.Options(
                "grid" => "major",
                "major grid style" => pgfx_linestyle(pgfx_thickness_scaling(sp), axis[:foreground_color_border], 1.0)
            )
        )
    end

    if !axis[:showaxis]
        push!(opt, "separate axis lines")
    end
    if !axis[:showaxis] || framestyle in (:zerolines, :grid, :none)
        push!(opt, string(letter, " axis line style") => "{draw opacity = 0}")
    else
        push!(opt, string(letter, " axis line style") => pgfx_linestyle(pgfx_thickness_scaling(sp), axis[:foreground_color_border], 1.0)
        )
    end
end
# --------------------------------------------------------------------------------------
# display calls this and then _display, its called 3 times for plot(1:5)
function _create_backend_figure(plt::Plot{PGFPlotsXBackend})

end

function _series_updated(plt::Plot{PGFPlotsXBackend}, series::Series)
end

# TODO: don't rebuild plots so often
# IDEA: use functor to only build plot once
function _update_plot_object(plt::Plot{PGFPlotsXBackend})
    plt.o = PGFPlotsX.TikzDocument()
    cols, rows = size(plt.layout.grid)
    push!(plt.o, PGFPlotsX.TikzPicture(PGFPlotsX.GroupPlot(
        PGFPlotsX.Options(
            "group style" => PGFPlotsX.Options(
                "group size" => string(cols)*" by "*string(rows)
            )
        )
    )))

    pushed_colormap = false
    for sp in plt.subplots
        bb = bbox(sp)
        cstr = plot_color(sp[:background_color_legend])
        a = alpha(cstr)
        title_cstr = plot_color(sp[:titlefontcolor])
        title_a = alpha(cstr)
        # TODO: aspect ratio
        axis_opt = PGFPlotsX.Options(
            "height" => string(height(bb)),
            "width" => string(width(bb)),
            "title" => sp[:title],
            "title style" => PGFPlotsX.Options(
                "font" => pgfx_font(sp[:titlefontsize], pgfx_thickness_scaling(sp)),
                "color" => title_cstr,
                "draw opacity" => title_a,
                "rotate" => sp[:titlefontrotation]
            ),
            "legend pos" => get(_pgfplotsx_legend_pos, sp[:legend], "outer north east"),
            "legend style" => PGFPlotsX.Options(
                pgfx_linestyle(pgfx_thickness_scaling(sp), sp[:foreground_color_legend], 1.0, "solid") => nothing,
                "fill" => cstr,
                "font" => pgfx_font(sp[:legendfontsize], pgfx_thickness_scaling(sp))
            ),
            "axis background/.style" => PGFPlotsX.Options(
                "fill" => sp[:background_color_inside]
            )
        )
        for letter in (:x, :y, :z)
            if letter != :z || is3d(sp)
                pgfx_axis!(axis_opt, sp, letter)
            end
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
                    if !pushed_colormap
                        PGFPlotsX.push_preamble!(plt.o, """\\pgfplotsset{
                            colormap={plots}{$(pgfx_colormap(series.plotattributes[col]))},
                        }""")
                        pushed_colormap = true
                        push!(axis_opt,
                            "colorbar" => nothing,
                            "colormap name" => "plots",
                        )
                    end

                    # goto is needed to break out of col and series for
                    @goto colorbar_end
                end
            end
        end
        @label colorbar_end

        push!(axis_opt, "colorbar style" => PGFPlotsX.Options(
            "title" => sp[:colorbar_title]
            )
        )
        axis = PGFPlotsX.Axis(
            axis_opt
        )
        for series in series_list(sp)
            opt = series.plotattributes
            st = series[:seriestype]
            # function args
            args = if st == :contour
                opt[:z].surf, opt[:x], opt[:y]
            elseif is3d(st)
                opt[:x], opt[:y], opt[:z]
            elseif st == :straightline
                straightline_data(series)
            elseif st == :shape
                shape_data(series)
            elseif ispolar(sp)
                theta, r = opt[:x], opt[:y]
                rad2deg.(theta), r
            else
                opt[:x], opt[:y]
            end
            series_opt = PGFPlotsX.Options(
                            "color" => opt[:linecolor],
                        )
            if st == :shape
                push!(series_opt, "area legend" => nothing)
            end
            if opt[:marker_z] !== nothing
                push!(series_opt, "point meta" => "explicit")
                push!(series_opt, "scatter" => nothing)
            end
            segments = iter_segments(series)
            segment_opt = PGFPlotsX.Options()
            for (i, rng) in enumerate(segments)
                segment_opt = merge( segment_opt, pgfx_linestyle(opt, i) )
                segment_opt = merge( segment_opt, pgfx_marker(opt, i) )
                if st == :shape
                    segment_opt = merge( segment_opt, pgfx_fillstyle(opt, i) )
                end
                seg_args = (arg[rng] for arg in args)
                # add fillrange
                if series[:fillrange] !== nothing && st != :shape
                    push!(axis, pgfx_fillrange_series(series, i, _cycle(series[:fillrange], rng), seg_args...))
                end
            end
            #include additional style
            if haskey(_pgfx_series_extrastyle, st)
                push!(series_opt, _pgfx_series_extrastyle[st] => nothing)
            end
            # TODO: different seriestypes, histogramms, contours, etc.
            # TODO: colorbars
            # TODO: gradients
            if is3d(series)
                series_func = PGFPlotsX.Plot3
            else
                series_func = PGFPlotsX.Plot
            end
            if st == :scatter
                push!(series_opt, "only marks" => nothing)
            end
            series_plot = series_func(
                merge(series_opt, segment_opt),
                PGFPlotsX.Coordinates(args..., meta = opt[:marker_z])
            )
            # add series annotations
            anns = series[:series_annotations]
            for (xi,yi,str,fnt) in EachAnn(anns, series[:x], series[:y])
                pgfx_add_annotation!(series_plot, xi, yi, PlotText(str, fnt), pgfx_thickness_scaling(series))
            end
            push!( axis, series_plot )
            if opt[:label] != "" && sp[:legend] != :none && should_add_to_legend(series)
                push!( axis, PGFPlotsX.LegendEntry( opt[:label] )
                )
            end
        end
        push!( plt.o.elements[1].elements[1], axis )
    end
end

function _show(io::IO, mime::MIME"image/svg+xml", plt::Plot{PGFPlotsXBackend})
    _update_plot_object(plt)
    show(io, mime, plt.o)
end

function _show(io::IO, mime::MIME"application/pdf", plt::Plot{PGFPlotsXBackend})
    _update_plot_object(plt)
    show(io, mime, plt.o)
end

function _show(io::IO, mime::MIME"image/png", plt::Plot{PGFPlotsXBackend})
    _update_plot_object(plt)
    show(io, mime, plt.o)
end

function _show(io::IO, mime::MIME"application/x-tex", plt::Plot{PGFPlotsXBackend})
    _update_plot_object(plt)
    PGFPlotsX.print_tex(plt.o)
end

function _display(plt::Plot{PGFPlotsXBackend})
    # fn = string(tempname(),".svg")
    # PGFPlotsX.pgfsave(fn, plt.o)
    # open_browser_window(fn)
    plt.o
end
