# # Type Recipes

@nospecialize

# this is the default "type recipe"... just pass the object through
@recipe f(::Type{T}, v::T) where {T} = v

# this should catch unhandled "series recipes" and error with a nice message
@recipe f(::Type{V}, x, y, z) where {V <: Val} = error(
    "The backend must not support the series type $V, and there isn't a series recipe defined.",
)

"""
    _apply_type_recipe(plotattributes, v::T, letter)

Apply the type recipe with signature `(::Type{T}, ::T)`.
"""
function _apply_type_recipe(plotattributes, v, letter)
    plt = plotattributes[:plot_object]
    preprocess_axis_args!(plt, plotattributes, letter)
    rdvec = RecipesBase.apply_recipe(plotattributes, typeof(v), v)
    warn_on_recipe_aliases!(plotattributes[:plot_object], plotattributes, :type, v)
    postprocess_axis_args!(plt, plotattributes, letter)
    return rdvec[1].args[1]
end

# Handle type recipes when the recipe is defined on the elements.
# This sort of recipe should return a pair of functions... one to convert to number,
# and one to format tick values.
function _apply_type_recipe(plotattributes, v::AbstractArray, letter)
    plt = plotattributes[:plot_object]
    preprocess_axis_args!(plt, plotattributes, letter)
    # First we try to apply an array type recipe.
    w = RecipesBase.apply_recipe(plotattributes, typeof(v), v)[1].args[1]
    warn_on_recipe_aliases!(plt, plotattributes, :type, v)
    # If the type did not change try it element-wise
    if typeof(v) == typeof(w)
        if (smv = skipmissing(v)) |> isempty
            postprocess_axis_args!(plt, plotattributes, letter)
            return Float64[]
        end
        x = first(smv)
        args = RecipesBase.apply_recipe(plotattributes, typeof(x), x)[1].args
        warn_on_recipe_aliases!(plt, plotattributes, :type, x)
        postprocess_axis_args!(plt, plotattributes, letter)
        return if length(args) == 2 && all(arg -> arg isa Function, args)
            numfunc, formatter = args
            Formatted(map(numfunc, v), formatter)
        else
            v
        end
    end
    postprocess_axis_args!(plt, plotattributes, letter)
    return w
end

# special handling for Surface... need to properly unwrap and re-wrap
_apply_type_recipe(
    plotattributes,
    v::Surface{<:AMat{<:Union{AbstractFloat, Integer, AbstractString, Missing}}},
    letter,
) = v
function _apply_type_recipe(plotattributes, v::Surface, letter)
    ret = _apply_type_recipe(plotattributes, v.surf, letter)
    return if typeof(ret) <: Formatted
        Formatted(Surface(ret.data), ret.formatter)
    else
        Surface(ret)
    end
end

# don't do anything for datapoints or nothing
_apply_type_recipe(
    plotattributes,
    v::AbstractArray{<:Union{AbstractFloat, Integer, AbstractString, Missing}},
    letter,
) = v
_apply_type_recipe(plotattributes, v::Nothing, letter) = v

@specialize
