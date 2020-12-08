# https://github.com/mbaz/Gaston.
const G = Gaston
const GastonSubplot = G.Plot
const GASTON_MARKER_SCALING = 1.3 / 5.0
const GNUPLOT_DPI = 72  # Compensate for DPI with increased resolution

#
# --------------------------------------------
# These functions are called by Plots
# --------------------------------------------
#
# Create the window/figure for this backend.
function _create_backend_figure(plt::Plot{GastonBackend})
    xsize = plt.attr[:size][1]
    ysize = plt.attr[:size][2]
    G.set(termopts="""size $xsize,$ysize""")

    state_handle = G.nexthandle() # for now all the figures will be kept
    plt.o = G.newfigure(state_handle)
end


function _before_layout_calcs(plt::Plot{GastonBackend})
    # Initialize all the subplots first
    plt.o.subplots = G.SubPlot[]
    grid = size(plt.layout)
    plt.o.layout = grid


    for sp in plt.subplots
        gaston_init_subplot(plt, sp)
    end

    # Then add the series (curves in gaston)
    for series in plt.series_list
        gaston_add_series(plt, series)
    end
end

function _update_min_padding!(sp::Subplot{GastonBackend})
    sp.minpad = (20mm, 5mm, 2mm, 10mm)
end

function _update_plot_object(plt::Plot{GastonBackend})
end

for (mime, term) in (
    "application/eps"         => "epscairo",   # NEED fixing TODO
    "image/eps"               => "epslatex",   # NEED fixing TODO
    "application/pdf"         => "pdfcairo",   # NEED fixing TODO
    "application/postscript"  => "postscript", # NEED fixing TODO
    "image/svg+xml"           => "svg",
    "text/latex"              => "tikz",       # NEED fixing TODO
    "application/x-tex"       => "epslatex",   # NEED fixing TODO
    "text/plain"              => "dumb",       # NEED fixing TODO
)
    @eval function _show(io::IO, ::MIME{Symbol($mime)}, plt::Plot{GastonBackend})
        xsize = plt.attr[:size][1]
        ysize = plt.attr[:size][2]
        termopts="""size $xsize,$ysize"""

        tmpfile = G.tempname() * "." * $term

        G.save(
            term = $term,
            output = tmpfile,
            handle = plt.o.handle,
            saveopts = termopts
        )
        while !isfile(tmpfile) end  # avoid race condition with read in next line
        write(io, read(tmpfile))
        rm(tmpfile, force=true)
        nothing

    end
end

function _show(io::IO, mime::MIME{Symbol("image/png")},
               plt::Plot{GastonBackend},)
    scaling = plt.attr[:dpi] / GNUPLOT_DPI
    xsize = plt.attr[:size][1] * scaling
    ysize = plt.attr[:size][2] * scaling

    # Scale all plot elements to match Plots.jl DPI standard
    termopts="""size $xsize,$ysize fontscale $scaling lw $scaling dl $scaling ps $scaling"""

    tmpfile = G.tempname()

    G.save(
        term = "pngcairo",
        output = tmpfile,
        handle = plt.o.handle,
        saveopts = termopts
    )
    while !isfile(tmpfile) end  # avoid race condition with read in next line
    write(io, read(tmpfile))
    rm(tmpfile, force=true)
    nothing
end


function _display(plt::Plot{GastonBackend})
    display(plt.o)
end
#
# --------------------------------------------
# These functions are gaston specific
# --------------------------------------------
#
function gaston_init_subplot(plt::Plot{GastonBackend}, sp::Subplot{GastonBackend})
    dims = RecipesPipeline.is3d(sp) ? 3 : 2

    axesconf = gaston_parse_axes_args(plt, sp)  # Gnuplot string
    sp.o = GastonSubplot(dims=dims, axesconf = axesconf, curves = [])
    push!(plt.o.subplots,  sp.o)

end

function gaston_add_series(plt::Plot{GastonBackend}, series::Series)
    # Gaston.Curve = Plots.Series
    sp = series[:subplot]
    g_sp = sp.o  # Gaston subplot object

    seriesconf = gaston_parse_series_args(series)  # Gnuplot string
    c = G.Curve(series[:x], series[:y], nothing, nothing, seriesconf )

    isfirst = length(g_sp.curves) == 0 ? true : false
    push!(g_sp.curves, c)
    G.write_data(c, g_sp.dims, g_sp.datafile, append = isfirst ? false : true)
end

function gaston_parse_series_args(series::Series)
    curveconf = String[]
    st = series[:seriestype]

    if st == :scatter
        pt = gaston_marker(series[:markershape])
        ps = series[:markersize] * GASTON_MARKER_SCALING
        lc = gaston_color(series[:markercolor])
        # alpha = series[:markeralpha] # TODO merge alpha with rgb color
        push!(curveconf, """with points pt $pt ps $ps lc $lc""")
    elseif st == :path
        lc = gaston_color(series[:linecolor])
        dt = gaston_linestyle(series[:linestyle])
        lw = series[:linewidth]
        # alpha = series[:linealpha] # TODO merge alpha with rgb color
        if series[:markershape] == :none # simplepath
            push!(curveconf, """with lines lc $lc dt $dt lw $lw""")
        else
            pt = gaston_marker(series[:markershape])
            ps = series[:markersize] * GASTON_MARKER_SCALING
            push!(curveconf, """with lp lc $lc dt $dt lw $lw pt $pt ps $ps""")
        end
    elseif st == :shape
        fc = gaston_color(series[:fillcolor])
        fs = "solid"
        lc = gaston_color(series[:linecolor])
        push!(curveconf, """with filledcurves fc $fc fs $fs border lc $lc""")
    elseif st == :steppre
        push!(curveconf, """with steps""")
    elseif st == :steppost
        push!(curveconf, """with fsteps""")  # Not sure if not the other way
    end

    # label
    push!(curveconf, """title "$(series[:label])" """)

    return join(curveconf, " ")
end

function gaston_parse_axes_args(plt::Plot{GastonBackend}, sp::Subplot{GastonBackend})
    axesconf = String[]
    # Standard 2d axis
    if !ispolar(sp) && !RecipesPipeline.is3d(sp)
        # TODO
        # configure grid, axis spines, thickness
    end

    for letter in (:x, :y, :z)
        axis_attr = sp.attr[Symbol(letter, :axis)]
        # label names
        push!(axesconf, """set $(letter)label "$(axis_attr[:guide])"  """)
        push!(axesconf, """set $(letter)label font "$(axis_attr[:guidefontfamily]), $(axis_attr[:guidefontsize])"  """)

        # Handle ticks
        # ticksyle
        push!(axesconf, """set $(letter)tics font "$(axis_attr[:tickfontfamily]), $(axis_attr[:tickfontsize])"  """)
        push!(axesconf, """set $(letter)tics textcolor rgb "#$(hex(axis_attr[:tickfontcolor], :rrggbb))" """)
        push!(axesconf, """set $(letter)tics  $(axis_attr[:tick_direction])""")

        mirror = axis_attr[:mirror] ? "mirror" : "nomirror"
        push!(axesconf, """set $(letter)tics  $(mirror) """)

        logscale = if axis_attr[:scale] == :identity
            "nologscale"
        elseif axis_attr[:scale] == :log10
            "logscale"
        end
        push!(axesconf, """set $logscale $(letter)""")

        # tick locations
        if axis_attr[:ticks] != :native
            # axis limits
            from, to = axis_limits(sp, letter)
            push!(axesconf, """set $(letter)range [$from:$to]""")

            ticks = get_ticks(sp, axis_attr)
            gaston_set_ticks!(axesconf, ticks, letter)
        end


        # TODO logscale, explicit tick location, range,
    end
    return join(axesconf, "\n")
end

function gaston_set_ticks!(axesconf, ticks, letter)

    ticks == :auto && return
    if ticks == :none || ticks === nothing || ticks == false
        push!(axesconf, """unset $(letter)tics """)
        return
    end

    ttype = ticksType(ticks)
    if ttype == :ticks
        tick_locations = @view ticks[:]
        gaston_tick_string = []
        for i in eachindex(tick_locations)
            lac = tick_locations[i]
            push!(gaston_tick_string, "$loc")
        end
        push!(
            axesconf,
            "set $(letter)tics (" * join(gaston_tick_string, ", ") * ")"
        )

    elseif ttype == :ticks_and_labels
        tick_locations = @view ticks[1][:]
        tick_labels = @view ticks[2][:]
        gaston_tick_string = []
        for i in eachindex(tick_locations)
            loc = tick_locations[i]
            lab = gaston_enclose_tick_string(tick_labels[i])
            push!(gaston_tick_string, "'$lab' $loc")
        end
        push!(
            axesconf,
            "set $(letter)tics (" * join(gaston_tick_string, ", ") * ")"
        )

    else
        error("Invalid input for $(letter)ticks: $ticks")
    end
end

function gaston_marker(marker)
    marker == :none && return -1
    marker == :circle && return 7
    marker == :rect && return 5
    marker == :diamond && return 28
    marker == :utriangle && return 9
    marker == :dtriangle && return 11
    marker == :+ && return 1
    marker == :x && return 2
    marker == :star5 && return 3
    marker == :pentagon && return 15
    marker == :pixel && return 0

    @warn("Unsupported marker $marker")
    return 1
end

gaston_color(color) = """rgb "#$(hex(color, :rrggbb))"  """

function gaston_linestyle(style)
    style == :solid && return "1"
    style == :dash && return "2"
    style == :dot && return "3"
    style == :dashdot && return "4"
    style == :dashdotdot && return "5"
end

function gaston_enclose_tick_string(tick_string)
    if findfirst("^", tick_string) == nothing
        return tick_string
    end


    base, power = split(tick_string, "^")
    power = string("{", power, "}")
    return string(base, "^", power)
end
