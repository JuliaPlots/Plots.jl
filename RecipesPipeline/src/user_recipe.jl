# # User Recipes

"""
    _process_userrecipes(plt, plotattributes, args)

Wrap input arguments in a `RecipeData' vector and recursively apply user recipes and type
recipes on the first element. Prepend the returned `RecipeData` vector. If an element with
empy `args` is returned pop it from the vector, finish up, and it to vector of `Dict`s with
processed series. When all arguments are processed return the series `Dict`.
"""
function _process_userrecipes!(plt, plotattributes, args)
    @nospecialize
    still_to_process = _recipedata_vector(plt, plotattributes, args)

    # For plotting recipes, we swap out the args and update the parameter dictionary.  We are keeping a stack of series that still need to be processed.
    #
    # On each pass through the loop, we pop one off and apply the recipe.
    # the recipe will return a list a Series objects. The ones that are
    # finished (no more args) get added to the `kw_list`, and the ones that are not
    # are placed on top of the stack and are then processed further.

    kw_list = KW[]
    while !isempty(still_to_process)
        # grab the first in line to be processed and either add it to the kw_list or
        # pass it through apply_recipe to generate a list of RecipeData objects
        # (data + attributes) for further processing.
        next_series = popfirst!(still_to_process)
        # recipedata should be of type RecipeData.
        # if it's not then the inputs must not have been fully processed by recipes
        if !(typeof(next_series) <: RecipeData)
            error(
                "Inputs couldn't be processed... expected RecipeData but got: $next_series",
            )
        end
        if isempty(next_series.args)
            _finish_userrecipe!(plt, kw_list, next_series)
        else
            rd_list =
                RecipesBase.apply_recipe(next_series.plotattributes, next_series.args...)
            warn_on_recipe_aliases!(plt, rd_list, :user, next_series.args)
            prepend!(still_to_process, rd_list)
        end
    end

    # don't allow something else to handle it
    plotattributes[:smooth] = false
    kw_list
end

# TODO Move this to api.jl?

function _recipedata_vector(plt, plotattributes, args)
    @nospecialize
    still_to_process = RecipeData[]
    # the grouping mechanism is a recipe on a GroupBy object
    # we simply add the GroupBy object to the front of the args list to allow
    # the recipe to be applied
    if haskey(plotattributes, :group)
        args = (_extract_group_attributes(plotattributes[:group], args...), args...)
    end

    # if we were passed a vector/matrix of seriestypes and there's more than one row,
    # we want to duplicate the inputs, once for each seriestype row.
    isempty(args) ||
        append!(still_to_process, _expand_seriestype_array(plotattributes, args))

    # remove subplot and axis args from plotattributes...
    # they will be passed through in the kw_list
    isempty(args) || for (k, v) in plotattributes
        if is_subplot_attribute(plt, k) || is_axis_attribute(plt, k)
            reset_kw!(plotattributes, k)
        end
    end

    still_to_process
end

function _expand_seriestype_array(plotattributes, args)
    @nospecialize
    sts = get(plotattributes, :seriestype, :path)
    if typeof(sts) <: AbstractArray
        reset_kw!(plotattributes, :seriestype)
        rd = Vector{RecipeData}(undef, size(sts, 1))
        for r in axes(sts, 1)
            dc = copy(plotattributes)
            dc[:seriestype] = sts[r:r, :]
            rd[r] = RecipeData(dc, args)
        end
        rd
    else
        RecipeData[RecipeData(copy(plotattributes), args)]
    end
end

function _finish_userrecipe!(plt, kw_list, recipedata)
    # when the arg tuple is empty, that means there's nothing left to recursively
    # process... finish up and add to the kw_list
    kw = recipedata.plotattributes
    preprocess_attributes!(plt, kw)
    # if there was a grouping, filter the data here
    _filter_input_data!(kw)
    process_userrecipe!(plt, kw_list, kw)
end

# --------------------------------
# Fallback user recipes
# --------------------------------

@nospecialize

# These call `_apply_type_recipe` in type_recipe.jl and finally the `SliceIt` recipe in
# series.jl.

# handle "type recipes" by converting inputs, and then either re-calling or slicing
@recipe function f(x, y, z)  # COV_EXCL_LINE
    wrap_surfaces!(plotattributes, x, y, z)
    did_replace = false
    did_replace |= x !== (newx = _apply_type_recipe(plotattributes, x, :x))
    did_replace |= y !== (newy = _apply_type_recipe(plotattributes, y, :y))
    did_replace |= z !== (newz = _apply_type_recipe(plotattributes, z, :z))
    if did_replace
        newx, newy, newz
    else
        SliceIt, x, y, z
    end
end
@recipe function f(x, y)  # COV_EXCL_LINE
    wrap_surfaces!(plotattributes, x, y)
    did_replace = false
    did_replace |= x !== (newx = _apply_type_recipe(plotattributes, x, :x))
    did_replace |= y !== (newy = _apply_type_recipe(plotattributes, y, :y))
    if did_replace
        newx, newy
    else
        SliceIt, x, y, nothing
    end
end
@recipe function f(y)  # COV_EXCL_LINE
    wrap_surfaces!(plotattributes, y)
    if y !== (newy = _apply_type_recipe(plotattributes, y, :y))
        newy
    else
        SliceIt, nothing, y, nothing
    end
end

# if there's more than 3 inputs, it can't be passed directly to SliceIt
# so we'll apply_type_recipe to all of them
@recipe function f(v1, v2, v3, v4, vrest...)  # COV_EXCL_LINE
    did_replace = false
    newargs = map(
        v -> begin
            did_replace |= v !== (newv = _apply_type_recipe(plotattributes, v, :unknown))
            newv
        end,
        (v1, v2, v3, v4, vrest...),
    )
    did_replace ||
        error("Couldn't process recipe args: $(map(typeof, (v1, v2, v3, v4, vrest...)))")
    newargs
end

# helper function to ensure relevant attributes are wrapped by Surface
function wrap_surfaces!(plotattributes, args...) end
wrap_surfaces!(plotattributes, x::AMat, y::AMat, z::AMat) = wrap_surfaces!(plotattributes)
wrap_surfaces!(plotattributes, x::AVec, y::AVec, z::AMat) = wrap_surfaces!(plotattributes)
wrap_surfaces!(plotattributes, x::AVec, y::AVec, z::Surface) =
    wrap_surfaces!(plotattributes)
wrap_surfaces!(plotattributes) =
    if (v = get(plotattributes, :fill_z, nothing)) !== nothing
        v isa Surface || (plotattributes[:fill_z] = Surface(v))
    end

# --------------------------------
# Special Cases
# --------------------------------

# --------------------------------
# 1 argument

@recipe f(n::Integer) =
    if is3d(plotattributes)
        SliceIt, n, n, n
    else
        SliceIt, n, n, nothing
    end

# return a surface if this is a 3d plot, otherwise let it be sliced up
@recipe f(mat::AMat) =
    if is3d(plotattributes)
        n, m = axes(mat)
        m, n, Surface(mat)
    else
        nothing, mat, nothing
    end

# if a matrix is wrapped by Formatted, do similar logic, but wrap data with Surface
@recipe f(fmt::Formatted{<:AMat}) =
    if is3d(plotattributes)
        mat = fmt.data
        n, m = axes(mat)
        m, n, Formatted(Surface(mat), fmt.formatter)
    else
        nothing, fmt, nothing
    end

# assume this is a Volume, so construct one
@recipe function f(vol::AbstractArray{<:MaybeNumber,3}, args...)  # COV_EXCL_LINE
    seriestype := :volume
    SliceIt, nothing, Volume(vol, args...), nothing
end

# Dicts: each entry is a data point (x,y)=(key,value)
@recipe function f(d::AbstractDict)  # COV_EXCL_LINE
    seriestype --> :line
    collect(keys(d)), collect(values(d))
end
# function without range... use the current range of the x-axis
@recipe function f(f::FuncOrFuncs{F}) where {F<:Function}  # COV_EXCL_LINE
    plt = plotattributes[:plot_object]
    xmin, xmax = if haskey(plotattributes, :xlims)
        plotattributes[:xlims]
    else
        try
            get_axis_limits(plt, :x)
        catch
            xinv = inverse_scale_func(get(plotattributes, :xscale, :identity))
            xm = PlotUtils.tryrange(f, xinv.([-5, -1, 0, 0.01]))
            xm, PlotUtils.tryrange(f, filter(x -> x > xm, xinv.([5, 1, 0.99, 0, -0.01])))
        end
    end
    f, xmin, xmax
end

# --------------------------------
# 2 arguments

# if functions come first, just swap the order (not to be confused with parametric
# functions... as there would be more than one function passed in)
@recipe function f(f::FuncOrFuncs{F}, x) where {F<:Function}  # COV_EXCL_LINE
    F2 = typeof(x)
    @assert !(F2 <: Function || (F2 <: AbstractArray && F2.parameters[1] <: Function))
    # otherwise we'd hit infinite recursion here
    x, f
end

# --------------------------------
# 3 arguments

# surface-like... function
@recipe f(x::AVec, y::AVec, zf::Function) = x, y, Surface(zf, x, y)  # TODO: replace with SurfaceFunction when supported

# surface-like... matrix grid
@recipe function f(x::AVec, y::AVec, z::AMat)  # COV_EXCL_LINE
    if !is_surface(plotattributes)
        plotattributes[:seriestype] = :contour
    end
    x, y, Surface(z)
end

# parametric functions
# special handling... xmin/xmax with parametric function(s)
@recipe function f(f::Function, xmin::Number, xmax::Number)  # COV_EXCL_LINE
    xscale, yscale = map(sym -> get(plotattributes, sym, :identity), (:xscale, :yscale))
    _scaled_adapted_grid(f, xscale, yscale, xmin, xmax)
end
@recipe function f(fs::AbstractArray{F}, xmin::Number, xmax::Number) where {F<:Function}  # COV_EXCL_LINE
    xscale, yscale = map(sym -> get(plotattributes, sym, :identity), (:xscale, :yscale))
    unzip(_scaled_adapted_grid.(vec(fs), xscale, yscale, xmin, xmax))
end
@recipe f(fx::FuncOrFuncs{F}, fy::FuncOrFuncs{G}, u::AVec) where {F<:Function,G<:Function} =
    _map_funcs(fx, u), _map_funcs(fy, u)
@recipe f(
    fx::FuncOrFuncs{F},
    fy::FuncOrFuncs{G},
    umin::Number,
    umax::Number,
    n = 200,
) where {F<:Function,G<:Function} = fx, fy, range(umin, stop = umax, length = n)

# special handling... 3D parametric function(s)
@recipe f(
    fx::FuncOrFuncs{F},
    fy::FuncOrFuncs{G},
    fz::FuncOrFuncs{H},
    u::AVec,
) where {F<:Function,G<:Function,H<:Function} =
    _map_funcs(fx, u), _map_funcs(fy, u), _map_funcs(fz, u)

@recipe f(
    fx::FuncOrFuncs{F},
    fy::FuncOrFuncs{G},
    fz::FuncOrFuncs{H},
    umin::Number,
    umax::Number,
    numPoints = 200,
) where {F<:Function,G<:Function,H<:Function} =
    fx, fy, fz, range(umin, stop = umax, length = numPoints)

# list of tuples
@recipe f(v::AVec{<:Tuple}) = unzip(v)
@recipe f(tup::Tuple) = [tup]

# list of NamedTuples
@recipe function f(ntv::AVec{<:NamedTuple{K,Tuple{S,T}}}) where {K,S,T}  # COV_EXCL_LINE
    xguide --> string(K[1])
    yguide --> string(K[2])
    Tuple.(ntv)
end
@recipe function f(ntv::AVec{<:NamedTuple{K,Tuple{R,S,T}}}) where {K,R,S,T}  # COV_EXCL_LINE
    xguide --> string(K[1])
    yguide --> string(K[2])
    zguide --> string(K[3])
    Tuple.(ntv)
end

@specialize

function _scaled_adapted_grid(f, xscale, yscale, xmin, xmax)
    (xf, xinv), (yf, yinv) =
        map(s -> (scale_func(s), inverse_scale_func(s)), (xscale, yscale))
    xs, ys = PlotUtils.adapted_grid(yf ∘ f ∘ xinv, xf.((xmin, xmax)))
    xinv.(xs), yinv.(ys)
end
