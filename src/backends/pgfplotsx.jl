const Options = PGFPlotsX.Options
const Table = PGFPlotsX.Table

Base.@kwdef mutable struct PGFPlotsXPlot
    is_created::Bool = false
    was_shown::Bool = false
    the_plot::PGFPlotsX.TikzDocument = PGFPlotsX.TikzDocument()
    function PGFPlotsXPlot(is_created, was_shown, the_plot)
        pgfx_plot = new(is_created, was_shown, the_plot)
        # tikz libraries
        PGFPlotsX.push_preamble!(pgfx_plot.the_plot, "\\usetikzlibrary{arrows.meta}")
        PGFPlotsX.push_preamble!(pgfx_plot.the_plot, "\\usetikzlibrary{backgrounds}")
        # pgfplots libraries
        PGFPlotsX.push_preamble!(pgfx_plot.the_plot, "\\usepgfplotslibrary{patchplots}")
        PGFPlotsX.push_preamble!(pgfx_plot.the_plot, "\\usepgfplotslibrary{fillbetween}")
        # compatibility fixes
        # add background layer to standard layers
        PGFPlotsX.push_preamble!(
            pgfx_plot.the_plot,
            raw"""\pgfplotsset{%
                layers/standard/.define layer set={%
                    background,axis background,axis grid,axis ticks,axis lines,axis tick labels,pre main,main,axis descriptions,axis foreground%
                }{
                    grid style={/pgfplots/on layer=axis grid},%
                    tick style={/pgfplots/on layer=axis ticks},%
                    axis line style={/pgfplots/on layer=axis lines},%
                    label style={/pgfplots/on layer=axis descriptions},%
                    legend style={/pgfplots/on layer=axis descriptions},%
                    title style={/pgfplots/on layer=axis descriptions},%
                    colorbar style={/pgfplots/on layer=axis descriptions},%
                    ticklabel style={/pgfplots/on layer=axis tick labels},%
                    axis background@ style={/pgfplots/on layer=axis background},%
                    3d box foreground style={/pgfplots/on layer=axis foreground},%
                },
            }
            """,
        )
        pgfx_plot
    end
end

## end user utility functions

pgfx_axes(pgfx_plot::PGFPlotsXPlot) = pgfx_plot.the_plot.elements[1].elements

pgfx_preamble() = pgfx_preamble(current())
function pgfx_preamble(pgfx_plot::Plot{PGFPlotsXBackend})
    old_flag = pgfx_plot.attr[:tex_output_standalone]
    pgfx_plot.attr[:tex_output_standalone] = true
    fulltext = String(repr("application/x-tex", pgfx_plot))
    preamble = fulltext[1:(first(findfirst("\\begin{document}", fulltext)) - 1)]
    pgfx_plot.attr[:tex_output_standalone] = old_flag
    return preamble
end

function surface_to_vecs(x::AVec, y::AVec, s::Union{AMat, Surface})
    a = Array(s)
    xn = Vector{eltype(x)}(undef, length(a))
    yn = Vector{eltype(y)}(undef, length(a))
    zn = Vector{eltype(s)}(undef, length(a))
    for (n, (i, j)) in enumerate(Tuple.(CartesianIndices(a)))
        if length(x) == size(s, 1)
            i, j = j, i
        end
        xn[n] = x[j]
        yn[n] = y[i]
        zn[n] = a[i, j]
    end
    return xn, yn, zn
end
surface_to_vecs(x::AVec, y::AVec, z::AVec) = x, y, z

Base.push!(pgfx_plot::PGFPlotsXPlot, item) = push!(pgfx_plot.the_plot, item)

pgfx_split_extra_kw(extra) =
    (get(extra, :add, nothing), filter(x -> first(x) !== :add, extra))

curly(obj) = "{$(string(obj))}"

# anything other than `Function`, `:plain` or `:latex` should map to `:latex` formatter instead
latex_formatter(formatter::Symbol) = formatter in (:plain, :latex) ? formatter : :latex
latex_formatter(formatter::Function) = formatter

labelfunc(scale::Symbol, backend::PGFPlotsXBackend) = labelfunc_tex(scale)

pgfx_halign(k) = (left = "left", hcenter = "center", center = "center", right = "right")[k]

function (pgfx_plot::PGFPlotsXPlot)(plt::Plot{PGFPlotsXBackend})
    if !pgfx_plot.is_created || pgfx_plot.was_shown
        pgfx_sanitize_plot!(plt)
        # extract extra kwargs
        extra_plot, extra_plot_opt = pgfx_split_extra_kw(plt[:extra_plot_kwargs])
        the_plot = PGFPlotsX.TikzPicture(Options(extra_plot_opt...))
        extra_plot !== nothing && push!(the_plot, wraptuple(extra_plot)...)
        bgc = plt.attr[
            if plt.attr[:background_color_outside] === :match
                :background_color
            else
                :background_color_outside
            end,
        ]
        if bgc isa Colors.Colorant
            cstr = plot_color(bgc)
            push!(
                the_plot.options,
                "/tikz/background rectangle/.style" => Options(
                    # "draw" => "black",
                    "fill" => cstr,
                    "fill opacity" => alpha(cstr),
                    "draw opacity" => alpha(cstr),
                ),
                "show background rectangle" => nothing,
            )
        end

        for sp in plt.subplots
            bb2 = bbox(sp)
            dx, dy = bb2.x0
            sp_w, sp_h = width(bb2), height(bb2)
            if sp[:subplot_index] == plt[:plot_titleindex]
                x = dx + sp_w / 2 - 10mm  # FIXME: get rid of magic constant
                y = dy + sp_h / 2
                pgfx_add_annotation!(
                    the_plot,
                    (x, y),
                    PlotText(plt[:plot_title], plottitlefont(plt)),
                    pgfx_thickness_scaling(plt);
                    options = Options("anchor" => "center"),
                    cs = "",
                )
                continue
            end

            lpad = leftpad(sp) + sp[:left_margin]
            rpad = rightpad(sp) + sp[:right_margin]
            tpad = toppad(sp) + sp[:top_margin]
            bpad = bottompad(sp) + sp[:bottom_margin]
            dx += lpad
            dy += tpad
            title_cstr = plot_color(sp[:titlefontcolor])
            bgc_inside = plot_color(sp[:background_color_inside])
            update_clims(sp)
            axis_opt = Options(
                "point meta max" => get_clims(sp)[2],
                "point meta min" => get_clims(sp)[1],
                "legend cell align" => "left",
                "legend columns" => pgfx_legend_col(sp[:legend_column]),
                "title" => sp[:title],
                "title style" => Options(
                    pgfx_get_title_pos(sp[:titlelocation])...,
                    "font" => pgfx_font(sp[:titlefontsize], pgfx_thickness_scaling(sp)),
                    "color" => title_cstr,
                    "draw opacity" => alpha(title_cstr),
                    "rotate" => sp[:titlefontrotation],
                    "align" => pgfx_halign(sp[:titlefonthalign]),
                ),
                "legend style" => pgfx_get_legend_style(sp),
                "axis background/.style" =>
                    Options("fill" => bgc_inside, "opacity" => alpha(bgc_inside)),
                # these are for layouting
                "anchor" => "north west",
                "xshift" => string(dx),
                "yshift" => string(-dy),
            )
            sp_w > 0mm && push!(axis_opt, "width" => string(sp_w - (rpad + lpad)))
            sp_h > 0mm && push!(axis_opt, "height" => string(sp_h - (tpad + bpad)))
            for letter in (:x, :y, :z)
                if letter !== :z || RecipesPipeline.is3d(sp)
                    pgfx_axis!(axis_opt, sp, letter)
                end
            end
            # Search series for any gradient. In case one series uses a gradient set the colorbar and colomap.
            # The reasoning behind doing this on the axis level is that
            # pgfplots colorbar seems to only work on axis level and needs the proper colormap for correctly displaying it.
            # It's also possible to assign the colormap to the series itself but
            # then the colormap needs to be added twice, once for the axis and once for the series.
            # As it is likely that all series within the same axis use the same colormap this should not cause any problem.
            for series in series_list(sp)
                if hascolorbar(series)
                    cg = get_colorgradient(series)
                    cm = pgfx_colormap(cg)
                    PGFPlotsX.push_preamble!(
                        pgfx_plot.the_plot,
                        "\\pgfplotsset{\ncolormap={plots$(sp.attr[:subplot_index])}{$cm},\n}",
                    )
                    push!(axis_opt, "colormap name" => "plots$(sp.attr[:subplot_index])")
                    if cg isa PlotUtils.CategoricalColorGradient
                        push!(
                            axis_opt,
                            "colormap access" => "piecewise const",
                            "colorbar sampled" => nothing,
                        )
                    end
                    break
                end
            end

            if hascolorbar(sp)
                formatter = latex_formatter(sp[:colorbar_formatter])
                cticks = curly(join(get_colorbar_ticks(sp; formatter = formatter)[1], ','))
                letter = sp[:colorbar] === :top ? :x : :y

                colorbar_style = push!(
                    Options("$(letter)label" => sp[:colorbar_title]),
                    "$(letter)label style" => pgfx_get_colorbar_title_style(sp),
                    "$(letter)tick" => cticks,
                    "$(letter)ticklabel style" => pgfx_get_colorbar_ticklabel_style(sp),
                )

                if sp[:colorbar] === :top
                    push!(
                        colorbar_style,
                        "at" => "(0.5, 1.05)",
                        "anchor" => "south",
                        "xticklabel pos" => "upper",
                    )
                end

                if !_has_ticks(sp[:colorbar_ticks])
                    push!(
                        colorbar_style,
                        "$(letter)tick style" => "{draw=none}",
                        "$(letter)ticklabels" => "{,,}",
                    )
                end

                push!(
                    axis_opt,
                    "colorbar $(pgfx_get_colorbar_pos(sp[:colorbar]))" => nothing,
                    "colorbar style" => colorbar_style,
                )
            else
                push!(axis_opt, "colorbar" => "false")
            end
            if RecipesPipeline.is3d(sp)
                if (ar = sp[:aspect_ratio]) !== :auto
                    push!(
                        axis_opt,
                        "unit vector ratio" => ar === :equal ? 1 : join(ar, ' '),
                    )
                end
                push!(axis_opt, "view" => tuple(sp[:camera]))
            end
            axisf = if sp[:projection] === :polar
                # push!(axis_opt, "xmin" => 90)
                # push!(axis_opt, "xmax" => 450)
                PGFPlotsX.PolarAxis
            else
                PGFPlotsX.Axis
            end
            extra_sp, extra_sp_opt = pgfx_split_extra_kw(sp[:extra_kwargs])
            axis = axisf(merge(axis_opt, Options(extra_sp_opt...)))
            extra_sp !== nothing && push!(axis, wraptuple(extra_sp)...)
            if sp[:legend_title] !== nothing
                legtfont = legendtitlefont(sp)
                leg_opt = Options(
                    "font" => pgfx_font(legtfont.pointsize, pgfx_thickness_scaling(sp)),
                    "text" => legtfont.color,
                )
                push!(
                    axis,
                    Options("\\addlegendimage{empty legend}" => nothing),
                    PGFPlotsX.LegendEntry(
                        leg_opt,
                        "\\hspace{-.6cm}{\\textbf{$(sp[:legend_title])}}",
                        false,
                    ),
                )
            end
            for (series_index, series) in enumerate(series_list(sp))
                # give each series an id for fillbetween
                series_id = maximum(values(_pgfplotsx_series_ids), init = 0) + 1
                _pgfplotsx_series_ids[Symbol("$series_index")] = series_id
                opt = series.plotattributes
                st = series[:seriestype]
                extra_series, extra_series_opt = pgfx_split_extra_kw(series[:extra_kwargs])
                series_opt = Options(
                    "color" => single_color(opt[:linecolor]),
                    "name path" => string(series_id),
                )
                series_func =
                if (
                        RecipesPipeline.is3d(series) ||
                            st in (:heatmap, :contour) ||
                            (st === :quiver && opt[:z] !== nothing)
                    )
                    PGFPlotsX.Plot3
                else
                    PGFPlotsX.Plot
                end
                if (
                        series[:fillrange] !== nothing &&
                            series[:ribbon] === nothing &&
                            !isfilledcontour(series)
                    )
                    push!(series_opt, "area legend" => nothing)
                end
                pgfx_add_series!(Val(st), axis, series_opt, series, series_func, opt)
                last_plot =
                    axis.contents[end] isa PGFPlotsX.LegendEntry ? axis.contents[end - 1] :
                    axis.contents[end]
                merge!(last_plot.options, Options(extra_series_opt...))
                if extra_series !== nothing
                    push!(axis.contents[end], wraptuple(extra_series)...)
                end
                # add series annotations
                anns = series[:series_annotations]
                for (xi, yi, str, fnt) in EachAnn(anns, series[:x], series[:y])
                    pgfx_add_annotation!(
                        axis,
                        (xi, yi),
                        PlotText(str, fnt),
                        pgfx_thickness_scaling(series),
                    )
                end
            end  # for series
            # add subplot annotations
            for ann in sp[:annotations]
                # [1:end-1] -> coordinates, [end] is string
                loc_val = locate_annotation(sp, ann...)
                pgfx_add_annotation!(
                    axis,
                    loc_val[1:(end - 1)],
                    loc_val[end],
                    pgfx_thickness_scaling(sp),
                )
            end
            push!(the_plot, axis)
            if length(plt.o.the_plot.elements) > 0
                plt.o.the_plot.elements[1] = the_plot
            else
                push!(plt.o, the_plot)
            end
        end  # for subplots
        pgfx_plot.is_created = true
        pgfx_plot.was_shown = false
    end
    return pgfx_plot
end

## seriestype specifics
function pgfx_add_series!(axis, series_opt, series, series_func, opt)
    series_opt = series_func(series_opt, Table(pgfx_series_arguments(series, opt)...))
    return pgfx_add_legend!(push!(axis, series_opt), series, opt)
end

function pgfx_add_series!(::Val{:path}, axis, series_opt, series, series_func, opt)
    # treat segments
    segments = collect(series_segments(series, series[:seriestype]; check = true))
    for (k, segment) in enumerate(segments)
        i, rng = segment.attr_index, segment.range
        segment_opt = pgfx_linestyle(opt, i)
        if opt[:markershape] !== :none
            if (marker = _cycle(opt[:markershape], i)) isa Shape
                scale_factor = 0.00125
                msize = opt[:markersize] * scale_factor
                path = join(
                    map((x, y) -> "($(x * msize), $(y * msize))", marker.x, marker.y),
                    " -- ",
                )
                PGFPlotsX.push_preamble!(
                    series[:plot_object].o.the_plot,
                    """
                    \\pgfdeclareplotmark{PlotsShape$(series[:series_plotindex])}{
                    \\filldraw
                    $path;
                    }
                    """,
                )
            end
            segment_opt = merge(segment_opt, pgfx_marker(opt, i))
        end
        # add fillrange
        if (sf = opt[:fillrange]) !== nothing && !isfilledcontour(series)
            if sf isa Number || sf isa AVec
                pgfx_fillrange_series!(axis, series, series_func, i, _cycle(sf, rng), rng)
            elseif sf isa Tuple && series[:ribbon] !== nothing
                for sfi in sf
                    pgfx_fillrange_series!(
                        axis,
                        series,
                        series_func,
                        i,
                        _cycle(sfi, rng),
                        rng,
                    )
                end
            end
            if (
                    i == 1 &&
                        series[:subplot][:legend_position] !== :none &&
                        pgfx_should_add_to_legend(series)
                )
                pgfx_filllegend!(series_opt, opt)
            end
        end
        # handle arrows
        coordinates = if (arrow = opt[:arrow]) isa Arrow
            arrow_opt = merge(
                segment_opt,
                Options(
                    "quiver" => Options(
                        "u" => "\\thisrow{u}",
                        "v" => "\\thisrow{v}",
                        pgfx_arrow(arrow, :head) => nothing,
                    ),
                ),
            )
            isempty(opt[:label]) && push!(arrow_opt, "forget plot" => nothing)
            rx, ry = opt[:x][rng], opt[:y][rng]
            nx, ny = length(rx), length(ry)
            x_arrow, y_arrow, x_path, y_path = if arrow.side === :head
                rx[(nx - 1):nx], ry[(ny - 1):ny], rx[1:(nx - 1)], ry[1:(ny - 1)]
            elseif arrow.side === :tail
                rx[2:-1:1], ry[2:-1:1], rx[2:nx], ry[2:ny]
            elseif arrow.side === :both
                rx[[2, 1, nx - 1, nx]], ry[[2, 1, ny - 1, ny]], rx[2:(nx - 1)], ry[2:(ny - 1)]
            end
            coords = Table(
                [
                    :x => x_arrow[1:2:(end - 1)],
                    :y => y_arrow[1:2:(end - 1)],
                    :u => [x_arrow[i] - x_arrow[i - 1] for i in 2:2:lastindex(x_arrow)],
                    :v => [y_arrow[i] - y_arrow[i - 1] for i in 2:2:lastindex(y_arrow)],
                ]
            )
            arrow_plot = series_func(merge(series_opt, arrow_opt), coords)
            push!(series_opt, "forget plot" => nothing)
            push!(axis, arrow_plot)
            Table(x_path, y_path)
        else
            Table(pgfx_series_arguments(series, opt, rng)...)
        end
        push!(axis, series_func(merge(series_opt, segment_opt), coordinates))
        # fill between functions
        if sf isa Tuple && series[:ribbon] === nothing
            sf1, sf2 = sf
            @assert sf1 == series_index "First index of the tuple has to match the current series index."
            push!(
                axis,
                series_func(
                    merge(
                        pgfx_fillstyle(opt, series_index),
                        Options("forget plot" => nothing),
                    ),
                    "fill between [of=$series_id and $(_pgfplotsx_series_ids[Symbol(string(sf2))])]",
                ),
            )
        end
        pgfx_add_legend!(axis, series, opt, k)
    end  # for segments

    # get that last marker
    if !isnothing(opt[:y]) && !any(isnan, opt[:y]) && opt[:markershape] isa AVec
        push!(
            axis,
            PGFPlotsX.PlotInc(  # additional plot
                pgfx_marker(opt, length(segments) + 1),
                PGFPlotsX.Coordinates(tuple((last(opt[:x]), last(opt[:y])))),
            ),
        )
    end
    return nothing
end

pgfx_add_series!(::Val{:straightline}, args...) = pgfx_add_series!(Val(:path), args...)
pgfx_add_series!(::Val{:path3d}, args...) = pgfx_add_series!(Val(:path), args...)

function pgfx_add_series!(::Val{:scatter}, axis, series_opt, args...)
    push!(series_opt, "only marks" => nothing)
    return pgfx_add_series!(Val(:path), axis, series_opt, args...)
end

function pgfx_add_series!(::Val{:scatter3d}, axis, series_opt, args...)
    push!(series_opt, "only marks" => nothing)
    return pgfx_add_series!(Val(:path), axis, series_opt, args...)
end

function pgfx_add_series!(::Val{:surface}, axis, series_opt, series, series_func, opt)
    push!(
        series_opt,
        "surf" => nothing,
        "mesh/rows" => length(unique(opt[:x])), # unique if its all vectors
        "mesh/cols" => length(unique(opt[:y])),
        "z buffer" => "sort",
        "opacity" => something(get_fillalpha(series), 1.0),
    )
    return pgfx_add_series!(axis, series_opt, series, series_func, opt)
end

function pgfx_add_series!(::Val{:wireframe}, axis, series_opt, series, series_func, opt)
    push!(series_opt, "mesh" => nothing, "mesh/rows" => length(opt[:x]))
    return pgfx_add_series!(axis, series_opt, series, series_func, opt)
end

function pgfx_add_series!(::Val{:heatmap}, axis, series_opt, series, series_func, opt)
    push!(axis.options, "view" => "{0}{90}")
    push!(
        series_opt,
        "matrix plot*" => nothing,
        "mesh/rows" => length(opt[:x]),
        "mesh/cols" => length(opt[:y]),
        "point meta" => "\\thisrow{meta}",
        "opacity" => something(get_fillalpha(series), 1.0),
    )
    args = pgfx_series_arguments(series, opt)
    meta = map(r -> any(!isfinite, r) ? NaN : r[3], zip(args...))
    for arg in args
        arg[(!isfinite).(arg)] .= 0
    end
    table = Table(
        [
            "x" => ispolar(series) ? rad2deg.(args[1]) : args[1],
            "y" => args[2],
            "z" => args[3],
            "meta" => meta,
        ]
    )
    push!(axis, series_func(series_opt, table))
    return pgfx_add_legend!(axis, series, opt)
end

function pgfx_add_series!(::Val{:mesh3d}, axis, series_opt, series, series_func, opt)
    ptable = if (cns = opt[:connections]) isa Tuple{Array, Array, Array}  # 0-based indexing
        map((i, j, k) -> "$i $j $k\\\\", cns...)
    elseif typeof(cns) <: AVec{NTuple{3, Int}}  # 1-based indexing
        map(c -> "$(c[1] - 1) $(c[2] - 1) $(c[3] - 1)\\\\", cns)
    else
        """
        Argument connections has to be either a tuple of three arrays (0-based indexing)
        or an AbstractVector{NTuple{3,Int}} (1-based indexing).
        """ |>
            ArgumentError |>
            throw
    end
    push!(
        series_opt,
        "patch" => nothing,
        "table/row sep" => "\\\\",
        "patch table" => join(ptable, "\n        "),
    )
    return pgfx_add_series!(axis, series_opt, series, series_func, opt)
end

function pgfx_add_series!(::Val{:contour}, axis, series_opt, series, series_func, opt)
    push!(axis.options, "view" => "{0}{90}")
    if isfilledcontour(series)
        pgfx_add_series!(Val(:filledcontour), axis, series_opt, series, series_func, opt)
        return nothing
    end
    return pgfx_add_series!(Val(:contour3d), axis, series_opt, series, series_func, opt)
end

function pgfx_add_series!(::Val{:filledcontour}, axis, series_opt, series, series_func, opt)
    push!(
        series_opt,
        "contour filled" => Options(), # labels not supported
        "patch type" => "bilinear",
        "shader" => "flat",
    )
    if (levels = opt[:levels]) isa Number
        push!(series_opt["contour filled"], "number" => levels)
    elseif levels isa AVec
        push!(series_opt["contour filled"], "levels" => levels)
    end
    return pgfx_add_series!(axis, series_opt, series, series_func, opt)
end

function pgfx_add_series!(::Val{:contour3d}, axis, series_opt, series, series_func, opt)
    push!(series_opt, "contour prepared" => Options("labels" => opt[:contour_labels]))
    push!(
        axis,
        series_func(
            merge(series_opt, pgfx_linestyle(opt)),
            Table(Contour.contours(pgfx_series_arguments(series, opt)..., opt[:levels])),
        ),
    )
    return pgfx_add_legend!(axis, series, opt)
end

function pgfx_add_series!(::Val{:quiver}, axis, series_opt, series, series_func, opt)
    if (quiver = opt[:quiver]) !== nothing
        push!(
            series_opt,
            "quiver" => Options(
                "u" => "\\thisrow{u}",
                "v" => "\\thisrow{v}",
                pgfx_arrow(opt[:arrow]) => nothing,
            ),
        )
        x, y, z = opt[:x], opt[:y], opt[:z]
        table = if z !== nothing
            push!(series_opt["quiver"], "w" => "\\thisrow{w}")
            pgfx_axis!(axis.options, series[:subplot], :z)
            [:x => x, :y => y, :z => z, :u => quiver[1], :v => quiver[2], :w => quiver[3]]
        else
            [:x => x, :y => y, :u => quiver[1], :v => quiver[2]]
        end
        pgfx_add_legend!(push!(axis, series_func(series_opt, Table(table))), series, opt)
    end
    return nothing
end

function pgfx_add_series!(::Val{:shape}, axis, series_opt, series, series_func, opt)
    series_opt = merge(push!(series_opt, "area legend" => nothing), pgfx_fillstyle(opt))
    return pgfx_add_series!(Val(:path), axis, series_opt, series, series_func, opt)
end

function pgfx_add_series!(::Val{:steppre}, axis, series_opt, args...)
    push!(series_opt, "const plot mark right" => nothing)
    return pgfx_add_series!(Val(:path), axis, series_opt, args...)
end

function pgfx_add_series!(::Val{:stepmid}, axis, series_opt, args...)
    push!(series_opt, "const plot mark mid" => nothing)
    return pgfx_add_series!(Val(:path), axis, series_opt, args...)
end

function pgfx_add_series!(::Val{:steppost}, axis, series_opt, args...)
    push!(series_opt, "const plot" => nothing)
    return pgfx_add_series!(Val(:path), axis, series_opt, args...)
end

function pgfx_add_series!(::Val{:ysticks}, axis, series_opt, args...)
    push!(series_opt, "const plot" => nothing)
    return pgfx_add_series!(Val(:path), axis, series_opt, args...)
end

function pgfx_add_series!(::Val{:xsticks}, axis, series_opt, args...)
    push!(series_opt, "const plot" => nothing)
    return pgfx_add_series!(Val(:path), axis, series_opt, args...)
end

function pgfx_add_legend!(axis, series, opt, i = 1)
    if series[:subplot][:legend_position] !== :none
        leg_entry = if (lab = opt[:label]) isa AVec
            get(lab, i, "")
        elseif lab isa AbstractString
            i == 1 ? lab : ""
        else
            throw(ArgumentError("Malformed label `$lab`"))
        end
        if isempty(leg_entry) || !pgfx_should_add_to_legend(series)
            push!(axis.contents[end].options, "forget plot" => nothing)
        else
            push!(axis, PGFPlotsX.LegendEntry(Options(), leg_entry, false))
        end
    end
    return nothing
end

pgfx_series_arguments(series, opt, range) =
    map(a -> a[range], pgfx_series_arguments(series, opt))
pgfx_series_arguments(series, opt) =
if (st = series[:seriestype]) in (:contour, :contour3d)
    opt[:x], opt[:y], handle_surface(opt[:z])
elseif st in (:heatmap, :surface, :wireframe)
    surface_to_vecs(opt[:x], opt[:y], opt[:z])
elseif RecipesPipeline.is3d(st)
    opt[:x], opt[:y], opt[:z]
elseif st === :straightline
    straightline_data(series)
elseif st === :shape
    shape_data(series)
elseif ispolar(series)
    theta, r = opt[:x], opt[:y]
    rad2deg.(theta), r
else
    opt[:x], opt[:y]
end

pgfx_get_linestyle(k::AbstractString) = pgfx_get_linestyle(Symbol(k))
pgfx_get_linestyle(k::Symbol) = get(
    (
        solid = "solid",
        dash = "dashed",
        dot = "dotted",
        dashdot = "dashdotted",
        dashdotdot = "dashdotdotted",
    ),
    k,
    "solid",
)

pgfx_get_marker(k::AbstractString) = pgfx_get_marker(Symbol(k))
pgfx_get_marker(k::Symbol) = get(
    (
        none = "none",
        cross = "+",
        xcross = "x",
        (+) = "+",
        x = "x",
        utriangle = "triangle*",
        dtriangle = "triangle*",
        rtriangle = "triangle*",
        ltriangle = "triangle*",
        circle = "*",
        rect = "square*",
        star5 = "star",
        star6 = "asterisk",
        diamond = "diamond*",
        pentagon = "pentagon*",
        hline = "-",
        vline = "|",
    ),
    k,
    "*",
)

pgfx_get_xguide_pos(k::AbstractString) = pgfx_get_xguide_pos(Symbol(k))
pgfx_get_xguide_pos(k::Symbol) = get(
    (
        top = "at={(0.5,1)},above,",
        right = "at={(ticklabel* cs:1.02)}, anchor=west,",
        left = "at={(ticklabel* cs:-0.02)}, anchor=east,",
    ),
    k,
    "at={(ticklabel cs:0.5)}, anchor=near ticklabel",
)

pgfx_get_yguide_pos(k::AbstractString) = pgfx_get_yguide_pos(Symbol(k))
pgfx_get_yguide_pos(k::Symbol) = get(
    (
        top = "at={(ticklabel* cs:1.02)}, anchor=south",
        right = "at={(1,0.5)},below,",
        bottom = "at={(ticklabel* cs:-0.02)}, anchor=north,",
    ),
    k,
    "at={(ticklabel cs:0.5)}, anchor=near ticklabel",
)

pgfx_get_legend_pos(k::AbstractString) = pgfx_get_legend_pos(Symbol(k))
pgfx_get_legend_pos(t::Tuple{<:Real, <:Real}) = ("at" => curly(t), "anchor" => "north west")
pgfx_get_legend_pos(nt::NamedTuple) = ("at" => curly(nt.at), "anchor" => string(nt.anchor))
pgfx_get_legend_pos(theta::Real) = pgfx_get_legend_pos((theta, :inner))
pgfx_get_legend_pos(k::Symbol) = get(
    (
        top = ("at" => "(0.5, 0.98)", "anchor" => "north"),
        bottom = ("at" => "(0.5, 0.02)", "anchor" => "south"),
        left = ("at" => "(0.02, 0.5)", "anchor" => "west"),
        right = ("at" => "(0.98, 0.5)", "anchor" => "east"),
        bottomleft = ("at" => "(0.02, 0.02)", "anchor" => "south west"),
        bottomright = ("at" => "(0.98, 0.02)", "anchor" => "south east"),
        topright = ("at" => "(0.98, 0.98)", "anchor" => "north east"),
        topleft = ("at" => "(0.02, 0.98)", "anchor" => "north west"),
        outertop = ("at" => "(0.5, 1.02)", "anchor" => "south"),
        outerbottom = ("at" => "(0.5, -0.02)", "anchor" => "north"),
        outerleft = ("at" => "(-0.02, 0.5)", "anchor" => "east"),
        outerright = ("at" => "(1.02, 0.5)", "anchor" => "west"),
        outerbottomleft = ("at" => "(-0.02, -0.02)", "anchor" => "north east"),
        outerbottomright = ("at" => "(1.02, -0.02)", "anchor" => "north west"),
        outertopright = ("at" => "(1.02, 1)", "anchor" => "north west"),
        outertopleft = ("at" => "(-0.02, 1)", "anchor" => "north east"),
    ),
    k,
    ("at" => "(1.02, 1)", "anchor" => "north west"),
)
function pgfx_get_legend_pos(v::Tuple{<:Real, Symbol})
    s, c = sincosd(first(v))
    anchors = [
        "south west" "south" "south east"
        "west" "center" "east"
        "north west" "north" "north east"
    ]
    I = legend_anchor_index(s)
    rect, anchor = if v[2] === :inner
        (0.07, 0.5, 1.0, 0.07, 0.52, 1.0), anchors[I, I]
    else
        (-0.15, 0.5, 1.05, -0.15, 0.52, 1.1), anchors[4 - I, 4 - I]
    end
    return "at" => string(legend_pos_from_angle(v[1], rect...)), "anchor" => anchor
end

function pgfx_get_legend_style(sp)
    cstr = plot_color(sp[:legend_background_color])
    return merge(
        pgfx_linestyle(
            pgfx_thickness_scaling(sp),
            sp[:legend_foreground_color],
            alpha(plot_color(sp[:legend_foreground_color])),
            "solid",
        ),
        Options(
            "fill" => cstr,
            "fill opacity" => alpha(cstr),
            "text opacity" => alpha(plot_color(sp[:legend_font_color])),
            "font" => pgfx_font(sp[:legend_font_pointsize], pgfx_thickness_scaling(sp)),
            "text" => plot_color(sp[:legend_font_color]),
            "cells" => Options(
                "anchor" => get(
                    (left = "west", right = "east", hcenter = "center"),
                    legendfont(sp).halign,
                    "west",
                ),
            ),
            pgfx_get_legend_pos(sp[:legend_position])...,
        ),
    )
end

pgfx_get_colorbar_pos(k::AbstractString) = pgfx_get_colorbar_pos(Symbol(k))
pgfx_get_colorbar_pos(b::Bool) = ""
pgfx_get_colorbar_pos(s::Symbol) =
    get((left = " left", bottom = " horizontal", top = " horizontal"), s, "")

pgfx_get_title_pos(k::AbstractString) = pgfx_get_title_pos(Symbol(k))
pgfx_get_title_pos(t::Tuple) = ("at" => curly(t), "anchor" => "south")
pgfx_get_title_pos(nt::NamedTuple) = ("at" => curly(nt.at), "anchor" => string(nt.anchor))
pgfx_get_title_pos(s::Symbol) = get(
    (
        left = ("at" => "{(0,1)}", "anchor" => "south west"),
        right = ("at" => "{(1,1)}", "anchor" => "south east"),
    ),
    s,
    ("at" => "{(0.5,1)}", "anchor" => "south"),
)

function pgfx_get_ticklabel_style(sp, axis)
    cstr = plot_color(axis[:tickfontcolor])
    opt = Options(
        "font" => pgfx_font(axis[:tickfontsize], pgfx_thickness_scaling(sp)),
        "color" => cstr,
        "draw opacity" => alpha(cstr),
        "rotate" => axis[:tickfontrotation],
    )
    # aligning rotated tick labels to ticks
    if RecipesPipeline.is3d(sp)
        if axis === sp[:xaxis]
            push!(opt, "anchor" => axis[:rotation] < 60 ? "north east" : "east")
        elseif axis === sp[:yaxis]
            push!(opt, "anchor" => axis[:rotation] < 45 ? "north west" : "north east")
        else
            push!(
                opt,
                "anchor" =>
                    axis[:rotation] == 0 ? "east" :
                    axis[:rotation] < 90 ? "south east" : "south",
            )
        end
    else
        if mod(axis[:rotation], 90) > 0 # 0 and ±90 already look good with the default anchor
            push!(opt, "anchor" => axis === sp[:xaxis] ? "north east" : "south east")
        end
    end
    return opt
end

function pgfx_get_colorbar_ticklabel_style(sp)
    cstr = plot_color(sp[:colorbar_tickfontcolor])
    return Options(
        "font" => pgfx_font(sp[:colorbar_tickfontsize], pgfx_thickness_scaling(sp)),
        "color" => cstr,
        "draw opacity" => alpha(cstr),
        "rotate" => sp[:colorbar_tickfontrotation],
    )
end
function pgfx_get_colorbar_title_style(sp)
    cstr = plot_color(sp[:colorbar_titlefontcolor])
    return Options(
        "font" => pgfx_font(sp[:colorbar_titlefontsize], pgfx_thickness_scaling(sp)),
        "color" => cstr,
        "draw opacity" => alpha(cstr),
        "rotate" => sp[:colorbar_titlefontrotation],
    )
end

## --------------------------------------------------------------------------------------
pgfx_arrow(::Nothing) = "every arrow/.append style={-}"
function pgfx_arrow(arr::Arrow, side = arr.side)
    components = ""
    arrow_head = "{Stealth[length = $(arr.headlength)pt, width = $(arr.headwidth)pt"
    arr.style === :open && (arrow_head *= ", open")
    arrow_head *= "]}"
    (side === :both || side === :tail) && (components *= arrow_head)
    components *= "-"
    (side === :both || side === :head) && (components *= arrow_head)
    return "every arrow/.append style={$components}"
end

function pgfx_filllegend!(series_opt, opt)
    style = strip(sprint(PGFPlotsX.print_tex, pgfx_fillstyle(opt)), ['[', ']', ' '])
    return push!(
        series_opt,
        "legend image code/.code" => "{\n\\draw[$style] (0cm,-0.1cm) rectangle (0.6cm,0.1cm);\n}",
    )
end

# Generates a colormap for pgfplots based on a ColorGradient
pgfx_colormap(cl::PlotUtils.AbstractColorList) = pgfx_colormap(color_list(cl))
pgfx_colormap(v::Vector{<:Colorant}) =
    join(map(c -> @sprintf("rgb=(%.8f,%.8f,%.8f)", red(c), green(c), blue(c)), v), '\n')
pgfx_colormap(cg::ColorGradient) = join(
    map(1:length(cg)) do i
        @sprintf(
            "rgb(%.8f)=(%.8f,%.8f,%.8f)",
            cg.values[i],
            red(cg.colors[i]),
            green(cg.colors[i]),
            blue(cg.colors[i])
        )
    end,
    '\n',
)

pgfx_framestyle(style::Symbol) =
if style in (:box, :axes, :origin, :zerolines, :grid, :none)
    style
else
    default_style = style === :semi ? :box : :axes
    @warn "Framestyle :$style is not (yet) supported by the PGFPlotsX backend. :$default_style was chosen instead."
    default_style
end

pgfx_thickness_scaling(plt::Plot) = plt[:thickness_scaling]
pgfx_thickness_scaling(sp::Subplot) = pgfx_thickness_scaling(sp.plt)
pgfx_thickness_scaling(series) = pgfx_thickness_scaling(series[:subplot])

function pgfx_fillstyle(plotattributes, i = 1)
    if (a = get_fillalpha(plotattributes, i)) === nothing
        a = alpha(single_color(get_fillcolor(plotattributes, i)))
    end
    return Options("fill" => get_fillcolor(plotattributes, i), "fill opacity" => a)
end

function pgfx_linestyle(linewidth::Real, color, α = 1, linestyle = :solid)
    cstr = plot_color(color, α)
    return Options(
        "color" => cstr,
        "draw opacity" => alpha(cstr),
        "line width" => linewidth,
        pgfx_get_linestyle(linestyle) => nothing,
    )
end

pgfx_legend_col(s::Symbol) = s === :horizontal ? -1 : 1
pgfx_legend_col(n) = n

function pgfx_linestyle(plotattributes, i = 1)
    lw = pgfx_thickness_scaling(plotattributes) * get_linewidth(plotattributes, i)
    lc = single_color(get_linecolor(plotattributes, i))
    la = get_linealpha(plotattributes, i)
    ls = get_linestyle(plotattributes, i)
    return pgfx_linestyle(lw, lc, la, ls)
end

function pgfx_font(fontsize, thickness_scaling = 1, font = "\\selectfont")
    fs = fontsize * thickness_scaling
    return "{\\fontsize{$fs pt}{$(1.3fs) pt}$font}"
end

# If a particular fontsize parameter is `nothing`, produce a figure that doesn't specify the
# font size, and therefore uses whatever fontsize is utilised by the doc in which the
# figure is located.
pgfx_font(fontsize::Nothing, thickness_scaling = 1, font = "\\selectfont") = curly(font)

pgfx_should_add_to_legend(series::Series) =
    series.plotattributes[:primary] &&
    series.plotattributes[:seriestype] ∉ (
    :hexbin,
    :bins2d,
    :histogram2d,
    :hline,
    :vline,
    :contour,
    :contourf,
    :contour3d,
    :heatmap,
    :image,
)

function pgfx_marker(plotattributes, i = 1)
    shape = _cycle(plotattributes[:markershape], i)
    cstr =
        plot_color(get_markercolor(plotattributes, i), get_markeralpha(plotattributes, i))
    cstr_stroke = plot_color(
        get_markerstrokecolor(plotattributes, i),
        get_markerstrokealpha(plotattributes, i),
    )
    mark_size =
        pgfx_thickness_scaling(plotattributes) *
        0.75 *
        _cycle(plotattributes[:markersize], i)
    mark_freq = if !any(isnan, plotattributes[:y]) && plotattributes[:markershape] isa AVec
        length(plotattributes[:markershape])
    else
        1
    end
    return Options(
        "mark" => shape isa Shape ? "PlotsShape$i" : pgfx_get_marker(shape),
        "mark size" => "$mark_size pt",
        "mark repeat" => mark_freq,
        "mark options" => Options(
            "color" => cstr_stroke,
            "draw opacity" => alpha(cstr_stroke),
            "fill" => cstr,
            "fill opacity" => alpha(cstr),
            "line width" =>
                pgfx_thickness_scaling(plotattributes) *
                0.75 *
                _cycle(plotattributes[:markerstrokewidth], i),
            "rotate" => if shape === :dtriangle
                180
            elseif shape === :rtriangle
                270
            elseif shape === :ltriangle
                90
            else
                0
            end,
            pgfx_get_linestyle(_cycle(plotattributes[:markerstrokestyle], i)) =>
                nothing,
        ),
    )
end

function pgfx_add_annotation!(
        o,
        pos,
        val,
        thickness_scaling = 1;
        cs = "axis cs:",
        options = Options(),
    )
    # Construct the style string.
    cstr = val.font.color
    ann_opt = merge(
        Options(
            get((hcenter = "", left = "right", right = "left"), val.font.halign, "") =>
                nothing,
            get((vcenter = "", top = "below", bottom = "above"), val.font.valign, "") =>
                nothing,
            "color" => cstr,
            "draw opacity" => float(alpha(cstr)),  # float(...): convert N0f8
            "rotate" => val.font.rotation,
            "font" => pgfx_font(val.font.pointsize, thickness_scaling),
        ),
        options,
    )
    return push!(
        o,
        "\\node$(sprint(PGFPlotsX.print_tex, ann_opt)) at ($(cs)$(join(pos, ','))) {$(val.str)};",
    )
end

function pgfx_fillrange_series!(axis, series, series_func, i, fillrange, rng)
    fr_opt = Options("line width" => "0", "draw opacity" => "0")
    fr_opt = merge(fr_opt, pgfx_fillstyle(series, i))
    push!(
        fr_opt,
        "mark" => "none",  # no markers on fillranges
        "forget plot" => nothing,
    )
    opt = series.plotattributes
    args = if RecipesPipeline.is3d(series)
        opt[:x][rng], opt[:y][rng], opt[:z][rng]
    elseif ispolar(series)
        rad2deg.(opt[:x][rng]), opt[:y][rng]
    elseif series[:seriestype] === :straightline
        straightline_data(series)
    else
        opt[:x][rng], opt[:y][rng]
    end
    return push!(axis, PGFPlotsX.PlotInc(fr_opt, pgfx_fillrange_args(fillrange, args...)))
end

function pgfx_fillrange_args(fillrange, x, y)
    n = length(x)
    x_fill = [x; x[n:-1:1]; x[1]]
    y_fill = [y; _cycle(fillrange, n:-1:1); y[1]]
    return PGFPlotsX.Coordinates(x_fill, y_fill)
end

function pgfx_fillrange_args(fillrange, x, y, z)
    n = length(x)
    x_fill = [x; x[n:-1:1]; x[1]]
    y_fill = [y; y[n:-1:1]; x[1]]
    z_fill = [z; _cycle(fillrange, n:-1:1); z[1]]
    return PGFPlotsX.Coordinates(x_fill, y_fill, z_fill)
end

pgfx_sanitize_string(p::PlotText) = PlotText(pgfx_sanitize_string(p.str), p.font)
pgfx_sanitize_string(s::LaTeXString) = LaTeXString(replace(s, r"\\?([#%])" => s"\\\1"))
function pgfx_sanitize_string(s::AbstractString)
    # regular latex text with the following special characters won't compile if not sanitized (escaped)
    sanitized = replace(s, r"\\?([#%_&\{\}\$])" => s"\\\1")
    return map(collect(sanitized)) do c
        if isascii(c)
            c
        else
            Latexify.latexify(c; parse = false)
        end
    end |> join |> LaTeXString
end

function pgfx_sanitize_plot!(plt)
    for (key, value) in plt.attr
        if value isa Union{AbstractString, AVec{<:AbstractString}}
            plt.attr[key] = pgfx_sanitize_string.(value)
        end
    end
    for subplot in plt.subplots
        for (key, value) in subplot.attr
            if key === :annotations && subplot.attr[:annotations] !== nothing
                old_ann = subplot.attr[key]
                for i in eachindex(old_ann)
                    # [1:end-1] is a tuple of coordinates, [end] - text
                    subplot.attr[key][i] =
                        (old_ann[i][1:(end - 1)]..., pgfx_sanitize_string(old_ann[i][end]))
                end
            elseif value isa Union{AbstractString, AVec{<:AbstractString}}
                subplot.attr[key] = pgfx_sanitize_string.(value)
            elseif value isa Axis
                for (k, v) in value.plotattributes
                    if v isa Union{AbstractString, AVec{<:AbstractString}}
                        value.plotattributes[k] = pgfx_sanitize_string.(v)
                    end
                end
            end
        end
    end
    for series in plt.series_list
        for (key, value) in series.plotattributes
            if key === :series_annotations &&
                    series.plotattributes[:series_annotations] !== nothing
                old_ann = series.plotattributes[key].strs
                for i in eachindex(old_ann)
                    series.plotattributes[key].strs[i] = pgfx_sanitize_string(old_ann[i])
                end
            elseif value isa Union{AbstractString, AVec{<:AbstractString}}
                series.plotattributes[key] = pgfx_sanitize_string.(value)
            end
        end
    end
    return
end

pgfx_is_inline_math(lab) = (
    (startswith(lab, '$') && endswith(lab, '$')) ||
        (startswith(lab, "\\(") && endswith(lab, "\\)"))
)

# surround the power part of label with curly braces
function wrap_power_label(label::AbstractString)
    pgfx_is_inline_math(label) && return label  # already in `mathmode` form
    occursin('^', label) || return label
    base, power = split(label, '^')
    return "$base^$(curly(power))"
end

wrap_power_labels(labels::AVec{LaTeXString}) = labels
function wrap_power_labels(labels::AVec{<:AbstractString})
    new_labels = similar(labels)
    for (i, label) in enumerate(labels)
        new_labels[i] = wrap_power_label(label)
    end
    return new_labels
end

# --------------------------------------------------------------------------------------
function pgfx_axis!(opt::Options, sp::Subplot, letter)
    axis = sp[get_attr_symbol(letter, :axis)]

    # turn off scaled ticks
    tick_color = plot_color(axis[:foreground_color_axis])
    push!(
        opt,
        "scaled $(letter) ticks" => "false",
        "$(letter)label" => Plots.get_guide(axis),
        "$(letter) tick style" =>
            Options("color" => color(tick_color), "opacity" => alpha(tick_color)),
        "$(letter) tick label style" => Options(
            "color" => color(tick_color),
            "opacity" => alpha(tick_color),
            "rotate" => axis[:rotation],
        ),
    )

    # set to supported framestyle
    framestyle = pgfx_framestyle(sp[:framestyle] == false ? :none : sp[:framestyle])

    # axis label position
    labelpos = if letter === :x
        pgfx_get_xguide_pos(axis[:guide_position])
    elseif letter === :y
        pgfx_get_yguide_pos(axis[:guide_position])
    else
        ""
    end

    # add label font
    cstr = plot_color(axis[:guidefontcolor])
    push!(
        opt,
        "$(letter)label style" => Options(
            labelpos => nothing,
            "at" => "{(ticklabel cs:$(get((left = 0, right = 1), axis[:guidefonthalign], 0.5)))}",
            "anchor" => "near ticklabel",
            "font" => pgfx_font(axis[:guidefontsize], pgfx_thickness_scaling(sp)),
            "color" => cstr,
            "draw opacity" => alpha(cstr),
            "rotate" => axis[:guidefontrotation],
        ),
    )

    # flip/reverse?
    axis[:flip] && push!(opt, "$letter dir" => "reverse")

    # scale
    scale = axis[:scale]
    if (is_log_scale = scale in (:ln, :log2, :log10))
        push!(opt, "$(letter)mode" => "log")
        scale === :ln || push!(opt, "log basis $letter" => "$(scale === :log2 ? 2 : 10)")
    end

    # ticks on or off
    if axis[:ticks] in (nothing, false, :none) || framestyle === :none
        push!(opt, "$(letter)majorticks" => "false")
    elseif framestyle in (:grid, :zerolines)
        push!(opt, "$letter tick style" => Options("draw" => "none"))
    end

    # grid on or off
    push!(opt, "$(letter)majorgrids" => string(axis[:grid] && framestyle !== :none))

    # limits
    lims = if ispolar(sp) && letter === :x
        rad2deg.(axis_limits(sp, :x))
    else
        axis_limits(sp, letter)
    end
    push!(opt, "$(letter)min" => lims[1], "$(letter)max" => lims[2])

    if axis[:ticks] ∉ (nothing, false, :none, :native) && framestyle !== :none
        vals, labs =
            ticks = get_ticks(sp, axis, formatter = latex_formatter(axis[:formatter]))
        # pgfplot ignores ticks with angles below `90` when `xmin = 90`, so shift values
        tick_values = if ispolar(sp) && letter === :x
            vcat(rad2deg.(vals[3:end]), 360, 405)
        else
            vals
        end
        tick_labels = if axis[:showaxis]
            if is_log_scale && axis[:ticks] === :auto
                labels = wrap_power_labels(labs)
                if (lab = first(labels)) isa LaTeXString || pgfx_is_inline_math(lab)
                    join(labels, ',')
                else
                    "\\(" * join(labels, "\\),\\(") * "\\)"
                end
            else
                labels = if ispolar(sp) && letter === :x
                    vcat(labs[3:end], "0", "45")
                else
                    labs
                end
                join(is_log_scale ? wrap_power_labels(labels) : labels, ',')
            end
        else
            ""
        end
        push!(
            opt,
            "$(letter)ticklabels" => curly(tick_labels),
            "$(letter)tick" => curly(join(tick_values, ',')),
            if (tick_dir = axis[:tick_direction]) === :none || axis[:showaxis] === false
                "$(letter)tick style" => "draw=none"
            else
                "$(letter)tick align" => "$(tick_dir)side"
            end,
            "$(letter)ticklabel style" => pgfx_get_ticklabel_style(sp, axis),
            "$letter grid style" => pgfx_linestyle(
                pgfx_thickness_scaling(sp) * axis[:gridlinewidth],
                axis[:foreground_color_grid],
                axis[:gridalpha],
                axis[:gridstyle],
            ),
        )

        # minor ticks
        # NOTE: PGFPlots would provide "minor x ticks num", but this only places minor ticks
        #       between major ticks and not outside first and last tick to the axis limits.
        #       Hence, we hack around with extra ticks.
        #       Unfortunately this conflicts with `:zerolines` framestyle hack.
        #       So minor ticks are not working with `:zerolines`.
        if (minor_ticks = get_minor_ticks(sp, axis, ticks)) !== nothing
            if ispolar(sp) && letter === :x
                minor_ticks = vcat(rad2deg.(minor_ticks[3:end]), 360, 405)
            end
            push!(
                opt,
                "extra $letter ticks" => curly(join(minor_ticks, ',')),
                "extra $letter tick labels" => "",
                "extra $letter tick style" => Options(
                    "grid" => axis[:minorgrid] ? "major" : "none",
                    "$letter grid style" => pgfx_linestyle(
                        pgfx_thickness_scaling(sp) * axis[:minorgridlinewidth],
                        axis[:foreground_color_minor_grid],
                        axis[:minorgridalpha],
                        axis[:minorgridstyle],
                    ),
                    if length(minor_ticks) > 0
                        "major tick length" => "0.1cm"
                    else
                        "major tick length" => "0"
                    end,
                ),
            )
        end
    end

    # framestyle
    if framestyle in (:axes, :origin)
        push!(
            opt,  # the * after line disables the arrow at the axis
            "axis $letter line$(axis[:draw_arrow] ? "" : "*")" =>
                (axis[:mirror] ? "right" : framestyle === :axes ? "left" : "middle"),
        )
    end

    # allow axis mirroring with :box framestyle
    if framestyle in (:box,)
        push!(opt, "$(letter)ticklabel pos" => (axis[:mirror] ? "right" : "left"))
    end

    if framestyle === :zerolines
        gs = pgfx_linestyle(pgfx_thickness_scaling(sp), axis[:foreground_color_border], 1)
        push!(
            opt,
            "extra $letter ticks" => "0",
            "extra $letter tick labels" => "",
            "extra $letter tick style" =>
                Options("grid" => "major", "$letter grid style" => gs),
        )
    end

    axis[:showaxis] || push!(opt, "separate axis lines")

    push!(
        opt,
        "$letter axis line style" =>
            if !axis[:showaxis] || framestyle in (:zerolines, :grid, :none)
            "{draw opacity = 0}"
        else
            pgfx_linestyle(
                pgfx_thickness_scaling(sp),
                axis[:foreground_color_border],
                1,
            )
        end,
    )
    return nothing
end

# --------------------------------------------------------------------------------------
# display calls this and then _display, its called 3 times for plot(1:5)
# Set the (left, top, right, bottom) minimum padding around the plot area
# to fit ticks, tick labels, guides, colorbars, etc.
function _update_min_padding!(sp::Subplot{PGFPlotsXBackend})
    return sp.minpad =
    if (leg = sp[:legend_position]) in
            (:best, :outertopright, :outerright, :outerbottomright) ||
            (leg isa Tuple && leg[1] >= 1)
        (0mm, 0mm, 5mm, 0mm)
    else
        (0mm, 0mm, 0mm, 0mm)
    end
end

_create_backend_figure(plt::Plot{PGFPlotsXBackend}) = plt.o = PGFPlotsXPlot()

_series_added(plt::Plot{PGFPlotsXBackend}, series::Series) = plt.o.is_created = false

_update_plot_object(plt::Plot{PGFPlotsXBackend}) = plt.o(plt)

for mime in ("application/pdf", "image/svg+xml", "image/png")
    @eval function _show(io::IO, mime::MIME{Symbol($mime)}, plt::Plot{PGFPlotsXBackend})
        plt.o.was_shown = true
        return show(io, mime, plt.o.the_plot)
    end
end

function _show(io::IO, mime::MIME{Symbol("application/x-tex")}, plt::Plot{PGFPlotsXBackend})
    plt.o.was_shown = true
    return PGFPlotsX.print_tex(
        io,
        plt.o.the_plot,
        include_preamble = plt.attr[:tex_output_standalone],
    )
end

function _display(plt::Plot{PGFPlotsXBackend})
    plt.o.was_shown = true
    return display(PGFPlotsX.PGFPlotsXDisplay(), plt.o.the_plot)
end
