module GeometryBasicsExt

import Plots: Plots, @ext_imp_use, @recipe
import RecipesPipeline
import Unzip

@ext_imp_use :import GeometryBasics

RecipesPipeline.unzip(points::AbstractVector{<:GeometryBasics.Point}) =
    Unzip.unzip(Tuple.(points))
RecipesPipeline.unzip(points::AbstractVector{GeometryBasics.Point{N,T}}) where {N,T} =
    isbitstype(T) && sizeof(T) > 0 ? Unzip.unzip(reinterpret(NTuple{N,T}, points)) :
    Unzip.unzip(Tuple.(points))
# -----------------------------------------
# Lists of tuples and GeometryBasics.Points
# -----------------------------------------
@recipe f(v::Plots.AVec{<:GeometryBasics.Point}) = RecipesPipeline.unzip(v)
@recipe f(p::GeometryBasics.Point) = [p]  # Special case for 4-tuples in :ohlc series

end  # module
