using Plots, Test

@testset "Subplot sclicing" begin
    pl = @test_nowarn plot(rand(4,8), layout=4, yscale=[:identity :identity :log10 :log10])
    @test pl[1][:yaxis][:scale] == :identity
    @test pl[2][:yaxis][:scale] == :identity
    @test pl[3][:yaxis][:scale] == :log10
    @test pl[4][:yaxis][:scale] == :log10
end
