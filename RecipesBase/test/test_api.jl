using RecipesBase, Test

@testset "Cycling attributes" begin
    c1 = cycle([:red, :green])
    @test c1[1] == :red
    @test c1[2] == :green
    @test c1[3] == :red
    @test c1[4] == :green
    c2 = cycle([:red :green; :blue :yellow])
    @test c2[1] == :red
    @test c2[2] == :blue
    @test c2[3] == :green
    @test c2[4] == :yellow
    @test c2[5] == :red
    @test c2[6] == :blue
    @test c2[7] == :green
    @test c2[8] == :yellow
    @test c2[1, :] == [:red, :green]
    @test c2[:, 1] == [:red, :blue]
    @test c2[3, :] == [:red, :green]
    @test c2[:, 3] == [:red, :blue]
end
