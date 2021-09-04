
# https://github.com/JuliaPlots/UnicodePlots.jl

# don't warn on unsupported... there's just too many warnings!!
warn_on_unsupported_args(::UnicodePlotsBackend, plotattributes::KW) = nothing

# --------------------------------------------------------------------------------------

_canvas_map() = (
    ascii = UnicodePlots.AsciiCanvas,
    block = UnicodePlots.BlockCanvas,
    braille = UnicodePlots.BrailleCanvas,
    density = UnicodePlots.DensityCanvas,
    dot = UnicodePlots.DotCanvas,
    heatmap = UnicodePlots.HeatmapCanvas,
    lookup = UnicodePlots.LookupCanvas,
)

# do all the magic here... build it all at once, since we need to know about all the series at the very beginning
function unicodeplots_rebuild(plt::Plot{UnicodePlotsBackend})
    plt.o = UnicodePlots.Plot[]
    canvas_map = _canvas_map()
    for sp in plt.subplots
        xaxis = sp[:xaxis]
        yaxis = sp[:yaxis]
        xlim = axis_limits(sp, :x)
        ylim = axis_limits(sp, :y)

        # make vectors
        xlim = [xlim[1], xlim[2]]
        ylim = [ylim[1], ylim[2]]

        # we set x/y to have a single point, since we need to create the plot with some data.
        # since this point is at the bottom left corner of the plot, it shouldn't actually be shown
        x = Float64[xlim[1]]
        y = Float64[ylim[1]]

        # create a plot window with xlim/ylim set, but the X/Y vectors are outside the bounds
        canvas_type = if (ct = _canvas_type[]) == :auto
            isijulia() ? :ascii : :braille
        else
            ct
        end

        o = UnicodePlots.Plot(
            x,
            y,
            canvas_map[canvas_type];
            title = sp[:title],
            xlim = xlim,
            ylim = ylim,
            xlabel = xaxis[:guide],
            ylabel = yaxis[:guide],
            border = isijulia() ? :ascii : :solid,
        )
        for series in series_list(sp)
            o = addUnicodeSeries!(sp, o, series, sp[:legend] != :none, xlim, ylim)
        end

        push!(plt.o, o)  # save the object
    end
end

# add a single series
function addUnicodeSeries!(
    sp::Subplot{UnicodePlotsBackend},
    up::UnicodePlots.Plot,
    series,
    addlegend::Bool,
    xlim,
    ylim,
)
    st = series[:seriestype]
    
    # get the series data and label
    x, y = if st == :straightline
        straightline_data(series)
    elseif st == :shape
        shape_data(series)
    else
        float(series[:x]), float(series[:y])
    end

    # special handling (src/interface)
    if st == :histogram2d
        return UnicodePlots.densityplot(x, y)
    elseif st == :heatmap
        rng = range(0, 1, length = length(UnicodePlots.COLOR_MAP_DATA[:viridis]))
        cmap = [(red(c), green(c), blue(c)) for c in get(get_colorgradient(series), rng)]
        return UnicodePlots.heatmap(
            series[:z].surf;
            title = sp[:title],
            zlabel = sp[:colorbar_title],
            colormap = cmap,
        )
    elseif st == :spy
        return UnicodePlots.spy(series[:z].surf; title = sp[:title])
    end

    # now use the ! functions to add to the plot
    if st in (:path, :straightline, :shape)
        func = UnicodePlots.lineplot!
    elseif st == :scatter || series[:markershape] != :none
        func = UnicodePlots.scatterplot!
    else
        error("Series type $st not supported by UnicodePlots")
    end

    label = addlegend ? series[:label] : ""

    for (n, segment) in enumerate(series_segments(series, st; check = true))
        i, rng = segment.attr_index, segment.range
        lc = get_linecolor(series, i)
        if typeof(lc) <: UnicodePlots.UserColorType
            color = lc
        elseif typeof(lc) <: RGBA
            lc = convert(ARGB32, lc)
            color = map(Int, (red(lc).i, green(lc).i, blue(lc).i))
        else
            color = :auto
        end

        up = func(up, x[rng], y[rng]; color = color, name = n == 1 ? label : "")
    end
    return up
end

# -------------------------------

# since this is such a hack, it's only callable using `png`... should error during normal `show`
function png(plt::Plot{UnicodePlotsBackend}, fn::AbstractString)
    fn = addExtension(fn, "png")

    @static if Sys.isapple()
        # make some whitespace and show the plot
        println("\n\n\n\n\n\n")
        gui(plt)

        # BEGIN HACK

        # wait while the plot gets drawn
        sleep(0.5)

        # use osx screen capture when my terminal is maximized and cursor starts at the bottom (I know, right?)
        # TODO: compute size of plot to adjust these numbers (or maybe implement something good??)
        run(`screencapture -R50,600,700,420 $fn`)

        # END HACK (phew)
        return
    elseif Sys.islinux()
        run(`clear`)
        gui(plt)
        run(`import -window $(ENV["WINDOWID"]) $fn`)
        return
    end

    error(
        "Can only savepng on MacOS or Linux with UnicodePlots (though even then I wouldn't do it)",
    )
end

# -------------------------------
Base.show(plt::Plot{UnicodePlotsBackend}) = _show(stdout, MIME("text/plain"), plt)

function _show(io::IO, ::MIME"text/plain", plt::Plot{UnicodePlotsBackend})
    unicodeplots_rebuild(plt)
    nr, nc = size(plt.layout)
    lines_colored = Array{Union{Nothing,Vector{String}}}(undef, nr, nc)
    lines_uncolored = copy(lines_colored)
    l_max = zeros(Int, nr)
    buf = IOBuffer()
    cbuf = IOContext(buf, :color => true)
    sps = wmax = 0
    for r in 1:nr
        lmax = 0
        for c in 1:nc
            l = plt.layout[r, c]
            if l isa GridLayout && size(l) != (1, 1)
                @error "UnicodePlots: complex nested layout is currently unsupported !"
            else
                if get(l.attr, :blank, false)
                    lines_colored[r, c] = lines_uncolored[r, c] = nothing
                else
                    sp = plt.o[sps += 1]
                    show(cbuf, sp)
                    colored = String(take!(buf))
                    uncolored = replace(colored, r"\x1B\[[0-9;]*[a-zA-Z]" => "")
                    lines_colored[r, c] = lc = split(colored, "\n")
                    lines_uncolored[r, c] = lu = split(uncolored, "\n")
                    lmax = max(length(lc), lmax)
                    wmax = max(maximum(length.(lu)), wmax)
                end
            end
        end
        l_max[r] = lmax
    end
    empty = ' '^wmax
    for r in 1:nr
        for n in 1:l_max[r]
            for c in 1:nc
                pre = c == 1 ? '\0' : ' '
                lc = lines_colored[r, c]
                if lc === nothing || length(lc) < n
                    print(io, pre, empty)
                else
                    lu = lines_uncolored[r, c]
                    print(io, pre, lc[n], ' '^(wmax - length(lu[n])))
                end
            end
            println(io)
        end
        r < nr && println(io)
    end
    nothing
end

function _display(plt::Plot{UnicodePlotsBackend})
    unicodeplots_rebuild(plt)
    map(display, plt.o)
    nothing
end
