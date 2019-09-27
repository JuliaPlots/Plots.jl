# RecipesPipeline API

## Warnings

function RecipesPipeline.warn_on_recipe_aliases!(
    plt::Plot,
    plotattributes,
    recipe_type,
    args...,
)
    for k in keys(plotattributes)
        if !is_default_attribute(k)
            dk = get(_keyAliases, k, k)
            if k !== dk
                @warn "Attribute alias `$k` detected in the $recipe_type recipe defined for the signature $(_signature_string(Val{recipe_type}, args...)). To ensure expected behavior it is recommended to use the default attribute `$dk`."
            end
            plotattributes[dk] = RecipesPipeline.pop_kw!(plotattributes, k)
        end
    end
end
function RecipesPipeline.warn_on_recipe_aliases!(
    plt::Plot,
    v::AbstractVector,
    recipe_type,
    args...,
)
    foreach(x -> RecipesPipeline.warn_on_recipe_aliases!(plt, x, recipe_type, args...), v)
end
function RecipesPipeline.warn_on_recipe_aliases!(
    plt::Plot,
    rd::RecipeData,
    recipe_type,
    args...,
)
    RecipesPipeline.warn_on_recipe_aliases!(plt, rd.plotattributes, recipe_type, args...)
end

function _signature_string(::Type{Val{:user}}, args...)
    return string("(::", join(string.(typeof.(args)), ", ::"), ")")
end
_signature_string(::Type{Val{:type}}, T) = "(::Type{$T}, ::$T)"
_signature_string(::Type{Val{:plot}}, st) = "(::Type{Val{:$st}}, ::AbstractPlot)"
_signature_string(::Type{Val{:series}}, st) = "(::Type{Val{:$st}}, x, y, z)"


## Grouping

RecipesPipeline.splittable_attribute(plt::Plot, key, val::SeriesAnnotations, len) =
    RecipesPipeline.splittable_attribute(plt, key, val.strs, len)

function RecipesPipeline.split_attribute(plt::Plot, key, val::SeriesAnnotations, indices)
    split_strs = _RecipesPipeline.split_attribute(key, val.strs, indices)
    return SeriesAnnotations(split_strs, val.font, val.baseshape, val.scalefactor)
end


## Preprocessing attributes

RecipesPipeline.preprocess_attributes!(plt::Plot, plotattributes) =
    RecipesPipeline.preprocess_attributes!(plotattributes) # in src/args.jl

RecipesPipeline.is_axis_attribute(plt::Plot, attr) = is_axis_attr_noletter(attr) # in src/args.jl

RecipesPipeline.is_subplot_attribute(plt::Plot, attr) = is_subplot_attr(attr) # in src/args.jl


## User recipes

function RecipesPipeline.process_userrecipe!(plt::Plot, kw_list, kw)
    _preprocess_userrecipe(kw)
    warn_on_unsupported_scales(plt.backend, kw)
    # add the plot index
    plt.n += 1
    kw[:series_plotindex] = plt.n

    push!(kw_list, kw)
    _add_errorbar_kw(kw_list, kw)
    _add_smooth_kw(kw_list, kw)
    return
end

function _preprocess_userrecipe(kw::AKW)
    _add_markershape(kw)

    # map marker_z if it's a Function
    if isa(get(kw, :marker_z, nothing), Function)
        # TODO: should this take y and/or z as arguments?
        kw[:marker_z] = isa(kw[:z], Nothing) ? map(kw[:marker_z], kw[:x], kw[:y]) :
            map(kw[:marker_z], kw[:x], kw[:y], kw[:z])
    end

    # map line_z if it's a Function
    if isa(get(kw, :line_z, nothing), Function)
        kw[:line_z] = isa(kw[:z], Nothing) ? map(kw[:line_z], kw[:x], kw[:y]) :
            map(kw[:line_z], kw[:x], kw[:y], kw[:z])
    end

    # convert a ribbon into a fillrange
    if get(kw, :ribbon, nothing) !== nothing
        make_fillrange_from_ribbon(kw)
    end
    return
end

function _add_errorbar_kw(kw_list::Vector{KW}, kw::AKW)
    # handle error bars by creating new recipedata data... these will have
    # the same recipedata index as the recipedata they are copied from
    for esym in (:xerror, :yerror, :zerror)
        if get(kw, esym, nothing) !== nothing
            # we make a copy of the KW and apply an errorbar recipe
            errkw = copy(kw)
            errkw[:seriestype] = esym
            errkw[:label] = ""
            errkw[:primary] = false
            push!(kw_list, errkw)
        end
    end
end

function _add_smooth_kw(kw_list::Vector{KW}, kw::AKW)
    # handle smoothing by adding a new series
    if get(kw, :smooth, false)
        x, y = kw[:x], kw[:y]
        β, α = convert(Matrix{Float64}, [x ones(length(x))]) \ convert(Vector{Float64}, y)
        sx = [ignorenan_minimum(x), ignorenan_maximum(x)]
        sy = β .* sx .+ α
        push!(
            kw_list,
            merge(
                copy(kw),
                KW(
                    :seriestype => :path,
                    :x => sx,
                    :y => sy,
                    :fillrange => nothing,
                    :label => "",
                    :primary => false,
                ),
            ),
        )
    end
end


RecipesPipeline.get_axis_limits(plt::Plot, f, letter) = axis_limits(plt[1], letter)


## Plot recipes

RecipesPipeline.type_alias(plt::Plot) = get(_typeAliases, st, st)


## Plot setup

function RecipesPipeline.plot_setup!(plt::Plot, plotattributes, kw_list)
    _plot_setup(plt, plotattributes, kw_list)
    _subplot_setup(plt, plotattributes, kw_list)
end

# TODO: Should some of this logic be moved to RecipesPipeline?
function _plot_setup(plt::Plot, plotattributes::AKW, kw_list::Vector{KW})
    # merge in anything meant for the Plot
    for kw in kw_list, (k, v) in kw
        haskey(_plot_defaults, k) && (plotattributes[k] = pop!(kw, k))
    end

    # TODO: init subplots here
    _update_plot_args(plt, plotattributes)
    if !plt.init
        plt.o = Base.invokelatest(_create_backend_figure, plt)

        # create the layout and subplots from the inputs
        plt.layout, plt.subplots, plt.spmap = build_layout(plt.attr)
        for (idx, sp) in enumerate(plt.subplots)
            sp.plt = plt
            sp.attr[:subplot_index] = idx
        end

        plt.init = true
    end


    # handle inset subplots
    insets = plt[:inset_subplots]
    if insets !== nothing
        if !(typeof(insets) <: AVec)
            insets = [insets]
        end
        for inset in insets
            parent, bb = is_2tuple(inset) ? inset : (nothing, inset)
            P = typeof(parent)
            if P <: Integer
                parent = plt.subplots[parent]
            elseif P == Symbol
                parent = plt.spmap[parent]
            else
                parent = plt.layout
            end
            sp = Subplot(backend(), parent = parent)
            sp.plt = plt
            push!(plt.subplots, sp)
            push!(plt.inset_subplots, sp)
            sp.attr[:relative_bbox] = bb
            sp.attr[:subplot_index] = length(plt.subplots)
        end
    end
    plt[:inset_subplots] = nothing
end

function _subplot_setup(plt::Plot, plotattributes::AKW, kw_list::Vector{KW})
    # we'll keep a map of subplot to an attribute override dict.
    # Subplot/Axis attributes set by a user/series recipe apply only to the
    # Subplot object which they belong to.
    # TODO: allow matrices to still apply to all subplots
    sp_attrs = Dict{Subplot, Any}()
    for kw in kw_list
        # get the Subplot object to which the series belongs.
        sps = get(kw, :subplot, :auto)
        sp = get_subplot(
            plt,
            _cycle(
                sps == :auto ? plt.subplots : plt.subplots[sps],
                series_idx(kw_list, kw),
            ),
        )
        kw[:subplot] = sp

        # extract subplot/axis attributes from kw and add to sp_attr
        attr = KW()
        for (k, v) in collect(kw)
            if is_subplot_attr(k) || is_axis_attr(k)
                attr[k] = pop!(kw, k)
            end
            if is_axis_attr_noletter(k)
                v = pop!(kw, k)
                for letter in (:x, :y, :z)
                    attr[Symbol(letter, k)] = v
                end
            end
            for k in (:scale,), letter in (:x, :y, :z)
                # Series recipes may need access to this information
                lk = Symbol(letter, k)
                if haskey(attr, lk)
                    kw[lk] = attr[lk]
                end
            end
        end
        sp_attrs[sp] = attr
    end

    # override subplot/axis args.  `sp_attrs` take precendence
    for (idx, sp) in enumerate(plt.subplots)
        attr = if !haskey(plotattributes, :subplot) || plotattributes[:subplot] == idx
            merge(plotattributes, get(sp_attrs, sp, KW()))
        else
            get(sp_attrs, sp, KW())
        end
        _update_subplot_args(plt, sp, attr, idx, false)
    end

    # do we need to link any axes together?
    link_axes!(plt.layout, plt[:link])
end

function series_idx(kw_list::AVec{KW}, kw::AKW)
    Int(kw[:series_plotindex]) - Int(kw_list[1][:series_plotindex]) + 1
end


## Series recipes

function RecipesPipeline.slice_series_attributes!(plt::Plot, kw_list, kw)
    sp::Subplot = kw[:subplot]
    # in series attributes given as vector with one element per series,
    # select the value for current series
    _slice_series_args!(kw, plt, sp, series_idx(kw_list, kw))
end

RecipesPipeline.series_defaults(plt::Plot) = _series_defaults # in args.jl

RecipesPipeline.is_seriestype_supported(plt::Plot, st) = is_seriestype_supported(st)

function RecipesPipeline.add_series!(plt::Plot, plotattributes)
    sp = _prepare_subplot(plt, plotattributes)
    _expand_subplot_extrema(sp, plotattributes, plotattributes[:seriestype])
    _update_series_attributes!(plotattributes, plt, sp)
    _add_the_series(plt, sp, plotattributes)
end

# getting ready to add the series... last update to subplot from anything
# that might have been added during series recipes
function _prepare_subplot(plt::Plot{T}, plotattributes::AKW) where {T}
    st::Symbol = plotattributes[:seriestype]
    sp::Subplot{T} = plotattributes[:subplot]
    sp_idx = get_subplot_index(plt, sp)
    _update_subplot_args(plt, sp, plotattributes, sp_idx, true)

    st = _override_seriestype_check(plotattributes, st)

    # change to a 3d projection for this subplot?
    if RecipesPipeline.needs_3d_axes(st)
        sp.attr[:projection] = "3d"
    end

    # initialize now that we know the first series type
    if !haskey(sp.attr, :init)
        _initialize_subplot(plt, sp)
        sp.attr[:init] = true
    end
    sp
end

function _override_seriestype_check(plotattributes::AKW, st::Symbol)
    # do we want to override the series type?
    if !RecipesPipeline.is3d(st) && !(st in (:contour, :contour3d))
        z = plotattributes[:z]
        if !isa(z, Nothing) &&
           (size(plotattributes[:x]) == size(plotattributes[:y]) == size(z))
            st = (st == :scatter ? :scatter3d : :path3d)
            plotattributes[:seriestype] = st
        end
    end
    st
end

function _expand_subplot_extrema(sp::Subplot, plotattributes::AKW, st::Symbol)
    # adjust extrema and discrete info
    if st == :image
        xmin, xmax = ignorenan_extrema(plotattributes[:x])
        ymin, ymax = ignorenan_extrema(plotattributes[:y])
        expand_extrema!(sp[:xaxis], (xmin, xmax))
        expand_extrema!(sp[:yaxis], (ymin, ymax))
    elseif !(st in (:histogram, :bins2d, :histogram2d))
        expand_extrema!(sp, plotattributes)
    end
    # expand for zerolines (axes through origin)
    if sp[:framestyle] in (:origin, :zerolines)
        expand_extrema!(sp[:xaxis], 0.0)
        expand_extrema!(sp[:yaxis], 0.0)
    end
end

function _add_the_series(plt, sp, plotattributes)
    plotattributes[:extra_kwargs] = warnOnUnsupported_args(plt.backend, plotattributes)
    warnOnUnsupported(plt.backend, plotattributes)
    series = Series(plotattributes)
    push!(plt.series_list, series)
    push!(sp.series_list, series)
    _series_added(plt, series)
end
