# ensure we dispatch to the slicer
struct SliceIt end

# the catch-all recipes
@recipe function f(::Type{SliceIt}, x, y, z)

    # handle data with formatting attached
    if typeof(x) <: Formatted
        xformatter := x.formatter
        x = x.data
    end
    if typeof(y) <: Formatted
        yformatter := y.formatter
        y = y.data
    end
    if typeof(z) <: Formatted
        zformatter := z.formatter
        z = z.data
    end

    xs = convertToAnyVector(x, plotattributes)
    ys = convertToAnyVector(y, plotattributes)
    zs = convertToAnyVector(z, plotattributes)


    fr = pop!(plotattributes, :fillrange, nothing)
    fillranges = process_fillrange(fr, plotattributes)
    mf = length(fillranges)

    rib = pop!(plotattributes, :ribbon, nothing)
    ribbons = process_ribbon(rib, plotattributes)
    mr = length(ribbons)

    # @show zs

    mx = length(xs)
    my = length(ys)
    mz = length(zs)
    if mx > 0 && my > 0 && mz > 0
        for i in 1:max(mx, my, mz)
            # add a new series
            di = copy(plotattributes)
            xi, yi, zi = xs[mod1(i,mx)], ys[mod1(i,my)], zs[mod1(i,mz)]
            di[:x], di[:y], di[:z] = compute_xyz(xi, yi, zi)

            # handle fillrange
            fr = fillranges[mod1(i,mf)]
            di[:fillrange] = isa(fr, Function) ? map(fr, di[:x]) : fr

            # handle ribbons
            rib = ribbons[mod1(i,mr)]
            di[:ribbon] = isa(rib, Function) ? map(rib, di[:x]) : rib

            push!(series_list, RecipeData(di, ()))
        end
    end
    nothing  # don't add a series for the main block
end

# this is the default "type recipe"... just pass the object through
@recipe f(::Type{T}, v::T) where {T<:Any} = v

# this should catch unhandled "series recipes" and error with a nice message
@recipe f(::Type{V}, x, y, z) where {V<:Val} = error("The backend must not support the series type $V, and there isn't a series recipe defined.")
