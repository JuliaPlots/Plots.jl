
# TODO: I declare lots of types here because of the lacking ability to do forward declarations in current Julia
# I should move these to the relevant files when something like "extern" is implemented

const AVec = AbstractVector
const AMat = AbstractMatrix
const KW = Dict{Symbol,Any}
const AKW = AbstractDict{Symbol,Any}
const TicksArgs =
    Union{AVec{T},Tuple{AVec{T},AVec{S}},Symbol} where {T<:Real,S<:AbstractString}

struct PlotsDisplay <: AbstractDisplay end

struct InputWrapper{T}
    obj::T
end

mutable struct Series
    plotattributes::DefaultsDict
end

# a single subplot
mutable struct Subplot{T<:AbstractBackend} <: AbstractLayout
    parent::AbstractLayout
    series_list::Vector{Series}  # arguments for each series
    primary_series_count::Int # Number of primary series in the series list
    minpad::Tuple # leftpad, toppad, rightpad, bottompad
    bbox::BoundingBox  # the canvas area which is available to this subplot
    plotarea::BoundingBox  # the part where the data goes
    attr::DefaultsDict  # args specific to this subplot
    o  # can store backend-specific data... like a pyplot ax
    plt  # the enclosing Plot object (can't give it a type because of no forward declarations)

    Subplot(::T; parent = RootLayout()) where {T<:AbstractBackend} = new{T}(
        parent,
        Series[],
        0,
        DEFAULT_MINPAD[],
        DEFAULT_BBOX[],
        DEFAULT_BBOX[],
        DefaultsDict(KW(), _subplot_defaults),
        nothing,
        nothing,
    )
end

# simple wrapper around a KW so we can hold all attributes pertaining to the axis in one place
mutable struct Axis
    sps::Vector{Subplot}
    plotattributes::DefaultsDict
end

mutable struct Extrema
    emin::Float64
    emax::Float64
end

Extrema() = Extrema(Inf, -Inf)

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
        be = backend()
        new{typeof(be)}(
            be,
            0,
            DefaultsDict(KW(), _plot_defaults),
            Series[],
            nothing,
            Subplot[],
            SubplotMap(),
            EmptyLayout(),
            Subplot[],
            false,
        )
    end

    function Plot(osp::Subplot)
        plt = Plot()
        plt.layout = GridLayout(1, 1)
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
end

struct PlaceHolder end
const PlotOrSubplot = Union{Plot,Subplot}

# -----------------------------------------------------------

wrap(obj::T) where {T} = InputWrapper{T}(obj)
Base.isempty(wrapper::InputWrapper) = false

# -----------------------------------------------------------
attr(series::Series, k::Symbol) = series.plotattributes[k]
attr!(series::Series, v, k::Symbol) = (series.plotattributes[k] = v)

should_add_to_legend(series::Series) =
    series.plotattributes[:primary] &&
    series.plotattributes[:label] != "" &&
    series.plotattributes[:seriestype] ∉ (
        :hexbin,
        :bins2d,
        :histogram2d,
        :hline,
        :vline,
        :contour,
        :contourf,
        :contour3d,
        :surface,
        :wireframe,
        :heatmap,
        :image,
    )

# -----------------------------------------------------------------------
Base.iterate(plt::Plot) = iterate(plt.subplots)

Base.getindex(plt::Plot, i::Union{Vector{<:Integer},Integer}) = plt.subplots[i]
Base.length(plt::Plot) = length(plt.subplots)
Base.lastindex(plt::Plot) = length(plt)

Base.getindex(plt::Plot, r::Integer, c::Integer) = plt.layout[r, c]
Base.size(plt::Plot) = size(plt.layout)
Base.size(plt::Plot, i::Integer) = size(plt.layout)[i]
Base.ndims(plt::Plot) = 2

# clear out series list, but retain subplots
Base.empty!(plt::Plot) = foreach(sp -> empty!(sp.series_list), plt.subplots)

# attr(plt::Plot, k::Symbol) = plt.attr[k]
# attr!(plt::Plot, v, k::Symbol) = (plt.attr[k] = v)

Base.getindex(sp::Subplot, i::Union{Vector{<:Integer},Integer}) = series_list(sp)[i]
Base.lastindex(sp::Subplot) = length(series_list(sp))

Base.empty!(sp::Subplot) = empty!(sp.series_list)

# -----------------------------------------------------------------------

Base.show(io::IO, sp::Subplot) = print(io, "Subplot{$(sp[:subplot_index])}")

"""
    plotarea(subplot)

Return the bounding box of a subplot.
"""
plotarea(sp::Subplot) = sp.plotarea
plotarea!(sp::Subplot, bbox::BoundingBox) = (sp.plotarea = bbox)

Base.size(sp::Subplot) = (1, 1)
Base.length(sp::Subplot) = 1
Base.getindex(sp::Subplot, r::Int, c::Int) = sp

leftpad(sp::Subplot)   = sp.minpad[1]
toppad(sp::Subplot)    = sp.minpad[2]
rightpad(sp::Subplot)  = sp.minpad[3]
bottompad(sp::Subplot) = sp.minpad[4]

get_subplot(plt::Plot, sp::Subplot) = sp
get_subplot(plt::Plot, i::Integer) = plt.subplots[i]
get_subplot(plt::Plot, k) = plt.spmap[k]
get_subplot(series::Series) = series.plotattributes[:subplot]

get_subplot_index(plt::Plot, sp::Subplot) = findfirst(x -> x === sp, plt.subplots)

series_list(sp::Subplot) = sp.series_list # filter(series -> series.plotattributes[:subplot] === sp, sp.plt.series_list)
