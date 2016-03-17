
# create a new "build_series_args" which converts all inputs into xs = Any[xitems], ys = Any[yitems].
# Special handling for: no args, xmin/xmax, parametric, dataframes
# Then once inputs have been converted, build the series args, map functions, etc.
# This should cut down on boilerplate code and allow more focused dispatch on type
# note: returns meta information... mainly for use with automatic labeling from DataFrames for now

typealias FuncOrFuncs @compat(Union{Function, AVec{Function}})

all3D(d::Dict) = trueOrAllTrue(lt -> lt in (:contour, :heatmap, :surface, :wireframe), get(d, :linetype, :none))

# missing
convertToAnyVector(v::@compat(Void), d::Dict) = Any[nothing], nothing

# fixed number of blank series
convertToAnyVector(n::Integer, d::Dict) = Any[zeros(0) for i in 1:n], nothing

# numeric vector
convertToAnyVector{T<:Real}(v::AVec{T}, d::Dict) = Any[v], nothing

# string vector
convertToAnyVector{T<:@compat(AbstractString)}(v::AVec{T}, d::Dict) = Any[v], nothing

# numeric matrix
function convertToAnyVector{T<:Real}(v::AMat{T}, d::Dict)
    if all3D(d)
        Any[Surface(v)]
    else
        Any[v[:,i] for i in 1:size(v,2)]
    end, nothing
end

# function
convertToAnyVector(f::Function, d::Dict) = Any[f], nothing

# surface
convertToAnyVector(s::Surface, d::Dict) = Any[s], nothing

# vector of OHLC
convertToAnyVector(v::AVec{OHLC}, d::Dict) = Any[v], nothing

# dates
convertToAnyVector{D<:Union{Date,DateTime}}(dts::AVec{D}, d::Dict) = Any[dts], nothing

# list of things (maybe other vectors, functions, or something else)
function convertToAnyVector(v::AVec, d::Dict)
    if all(x -> typeof(x) <: Real, v)
        # all real numbers wrap the whole vector as one item
        Any[convert(Vector{Float64}, v)], nothing
    else
        # something else... treat each element as an item
        vcat(Any[convertToAnyVector(vi, d)[1] for vi in v]...), nothing
        # Any[vi for vi in v], nothing
    end
end


# --------------------------------------------------------------------

# in computeXandY, we take in any of the possible items, convert into proper x/y vectors, then return.
# this is also where all the "set x to 1:length(y)" happens, and also where we assert on lengths.
computeX(x::@compat(Void), y) = 1:size(y,1)
computeX(x, y) = copy(x)
computeY(x, y::Function) = map(y, x)
computeY(x, y) = copy(y)
function computeXandY(x, y)
    if x == nothing && isa(y, Function)
        error("If you want to plot the function `$y`, you need to define the x values somehow!")
    end
    x, y = computeX(x,y), computeY(x,y)
    # @assert length(x) == length(y)
    x, y
end


# --------------------------------------------------------------------

# create n=max(mx,my) series arguments. the shorter list is cycled through
# note: everything should flow through this
function build_series_args(plt::AbstractPlot, x, y; kw...)
    kwdict = Dict(kw)
    xs, xmeta = convertToAnyVector(x, kwdict)
    ys, ymeta = convertToAnyVector(y, kwdict)

    mx = length(xs)
    my = length(ys)
    ret = Any[]
    for i in 1:max(mx, my)

        # try to set labels using ymeta
        d = copy(kwdict)
        if !haskey(d, :label) && ymeta != nothing
            if isa(ymeta, Symbol)
                d[:label] = string(ymeta)
            elseif isa(ymeta, AVec{Symbol})
                d[:label] = string(ymeta[mod1(i,length(ymeta))])
            end
        end

        # build the series arg dict
        numUncounted = get(d, :numUncounted, 0)
        n = plt.n + i + numUncounted
        dumpdict(d, "before getSeriesArgs")
        d = getSeriesArgs(plt.backend, getplotargs(plt, n), d, i + numUncounted, convertSeriesIndex(plt, n), n)
        dumpdict(d, "after getSeriesArgs")
        d[:x], d[:y] = computeXandY(xs[mod1(i,mx)], ys[mod1(i,my)])

        lt = d[:linetype]
        if isa(d[:y], Surface)
            if lt in (:contour, :heatmap, :surface, :wireframe)
                z = d[:y]
                d[:y] = 1:size(z,2)
                d[:z] = z
            end
        end

        if haskey(d, :idxfilter)
            d[:x] = d[:x][d[:idxfilter]]
            d[:y] = d[:y][d[:idxfilter]]
        end

        # for linetype `line`, need to sort by x values
        if lt == :line
            # order by x
            indices = sortperm(d[:x])
            d[:x] = d[:x][indices]
            d[:y] = d[:y][indices]
            d[:linetype] = :path
        end

        # map functions to vectors
        if isa(d[:zcolor], Function)
            d[:zcolor] = map(d[:zcolor], d[:x])
        end
        if isa(d[:fillrange], Function)
            d[:fillrange] = map(d[:fillrange], d[:x])
        end

        # cleanup those fields that were used only for generating kw args
        for k in (:idxfilter, :numUncounted, :dataframe)
            delete!(d, k)
        end

        # add it to our series list
        push!(ret, d)
    end

    ret, xmeta, ymeta
end

# handle grouping
function build_series_args(plt::AbstractPlot, groupby::GroupBy, args...; kw...)
    ret = Any[]
    for (i,glab) in enumerate(groupby.groupLabels)
        # TODO: don't automatically overwrite labels
        kwlist, xmeta, ymeta = build_series_args(plt, args...; kw...,
                                            idxfilter = groupby.groupIds[i],
                                            label = string(glab),
                                            numUncounted = length(ret))  # we count the idx from plt.n + numUncounted + i
        append!(ret, kwlist)
    end
    ret, nothing, nothing # TODO: handle passing meta through
end

# pass it off to the x/y version
function build_series_args(plt::AbstractPlot, y; kw...)
    build_series_args(plt, nothing, y; kw...)
end

# 3d line or scatter
function build_series_args(plt::AbstractPlot, x::AVec, y::AVec, zvec::AVec; kw...)
    d = Dict(kw)
    if !(get(d, :linetype, :none) in _3dTypes)
        d[:linetype] = :path3d
    end
    build_series_args(plt, x, y; z=zvec, d...)
end

function build_series_args{T<:Real}(plt::AbstractPlot, z::AMat{T}; kw...)
    d = Dict(kw)
    if all3D(d)
    n,m = size(z)
        build_series_args(plt, 1:n, 1:m, z; kw...)
    else
        build_series_args(plt, nothing, z; kw...)
    end
end

# contours or surfaces... function grid
function build_series_args(plt::AbstractPlot, x::AVec, y::AVec, zf::Function; kw...)
    # only allow sorted x/y for now
    # TODO: auto sort x/y/z properly
    @assert x == sort(x)
    @assert y == sort(y)
    surface = Float64[zf(xi, yi) for xi in x, yi in y]
    build_series_args(plt, x, y, surface; kw...)  # passes it to the zmat version
end

# contours or surfaces... matrix grid
function build_series_args{T<:Real}(plt::AbstractPlot, x::AVec, y::AVec, zmat::AMat{T}; kw...)
    # only allow sorted x/y for now
    # TODO: auto sort x/y/z properly
    @assert x == sort(x)
    @assert y == sort(y)
    @assert size(zmat) == (length(x), length(y))
    # surf = Surface(convert(Matrix{Float64}, zmat))
    # surf = Array(Any,1,1)
    # surf[1,1] = convert(Matrix{Float64}, zmat)
    d = Dict(kw)
    d[:z] = Surface(convert(Matrix{Float64}, zmat))
    if !(get(d, :linetype, :none) in (:contour, :heatmap, :surface, :wireframe))
        d[:linetype] = :contour
    end
    build_series_args(plt, x, y; d...) #, z = surf)
end

# contours or surfaces... general x, y grid
function build_series_args{T<:Real}(plt::AbstractPlot, x::AMat{T}, y::AMat{T}, zmat::AMat{T}; kw...)
    @assert size(zmat) == size(x) == size(y)
    surf = Surface(convert(Matrix{Float64}, zmat))
    # surf = Array(Any,1,1)
    # surf[1,1] = convert(Matrix{Float64}, zmat)
    d = Dict(kw)
    d[:z] = Surface(convert(Matrix{Float64}, zmat))
    if !(get(d, :linetype, :none) in (:contour, :heatmap, :surface, :wireframe))
        d[:linetype] = :contour
    end
    build_series_args(plt, Any[x], Any[y]; d...) #kw..., z = surf, linetype = :contour)
end

# plotting arbitrary shapes/polygons
function build_series_args(plt::AbstractPlot, shape::Shape; kw...)
    x, y = unzip(shape.vertices)
    build_series_args(plt, x, y; linetype = :shape, kw...)
end

function shape_coords(shapes::AVec{Shape})
    xs = map(get_xs, shapes)
    ys = map(get_ys, shapes)
    x, y = unzip(shapes[1].vertices)
    for shape in shapes[2:end]
        tmpx, tmpy = unzip(shape.vertices)
        x = vcat(x, NaN, tmpx)
        y = vcat(y, NaN, tmpy)
    end
    x, y
end

function build_series_args(plt::AbstractPlot, shapes::AVec{Shape}; kw...)
    x, y = shape_coords(shapes)
    build_series_args(plt, x, y; linetype = :shape, kw...)
end
function build_series_args(plt::AbstractPlot, shapes::AMat{Shape}; kw...)
    x, y = [], []
    for j in 1:size(shapes, 2)
        tmpx, tmpy = shape_coords(vec(shapes[:,j]))
        push!(x, tmpx)
        push!(y, tmpy)
    end
    build_series_args(plt, x, y; linetype = :shape, kw...)
end

function build_series_args(plt::AbstractPlot, surf::Surface; kw...)
    build_series_args(plt, 1:size(surf.surf,1), 1:size(surf.surf,2), convert(Matrix{Float64}, surf.surf); kw...)
end

function build_series_args(plt::AbstractPlot, x::AVec, y::AVec, surf::Surface; kw...)
    build_series_args(plt, x, y, convert(Matrix{Float64}, surf.surf); kw...)
end

function build_series_args(plt::AbstractPlot, f::FuncOrFuncs; kw...)
    build_series_args(plt, f, xmin(plt), xmax(plt); kw...)
end

# list of functions
function build_series_args(plt::AbstractPlot, f::FuncOrFuncs, x; kw...)
    @assert !(typeof(x) <: FuncOrFuncs)  # otherwise we'd hit infinite recursion here
    build_series_args(plt, x, f; kw...)
end

# special handling... xmin/xmax with function(s)
function build_series_args(plt::AbstractPlot, f::FuncOrFuncs, xmin::Real, xmax::Real; kw...)
    width = get(plt.plotargs, :size, (100,))[1]
    x = collect(linspace(xmin, xmax, width))  # we don't need more than the width
    build_series_args(plt, x, f; kw...)
end

mapFuncOrFuncs(f::Function, u::AVec) = map(f, u)
mapFuncOrFuncs(fs::AVec{Function}, u::AVec) = [map(f, u) for f in fs]

# special handling... xmin/xmax with parametric function(s)
build_series_args{T<:Real}(plt::AbstractPlot, fx::FuncOrFuncs, fy::FuncOrFuncs, u::AVec{T}; kw...) = build_series_args(plt, mapFuncOrFuncs(fx, u), mapFuncOrFuncs(fy, u); kw...)
build_series_args{T<:Real}(plt::AbstractPlot, u::AVec{T}, fx::FuncOrFuncs, fy::FuncOrFuncs; kw...) = build_series_args(plt, mapFuncOrFuncs(fx, u), mapFuncOrFuncs(fy, u); kw...)
build_series_args(plt::AbstractPlot, fx::FuncOrFuncs, fy::FuncOrFuncs, umin::Real, umax::Real, numPoints::Int = 1000; kw...) = build_series_args(plt, fx, fy, linspace(umin, umax, numPoints); kw...)

# special handling... 3D parametric function(s)
build_series_args{T<:Real}(plt::AbstractPlot, fx::FuncOrFuncs, fy::FuncOrFuncs, fz::FuncOrFuncs, u::AVec{T}; kw...) = build_series_args(plt, mapFuncOrFuncs(fx, u), mapFuncOrFuncs(fy, u), mapFuncOrFuncs(fz, u); kw...)
build_series_args{T<:Real}(plt::AbstractPlot, u::AVec{T}, fx::FuncOrFuncs, fy::FuncOrFuncs, fz::FuncOrFuncs; kw...) = build_series_args(plt, mapFuncOrFuncs(fx, u), mapFuncOrFuncs(fy, u), mapFuncOrFuncs(fz, u); kw...)
build_series_args(plt::AbstractPlot, fx::FuncOrFuncs, fy::FuncOrFuncs, fz::FuncOrFuncs, umin::Real, umax::Real, numPoints::Int = 1000; kw...) = build_series_args(plt, fx, fy, fz, linspace(umin, umax, numPoints); kw...)

# (x,y) tuples
function build_series_args{R1<:Real,R2<:Real}(plt::AbstractPlot, xy::AVec{Tuple{R1,R2}}; kw...)
    build_series_args(plt, unzip(xy)...; kw...)
end
function build_series_args{R1<:Real,R2<:Real}(plt::AbstractPlot, xy::Tuple{R1,R2}; kw...)
    build_series_args(plt, [xy[1]], [xy[2]]; kw...)
end



# special handling... no args... 1 series
function build_series_args(plt::AbstractPlot; kw...)
    d = Dict(kw)
    if !haskey(d, :y)
        # assume we just want to create an empty plot object which can be added to later
        return [], nothing, nothing
        # error("Called plot/subplot without args... must set y in the keyword args.  Example: plot(; y=rand(10))")
    end

    if haskey(d, :x)
        return build_series_args(plt, d[:x], d[:y]; kw...)
    else
        return build_series_args(plt, d[:y]; kw...)
    end
end

# --------------------------------------------------------------------

unzip{T}(x::AVec{FixedSizeArrays.Vec{2,T}}) = T[xi[1] for xi in x], T[xi[2] for xi in x]
unzip{T}(x::FixedSizeArrays.Vec{2,T}) = T[x[1]], T[x[2]]

function build_series_args{T<:Real}(plt::AbstractPlot, xy::AVec{FixedSizeArrays.Vec{2,T}}; kw...)
    build_series_args(plt, unzip(xy)...; kw...)
end

function build_series_args{T<:Real}(plt::AbstractPlot, xy::FixedSizeArrays.Vec{2,T}; kw...)
    build_series_args(plt, [xy[1]], [xy[2]]; kw...)
end

# --------------------------------------------------------------------

# For DataFrame support.  Imports DataFrames and defines the necessary methods which support them.

function setup_dataframes()
    @require DataFrames begin

        function build_series_args(plt::AbstractPlot, df::DataFrames.AbstractDataFrame, args...; kw...)
            build_series_args(plt, args...; kw..., dataframe = df)
        end

        # expecting the column name of a dataframe that was passed in... anything else should error
        function extractGroupArgs(s::Symbol, df::DataFrames.AbstractDataFrame, args...)
            if haskey(df, s)
                return extractGroupArgs(df[s])
            else
                error("Got a symbol, and expected that to be a key in d[:dataframe]. s=$s d=$d")
            end
        end

        function getDataFrameFromKW(d::Dict)
            get(d, :dataframe) do
                error("Missing dataframe argument!")
            end
        end

        # the conversion functions for when we pass symbols or vectors of symbols to reference dataframes
        convertToAnyVector(s::Symbol, d::Dict) = Any[getDataFrameFromKW(d)[s]], s
        convertToAnyVector(v::AVec{Symbol}, d::Dict) = (df = getDataFrameFromKW(d); Any[df[s] for s in v]), v

    end
end
