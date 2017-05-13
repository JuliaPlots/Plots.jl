

# create a new "build_series_args" which converts all inputs into xs = Any[xitems], ys = Any[yitems].
# Special handling for: no args, xmin/xmax, parametric, dataframes
# Then once inputs have been converted, build the series args, map functions, etc.
# This should cut down on boilerplate code and allow more focused dispatch on type
# note: returns meta information... mainly for use with automatic labeling from DataFrames for now

const FuncOrFuncs{F} = Union{F, Vector{F}, Matrix{F}}

all3D(d::KW) = trueOrAllTrue(st -> st in (:contour, :contourf, :heatmap, :surface, :wireframe, :contour3d, :image), get(d, :seriestype, :none))

# missing
convertToAnyVector(v::Void, d::KW) = Any[nothing], nothing

# fixed number of blank series
convertToAnyVector(n::Integer, d::KW) = Any[zeros(0) for i in 1:n], nothing

# numeric vector
convertToAnyVector{T<:Number}(v::AVec{T}, d::KW) = Any[v], nothing

# string vector
convertToAnyVector{T<:AbstractString}(v::AVec{T}, d::KW) = Any[v], nothing

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

# volume
convertToAnyVector(v::Volume, d::KW) = Any[v], nothing

# # vector of OHLC
# convertToAnyVector(v::AVec{OHLC}, d::KW) = Any[v], nothing

# # dates
# convertToAnyVector{D<:Union{Date,DateTime}}(dts::AVec{D}, d::KW) = Any[dts], nothing

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
compute_xyz{F<:Function}(x::Void, y::FuncOrFuncs{F}, z)       = error("If you want to plot the function `$y`, you need to define the x values!")
compute_xyz{F<:Function}(x::Void, y::Void, z::FuncOrFuncs{F}) = error("If you want to plot the function `$z`, you need to define x and y values!")
compute_xyz(x::Void, y::Void, z::Void)        = error("x/y/z are all nothing!")

# --------------------------------------------------------------------


# we are going to build recipes to do the processing and splitting of the args

# ensure we dispatch to the slicer
immutable SliceIt end

# the catch-all recipes
@recipe function f(::Type{SliceIt}, x, y, z)

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

    xs, _ = convertToAnyVector(x, d)
    ys, _ = convertToAnyVector(y, d)
    zs, _ = convertToAnyVector(z, d)

    fr = pop!(d, :fillrange, nothing)
    fillranges, _ = if typeof(fr) <: Number
        ([fr],nothing)
    else
        convertToAnyVector(fr, d)
    end
    mf = length(fillranges)

    # @show zs

    mx = length(xs)
    my = length(ys)
    mz = length(zs)
    if mx > 0 && my > 0 && mz > 0
        for i in 1:max(mx, my, mz)
            # add a new series
            di = copy(d)
            xi, yi, zi = xs[mod1(i,mx)], ys[mod1(i,my)], zs[mod1(i,mz)]
            di[:x], di[:y], di[:z] = compute_xyz(xi, yi, zi)

            # handle fillrange
            fr = fillranges[mod1(i,mf)]
            di[:fillrange] = isa(fr, Function) ? map(fr, di[:x]) : fr

            push!(series_list, RecipeData(di, ()))
        end
    end
    nothing  # don't add a series for the main block
end

# this is the default "type recipe"... just pass the object through
@recipe f{T<:Any}(::Type{T}, v::T) = v

# this should catch unhandled "series recipes" and error with a nice message
@recipe f{V<:Val}(::Type{V}, x, y, z) = error("The backend must not support the series type $V, and there isn't a series recipe defined.")

_apply_type_recipe(d, v) = RecipesBase.apply_recipe(d, typeof(v), v)[1].args[1]

# Handle type recipes when the recipe is defined on the elements.
# This sort of recipe should return a pair of functions... one to convert to number,
# and one to format tick values.
function _apply_type_recipe(d, v::AbstractArray)
    args = RecipesBase.apply_recipe(d, typeof(v[1]), v[1])[1].args
    if length(args) == 2 && typeof(args[1]) <: Function && typeof(args[2]) <: Function
        numfunc, formatter = args
        Formatted(map(numfunc, v), formatter)
    else
        v
    end
end

# # special handling for Surface... need to properly unwrap and re-wrap
# function _apply_type_recipe(d, v::Surface)
#     T = eltype(v.surf)
#     @show T
#     if T <: Integer || T <: AbstractFloat
#         v
#     else
#         ret = _apply_type_recipe(d, v.surf)
#         if typeof(ret) <: Formatted
#             Formatted(Surface(ret.data), ret.formatter)
#         else
#             v
#         end
#     end
# end

# don't do anything for ints or floats
_apply_type_recipe{T<:Union{Integer,AbstractFloat}}(d, v::AbstractArray{T}) = v

# handle "type recipes" by converting inputs, and then either re-calling or slicing
@recipe function f(x, y, z)
    did_replace = false
    newx = _apply_type_recipe(d, x)
    x === newx || (did_replace = true)
    newy = _apply_type_recipe(d, y)
    y === newy || (did_replace = true)
    newz = _apply_type_recipe(d, z)
    z === newz || (did_replace = true)
    if did_replace
        newx, newy, newz
    else
        SliceIt, x, y, z
    end
end
@recipe function f(x, y)
    did_replace = false
    newx = _apply_type_recipe(d, x)
    x === newx || (did_replace = true)
    newy = _apply_type_recipe(d, y)
    y === newy || (did_replace = true)
    if did_replace
        newx, newy
    else
        SliceIt, x, y, nothing
    end
end
@recipe function f(y)
    newy = _apply_type_recipe(d, y)
    if y !== newy
        newy
    else
        SliceIt, nothing, y, nothing
    end
end

# if there's more than 3 inputs, it can't be passed directly to SliceIt
# so we'll apply_type_recipe to all of them
@recipe function f(v1, v2, v3, v4, vrest...)
    did_replace = false
    newargs = map(v -> begin
        newv = _apply_type_recipe(d, v)
        if newv !== v
            did_replace = true
        end
        newv
    end, (v1, v2, v3, v4, vrest...))
    if !did_replace
        error("Couldn't process recipe args: $(map(typeof, (v1, v2, v3, v4, vrest...)))")
    end
    newargs
end


# # --------------------------------------------------------------------
# # 1 argument
# # --------------------------------------------------------------------

# helper function to ensure relevant attributes are wrapped by Surface
function wrap_surfaces(d::KW)
    if haskey(d, :fill_z)
        v = d[:fill_z]
        if !isa(v, Surface)
            d[:fill_z] = Surface(v)
        end
    end
end

@recipe f(n::Integer) = is3d(get(d,:seriestype,:path)) ? (SliceIt, n, n, n) : (SliceIt, n, n, nothing)

# return a surface if this is a 3d plot, otherwise let it be sliced up
@recipe function f{T<:Union{Integer,AbstractFloat}}(mat::AMat{T})
    if all3D(d)
        n,m = size(mat)
        wrap_surfaces(d)
        SliceIt, 1:m, 1:n, Surface(mat)
    else
        SliceIt, nothing, mat, nothing
    end
end

# if a matrix is wrapped by Formatted, do similar logic, but wrap data with Surface
@recipe function f{T<:AbstractMatrix}(fmt::Formatted{T})
    if all3D(d)
        mat = fmt.data
        n,m = size(mat)
        wrap_surfaces(d)
        SliceIt, 1:m, 1:n, Formatted(Surface(mat), fmt.formatter)
    else
        SliceIt, nothing, fmt, nothing
    end
end

# assume this is a Volume, so construct one
@recipe function f{T<:Number}(vol::AbstractArray{T,3}, args...)
    seriestype := :volume
    SliceIt, nothing, Volume(vol, args...), nothing
end


# # images - grays

@recipe function f{T<:Gray}(mat::AMat{T})
    if is_seriestype_supported(:image)
        seriestype := :image
        n, m = size(mat)
        SliceIt, 1:m, 1:n, Surface(mat)
    else
        seriestype := :heatmap
        yflip --> true
        fillcolor --> ColorGradient([:black, :white])
        SliceIt, 1:m, 1:n, Surface(convert(Matrix{Float64}, mat))
    end
end

# # images - colors

@recipe function f{T<:Colorant}(mat::AMat{T})
    if is_seriestype_supported(:image)
        seriestype := :image
        n, m = size(mat)
        SliceIt, 1:m, 1:n, Surface(mat)
    else
        seriestype := :heatmap
        yflip --> true
        z, d[:fillcolor] = replace_image_with_heatmap(mat)
        SliceIt, 1:m, 1:n, Surface(z)
    end
end

#
# # plotting arbitrary shapes/polygons

@recipe function f(shape::Shape)
    seriestype --> :shape
    coords(shape)
end

@recipe function f(shapes::AVec{Shape})
    seriestype --> :shape
    coords(shapes)
end

@recipe function f(shapes::AMat{Shape})
    seriestype --> :shape
    for j in 1:size(shapes,2)
        @series coords(vec(shapes[:,j]))
    end
end



# function without range... use the current range of the x-axis

@recipe function f{F<:Function}(f::FuncOrFuncs{F})
    plt = d[:plot_object]
    xmin, xmax = try
        axis_limits(plt[1][:xaxis])
    catch
        -5, 5
    end
    f, xmin, xmax
end

#
# # --------------------------------------------------------------------
# # 2 arguments
# # --------------------------------------------------------------------
#
#
# # if functions come first, just swap the order (not to be confused with parametric functions...
# # as there would be more than one function passed in)

@recipe function f{F<:Function}(f::FuncOrFuncs{F}, x)
    F2 = typeof(x)
    @assert !(F2 <: Function || (F2 <: AbstractArray && F2.parameters[1] <: Function))  # otherwise we'd hit infinite recursion here
    x, f
end

#
# # --------------------------------------------------------------------
# # 3 arguments
# # --------------------------------------------------------------------
#
#
# # 3d line or scatter

@recipe function f(x::AVec, y::AVec, z::AVec)
    # st = get(d, :seriestype, :none)
    # if st == :scatter
    #     d[:seriestype] = :scatter3d
    # elseif !is3d(st)
    #     d[:seriestype] = :path3d
    # end
    SliceIt, x, y, z
end

@recipe function f(x::AMat, y::AMat, z::AMat)
    # st = get(d, :seriestype, :none)
    # if size(x) == size(y) == size(z)
    #     if !is3d(st)
    #         seriestype := :path3d
    #     end
    # end
    wrap_surfaces(d)
    SliceIt, x, y, z
end

#
# # surface-like... function

@recipe function f(x::AVec, y::AVec, zf::Function)
    # x = X <: Number ? sort(x) : x
    # y = Y <: Number ? sort(y) : y
    wrap_surfaces(d)
    SliceIt, x, y, Surface(zf, x, y)  # TODO: replace with SurfaceFunction when supported
end

#
# # surface-like... matrix grid

@recipe function f(x::AVec, y::AVec, z::AMat)
    if !like_surface(get(d, :seriestype, :none))
        d[:seriestype] = :contour
    end
    wrap_surfaces(d)
    SliceIt, x, y, Surface(z)
end

#
#
# # --------------------------------------------------------------------
# # Parametric functions
# # --------------------------------------------------------------------

#
# # special handling... xmin/xmax with parametric function(s)
@recipe function f(f::Function, xmin::Number, xmax::Number)
    xs = adapted_grid(f, (xmin, xmax))
    xs, f
end
@recipe function f{F<:Function}(fs::AbstractArray{F}, xmin::Number, xmax::Number)
    xs = Any[adapted_grid(f, (xmin, xmax)) for f in fs]
    xs, fs
end
@recipe f{F<:Function,G<:Function}(fx::FuncOrFuncs{F}, fy::FuncOrFuncs{G}, u::AVec)  = mapFuncOrFuncs(fx, u), mapFuncOrFuncs(fy, u)
@recipe f{F<:Function,G<:Function}(fx::FuncOrFuncs{F}, fy::FuncOrFuncs{G}, umin::Number, umax::Number, n = 200) = fx, fy, linspace(umin, umax, n)

#
# # special handling... 3D parametric function(s)
@recipe function f{F<:Function,G<:Function,H<:Function}(fx::FuncOrFuncs{F}, fy::FuncOrFuncs{G}, fz::FuncOrFuncs{H}, u::AVec)
    mapFuncOrFuncs(fx, u), mapFuncOrFuncs(fy, u), mapFuncOrFuncs(fz, u)
end
@recipe function f{F<:Function,G<:Function,H<:Function}(fx::FuncOrFuncs{F}, fy::FuncOrFuncs{G}, fz::FuncOrFuncs{H}, umin::Number, umax::Number, numPoints = 200)
    fx, fy, fz, linspace(umin, umax, numPoints)
end

#
#
# # --------------------------------------------------------------------
# # Lists of tuples and FixedSizeArrays
# # --------------------------------------------------------------------
#
# # if we get an unhandled tuple, just splat it in
@recipe f(tup::Tuple) = tup

#
# # (x,y) tuples
@recipe f{R1<:Number,R2<:Number}(xy::AVec{Tuple{R1,R2}}) = unzip(xy)
@recipe f{R1<:Number,R2<:Number}(xy::Tuple{R1,R2})       = [xy[1]], [xy[2]]

#
# # (x,y,z) tuples
@recipe f{R1<:Number,R2<:Number,R3<:Number}(xyz::AVec{Tuple{R1,R2,R3}}) = unzip(xyz)
@recipe f{R1<:Number,R2<:Number,R3<:Number}(xyz::Tuple{R1,R2,R3})       = [xyz[1]], [xyz[2]], [xyz[3]]

# these might be points+velocity, or OHLC or something else
@recipe f{R1<:Number,R2<:Number,R3<:Number,R4<:Number}(xyuv::AVec{Tuple{R1,R2,R3,R4}}) = get(d,:seriestype,:path)==:ohlc ? OHLC[OHLC(t...) for t in xyuv] : unzip(xyuv)
@recipe f{R1<:Number,R2<:Number,R3<:Number,R4<:Number}(xyuv::Tuple{R1,R2,R3,R4})       = [xyuv[1]], [xyuv[2]], [xyuv[3]], [xyuv[4]]


#
# # 2D FixedSizeArrays
@recipe f{T<:Number}(xy::AVec{FixedSizeArrays.Vec{2,T}}) = unzip(xy)
@recipe f{T<:Number}(xy::FixedSizeArrays.Vec{2,T})       = [xy[1]], [xy[2]]

#
# # 3D FixedSizeArrays
@recipe f{T<:Number}(xyz::AVec{FixedSizeArrays.Vec{3,T}}) = unzip(xyz)
@recipe f{T<:Number}(xyz::FixedSizeArrays.Vec{3,T})       = [xyz[1]], [xyz[2]], [xyz[3]]

#
# # --------------------------------------------------------------------
# # handle grouping
# # --------------------------------------------------------------------

# @recipe function f(groupby::GroupBy, args...)
#     for (i,glab) in enumerate(groupby.groupLabels)
#         # create a new series, with the label of the group, and an idxfilter (to be applied in slice_and_dice)
#         # TODO: use @series instead
#         @show i, glab, groupby.groupIds[i]
#         di = copy(d)
#         get!(di, :label, string(glab))
#         get!(di, :idxfilter, groupby.groupIds[i])
#         push!(series_list, RecipeData(di, args))
#     end
#     nothing
# end

# split the group into 1 series per group, and set the label and idxfilter for each
@recipe function f(groupby::GroupBy, args...)
    for (i,glab) in enumerate(groupby.groupLabels)
        @series begin
            label     --> string(glab)
            idxfilter --> groupby.groupIds[i]
            args
        end
    end
end
