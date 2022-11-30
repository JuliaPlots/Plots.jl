# Run tests with `import RecipesBase as RB` instead of `using RecipesBase`
# or `import RecipesBase` to test that macros do not depend on the
# namespace of the enclosing scope.
import RecipesBase as RB
using StableRNGs
using Test

const KW = Dict{Symbol,Any}

RB.is_key_supported(k::Symbol) = true

for t in map(i -> Symbol(:T, i), 1:5)
    @eval struct $t end
end

struct Dummy end

RB.@recipe function plot(t::Dummy, args...) end

@testset "coverage" begin
    @test !RB.group_as_matrix(nothing)
    @test RB.apply_recipe(KW(:foo => 1)) == ()

    @test RB.to_symbol(:x) ≡ :x
    @test RB.to_symbol(QuoteNode(:x)) ≡ :x

    @test RB._equals_symbol(:x, :x)
    @test RB._equals_symbol(QuoteNode(:x), :x)
    @test !RB._equals_symbol(nothing, :x)

    @test RB.gettypename(:x) ≡ :x
    @test RB.gettypename(:(Foo{T})) ≡ :Foo

    RB.recipetype(::Val{:Dummy}, args...) = nothing
    @test RB.recipetype(:Dummy, 1:10) isa Nothing
    @test_throws ErrorException RB.recipetype(:NotDefined)
end

@testset "layout" begin
    grid(x, y) = (x, y)  # fake `grid` function for `Plots`
    @test RB.@layout([a b; c]) isa Matrix
    @test RB.@layout([a{0.3w}; b{0.2h}]) isa Matrix
    @test RB.@layout([a{0.3w} [grid(3, 3); b{0.2h}]]) isa Matrix
    @test RB.@layout([_ ° _; ° ° °; ° ° °]) isa Matrix
end

@testset "@recipe" begin
    """
    make sure the attribute dictionary was populated correctly,
    and the returned arguments are as expected
    """
    function check_apply_recipe(T::DataType, expect)
        # this is similar to how Plots would call the method
        plotattributes = KW(:customcolor => :red)

        data_list = RB.apply_recipe(plotattributes, T(), 2)
        @test data_list[1].args == (rand(StableRNG(1), 10, 2),)
        @test plotattributes == expect
    end

    @testset "simple parametric type" begin
        @test_throws MethodError RB.apply_recipe(KW(), T1())

        RB.@recipe function plot(t::T1, n::N = 1; customcolor = :green) where {N<:Integer}
            :markershape --> :auto, :require
            :markercolor --> customcolor, :force
            :xrotation --> 5
            :zrotation --> 6, :quiet
            rand(StableRNG(1), 10, n)
        end

        check_apply_recipe(
            T1,
            KW(
                :customcolor => :red,
                :markershape => :auto,
                :markercolor => :red,
                :xrotation => 5,
                :zrotation => 6,
            ),
        )
    end

    @testset "parametric type with where" begin
        @test_throws MethodError RB.apply_recipe(KW(), T2())

        RB.@recipe function plot(t::T2, n::N = 1; customcolor = :green) where {N<:Integer}
            :markershape --> :auto, :require
            :markercolor --> customcolor, :force
            :xrotation --> 5
            :zrotation --> 6, :quiet
            rand(StableRNG(1), 10, n)
        end

        check_apply_recipe(
            T2,
            KW(
                :customcolor => :red,
                :markershape => :auto,
                :markercolor => :red,
                :xrotation => 5,
                :zrotation => 6,
            ),
        )
    end

    @testset "parametric type with double where" begin
        @test_throws MethodError RB.apply_recipe(KW(), T3())

        RB.@recipe function plot(
            t::T3,
            n::N = 1,
            m::M = 0.0;
            customcolor = :green,
        ) where {N<:Integer} where {M<:Float64}
            :markershape --> :auto, :require
            :markercolor --> customcolor, :force
            :xrotation --> 5
            :zrotation --> 6, :quiet
            rand(StableRNG(1), 10, n)
        end

        check_apply_recipe(
            T3,
            KW(
                :customcolor => :red,
                :markershape => :auto,
                :markercolor => :red,
                :xrotation => 5,
                :zrotation => 6,
            ),
        )
    end

    @testset "manual access of plotattributes" begin
        @test_throws MethodError RB.apply_recipe(KW(), T4())

        RB.@recipe function plot(t::T4, n = 1; customcolor = :green)
            :markershape --> :auto, :require
            :markercolor --> customcolor, :force
            :xrotation --> 5
            :zrotation --> 6, :quiet
            plotattributes[:hello] = "hi"
            plotattributes[:world] = "world"
            rand(StableRNG(1), 10, n)
        end
        check_apply_recipe(
            T4,
            KW(
                :customcolor => :red,
                :markershape => :auto,
                :markercolor => :red,
                :xrotation => 5,
                :zrotation => 6,
                :hello => "hi",
                :world => "world",
            ),
        )
    end

    @testset "no force" begin
        @test_throws MethodError RB.apply_recipe(KW(), T5())

        RB.@recipe function plot(t::T5, n::Integer = 1)
            customcolor --> :notred
            rand(StableRNG(1), 10, n)
        end

        check_apply_recipe(T5, KW(:customcolor => :red))
    end
end  # @testset "@recipe"

# Can't do this inside a test-set, because it creates a struct.
RB.@userplot MyPlot

@testset "@userplot" begin
    @test typeof(myplot) <: Function
    @test length(methods(myplot)) == 1
    @test typeof(myplot!) <: Function
    @test length(methods(myplot!)) == 2
    m = MyPlot(:my_arg)
    @test m.args ≡ :my_arg
end
