module PlotsPlots

export Plot, PlotOrSubplot, _update_plot_args
import Plots: Plots, AbstractPlot, AbstractBackend, DefaultsDict, Series, Axis, Subplot, AbstractLayout
using Plots.Commons

const SubplotMap = Dict{Any,Subplot}

mutable struct Plot{T<:AbstractBackend} <: AbstractPlot{T}
    backend::T                   # the backend type
    n::Int                       # number of series
    attr::DefaultsDict            # arguments for the whole plot
    series_list::Vector{Series}  # arguments for each series
    o                            # the backend's plot object
    subplots::Vector{Subplot}
    spmap::SubplotMap            # provide any label as a map to a subplot
    layout::AbstractLayout
    inset_subplots::Vector{Subplot}  # list of inset subplots
    init::Bool

    function Plot()
        be = Plots.backend()
        new{typeof(be)}(
            be,
            0,
            DefaultsDict(KW(), Plots._plot_defaults),
            Series[],
            nothing,
            Subplot[],
            SubplotMap(),
            Plots.EmptyLayout(),
            Subplot[],
            false,
        )
    end

    function Plot(osp::Subplot)
        plt = Plot()
        plt.layout = Plots.GridLayout(1, 1)
        sp = deepcopy(osp)  # FIXME: fails `PlotlyJS` ?
        plt.layout.grid[1, 1] = sp
        # reset some attributes
        sp.minpad = DEFAULT_MINPAD[]
        sp.bbox = DEFAULT_BBOX[]
        sp.plotarea = DEFAULT_BBOX[]
        sp.plt = plt  # change the enclosing plot
        push!(plt.subplots, sp)
        plt
    end
end # Plot

const PlotOrSubplot = Union{Plot,Subplot}

Base.iterate(plt::Plot) = iterate(plt.subplots)

# properly retrieve from plt.attr, passing `:match` to the correct key
Base.getindex(plt::Plot, k::Symbol) =
    if (v = plt.attr[k]) === :match
        plt[_match_map[k]]
    else
        v
    end
Base.getindex(plt::Plot, i::Union{Vector{<:Integer},Integer}) = plt.subplots[i]
Base.getindex(plt::Plot, r::Integer, c::Integer) = plt.layout[r, c]
Base.setindex!(plt::Plot, v, k::Symbol)      = (plt.attr[k] = v)
Base.length(plt::Plot) = length(plt.subplots)
Base.lastindex(plt::Plot) = length(plt)
Base.get(plt::Plot, k::Symbol, v)      = get(plt.attr, k, v)

Base.size(plt::Plot) = size(plt.layout)
Base.size(plt::Plot, i::Integer) = size(plt.layout)[i]
Base.ndims(plt::Plot) = 2

# clear out series list, but retain subplots
Base.empty!(plt::Plot) = foreach(sp -> empty!(sp.series_list), plt.subplots)
Plots.get_subplot(plt::Plot, sp::Subplot) = sp
Plots.get_subplot(plt::Plot, i::Integer) = plt.subplots[i]
Plots.get_subplot(plt::Plot, k) = plt.spmap[k]
Plots.series_list(plt::Plot) = plt.series_list
get_subplot_index(plt::Plot, sp::Subplot) = findfirst(x -> x === sp, plt.subplots)
Plots.RecipesPipeline.preprocess_attributes!(plt::Plot, plotattributes::AKW) =
    Plots.preprocess_attributes!(plotattributes)

# update attr from an input dictionary
function _update_plot_args(plt::Plot, plotattributes_in::AKW)
    for (k, v) in Plots._plot_defaults
        Plots.slice_arg!(plotattributes_in, plt.attr, k, 1, true)
    end

    # handle colors
    plt[:background_color] = plot_color(plt.attr[:background_color])
    plt[:foreground_color] = fg_color(plt.attr)
    color_or_nothing!(plt.attr, :background_color_outside)
end

function _update_axis_links(plt::Plot, axis::Axis, letter::Symbol)
    # handle linking here.  if we're passed a list of
    # other subplots to link to, link them together
    (link = axis[:link]) |> isempty && return
    for other_sp in link
        link_axes!(axis, get_axis(get_subplot(plt, other_sp), letter))
    end
    axis.plotattributes[:link] = []
    nothing
end

function Plots._update_axis(
    plt::Plot,
    sp::Subplot,
    plotattributes_in::AKW,
    letter::Symbol,
    subplot_index::Int,
)
    # get (maybe initialize) the axis
    axis = get_axis(sp, letter)

    _update_axis(axis, plotattributes_in, letter, subplot_index)

    # convert a bool into auto or nothing
    if isa(axis[:ticks], Bool)
        axis[:ticks] = axis[:ticks] ? :auto : nothing
    end

    _update_axis_colors(axis)
    _update_axis_links(plt, axis, letter)
    nothing
end

# update a subplots args and axes
function _update_subplot_args(
    plt::Plot,
    sp::Subplot,
    plotattributes_in,
    subplot_index::Int,
    remove_pair::Bool,
)
    anns = RecipesPipeline.pop_kw!(sp.attr, :annotations)

    # grab those args which apply to this subplot
    for k in keys(_subplot_defaults)
        slice_arg!(plotattributes_in, sp.attr, k, subplot_index, remove_pair)
    end

    _update_subplot_colors(sp)
    _update_margins(sp)
    colorbar_update_keys =
        (:clims, :colorbar, :seriestype, :marker_z, :line_z, :fill_z, :colorbar_entry)
    if any(haskey.(Ref(plotattributes_in), colorbar_update_keys))
        _update_subplot_colorbars(sp)
    end

    lims_warned = false
    for letter in (:x, :y, :z)
        _update_axis(plt, sp, plotattributes_in, letter, subplot_index)
        lk = get_attr_symbol(letter, :lims)

        # warn against using `Range` in x,y,z lims
        if !lims_warned &&
           haskey(plotattributes_in, lk) &&
           plotattributes_in[lk] isa AbstractRange
            @warn "lims should be a Tuple, not $(typeof(plotattributes_in[lk]))."
            lims_warned = true
        end
    end

    _update_subplot_periphery(sp, anns)
end

function _update_series_attributes!(plotattributes::AKW, plt::Plot, sp::Subplot)
    pkg = plt.backend
    globalIndex = plotattributes[:series_plotindex]
    plotIndex = _series_index(plotattributes, sp)

    aliasesAndAutopick(
        plotattributes,
        :linestyle,
        _styleAliases,
        supported_styles(pkg),
        plotIndex,
    )
    aliasesAndAutopick(
        plotattributes,
        :markershape,
        _markerAliases,
        supported_markers(pkg),
        plotIndex,
    )

    # update alphas
    for asym in (:linealpha, :markeralpha, :fillalpha)
        if plotattributes[asym] === nothing
            plotattributes[asym] = plotattributes[:seriesalpha]
        end
    end
    if plotattributes[:markerstrokealpha] === nothing
        plotattributes[:markerstrokealpha] = plotattributes[:markeralpha]
    end

    # update series color
    scolor = plotattributes[:seriescolor]
    stype = plotattributes[:seriestype]
    plotattributes[:seriescolor] = scolor = get_series_color(scolor, sp, plotIndex, stype)

    # update other colors (`linecolor`, `markercolor`, `fillcolor`) <- for grep
    for s in (:line, :marker, :fill)
        csym, asym = Symbol(s, :color), Symbol(s, :alpha)
        plotattributes[csym] = if plotattributes[csym] === :auto
            plot_color(if has_black_border_for_default(stype) && s === :line
                sp[:foreground_color_subplot]
            else
                scolor
            end)
        elseif plotattributes[csym] === :match
            plot_color(scolor)
        else
            get_series_color(plotattributes[csym], sp, plotIndex, stype)
        end
    end

    # update markerstrokecolor
    plotattributes[:markerstrokecolor] = if plotattributes[:markerstrokecolor] === :match
        plot_color(sp[:foreground_color_subplot])
    elseif plotattributes[:markerstrokecolor] === :auto
        get_series_color(plotattributes[:markercolor], sp, plotIndex, stype)
    else
        get_series_color(plotattributes[:markerstrokecolor], sp, plotIndex, stype)
    end

    # if marker_z, fill_z or line_z are set, ensure we have a gradient
    if plotattributes[:marker_z] !== nothing
        ensure_gradient!(plotattributes, :markercolor, :markeralpha)
    end
    if plotattributes[:line_z] !== nothing
        ensure_gradient!(plotattributes, :linecolor, :linealpha)
    end
    if plotattributes[:fill_z] !== nothing
        ensure_gradient!(plotattributes, :fillcolor, :fillalpha)
    end

    # scatter plots don't have a line, but must have a shape
    if plotattributes[:seriestype] in (:scatter, :scatterbins, :scatterhist, :scatter3d)
        plotattributes[:linewidth] = 0
        if plotattributes[:markershape] === :none
            plotattributes[:markershape] = :circle
        end
    end

    # set label
    plotattributes[:label] = label_to_string.(plotattributes[:label], globalIndex)

    _replace_linewidth(plotattributes)
    plotattributes
end

function _slice_series_args!(plotattributes::AKW, plt::Plot, sp::Subplot, commandIndex::Int)
    for k in keys(_series_defaults)
        haskey(plotattributes, k) &&
            slice_arg!(plotattributes, plotattributes, k, commandIndex, false)
    end
    plotattributes
end
end # PlotsPlots
