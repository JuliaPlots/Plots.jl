plot_function(plt::Function, grouped) = plt
plot_function(plt::Tuple, grouped) = grouped ? plt[2] : plt[1]

combine_cols(dict, ns) = length(ns) > 1 ? hcat((dict[n] for n in ns)...) : dict[ns[1]]

function dataviewer(t; throttle = 0.1, nbins = 30, nbins_range = 1:100)
    (t isa AbstractObservable) || (t = Observable{Any}(t))

    coltable = map(Tables.columntable, t)

    @show names = map(collect ∘ keys, coltable)

    dict = @map Dict((key, val) for (key, val) in pairs(&coltable))
    x = Widgets.dropdown(names, placeholder = "First axis", multiple = true)
    y = Widgets.dropdown(names, placeholder = "Second axis", multiple = true)
    y_toggle = Widgets.togglecontent(y, value = false, label = "Second axis")
    plot_type = Widgets.dropdown(
        OrderedDict(
            "line"         => PlotsBase.plot,
            "scatter"      => PlotsBase.scatter,
            "bar"          => (PlotsBase.bar, StatsPlots.groupedbar),
            "boxplot"      => (StatsPlots.boxplot, StatsPlots.groupedboxplot),
            "corrplot"     => StatsPlots.corrplot,
            "cornerplot"   => StatsPlots.cornerplot,
            "density"      => StatsPlots.density,
            "cdensity"     => StatsPlots.cdensity,
            "histogram"    => StatsPlots.histogram,
            "marginalhist" => StatsPlots.marginalhist,
            "violin"       => (StatsPlots.violin, StatsPlots.groupedviolin),
        ),
        placeholder = "Plot type",
    )

    # Add bins if the plot allows it
    display_nbins =
        @map (&plot_type) in [corrplot, cornerplot, histogram, marginalhist] ? "block" :
             "none"
    nbins = (Widgets.slider(
        nbins_range,
        extra_obs = ["display" => display_nbins],
        value = nbins,
        label = "number of bins",
    ))
    nbins.scope.dom = Widgets.div(
        nbins.scope.dom,
        attributes = Dict("data-bind" => "style: {display: display}"),
    )
    nbins_throttle = Observables.throttle(throttle, nbins)

    by = Widgets.dropdown(names, multiple = true, placeholder = "Group by")
    by_toggle = Widgets.togglecontent(by, value = false, label = "Split data")
    plt = Widgets.button("plot")
    output = @map begin
        if (&plt == 0)
            plot()
        else
            args = Any[]
            # add first and maybe second argument
            push!(args, combine_cols(&dict, x[]))
            has_y = y_toggle[] && !isempty(y[])
            has_y && push!(args, combine_cols(&dict, y[]))

            # compute automatic kwargs
            kwargs = Dict()

            # grouping kwarg
            has_by = by_toggle[] && !isempty(by[])
            by_tup = Tuple(getindex(&dict, b) for b in by[])
            has_by && (kwargs[:group] = NamedTuple{Tuple(by[])}(by_tup))

            # label kwarg
            if length(x[]) > 1
                kwargs[:label] = x[]
            elseif y_toggle[] && length(y[]) > 1
                kwargs[:label] = y[]
            end

            # x and y labels
            densityplot1D = plot_type[] in [cdensity, density, histogram]
            (length(x[]) == 1 && (densityplot1D || has_y)) && (kwargs[:xlabel] = x[][1])
            if has_y && length(y[]) == 1
                kwargs[:ylabel] = y[][1]
            elseif !has_y && !densityplot1D && length(x[]) == 1
                kwargs[:ylabel] = x[][1]
            end

            plot_func = plot_function(plot_type[], has_by)
            plot_func(args...; nbins = &nbins_throttle, kwargs...)
        end
    end
    wdg = Widget{:dataviewer}(
        [
            "x" => x,
            "y" => y,
            "y_toggle" => y_toggle,
            "by" => by,
            "by_toggle" => by_toggle,
            "plot_type" => plot_type,
            "plot_button" => plt,
            "nbins" => nbins,
        ],
        output = output,
    )
    @layout! wdg Widgets.div(
        Widgets.div(:x, :y_toggle, :plot_type, :by_toggle, :plot_button),
        Widgets.div(style = Dict("width" => "3em")),
        Widgets.div(Widgets.observe(_), :nbins),
        style = Dict("display" => "flex", "direction" => "row"),
    )
end
