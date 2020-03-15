# aliases
const AVec = AbstractVector
const AMat = AbstractMatrix

# ensure we dispatch to the slicer
struct SliceIt end

"Represents data values with formatting that should apply to the tick labels."
struct Formatted{T}
    data::T
    formatter::Function
end

abstract type AbstractSurface end

"represents a contour or surface mesh"
struct Surface{M<:AMat} <: AbstractSurface
  surf::M
end

Surface(f::Function, x, y) = Surface(Float64[f(xi,yi) for yi in y, xi in x])

Base.Array(surf::Surface) = surf.surf

for f in (:length, :size)
  @eval Base.$f(surf::Surface, args...) = $f(surf.surf, args...)
end
Base.copy(surf::Surface) = Surface(copy(surf.surf))
Base.eltype(surf::Surface{T}) where {T} = eltype(T)
# the catch-all recipes
RecipesBase.@recipe function f(::Type{SliceIt}, x, y, z)

    # handle data with formatting attached
    if typeof(x) <: Formatted
        xformatter := x.formatter
        x = x.data
    end
    if typeof(y) <: Formatted
        yformatter := y.formatter
        y = y.data
    end
    if typeof(z) <: Formatted
        zformatter := z.formatter
        z = z.data
    end

    xs = convertToAnyVector(x, plotattributes)
    ys = convertToAnyVector(y, plotattributes)
    zs = convertToAnyVector(z, plotattributes)


    fr = pop!(plotattributes, :fillrange, nothing)
    fillranges = process_fillrange(fr, plotattributes)
    mf = length(fillranges)

    rib = pop!(plotattributes, :ribbon, nothing)
    ribbons = process_ribbon(rib, plotattributes)
    mr = length(ribbons)

    # @show zs

    mx = length(xs)
    my = length(ys)
    mz = length(zs)
    if mx > 0 && my > 0 && mz > 0
        for i in 1:max(mx, my, mz)
            # add a new series
            di = copy(plotattributes)
            xi, yi, zi = xs[mod1(i,mx)], ys[mod1(i,my)], zs[mod1(i,mz)]
            di[:x], di[:y], di[:z] = compute_xyz(xi, yi, zi)

            # handle fillrange
            fr = fillranges[mod1(i,mf)]
            di[:fillrange] = isa(fr, Function) ? map(fr, di[:x]) : fr

            # handle ribbons
            rib = ribbons[mod1(i,mr)]
            di[:ribbon] = isa(rib, Function) ? map(rib, di[:x]) : rib

            push!(series_list, RecipeData(di, ()))
        end
    end
    nothing  # don't add a series for the main block
end

# this is the default "type recipe"... just pass the object through
RecipesBase.@recipe f(::Type{T}, v::T) where {T<:Any} = v

# this should catch unhandled "series recipes" and error with a nice message
RecipesBase.@recipe f(::Type{V}, x, y, z) where {V<:Val} = error("The backend must not support the series type $V, and there isn't a series recipe defined.")

# create a new "build_series_args" which converts all inputs into xs = Any[xitems], ys = Any[yitems].
# Special handling for: no args, xmin/xmax, parametric, dataframes
# Then once inputs have been converted, build the series args, map functions, etc.
# This should cut down on boilerplate code and allow more focused dispatch on type
# note: returns meta information... mainly for use with automatic labeling from DataFrames for now

const FuncOrFuncs{F} = Union{F, Vector{F}, Matrix{F}}
const MaybeNumber = Union{Number, Missing}
const MaybeString = Union{AbstractString, Missing}
const DataPoint = Union{MaybeNumber, MaybeString}

prepareSeriesData(x) = error("Cannot convert $(typeof(x)) to series data for plotting")
prepareSeriesData(::Nothing) = nothing
prepareSeriesData(t::Tuple{T, T}) where {T<:Number} = t
prepareSeriesData(f::Function) = f
prepareSeriesData(a::AbstractArray{<:MaybeNumber}) = replace!(
                                    x -> ismissing(x) || isinf(x) ? NaN : x,
                                    map(float,a))
prepareSeriesData(a::AbstractArray{<:MaybeString}) = replace(x -> ismissing(x) ? "" : x, a)
prepareSeriesData(s::Surface{<:AMat{<:MaybeNumber}}) = Surface(prepareSeriesData(s.surf))
prepareSeriesData(s::Surface) = s  # non-numeric Surface, such as an image
prepareSeriesData(v::Volume) = Volume(prepareSeriesData(v.v), v.x_extents, v.y_extents, v.z_extents)

# default: assume x represents a single series
convertToAnyVector(x, plotattributes) = Any[prepareSeriesData(x)]

# fixed number of blank series
convertToAnyVector(n::Integer, plotattributes) = Any[zeros(0) for i in 1:n]

# vector of data points is a single series
convertToAnyVector(v::AVec{<:DataPoint}, plotattributes) = Any[prepareSeriesData(v)]

# list of things (maybe other vectors, functions, or something else)
function convertToAnyVector(v::AVec, plotattributes)
    if all(x -> x isa MaybeNumber, v)
        convertToAnyVector(Vector{MaybeNumber}(v), plotattributes)
    elseif all(x -> x isa MaybeString, v)
        convertToAnyVector(Vector{MaybeString}(v), plotattributes)
    else
        vcat((convertToAnyVector(vi, plotattributes) for vi in v)...)
    end
end

# Matrix is split into columns
function convertToAnyVector(v::AMat{<:DataPoint}, plotattributes)
    if all3D(plotattributes)
        Any[prepareSeriesData(Surface(v))]
    else
        Any[prepareSeriesData(v[:, i]) for i in axes(v, 2)]
    end
end

# --------------------------------------------------------------------
# Fillranges & ribbons


process_fillrange(range::Number, plotattributes) = [range]
process_fillrange(range, plotattributes) = convertToAnyVector(range, plotattributes)

process_ribbon(ribbon::Number, plotattributes) = [ribbon]
process_ribbon(ribbon, plotattributes) = convertToAnyVector(ribbon, plotattributes)
# ribbon as a tuple: (lower_ribbons, upper_ribbons)
process_ribbon(ribbon::Tuple{Any,Any}, plotattributes) = collect(zip(convertToAnyVector(ribbon[1], plotattributes),
                                                     convertToAnyVector(ribbon[2], plotattributes)))


all3D(plotattributes) = trueOrAllTrue(st -> st in (:contour, :contourf, :heatmap, :surface, :wireframe, :contour3d, :image, :plots_heatmap), get(plotattributes, :seriestype, :none))

trueOrAllTrue(f::Function, x::AbstractArray) = all(f, x)
trueOrAllTrue(f::Function, x) = f(x)
