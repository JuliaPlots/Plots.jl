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
d = KW(:customcolor => :red)
data_list = RecipesBase.apply_recipe(d, T(), 2)

# make sure the attribute dictionary was populated correctly, and the returned arguments are as expected
@test data_list[1].args == (srand(1); (rand(10,2),))
@test d == KW(
	:customcolor => :red,
    :markershape => :auto,
    :markercolor => :red,
    :xrotation => 5,
    :zrotation => 6
)
