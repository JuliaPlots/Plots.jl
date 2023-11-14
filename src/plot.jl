
mutable struct CurrentPlot
    nullableplot::Union{AbstractPlot,Nothing}
end
const CURRENT_PLOT = CurrentPlot(nothing)

isplotnull() = CURRENT_PLOT.nullableplot === nothing

"""
    current()
Returns the Plot object for the current plot
"""
function current()
    isplotnull() && error("No current plot/subplot")
    CURRENT_PLOT.nullableplot
end
current(plot::AbstractPlot) = (CURRENT_PLOT.nullableplot = plot)

# ---------------------------------------------------------

Base.string(plt::Plot) = "Plot{$(plt.backend) n=$(plt.n)}"
Base.print(io::IO, plt::Plot) = print(io, string(plt))
function Base.show(io::IO, plt::Plot)
    print(io, string(plt))
    sp_ekwargs = getindex.(plt.subplots, :extra_kwargs)
    s_ekwargs = getindex.(plt.series_list, :extra_kwargs)
    (
        isempty(plt[:extra_plot_kwargs]) &&
        all(isempty, sp_ekwargs) &&
        all(isempty, s_ekwargs)
    ) && return
    print(io, "\nCaptured extra kwargs:\n")
    do_show = true
    for (key, value) in plt[:extra_plot_kwargs]
        do_show && println(io, "  Plot:")
        println(io, " "^4, key, ": ", value)
        do_show = false
    end
    do_show = true
    for (i, ekwargs) in enumerate(sp_ekwargs)
        for (key, value) in ekwargs
            do_show && println(io, "  SubplotPlot{$i}:")
            println(io, " "^4, key, ": ", value)
            do_show = false
        end
        do_show = true
    end
    for (i, ekwargs) in enumerate(s_ekwargs)
        for (key, value) in ekwargs
            do_show && println(io, "  Series{$i}:")
            println(io, " "^4, key, ": ", value)
            do_show = false
        end
        do_show = true
    end
end

getplot(plt::Plot) = plt
getattr(plt::Plot, idx::Int = 1) = plt.attr

# ---------------------------------------------------------

"""
The main plot command. Use `plot` to create a new plot object, and `plot!` to add to an existing one:

```
    plot(args...; kw...)                  # creates a new plot window, and sets it to be the current
    plot!(args...; kw...)                 # adds to the `current`
    plot!(plotobj, args...; kw...)        # adds to the plot `plotobj`
```

There are lots of ways to pass in data, and lots of keyword arguments... just try it and it will likely work as expected.
When you pass in matrices, it splits by columns.
To see the list of available attributes, use the `plotattr(attr)`
function, where `attr` is the symbol `:Series`, `:Subplot`, `:Plot`, or `:Axis`.
Pass any attribute to `plotattr` as a String to look up its docstring, e.g., `plotattr("seriestype")`.

# Extended help

## Series attributes
- $(_generate_doclist(_all_series_args))

## Axis attributes
Prepend these with the axis letter (x, y or z)
- $(_generate_doclist(_all_axis_args))

## Subplot attributes
- $(_generate_doclist(_all_subplot_args))

## Plot attributes
- $(_generate_doclist(_all_plot_args))
"""
function RecipesBase.plot(args...; kw...)
    @nospecialize
    # this creates a new plot with args/kw and sets it to be the current plot
    plotattributes = KW(kw)
    Plots.preprocess_attributes!(plotattributes)

    # create an empty Plot then process
    plt = Plot()
    # plt.user_attr = plotattributes
    _plot!(plt, plotattributes, args)
end

# build a new plot from existing plots
# note: we split into plt1, plt2 and plts_tail so we can dispatch correctly
plot(
    plt1::Plot,
    plt2::Union{PlaceHolder,Plot},
    plts_tail::Union{PlaceHolder,Plot}...;
    kw...,
) = plot!(deepcopy(plt1), deepcopy(plt2), deepcopy.(plts_tail)...; kw...)
function plot!(
    plt1::Plot,
    plt2::Union{PlaceHolder,Plot},
    plts_tail::Union{PlaceHolder,Plot}...;
    kw...,
)
    @nospecialize
    plotattributes = KW(kw)
    Plots.preprocess_attributes!(plotattributes)

    # build our plot vector from the args
    plts = Plot[plt1]
    plt2 isa PlaceHolder || push!(plts, plt2)
    foreach(p -> p isa PlaceHolder || push!(plts, p), plts_tail)
    n = length(plts)

    # compute the layout
    layout = layout_args(plotattributes, n)[1]
    num_sp = sum(length(p.subplots) for p in plts)

    # create a new plot object, with subplot list/map made of existing subplots.
    # note: we create a new backend figure for this new plot object
    # note: all subplots and series "belong" to this new plot...
    plt = Plot()

    # TODO: build the user_attr dict by creating "Any matrices" for the args of each subplot

    # TODO: replace this with proper processing from a merged user_attr KW
    # update plot args
    for p in plts
        plt.attr = merge(p.attr, plt.attr)  # plt.attr preempts p.attr (for `twinx`)
        plt.n += p.n
    end
    plt[:size] = last(sort(getindex.(plts, :size), by = x -> x[1] * x[2]))
    _update_plot_args(plt, plotattributes)

    # pass new plot to the backend
    plt.o = _create_backend_figure(plt)
    plt.init = true

    series_attr = KW()
    for (k, v) in plotattributes
        is_series_attr(k) && (series_attr[k] = pop!(plotattributes, k))
    end

    # create the layout
    plt.layout, plt.subplots, plt.spmap = build_layout(layout, num_sp, copy(plts))

    # do we need to link any axes together?
    link_axes!(plt.layout, plt[:link])

    # initialize the subplots
    cmdidx = 1
    for (idx, sp) in enumerate(plt.subplots)
        _initialize_subplot(plt, sp)
        serieslist = series_list(sp)
        append!(plt.inset_subplots, sp.plt.inset_subplots)
        sp.plt = plt
        sp.attr[:subplot_index] = idx
        for series in serieslist
            merge!(series.plotattributes, series_attr)
            _slice_series_args!(series.plotattributes, plt, sp, cmdidx)
            push!(plt.series_list, series)
            _series_added(plt, series)
            cmdidx += 1
        end
    end
    ttl_idx = _add_plot_title!(plt)

    # first apply any args for the subplots
    for (idx, sp) in enumerate(plt.subplots)
        _update_subplot_args(plt, sp, idx == ttl_idx ? KW() : plotattributes, idx, false)
    end

    # finish up
    current(plt)
    _do_plot_show(plt, get(plotattributes, :show, default(:show)))
    plt
end

# this adds to the current plot, or creates a new plot if none are current
function plot!(args...; kw...)
    @nospecialize
    local plt
    try
        plt = current()
    catch
        return plot(args...; kw...)
    end
    plot!(current(), args...; kw...)
end

# this adds to a specific plot... most plot commands will flow through here
plot(plt::Plot, args...; kw...) = plot!(deepcopy(plt), args...; kw...)

function plot!(plt::Plot, args...; kw...)
    @nospecialize
    plotattributes = KW(kw)
    Plots.preprocess_attributes!(plotattributes)
    # merge!(plt.user_attr, plotattributes)
    _plot!(plt, plotattributes, args)
end

# -------------------------------------------------------------------------------

# this is the core plotting function.  recursively apply recipes to build
# a list of series KW dicts.
# note: at entry, we only have those preprocessed args which were passed in... no default values yet
function _plot!(plt::Plot, plotattributes, args)
    @nospecialize
    RecipesPipeline.recipe_pipeline!(plt, plotattributes, args)
    current(plt)
    _do_plot_show(plt, plt[:show])
    return plt
end

# we're getting ready to display/output.  prep for layout calcs, then update
# the plot object after
function prepare_output(plt::Plot)
    _before_layout_calcs(plt)

    _wh = plt.attr[:size]
    if length(_wh) != 2
        throw(ArgumentError("plot size must have length = 2, got size = $_wh"))
    end
    w, h = _wh

    plt.layout.bbox = BoundingBox(0mm, 0mm, w * px, h * px)

    # One pass down and back up the tree to compute the minimum padding
    # of the children on the perimeter.  This is an backend callback.
    _update_min_padding!(plt.layout)

    # specific to :plot_title see _add_plot_title!
    force_minpad = get(plt, :force_minpad, ())
    isempty(force_minpad) || for i in eachindex(plt.layout.grid)
        plt.layout.grid[i].minpad = Tuple(
            i === nothing ? j : i for
            (i, j) in zip(force_minpad, plt.layout.grid[i].minpad)
        )
    end

    # now another pass down, to update the bounding boxes
    update_child_bboxes!(plt.layout)

    # update those bounding boxes of inset subplots
    update_inset_bboxes!(plt)

    # the backend callback, to reposition subplots, etc
    _update_plot_object(plt)
end

"""
    backend_object(plot)

Returns the backend representation of a Plot object.
Returns `nothing` if the backend does not support this.
"""
function backend_object(plt::Plot)
    prepare_output(plt)
    plt.o
end

# --------------------------------------------------------------------

"""
Extract a subplot from an existing plot.

# Examples
```julia-repl
julia> p1, p2 = plot(1:2), plot(10:20)
julia> pl = plot(p1, p2)  # plot containing 2 subplots

julia> plot(pl.subplots[1])  # extract 1st subplot as a standalone plot
julia> plot(pl.subplots[2])  # extract 2nd subplot as a standalone plot
```
"""
function plot(sp::Subplot, args...; kw...)
    @nospecialize
    plt = Plots.Plot(sp)
    plot(plt, PlaceHolder(), PlaceHolder(), args...; kw...)
end

# plot to a Subplot
function plot!(sp::Subplot, args...; kw...)
    @nospecialize
    plt = sp.plt
    plot!(plt, args...; kw..., subplot = findfirst(isequal(sp), plt.subplots))
end
