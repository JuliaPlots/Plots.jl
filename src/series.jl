# --------------------------------------------------------------------
# 1 argument
# --------------------------------------------------------------------

# images - grays
function clamp_greys!(mat::AMat{<:Gray})
    for i in eachindex(mat)
        mat[i].val < 0 && (mat[i] = Gray(0))
        mat[i].val > 1 && (mat[i] = Gray(1))
    end
    mat
end

@recipe function f(mat::AMat{<:Gray})
    n, m = axes(mat)
    if is_seriestype_supported(:image)
        seriestype := :image
        yflip --> true
        SliceIt, m, n, Surface(clamp_greys!(mat))
    else
        seriestype := :heatmap
        yflip --> true
        cbar --> false
        fillcolor --> ColorGradient([:black, :white])
        SliceIt, m, n, Surface(clamp!(convert(Matrix{Float64}, mat), 0.0, 1.0))
    end
end

# images - colors
@recipe function f(mat::AMat{T}) where {T <: Colorant}
    n, m = axes(mat)

    if is_seriestype_supported(:image)
        seriestype := :image
        yflip --> true
        SliceIt, m, n, Surface(mat)
    else
        seriestype := :heatmap
        yflip --> true
        cbar --> false
        aspect_ratio --> :equal
        z, plotattributes[:fillcolor] = replace_image_with_heatmap(mat)
        SliceIt, m, n, Surface(z)
    end
end

# plotting arbitrary shapes/polygons

@recipe function f(shape::Shape)
    seriestype --> :shape
    coords(shape)
end

@recipe function f(shapes::AVec{Shape})
    seriestype --> :shape
    coords(shapes)
end

@recipe function f(shapes::AMat{Shape})
    seriestype --> :shape
    for j in axes(shapes, 2)
        @series coords(vec(shapes[:, j]))
    end
end


# --------------------------------------------------------------------
# 3 arguments
# --------------------------------------------------------------------

# images - grays
@recipe function f(x::AVec, y::AVec, mat::AMat{T}) where {T <: Gray}
    if is_seriestype_supported(:image)
        seriestype := :image
        yflip --> true
        SliceIt, x, y, Surface(mat)
    else
        seriestype := :heatmap
        yflip --> true
        cbar --> false
        fillcolor --> ColorGradient([:black, :white])
        SliceIt, x, y, Surface(convert(Matrix{Float64}, mat))
    end
end

# images - colors
@recipe function f(x::AVec, y::AVec, mat::AMat{T}) where {T <: Colorant}
    if is_seriestype_supported(:image)
        seriestype := :image
        yflip --> true
        SliceIt, x, y, Surface(mat)
    else
        seriestype := :heatmap
        yflip --> true
        cbar --> false
        z, plotattributes[:fillcolor] = replace_image_with_heatmap(mat)
        SliceIt, x, y, Surface(z)
    end
end

# --------------------------------------------------------------------
# Lists of tuples and GeometryTypes.Points
# --------------------------------------------------------------------
@recipe f(v::AVec{<:GeometryTypes.Point}) = unzip(v)
@recipe f(p::GeometryTypes.Point) = [p]

# Special case for 4-tuples in :ohlc series
@recipe f(xyuv::AVec{<:Tuple{R1, R2, R3, R4}}) where {R1, R2, R3, R4} =
    get(plotattributes, :seriestype, :path) == :ohlc ? OHLC[OHLC(t...) for t in xyuv] :
    unzip(xyuv)
