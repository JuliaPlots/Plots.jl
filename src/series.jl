

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
prepareSeriesData(ar::AbstractRange{<:Number}) = ar
function prepareSeriesData(a::AbstractArray{<:MaybeNumber})
    f = isimmutable(a) ? replace : replace!
    a = f(x -> ismissing(x) || isinf(x) ? NaN : x, map(float, a))
end
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


# --------------------------------------------------------------------

# TODO: can we avoid the copy here?  one error that crops up is that mapping functions over the same array
#       result in that array being shared.  push!, etc will add too many items to that array

compute_x(x::Nothing, y::Nothing, z)      = axes(z,1)
compute_x(x::Nothing, y, z)            = axes(y,1)
compute_x(x::Function, y, z)        = map(x, y)
compute_x(x, y, z)                  = copy(x)

# compute_y(x::Void, y::Function, z)  = error()
compute_y(x::Nothing, y::Nothing, z)      = axes(z,2)
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
compute_xyz(x::Nothing, y::FuncOrFuncs{F}, z) where {F<:Function}       = error("If you want to plot the function `$y`, you need to define the x values!")
compute_xyz(x::Nothing, y::Nothing, z::FuncOrFuncs{F}) where {F<:Function} = error("If you want to plot the function `$z`, you need to define x and y values!")
compute_xyz(x::Nothing, y::Nothing, z::Nothing)        = error("x/y/z are all nothing!")

# --------------------------------------------------------------------


# we are going to build recipes to do the processing and splitting of the args

# ensure we dispatch to the slicer
struct SliceIt end

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
@recipe f(::Type{T}, v::T) where {T<:Any} = v

# this should catch unhandled "series recipes" and error with a nice message
@recipe f(::Type{V}, x, y, z) where {V<:Val} = error("The backend must not support the series type $V, and there isn't a series recipe defined.")

_apply_type_recipe(plotattributes, v) = RecipesBase.apply_recipe(plotattributes, typeof(v), v)[1].args[1]

# Handle type recipes when the recipe is defined on the elements.
# This sort of recipe should return a pair of functions... one to convert to number,
# and one to format tick values.
function _apply_type_recipe(plotattributes, v::AbstractArray)
    isempty(skipmissing(v)) && return Float64[]
    x = first(skipmissing(v))
    args = RecipesBase.apply_recipe(plotattributes, typeof(x), x)[1].args
    if length(args) == 2 && typeof(args[1]) <: Function && typeof(args[2]) <: Function
        numfunc, formatter = args
        Formatted(map(numfunc, v), formatter)
    else
        v
    end
end

# # special handling for Surface... need to properly unwrap and re-wrap
# function _apply_type_recipe(plotattributes, v::Surface)
#     T = eltype(v.surf)
#     @show T
#     if T <: Integer || T <: AbstractFloat
#         v
#     else
#         ret = _apply_type_recipe(plotattributes, v.surf)
#         if typeof(ret) <: Formatted
#             Formatted(Surface(ret.data), ret.formatter)
#         else
#             v
#         end
#     end
# end

# don't do anything for ints or floats
_apply_type_recipe(plotattributes, v::AbstractArray{T}) where {T<:Union{Integer,AbstractFloat}} = v

# handle "type recipes" by converting inputs, and then either re-calling or slicing
@recipe function f(x, y, z)
    did_replace = false
    newx = _apply_type_recipe(plotattributes, x)
    x === newx || (did_replace = true)
    newy = _apply_type_recipe(plotattributes, y)
    y === newy || (did_replace = true)
    newz = _apply_type_recipe(plotattributes, z)
    z === newz || (did_replace = true)
    if did_replace
        newx, newy, newz
    else
        SliceIt, x, y, z
    end
end
@recipe function f(x, y)
    did_replace = false
    newx = _apply_type_recipe(plotattributes, x)
    x === newx || (did_replace = true)
    newy = _apply_type_recipe(plotattributes, y)
    y === newy || (did_replace = true)
    if did_replace
        newx, newy
    else
        SliceIt, x, y, nothing
    end
end
@recipe function f(y)
    newy = _apply_type_recipe(plotattributes, y)
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
        newv = _apply_type_recipe(plotattributes, v)
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
function wrap_surfaces(plotattributes::AKW)
    if haskey(plotattributes, :fill_z)
        v = plotattributes[:fill_z]
        if !isa(v, Surface)
            plotattributes[:fill_z] = Surface(v)
        end
    end
end

@recipe f(n::Integer) = is3d(get(plotattributes,:seriestype,:path)) ? (SliceIt, n, n, n) : (SliceIt, n, n, nothing)

all3D(plotattributes) = trueOrAllTrue(st -> st in (:contour, :contourf, :heatmap, :surface, :wireframe, :contour3d, :image, :plots_heatmap), get(plotattributes, :seriestype, :none))

# return a surface if this is a 3d plot, otherwise let it be sliced up
@recipe function f(mat::AMat{T}) where T<:Union{Integer,AbstractFloat,Missing}
    if all3D(plotattributes)
        n,m = axes(mat)
        wrap_surfaces(plotattributes)
        SliceIt, m, n, Surface(mat)
    else
        SliceIt, nothing, mat, nothing
    end
end

# if a matrix is wrapped by Formatted, do similar logic, but wrap data with Surface
@recipe function f(fmt::Formatted{T}) where T<:AbstractMatrix
    if all3D(plotattributes)
        mat = fmt.data
        n,m = axes(mat)
        wrap_surfaces(plotattributes)
        SliceIt, m, n, Formatted(Surface(mat), fmt.formatter)
    else
        SliceIt, nothing, fmt, nothing
    end
end

# assume this is a Volume, so construct one
@recipe function f(vol::AbstractArray{T,3}, args...) where T<:Union{Number,Missing}
    seriestype := :volume
    SliceIt, nothing, Volume(vol, args...), nothing
end


# # images - grays
function clamp_greys!(mat::AMat{T}) where T<:Gray
    for i in eachindex(mat)
        mat[i].val < 0 && (mat[i] = Gray(0))
        mat[i].val > 1 && (mat[i] = Gray(1))
    end
    mat
end

@recipe function f(mat::AMat{T}) where T<:Gray
    n, m = axes(mat)
    if is_seriestype_supported(:image)
        seriestype := :image
        yflip --> true
        SliceIt, m, n, Surface(clamp_greys!(mat))
    else
        seriestype := :heatmap
        yflip --> true
        cbar --> false
        fillcolor --> ColorGradient([:black, :white])
        SliceIt, m, n, Surface(clamp!(convert(Matrix{Float64}, mat), 0., 1.))
    end
end

# # images - colors

@recipe function f(mat::AMat{T}) where T<:Colorant
	n, m = axes(mat)

    if is_seriestype_supported(:image)
        seriestype := :image
        yflip --> true
        SliceIt, m, n, Surface(mat)
    else
        seriestype := :heatmap
        yflip --> true
        cbar --> false
        aspect_ratio --> :equal
        z, plotattributes[:fillcolor] = replace_image_with_heatmap(mat)
        SliceIt, m, n, Surface(z)
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
    for j in axes(shapes,2)
        @series coords(vec(shapes[:,j]))
    end
end

# Dicts: each entry is a data point (x,y)=(key,value)

@recipe f(d::AbstractDict) = collect(keys(d)), collect(values(d))

# function without range... use the current range of the x-axis

@recipe function f(f::FuncOrFuncs{F}) where F<:Function
    plt = plotattributes[:plot_object]
    xmin, xmax = if haskey(plotattributes, :xlims)
        plotattributes[:xlims]
    else
        try
            axis_limits(plt[1], :x)
        catch
            xinv = invscalefunc(get(plotattributes, :xscale, :identity))
            xm = tryrange(f, xinv.([-5,-1,0,0.01]))
            xm, tryrange(f, filter(x->x>xm, xinv.([5,1,0.99, 0, -0.01])))
        end
    end

    f, xmin, xmax
end

# try some intervals over which the function may be defined
function tryrange(F::AbstractArray, vec)
    rets = [tryrange(f, vec) for f in F] # get the preferred for each
    maxind = maximum(indexin(rets, vec)) # get the last attempt that succeeded (most likely to fit all)
    rets .= [tryrange(f, vec[maxind:maxind]) for f in F] # ensure that all functions compute there
    rets[1]
end

function tryrange(F, vec)
    for v in vec
        try
            tmp = F(v)
            return v
        catch
        end
    end
    error("$F is not a Function, or is not defined at any of the values $vec")
end
#
# # --------------------------------------------------------------------
# # 2 arguments
# # --------------------------------------------------------------------
#
#
# # if functions come first, just swap the order (not to be confused with parametric functions...
# # as there would be more than one function passed in)

@recipe function f(f::FuncOrFuncs{F}, x) where F<:Function
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
    # st = get(plotattributes, :seriestype, :none)
    # if st == :scatter
    #     plotattributes[:seriestype] = :scatter3d
    # elseif !is3d(st)
    #     plotattributes[:seriestype] = :path3d
    # end
    SliceIt, x, y, z
end

@recipe function f(x::AMat, y::AMat, z::AMat)
    # st = get(plotattributes, :seriestype, :none)
    # if size(x) == size(y) == size(z)
    #     if !is3d(st)
    #         seriestype := :path3d
    #     end
    # end
    wrap_surfaces(plotattributes)
    SliceIt, x, y, z
end

#
# # surface-like... function

@recipe function f(x::AVec, y::AVec, zf::Function)
    # x = X <: Number ? sort(x) : x
    # y = Y <: Number ? sort(y) : y
    wrap_surfaces(plotattributes)
    SliceIt, x, y, Surface(zf, x, y)  # TODO: replace with SurfaceFunction when supported
end

#
# # surface-like... matrix grid

@recipe function f(x::AVec, y::AVec, z::AMat)
    if !like_surface(get(plotattributes, :seriestype, :none))
        plotattributes[:seriestype] = :contour
    end
    wrap_surfaces(plotattributes)
    SliceIt, x, y, Surface(z)
end

# # images - grays

@recipe function f(x::AVec, y::AVec, mat::AMat{T}) where T<:Gray
    if is_seriestype_supported(:image)
        seriestype := :image
        yflip --> true
        SliceIt, x, y, Surface(mat)
    else
        seriestype := :heatmap
        yflip --> true
        cbar --> false
        fillcolor --> ColorGradient([:black, :white])
        SliceIt, x, y, Surface(convert(Matrix{Float64}, mat))
    end
end

# # images - colors

@recipe function f(x::AVec, y::AVec, mat::AMat{T}) where T<:Colorant
    if is_seriestype_supported(:image)
        seriestype := :image
        yflip --> true
        SliceIt, x, y, Surface(mat)
    else
        seriestype := :heatmap
        yflip --> true
        cbar --> false
        z, plotattributes[:fillcolor] = replace_image_with_heatmap(mat)
        SliceIt, x, y, Surface(z)
    end
end

#
#
# # --------------------------------------------------------------------
# # Parametric functions
# # --------------------------------------------------------------------

#
# # special handling... xmin/xmax with parametric function(s)
@recipe function f(f::Function, xmin::Number, xmax::Number)
    xscale, yscale = [get(plotattributes, sym, :identity) for sym=(:xscale,:yscale)]
    _scaled_adapted_grid(f, xscale, yscale, xmin, xmax)
end
@recipe function f(fs::AbstractArray{F}, xmin::Number, xmax::Number) where F<:Function
    xscale, yscale = [get(plotattributes, sym, :identity) for sym=(:xscale,:yscale)]
    xs = Array{Any}(undef, length(fs))
    ys = Array{Any}(undef, length(fs))
    for (i, (x, y)) in enumerate(_scaled_adapted_grid(f, xscale, yscale, xmin, xmax) for f in fs)
        xs[i] = x
    	ys[i] = y
    end
    xs, ys
end
@recipe f(fx::FuncOrFuncs{F}, fy::FuncOrFuncs{G}, u::AVec) where {F<:Function,G<:Function}  = mapFuncOrFuncs(fx, u), mapFuncOrFuncs(fy, u)
@recipe f(fx::FuncOrFuncs{F}, fy::FuncOrFuncs{G}, umin::Number, umax::Number, n = 200) where {F<:Function,G<:Function} = fx, fy, range(umin, stop = umax, length = n)

function _scaled_adapted_grid(f, xscale, yscale, xmin, xmax)
    (xf, xinv), (yf, yinv) =  ((scalefunc(s),invscalefunc(s)) for s in (xscale,yscale))
    xs, ys = adapted_grid(yf∘f∘xinv, xf.((xmin, xmax)))
    xinv.(xs), yinv.(ys)
end

#
# # special handling... 3D parametric function(s)
@recipe function f(fx::FuncOrFuncs{F}, fy::FuncOrFuncs{G}, fz::FuncOrFuncs{H}, u::AVec) where {F<:Function,G<:Function,H<:Function}
    mapFuncOrFuncs(fx, u), mapFuncOrFuncs(fy, u), mapFuncOrFuncs(fz, u)
end
@recipe function f(fx::FuncOrFuncs{F}, fy::FuncOrFuncs{G}, fz::FuncOrFuncs{H}, umin::Number, umax::Number, numPoints = 200) where {F<:Function,G<:Function,H<:Function}
    fx, fy, fz, range(umin, stop = umax, length = numPoints)
end

#
#
# # --------------------------------------------------------------------
# # Lists of tuples and GeometryTypes.Points
# # --------------------------------------------------------------------
#

@recipe f(v::AVec{<:Tuple})               = unzip(v)
@recipe f(v::AVec{<:GeometryTypes.Point}) = unzip(v)
@recipe f(tup::Tuple)             = [tup]
@recipe f(p::GeometryTypes.Point) = [p]

# Special case for 4-tuples in :ohlc series
@recipe f(xyuv::AVec{<:Tuple{R1,R2,R3,R4}}) where {R1,R2,R3,R4} = get(plotattributes,:seriestype,:path)==:ohlc ? OHLC[OHLC(t...) for t in xyuv] : unzip(xyuv)

#
# # --------------------------------------------------------------------
# # handle grouping
# # --------------------------------------------------------------------

# @recipe function f(groupby::GroupBy, args...)
#     for (i,glab) in enumerate(groupby.groupLabels)
#         # create a new series, with the label of the group, and an idxfilter (to be applied in slice_and_dice)
#         # TODO: use @series instead
#         @show i, glab, groupby.groupIds[i]
#         di = copy(plotattributes)
#         get!(di, :label, string(glab))
#         get!(di, :idxfilter, groupby.groupIds[i])
#         push!(series_list, RecipeData(di, args))
#     end
#     nothing
# end

splittable_kw(key, val, lengthGroup) = false
splittable_kw(key, val::AbstractArray, lengthGroup) = !(key in (:group, :color_palette)) && length(axes(val,1)) == lengthGroup
splittable_kw(key, val::Tuple, lengthGroup) = all(splittable_kw.(key, val, lengthGroup))
splittable_kw(key, val::SeriesAnnotations, lengthGroup) = splittable_kw(key, val.strs, lengthGroup)

split_kw(key, val::AbstractArray, indices) = val[indices, fill(Colon(), ndims(val)-1)...]
split_kw(key, val::Tuple, indices) = Tuple(split_kw(key, v, indices) for v in val)
function split_kw(key, val::SeriesAnnotations, indices)
    split_strs = split_kw(key, val.strs, indices)
    return SeriesAnnotations(split_strs, val.font, val.baseshape, val.scalefactor)
end

function groupedvec2mat(x_ind, x, y::AbstractArray, groupby, def_val = y[1])
    y_mat = Array{promote_type(eltype(y), typeof(def_val))}(undef, length(keys(x_ind)), length(groupby.groupLabels))
    fill!(y_mat, def_val)
    for i in eachindex(groupby.groupLabels)
        xi = x[groupby.groupIds[i]]
        yi = y[groupby.groupIds[i]]
        y_mat[getindex.(Ref(x_ind), xi), i] = yi
    end
    return y_mat
end

groupedvec2mat(x_ind, x, y::Tuple, groupby) = Tuple(groupedvec2mat(x_ind, x, v, groupby) for v in y)

group_as_matrix(t) = false

# split the group into 1 series per group, and set the label and idxfilter for each
@recipe function f(groupby::GroupBy, args...)
    lengthGroup = maximum(union(groupby.groupIds...))
    if !(group_as_matrix(args[1]))
        for (i,glab) in enumerate(groupby.groupLabels)
            @series begin
                label     --> string(glab)
                idxfilter --> groupby.groupIds[i]
                for (key,val) in plotattributes
                    if splittable_kw(key, val, lengthGroup)
                        :($key) := split_kw(key, val, groupby.groupIds[i])
                    end
                end
                args
            end
        end
    else
        g = args[1]
        if length(g.args) == 1
            x = zeros(Int, lengthGroup)
            for indexes in groupby.groupIds
                x[indexes] = eachindex(indexes)
            end
            last_args = g.args
        else
            x = g.args[1]
            last_args = g.args[2:end]
        end
        x_u = unique(sort(x))
        x_ind = Dict(zip(x_u, eachindex(x_u)))
        for (key,val) in plotattributes
            if splittable_kw(key, val, lengthGroup)
                :($key) := groupedvec2mat(x_ind, x, val, groupby)
            end
        end
        label --> reshape(groupby.groupLabels, 1, :)
        typeof(g)((x_u, (groupedvec2mat(x_ind, x, arg, groupby, NaN) for arg in last_args)...))
    end
end
