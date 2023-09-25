module Surfaces

export SurfaceFunction, Surface

using Plots: Plots, Axis
using RecipesPipeline: AbstractSurface, Surface
using Plots.Commons
import Plots: expand_extrema!, Commons


function Plots.expand_extrema!(a::Axis, surf::Surface)
    ex = a[:extrema]
    foreach(x -> expand_extrema!(ex, x), surf.surf)
    ex
end

"For the case of representing a surface as a function of x/y... can possibly avoid allocations."
struct SurfaceFunction <: AbstractSurface
    f::Function
end

Commons.handle_surface(z::Surface) = permutedims(z.surf)
end
