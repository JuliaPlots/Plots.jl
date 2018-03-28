
# https://github.com/Evizero/UnicodePlots.jl

@require Revise begin
    Revise.track(Plots, joinpath(Pkg.dir("Plots"), "src", "backends", "unicodeplots.jl")) 
end

const _unicodeplots_attr = merge_with_base_supported([
    :label,
    :legend,
    :seriescolor,
    :seriesalpha,
    :linestyle,
    :markershape,
    :bins,
    :title,
    :guide, :lims,
  ])
const _unicodeplots_seriestype = [
    :path, :scatter,
    # :bar,
    :shape,
    :histogram2d,
    :spy
]
const _unicodeplots_style = [:auto, :solid]
const _unicodeplots_marker = [:none, :auto, :circle]
const _unicodeplots_scale = [:identity]


# don't warn on unsupported... there's just too many warnings!!
warnOnUnsupported_args(::UnicodePlotsBackend, d::KW) = nothing

# --------------------------------------------------------------------------------------

function add_backend_string(::UnicodePlotsBackend)
    """
    Pkg.add("UnicodePlots")
    Pkg.build("UnicodePlots")
    """
end

function _initialize_backend(::UnicodePlotsBackend; kw...)
    @eval begin
        import UnicodePlots
        export UnicodePlots
    end
end

# -------------------------------

const _canvas_type = Ref(:auto)

function _canvas_map()
    KW(
        :braille => UnicodePlots.BrailleCanvas,
        :ascii => UnicodePlots.AsciiCanvas,
        :block => UnicodePlots.BlockCanvas,
        :dot => UnicodePlots.DotCanvas,
        :density => UnicodePlots.DensityCanvas,
    )
end


# do all the magic here... build it all at once, since we need to know about all the series at the very beginning
function rebuildUnicodePlot!(plt::Plot, width, height)
    plt.o = []

    for sp in plt.subplots
        xaxis = sp[:xaxis]
        yaxis = sp[:yaxis]
        xlim =  axis_limits(xaxis)
        ylim =  axis_limits(yaxis)

        # make vectors
        xlim = [xlim[1], xlim[2]]
        ylim = [ylim[1], ylim[2]]

        # we set x/y to have a single point, since we need to create the plot with some data.
        # since this point is at the bottom left corner of the plot, it shouldn't actually be shown
        x = Float64[xlim[1]]
        y = Float64[ylim[1]]

        # create a plot window with xlim/ylim set, but the X/Y vectors are outside the bounds
        ct = _canvas_type[]
        canvas_type = if ct == :auto
            isijulia() ? UnicodePlots.AsciiCanvas : UnicodePlots.BrailleCanvas
        else
            _canvas_map()[ct]
        end

        # special handling for spy
        if length(sp.series_list) == 1
            series = sp.series_list[1]
            if series[:seriestype] == :spy
                push!(plt.o, UnicodePlots.spy(
                    series[:z].surf,
                    width = width,
                    height = height,
                    title = sp[:title],
                    canvas = canvas_type
                ))
                continue
            end
        end

        # # make it a bar canvas if plotting bar
        # if any(series -> series[:seriestype] == :bar, series_list(sp))
        #     canvas_type = UnicodePlots.BarplotGraphics
        # end

        o = UnicodePlots.Plot(x, y, canvas_type;
            width = width,
            height = height,
            title = sp[:title],
            xlim = xlim,
            ylim = ylim,
            border = isijulia() ? :ascii : :solid
        )

        # set the axis labels
        UnicodePlots.xlabel!(o, xaxis[:guide])
        UnicodePlots.ylabel!(o, yaxis[:guide])

        # now use the ! functions to add to the plot
        for series in series_list(sp)
            addUnicodeSeries!(o, series.d, sp[:legend] != :none, xlim, ylim)
        end

        # save the object
        push!(plt.o, o)
    end
end


# add a single series
function addUnicodeSeries!(o, d::KW, addlegend::Bool, xlim, ylim)
    # get the function, or special handling for step/bar/hist
    st = d[:seriestype]
    if st == :histogram2d
        UnicodePlots.densityplot!(o, d[:x], d[:y])
        return
    end

    if st == :path
        func = UnicodePlots.lineplot!
    elseif st == :scatter || d[:markershape] != :none
        func = UnicodePlots.scatterplot!
    # elseif st == :bar
    #     func = UnicodePlots.barplot!
    elseif st == :shape
        func = UnicodePlots.lineplot!
    else
        error("Linestyle $st not supported by UnicodePlots")
    end

    # get the series data and label
    x, y = [collect(float(d[s])) for s in (:x, :y)]
    label = addlegend ? d[:label] : ""

    # if we happen to pass in allowed color symbols, great... otherwise let UnicodePlots decide
    color = d[:linecolor] in UnicodePlots.color_cycle ? d[:linecolor] : :auto

    # add the series
    x, y = Plots.unzip(collect(Base.Iterators.filter(xy->isfinite(xy[1])&&isfinite(xy[2]), zip(x,y))))
    func(o, x, y; color = color, name = label)
end

# -------------------------------

# since this is such a hack, it's only callable using `png`... should error during normal `show`
function png(plt::AbstractPlot{UnicodePlotsBackend}, fn::AbstractString)
    fn = addExtension(fn, "png")

    # make some whitespace and show the plot
    println("\n\n\n\n\n\n")
    gui(plt)

    # @osx_only begin
    @static if is_apple()
        # BEGIN HACK

        # wait while the plot gets drawn
        sleep(0.5)

        # use osx screen capture when my terminal is maximized and cursor starts at the bottom (I know, right?)
        # TODO: compute size of plot to adjust these numbers (or maybe implement something good??)
        run(`screencapture -R50,600,700,420 $fn`)

        # END HACK (phew)
        return
    end

    error("Can only savepng on osx with UnicodePlots (though even then I wouldn't do it)")
end

# -------------------------------

# we don't do very much for subplots... just stack them vertically

function unicodeplots_rebuild(plt::Plot{UnicodePlotsBackend})
    w, h = plt[:size]
    plt.attr[:color_palette] = [RGB(0,0,0)]
    rebuildUnicodePlot!(plt, div(w, 10), div(h, 20))
end

function _show(io::IO, ::MIME"text/plain", plt::Plot{UnicodePlotsBackend})
    unicodeplots_rebuild(plt)
    map(show, plt.o)
    nothing
end


function _display(plt::Plot{UnicodePlotsBackend})
    unicodeplots_rebuild(plt)
    map(show, plt.o)
    nothing
end
