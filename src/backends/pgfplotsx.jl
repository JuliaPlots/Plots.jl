using PGFPlotsX: PGFPlotsX

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
# --------------------------------------------------------------------------------------
# display calls this and then _display, its called 3 times for plot(1:5)
function _update_plot_object(plt::Plot{PGFPlotsXBackend})
    plt.o = PGFPlotsX.GroupPlot()

    local axis
    for sp in plt.subplots
        bb = bbox(sp)
        axis = PGFPlotsX.@pgf PGFPlotsX.Axis(
            {
                xlabel = sp.attr[:xaxis][:guide],
                ylabel = sp.attr[:yaxis][:guide],
                height = string(height(bb)),
                width = string(width(bb)),
                title = sp[:title],
            },
        )
        for series in series_list(sp)
            opt = series.plotattributes
            series_plot = PGFPlotsX.@pgf PGFPlotsX.Plot(
                {
                    color = opt[:linecolor],
                    mark = _pgfplotsx_markers[opt[:markershape]],
                    # TODO: how to do nested options?
                    # "mark options" = "{color = $(opt[:markercolor])}",
                },
                PGFPlotsX.Coordinates(series[:x],series[:y])
                )
            push!( axis, series_plot )
            if opt[:label] != "" && sp[:legend] != :none && should_add_to_legend(series)
                push!( axis, PGFPlotsX.LegendEntry( opt[:label] )
                )
            end
        end
    end
    push!( plt.o, axis )
end

function _show(io::IO, mime::MIME"image/svg+xml", plt::Plot{PGFPlotsXBackend})
    show(io, mime, plt.o)
end

function _show(io::IO, mime::MIME"application/pdf", plt::Plot{PGFPlotsXBackend})
    show(io, mime, plt.o)
end

function _show(io::IO, mime::MIME"image/png", plt::Plot{PGFPlotsXBackend})
    show(io, mime, plt.o)
end

function _show(io::IO, mime::MIME"application/x-tex", plt::Plot{PGFPlotsXBackend})
    PGFPlotsX.print_tex(plt.o)
end

function _display(plt::Plot{PGFPlotsXBackend})
    # fn = string(tempname(),".svg")
    # PGFPlotsX.pgfsave(fn, plt.o)
    # open_browser_window(fn)
    plt.o
end
