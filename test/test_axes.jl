using Plots, Test

@testset "Showaxis" begin
    @test plot(1:5, showaxis = :y)[1][:yaxis][:showaxis] == true
end
