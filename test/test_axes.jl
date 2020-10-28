using Plots, Test

@testset "Showaxis" begin
    for value in Plots._allShowaxisArgs
        @test plot(1:5, showaxis = value)[1][:yaxis][:showaxis] isa Bool
    end
    @test plot(1:5, showaxis = :y)[1][:yaxis][:showaxis] == true
    @test plot(1:5, showaxis = :y)[1][:xaxis][:showaxis] == false
end

@testset "Magic axis" begin
    @test plot(1, axis=nothing)[1][:xaxis][:ticks] == []
    @test plot(1, axis=nothing)[1][:yaxis][:ticks] == []
end # testset

@testset "Categorical ticks" begin
    p1 = plot('A':'M', 1:13)
    p2 = plot('A':'Z', 1:26)
    p3 = plot('A':'Z', 1:26, ticks = :all)
    @test Plots.get_ticks(p1[1], p1[1][:xaxis])[2] == string.('A':'M')
    @test Plots.get_ticks(p2[1], p2[1][:xaxis])[2] == string.('C':3:'Z')
    @test Plots.get_ticks(p3[1], p3[1][:xaxis])[2] == string.('A':'Z')
end
