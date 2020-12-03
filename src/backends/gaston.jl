# https://github.com/mbaz/Gaston.
const G = Gaston
const GastonSubplot = G.Plot
# --------------------------------------------
# These functions are called by Plots
# --------------------------------------------
# Create the window/figure for this backend.
function _create_backend_figure(plt::Plot{GastonBackend})
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

function _show(io::IO, ::MIME"image/png", plt::Plot{GastonBackend})
end

function _display(plt::Plot{GastonBackend})
    display(plt.o)
end

# --------------------------------------------
# These functions are called gaston specific
# --------------------------------------------

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
    G.write_data(c, g_sp.dims, g_sp.datafile, append = isfirst ? false : true)  # TODO add appended series
end

function gaston_parse_series_args(series::Series)
    curveconf = String[]
    st = series[:seriestype]

    if st == :path
        push!(curveconf, """with lines """)
    elseif st == :steppre
        push!(curveconf, """with steps""")
    elseif st == :steppost
        push!(curveconf, """with fsteps""")  # Not sure if not the other way
    end

    # line color
    push!(curveconf, """lc rgb "#$(hex(series[:linecolor], :rrggbb))" """)

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

        # tick font
        push!(axesconf, """set $(letter)tics font "$(axis_attr[:tickfontfamily]), $(axis_attr[:tickfontsize])"  """)

        push!(axesconf, """set $(letter)tics textcolor rgb "#$(hex(axis_attr[:tickfontcolor], :rrggbb))" """)

        push!(axesconf, """set $(letter)tics  $(axis_attr[:tick_direction])""")

        mirror = axis_attr[:mirror] ? "nomirror" : "mirror"
        push!(axesconf, """set $(letter)tics  $(mirror) """)

        # set xtics (1,2,5,10,20,50)
        # TODO logscale, explicit tick location, range,
    end
    return join(axesconf, "\n")
end
