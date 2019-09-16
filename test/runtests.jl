import ImageMagick
using VisualRegressionTests
using Plots
using Random
using Test
using FileIO
using Gtk
using LibGit2

reference_dir(args...) = joinpath(homedir(), ".julia", "dev", "PlotReferenceImages", args...)

function reference_file(backend, i, version)
    refdir = reference_dir("Plots", string(backend))
    fn = "ref$i.png"
    versions = sort(VersionNumber.(readdir(refdir)), rev = true)

    reffn = joinpath(refdir, string(version), fn)
    for v in versions
        tmpfn = joinpath(refdir, string(v), fn)
        if isfile(tmpfn)
            reffn = tmpfn
            break
        end
    end

    return reffn
end

reference_path(backend, version) = reference_dir("Plots", string(backend), string(version))

if !isdir(reference_dir())
    LibGit2.clone("https://github.com/JuliaPlots/PlotReferenceImages.jl.git", reference_dir())
end

include("imgcomp.jl")
# don't actually show the plots
Random.seed!(1234)
default(show=false, reuse=true)
is_ci() = get(ENV, "CI", "false") == "true"
img_tol = is_ci() ? 10e-2 : 10e-2

@testset "Backends" begin

    @testset "GR" begin
        ENV["PLOTS_TEST"] = "true"
        ENV["GKSwstype"] = "100"
        @test gr() == Plots.GRBackend()
        @test backend() == Plots.GRBackend()

        @static if Sys.islinux()
            image_comparison_facts(:gr, tol=img_tol, skip = Plots._backend_skips[:gr])
        end
    end

    @testset "UnicodePlots" begin
        @test unicodeplots() == Plots.UnicodePlotsBackend()
        @test backend() == Plots.UnicodePlotsBackend()

        # lets just make sure it runs without error
        p = plot(rand(10))
        @test isa(p, Plots.Plot) == true
        @test isa(display(p), Nothing) == true
        p = bar(randn(10))
        @test isa(p, Plots.Plot) == true
        @test isa(display(p), Nothing) == true
    end

end

@testset "Axes" begin
    p = plot()
    axis = p.subplots[1][:xaxis]
    @test typeof(axis) == Plots.Axis
    @test Plots.discrete_value!(axis, "HI") == (0.5, 1)
    @test Plots.discrete_value!(axis, :yo) == (1.5, 2)
    @test Plots.ignorenan_extrema(axis) == (0.5,1.5)
    @test axis[:discrete_map] == Dict{Any,Any}(:yo  => 2, "HI" => 1)

    Plots.discrete_value!(axis, ["x$i" for i=1:5])
    Plots.discrete_value!(axis, ["x$i" for i=0:2])
    @test Plots.ignorenan_extrema(axis) == (0.5, 7.5)
end

@testset "NoFail" begin
    plots = [histogram([1, 0, 0, 0, 0, 0]),
             plot([missing]),
             plot([missing; 1:4]),
             plot([fill(missing,10); 1:4]),
             plot([1 1; 1 missing]),
             plot(["a" "b"; missing "d"], [1 2; 3 4])]
    for plt in plots
        display(plt)
    end
end

@testset "EmptyAnim" begin
    anim = @animate for i in []
    end

    @test_throws ArgumentError gif(anim)
end

@testset "Segments" begin
    function segments(args...)
        segs = UnitRange{Int}[]
        for seg in iter_segments(args...)
            push!(segs,seg)
        end
        segs
    end

    nan10 = fill(NaN,10)
    @test segments(11:20) == [1:10]
    @test segments([NaN]) == []
    @test segments(nan10) == []
    @test segments([nan10; 1:5]) == [11:15]
    @test segments([1:5;nan10]) == [1:5]
    @test segments([nan10; 1:5; nan10; 1:5; nan10]) == [11:15, 26:30]
    @test segments([NaN; 1], 1:10) == [2:2, 4:4, 6:6, 8:8, 10:10]
    @test segments([nan10; 1:15], [1:15; nan10]) == [11:15]
end

@testset "Utils" begin
    zipped = ([(1,2)], [("a","b")], [(1,"a"),(2,"b")],
              [(1,2),(3,4)], [(1,2,3),(3,4,5)], [(1,2,3,4),(3,4,5,6)],
              [(1,2.0),(missing,missing)], [(1,missing),(missing,"a")],
              [(missing,missing)], [(missing,missing,missing),("a","b","c")])
    for z in zipped
        @test isequal(collect(zip(Plots.unzip(z)...)), z)
        @test isequal(collect(zip(Plots.unzip(Point.(z))...)), z)
    end
end
