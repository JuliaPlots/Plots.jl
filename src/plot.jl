
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
    # pkg = backend()
    d = KW(kw)
    preprocessArgs!(d)

    # create an empty Plot, update the args using the inputs, then pass it
    # to the backend to finish backend-specific initialization
    plt = Plot()
    # _update_plot_args(plt, d)
    # plt.o = _create_backend_figure(plt)
    #
    # # create the layout and subplots from the inputs
    # plt.layout, plt.subplots, plt.spmap = build_layout(plt.attr)
    # for (idx,sp) in enumerate(plt.subplots)
    #     sp.plt = plt
    #     sp.attr[:subplot_index] = idx
    #     _update_subplot_args(plt, sp, copy(d), idx)
    # end

    # now update the plot
    _plot!(plt, d, args...)
end

# build a new plot from existing plots
# note: we split into plt1 and plts_tail so we can dispatch correctly
function plot(plt1::Plot, plts_tail::Plot...; kw...)
    d = KW(kw)
    preprocessArgs!(d)

    # create a layout, but don't add subplots... we expect nplts == layout capacity
    # TODO: move this to layouts.jl
    # plts = vcat(plt1, plts)

    # build our plot vector
    n = length(plts_tail) + 1
    plts = Array(Plot, n)
    plts[1] = plt1
    for (i,plt) in enumerate(plts_tail)
        plts[i+1] = plt
    end
    # plts[2:end] = plts_tail
    # @show typeof(plts),n

    # compute the layout
    layout = layout_args(d, n)[1]
    num_sp = sum([length(p.subplots) for p in plts])
    # @show typeof(layout), num_sp

    # create a new plot object, with subplot list/map made of existing subplots.
    # note: we create a new backend figure for this new plot object
    # note: all subplots and series "belong" to this new plot...
    plt = Plot()

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
    # @show map(typeof, (plt.layout, plt.subplots, plt.spmap))
    for (idx, sp) in enumerate(plt.subplots)
        _initialize_subplot(plt, sp)
        serieslist = series_list(sp)
        sp.plt = plt
        sp.attr[:subplot_index] = idx
        for series in serieslist
            push!(plt.series_list, series)
            _series_added(plt, series)
        end
    end

    # finish up
    current(plt)
    if get(d, :show, default(:show))
        gui()
    end
    plt

        # _update_plot_args(plt, d)
        # plt.o = _create_backend_figure(plt)
        #
        # # create the layout and subplots from the inputs
        # plt.layout, plt.subplots, plt.spmap = build_layout(plt.attr)
        # for (idx,sp) in enumerate(plt.subplots)
        #     sp.plt = plt
        #     sp.attr[:subplot_index] = idx
        #     # _update_subplot_args(plt, sp, copy(d), idx)
        # end
        #
        # plt.init = true
    #
    # nr, nc = size(layout)
    # subplots = Subplot[]
    # spmap = SubplotMap()
    # i = 0
    # for r=1:nr, c=1:nc
    #     l = layout[r,c]
    #     if isa(l, EmptyLayout)
    #         i += 1
    #         plt = plts[i]
    #         layout[r,c] = plt.layout
    #         append!(subplots, plt.subplots)
    #         merge!(spmap, plt.spmap)
    #         # if init_sp
    #         #     sp = Subplot(backend(), parent=layout)
    #         #     layout[r,c] = sp
    #         #     push!(subplots, sp)
    #         #     spmap[attr(l,:label,gensym())] = sp
    #         # end
    #         if hasattr(l,:width)
    #             layout.widths[c] = attr(l,:width)
    #         end
    #         if hasattr(l,:height)
    #             layout.heights[r] = attr(l,:height)
    #         end
    #     elseif isa(l, GridLayout)
    #         # sub-grid
    #         l, sps, m = build_layout(l, n-i)
    #         append!(subplots, sps)
    #         merge!(spmap, m)
    #         i += length(sps)
    #     end
    #     i >= n && break  # only add n subplots
    # end
    # layout, subplots, spmap

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
    _plot!(plt, d, args...)
end

function strip_first_letter(s::Symbol)
    str = string(s)
    str[1:1], symbol(str[2:end])
end


# this method recursively applies series recipes when the seriestype is not supported
# natively by the backend
function _apply_series_recipe(plt::Plot, d::KW)
    st = d[:seriestype]
    # @show st
    if st in supportedTypes()

        # getting ready to add the series... last update to subplot from anything
        # that might have been added during series recipes
        sp = d[:subplot]
        sp_idx = get_subplot_index(plt, sp)
        _update_subplot_args(plt, sp, d, sp_idx)

        # change to a 3d projection for this subplot?
        if is3d(st)
            sp.attr[:projection] = "3d"
        end

        # initialize now that we know the first series type
        if !haskey(sp.attr, :init)
            _initialize_subplot(plt, sp)
            sp.attr[:init] = true
        end

        # adjust extrema and discrete info
        if st != :image
            for letter in (:x, :y, :z)
                data = d[letter]
                axis = sp.attr[symbol(letter, "axis")]
                if eltype(data) <: Number
                    expand_extrema!(axis, data)
                elseif isa(data, Surface) && eltype(data.surf) <: Number
                    expand_extrema!(axis, data)
                elseif data != nothing
                    # TODO: need more here... gotta track the discrete reference value
                    #       as well as any coord offset (think of boxplot shape coords... they all
                    #       correspond to the same x-value)
                    # @show letter,eltype(data),typeof(data)
                    d[letter], d[symbol(letter,"_discrete_indices")] = discrete_value!(axis, data)
                end
            end
        end

        # add the series!
        warnOnUnsupportedArgs(plt.backend, d)
        warnOnUnsupported(plt.backend, d)
        series = Series(d)
        push!(plt.series_list, series)
        # @show series
        _series_added(plt, series)

    else
        # get a sub list of series for this seriestype
        datalist = try
            RecipesBase.apply_recipe(d, Val{st}, d[:x], d[:y], d[:z])
        catch
            warn("Exception during apply_recipe(Val{$st}, ...) with types ($(typeof(d[:x])), $(typeof(d[:y])), $(typeof(d[:z])))")
            rethrow()
        end

        # assuming there was no error, recursively apply the series recipes
        for data in datalist
            if isa(data, RecipeData)
                _apply_series_recipe(plt, data.d)
            else
                warn("Unhandled recipe: $(data)")
                break
            end
        end
    end
end


# this is the core plotting function.  recursively apply recipes to build
# a list of series KW dicts.
# note: at entry, we only have those preprocessed args which were passed in... no default values yet
function _plot!(plt::Plot, d::KW, args...)
    # # just in case the backend needs to set up the plot (make it current or something)
    # _prepare_plot_object(plt)
    #
    # # first apply any args for the subplots
    # for (idx,sp) in enumerate(plt.subplots)
    #     _update_subplot_args(plt, sp, d, idx)
    # end

    # the grouping mechanism is a recipe on a GroupBy object
    # we simply add the GroupBy object to the front of the args list to allow
    # the recipe to be applied
    if haskey(d, :group)
        args = (extractGroupArgs(d[:group], args...), args...)
    end


    # for plotting recipes, swap out the args and update the parameter dictionary
    # we are keeping a queue of series that still need to be processed.
    # each pass through the loop, we pop one off and apply the recipe.
    # the recipe will return a list a Series objects... the ones that are
    # finished (no more args) get added to the kw_list, and the rest go into the queue
    # for processing.
    kw_list = KW[]
    still_to_process = isempty(args) ? [] : [RecipeData(copy(d), args)]
    while !isempty(still_to_process)

        # grab the first in line to be processed and pass it through apply_recipe
        # to generate a list of RecipeData objects (data + attributes)
        next_series = shift!(still_to_process)
        for recipedata in RecipesBase.apply_recipe(next_series.d, next_series.args...)

            # recipedata should be of type RecipeData.  if it's not then the inputs must not have been fully processed by recipes
            if !(typeof(recipedata) <: RecipeData)
                error("Inputs couldn't be processed... expected RecipeData but got: $recipedata")
            end

            if isempty(recipedata.args)
                # when the arg tuple is empty, that means there's nothing left to recursively
                # process... finish up and add to the kw_list
                kw = recipedata.d
                _add_markershape(kw)

                # if there was a grouping, filter the data here
                _filter_input_data!(kw)

                # map marker_z if it's a Function
                if isa(get(kw, :marker_z, nothing), Function)
                    # TODO: should this take y and/or z as arguments?
                    kw[:marker_z] = map(kw[:marker_z], kw[:x])
                end

                # convert a ribbon into a fillrange
                if get(kw, :ribbon, nothing) != nothing
                    rib = kw[:ribbon]
                    kw[:fillrange] = (kw[:y] - rib, kw[:y] + rib)
                end

                # add the plot index
                plt.n += 1
                kw[:series_plotindex] = plt.n

                # check that the backend will support the command and add it to the list
                warnOnUnsupportedScales(plt.backend, kw)
                push!(kw_list, kw)

                # handle error bars by creating new recipedata data... these will have
                # the same recipedata index as the recipedata they are copied from
                for esym in (:xerror, :yerror)
                    if get(d, esym, nothing) != nothing
                        # we make a copy of the KW and apply an errorbar recipe
                        errkw = copy(kw)
                        errkw[:seriestype] = esym
                        push!(kw_list, errkw)
                    end
                end

            else
                # args are non-empty, so there's still processing to do... add it back to the queue
                push!(still_to_process, recipedata)
            end
        end
    end

    # merge in anything meant for plot/subplot
    for kw in kw_list
        for (k,v) in kw
            if haskey(_plot_defaults, k) || haskey(_subplot_defaults, k)
                d[k] = v
            end
        end
    end

    # TODO: init subplots here
    if !plt.init
        _update_plot_args(plt, d)
        plt.o = _create_backend_figure(plt)

        # create the layout and subplots from the inputs
        plt.layout, plt.subplots, plt.spmap = build_layout(plt.attr)
        for (idx,sp) in enumerate(plt.subplots)
            sp.plt = plt
            sp.attr[:subplot_index] = idx
            # _update_subplot_args(plt, sp, copy(d), idx)
        end

        plt.init = true
    end

    # just in case the backend needs to set up the plot (make it current or something)
    _prepare_plot_object(plt)

    # first apply any args for the subplots
    for (idx,sp) in enumerate(plt.subplots)
        _update_subplot_args(plt, sp, d, idx)
    end

    # do we need to link any axes together?
    link_axes!(plt.layout, plt.attr[:link])

    # !!! note: At this point, kw_list is fully decomposed into individual series... one KW per series.          !!!
    # !!!       The next step is to recursively apply series recipes until the backend supports that series type !!!

    # this is it folks!
    # TODO: we probably shouldn't use i for tracking series index, but rather explicitly track it in recipes
    for (i,kw) in enumerate(kw_list)
        # if !(get(kw, :seriestype, :none) in (:xerror, :yerror))
        #     plt.n += 1
        # end

        # get the Subplot object to which the series belongs
        sp = get(kw, :subplot, :auto)
        sp = if sp == :auto
            mod1(i,length(plt.subplots))
        else
            slice_arg(sp, i)
        end
        sp = kw[:subplot] = get_subplot(plt, sp)
        idx = get_subplot_index(plt, sp)

        # strip out series annotations (those which are based on series x/y coords)
        # and add them to the subplot attr
        sp_anns = annotations(sp.attr[:annotations])
        anns = annotations(pop!(kw, :series_annotations, []))
        if length(anns) > 0
            x, y = kw[:x], kw[:y]
            nx, ny, na = map(length, (x,y,anns))
            n = max(nx, ny, na)
            anns = [(x[mod1(i,nx)], y[mod1(i,ny)], text(anns[mod1(i,na)])) for i=1:n]
        end
        sp.attr[:annotations] = vcat(sp_anns, anns)

        # we update subplot args in case something like the color palatte is part of the recipe
        _update_subplot_args(plt, sp, kw, idx)

        # set default values, select from attribute cycles, and generally set the final attributes
        _add_defaults!(kw, plt, sp, i)

        # now we have a fully specified series, with colors chosen.   we must recursively handle
        # series recipes, which dispatch on seriestype.  If a backend does not natively support a seriestype,
        # we check for a recipe that will convert that series type into one made up of lower-level components.
        # For example, a histogram is just a bar plot with binned data, a bar plot is really a filled step plot,
        # and a step plot is really just a path.  So any backend that supports drawing a path will implicitly
        # be able to support step, bar, and histogram plots (and any recipes that use those components).
        _apply_series_recipe(plt, kw)
    end

    # # everything is processed, time to compute the layout bounding boxes
    # _before_layout_calcs(plt)
    # w, h = plt.attr[:size]
    # plt.layout.bbox = BoundingBox(0mm, 0mm, w*px, h*px)
    # update_child_bboxes!(plt.layout)
    #
    # # TODO just need to pass plt... and we should do all non-series updates here
    # _update_plot_object(plt)

    current(plt)

    # note: lets ignore the show param and effectively use the semicolon at the end of the REPL statement
    # # do we want to show it?
    # if haskey(d, :show) && d[:show]
    if get(d, :show, default(:show))
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
    update_child_bboxes!(plt.layout)

    _update_plot_object(plt)
end

function prepared_object(plt::Plot)
    prepare_output(plt)
    plt.o
end

# --------------------------------------------------------------------

# function get_indices(orig, labels)
#     Int[findnext(labels, l, 1) for l in orig]
# end

# # TODO: remove?? this is the old way of handling discrete data... should be
# # replaced by the Axis type and logic
# function setTicksFromStringVector(plt::Plot, d::KW, di::KW, letter)
#     sym = symbol(letter)
#     ticksym = symbol(letter * "ticks")
#     pargs = plt.attr
#     v = di[sym]
#
#     # do we really want to do this?
#     typeof(v) <: AbstractArray || return
#     isempty(v) && return
#     trueOrAllTrue(_ -> typeof(_) <: AbstractString, v) || return
#
#     # compute the ticks and labels
#     ticks, labels = if ticksType(pargs[ticksym]) == :ticks_and_labels
#         # extend the existing ticks and labels. only add to labels if they're new!
#         ticks, labels = pargs[ticksym]
#         newlabels = filter(_ -> !(_ in labels), unique(v))
#         newticks = if isempty(ticks)
#             collect(1:length(newlabels))
#         else
#             maximum(ticks) + collect(1:length(newlabels))
#         end
#         ticks = vcat(ticks, newticks)
#         labels = vcat(labels, newlabels)
#         ticks, labels
#     else
#         # create new ticks and labels
#         newlabels = unique(v)
#         collect(1:length(newlabels)), newlabels
#     end
#
#     d[ticksym] = ticks, labels
#     plt.attr[ticksym] = ticks, labels
#
#     # add an origsym field so that later on we can re-compute the x vector if ticks change
#     origsym = symbol(letter * "orig")
#     di[origsym] = v
#     di[sym] = get_indices(v, labels)
#
#     # loop through existing plt.seriesargs and adjust indices if there is an origsym key
#     for sargs in plt.seriesargs
#         if haskey(sargs, origsym)
#             # TODO: might need to call the setindex function instead to trigger a plot update for some backends??
#             sargs[sym] = get_indices(sargs[origsym], labels)
#         end
#     end
# end


# --------------------------------------------------------------------



# --------------------------------------------------------------------

# function Base.copy(plt::Plot)
#     backend(plt.backend)
#     plt2 = plot(; plt.attr...)
#     for sargs in plt.seriesargs
#         sargs = filter((k,v) -> haskey(_series_defaults,k), sargs)
#         plot!(plt2; sargs...)
#     end
#     plt2
# end

# --------------------------------------------------------------------
