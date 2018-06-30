
# create a new "build_series_args" which converts all inputs into xs = Any[xitems], ys = Any[yitems].
# Special handling for: no args, xmin/xmax, parametric, dataframes
# Then once inputs have been converted, build the series args, map functions, etc.
# This should cut down on boilerplate code and allow more focused dispatch on type
# note: returns meta information... mainly for use with automatic labeling from DataFrames for now

const FuncOrFuncs = Union{Function, AVec{Function}}

all3D(d::KW) = trueOrAllTrue(st -> st in (:contour, :contourf, :heatmap, :surface, :wireframe, :contour3d, :image), get(d, :seriestype, :none))

# missing
convertToAnyVector(v::Nothing, d::KW) = Any[nothing], nothing

# fixed number of blank series
convertToAnyVector(n::Integer, d::KW) = Any[zeros(0) for i in 1:n], nothing

# numeric vector
convertToAnyVector(v::AVec{T}, d::KW) where {T<:Number} = Any[v], nothing

# string vector
convertToAnyVector(v::AVec{T}, d::KW) where {T<:AbstractString} = Any[v], nothing

function convertToAnyVector(v::AMat, d::KW)
    if all3D(d)
        Any[Surface(v)]
    else
        Any[v[:,i] for i in 1:size(v,2)]
    end, nothing
end

# function
convertToAnyVector(f::Function, d::KW) = Any[f], nothing

# surface
convertToAnyVector(s::Surface, d::KW) = Any[s], nothing

# # vector of OHLC
# convertToAnyVector(v::AVec{OHLC}, d::KW) = Any[v], nothing

# dates
convertToAnyVector(dts::AVec{D}, d::KW) where {D<:Union{Date,DateTime}} = Any[dts], nothing

# list of things (maybe other vectors, functions, or something else)
function convertToAnyVector(v::AVec, d::KW)
    if all(x -> typeof(x) <: Number, v)
        # all real numbers wrap the whole vector as one item
        Any[convert(Vector{Float64}, v)], nothing
    else
        # something else... treat each element as an item
        vcat(Any[convertToAnyVector(vi, d)[1] for vi in v]...), nothing
        # Any[vi for vi in v], nothing
    end
end

convertToAnyVector(t::Tuple, d::KW) = Any[t], nothing


function convertToAnyVector(args...)
    error("In convertToAnyVector, could not handle the argument types: $(map(typeof, args[1:end-1]))")
end

# --------------------------------------------------------------------

# TODO: can we avoid the copy here?  one error that crops up is that mapping functions over the same array
#       result in that array being shared.  push!, etc will add too many items to that array

compute_x(x::Nothing, y::Nothing, z)      = 1:size(z,1)
compute_x(x::Nothing, y, z)            = 1:size(y,1)
compute_x(x::Function, y, z)        = map(x, y)
compute_x(x, y, z)                  = copy(x)

# compute_y(x::Void, y::Function, z)  = error()
compute_y(x::Nothing, y::Nothing, z)      = 1:size(z,2)
compute_y(x, y::Function, z)        = map(y, x)
compute_y(x, y, z)                  = copy(y)

compute_z(x, y, z::Function)        = map(z, x, y)
compute_z(x, y, z::AbstractMatrix)  = Surface(z)
compute_z(x, y, z::Nothing)            = nothing
compute_z(x, y, z)                  = copy(z)

nobigs(v::AVec{BigFloat}) = map(Float64, v)
nobigs(v::AVec{BigInt}) = map(Int64, v)
nobigs(v) = v

@noinline function compute_xyz(x, y, z)
    x = compute_x(x,y,z)
    y = compute_y(x,y,z)
    z = compute_z(x,y,z)
    nobigs(x), nobigs(y), nobigs(z)
end

# not allowed
compute_xyz(x::Nothing, y::FuncOrFuncs, z)       = error("If you want to plot the function `$y`, you need to define the x values!")
compute_xyz(x::Nothing, y::Nothing, z::FuncOrFuncs) = error("If you want to plot the function `$z`, you need to define x and y values!")
compute_xyz(x::Nothing, y::Nothing, z::Nothing)        = error("x/y/z are all nothing!")

# --------------------------------------------------------------------
