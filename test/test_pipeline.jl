using Plots, Test
using RecipesPipeline

@testset "plot" begin
    pl = plot(1:5)
    pl2 = plot(pl, tex_output_standalone = true)
    @test pl[:tex_output_standalone] == false
    @test pl2[:tex_output_standalone] == true
    plot!(pl, tex_output_standalone = true)
    @test pl[:tex_output_standalone] == true
end

@testset "get_axis_limits" begin
    x = [0.1, 5]
    p1 = plot(x, [5, 0.1], yscale = :log10)
    p2 = plot!(identity)
    @test all(RecipesPipeline.get_axis_limits(p1, :x) .== x)
    @test all(RecipesPipeline.get_axis_limits(p2, :x) .== x)
end

@testset "Slicing" begin
    @test plot(1:5, fillrange = 0)[1][1][:fillrange] == 0
    data4 = rand(4, 4)
    mat = reshape(1:8, 2, 4)
    for i in axes(data4, 1)
        for attribute in (:fillrange, :ribbon)
            @test plot(data4; NamedTuple{tuple(attribute)}(0)...)[1][i][attribute] == 0
            @test plot(data4; NamedTuple{tuple(attribute)}(Ref([1, 2]))...)[1][i][attribute] ==
                  [1.0, 2.0]
            @test plot(data4; NamedTuple{tuple(attribute)}(Ref([1 2]))...)[1][i][attribute] ==
                  (iseven(i) ? 2 : 1)
            @test plot(data4; NamedTuple{tuple(attribute)}(Ref(mat))...)[1][i][attribute] ==
                  [2(i - 1) + 1, 2i]
        end
        @test plot(data4, ribbon = (mat, mat))[1][i][:ribbon] == ([2(i - 1) + 1, 2i], [2(i - 1) + 1, 2i])
    end
end
