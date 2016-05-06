using RecipesBase
using Base.Test

srand(1)
RecipesBase.is_key_supported(k::Symbol) = true

type T end

@recipe function plot{N<:Integer}(t::T, n::N = 1; customcolor = :green)
    :markershape --> :auto, :require
    :markercolor --> customcolor, :force
    :xrotation --> 5
    :zrotation --> 6, :quiet
    rand(10,n)
end

# this is similar to how Plots would call the method
typealias KW Dict{Symbol,Any}
d = KW()
kw = KW(:customcolor => :red)
args = RecipesBase.apply_recipe(d, kw, T(), 2; issubplot = false)

# make sure the attribute dictionary was populated correctly, and the returned arguments are as expected
@test args == (srand(1); (rand(10,2),))
@test d == KW(
    :markershape => :auto,
    :markercolor => :red,
    :xrotation => 5,
    :zrotation => 6
)
