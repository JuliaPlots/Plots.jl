
# create a new "build_series_args" which converts all inputs into xs = Any[xitems], ys = Any[yitems].
# Special handling for: no args, xmin/xmax, parametric, dataframes
# Then once inputs have been converted, build the series args, map functions, etc.
# This should cut down on boilerplate code and allow more focused dispatch on type
# note: returns meta information... mainly for use with automatic labeling from DataFrames for now

typealias FuncOrFuncs @compat(Union{Function, AVec{Function}})

all3D(d::KW) = trueOrAllTrue(lt -> lt in (:contour, :heatmap, :surface, :wireframe, :contour3d), get(d, :linetype, :none))

# missing
convertToAnyVector(v::@compat(Void), d::KW) = Any[nothing], nothing

# fixed number of blank series
convertToAnyVector(n::Integer, d::KW) = Any[zeros(0) for i in 1:n], nothing

# numeric vector
convertToAnyVector{T<:Number}(v::AVec{T}, d::KW) = Any[v], nothing

# string vector
convertToAnyVector{T<:@compat(AbstractString)}(v::AVec{T}, d::KW) = Any[v], nothing

# numeric matrix
function convertToAnyVector{T<:Number}(v::AMat{T}, d::KW)
    if all3D(d)
        Any[Surface(v)]
    else
        Any[v[:,i] for i in 1:size(v,2)]
    end, nothing
end

# other matrix... vector of columns
function convertToAnyVector(m::AMat, d::KW)
    Any[begin
        v = vec(m[:,i])
        length(v) == 1 ? v[1] : v
    end for i=1:size(m,2)], nothing
end

# function
convertToAnyVector(f::Function, d::KW) = Any[f], nothing

# surface
convertToAnyVector(s::Surface, d::KW) = Any[s], nothing

# vector of OHLC
convertToAnyVector(v::AVec{OHLC}, d::KW) = Any[v], nothing

# dates
convertToAnyVector{D<:Union{Date,DateTime}}(dts::AVec{D}, d::KW) = Any[dts], nothing

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


# --------------------------------------------------------------------

# TODO: can we avoid the copy here?  one error that crops up is that mapping functions over the same array
#       result in that array being shared.  push!, etc will add too many items to that array

compute_x(x::Void, y::Void, z)      = 1:size(z,1)
compute_x(x::Void, y, z)            = 1:size(y,1)
compute_x(x::Function, y, z)        = map(x, y)
compute_x(x, y, z)                  = copy(x)

# compute_y(x::Void, y::Function, z)  = error()
compute_y(x::Void, y::Void, z)      = 1:size(z,2)
compute_y(x, y::Function, z)        = map(y, x)
compute_y(x, y, z)                  = copy(y)

compute_z(x, y, z::Function)        = map(z, x, y)
compute_z(x, y, z::AbstractMatrix)  = Surface(z)
compute_z(x, y, z::Void)            = nothing
compute_z(x, y, z)                  = copy(z)

@noinline function compute_xyz(x, y, z)
    x = compute_x(x,y,z)
    y = compute_y(x,y,z)
    z = compute_z(x,y,z)
    x, y, z
end

# not allowed
compute_xyz(x::Void, y::FuncOrFuncs, z)       = error("If you want to plot the function `$y`, you need to define the x values!")
compute_xyz(x::Void, y::Void, z::FuncOrFuncs) = error("If you want to plot the function `$z`, you need to define x and y values!")
compute_xyz(x::Void, y::Void, z::Void)        = error("x/y/z are all nothing!")

# --------------------------------------------------------------------

# create n=max(mx,my) series arguments. the shorter list is cycled through
# note: everything should flow through this
function build_series_args(plt::AbstractPlot, kw::KW) #, idxfilter)
    x, y, z = map(sym -> pop!(kw, sym, nothing), (:x, :y, :z))
    if nothing == x == y == z
        return [], nothing, nothing
    end

    xs, xmeta = convertToAnyVector(x, kw)
    ys, ymeta = convertToAnyVector(y, kw)
    zs, zmeta = convertToAnyVector(z, kw)

    fr = pop!(kw, :fillrange, nothing)
    fillranges, _ = if typeof(fr) <: Number
        ([fr],nothing)
    else
        convertToAnyVector(fr, kw)
    end

    mx = length(xs)
    my = length(ys)
    mz = length(zs)
    ret = Any[]
    for i in 1:max(mx, my, mz)

        # try to set labels using ymeta
        d = copy(kw)
        if !haskey(d, :label) && ymeta != nothing
            if isa(ymeta, Symbol)
                d[:label] = string(ymeta)
            elseif isa(ymeta, AVec{Symbol})
                d[:label] = string(ymeta[mod1(i,length(ymeta))])
            end
        end

        # build the series arg dict
        numUncounted = pop!(d, :numUncounted, 0)
        commandIndex = i + numUncounted
        n = plt.n + i

        dumpdict(d, "before getSeriesArgs")
        d = getSeriesArgs(plt.backend, getplotargs(plt, n), d, commandIndex, convertSeriesIndex(plt, n), n)
        dumpdict(d, "after getSeriesArgs")

        d[:x], d[:y], d[:z] = compute_xyz(xs[mod1(i,mx)], ys[mod1(i,my)], zs[mod1(i,mz)])
        lt = d[:linetype]

        # for linetype `line`, need to sort by x values
        if lt == :line
            # order by x
            indices = sortperm(d[:x])
            d[:x] = d[:x][indices]
            d[:y] = d[:y][indices]
            d[:linetype] = :path
        end

        # special handling for missing x in box plot... all the same category
        if lt == :box && xs[mod1(i,mx)] == nothing
            d[:x] = ones(Int, length(d[:y]))
        end

        # map functions to vectors
        if isa(d[:marker_z], Function)
            d[:marker_z] = map(d[:marker_z], d[:x])
        end

        # @show fillranges
        d[:fillrange] = fillranges[mod1(i,length(fillranges))]
        if isa(d[:fillrange], Function)
            d[:fillrange] = map(d[:fillrange], d[:x])
        end

        # handle error bars
        for esym in (:xerror, :yerror)
            if get(d, esym, nothing) != nothing
                # we make a copy of the KW and apply an errorbar recipe
                append!(ret, apply_series_recipe(copy(d), Val{esym}))
            end
        end

        # handle ribbons
        if get(d, :ribbon, nothing) != nothing
            rib = d[:ribbon]
            d[:fillrange] = (d[:y] - rib, d[:y] + rib)
        end

        # handle quiver plots
        if lt == :quiver
            d[:linetype] = lt = :path
            d[:linewidth] = 0
        end
        if get(d, :quiver, nothing) != nothing
            append!(ret, apply_series_recipe(copy(d), Val{:quiver}))
        end



        # now that we've processed a given series... optionally split into
        # multiple dicts through a recipe (for example, a box plot is split into component
        # parts... polygons, lines, and scatters)
        # note: we pass in a Val type (i.e. Val{:box}) so that we can dispatch on the linetype
        kwlist = apply_series_recipe(d, Val{lt})
        append!(ret, kwlist)

        # # add it to our series list
        # push!(ret, d)
    end

    ret, xmeta, ymeta
end


# --------------------------------------------------------------------
# process_inputs
# --------------------------------------------------------------------

# These methods take a plot and the keyword arguments, and processes the input
# arguments (x/y/z, group, etc), populating the KW dict with appropriate values.

# --------------------------------------------------------------------
# 0 arguments
# --------------------------------------------------------------------

# don't do anything
function process_inputs(plt::AbstractPlot, d::KW)
end

# --------------------------------------------------------------------
# 1 argument
# --------------------------------------------------------------------

function process_inputs(plt::AbstractPlot, d::KW, n::Integer)
    # d[:x], d[:y], d[:z] = zeros(0), zeros(0), zeros(0)
    d[:x] = d[:y] = d[:z] = n
end

# no special handling... assume x and z are nothing
function process_inputs(plt::AbstractPlot, d::KW, y)
    d[:y] = y
end

# matrix... is it z or y?
function process_inputs{T<:Number}(plt::AbstractPlot, d::KW, mat::AMat{T})
    if all3D(d)
        n,m = size(mat)
        d[:x], d[:y], d[:z] = 1:n, 1:m, mat
    else
        d[:y] = mat
    end
end


# plotting arbitrary shapes/polygons
function process_inputs(plt::AbstractPlot, d::KW, shape::Shape)
    d[:x], d[:y] = shape_coords(shape)
    d[:linetype] = :shape
end
function process_inputs(plt::AbstractPlot, d::KW, shapes::AVec{Shape})
    d[:x], d[:y] = shape_coords(shapes)
    d[:linetype] = :shape
end
function process_inputs(plt::AbstractPlot, d::KW, shapes::AMat{Shape})
    x, y = [], []
    for j in 1:size(shapes, 2)
        tmpx, tmpy = shape_coords(vec(shapes[:,j]))
        push!(x, tmpx)
        push!(y, tmpy)
    end
    d[:x], d[:y] = x, y
    d[:linetype] = :shape
end


# function without range... use the current range of the x-axis
function process_inputs(plt::AbstractPlot, d::KW, f::FuncOrFuncs)
    process_inputs(plt, d, f, xmin(plt), xmax(plt))
end

# --------------------------------------------------------------------
# 2 arguments
# --------------------------------------------------------------------

function process_inputs(plt::AbstractPlot, d::KW, x, y)
    d[:x], d[:y] = x, y
end

# if functions come first, just swap the order (not to be confused with parametric functions...
# as there would be more than one function passed in)
function process_inputs(plt::AbstractPlot, d::KW, f::FuncOrFuncs, x)
    @assert !(typeof(x) <: FuncOrFuncs)  # otherwise we'd hit infinite recursion here
    process_inputs(plt, d, x, f)
end

# --------------------------------------------------------------------
# 3 arguments
# --------------------------------------------------------------------

# no special handling... just pass them through
function process_inputs(plt::AbstractPlot, d::KW, x, y, z)
    d[:x], d[:y], d[:z] = x, y, z
end

# 3d line or scatter
function process_inputs(plt::AbstractPlot, d::KW, x::AVec, y::AVec, zvec::AVec)
    # default to path3d if we haven't set a 3d linetype
    lt = get(d, :linetype, :none)
    if lt == :scatter
        d[:linetype] = :scatter3d
    elseif !(lt in _3dTypes)
        d[:linetype] = :path3d
    end
    d[:x], d[:y], d[:z] = x, y, zvec
end

# surface-like... function
function process_inputs{TX,TY}(plt::AbstractPlot, d::KW, x::AVec{TX}, y::AVec{TY}, zf::Function)
    x = TX <: Number ? sort(x) : x
    y = TY <: Number ? sort(y) : y
    # x, y = sort(x), sort(y)
    d[:z] = Surface(zf, x, y)  # TODO: replace with SurfaceFunction when supported
    d[:x], d[:y] = x, y
end

# surface-like... matrix grid
function process_inputs{TX,TY,TZ}(plt::AbstractPlot, d::KW, x::AVec{TX}, y::AVec{TY}, zmat::AMat{TZ})
    @assert size(zmat) == (length(x), length(y))
    if TX <: Number && !issorted(x)
        idx = sortperm(x)
        x, zmat = x[idx], zmat[idx, :]
    end
    if TY <: Number && !issorted(y)
        idx = sortperm(y)
        y, zmat = y[idx], zmat[:, idx]
    end
    d[:x], d[:y], d[:z] = x, y, Surface{Matrix{TZ}}(zmat)
    if !like_surface(get(d, :linetype, :none))
        d[:linetype] = :contour
    end
end

# surfaces-like... general x, y grid
function process_inputs{T<:Number}(plt::AbstractPlot, d::KW, x::AMat{T}, y::AMat{T}, zmat::AMat{T})
    @assert size(zmat) == size(x) == size(y)
    # d[:x], d[:y], d[:z] = Any[x], Any[y], Surface{Matrix{Float64}}(zmat)
    d[:x], d[:y], d[:z] = map(Surface{Matrix{Float64}}, (x, y, zmat))
    if !like_surface(get(d, :linetype, :none))
        d[:linetype] = :contour
    end
end


# --------------------------------------------------------------------
# Parametric functions
# --------------------------------------------------------------------

# special handling... xmin/xmax with function(s)
function process_inputs(plt::AbstractPlot, d::KW, f::FuncOrFuncs, xmin::Number, xmax::Number)
    width = get(plt.plotargs, :size, (100,))[1]
    x = linspace(xmin, xmax, width)
    process_inputs(plt, d, x, f)
end

# special handling... xmin/xmax with parametric function(s)
process_inputs{T<:Number}(plt::AbstractPlot, d::KW, fx::FuncOrFuncs, fy::FuncOrFuncs, u::AVec{T}) = process_inputs(plt, d, mapFuncOrFuncs(fx, u), mapFuncOrFuncs(fy, u))
process_inputs{T<:Number}(plt::AbstractPlot, d::KW, u::AVec{T}, fx::FuncOrFuncs, fy::FuncOrFuncs) = process_inputs(plt, d, mapFuncOrFuncs(fx, u), mapFuncOrFuncs(fy, u))
process_inputs(plt::AbstractPlot, d::KW, fx::FuncOrFuncs, fy::FuncOrFuncs, umin::Number, umax::Number, numPoints::Int = 1000) = process_inputs(plt, d, fx, fy, linspace(umin, umax, numPoints))

# special handling... 3D parametric function(s)
process_inputs{T<:Number}(plt::AbstractPlot, d::KW, fx::FuncOrFuncs, fy::FuncOrFuncs, fz::FuncOrFuncs, u::AVec{T}) = process_inputs(plt, d, mapFuncOrFuncs(fx, u), mapFuncOrFuncs(fy, u), mapFuncOrFuncs(fz, u))
process_inputs{T<:Number}(plt::AbstractPlot, d::KW, u::AVec{T}, fx::FuncOrFuncs, fy::FuncOrFuncs, fz::FuncOrFuncs) = process_inputs(plt, d, mapFuncOrFuncs(fx, u), mapFuncOrFuncs(fy, u), mapFuncOrFuncs(fz, u))
process_inputs(plt::AbstractPlot, d::KW, fx::FuncOrFuncs, fy::FuncOrFuncs, fz::FuncOrFuncs, umin::Number, umax::Number, numPoints::Int = 1000) = process_inputs(plt, d, fx, fy, fz, linspace(umin, umax, numPoints))


# --------------------------------------------------------------------
# Lists of tuples and FixedSizeArrays
# --------------------------------------------------------------------

# if we get an unhandled tuple, just splat it in
function process_inputs(plt::AbstractPlot, d::KW, tup::Tuple)
    process_inputs(plt, d, tup...)
end

# (x,y) tuples
function process_inputs{R1<:Number,R2<:Number}(plt::AbstractPlot, d::KW, xy::AVec{Tuple{R1,R2}})
    process_inputs(plt, d, unzip(xy)...)
end
function process_inputs{R1<:Number,R2<:Number}(plt::AbstractPlot, d::KW, xy::Tuple{R1,R2})
    process_inputs(plt, d, [xy[1]], [xy[2]])
end

# (x,y,z) tuples
function process_inputs{R1<:Number,R2<:Number,R3<:Number}(plt::AbstractPlot, d::KW, xyz::AVec{Tuple{R1,R2,R3}})
    process_inputs(plt, d, unzip(xyz)...)
end
function process_inputs{R1<:Number,R2<:Number,R3<:Number}(plt::AbstractPlot, d::KW, xyz::Tuple{R1,R2,R3})
    process_inputs(plt, d, [xyz[1]], [xyz[2]], [xyz[3]])
end

# 2D FixedSizeArrays
function process_inputs{T<:Number}(plt::AbstractPlot, d::KW, xy::AVec{FixedSizeArrays.Vec{2,T}})
    process_inputs(plt, d, unzip(xy)...)
end
function process_inputs{T<:Number}(plt::AbstractPlot, d::KW, xy::FixedSizeArrays.Vec{2,T})
    process_inputs(plt, d, [xy[1]], [xy[2]])
end

# 3D FixedSizeArrays
function process_inputs{T<:Number}(plt::AbstractPlot, d::KW, xyz::AVec{FixedSizeArrays.Vec{3,T}})
    process_inputs(plt, d, unzip(xyz)...)
end
function process_inputs{T<:Number}(plt::AbstractPlot, d::KW, xyz::FixedSizeArrays.Vec{3,T})
    process_inputs(plt, d, [xyz[1]], [xyz[2]], [xyz[3]])
end

# --------------------------------------------------------------------
# handle grouping
# --------------------------------------------------------------------

# function process_inputs(plt::AbstractPlot, d::KW, groupby::GroupBy, args...)
#     ret = Any[]
#     error("unfinished after series reorg")
#     for (i,glab) in enumerate(groupby.groupLabels)
#         # TODO: don't automatically overwrite labels
#         kwlist, xmeta, ymeta = process_inputs(plt, d, args...,
#                                             idxfilter = groupby.groupIds[i],
#                                             label = string(glab),
#                                             numUncounted = length(ret))  # we count the idx from plt.n + numUncounted + i
#         append!(ret, kwlist)
#     end
#     ret, nothing, nothing # TODO: handle passing meta through
# end

# --------------------------------------------------------------------
# For DataFrame support.  Imports DataFrames and defines the necessary methods which support them.
# --------------------------------------------------------------------

function setup_dataframes()
    @require DataFrames begin

        get_data(df::DataFrames.AbstractDataFrame, arg::Symbol) = df[arg]
        get_data(df::DataFrames.AbstractDataFrame, arg) = arg

        function process_inputs(plt::AbstractPlot, d::KW, df::DataFrames.AbstractDataFrame, args...)
            # d[:dataframe] = df
            process_inputs(plt, d, map(arg -> get_data(df, arg), args)...)
        end

        # expecting the column name of a dataframe that was passed in... anything else should error
        function extractGroupArgs(s::Symbol, df::DataFrames.AbstractDataFrame, args...)
            if haskey(df, s)
                return extractGroupArgs(df[s])
            else
                error("Got a symbol, and expected that to be a key in d[:dataframe]. s=$s d=$d")
            end
        end

        # function getDataFrameFromKW(d::KW)
        #     get(d, :dataframe) do
        #         error("Missing dataframe argument!")
        #     end
        # end

        # # the conversion functions for when we pass symbols or vectors of symbols to reference dataframes
        # convertToAnyVector(s::Symbol, d::KW) = Any[getDataFrameFromKW(d)[s]], s
        # convertToAnyVector(v::AVec{Symbol}, d::KW) = (df = getDataFrameFromKW(d); Any[df[s] for s in v]), v

    end
end
