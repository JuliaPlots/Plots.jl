
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
    mf = length(fillranges)

    mx = length(xs)
    my = length(ys)
    mz = length(zs)
    # ret = Any[]
    for i in 1:max(mx, my, mz)
        # add a new series
        di = copy(d)
        xi, yi, zi = xs[mod1(i,mx)], ys[mod1(i,my)], zs[mod1(i,mz)]
        @show i, typeof((xi, yi, zi))
        di[:x], di[:y], di[:z] = compute_xyz(xi, yi, zi)

        # handle fillrange
        fr = fillranges[mod1(i,mf)]
        d[:fillrange] = isa(fr, Function) ? map(fr, di[:x]) : fr

        @show i, di[:x], di[:y], di[:z]
        push!(series_list, RecipeData(di, ()))
    end
    nothing  # don't add a series for the main block
end

@recipe f(x, y) = x, y, nothing
@recipe f(y) = nothing, y, nothing


# # --------------------------------------------------------------------
# # 1 argument
# # --------------------------------------------------------------------
#
# function process_inputs(plt::AbstractPlot, d::KW, n::Integer)
#     # d[:x], d[:y], d[:z] = zeros(0), zeros(0), zeros(0)
#     d[:x] = d[:y] = d[:z] = n
# end

@recipe f(n::Integer) = n, n, n

#
# # matrix... is it z or y?
# function process_inputs{T<:Number}(plt::AbstractPlot, d::KW, mat::AMat{T})
#     if all3D(d)
#         n,m = size(mat)
#         d[:x], d[:y], d[:z] = 1:n, 1:m, mat
#     else
#         d[:y] = mat
#     end
# end

# return a surface if this is a 3d plot, otherwise let it be sliced up
@recipe function f{T<:Number}(mat::AMat{T})
    if all3D(d)
        n,m = size(mat)
        1:n, 1:m, Surface(mat)
    else
        nothing, mat, nothing
    end
end


#
# # images - grays
# function process_inputs{T<:Gray}(plt::AbstractPlot, d::KW, mat::AMat{T})
#     d[:linetype] = :image
#     n,m = size(mat)
#     d[:x], d[:y], d[:z] = 1:n, 1:m, Surface(mat)
#     # handle images... when not supported natively, do a hack to use heatmap machinery
#     if !nativeImagesSupported()
#         d[:linetype] = :heatmap
#         d[:yflip] = true
#         d[:z] = Surface(convert(Matrix{Float64}, mat.surf))
#         d[:fillcolor] = ColorGradient([:black, :white])
#     end
# end

# TODO

#
# # images - colors
# function process_inputs{T<:Colorant}(plt::AbstractPlot, d::KW, mat::AMat{T})
#     d[:linetype] = :image
#     n,m = size(mat)
#     d[:x], d[:y], d[:z] = 1:n, 1:m, Surface(mat)
#     # handle images... when not supported natively, do a hack to use heatmap machinery
#     if !nativeImagesSupported()
#         d[:yflip] = true
#         imageHack(d)
#     end
# end
#

# TODO

#
# # plotting arbitrary shapes/polygons
# function process_inputs(plt::AbstractPlot, d::KW, shape::Shape)
#     d[:x], d[:y] = shape_coords(shape)
#     d[:linetype] = :shape
# end

# TODO

# function process_inputs(plt::AbstractPlot, d::KW, shapes::AVec{Shape})
#     d[:x], d[:y] = shape_coords(shapes)
#     d[:linetype] = :shape
# end

# TODO

# function process_inputs(plt::AbstractPlot, d::KW, shapes::AMat{Shape})
#     x, y = [], []
#     for j in 1:size(shapes, 2)
#         tmpx, tmpy = shape_coords(vec(shapes[:,j]))
#         push!(x, tmpx)
#         push!(y, tmpy)
#     end
#     d[:x], d[:y] = x, y
#     d[:linetype] = :shape
# end

# TODO

#
#
# # function without range... use the current range of the x-axis
# function process_inputs(plt::AbstractPlot, d::KW, f::FuncOrFuncs)
#     process_inputs(plt, d, f, xmin(plt), xmax(plt))
# end

# TODO

#
# # --------------------------------------------------------------------
# # 2 arguments
# # --------------------------------------------------------------------
#
#
# # if functions come first, just swap the order (not to be confused with parametric functions...
# # as there would be more than one function passed in)
# function process_inputs(plt::AbstractPlot, d::KW, f::FuncOrFuncs, x)
#     @assert !(typeof(x) <: FuncOrFuncs)  # otherwise we'd hit infinite recursion here
#     process_inputs(plt, d, x, f)
# end

# TODO

#
# # --------------------------------------------------------------------
# # 3 arguments
# # --------------------------------------------------------------------
#
#
# # 3d line or scatter
# function process_inputs(plt::AbstractPlot, d::KW, x::AVec, y::AVec, zvec::AVec)
#     # default to path3d if we haven't set a 3d linetype
#     lt = get(d, :linetype, :none)
#     if lt == :scatter
#         d[:linetype] = :scatter3d
#     elseif !(lt in _3dTypes)
#         d[:linetype] = :path3d
#     end
#     d[:x], d[:y], d[:z] = x, y, zvec
# end

# TODO

#
# # surface-like... function
# function process_inputs{TX,TY}(plt::AbstractPlot, d::KW, x::AVec{TX}, y::AVec{TY}, zf::Function)
#     x = TX <: Number ? sort(x) : x
#     y = TY <: Number ? sort(y) : y
#     # x, y = sort(x), sort(y)
#     d[:z] = Surface(zf, x, y)  # TODO: replace with SurfaceFunction when supported
#     d[:x], d[:y] = x, y
# end

# TODO

#
# # surface-like... matrix grid
# function process_inputs{TX,TY,TZ}(plt::AbstractPlot, d::KW, x::AVec{TX}, y::AVec{TY}, zmat::AMat{TZ})
#     # @assert size(zmat) == (length(x), length(y))
#     # if TX <: Number && !issorted(x)
#     #     idx = sortperm(x)
#     #     x, zmat = x[idx], zmat[idx, :]
#     # end
#     # if TY <: Number && !issorted(y)
#     #     idx = sortperm(y)
#     #     y, zmat = y[idx], zmat[:, idx]
#     # end
#     d[:x], d[:y], d[:z] = x, y, Surface{Matrix{TZ}}(zmat)
#     if !like_surface(get(d, :linetype, :none))
#         d[:linetype] = :contour
#     end
# end

# TODO

#
# # surfaces-like... general x, y grid
# function process_inputs{T<:Number}(plt::AbstractPlot, d::KW, x::AMat{T}, y::AMat{T}, zmat::AMat{T})
#     @assert size(zmat) == size(x) == size(y)
#     # d[:x], d[:y], d[:z] = Any[x], Any[y], Surface{Matrix{Float64}}(zmat)
#     d[:x], d[:y], d[:z] = map(Surface{Matrix{Float64}}, (x, y, zmat))
#     if !like_surface(get(d, :linetype, :none))
#         d[:linetype] = :contour
#     end
# end

# TODO: maybe change this logic... we should check is3d??

#
#
# # --------------------------------------------------------------------
# # Parametric functions
# # --------------------------------------------------------------------
#
# # special handling... xmin/xmax with function(s)
# function process_inputs(plt::AbstractPlot, d::KW, f::FuncOrFuncs, xmin::Number, xmax::Number)
#     width = get(plt.plotargs, :size, (100,))[1]
#     x = linspace(xmin, xmax, width)
#     process_inputs(plt, d, x, f)
# end

# TODO

#
# # special handling... xmin/xmax with parametric function(s)
# process_inputs{T<:Number}(plt::AbstractPlot, d::KW, fx::FuncOrFuncs, fy::FuncOrFuncs, u::AVec{T}) = process_inputs(plt, d, mapFuncOrFuncs(fx, u), mapFuncOrFuncs(fy, u))
# process_inputs{T<:Number}(plt::AbstractPlot, d::KW, u::AVec{T}, fx::FuncOrFuncs, fy::FuncOrFuncs) = process_inputs(plt, d, mapFuncOrFuncs(fx, u), mapFuncOrFuncs(fy, u))
# process_inputs(plt::AbstractPlot, d::KW, fx::FuncOrFuncs, fy::FuncOrFuncs, umin::Number, umax::Number, numPoints::Int = 1000) = process_inputs(plt, d, fx, fy, linspace(umin, umax, numPoints))

# TODO

#
# # special handling... 3D parametric function(s)
# process_inputs{T<:Number}(plt::AbstractPlot, d::KW, fx::FuncOrFuncs, fy::FuncOrFuncs, fz::FuncOrFuncs, u::AVec{T}) = process_inputs(plt, d, mapFuncOrFuncs(fx, u), mapFuncOrFuncs(fy, u), mapFuncOrFuncs(fz, u))
# process_inputs{T<:Number}(plt::AbstractPlot, d::KW, u::AVec{T}, fx::FuncOrFuncs, fy::FuncOrFuncs, fz::FuncOrFuncs) = process_inputs(plt, d, mapFuncOrFuncs(fx, u), mapFuncOrFuncs(fy, u), mapFuncOrFuncs(fz, u))
# process_inputs(plt::AbstractPlot, d::KW, fx::FuncOrFuncs, fy::FuncOrFuncs, fz::FuncOrFuncs, umin::Number, umax::Number, numPoints::Int = 1000) = process_inputs(plt, d, fx, fy, fz, linspace(umin, umax, numPoints))

# TODO

#
#
# # --------------------------------------------------------------------
# # Lists of tuples and FixedSizeArrays
# # --------------------------------------------------------------------
#
# # if we get an unhandled tuple, just splat it in
# function process_inputs(plt::AbstractPlot, d::KW, tup::Tuple)
#     process_inputs(plt, d, tup...)
# end

# TODO

#
# # (x,y) tuples
# function process_inputs{R1<:Number,R2<:Number}(plt::AbstractPlot, d::KW, xy::AVec{Tuple{R1,R2}})
#     process_inputs(plt, d, unzip(xy)...)
# end

# TODO

# function process_inputs{R1<:Number,R2<:Number}(plt::AbstractPlot, d::KW, xy::Tuple{R1,R2})
#     process_inputs(plt, d, [xy[1]], [xy[2]])
# end

# TODO

#
# # (x,y,z) tuples
# function process_inputs{R1<:Number,R2<:Number,R3<:Number}(plt::AbstractPlot, d::KW, xyz::AVec{Tuple{R1,R2,R3}})
#     process_inputs(plt, d, unzip(xyz)...)
# end
# function process_inputs{R1<:Number,R2<:Number,R3<:Number}(plt::AbstractPlot, d::KW, xyz::Tuple{R1,R2,R3})
#     process_inputs(plt, d, [xyz[1]], [xyz[2]], [xyz[3]])
# end

# TODO

#
# # 2D FixedSizeArrays
# function process_inputs{T<:Number}(plt::AbstractPlot, d::KW, xy::AVec{FixedSizeArrays.Vec{2,T}})
#     process_inputs(plt, d, unzip(xy)...)
# end

# TODO

# function process_inputs{T<:Number}(plt::AbstractPlot, d::KW, xy::FixedSizeArrays.Vec{2,T})
#     process_inputs(plt, d, [xy[1]], [xy[2]])
# end

# TODO

#
# # 3D FixedSizeArrays
# function process_inputs{T<:Number}(plt::AbstractPlot, d::KW, xyz::AVec{FixedSizeArrays.Vec{3,T}})
#     process_inputs(plt, d, unzip(xyz)...)
# end

# TODO

# function process_inputs{T<:Number}(plt::AbstractPlot, d::KW, xyz::FixedSizeArrays.Vec{3,T})
#     process_inputs(plt, d, [xyz[1]], [xyz[2]], [xyz[3]])
# end

# TODO

#
# # --------------------------------------------------------------------
# # handle grouping
# # --------------------------------------------------------------------
#
# # function process_inputs(plt::AbstractPlot, d::KW, groupby::GroupBy, args...)
# #     ret = Any[]
# #     error("unfinished after series reorg")
# #     for (i,glab) in enumerate(groupby.groupLabels)
# #         kwlist, xmeta, ymeta = process_inputs(plt, d, args...,
# #                                             idxfilter = groupby.groupIds[i],
# #                                             label = string(glab),
# #                                             numUncounted = length(ret))  # we count the idx from plt.n + numUncounted + i
# #         append!(ret, kwlist)
# #     end
# #     ret, nothing, nothing
# # end

# TODO
