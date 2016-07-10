
type CurrentPlot
    nullableplot::Nullable{AbstractPlot}
end
const CURRENT_PLOT = CurrentPlot(Nullable{AbstractPlot}())

isplotnull() = isnull(CURRENT_PLOT.nullableplot)

function current()
    if isplotnull()
        error("No current plot/subplot")
    end
    get(CURRENT_PLOT.nullableplot)
end
current(plot::AbstractPlot) = (CURRENT_PLOT.nullableplot = Nullable(plot))

# ---------------------------------------------------------


Base.string(plt::Plot) = "Plot{$(plt.backend) n=$(plt.n)}"
Base.print(io::IO, plt::Plot) = print(io, string(plt))
Base.show(io::IO, plt::Plot) = print(io, string(plt))

getplot(plt::Plot) = plt
getattr(plt::Plot, idx::Int = 1) = plt.attr
convertSeriesIndex(plt::Plot, n::Int) = n

# ---------------------------------------------------------


"""
The main plot command.  Use `plot` to create a new plot object, and `plot!` to add to an existing one:

```
    plot(args...; kw...)                  # creates a new plot window, and sets it to be the current
    plot!(args...; kw...)                 # adds to the `current`
    plot!(plotobj, args...; kw...)        # adds to the plot `plotobj`
```

There are lots of ways to pass in data, and lots of keyword arguments... just try it and it will likely work as expected.
When you pass in matrices, it splits by columns.  See the documentation for more info.
"""

# this creates a new plot with args/kw and sets it to be the current plot
function plot(args...; kw...)
    info("started to plot")
    d = KW(kw)
    preprocessArgs!(d)

    # create an empty Plot then process
    plt = Plot()
    # plt.user_attr = d
    _plot!(plt, d, args)
end

# build a new plot from existing plots
# note: we split into plt1 and plts_tail so we can dispatch correctly
function plot(plt1::Plot, plts_tail::Plot...; kw...)
    d = KW(kw)
    preprocessArgs!(d)

    # build our plot vector from the args
    n = length(plts_tail) + 1
    plts = Array(Plot, n)
    plts[1] = plt1
    for (i,plt) in enumerate(plts_tail)
        plts[i+1] = plt
    end

    # compute the layout
    layout = layout_args(d, n)[1]
    num_sp = sum([length(p.subplots) for p in plts])

    # create a new plot object, with subplot list/map made of existing subplots.
    # note: we create a new backend figure for this new plot object
    # note: all subplots and series "belong" to this new plot...
    plt = Plot()

    # TODO: build the user_attr dict by creating "Any matrices" for the args of each subplot

    # TODO: replace this with proper processing from a merged user_attr KW
    # update plot args, first with existing plots, then override with d
    for p in plts
        _update_plot_args(plt, p.attr)
        plt.n += p.n
    end
    _update_plot_args(plt, d)

    # pass new plot to the backend
    plt.o = _create_backend_figure(plt)
    plt.init = true

    # create the layout and initialize the subplots
    plt.layout, plt.subplots, plt.spmap = build_layout(layout, num_sp, copy(plts))
    for (idx, sp) in enumerate(plt.subplots)
        _initialize_subplot(plt, sp)
        serieslist = series_list(sp)
        if sp in sp.plt.inset_subplots
            push!(plt.inset_subplots, sp)
        end
        sp.plt = plt
        sp.attr[:subplot_index] = idx
        for series in serieslist
            push!(plt.series_list, series)
            _series_added(plt, series)
        end
    end

    # first apply any args for the subplots
    for (idx,sp) in enumerate(plt.subplots)
        _update_subplot_args(plt, sp, d, idx, remove_pair = false)
    end

    # do we need to link any axes together?
    link_axes!(plt.layout, plt[:link])

    # finish up
    current(plt)
    if get(d, :show, default(:show))
        gui()
    end
    plt
end



# this adds to the current plot, or creates a new plot if none are current
function  plot!(args...; kw...)
    local plt
    try
        plt = current()
    catch
        return plot(args...; kw...)
    end
    plot!(current(), args...; kw...)
end

# this adds to a specific plot... most plot commands will flow through here
function plot!(plt::Plot, args...; kw...)
    d = KW(kw)
    preprocessArgs!(d)
    # merge!(plt.user_attr, d)
    _plot!(plt, d, args)
end

function strip_first_letter(s::Symbol)
    str = string(s)
    str[1:1], Symbol(str[2:end])
end

# -------------------------------------------------------------------------------

# getting ready to add the series... last update to subplot from anything
# that might have been added during series recipes
function _prepare_subplot(plt::Plot, d::KW)
    st = d[:seriestype]
    sp = d[:subplot]
    sp_idx = get_subplot_index(plt, sp)
    _update_subplot_args(plt, sp, d, sp_idx)

    # do we want to override the series type?
    if !is3d(st) && d[:z] != nothing && (size(d[:x]) == size(d[:y]) == size(d[:z]))
        st = d[:seriestype] = (st == :scatter ? :scatter3d : :path3d)
    end

    # change to a 3d projection for this subplot?
    if is3d(st)
        sp.attr[:projection] = "3d"
    end

    # initialize now that we know the first series type
    if !haskey(sp.attr, :init)
        _initialize_subplot(plt, sp)
        sp.attr[:init] = true
    end
    sp::Subplot
end

function _prepare_annotations(sp::Subplot, d::KW)
    # strip out series annotations (those which are based on series x/y coords)
    # and add them to the subplot attr
    sp_anns = annotations(sp[:annotations])
    anns = annotations(pop!(d, :series_annotations, []))
    if length(anns) > 0
        x, y = d[:x], d[:y]
        nx, ny, na = map(length, (x,y,anns))
        n = max(nx, ny, na)
        anns = [(x[mod1(i,nx)], y[mod1(i,ny)], text(anns[mod1(i,na)])) for i=1:n]
    end
    sp.attr[:annotations] = vcat(sp_anns, anns)
end

function _expand_subplot_extrema(sp::Subplot, d::KW, st::Symbol)
    # adjust extrema and discrete info
    if st == :image
        w, h = size(d[:z])
        expand_extrema!(sp[:xaxis], (0,w))
        expand_extrema!(sp[:yaxis], (0,h))
        sp[:yaxis].d[:flip] = true
    elseif !(st in (:pie, :histogram, :histogram2d))
        expand_extrema!(sp, d)
    end
end

function _add_the_series(plt, d)
    warnOnUnsupported_args(plt.backend, d)
    warnOnUnsupported(plt.backend, d)
    series = Series(d)
    push!(plt.series_list, series)
    _series_added(plt, series)
end

# -------------------------------------------------------------------------------

# this method recursively applies series recipes when the seriestype is not supported
# natively by the backend
function _process_seriesrecipe(plt::Plot, d::KW)
    # replace seriestype aliases
    st = Symbol(d[:seriestype])
    st = d[:seriestype] = get(_typeAliases, st, st)

    # if it's natively supported, finalize processing and pass along to the backend, otherwise recurse
    if st in supported_types()
        sp = _prepare_subplot(plt, d)
        _prepare_annotations(sp, d)
        _expand_subplot_extrema(sp, d, st)
        _add_the_series(plt, d)

    else
        # get a sub list of series for this seriestype
        datalist = RecipesBase.apply_recipe(d, Val{st}, d[:x], d[:y], d[:z])

        # assuming there was no error, recursively apply the series recipes
        for data in datalist
            if isa(data, RecipeData)
                _process_seriesrecipe(plt, data.d)
            else
                warn("Unhandled recipe: $(data)")
                break
            end
        end
    end
    nothing
end

function command_idx(kw_list::AVec{KW}, kw::KW)
    kw[:series_plotindex] - kw_list[1][:series_plotindex] + 1
end

function _expand_seriestype_array(d::KW, args)
    sts = get(d, :seriestype, :path)
    if typeof(sts) <: AbstractArray
        delete!(d, :seriestype)
        RecipeData[begin
            dc = copy(d)
            dc[:seriestype] = sts[r,:]
            RecipeData(dc, args)
        end for r=1:size(sts,1)]
    else
        RecipeData[RecipeData(copy(d), args)]
    end
end

function _preprocess_args(d::KW, args, still_to_process::Vector{RecipeData})
    # the grouping mechanism is a recipe on a GroupBy object
    # we simply add the GroupBy object to the front of the args list to allow
    # the recipe to be applied
    if haskey(d, :group)
        args = (extractGroupArgs(d[:group], args...), args...)
    end

    # if we were passed a vector/matrix of seriestypes and there's more than one row,
    # we want to duplicate the inputs, once for each seriestype row.
    if !isempty(args)
        append!(still_to_process, _expand_seriestype_array(d, args))
    end

    # remove subplot and axis args from d... they will be passed through in the kw_list
    if !isempty(args)
        for (k,v) in d
            for defdict in (_subplot_defaults,
                            _axis_defaults,
                            _axis_defaults_byletter)
                if haskey(defdict, k)
                    delete!(d, k)
                end
            end
        end
    end

    args
end


function _preprocess_userrecipe(kw::KW)
    _add_markershape(kw)

    # if there was a grouping, filter the data here
    _filter_input_data!(kw)

    # map marker_z if it's a Function
    if isa(get(kw, :marker_z, nothing), Function)
        # TODO: should this take y and/or z as arguments?
        kw[:marker_z] = map(kw[:marker_z], kw[:x], kw[:y], kw[:z])
    end

    # map line_z if it's a Function
    if isa(get(kw, :line_z, nothing), Function)
        kw[:line_z] = map(kw[:line_z], kw[:x], kw[:y], kw[:z])
    end

    # convert a ribbon into a fillrange
    if get(kw, :ribbon, nothing) != nothing
        make_fillrange_from_ribbon(kw)
    end
    return
end

function _add_errorbar_kw(kw_list::Vector{KW}, kw::KW)
    # handle error bars by creating new recipedata data... these will have
    # the same recipedata index as the recipedata they are copied from
    for esym in (:xerror, :yerror)
        if get(kw, esym, nothing) != nothing
            # we make a copy of the KW and apply an errorbar recipe
            errkw = copy(kw)
            errkw[:seriestype] = esym
            errkw[:label] = ""
            errkw[:primary] = false
            push!(kw_list, errkw)
        end
    end
end

function _add_smooth_kw(kw_list::Vector{KW}, kw::KW)
    # handle smoothing by adding a new series
    if get(kw, :smooth, false)
        x, y = kw[:x], kw[:y]
        β, α = convert(Matrix{Float64}, [x ones(length(x))]) \ convert(Vector{Float64}, y)
        sx = [minimum(x), maximum(x)]
        sy = β * sx + α
        push!(kw_list, merge(copy(kw), KW(
            :seriestype => :path,
            :x => sx,
            :y => sy,
            :fillrange => nothing,
            :label => "",
            :primary => false,
        )))
    end
end

function _process_userrecipes(plt::Plot, d::KW, args)
    still_to_process = RecipeData[]
    args = _preprocess_args(d, args, still_to_process)

    # for plotting recipes, swap out the args and update the parameter dictionary
    # we are keeping a queue of series that still need to be processed.
    # each pass through the loop, we pop one off and apply the recipe.
    # the recipe will return a list a Series objects... the ones that are
    # finished (no more args) get added to the kw_list, and the rest go into the queue
    # for processing.
    kw_list = KW[]
    while !isempty(still_to_process)
        # grab the first in line to be processed and pass it through apply_recipe
        # to generate a list of RecipeData objects (data + attributes)
        next_series = shift!(still_to_process)
        rd_list = RecipesBase.apply_recipe(next_series.d, next_series.args...)
        for recipedata in rd_list
            # recipedata should be of type RecipeData.  if it's not then the inputs must not have been fully processed by recipes
            if !(typeof(recipedata) <: RecipeData)
                error("Inputs couldn't be processed... expected RecipeData but got: $recipedata")
            end

            if isempty(recipedata.args)
                _process_userrecipe(plt, kw_list, recipedata)
            else
                # args are non-empty, so there's still processing to do... add it back to the queue
                push!(still_to_process, recipedata)
            end
        end
    end

    # don't allow something else to handle it
    d[:smooth] = false
    kw_list
end

function _process_userrecipe(plt::Plot, kw_list::Vector{KW}, recipedata::RecipeData)
    # when the arg tuple is empty, that means there's nothing left to recursively
    # process... finish up and add to the kw_list
    kw = recipedata.d
    _preprocess_userrecipe(kw)
    warnOnUnsupported_scales(plt.backend, kw)

    # add the plot index
    plt.n += 1
    kw[:series_plotindex] = plt.n

    push!(kw_list, kw)
    _add_errorbar_kw(kw_list, kw)
    _add_smooth_kw(kw_list, kw)
    return
end

# Grab the first in line to be processed and pass it through apply_recipe
# to generate a list of RecipeData objects (data + attributes).
# If we applied a "plot recipe" without error, then add the returned datalist's KWs,
# otherwise we just add the original KW.
function _process_plotrecipe(kw::KW, kw_list::Vector{KW}, still_to_process::Vector{KW})
    if !isa(get(kw, :seriestype, nothing), Symbol)
        # seriestype was never set, or it's not a Symbol, so it can't be a plot recipe
        push!(kw_list, kw)
        return
    end
    try
        st = kw[:seriestype]
        st = kw[:seriestype] = get(_typeAliases, st, st)
        datalist = RecipesBase.apply_recipe(kw, Val{st}, plt)
        for data in datalist
            if data.d[:seriestype] == st
                error("Plot recipe $st returned the same seriestype: $(data.d)")
            end
            push!(still_to_process, data.d)
        end
    catch err
        if isa(err, MethodError)
            push!(kw_list, kw)
        else
            rethrow()
        end
    end
    return
end

function _plot_setup(plt::Plot, d::KW, kw_list::Vector{KW})
    # merge in anything meant for the Plot
    for kw in kw_list, (k,v) in kw
        haskey(_plot_defaults, k) && (d[k] = pop!(kw, k))
    end

    # TODO: init subplots here
    _update_plot_args(plt, d)
    if !plt.init
        plt.o = _create_backend_figure(plt)

        # create the layout and subplots from the inputs
        plt.layout, plt.subplots, plt.spmap = build_layout(plt.attr)
        for (idx,sp) in enumerate(plt.subplots)
            sp.plt = plt
            sp.attr[:subplot_index] = idx
        end

        plt.init = true
    end


    # handle inset subplots
    insets = plt[:inset_subplots]
    if insets != nothing
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
            sp = Subplot(backend(), parent=parent)
            sp.plt = plt
            sp.attr[:relative_bbox] = bb
            sp.attr[:subplot_index] = length(plt.subplots)
            push!(plt.subplots, sp)
            push!(plt.inset_subplots, sp)
        end
    end
end

function _subplot_setup(plt::Plot, d::KW, kw_list::Vector{KW})
    # we'll keep a map of subplot to an attribute override dict.
    # Subplot/Axis attributes set by a user/series recipe apply only to the
    # Subplot object which they belong to.
    # TODO: allow matrices to still apply to all subplots
    sp_attrs = Dict{Subplot,Any}()
    for kw in kw_list
        # get the Subplot object to which the series belongs.
        sps = get(kw, :subplot, :auto)
        sp = get_subplot(plt, cycle(sps == :auto ? plt.subplots : plt.subplots[sps], command_idx(kw_list,kw)))
        kw[:subplot] = sp

        # extract subplot/axis attributes from kw and add to sp_attr
        attr = KW()
        for (k,v) in kw
            if haskey(_subplot_defaults, k) || haskey(_axis_defaults_byletter, k)
                attr[k] = pop!(kw, k)
            end
            if haskey(_axis_defaults, k)
                v = pop!(kw, k)
                for letter in (:x,:y,:z)
                    attr[Symbol(letter,k)] = v
                end
            end
        end
        sp_attrs[sp] = attr
    end

    # override subplot/axis args.  `sp_attrs` take precendence
    for (idx,sp) in enumerate(plt.subplots)
        attr = merge(d, get(sp_attrs, sp, KW()))
        _update_subplot_args(plt, sp, attr, idx, remove_pair = false)
    end

    # do we need to link any axes together?
    link_axes!(plt.layout, plt[:link])
end

# this is the core plotting function.  recursively apply recipes to build
# a list of series KW dicts.
# note: at entry, we only have those preprocessed args which were passed in... no default values yet
function _plot!(plt::Plot, d::KW, args::Tuple)
    # d[:plot_object] = plt

    # --------------------------------
    # "USER RECIPES"
    # --------------------------------

    kw_list = _process_userrecipes(plt, d, args)


    # --------------------------------
    # "PLOT RECIPES"
    # --------------------------------

    # "plot recipe", which acts like a series type, and is processed before
    # the plot layout is created, which allows for setting layouts and other plot-wide attributes.
    # we get inputs which have been fully processed by "user recipes" and "type recipes",
    # so we can expect standard vectors, surfaces, etc.  No defaults have been set yet.
    still_to_process = kw_list
    kw_list = KW[]
    while !isempty(still_to_process)
        next_kw = shift!(still_to_process)
        _process_plotrecipe(next_kw, kw_list, still_to_process)
    end

    # --------------------------------
    # Plot/Subplot/Layout setup
    # --------------------------------
    _plot_setup(plt, d, kw_list)
    _subplot_setup(plt, d, kw_list)

    # !!! note: At this point, kw_list is fully decomposed into individual series... one KW per series.          !!!
    # !!!       The next step is to recursively apply series recipes until the backend supports that series type !!!

    # --------------------------------
    # "SERIES RECIPES"
    # --------------------------------
    
    for kw in kw_list
        sp = kw[:subplot]
        idx = get_subplot_index(plt, sp)

        # # we update subplot args in case something like the color palatte is part of the recipe
        # _update_subplot_args(plt, sp, kw, idx)

        # set default values, select from attribute cycles, and generally set the final attributes
        _add_defaults!(kw, plt, sp, command_idx(kw_list,kw))

        # now we have a fully specified series, with colors chosen.   we must recursively handle
        # series recipes, which dispatch on seriestype.  If a backend does not natively support a seriestype,
        # we check for a recipe that will convert that series type into one made up of lower-level components.
        # For example, a histogram is just a bar plot with binned data, a bar plot is really a filled step plot,
        # and a step plot is really just a path.  So any backend that supports drawing a path will implicitly
        # be able to support step, bar, and histogram plots (and any recipes that use those components).
        _process_seriesrecipe(plt, kw)
    end

    # --------------------------------

    current(plt)

    # do we want to force display?
    if plt[:show]
        gui()
    end

    plt
end


function _replace_linewidth(d::KW)
    # get a good default linewidth... 0 for surface and heatmaps
    if get(d, :linewidth, :auto) == :auto
        d[:linewidth] = (get(d, :seriestype, :path) in (:surface,:heatmap,:image) ? 0 : 1)
    end
end

# we're getting ready to display/output.  prep for layout calcs, then update
# the plot object after
function prepare_output(plt::Plot)
    _before_layout_calcs(plt)

    w, h = plt.attr[:size]
    plt.layout.bbox = BoundingBox(0mm, 0mm, w*px, h*px)

    # One pass down and back up the tree to compute the minimum padding
    # of the children on the perimeter.  This is an backend callback.
    _update_min_padding!(plt.layout)
    for sp in plt.inset_subplots
        _update_min_padding!(sp)
    end

    # now another pass down, to update the bounding boxes
    update_child_bboxes!(plt.layout)

    # update those bounding boxes of inset subplots
    update_inset_bboxes!(plt)

    # the backend callback, to reposition subplots, etc
    _update_plot_object(plt)
end

function prepared_object(plt::Plot)
    prepare_output(plt)
    plt.o
end

# --------------------------------------------------------------------
# plot to a Subplot

function plot(sp::Subplot, args...; kw...)
    plt = sp.plt
    plot(plt, args...; kw..., subplot = findfirst(plt.subplots, sp))
end
function plot!(sp::Subplot, args...; kw...)
    plt = sp.plt
    plot!(plt, args...; kw..., subplot = findfirst(plt.subplots, sp))
end

# --------------------------------------------------------------------
