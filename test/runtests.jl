using Plots: guidefont, series_annotations, PLOTS_SEED

using VisualRegressionTests
using RecipesBase
using StableRNGs
using TestImages
using LibGit2
using Random
using FileIO
using Plots
using Dates
using JSON
using Test
using Gtk

import GeometryBasics
import ImageMagick

@testset "Infrastructure" begin
    @test_nowarn JSON.Parser.parse(
        String(read(joinpath(dirname(pathof(Plots)), "..", ".zenodo.json"))),
    )
end

@testset "Plotly standalone" begin
    @test_nowarn Plots._init_ijulia_plotting()
    @test Plots.plotly_local_file_path[] === nothing
    temp = Plots.use_local_dependencies[]
    withenv("PLOTS_HOST_DEPENDENCY_LOCAL" => true) do
        Plots.__init__()
        @test Plots.plotly_local_file_path[] isa String
        @test isfile(Plots.plotly_local_file_path[])
        @test Plots.use_local_dependencies[] = true
        @test_nowarn Plots._init_ijulia_plotting()
    end
    Plots.plotly_local_file_path[] = nothing
    Plots.use_local_dependencies[] = temp
end

include("test_defaults.jl")
include("test_pipeline.jl")
include("test_axes.jl")
include("test_contours.jl")
include("test_axis_letter.jl")
include("test_components.jl")
include("test_shorthands.jl")
include("integration_dates.jl")
include("test_recipes.jl")
include("test_hdf5plots.jl")
include("test_pgfplotsx.jl")
include("test_plotly.jl")

reference_dir(args...) =
    joinpath(homedir(), ".julia", "dev", "PlotReferenceImages", args...)

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
    mkpath(reference_dir())
    LibGit2.clone(
        "https://github.com/JuliaPlots/PlotReferenceImages.jl.git",
        reference_dir(),
    )
end

include("imgcomp.jl")
Random.seed!(PLOTS_SEED)

default(show = false, reuse = true)  # don't actually show the plots

is_ci() = get(ENV, "CI", "false") == "true"
const PLOTS_IMG_TOL = parse(Float64, get(ENV, "PLOTS_IMG_TOL", is_ci() ? "1e-4" : "1e-5"))

## Uncomment the following lines to update reference images for different backends

# @testset "GR" begin
#     image_comparison_facts(:gr, tol=PLOTS_IMG_TOL, skip = Plots._backend_skips[:gr])
# end
#
# plotly()
# @testset "Plotly" begin
#     image_comparison_facts(:plotly, tol=PLOTS_IMG_TOL, skip = Plots._backend_skips[:plotlyjs])
# end
#
# pyplot()
# @testset "PyPlot" begin
#     image_comparison_facts(:pyplot, tol=PLOTS_IMG_TOL, skip = Plots._backend_skips[:pyplot])
# end
#
# pgfplotsx()
# @testset "PGFPlotsX" begin
#     image_comparison_facts(:pgfplotsx, tol=PLOTS_IMG_TOL, skip = Plots._backend_skips[:pgfplotsx])
# end

##

@testset "Axes" begin
    p = plot()
    axis = p.subplots[1][:xaxis]
    @test typeof(axis) == Plots.Axis
    @test Plots.discrete_value!(axis, "HI") == (0.5, 1)
    @test Plots.discrete_value!(axis, :yo) == (1.5, 2)
    @test Plots.ignorenan_extrema(axis) == (0.5, 1.5)
    @test axis[:discrete_map] == Dict{Any,Any}(:yo => 2, "HI" => 1)

    Plots.discrete_value!(axis, ["x$i" for i in 1:5])
    Plots.discrete_value!(axis, ["x$i" for i in 0:2])
    @test Plots.ignorenan_extrema(axis) == (0.5, 7.5)
end

@testset "NoFail" begin
    # ensure backend with tested display
    @test unicodeplots() == Plots.UnicodePlotsBackend()
    @test backend() == Plots.UnicodePlotsBackend()

    dsp = TextDisplay(IOContext(IOBuffer(), :color => true))

    @testset "Plot" begin
        plots = [
            histogram([1, 0, 0, 0, 0, 0]),
            plot([missing]),
            plot([missing, missing]),
            plot(fill(missing, 10)),
            plot([missing; 1:4]),
            plot([fill(missing, 10); 1:4]),
            plot([1 1; 1 missing]),
            plot(["a" "b"; missing "d"], [1 2; 3 4]),
        ]
        for plt in plots
            display(dsp, plt)
        end
        @test_nowarn plot(x -> x^2, 0, 2)
    end

    @testset "Bar" begin
        p = bar([3, 2, 1], [1, 2, 3])
        @test p isa Plots.Plot
        @test display(dsp, p) isa Nothing
    end
end

@testset "EmptyAnim" begin
    anim = @animate for i in []
    end

    @test_throws ArgumentError gif(anim)
end

@testset "NaN-separated Segments" begin
    segments(args...) = collect(iter_segments(args...))

    nan10 = fill(NaN, 10)
    @test segments(11:20) == [1:10]
    @test segments([NaN]) == []
    @test segments(nan10) == []
    @test segments([nan10; 1:5]) == [11:15]
    @test segments([1:5; nan10]) == [1:5]
    @test segments([nan10; 1:5; nan10; 1:5; nan10]) == [11:15, 26:30]
    @test segments([NaN; 1], 1:10) == [2:2, 4:4, 6:6, 8:8, 10:10]
    @test segments([nan10; 1:15], [1:15; nan10]) == [11:15]
end

@testset "Utils" begin
    zipped = (
        [(1, 2)],
        [("a", "b")],
        [(1, "a"), (2, "b")],
        [(1, 2), (3, 4)],
        [(1, 2, 3), (3, 4, 5)],
        [(1, 2, 3, 4), (3, 4, 5, 6)],
        [(1, 2.0), (missing, missing)],
        [(1, missing), (missing, "a")],
        [(missing, missing)],
        [(missing, missing, missing), ("a", "b", "c")],
    )
    for z in zipped
        @test isequal(collect(zip(Plots.unzip(z)...)), z)
        @test isequal(collect(zip(Plots.unzip(GeometryBasics.Point.(z))...)), z)
    end
    op1 = Plots.process_clims((1.0, 2.0))
    op2 = Plots.process_clims((1, 2.0))
    data = randn(100, 100)
    @test op1(data) == op2(data)
    @test Plots.process_clims(nothing) ==
          Plots.process_clims(missing) ==
          Plots.process_clims(:auto)
end

@testset "Backends" begin
    @testset "UnicodePlots" begin
        @test unicodeplots() == Plots.UnicodePlotsBackend()
        @test backend() == Plots.UnicodePlotsBackend()

        io = IOContext(IOBuffer(), :color => true)

        # lets just make sure it runs without error
        p = plot(rand(10))
        @test p isa Plots.Plot
        @test show(io, p) isa Nothing
        p = bar(randn(10))
        @test p isa Plots.Plot
        @test show(io, p) isa Nothing
        p = plot([1, 2], [3, 4])
        annotate!(p, [(1.5, 3.2, Plots.text("Test", :red, :center))])
        hline!(p, [3.1])
        @test p isa Plots.Plot
        @test show(io, p) isa Nothing
        p = plot([Dates.Date(2019, 1, 1), Dates.Date(2019, 2, 1)], [3, 4])
        hline!(p, [3.1])
        annotate!(p, [(Dates.Date(2019, 1, 15), 3.2, Plots.text("Test", :red, :center))])
        @test p isa Plots.Plot
        @test show(io, p) isa Nothing
        p = plot([Dates.Date(2019, 1, 1), Dates.Date(2019, 2, 1)], [3, 4])
        annotate!(p, [(Dates.Date(2019, 1, 15), 3.2, :auto)])
        hline!(p, [3.1])
        @test p isa Plots.Plot
        @test show(io, p) isa Nothing
    end

    @testset "PlotlyJS" begin
        @test plotlyjs() == Plots.PlotlyJSBackend()
        @test backend() == Plots.PlotlyJSBackend()

        p = plot(rand(10))
        @test p isa Plots.Plot
        @test_broken display(p) isa Nothing
    end

    @testset "GR" begin
        ENV["PLOTS_TEST"] = "true"
        ENV["GKSwstype"] = "100"
        @test gr() == Plots.GRBackend()
        @test backend() == Plots.GRBackend()

        @static if haskey(ENV, "APPVEYOR")
            @info "Skipping GR image comparison tests on AppVeyor"
        else
            image_comparison_facts(
                :gr,
                tol = PLOTS_IMG_TOL,
                skip = Plots._backend_skips[:gr],
            )
        end
    end
end
