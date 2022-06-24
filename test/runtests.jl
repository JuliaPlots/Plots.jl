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

@testset "NoFail" begin
    # ensure backend with tested display
    @test unicodeplots() == Plots.UnicodePlotsBackend()
    @test backend() == Plots.UnicodePlotsBackend()

    dsp = TextDisplay(IOContext(IOBuffer(), :color => true))

    @testset "plot" begin
        for plt in [
            histogram([1, 0, 0, 0, 0, 0]),
            plot([missing]),
            plot([missing, missing]),
            plot(fill(missing, 10)),
            plot([missing; 1:4]),
            plot([fill(missing, 10); 1:4]),
            plot([1 1; 1 missing]),
            plot(["a" "b"; missing "d"], [1 2; 3 4]),
        ]
            display(dsp, plt)
        end
        @test_nowarn plot(x -> x^2, 0, 2)
    end

    @testset "bar" begin
        p = bar([3, 2, 1], [1, 2, 3])
        @test p isa Plots.Plot
        @test display(dsp, p) isa Nothing
    end

    @testset "gui" begin
        open(tempname(), "w") do io
            redirect_stdout(io) do
                gui(plot())
            end
        end
    end

    gr()  # reset to default backend
end

for fn in (
    "test_coverage.jl",
    "test_utils.jl",
    "test_args.jl",
    "test_defaults.jl",
    "test_pipeline.jl",
    "test_axes.jl",
    "test_layouts.jl",
    "test_contours.jl",
    "test_axis_letter.jl",
    "test_components.jl",
    "test_shorthands.jl",
    "integration_dates.jl",
    "test_recipes.jl",
    "test_hdf5plots.jl",
    "test_pgfplotsx.jl",
    "test_plotly.jl",
    "test_animations.jl",
    "test_output.jl",
)
    @testset "$fn" begin
        include(fn)
    end
end

reference_dir(args...) =
    joinpath(homedir(), ".julia", "dev", "PlotReferenceImages", args...)

function reference_file(backend, i, version)
    refdir = reference_dir("Plots", string(backend))
    fn = "ref$i.png"
    versions = sort(VersionNumber.(readdir(refdir)), rev = true)
    reffn = joinpath(refdir, string(version), fn)
    for v in versions
        if (tmpfn = joinpath(refdir, string(v), fn)) |> isfile
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
const PLOTS_IMG_TOL = parse(
    Float64,
    get(ENV, "PLOTS_IMG_TOL", is_ci() ? (Sys.iswindows() ? "2e-3" : "1e-4") : "2e-5"),
)

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

        p = plot((plot(i) for i in 1:4)..., layout = (2, 2))
        @test p isa Plots.Plot
        @test show(io, p) isa Nothing
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

    @testset "PlotlyJS" begin
        @test plotlyjs() == Plots.PlotlyJSBackend()
        @test backend() == Plots.PlotlyJSBackend()

        p = plot(rand(10))
        @test p isa Plots.Plot
        @test_broken display(p) isa Nothing
    end
end

@testset "Examples" begin
    if Sys.islinux()
        backends = (
            :unicodeplots,
            :pgfplotsx,
            :inspectdr,
            :plotlyjs,
            :gaston,
            # :pyplot,  # FIXME: fails with system matplotlib
        )
        only = setdiff(
            1:length(Plots._examples),
            (Plots._backend_skips[be] for be in backends)...,
        )
        for be in backends
            @info be
            for (i, p) in Plots.test_examples(be, only = only, disp = false)
                fn = tempname() * ".png"
                png(p, fn)
                @test filesize(fn) > 1_000
            end
        end
    end
end
