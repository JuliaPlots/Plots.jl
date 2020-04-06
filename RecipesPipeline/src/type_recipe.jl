# this is the default "type recipe"... just pass the object through
@recipe f(::Type{T}, v::T) where {T} = v

# this should catch unhandled "series recipes" and error with a nice message
@recipe f(::Type{V}, x, y, z) where {V <: Val} =
    error("The backend must not support the series type $V, and there isn't a series recipe defined.")

"""
    _apply_type_recipe(plotattributes, v::T, letter)

Apply the type recipe with signature `(::Type{T}, ::T)`.
"""
function _apply_type_recipe(plotattributes, v, letter)
    _preprocess_axis_args!(plotattributes, letter)
    rdvec = RecipesBase.apply_recipe(plotattributes, typeof(v), v)
    warn_on_recipe_aliases!(plotattributes[:plot_object], plotattributes, :type, typeof(v))
    _postprocess_axis_args!(plotattributes, letter)
    return rdvec[1].args[1]
end

# Handle type recipes when the recipe is defined on the elements.
# This sort of recipe should return a pair of functions... one to convert to number,
# and one to format tick values.
function _apply_type_recipe(plotattributes, v::AbstractArray, letter)
    plt = plotattributes[:plot_object]
    _preprocess_axis_args!(plotattributes, letter)
    # First we try to apply an array type recipe.
    w = RecipesBase.apply_recipe(plotattributes, typeof(v), v)[1].args[1]
    warn_on_recipe_aliases!(plt, plotattributes, :type, typeof(v))
    # If the type did not change try it element-wise
    if typeof(v) == typeof(w)
        isempty(skipmissing(v)) && return Float64[]
        x = first(skipmissing(v))
        args = RecipesBase.apply_recipe(plotattributes, typeof(x), x)[1].args
        warn_on_recipe_aliases!(plt, plotattributes, :type, typeof(x))
        _postprocess_axis_args!(plotattributes, letter)
        if length(args) == 2 && all(arg -> arg isa Function, args)
            numfunc, formatter = args
            return Formatted(map(numfunc, v), formatter)
        else
            return v
        end
    end
    _postprocess_axis_args!(plotattributes, letter)
    return w
end

# special handling for Surface... need to properly unwrap and re-wrap
_apply_type_recipe(plotattributes, v::Surface{<:AMat{<:MaybeString}}) = v
_apply_type_recipe(
    plotattributes,
    v::Surface{<:AMat{<:Union{AbstractFloat, Integer, Missing}}},
) = v
function _apply_type_recipe(plotattributes, v::Surface)
    ret = _apply_type_recipe(plotattributes, v.surf)
    if typeof(ret) <: Formatted
        Formatted(Surface(ret.data), ret.formatter)
    else
        Surface(ret.data)
    end
end

# don't do anything for datapoints or nothing
_apply_type_recipe(plotattributes, v::AbstractArray{<:MaybeString}, letter) = v
_apply_type_recipe(
    plotattributes,
    v::AbstractArray{<:Union{AbstractFloat, Integer, Missing}},
    letter,
) = v
_apply_type_recipe(plotattributes, v::Nothing, letter) = v

# axis args before type recipes should still be mapped to all axes
function _preprocess_axis_args!(plotattributes)
    plt = plotattributes[:plot_object]
    for (k, v) in plotattributes
        if is_axis_attribute(plt, k)
            pop!(plotattributes, k)
            for l in (:x, :y, :z)
                lk = Symbol(l, k)
                haskey(plotattributes, lk) || (plotattributes[lk] = v)
            end
        end
    end
end
function _preprocess_axis_args!(plotattributes, letter)
    plotattributes[:letter] = letter
    _preprocess_axis_args!(plotattributes)
end

# axis args in type recipes should only be applied to the current axis
function _postprocess_axis_args!(plotattributes, letter)
    plt = plotattributes[:plot_object]
    pop!(plotattributes, :letter)
    if letter in (:x, :y, :z)
        for (k, v) in plotattributes
            if is_axis_attribute(plt, k)
                pop!(plotattributes, k)
                lk = Symbol(letter, k)
                haskey(plotattributes, lk) || (plotattributes[lk] = v)
            end
        end
    end
end
