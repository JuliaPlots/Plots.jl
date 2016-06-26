
# we are going to build recipes to do the processing and splitting of the args


function _add_defaults!(d::KW, plt::Plot, sp::Subplot, commandIndex::Int)
    pkg = plt.backend
    globalIndex = d[:series_plotindex]

    # add default values to our dictionary, being careful not to delete what we just added!
    for (k,v) in _series_defaults
        slice_arg!(d, d, k, v, commandIndex, remove_pair = false)
    end

    # this is how many series belong to this subplot
    plotIndex = count(series -> series.d[:subplot] === sp && series.d[:primary], plt.series_list)
    if get(d, :primary, true)
        plotIndex += 1
    end

    aliasesAndAutopick(d, :linestyle, _styleAliases, supported_styles(pkg), plotIndex)
    aliasesAndAutopick(d, :markershape, _markerAliases, supported_markers(pkg), plotIndex)

    # update color
    d[:seriescolor] = getSeriesRGBColor(d[:seriescolor], sp, plotIndex)

    # update colors
    for csym in (:linecolor, :markercolor, :fillcolor)
        d[csym] = if d[csym] == :match
            if has_black_border_for_default(d[:seriestype]) && csym == :linecolor
                :black
            else
                d[:seriescolor]
            end
        else
            getSeriesRGBColor(d[csym], sp, plotIndex)
        end
    end

    # update markerstrokecolor
    c = d[:markerstrokecolor]
    c = if c == :match
        sp[:foreground_color_subplot]
    else
        getSeriesRGBColor(c, sp, plotIndex)
    end
    d[:markerstrokecolor] = c

    # update alphas
    for asym in (:linealpha, :markeralpha, :fillalpha)
        if d[asym] == nothing
            d[asym] = d[:seriesalpha]
        end
    end
    if d[:markerstrokealpha] == nothing
        d[:markerstrokealpha] = d[:markeralpha]
    end

    # scatter plots don't have a line, but must have a shape
    if d[:seriestype] in (:scatter, :scatter3d)
        d[:linewidth] = 0
        if d[:markershape] == :none
            d[:markershape] = :circle
        end
    end

    # set label
    label = d[:label]
    label = (label == "AUTO" ? "y$globalIndex" : label)
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

# this is the default "type recipe"... just pass the object through
@recipe f{T<:Any}(::Type{T}, v::T) = v

# this should catch unhandled "series recipes" and error with a nice message
@recipe f{V<:Val}(::Type{V}, x, y, z) = error("The backend must not support the series type $V, and there isn't a series recipe defined.")

_apply_type_recipe(d, v) = RecipesBase.apply_recipe(d, typeof(v), v)[1].args[1]

# handle "type recipes" by converting inputs, and then either re-calling or slicing
@recipe function f(x, y, z)
    did_replace = false
    newx = _apply_type_recipe(d, x)
    x === newx || (did_replace = true)
    newy = _apply_type_recipe(d, y)
    y === newy || (did_replace = true)
    newz = _apply_type_recipe(d, z)
    z === newz || (did_replace = true)
    if did_replace
        newx, newy, newz
    else
        SliceIt, x, y, z
    end
end
@recipe function f(x, y)
    did_replace = false
    newx = _apply_type_recipe(d, x)
    x === newx || (did_replace = true)
    newy = _apply_type_recipe(d, y)
    y === newy || (did_replace = true)
    if did_replace
        newx, newy
    else
        SliceIt, x, y, nothing
    end
end
@recipe function f(y)
    newy = _apply_type_recipe(d, y)
    if y !== newy
        newy
    else
        SliceIt, nothing, y, nothing
    end
end

# if there's more than 3 inputs, it can't be passed directly to SliceIt
# so we'll apply_type_recipe to all of them
@recipe function f(v1, v2, v3, v4, vrest...)
    did_replace = false
    newargs = map(v -> begin
        newv = _apply_type_recipe(d, v)
        if newv !== v
            did_replace = true
        end
        newv
    end, (v1, v2, v3, v4, vrest...))
    if !did_replace
        error("Couldn't process recipe args: $(map(typeof, (v1, v2, v3, v4, vrest...)))")
    end
    newargs
end


# # --------------------------------------------------------------------
# # 1 argument
# # --------------------------------------------------------------------

@recipe f(n::Integer) = n, n, n

# return a surface if this is a 3d plot, otherwise let it be sliced up
@recipe function f{T<:Number}(mat::AMat{T})
    if all3D(d)
        n,m = size(mat)
        SliceIt, 1:m, 1:n, Surface(mat)
    else
        SliceIt, nothing, mat, nothing
    end
end


# # images - grays

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

# # images - colors

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

@recipe function f(shape::Shape)
    seriestype := :shape
    shape_coords(shape)
end

@recipe function f(shapes::AVec{Shape})
    seriestype := :shape
    shape_coords(shapes)
end

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

@recipe function f(x::AVec, y::AVec, z::AVec)
    # st = get(d, :seriestype, :none)
    # if st == :scatter
    #     d[:seriestype] = :scatter3d
    # elseif !is3d(st)
    #     d[:seriestype] = :path3d
    # end
    SliceIt, x, y, z
end

@recipe function f(x::AMat, y::AMat, z::AMat)
    # st = get(d, :seriestype, :none)
    # if size(x) == size(y) == size(z)
    #     if !is3d(st)
    #         seriestype := :path3d
    #     end
    # end
    SliceIt, x, y, z
end

#
# # surface-like... function

@recipe function f(x::AVec, y::AVec, zf::Function)
    # x = X <: Number ? sort(x) : x
    # y = Y <: Number ? sort(y) : y
    SliceIt, x, y, Surface(zf, x, y)  # TODO: replace with SurfaceFunction when supported
end

#
# # surface-like... matrix grid

@recipe function f(x::AVec, y::AVec, z::AMat)
    if !like_surface(get(d, :seriestype, :none))
        d[:seriestype] = :contour
    end
    SliceIt, x, y, Surface(z)
end

#
#
# # --------------------------------------------------------------------
# # Parametric functions
# # --------------------------------------------------------------------

#
# # special handling... xmin/xmax with parametric function(s)
@recipe f(f::FuncOrFuncs, xmin::Number, xmax::Number) = linspace(xmin, xmax, 100), f
@recipe f(fx::FuncOrFuncs, fy::FuncOrFuncs, u::AVec)  = mapFuncOrFuncs(fx, u), mapFuncOrFuncs(fy, u)
@recipe f(fx::FuncOrFuncs, fy::FuncOrFuncs, umin::Number, umax::Number, n = 200) = fx, fy, linspace(umin, umax, n)

#
# # special handling... 3D parametric function(s)
@recipe function f(fx::FuncOrFuncs, fy::FuncOrFuncs, fz::FuncOrFuncs, u::AVec)
    mapFuncOrFuncs(fx, u), mapFuncOrFuncs(fy, u), mapFuncOrFuncs(fz, u)
end
@recipe function f(fx::FuncOrFuncs, fy::FuncOrFuncs, fz::FuncOrFuncs, umin::Number, umax::Number, numPoints = 200)
    fx, fy, fz, linspace(umin, umax, numPoints)
end

#
#
# # --------------------------------------------------------------------
# # Lists of tuples and FixedSizeArrays
# # --------------------------------------------------------------------
#
# # if we get an unhandled tuple, just splat it in
@recipe f(tup::Tuple) = tup

#
# # (x,y) tuples
@recipe f{R1<:Number,R2<:Number}(xy::AVec{Tuple{R1,R2}}) = unzip(xy)
@recipe f{R1<:Number,R2<:Number}(xy::Tuple{R1,R2})       = [xy[1]], [xy[2]]

#
# # (x,y,z) tuples
@recipe f{R1<:Number,R2<:Number,R3<:Number}(xyz::AVec{Tuple{R1,R2,R3}}) = unzip(xyz)
@recipe f{R1<:Number,R2<:Number,R3<:Number}(xyz::Tuple{R1,R2,R3})       = [xyz[1]], [xyz[2]], [xyz[3]]

# these might be points+velocity, or OHLC or something else
@recipe f{R1<:Number,R2<:Number,R3<:Number,R4<:Number}(xyuv::AVec{Tuple{R1,R2,R3,R4}}) = get(d,:seriestype,:path)==:ohlc ? OHLC[OHLC(t...) for t in xyuv] : unzip(xyuv)
@recipe f{R1<:Number,R2<:Number,R3<:Number,R4<:Number}(xyuv::Tuple{R1,R2,R3,R4})       = [xyuv[1]], [xyuv[2]], [xyuv[3]], [xyuv[4]]


#
# # 2D FixedSizeArrays
@recipe f{T<:Number}(xy::AVec{FixedSizeArrays.Vec{2,T}}) = unzip(xy)
@recipe f{T<:Number}(xy::FixedSizeArrays.Vec{2,T})       = [xy[1]], [xy[2]]

#
# # 3D FixedSizeArrays
@recipe f{T<:Number}(xyz::AVec{FixedSizeArrays.Vec{3,T}}) = unzip(xyz)
@recipe f{T<:Number}(xyz::FixedSizeArrays.Vec{3,T})       = [xyz[1]], [xyz[2]], [xyz[3]]

#
# # --------------------------------------------------------------------
# # handle grouping
# # --------------------------------------------------------------------

# @recipe function f(groupby::GroupBy, args...)
#     for (i,glab) in enumerate(groupby.groupLabels)
#         # create a new series, with the label of the group, and an idxfilter (to be applied in slice_and_dice)
#         # TODO: use @series instead
#         @show i, glab, groupby.groupIds[i]
#         di = copy(d)
#         get!(di, :label, string(glab))
#         get!(di, :idxfilter, groupby.groupIds[i])
#         push!(series_list, RecipeData(di, args))
#     end
#     nothing
# end

# split the group into 1 series per group, and set the label and idxfilter for each
@recipe function f(groupby::GroupBy, args...)
    for (i,glab) in enumerate(groupby.groupLabels)
        @series begin
            label     --> string(glab)
            idxfilter --> groupby.groupIds[i]
            args
        end
    end
end

