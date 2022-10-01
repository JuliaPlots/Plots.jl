# Run tests with `import RecipesBase` instead of `using RecipesBase` to test
# that objects like `AbstractPlot` are properly prefixed with `RecipesBase.` in
# the macros.
import RecipesBase
using Test, Random

const KW = Dict{Symbol, Any}

RecipesBase.is_key_supported(k::Symbol) = true

for t in [Symbol(:T, i) for i in 1:5]
    @eval struct $t end
end


@testset "@recipe" begin


"""
make sure the attribute dictionary was populated correctly,
and the returned arguments are as expected
"""
function check_apply_recipe(T::DataType, expect)
    # this is similar to how Plots would call the method
    plotattributes = KW(:customcolor => :red)

    data_list = RecipesBase.apply_recipe(plotattributes, T(), 2)
    @test data_list[1].args == (Random.seed!(1); (rand(10,2),))
    @test plotattributes == expect
end


@testset "simple parametric type" begin
    @test_throws MethodError RecipesBase.apply_recipe(KW(), T1())

    RecipesBase.@recipe function plot(t::T1, n::N = 1; customcolor = :green) where N <: Integer
        :markershape --> :auto, :require
        :markercolor --> customcolor, :force
        :xrotation --> 5
        :zrotation --> 6, :quiet
        rand(10, n)
    end

    Random.seed!(1)
    check_apply_recipe(T1, KW(
        :customcolor => :red,
        :markershape => :auto,
        :markercolor => :red,
        :xrotation => 5,
        :zrotation => 6))
end


@testset "parametric type with where" begin
    @test_throws MethodError RecipesBase.apply_recipe(KW(), T2())

    RecipesBase.@recipe function plot(t::T2, n::N = 1; customcolor = :green) where {N <: Integer}
        :markershape --> :auto, :require
        :markercolor --> customcolor, :force
        :xrotation --> 5
        :zrotation --> 6, :quiet
        rand(10, n)
    end

    Random.seed!(1)
    check_apply_recipe(T2, KW(
        :customcolor => :red,
        :markershape => :auto,
        :markercolor => :red,
        :xrotation => 5,
        :zrotation => 6))
end


@testset "parametric type with double where" begin
    @test_throws MethodError RecipesBase.apply_recipe(KW(), T3())

    RecipesBase.@recipe function plot(
            t::T3, n::N = 1, m::M = 0.0; customcolor = :green
    ) where {N <: Integer} where {M <: Float64}
        :markershape --> :auto, :require
        :markercolor --> customcolor, :force
        :xrotation --> 5
        :zrotation --> 6, :quiet
        rand(10, n)
    end

    Random.seed!(1)
    check_apply_recipe(T3, KW(
        :customcolor => :red,
        :markershape => :auto,
        :markercolor => :red,
        :xrotation => 5,
        :zrotation => 6))
end


@testset "manual access of plotattributes" begin
    @test_throws MethodError RecipesBase.apply_recipe(KW(), T4())

    RecipesBase.@recipe function plot(t::T4, n = 1; customcolor = :green)
        :markershape --> :auto, :require
        :markercolor --> customcolor, :force
        :xrotation --> 5
        :zrotation --> 6, :quiet
        plotattributes[:hello] = "hi"
        plotattributes[:world] = "world"
        rand(10,n)
    end
    Random.seed!(1)
    check_apply_recipe(T4, KW(
    :customcolor => :red,
    :markershape => :auto,
    :markercolor => :red,
    :xrotation => 5,
    :zrotation => 6,
    :hello => "hi",
    :world => "world"
   ))
end

@testset "no force" begin
    @test_throws MethodError RecipesBase.apply_recipe(KW(), T5())

    RecipesBase.@recipe function plot(t::T5, n::Integer = 1)
        customcolor --> :notred
        rand(10, n)
    end

    Random.seed!(1)
    check_apply_recipe(T5, KW(:customcolor => :red))
end


end  # @testset "@recipe"

# Can't do this inside a test-set, because it creates a struct.
RecipesBase.@userplot MyPlot

@testset "@userplot" begin
    @test typeof(myplot) <: Function
    @test length(methods(myplot)) == 1
    @test typeof(myplot!) <: Function
    @test length(methods(myplot!)) == 2
    m = MyPlot(:my_arg)
    @test m.args == :my_arg
end
