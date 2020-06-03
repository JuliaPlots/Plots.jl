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
