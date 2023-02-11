# # API

# ## Warnings

"""
    warn_on_recipe_aliases!(plt, plotattributes, recipe_type, args...)

Warn if an alias is detected in `plotattributes` after a recipe of type `recipe_type` is
applied to 'args'. `recipe_type` is either `:user`, `:type`, `:plot` or `:series`.
"""
function warn_on_recipe_aliases!(
    plt,
    plotattributes::AKW,
    recipe_type::Symbol,
    @nospecialize(args)
) end
function warn_on_recipe_aliases!(
    plt,
    v::AbstractVector,
    recipe_type::Symbol,
    @nospecialize(args)
)
    for x in v
        warn_on_recipe_aliases!(plt, x, recipe_type, args)
    end
end
function warn_on_recipe_aliases!(
    plt,
    rd::RecipeData,
    recipe_type::Symbol,
    @nospecialize(args)
)
    warn_on_recipe_aliases!(plt, rd.plotattributes, recipe_type, args)
end

# ## Grouping

"""
    splittable_attribute(plt, key, val, len)

Returns `true` if the attribute `key` with the value `val` can be split into groups with
group provided as a vector of length `len`, `false` otherwise.
"""
splittable_attribute(plt, key, val, len) = false
splittable_attribute(plt, key, val::AbstractArray, len) =
    !(key in (:group, :color_palette)) && length(axes(val, 1)) == len
splittable_attribute(plt, key, val::Tuple, len) =
    all(v -> splittable_attribute(plt, key, v, len), val)

"""
    split_attribute(plt, key, val, indices)

Select the proper indices from `val` for attribute `key`.
"""
split_attribute(plt, key, val::AbstractArray, indices) =
    val[indices, fill(Colon(), ndims(val) - 1)...]
split_attribute(plt, key, val::Tuple, indices) =
    Tuple(split_attribute(plt, key, v, indices) for v in val)

# ## Preprocessing attributes

"""
    preprocess_attributes!(plt, plotattributes)

Any plotting package specific preprocessing of user or recipe input happens here.
For example, Plots replaces aliases and expands magic arguments.
"""
function preprocess_attributes!(plt, plotattributes) end

# TODO: should the Plots version be defined as fallback in RecipesPipeline?
"""
    is_subplot_attribute(plt, attr)

Returns `true` if `attr` is a subplot attribute, otherwise `false`.
"""
is_subplot_attribute(plt, attr) = false

# TODO: should the Plots version be defined as fallback in RecipesPipeline?
"""
    is_axis_attribute(plt, attr)

Returns `true` if `attr` is an axis attribute, i.e. it applies to `xattr`, `yattr` and
`zattr`, otherwise `false`.
"""
is_axis_attribute(plt, attr) = false

# ### processing of axis args
# axis args before type recipes should still be mapped to all axes
"""
    preprocess_axis_args!(plt, plotattributes)

Preprocessing of axis attributes.
Prepends the axis letter to axis attributes by default.
"""
function preprocess_axis_args!(plt, plotattributes)
    for (k, v) in plotattributes
        is_axis_attribute(plt, k) || continue
        pop!(plotattributes, k)
        for letter in (:x, :y, :z)
            get!(plotattributes, Symbol(letter, k), v)
        end
    end
end

"""
    preprocess_axis_args!(plt, plotattributes, letter)

This version additionally stores the letter name in  `plotattributes[:letter]`.
"""
function preprocess_axis_args!(plt, plotattributes, letter)
    plotattributes[:letter] = letter
    preprocess_axis_args!(plt, plotattributes)
end

# axis args in type recipes should only be applied to the current axis
"""
    postprocess_axis_args!(plt, plotattributes, letter)

Removes the `:letter` key from `plotattributes` and does the same prepending of the letters as `preprocess_axis_args!`.
"""
function postprocess_axis_args!(plt, plotattributes, letter)
    pop!(plotattributes, :letter)
    letter in (:x, :y, :z) || return
    for (k, v) in plotattributes
        is_axis_attribute(plt, k) || continue
        pop!(plotattributes, k)
        get!(plotattributes, Symbol(letter, k), v)
    end
end

# ## User recipes

"""
    process_userrecipe!(plt, attributes_list, attributes)

Do plotting package specific post-processing and add series attributes to attributes_list.
For example, Plots increases the number of series in `plt`, sets `:series_plotindex` in
attributes and possible adds new series attributes for errorbars or smooth.
"""
process_userrecipe!(plt, attributes_list, attributes) = push!(attributes_list, attributes)

"""
    get_axis_limits(plt, letter)

Get the limits for the axis specified by `letter` (`:x`, `:y` or `:z`) in `plt`. If it
errors, `tryrange` from PlotUtils is used.
"""
get_axis_limits(plt, letter) = throw(ErrorException("Axis limits not defined."))

# ## Plot recipes

"""
    type_alias(plt, st)

Return the seriestype alias for `st`.
"""
type_alias(plt, st) = st

# ## Plot setup

"""
    plot_setup!(plt, plotattributes, kw_list)

Setup plot, subplots and layouts.
For example, Plots creates the backend figure, initializes subplots, expands extrema and
links subplot axes.
"""
function plot_setup!(plt, plotattributes, kw_list) end

# ## Series recipes

"""
    slice_series_attributes!(plt, kw_list, kw)

For attributes given as vector with one element per series, only select the value for
current series.
"""
function slice_series_attributes!(plt, kw_list, kw) end

"""
    process_sliced_series_attributes!(plt, kw_list)

All series attributes are now properly resolved. Any change of the `kw_list` before the application of recipes must come here.
"""
function process_sliced_series_attributes!(plt, kw_list) end

"""
    series_defaults(plt)

Returns a `Dict` storing the defaults for series attributes.
"""
series_defaults(plt) = Dict{Symbol,Any}()

# TODO: Add a more sensible fallback including e.g. path, scatter, ...

"""
    is_seriestype_supported(plt, st)

Check if the plotting package natively supports the seriestype `st`.
"""
is_seriestype_supported(plt, st) = false

"""
    is_key_supported(key)

Check if the plotting package natively supports the attribute `key`
"""
RecipesBase.is_key_supported(key) = true

# ## Finalizer

"""
    add_series!(plt, kw)

Adds the series defined by `kw` to the plot object.
For example Plots updates the current subplot arguments, expands extrema and pushes the
the series to the series_list of `plt`.
"""
function add_series!(plt, kw) end
