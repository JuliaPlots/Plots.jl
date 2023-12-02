module PlotsPlots

export Plot, PlotOrSubplot, _update_plot_args, plottitlefont, ignorenan_extrema
import Plots.Axes: _update_axis, scale_lims!
import Plots.Commons: ignorenan_extrema
import Plots.Ticks: get_ticks
using Plots:
    Plots,
    AbstractPlot,
    AbstractBackend,
    DefaultsDict,
    Series,
    Axis,
    Subplot,
    AbstractLayout,
    RecipesPipeline
using Plots.Colorbars: _update_subplot_colorbars
using Plots.Subplots: _update_subplot_colors, _update_margins
using Plots.Axes: get_axis
using Plots.PlotUtils: get_color_palette
using Plots.Commons
using Plots.Commons.Frontend

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
# -------------------------------------------------------
# push/append for one series

Base.push!(plt::Plot, args::Real...) = push!(plt, 1, args...)
Base.push!(plt::Plot, i::Integer, args::Real...) = push!(plt.series_list[i], args...)
Base.append!(plt::Plot, args::AbstractVector) = append!(plt, 1, args...)
Base.append!(plt::Plot, i::Integer, args::Real...) = append!(plt.series_list[i], args...)

# tuples
Base.push!(plt::Plot, t::Tuple) = push!(plt, 1, t...)
Base.push!(plt::Plot, i::Integer, t::Tuple) = push!(plt, i, t...)
Base.append!(plt::Plot, t::Tuple) = append!(plt, 1, t...)
Base.append!(plt::Plot, i::Integer, t::Tuple) = append!(plt, i, t...)

# -------------------------------------------------------
# push/append for all series

# push y[i] to the ith series
function Base.push!(plt::Plot, y::AVec)
    ny = length(y)
    for i in 1:(plt.n)
        push!(plt, i, y[mod1(i, ny)])
    end
    plt
end

# push y[i] to the ith series
# same x for each series
Base.push!(plt::Plot, x::Real, y::AVec) = push!(plt, [x], y)

# push (x[i], y[i]) to the ith series
function Base.push!(plt::Plot, x::AVec, y::AVec)
    nx = length(x)
    ny = length(y)
    for i in 1:(plt.n)
        push!(plt, i, x[mod1(i, nx)], y[mod1(i, ny)])
    end
    plt
end

# push (x[i], y[i], z[i]) to the ith series
function Base.push!(plt::Plot, x::AVec, y::AVec, z::AVec)
    nx = length(x)
    ny = length(y)
    nz = length(z)
    for i in 1:(plt.n)
        push!(plt, i, x[mod1(i, nx)], y[mod1(i, ny)], z[mod1(i, nz)])
    end
    plt
end

# ---------------------------------------------------------------

"Smallest x in plot"
xmin(plt::Plot) = ignorenan_minimum([
    ignorenan_minimum(series.plotattributes[:x]) for series in plt.series_list
])
"Largest x in plot"
xmax(plt::Plot) = ignorenan_maximum([
    ignorenan_maximum(series.plotattributes[:x]) for series in plt.series_list
])

"Extrema of x-values in plot"
ignorenan_extrema(plt::Plot) = (xmin(plt), xmax(plt))

# ---------------------------------------------------------------
# indexing notation
# properly retrieve from plt.attr, passing `:match` to the correct key

Base.getindex(plt::Plot, k::Symbol) =
    if (v = plt.attr[k]) === :match
        plt[Commons._match_map[k]]
    else
        v
    end
Base.getindex(plt::Plot, i::Union{Vector{<:Integer},Integer}) = plt.subplots[i]
Base.getindex(plt::Plot, r::Integer, c::Integer) = plt.layout[r, c]
Base.setindex!(plt::Plot, xy::NTuple{2}, i::Integer) = (setxy!(plt, xy, i); plt)
Base.setindex!(plt::Plot, xyz::Tuple{3}, i::Integer) = (setxyz!(plt, xyz, i); plt)
Base.setindex!(plt::Plot, v, k::Symbol) = (plt.attr[k] = v)
Base.length(plt::Plot) = length(plt.subplots)
Base.lastindex(plt::Plot) = length(plt)
Base.get(plt::Plot, k::Symbol, v) = get(plt.attr, k, v)

Base.size(plt::Plot) = size(plt.layout)
Base.size(plt::Plot, i::Integer) = size(plt.layout)[i]
Base.ndims(plt::Plot) = 2

# clear out series list, but retain subplots
Base.empty!(plt::Plot) = foreach(sp -> empty!(sp.series_list), plt.subplots)
Plots.get_subplot(plt::Plot, sp::Subplot) = sp
Plots.get_subplot(plt::Plot, i::Integer) = plt.subplots[i]
Plots.get_subplot(plt::Plot, k) = plt.spmap[k]
Plots.series_list(plt::Plot) = plt.series_list

get_ticks(p::Plot, s::Symbol) = map(sp -> get_ticks(sp, s), p.subplots)

get_subplot_index(plt::Plot, sp::Subplot) = findfirst(x -> x === sp, plt.subplots)
Plots.RecipesPipeline.preprocess_attributes!(plt::Plot, plotattributes::AKW) =
    Commons.preprocess_attributes!(plotattributes)

plottitlefont(p::Plot) = font(;
    family = p[:plot_titlefontfamily],
    pointsize = p[:plot_titlefontsize],
    valign = p[:plot_titlefontvalign],
    halign = p[:plot_titlefonthalign],
    rotation = p[:plot_titlefontrotation],
    color = p[:plot_titlefontcolor],
)

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

function Plots.Axes._update_axis(
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

    Plots.Axes._update_axis_colors(axis)
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
        Plots.slice_arg!(plotattributes_in, sp.attr, k, subplot_index, remove_pair)
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

    Plots.Subplots._update_subplot_periphery(sp, anns)
end

function scale_lims!(plt::Plot, letter, factor)
    foreach(sp -> scale_lims!(sp, letter, factor), plt.subplots)
    plt
end
function scale_lims!(plt::Union{Plot,Subplot}, factor)
    foreach(letter -> scale_lims!(plt, letter, factor), (:x, :y, :z))
    plt
end
Commons.get_size(plt::Plot) = get_size(plt.attr)
Commons.get_thickness_scaling(plt::Plot) = get_thickness_scaling(plt.attr)
end # PlotsPlots
