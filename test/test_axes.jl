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

@testset "Ticks getter functions" begin
    ticks1 = ([1,2,3], ("a","b","c"))
    ticks2 = ([4,5], ("e","f"))
    p1 = plot(1:5, 1:5, 1:5, xticks=ticks1, yticks=ticks1, zticks=ticks1)
    p2 = plot(1:5, 1:5, 1:5, xticks=ticks2, yticks=ticks2, zticks=ticks2)
    p = plot(p1, p2)
    @test xticks(p) == yticks(p) == zticks(p) == [ticks1, ticks2]
    @test xticks(p[1]) == yticks(p[1]) == zticks(p[1]) == ticks1
end

@testset "Axis limits" begin
    pl = plot(1:5, xlims=:symmetric, widen = false)
    @test Plots.xlims(pl) == (-5, 5)
    
    pl = plot(1:3)
    @test Plots.xlims(pl) == Plots.widen(1,3)
    
    pl = plot(1:3, xlims=:round)
    @test Plots.xlims(pl) == (1, 3)
    
    pl = plot(1:3, xlims=(1,5))
    @test Plots.xlims(pl) == (1, 5)

    pl = plot(1:3, xlims=(1,5), widen=true)
    @test Plots.xlims(pl) == Plots.widen(1, 5)
end

@testset "3D Axis" begin
    ql = quiver([1, 2], [2, 1], [3, 4], quiver = ([1, -1], [0, 0], [1, -0.5]), arrow=true)
    @test ql[1][:projection] == "3d"
end
