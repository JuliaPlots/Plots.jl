
# we are going to build recipes to do the processing and splitting of the args


# build the argument dictionary for a series
# function getSeriesArgs(pkg::AbstractBackend, plotargs::KW, d, commandIndex::Int, plotIndex::Int, globalIndex::Int)  # TODO, pass in plotargs, not plt
function _add_defaults!(d::KW, plt::Plot, commandIndex::Int)
    # kwdict = KW(d)
    # d = KW()
    pkg = plt.backend
    n = plt.n
    plotargs = getplotargs(plt, n)
    plotIndex = convertSeriesIndex(plt, n)
    globalIndex = n

    # add defaults?
    for k in keys(_seriesDefaults)
        setDictValue(d, d, k, commandIndex, _seriesDefaults)
    end

    # # groupby args?
    # for k in (:idxfilter, :numUncounted, :dataframe)
    #     if haskey(kwdict, k)
    #         d[k] = kwdict[k]
    #     end
    # end

    if haskey(_typeAliases, d[:linetype])
        d[:linetype] = _typeAliases[d[:linetype]]
    end

    aliasesAndAutopick(d, :axis, _axesAliases, supportedAxes(pkg), plotIndex)
    aliasesAndAutopick(d, :linestyle, _styleAliases, supportedStyles(pkg), plotIndex)
    aliasesAndAutopick(d, :markershape, _markerAliases, supportedMarkers(pkg), plotIndex)

    # update color
    d[:seriescolor] = getSeriesRGBColor(d[:seriescolor], plotargs, plotIndex)

    # update colors
    for csym in (:linecolor, :markercolor, :fillcolor)
        d[csym] = if d[csym] == :match
            if has_black_border_for_default(d[:linetype]) && csym == :linecolor
                :black
            else
                d[:seriescolor]
            end
        else
            getSeriesRGBColor(d[csym], plotargs, plotIndex)
        end
    end

    # update markerstrokecolor
    c = d[:markerstrokecolor]
    c = (c == :match ? plotargs[:foreground_color] : getSeriesRGBColor(c, plotargs, plotIndex))
    d[:markerstrokecolor] = c

    # update alphas
    for asym in (:linealpha, :markeralpha, :markerstrokealpha, :fillalpha)
        if d[asym] == nothing
            d[asym] = d[:seriesalpha]
        end
    end

    # scatter plots don't have a line, but must have a shape
    if d[:linetype] in (:scatter, :scatter3d)
        d[:linewidth] = 0
        if d[:markershape] == :none
            d[:markershape] = :ellipse
        end
    end

    # set label
    label = d[:label]
    label = (label == "AUTO" ? "y$globalIndex" : label)
    if d[:axis] == :right && !(length(label) >= 4 && label[end-3:end] != " (R)")
        label = string(label, " (R)")
    end
    d[:label] = label

    warnOnUnsupported(pkg, d)

    d
end

# -------------------------------------------------------------------
# -------------------------------------------------------------------

# instead of process_inputs:

# the catch-all recipes
@recipe function f(x, y, z)
    @show "HERE", typeof((x,y,z))
    xs, _ = convertToAnyVector(x, d)
    ys, _ = convertToAnyVector(y, d)
    zs, _ = convertToAnyVector(z, d)

    fr = pop!(d, :fillrange, nothing)
    fillranges, _ = if typeof(fr) <: Number
        ([fr],nothing)
    else
        convertToAnyVector(fr, d)
    end

    mx = length(xs)
    my = length(ys)
    mz = length(zs)
    # ret = Any[]
    for i in 1:max(mx, my, mz)
        # add a new series
        di = copy(d)
        di[:x], di[:y], di[:z] = compute_xyz(xs[mod1(i,mx)], ys[mod1(i,my)], zs[mod1(i,mz)])
        @show i, di[:x], di[:y], di[:z]
        push!(series_list, RecipeData(di, ()))
    end
    nothing  # don't add a series for the main block
end

@recipe f(x, y) = x, y, nothing
@recipe f(y) = nothing, y, nothing

# @recipe function f{Y<:Number}(y::AVec{Y})
#     x --> 1:length(y)
#     y --> y
#     dumpdict(d,"y",true)
#     ()
# end
#
# @recipe function f{X<:Number,Y<:Number}(x::AVec{X}, y::AVec{Y})
#     x --> x
#     y --> y
#     dumpdict(d,"xy",true)
#     ()
# end
