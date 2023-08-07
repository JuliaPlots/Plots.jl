module Surfaces

export SurfaceFunction

import Plots: Plots, Axis, Surface, AbstractSurface
import Plots: expand_extrema!

function Plots.expand_extrema!(a::Axis, surf::Surface)
    ex = a[:extrema]
    foreach(x -> expand_extrema!(ex, x), surf.surf)
    ex
end

"For the case of representing a surface as a function of x/y... can possibly avoid allocations."
struct SurfaceFunction <: AbstractSurface
    f::Function
end

end
