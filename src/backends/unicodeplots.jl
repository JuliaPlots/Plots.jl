# https://github.com/JuliaPlots/UnicodePlots.jl

should_warn_on_unsupported(::UnicodePlotsBackend) = false

# ------------------------------------------------------------------------------------------
const _canvas_map = (
    braille = UnicodePlots.BrailleCanvas,
    density = UnicodePlots.DensityCanvas,
    heatmap = UnicodePlots.HeatmapCanvas,
    lookup = UnicodePlots.LookupCanvas,
    ascii = UnicodePlots.AsciiCanvas,
    block = UnicodePlots.BlockCanvas,
    dot = UnicodePlots.DotCanvas,
)

# do all the magic here... build it all at once,
# since we need to know about all the series at the very beginning
function unicodeplots_rebuild(plt::Plot{UnicodePlotsBackend})
    plt.o = UnicodePlots.Plot[]

    has_layout = prod(size(plt.layout)) > 1
    for sp in plt.subplots
        sp_kw = sp[:extra_kwargs]
        xaxis = sp[:xaxis]
        yaxis = sp[:yaxis]
        xlim = collect(axis_limits(sp, :x))
        ylim = collect(axis_limits(sp, :y))
        zlim = collect(axis_limits(sp, :z))
        F = float(eltype(xlim))

        # We set x/y to have a single point,
        # since we need to create the plot with some data.
        # Since this point is at the bottom left corner of the plot,
        # it should be hidden by consecutive plotting commands.
        x = Vector{F}(xlim)
        y = Vector{F}(ylim)
        z = Vector{F}(zlim)

        # create a plot window with xlim/ylim set,
        # but the X/Y vectors are outside the bounds
        canvas = if (up_c = get(sp_kw, :canvas, :auto)) === :auto
            isijulia() ? :ascii : :braille
        else
            up_c
        end

        border = if (up_b = get(sp_kw, :border, :auto)) === :auto
            isijulia() ? :ascii : :solid
        else
            up_b
        end

        # blank plots will not be shown
        width = has_layout && isempty(series_list(sp)) ? 0 : UnicodePlots.DEFAULT_WIDTH[]
        height = UnicodePlots.DEFAULT_HEIGHT[]

        plot_3d = is3d(sp)
        blend = get(sp_kw, :blend, true)
        grid = xaxis[:grid] && yaxis[:grid]
        quiver = contour = false
        for series in series_list(sp)
            st = series[:seriestype]
            blend &= get(series[:extra_kwargs], :blend, true)
            quiver |= series[:arrow] isa Arrow  # post-pipeline detection (:quiver -> :path)
            contour |= st === :contour
            if st === :histogram2d
                xlim = ylim = (0, 0)
            elseif st === :spy || st === :heatmap
                width = height = 0
                grid = false
            end
        end
        grid &= !(quiver || contour)
        blend &= !(quiver || contour)

        plot_3d && (xlim = ylim = (0, 0))  # determined using projection
        azimuth, elevation = sp[:camera]  # PyPlot: azimuth = -60 & elevation = 30
        projection = plot_3d ? get(sp_kw, :projection, :orthographic) : nothing

        kw = (
            compact = true,
            title = texmath2unicode(sp[:title]),
            xlabel = texmath2unicode(xaxis[:guide]),
            ylabel = texmath2unicode(yaxis[:guide]),
            grid = grid,
            blend = blend,
            height = height,
            width = width,
            xscale = xaxis[:scale],
            yscale = yaxis[:scale],
            border = border,
            xlim = xlim,
            ylim = ylim,
            # 3d
            projection = projection,
            elevation = elevation,
            azimuth = azimuth,
            zoom = get(sp_kw, :zoom, 1),
            up = get(sp_kw, :up, :z),
        )

        o = UnicodePlots.Plot(x, y, plot_3d ? z : nothing, _canvas_map[canvas]; kw...)
        for series in series_list(sp)
            o = addUnicodeSeries!(
                sp,
                o,
                kw,
                series,
                sp[:legend_position] !== :none,
                plot_3d,
            )
        end

        for ann in sp[:annotations]
            x, y, val = locate_annotation(sp, ann...)
            o = UnicodePlots.annotate!(
                o,
                x,
                y,
                texmath2unicode(val.str);
                color = up_color(val.font.color),
                halign = val.font.halign,
                valign = val.font.valign,
            )
        end

        push!(plt.o, o)  # save the object
    end
end

up_color(col::UnicodePlots.UserColorType) = col
up_color(col::RGBA) =
    (c = convert(ARGB32, col); map(Int, (red(c).i, green(c).i, blue(c).i)))
up_color(col) = :auto

function up_cmap(series)
    rng = range(0, 1, length = length(UnicodePlots.COLOR_MAP_DATA[:viridis]))
    [(red(c), green(c), blue(c)) for c in get(get_colorgradient(series), rng)]
end

# add a single series
function addUnicodeSeries!(
    sp::Subplot{UnicodePlotsBackend},
    up::UnicodePlots.Plot,
    kw,
    series,
    addlegend::Bool,
    plot_3d::Bool,
)
    st = series[:seriestype]
    se_kw = series[:extra_kwargs]

    # get the series data and label
    x, y = if st === :straightline
        straightline_data(series)
    elseif st === :shape
        shape_data(series)
    else
        series[:x], series[:y]
    end

    # special handling (src/interface)
    fix_ar = get(se_kw, :fix_ar, true)
    if st === :histogram2d
        return UnicodePlots.densityplot(x, y; kw...)
    elseif st === :spy
        return UnicodePlots.spy(Array(series[:z]); fix_ar = fix_ar, kw...)
    elseif st in (:contour, :heatmap)  # 2D
        colormap = get(se_kw, :colormap, :none)
        kw = (
            kw...,
            zlabel = sp[:colorbar_title],
            colormap = colormap === :none ? up_cmap(series) : colormap,
            colorbar = hascolorbar(sp),
        )
        if st === :contour
            isfilledcontour(series) &&
                @warn "Plots(UnicodePlots): filled contour is not implemented"
            return UnicodePlots.contourplot(
                x,
                y,
                Array(series[:z]);
                kw...,
                levels = series[:levels],
            )
        elseif st === :heatmap
            return UnicodePlots.heatmap(Array(series[:z]); fix_ar = fix_ar, kw...)
        end
    elseif st in (:surface, :wireframe)  # 3D
        colormap = get(se_kw, :colormap, :none)
        lines = get(se_kw, :lines, st === :wireframe)
        zscale = get(se_kw, :zscale, :identity)
        kw = (
            kw...,
            zlabel = sp[:colorbar_title],
            colormap = colormap === :none ? up_cmap(series) : colormap,
            colorbar = hascolorbar(sp),
            color = st === :wireframe ? up_color(get_linecolor(series, 1)) : nothing,
            zscale = zscale,
            lines = lines,
        )
        return UnicodePlots.surfaceplot(x, y, Array(series[:z]); kw...)
    elseif st === :mesh3d
        return UnicodePlots.lineplot!(
            up,
            mesh3d_triangles(x, y, series[:z], series[:connections])...,
        )
    end

    # now use the ! functions to add to the plot
    if st in (:path, :path3d, :straightline, :shape, :mesh3d)
        func = UnicodePlots.lineplot!
        series_kw = (; head_tail = series[:arrow] isa Arrow ? series[:arrow].side : nothing)
    elseif st in (:scatter, :scatter3d) || series[:markershape] !== :none
        func = UnicodePlots.scatterplot!
        series_kw = (; marker = series[:markershape])
    else
        error("Plots(UnicodePlots): series type $st not supported")
    end

    label = addlegend ? series[:label] : ""

    for (n, segment) in enumerate(series_segments(series, st; check = true))
        i, rng = segment.attr_index, segment.range
        lc = get_linecolor(series, i)
        up = func(
            up,
            x[rng],
            y[rng],
            plot_3d ? series[:z][rng] : nothing;
            color = up_color(lc),
            name = n == 1 ? label : "",
            series_kw...,
        )
    end

    for (xi, yi, str, fnt) in EachAnn(series[:series_annotations], x, y)
        up = UnicodePlots.annotate!(
            up,
            xi,
            yi,
            str;
            color = up_color(fnt.color),
            halign = fnt.halign,
            valign = fnt.valign,
        )
    end

    up
end

# ------------------------------------------------------------------------------------------

# since this is such a hack, it's only callable using `png`...
# should error during normal `show`
function png(plt::Plot{UnicodePlotsBackend}, fn::AbstractString)
    fn = addExtension(fn, "png")

    @static if Sys.isapple()
        # make some whitespace and show the plot
        println("\n\n\n\n\n\n")
        gui(plt)
        sleep(0.5)
        # use osx screen capture when my terminal is maximized
        # and cursor starts at the bottom (I know, right?)
        run(`screencapture -R50,600,700,420 $fn`)
        return
    elseif Sys.islinux()
        run(`clear`)
        gui(plt)
        win = if "WINDOWID" in keys(ENV)
            ENV["WINDOWID"]
        else
            readchomp(`xdotool getactivewindow`)
        end
        run(`import -window $win $fn`)
        return
    end

    error(
        "Can only savepng on MacOS or Linux with UnicodePlots " *
        "(though even then I wouldn't do it)",
    )
end

# ------------------------------------------------------------------------------------------
Base.show(plt::Plot{UnicodePlotsBackend}) = show(stdout, plt)
Base.show(io::IO, plt::Plot{UnicodePlotsBackend}) = _show(io, MIME("text/plain"), plt)

# NOTE: _show(...) must be kept for Base.showable (src/output.jl)
function _show(io::IO, ::MIME"text/plain", plt::Plot{UnicodePlotsBackend})
    unicodeplots_rebuild(plt)
    nr, nc = size(plt.layout)
    if nr == 1 && nc == 1  # fast path
        n = length(plt.o)
        for (i, p) in enumerate(plt.o)
            show(io, p)
            i < n && println(io)
        end
    else
        re_ansi = r"\e\[[0-9;]*[a-zA-Z]"  # m: color, [a-zA-Z]: all escape sequences
        have_color = Base.get_have_color()
        buf = IOContext(PipeBuffer(), :color => have_color)
        lines_colored = Array{Union{Nothing,Vector{String}}}(undef, nr, nc)
        lines_uncolored = have_color ? similar(lines_colored) : lines_colored
        l_max = zeros(Int, nr)
        w_max = zeros(Int, nc)
        sps = 0
        for r in 1:nr
            lmax = 0
            for c in 1:nc
                l = plt.layout[r, c]
                if l isa GridLayout && size(l) != (1, 1)
                    @error "Plots(UnicodePlots): complex nested layout is currently unsupported"
                else
                    if get(l.attr, :blank, false)
                        lines_colored[r, c] = lines_uncolored[r, c] = nothing
                    else
                        sp = plt.o[sps += 1]
                        show(buf, sp)
                        colored = read(buf, String)
                        lines_colored[r, c] = lu = lc = split(colored, '\n')
                        if have_color
                            uncolored = replace(colored, re_ansi => "")
                            lines_uncolored[r, c] = lu = split(uncolored, '\n')
                        end
                        lmax = max(length(lc), lmax)
                        w_max[c] = max(maximum(length.(lu)), w_max[c])
                    end
                end
            end
            l_max[r] = lmax
        end
        empty = String[' '^w for w in w_max]
        for r in 1:nr
            for n in 1:l_max[r]
                for c in 1:nc
                    pre = c == 1 ? '\0' : ' '
                    lc = lines_colored[r, c]
                    if lc === nothing || length(lc) < n
                        print(io, pre, empty[c])
                    else
                        lu = lines_uncolored[r, c]
                        print(io, pre, lc[n], ' '^(w_max[c] - length(lu[n])))
                    end
                end
                n < l_max[r] && println(io)
            end
            r < nr && println(io)
        end
    end
    nothing
end

# we only support MIME"text/plain", hence display(...) falls back to plain-text on stdout
_display(plt::Plot{UnicodePlotsBackend}) = (show(stdout, plt); println(stdout))
