
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
getplotargs(plt::Plot, idx::Int = 1) = plt.plotargs
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
    pkg = backend()
    d = KW(kw)
    preprocessArgs!(d)

    plotargs = merge(d, getPlotArgs(pkg, d, 1))
    plt = _create_plot(pkg, plotargs)  # create a new, blank plot

    # now update the plot
    _plot!(plt, d, args...)
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

# merge the KW d into the plot args
function _add_plotargs!(plt::Plot, d::KW)
    # @show d

    # handle axis updates from a recipe
    for letter in ("x","y","z")
        # get the Axis object
        axis = plt.plotargs[symbol(letter * "axis")]
        # @show 1,typeof(axis)

        # update xlabel, xscale, etc
        for k in _axis_symbols
            lk = symbol(letter * string(k))
            if haskey(d, lk)
                axis[k] = d[lk]
            end
        end
        # @show 2,axis

        # update guidefont, etc
        for k in _axis_symbols_fonts_colors
            if haskey(d, k)
                axis[k] = d[k]
            end
        end
        # @show 3,axis

        # update extrema and discrete values
        datasym = symbol(letter)
        if haskey(d, datasym)
            v = d[datasym]
            if eltype(v) <: Number
                expand_extrema!(axis, v)
            else
                d[datasym] = discrete_value!(axis, v)
            end
        end
        # @show 4,axis
    end

    for k in keys(_plotDefaults)
        if haskey(d, k)
            plt.plotargs[k] = pop!(d, k)
        end
    end
end

# this method recursively applies series recipes when the seriestype is not supported
# natively by the backend
function _apply_series_recipe(plt::Plot, d::KW)
    st = d[:seriestype]
    # dumpdict(d, "apply_series_recipe", true)
    if st in supportedTypes()
        # println("adding series!!")
        warnOnUnsupported(plt.backend, d)
        _add_series(plt.backend, plt, d)
    else
        # get a sub list of series for this seriestype
        series_list = try
            RecipesBase.apply_recipe(d, Val{st}, d[:x], d[:y], d[:z])
        catch
            warn("Exception during apply_recipe(Val{$st}, ...) with types ($(typeof(d[:x])), $(typeof(d[:y])), $(typeof(d[:z])))")
            rethrow()
        end

        # assuming there was no error, recursively apply the series recipes
        for series in series_list
            _apply_series_recipe(plt, series.d)
        end
    end
end


# this is the core plotting function.  recursively apply recipes to build
# a list of series KW dicts.
# note: at entry, we only have those preprocessed args which were passed in... no default values yet
function _plot!(plt::Plot, d::KW, args...)
    # just in case the backend needs to set up the plot (make it current or something)
    _before_add_series(plt)

    # the grouping mechanism is a recipe on a GroupBy object
    # we simply add the GroupBy object to the front of the args list to allow
    # the recipe to be applied
    if haskey(d, :group)
        args = tuple(extractGroupArgs(d[:group], args...), args...)
    end

    # initialize the annotations list with what was passed in
    # TODO: there must be cleaner way to handle this!
    anns = annotations(get(d, :annotation, NTuple{3}[]))
    if typeof(anns)  <: AVec{PlotText}
        anns = NTuple{3}[]
    else
        delete!(d, :annotation)
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
        next_series = pop!(still_to_process)
        series_list = RecipesBase.apply_recipe(next_series.d, next_series.args...)
        for series in series_list
            # @show series
            if isempty(series.args)
                # when the arg tuple is empty, that means there's nothing left to recursively
                # process... finish up and add to the kw_list
                kw = series.d
                _add_markershape(kw)

                # if there was a grouping, filter the data here
                _filter_input_data!(kw)
                @show typeof((kw[:x], kw[:y], kw[:z]))

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

                # check that the backend will support the command and add it to the list
                warnOnUnsupportedArgs(plt.backend, kw)
                warnOnUnsupportedScales(plt.backend, kw)
                push!(kw_list, kw)

                # handle error bars by creating new series data... these will have
                # the same series index as the series they are copied from
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
                push!(still_to_process, series)
            end
        end
    end

    # !!! note: at this point, kw_list is fully decomposed into individual series... one KW per series !!!


    # now include any annotations which were added during recipes
    for kw in kw_list
        append!(anns, annotations(pop!(kw, :annotation, [])))
    end
    # @show anns


    for kw in kw_list
        @show typeof((kw[:x], kw[:y], kw[:z]))
    end

    # merge plot args... this is where we combine all the plot args from the user and
    # from the recipes... axis info, colors, etc
    # TODO: why do i need to check for the subplot key?
    if !haskey(d, :subplot)
        for kw in vcat(kw_list, d)
            _add_plotargs!(plt, kw)
        end
        handlePlotColors(plt.backend, plt.plotargs)
    end

    for kw in kw_list
        @show typeof((kw[:x], kw[:y], kw[:z]))
    end

    # this is it folks!
    # TODO: we probably shouldn't use i for tracking series index, but rather explicitly track it in recipes
    for (i,kw) in enumerate(kw_list)
        if !(get(kw, :seriestype, :none) in (:xerror, :yerror))
            plt.n += 1
        end

        # TODO: can this be handled as a recipe??  (yes... need to remove)
        # note: this could probably be handled using a recipe signature f{S<:Union{AbstractString,Symbol}}(v::AVec{S}, letter::AbstractString)
        # that gets called from within the SliceIt section
        # if !stringsSupported() && di[:seriestype] != :pie
        #     setTicksFromStringVector(plt, d, di, "x")
        #     setTicksFromStringVector(plt, d, di, "y")
        #     setTicksFromStringVector(plt, d, di, "z")
        # end

        # TODO: unnecessary??  (yes... deleted as part of _add_plotargs... remove this)
        # # remove plot args
        # for k in keys(_plotDefaults)
        #     delete!(di, k)
        # end

        # TODO: why??  (I think we can remove??)
        # # merge in plotarg_overrides
        # plotarg_overrides = pop!(di, :plotarg_overrides, nothing)
        # if plotarg_overrides != nothing
        #     merge!(plt.plotargs, plotarg_overrides)
        # end

        # set default values, select from attribute cycles, and generally set the final attributes
        _add_defaults!(kw, plt, i)

        _replace_linewidth(kw)

        # now we have a fully specified series, with colors chosen.   we must recursively handle
        # series recipes, which dispatch on seriestype.  If a backend does not natively support a seriestype,
        # we check for a recipe that will convert that series type into one made up of lower-level components.
        # For example, a histogram is just a bar plot with binned data, a bar plot is really a filled step plot,
        # and a step plot is really just a path.  So any backend that supports drawing a path will implicitly
        # be able to support step, bar, and histogram plots (and any recipes that use those components).
        _apply_series_recipe(plt, kw)
    end

    # now that we're done adding all the series, add the annotations
    _add_annotations(plt, anns)

    # add title, axis labels, ticks, etc
    # TODO: do we really need this subplot check?
    if !haskey(d, :subplot)
        # merge!(plt.plotargs, d)  # this shouldn't be needed since we merged the keys earlier
        _update_plot(plt, plt.plotargs)
    end

    current(plt)

    # note: lets ignore the show param and effectively use the semicolon at the end of the REPL statement
    # # do we want to show it?
    if haskey(d, :show) && d[:show]
        gui()
    end

    plt
end

# # handle the grouping
# function _add_series(plt::Plot, d::KW, groupby::GroupBy, args...)
#     starting_n = plt.n
#     for (i, glab) in enumerate(groupby.groupLabels)
#         tmpd = copy(d)
#         tmpd[:numUncounted] = plt.n - starting_n
#         _add_series(plt, tmpd, nothing, args...;
#                     idxfilter = groupby.groupIds[i],
#                     grouplabel = string(glab))
#     end
# end


function _replace_linewidth(d::KW)
    # get a good default linewidth... 0 for surface and heatmaps
    if get(d, :linewidth, :auto) == :auto
        d[:linewidth] = (get(d, :seriestype, :path) in (:surface,:heatmap,:image) ? 0 : 1)
    end
end

# # no grouping
# function _add_series(plt::Plot, d::KW, args...;
#                      idxfilter = nothing,
#                      grouplabel = "")
#
#     # get the list of dictionaries, one per series
#     dumpdict(d, "before process_inputs")
#     process_inputs(plt, d, args...)
#     dumpdict(d, "after process_inputs")
#
#     if idxfilter != nothing
#         # add the group name as the label if there isn't one passed in
#         get!(d, :label, grouplabel)
#         # filter the data
#         filter_data!(d, idxfilter)
#     end
#     # dumpdict(d,"",true)
#
#     seriesArgList, xmeta, ymeta = build_series_args(plt, d) #, idxfilter)
#     # seriesArgList, xmeta, ymeta = build_series_args(plt, groupargs..., args...; d...)
#
#     # # if we were able to extract guide information from the series inputs, then update the plot
#     # # @show xmeta, ymeta
#     # updateDictWithMeta(d, plt.plotargs, xmeta, true)
#     # updateDictWithMeta(d, plt.plotargs, ymeta, false)
#
#
# # function _add_series(plt::Plot, ds::)
#     # now we can plot the series
#     for (i,di) in enumerate(seriesArgList)
#         plt.n += 1
#
#         if !stringsSupported() && di[:seriestype] != :pie
#             setTicksFromStringVector(plt, d, di, "x")
#             setTicksFromStringVector(plt, d, di, "y")
#             setTicksFromStringVector(plt, d, di, "z")
#         end
#
#         # remove plot args
#         for k in keys(_plotDefaults)
#             delete!(di, k)
#         end
#
#         # merge in plotarg_overrides
#         plotarg_overrides = pop!(di, :plotarg_overrides, nothing)
#         if plotarg_overrides != nothing
#             merge!(plt.plotargs, plotarg_overrides)
#         end
#         # dumpdict(plt.plotargs, "pargs", true)
#
#         dumpdict(di, "Series $i")
#
#         _replace_linewidth(di)
#
#         _add_series(plt.backend, plt, di)
#     end
# end

# --------------------------------------------------------------------

# function get_indices(orig, labels)
#     Int[findnext(labels, l, 1) for l in orig]
# end

# # TODO: remove?? this is the old way of handling discrete data... should be
# # replaced by the Axis type and logic
# function setTicksFromStringVector(plt::Plot, d::KW, di::KW, letter)
#     sym = symbol(letter)
#     ticksym = symbol(letter * "ticks")
#     pargs = plt.plotargs
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
#     plt.plotargs[ticksym] = ticks, labels
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

# TODO: remove
# # should we update the x/y label given the meta info during input slicing?
# function updateDictWithMeta(d::KW, plotargs::KW, meta::Symbol, isx::Bool)
#     lsym = isx ? :xlabel : :ylabel
#     if plotargs[lsym] == default(lsym)
#         d[lsym] = string(meta)
#     end
# end
# updateDictWithMeta(d::KW, plotargs::KW, meta, isx::Bool) = nothing

# --------------------------------------------------------------------

annotations(::@compat(Void)) = []
annotations{X,Y,V}(v::AVec{@compat(Tuple{X,Y,V})}) = v
annotations{X,Y,V}(t::@compat(Tuple{X,Y,V})) = [t]
annotations(v::AVec{PlotText}) = v
annotations(v::AVec) = map(PlotText, v)
annotations(anns) = error("Expecting a tuple (or vector of tuples) for annotations: ",
                       "(x, y, annotation)\n    got: $(typeof(anns))")

function annotations(plt::Plot, anns)
    anns = annotations(anns)
    # if we just have a list of PlotText objects, then create (x,y,text) tuples
    if typeof(anns) <: AVec{PlotText}
        x, y = plt[plt.n]
        anns = Tuple{Float64,Float64,PlotText}[(x[i], y[i], t) for (i,t) in enumerate(anns)]
    end
    anns
end


function _add_annotations(plt::Plot, d::KW)
    anns = annotations(get(d, :annotation, nothing))
    if !isempty(anns)

        # if we just have a list of PlotText objects, then create (x,y,text) tuples
        if typeof(anns) <: AVec{PlotText}
            x, y = plt[plt.n]
            anns = Tuple{Float64,Float64,PlotText}[(x[i], y[i], t) for (i,t) in enumerate(anns)]
        end

        _add_annotations(plt, anns)
    end
end


# --------------------------------------------------------------------

function Base.copy(plt::Plot)
    backend(plt.backend)
    plt2 = plot(; plt.plotargs...)
    for sargs in plt.seriesargs
        sargs = filter((k,v) -> haskey(_seriesDefaults,k), sargs)
        plot!(plt2; sargs...)
    end
    plt2
end

# --------------------------------------------------------------------
