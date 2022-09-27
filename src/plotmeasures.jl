module PlotMeasures

import ..Measures
import ..Measures:
    Length, AbsoluteLength, Measure, BoundingBox, mm, cm, inch, pt, width, height, w, h

const BBox = Measures.Absolute2DBox
export BBox, BoundingBox, mm, cm, inch, px, pct, pt, w, h

# allow pixels and percentages
const px = AbsoluteLength(0.254)
const pct = Length{:pct,Float64}(1.0)

Base.convert(::Type{<:Measure}, x::Float64) = x * pct

Base.:*(m1::AbsoluteLength, m2::Length{:pct}) = AbsoluteLength(m1.value * m2.value)
Base.:*(m1::Length{:pct}, m2::AbsoluteLength) = AbsoluteLength(m2.value * m1.value)
Base.:/(m1::AbsoluteLength, m2::Length{:pct}) = AbsoluteLength(m1.value / m2.value)
Base.:/(m1::Length{:pct}, m2::AbsoluteLength) = AbsoluteLength(m2.value / m1.value)

end
