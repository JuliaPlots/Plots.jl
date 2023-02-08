module GeometryBasicsExt
import Plots
import Unzip
Plots.@ext_imp_use :import GeometryBasics

Plots.RecipesPipeline.unzip(points::AbstractVector{<:GeometryBasics.Point}) =
    Unzip.unzip(Tuple.(points))
Plots.RecipesPipeline.unzip(points::AbstractVector{GeometryBasics.Point{N,T}}) where {N,T} =
    isbitstype(T) && sizeof(T) > 0 ? Unzip.unzip(reinterpret(NTuple{N,T}, points)) :
    Unzip.unzip(Tuple.(points))
# -----------------------------------------
# Lists of tuples and GeometryBasics.Points
# -----------------------------------------
Plots.@recipe f(v::AVec{<:GeometryBasics.Point}) = RecipesPipeline.unzip(v)
Plots.@recipe f(p::GeometryBasics.Point) = [p]  # Special case for 4-tuples in :ohlc series
end
