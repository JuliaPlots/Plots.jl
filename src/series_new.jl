
# we are going to build recipes to do the processing and splitting of the args


function _add_defaults!(d::KW, plt::Plot, sp::Subplot, commandIndex::Int)
    pkg = plt.backend
    # n = plt.n
    # attr = getattr(plt, n)
    # plotIndex = convertSeriesIndex(plt, n)
    # globalIndex = plt.n
    globalIndex = d[:series_plotindex]

    # # add defaults?
    # for k in keys(_series_defaults)
    #     setDictValue(d, d, k, commandIndex, _series_defaults)
    # end

    # add default values to our dictionary, being careful not to delete what we just added!
    for (k,v) in _series_defaults
        slice_arg!(d, d, k, v, commandIndex, remove_pair = false)
    end

    # this is how many series belong to this subplot
    plotIndex = count(series -> series.d[:subplot] === sp, plt.series_list) + 1

    # aliasesAndAutopick(d, :axis, _axesAliases, supportedAxes(pkg), plotIndex)
    aliasesAndAutopick(d, :linestyle, _styleAliases, supportedStyles(pkg), plotIndex)
    aliasesAndAutopick(d, :markershape, _markerAliases, supportedMarkers(pkg), plotIndex)

    # update color
    d[:seriescolor] = getSeriesRGBColor(d[:seriescolor], sp.attr, plotIndex)

    # update colors
    for csym in (:linecolor, :markercolor, :fillcolor)
        d[csym] = if d[csym] == :match
            if has_black_border_for_default(d[:seriestype]) && csym == :linecolor
                :black
            else
                d[:seriescolor]
            end
        else
            getSeriesRGBColor(d[csym], sp.attr, plotIndex)
        end
    end

    # update markerstrokecolor
    c = d[:markerstrokecolor]
    c = if c == :match
        sp.attr[:foreground_color_subplot]
    else
        getSeriesRGBColor(c, sp.attr, plotIndex)
    end
    d[:markerstrokecolor] = c

    # update alphas
    for asym in (:linealpha, :markeralpha, :markerstrokealpha, :fillalpha)
        if d[asym] == nothing
            d[asym] = d[:seriesalpha]
        end
    end

    # scatter plots don't have a line, but must have a shape
    if d[:seriestype] in (:scatter, :scatter3d)
        d[:linewidth] = 0
        if d[:markershape] == :none
            d[:markershape] = :ellipse
        end
    end

    # set label
    label = d[:label]
    label = (label == "AUTO" ? "y$globalIndex" : label)
    # if d[:axis] == :right && !(length(label) >= 4 && label[end-3:end] != " (R)")
    #     label = string(label, " (R)")
    # end
    d[:label] = label

    _replace_linewidth(d)
    d
end

# -------------------------------------------------------------------
# -------------------------------------------------------------------

# instead of process_inputs:

# ensure we dispatch to the slicer
immutable SliceIt end

# the catch-all recipes
@recipe function f(::Type{SliceIt}, x, y, z)
    # @show "HERE", typeof((x,y,z))
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

    # @show zs

    mx = length(xs)
    my = length(ys)
    mz = length(zs)
    # ret = Any[]
    for i in 1:max(mx, my, mz)
        # add a new series
        di = copy(d)
        xi, yi, zi = xs[mod1(i,mx)], ys[mod1(i,my)], zs[mod1(i,mz)]
        # @show i, typeof((xi, yi, zi))
        di[:x], di[:y], di[:z] = compute_xyz(xi, yi, zi)
        # @show i, typeof((di[:x], di[:y], di[:z]))

        # handle fillrange
        fr = fillranges[mod1(i,mf)]
        di[:fillrange] = isa(fr, Function) ? map(fr, di[:x]) : fr

        # @show i, di[:x], di[:y], di[:z]
        push!(series_list, RecipeData(di, ()))
    end
    nothing  # don't add a series for the main block
end

# pass these through to the slicer
@recipe f(x, y, z)  = SliceIt, x, y, z
@recipe f(x, y)     = SliceIt, x, y, nothing
@recipe f(y)        = SliceIt, nothing, y, nothing


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
#         d[:x], d[:y], d[:z] = 1:m, 1:n, mat
#     else
#         d[:y] = mat
#     end
# end

# return a surface if this is a 3d plot, otherwise let it be sliced up
@recipe function f{T<:Number}(mat::AMat{T})
    if all3D(d)
        n,m = size(mat)
        SliceIt, 1:m, 1:n, Surface(mat)
    else
        SliceIt, nothing, mat, nothing
    end
end


#
# # images - grays
# function process_inputs{T<:Gray}(plt::AbstractPlot, d::KW, mat::AMat{T})
#     d[:seriestype] = :image
#     n,m = size(mat)
#     d[:x], d[:y], d[:z] = 1:m, 1:n, Surface(mat)
#     # handle images... when not supported natively, do a hack to use heatmap machinery
#     if !nativeImagesSupported()
#         d[:seriestype] = :heatmap
#         d[:yflip] = true
#         d[:z] = Surface(convert(Matrix{Float64}, mat.surf))
#         d[:fillcolor] = ColorGradient([:black, :white])
#     end
# end

@recipe function f{T<:Gray}(mat::AMat{T})
    if nativeImagesSupported()
        seriestype := :image
        n, m = size(mat)
        SliceIt, 1:m, 1:n, Surface(mat)
    else
        seriestype := :heatmap
        yflip --> true
        fillcolor --> ColorGradient([:black, :white])
        SliceIt, 1:m, 1:n, Surface(convert(Matrix{Float64}, mat))
    end
end

#
# # images - colors
# function process_inputs{T<:Colorant}(plt::AbstractPlot, d::KW, mat::AMat{T})
#     d[:seriestype] = :image
#     n,m = size(mat)
#     d[:x], d[:y], d[:z] = 1:m, 1:n, Surface(mat)
#     # handle images... when not supported natively, do a hack to use heatmap machinery
#     if !nativeImagesSupported()
#         d[:yflip] = true
#         imageHack(d)
#     end
# end
#

@recipe function f{T<:Colorant}(mat::AMat{T})
    if nativeImagesSupported()
        seriestype := :image
        n, m = size(mat)
        SliceIt, 1:m, 1:n, Surface(mat)
    else
        seriestype := :heatmap
        yflip --> true
        z, d[:fillcolor] = replace_image_with_heatmap(mat)
        SliceIt, 1:m, 1:n, Surface(z)
    end
end

#
# # plotting arbitrary shapes/polygons
# function process_inputs(plt::AbstractPlot, d::KW, shape::Shape)
#     d[:x], d[:y] = shape_coords(shape)
#     d[:seriestype] = :shape
# end

@recipe function f(shape::Shape)
    seriestype := :shape
    shape_coords(shape)
end

# function process_inputs(plt::AbstractPlot, d::KW, shapes::AVec{Shape})
#     d[:x], d[:y] = shape_coords(shapes)
#     d[:seriestype] = :shape
# end

@recipe function f(shapes::AVec{Shape})
    seriestype := :shape
    shape_coords(shapes)
end

# function process_inputs(plt::AbstractPlot, d::KW, shapes::AMat{Shape})
#     x, y = [], []
#     for j in 1:size(shapes, 2)
#         tmpx, tmpy = shape_coords(vec(shapes[:,j]))
#         push!(x, tmpx)
#         push!(y, tmpy)
#     end
#     d[:x], d[:y] = x, y
#     d[:seriestype] = :shape
# end

@recipe function f(shapes::AMat{Shape})
    for j in 1:size(shapes,2)
        # create one series for each column
        # @series shape_coords(vec(shapes[:,j]))
        di = copy(d)
        push!(series_list, RecipeData(di, shape_coords(vec(shapes[:,j]))))
    end
    nothing # don't create a series for the main block
end

#
#
# # function without range... use the current range of the x-axis
# function process_inputs(plt::AbstractPlot, d::KW, f::FuncOrFuncs)
#     process_inputs(plt, d, f, xmin(plt), xmax(plt))
# end

@recipe function f(f::FuncOrFuncs)
    plt = d[:plot_object]
    f, xmin(plt), xmax(plt)
end

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

@recipe function f(f::FuncOrFuncs, x)
    @assert !(typeof(x) <: FuncOrFuncs)  # otherwise we'd hit infinite recursion here
    x, f
end

#
# # --------------------------------------------------------------------
# # 3 arguments
# # --------------------------------------------------------------------
#
#
# # 3d line or scatter
# function process_inputs(plt::AbstractPlot, d::KW, x::AVec, y::AVec, zvec::AVec)
#     # default to path3d if we haven't set a 3d seriestype
#     st = get(d, :seriestype, :none)
#     if st == :scatter
#         d[:seriestype] = :scatter3d
#     elseif !(st in _3dTypes)
#         d[:seriestype] = :path3d
#     end
#     d[:x], d[:y], d[:z] = x, y, zvec
# end

@recipe function f(x::AVec, y::AVec, z::AVec)
    st = get(d, :seriestype, :none)
    if st == :scatter
        d[:seriestype] = :scatter3d
    elseif !is3d(st)
        d[:seriestype] = :path3d
    end
    SliceIt, x, y, z
end

@recipe function f(x::AMat, y::AMat, z::AMat)
    st = get(d, :seriestype, :none)
    if size(x) == size(y) == size(z)
        if !is3d(st)
            seriestype := :path3d
        end
    end
    SliceIt, x, y, z
end

#
# # surface-like... function
# function process_inputs{TX,TY}(plt::AbstractPlot, d::KW, x::AVec{TX}, y::AVec{TY}, zf::Function)
#     x = TX <: Number ? sort(x) : x
#     y = TY <: Number ? sort(y) : y
#     # x, y = sort(x), sort(y)
#     d[:z] = Surface(zf, x, y)  # TODO: replace with SurfaceFunction when supported
#     d[:x], d[:y] = x, y
# end

@recipe function f(x::AVec, y::AVec, zf::Function)
    # x = X <: Number ? sort(x) : x
    # y = Y <: Number ? sort(y) : y
    SliceIt, x, y, Surface(zf, x, y)  # TODO: replace with SurfaceFunction when supported
end

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
#     if !like_surface(get(d, :seriestype, :none))
#         d[:seriestype] = :contour
#     end
# end

@recipe function f(x::AVec, y::AVec, z::AMat)
    if !like_surface(get(d, :seriestype, :none))
        d[:seriestype] = :contour
    end
    SliceIt, x, y, Surface(z)
end

#
# # surfaces-like... general x, y grid
# function process_inputs{T<:Number}(plt::AbstractPlot, d::KW, x::AMat{T}, y::AMat{T}, zmat::AMat{T})
#     @assert size(zmat) == size(x) == size(y)
#     # d[:x], d[:y], d[:z] = Any[x], Any[y], Surface{Matrix{Float64}}(zmat)
#     d[:x], d[:y], d[:z] = map(Surface{Matrix{Float64}}, (x, y, zmat))
#     if !like_surface(get(d, :seriestype, :none))
#         d[:seriestype] = :contour
#     end
# end

# TODO? maybe change this logic... we should check is3d??
#       I think I can take this out out and just let it be handled by slice_and_dice

#
#
# # --------------------------------------------------------------------
# # Parametric functions
# # --------------------------------------------------------------------
#
# # special handling... xmin/xmax with function(s)
# function process_inputs(plt::AbstractPlot, d::KW, f::FuncOrFuncs, xmin::Number, xmax::Number)
#     width = get(plt.attr, :size, (100,))[1]
#     x = linspace(xmin, xmax, width)
#     process_inputs(plt, d, x, f)
# end


#
# # special handling... xmin/xmax with parametric function(s)
# process_inputs{T<:Number}(plt::AbstractPlot, d::KW, fx::FuncOrFuncs, fy::FuncOrFuncs, u::AVec{T}) = process_inputs(plt, d, mapFuncOrFuncs(fx, u), mapFuncOrFuncs(fy, u))
# process_inputs{T<:Number}(plt::AbstractPlot, d::KW, u::AVec{T}, fx::FuncOrFuncs, fy::FuncOrFuncs) = process_inputs(plt, d, mapFuncOrFuncs(fx, u), mapFuncOrFuncs(fy, u))
# process_inputs(plt::AbstractPlot, d::KW, fx::FuncOrFuncs, fy::FuncOrFuncs, umin::Number, umax::Number, numPoints::Int = 1000) = process_inputs(plt, d, fx, fy, linspace(umin, umax, numPoints))

@recipe f(f::FuncOrFuncs, xmin::Number, xmax::Number) = linspace(xmin, xmax, 100), f
@recipe f(fx::FuncOrFuncs, fy::FuncOrFuncs, u::AVec)  = mapFuncOrFuncs(fx, u), mapFuncOrFuncs(fy, u)
# @recipe f(u::AVec, fx::FuncOrFuncs, fy::FuncOrFuncs)  = mapFuncOrFuncs(fx, u), mapFuncOrFuncs(fy, u)
@recipe f(fx::FuncOrFuncs, fy::FuncOrFuncs, umin::Number, umax::Number, n = 200) = fx, fy, linspace(umin, umax, n)

#
# # special handling... 3D parametric function(s)
# process_inputs{T<:Number}(plt::AbstractPlot, d::KW, fx::FuncOrFuncs, fy::FuncOrFuncs, fz::FuncOrFuncs, u::AVec{T}) = process_inputs(plt, d, mapFuncOrFuncs(fx, u), mapFuncOrFuncs(fy, u), mapFuncOrFuncs(fz, u))
# process_inputs{T<:Number}(plt::AbstractPlot, d::KW, u::AVec{T}, fx::FuncOrFuncs, fy::FuncOrFuncs, fz::FuncOrFuncs) = process_inputs(plt, d, mapFuncOrFuncs(fx, u), mapFuncOrFuncs(fy, u), mapFuncOrFuncs(fz, u))
# process_inputs(plt::AbstractPlot, d::KW, fx::FuncOrFuncs, fy::FuncOrFuncs, fz::FuncOrFuncs, umin::Number, umax::Number, numPoints::Int = 1000) = process_inputs(plt, d, fx, fy, fz, linspace(umin, umax, numPoints))

@recipe function f(fx::FuncOrFuncs, fy::FuncOrFuncs, fz::FuncOrFuncs, u::AVec)
    mapFuncOrFuncs(fx, u), mapFuncOrFuncs(fy, u), mapFuncOrFuncs(fz, u)
end
# @recipe function f(u::AVec, fx::FuncOrFuncs, fy::FuncOrFuncs, fz::FuncOrFuncs)
#     mapFuncOrFuncs(fx, u), mapFuncOrFuncs(fy, u), mapFuncOrFuncs(fz, u)
# end
@recipe function f(fx::FuncOrFuncs, fy::FuncOrFuncs, fz::FuncOrFuncs, umin::Number, umax::Number, numPointsn = 200)
    fx, fy, fz, linspace(umin, umax, numPoints)
end

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

@recipe f(tup::Tuple) = tup

#
# # (x,y) tuples
# function process_inputs{R1<:Number,R2<:Number}(plt::AbstractPlot, d::KW, xy::AVec{Tuple{R1,R2}})
#     process_inputs(plt, d, unzip(xy)...)
# end
# function process_inputs{R1<:Number,R2<:Number}(plt::AbstractPlot, d::KW, xy::Tuple{R1,R2})
#     process_inputs(plt, d, [xy[1]], [xy[2]])
# end

@recipe f{R1<:Number,R2<:Number}(xy::AVec{Tuple{R1,R2}}) = unzip(xy)
@recipe f{R1<:Number,R2<:Number}(xy::Tuple{R1,R2})       = [xy[1]], [xy[2]]

#
# # (x,y,z) tuples
# function process_inputs{R1<:Number,R2<:Number,R3<:Number}(plt::AbstractPlot, d::KW, xyz::AVec{Tuple{R1,R2,R3}})
#     process_inputs(plt, d, unzip(xyz)...)
# end
# function process_inputs{R1<:Number,R2<:Number,R3<:Number}(plt::AbstractPlot, d::KW, xyz::Tuple{R1,R2,R3})
#     process_inputs(plt, d, [xyz[1]], [xyz[2]], [xyz[3]])
# end

@recipe f{R1<:Number,R2<:Number,R3<:Number}(xyz::AVec{Tuple{R1,R2,R3}}) = unzip(xyz)
@recipe f{R1<:Number,R2<:Number,R3<:Number}(xyz::Tuple{R1,R2,R3})       = [xyz[1]], [xyz[2]], [xyz[3]]

# these might be points+velocity, or OHLC or something else
@recipe f{R1<:Number,R2<:Number,R3<:Number,R4<:Number}(xyuv::AVec{Tuple{R1,R2,R3,R4}}) = get(d,:seriestype,:path)==:ohlc ? OHLC[OHLC(t...) for t in xyuv] : unzip(xyuv)
@recipe f{R1<:Number,R2<:Number,R3<:Number,R4<:Number}(xyuv::Tuple{R1,R2,R3,R4})       = [xyuv[1]], [xyuv[2]], [xyuv[3]], [xyuv[4]]


#
# # 2D FixedSizeArrays
# function process_inputs{T<:Number}(plt::AbstractPlot, d::KW, xy::AVec{FixedSizeArrays.Vec{2,T}})
#     process_inputs(plt, d, unzip(xy)...)
# end
# function process_inputs{T<:Number}(plt::AbstractPlot, d::KW, xy::FixedSizeArrays.Vec{2,T})
#     process_inputs(plt, d, [xy[1]], [xy[2]])
# end

@recipe f{T<:Number}(xy::AVec{FixedSizeArrays.Vec{2,T}}) = unzip(xy)
@recipe f{T<:Number}(xy::FixedSizeArrays.Vec{2,T})       = [xy[1]], [xy[2]]

#
# # 3D FixedSizeArrays
# function process_inputs{T<:Number}(plt::AbstractPlot, d::KW, xyz::AVec{FixedSizeArrays.Vec{3,T}})
#     process_inputs(plt, d, unzip(xyz)...)
# end
# function process_inputs{T<:Number}(plt::AbstractPlot, d::KW, xyz::FixedSizeArrays.Vec{3,T})
#     process_inputs(plt, d, [xyz[1]], [xyz[2]], [xyz[3]])
# end

@recipe f{T<:Number}(xyz::AVec{FixedSizeArrays.Vec{3,T}}) = unzip(xyz)
@recipe f{T<:Number}(xyz::FixedSizeArrays.Vec{3,T})       = [xyz[1]], [xyz[2]], [xyz[3]]

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

@recipe function f(groupby::GroupBy, args...)
    for (i,glab) in enumerate(groupby.groupLabels)
        # create a new series, with the label of the group, and an idxfilter (to be applied in slice_and_dice)
        # TODO: use @series instead
        di = copy(d)
        get!(di, :label, string(glab))
        get!(di, :idxfilter, groupby.groupIds[i])
        push!(series_list, RecipeData(di, args))
    end
    nothing
end
