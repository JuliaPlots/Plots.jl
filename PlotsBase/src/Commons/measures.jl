
const DEFAULT_BBOX = Ref(BoundingBox(0mm, 0mm, 0mm, 0mm))
const DEFAULT_MINPAD = Ref((20mm, 5mm, 2mm, 10mm))
const DEFAULT_LINEWIDTH = Ref(1)
const PLOTS_SEED = 1234
const PX_PER_INCH = 100
const DPI = PX_PER_INCH
const MM_PER_INCH = 25.4
const MM_PER_PX = MM_PER_INCH / PX_PER_INCH
const _cbar_width = 5mm

# allow pixels and percentages
const px = Measures.AbsoluteLength(0.254)
const pct = Measures.Length{:pct,Float64}(1.0)

const BBox = Measures.Absolute2DBox

to_pixels(m::AbsoluteLength) = m.value / px.value

# convert x,y coordinates from absolute coords to percentages...
# returns x_pct, y_pct
function xy_mm_to_pcts(x::AbsoluteLength, y::AbsoluteLength, figw, figh, flipy = true)
    xmm, ymm = x.value, y.value
    if flipy
        ymm = figh.value - ymm  # flip y when origin in bottom-left
    end
    xmm / figw.value, ymm / figh.value
end

# convert a bounding box from absolute coords to percentages...
# returns an array of percentages of figure size: [left, bottom, width, height]
function bbox_to_pcts(bb::BoundingBox, figw, figh, flipy = true)
    mms = Float64[f(bb).value for f ∈ (left, bottom, width, height)]
    if flipy
        mms[2] = figh.value - mms[2]  # flip y when origin in bottom-left
    end
    mms ./ Float64[figw.value, figh.value, figw.value, figh.value]
end

Base.show(io::IO, bbox::BoundingBox) = print(
    io,
    "BBox{l,t,r,b,w,h = $(left(bbox)),$(top(bbox)), $(right(bbox)),$(bottom(bbox)), $(width(bbox)),$(height(bbox))}",
)

# Base.:*{T,N}(m1::Length{T,N}, m2::Length{T,N}) = Length{T,N}(m1.value * m2.value)
ispositive(m::Measure) = m.value > 0

# union together bounding boxes
function Base.:+(bb1::BoundingBox, bb2::BoundingBox)
    # empty boxes don't change the union
    ispositive(width(bb1)) || return bb2
    ispositive(height(bb1)) || return bb2
    ispositive(width(bb2)) || return bb1
    ispositive(height(bb2)) || return bb1

    l = min(left(bb1), left(bb2))
    t = min(top(bb1), top(bb2))
    r = max(right(bb1), right(bb2))
    b = max(bottom(bb1), bottom(bb2))
    BoundingBox(l, t, r - l, b - t)
end

Base.convert(::Type{<:Measure}, x::Float64) = x * pct

Base.:*(m1::AbsoluteLength, m2::Length{:pct}) = AbsoluteLength(m1.value * m2.value)
Base.:*(m1::Length{:pct}, m2::AbsoluteLength) = AbsoluteLength(m2.value * m1.value)
Base.:/(m1::AbsoluteLength, m2::Length{:pct}) = AbsoluteLength(m1.value / m2.value)
Base.:/(m1::Length{:pct}, m2::AbsoluteLength) = AbsoluteLength(m2.value / m1.value)

inch2px(inches::Real) = float(inches * PX_PER_INCH)
px2inch(px::Real)     = float(px / PX_PER_INCH)
inch2mm(inches::Real) = float(inches * MM_PER_INCH)
mm2inch(mm::Real)     = float(mm / MM_PER_INCH)
px2mm(px::Real)       = float(px * MM_PER_PX)
mm2px(mm::Real)       = float(mm / MM_PER_PX)
