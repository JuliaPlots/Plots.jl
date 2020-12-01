# https://github.com/mbaz/Gaston.
const G = Gaston

# Create the window/figure for this backend.
function _create_backend_figure(plt::Plot{GastonBackend})
    plt.o = G.newfigure(G.gnuplot_state.current)
end

# # this is called early in the pipeline, use it to make the plot current or something
# function _prepare_plot_object(plt::Plot{GastonBackend})
# end

# Set up the subplot within the backend object.
function gaston_init_subplot(plt::Plot{GastonBackend}, sp::Subplot{GastonBackend})
    sp.o = plt.o.subplots[1]
    empty!(sp.o.curves)

end

function _before_layout_calcs(plt::Plot{GastonBackend})
    for sp in plt.subplots
        gaston_init_subplot(plt, sp)
    end

    # add the series
    for series in plt.series_list
        gaston_add_series(plt, series)
    end
end

function gaston_add_series(plt::Plot{GastonBackend}, series::Series)
    st = series[:seriestype]
    sp = series[:subplot]
    g_sp = sp.o

    gnuplot_args = gaston_parse_series_args(series)
    c = G.Curve(series[:x], series[:y], nothing, nothing, gnuplot_args)

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
        push!(curveconf, """with fsteps""")  # Not sure if not 'steps'
    end

    # line color
    push!(curveconf, """lc rgb "#$(hex(series[:linecolor], :rrggbb))" """)

    # label
    push!(curveconf, """title "$(series[:label])" """)

    return join(curveconf, " ")
end

# Set the (left, top, right, bottom) minimum padding around the plot area
# to fit ticks, tick labels, guides, colorbars, etc.
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
