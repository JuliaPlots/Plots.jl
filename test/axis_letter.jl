
@testset "axis letter" begin
    using Plots, RecipesBase
    # a custom type for dispacthing the axis-letter-testing recipe
    struct MyType <: Number
        val::Float64
    end
    value(m::MyType) = m.val
    data = MyType.(sort(randn(20)))
    # A recipe that puts the axis letter in the title
    @recipe function f(::Type{T}, m::T) where T <: AbstractArray{<:MyType}
        title --> string(plotattributes[:letter])
        value.(m)
    end
    @testset "$f (orientation = $o)" for f in [histogram, barhist, stephist, scatterhist], o in [:vertical, :horizontal]
        @test f(data, orientation=o).subplots[1].attr[:title] == (o == :vertical ? "x" : "y")
    end
    @testset "$f" for f in [hline, hspan]
        @test f(data).subplots[1].attr[:title] == "y"
    end
    @testset "$f" for f in [vline, vspan]
        @test f(data).subplots[1].attr[:title] == "x"
    end
end