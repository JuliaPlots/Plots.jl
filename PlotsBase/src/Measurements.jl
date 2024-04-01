module Measurements

export DEFAULT_BBOX, DEFAULT_MINPAD, DEFAULT_LINEWIDTH
export PX_PER_INCH, DPI, MM_PER_INCH, MM_PER_PX
export Length, AbsoluteLength, Measure, width, height

import ..Measures
import ..Measures: Length, AbsoluteLength, Measure, BoundingBox
import ..Measures: mm, cm, inch, pt, width, height, w, h

const BBox = Measures.Absolute2DBox
export BBox, BoundingBox, mm, cm, inch, px, pct, pt, w, h

# allow pixels and percentages
const px = AbsoluteLength(0.254)
const pct = Length{:pct,Float64}(1.0)

const PX_PER_INCH = 100
const DPI = PX_PER_INCH
const MM_PER_INCH = 25.4
const MM_PER_PX = MM_PER_INCH / PX_PER_INCH
const _cbar_width = 5mm
const DEFAULT_BBOX = Ref(BoundingBox(0mm, 0mm, 0mm, 0mm))
const DEFAULT_MINPAD = Ref((20mm, 5mm, 2mm, 10mm))
const DEFAULT_LINEWIDTH = Ref(1)

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

end  # module
