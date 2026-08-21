# Run tests with `import RecipesBase as RB` instead of `using RecipesBase`
# or `import RecipesBase` to test that macros do not depend on the
# namespace of the enclosing scope.
import RecipesBase as RB
using StableRNGs
using Test

const KW = Dict{Symbol, Any}

RB.is_key_supported(k::Symbol) = true

for t in map(i -> Symbol(:T, i), 1:7)
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

        RB.@recipe function plot(t::T1, n::N = 1; customcolor = :green) where {N <: Integer}
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

        RB.@recipe function plot(t::T2, n::N = 1; customcolor = :green) where {N <: Integer}
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
            ) where {N <: Integer} where {M <: Float64}
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

@testset "attribute reads" begin
    # `plotattributes` is only bound inside a recipe, so exercise the rewriter directly
    walk(str) = (ex = Meta.parse("begin\n$str\nend"); RB.process_recipe_body!(ex); ex)
    unchanged(str) = walk(str) == Meta.parse("begin\n$str\nend")

    @testset "`\$` and `<--` read an attribute" begin
        RB.canonical_key(k::Symbol) = k ≡ :mycolor ? :markercolor : k

        RB.@recipe function plot(t::T6, n::Integer = 1)
            :xrotation --> $markercolor          # read on the right of an arrow
            lw = $mycolor                        # read through an alias
            war <-- :markershape                 # the binary form
            :zrotation --> something($xrotation, 0)  # read as a call argument
            :yrotation --> lw
            :markershape --> war
            rand(StableRNG(1), 10, n)
        end

        plotattributes = KW(:markercolor => :red, :xrotation => 5, :markershape => :auto)
        RB.apply_recipe(plotattributes, T6(), 2)
        @test plotattributes[:xrotation] == 5      # `--> ` does not override an explicit value
        @test plotattributes[:zrotation] == 5      # `$xrotation` was read, then written through
        @test plotattributes[:yrotation] ≡ :red    # `$mycolor` resolved to `markercolor`
        @test plotattributes[:markershape] ≡ :auto # `war <-- :markershape`
    end

    @testset "`\$` inside quoted code is left alone" begin
        # `$` already means interpolation inside a quote, so none of these are ours.
        # the arrow itself is still rewritten, but the quoted key survives verbatim:
        # this is the `RecipesPipeline` grouping idiom for a key computed at run time
        @test walk(":(\$key) := split_attribute(plt, key, val, idx)") ==
            Meta.parse("begin\nplotattributes[:(\$key)] = split_attribute(plt, key, val, idx)\nend")
        @test unchanged("ex = :(y = \$val)")
        @test unchanged("ex = quote z = \$val end")
        @test unchanged("ex = :(f(\$(g(u))))")
        @test unchanged("ex = :(:(\$(\$x)))")
        # macros quote implicitly, so `$` under one is theirs, not ours
        @test unchanged("@eval myfun(::\$T) = 1")
        @test unchanged("@btime f(\$x)")
        # ordinary string interpolation never produces an `Expr(:\$)` in the first place
        @test unchanged("plotattributes[:hello] = \"\$var\"")
        @test unchanged("run(`convert \$infile \$outfile`)")
        # ... but `@series` is ours, so reads inside it still work
        @test !unchanged("@series begin lc = \$linecolor end")
    end

    @testset "`return` is not mangled" begin
        # the walk must tolerate a non-`Expr` replacing the `return` it strips
        for payload in ("z", "", ":auto", "(a, b)", "\$markercolor")
            @test walk("return $payload") isa Expr
        end

        RB.@recipe function plot(t::T7, n::Integer = 1)
            :markercolor --> :red, :force
            return rand(StableRNG(1), 10, n)
        end
        plotattributes = KW()
        data_list = RB.apply_recipe(plotattributes, T7(), 2)
        @test data_list[1].args == (rand(StableRNG(1), 10, 2),)
        @test plotattributes[:markercolor] ≡ :red
    end

    @testset "a computed key errors at expansion time" begin
        @test_throws ErrorException walk("c = \$(:markershape)")
        @test_throws ErrorException walk("c = \$(get_key(u))")
    end
end

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
