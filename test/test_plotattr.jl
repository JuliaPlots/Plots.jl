using Plots, Test

tplot = plot(
    repeat([1:5, 2:6], inner = 3),
    layout = @layout([a b; c]),
    this = :that,
    line = (5, :dash),
    title = ["A" "B"],
    xlims = [:auto (0, Inf)],
)
@testset "Get attributes" begin
    @testset "From Plot" begin
        @test getattr(tplot, :size) == default(:size) == getattr(tplot, :sizes)
        @test getattr(tplot, :linestyle) == permutedims(fill(:dash, 6))
        @test getattr(tplot, :title) == ["A" "B" "A"]
        @test getattr(tplot, :xlims) == [:auto (0, Inf) :auto] #Note: this is different from Plots.xlims.(tplot.subplots)
        @test getattr(tplot, :lims) == [
            (xaxis = :auto, yaxis = :auto, zaxis = :auto),
            (xaxis = (0, Inf), yaxis = :auto, zaxis = :auto),
            (xaxis = :auto, yaxis = :auto, zaxis = :auto),
        ]
        @test getattr(tplot, :this) == Dict(
            :series =>
                [1 => :that, 2 => :that, 3 => :that, 4 => :that, 5 => :that, 6 => :that],
            :subplots => Any[],
            :plot => Any[],
        )
        @test (@test_logs (
            :info,
            r"line is a magic argument",
        ) getattr(tplot, :line)) === missing
        @test_throws ArgumentError getattr(tplot, :nothere)
    end
    @testset "From Sublot" begin
        sp = tplot[2]
        @test getattr(sp, :size) == default(:size) == getattr(sp, :sizes)
        @test getattr(sp, :linestyle) == permutedims(fill(:dash, 2))
        @test getattr(sp, :title) == "B"
        @test getattr(sp, :xlims) == (0, Inf)
        @test getattr(sp, :lims) == [
            (xaxis = (0, Inf), yaxis = :auto, zaxis = :auto),
        ]
        @test_broken getattr(sp, :this) == Dict(
            :series =>
                [2 => :that, 5 => :that], # TODO: would be good if Series knew their ID
            :subplots => Any[],
            :plot => Any[],
        )
        @test (@test_logs (
            :info,
            r"line is a magic argument",
        ) getattr(sp, :line)) === missing
        @test_throws ArgumentError getattr(sp, :nothere)
    end
    @testset "From Axis" begin
        axis = tplot[3][:yaxis]
        @test getattr(axis, :size) == default(:size) == getattr(axis, :sizes)
        @test getattr(axis, :linestyle) == permutedims(fill(:dash, 2))
        @test getattr(axis, :title) == "A"
        @test getattr(axis, :xlims) === :auto # TODO: is this expected?
        @test getattr(axis, :lims) == :auto
        @test_broken getattr(axis, :this) == Dict(
            :series =>
                [3 => :that, 6 => :that], # TODO: would be good if Series knew their ID
            :subplots => Any[],
            :plot => Any[],
        )
        @test (@test_logs (
            :info,
            r"line is a magic argument",
        ) getattr(axis, :line)) === missing
        @test_throws ArgumentError getattr(axis, :nothere)
    end
    @testset "From Series" begin
        series = tplot[1][1]
        @test getattr(series, :size) == default(:size) == getattr(series, :sizes)
        @test getattr(series, :linestyle) == :dash
        @test getattr(series, :title) == "A"
        @test getattr(series, :xlims) == :auto
        @test getattr(series, :lims) == [
            (xaxis = :auto, yaxis = :auto, zaxis = :auto),
        ]
        @test_broken getattr(series, :this) == Dict(
            :series =>
                [1 => :that, 4 => :that], # TODO: would be good if Series knew their ID
            :subplots => Any[],
            :plot => Any[],
        )
        @test (@test_logs (
            :info,
            r"line is a magic argument",
        ) getattr(series, :line)) === missing
        @test_throws ArgumentError getattr(series, :nothere)
    end
end
