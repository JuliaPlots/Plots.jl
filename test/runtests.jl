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
        @test isequal(collect(zip(Plots.RecipesPipeline.unzip(z)...)), z)
        @test isequal(
            collect(zip(Plots.RecipesPipeline.unzip(GeometryBasics.Point.(z))...)),
            z,
        )
    end
    op1 = Plots.process_clims((1.0, 2.0))
    op2 = Plots.process_clims((1, 2.0))
    data = randn(100, 100)
    @test op1(data) == op2(data)
    @test Plots.process_clims(nothing) ==
          Plots.process_clims(missing) ==
          Plots.process_clims(:auto)

    @test (==)(
        Plots.texmath2unicode(
            raw"Equation $y = \alpha \cdot x + \beta$ and eqn $y = \sin(x)^2$",
        ),
        raw"Equation y = α ⋅ x + β and eqn y = sin(x)²",
    )

    @test Plots.isvector([1, 2])
    @test !Plots.isvector(nothing)
    @test Plots.ismatrix([1 2; 3 4])
    @test !Plots.ismatrix(nothing)
    @test Plots.isscalar(1.0)
    @test !Plots.isscalar(nothing)
    @test Plots.tovec([]) isa AbstractVector
    @test Plots.tovec(nothing) isa AbstractVector
    @test Plots.anynan(1, 3, (1, NaN, 3))
    @test Plots.allnan(1, 2, (NaN, NaN, 1))
    @test Plots.makevec([]) isa AbstractVector
    @test Plots.makevec(1) isa AbstractVector
    @test Plots.maketuple(1) == (1, 1)
    @test Plots.maketuple((1, 1)) == (1, 1)
    @test Plots.ok(1, 2)
    @test !Plots.ok(1, 2, NaN)
    @test Plots.ok((1, 2, 3))
    @test !Plots.ok((1, 2, NaN))
    @test Plots.nansplit([1, 2, NaN, 3, 4]) == [[1.0, 2.0], [3.0, 4.0]]
    @test Plots.nanvcat([1, NaN]) |> length == 4

    @test Plots.nop() === nothing
    @test_throws ErrorException Plots.notimpl()

    @test Plots.inch2px(1) isa AbstractFloat
    @test Plots.px2inch(1) isa AbstractFloat
    @test Plots.inch2mm(1) isa AbstractFloat
    @test Plots.mm2inch(1) isa AbstractFloat
    @test Plots.px2mm(1) isa AbstractFloat
    @test Plots.mm2px(1) isa AbstractFloat

    p = plot()
    @test xlims() isa Tuple
    @test ylims() isa Tuple
    @test zlims() isa Tuple

    Plots.makekw(foo = 1, bar = 2) isa Dict

    @test_throws ErrorException Plots.inline()
    @test_throws ErrorException Plots._do_plot_show(plot(), :inline)
    @test_throws ErrorException Plots.dumpcallstack()

    Plots.debugplots(true)
    Plots.debugplots(false)
    Plots.debugshow(devnull, nothing)
    Plots.debugshow(devnull, [1])

    p = plot(1)
    push!(p, 1.5)
    push!(p, 1, 1.5)
    # append!(p, [1., 2.])
    append!(p, 1, 2.5, 2.5)
    push!(p, (1.5, 2.5))
    push!(p, 1, (1.5, 2.5))
    append!(p, (1.5, 2.5))
    append!(p, 1, (1.5, 2.5))

    p = plot([1, 2, 3], [4, 5, 6])
    @test Plots.xmin(p) == 1
    @test Plots.xmax(p) == 3
    @test Plots.ignorenan_extrema(p) == (1, 3)

    @test Plots.get_attr_symbol(:x, "lims") == :xlims
    @test Plots.get_attr_symbol(:x, :lims) == :xlims

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
end

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
end

@testset "Coverage" begin
    @testset "themes" begin
        p = showtheme(:dark)
        @test p isa Plots.Plot
    end

    @testset "plotattr" begin
        tmp = tempname()
        open(tmp, "w") do io
            redirect_stdout(io) do
                plotattr("seriestype")
                plotattr(:Plot)
                plotattr()
            end
        end
        str = join(readlines(tmp), "")
        @test occursin("seriestype", str)
        @test occursin("Plot attributes", str)
    end

    @testset "legend" begin
        @test isa(
            Plots.legend_pos_from_angle(20, 0.0, 0.5, 1.0, 0.0, 0.5, 1.0),
            NTuple{2,<:AbstractFloat},
        )
        @test Plots.legend_anchor_index(-1) == 1
        @test Plots.legend_anchor_index(+0) == 2
        @test Plots.legend_anchor_index(+1) == 3

        @test Plots.legend_angle(:foo_bar) == (45, :inner)
        @test Plots.legend_angle(20.0) ==
              Plots.legend_angle((20.0, :inner)) ==
              (20.0, :inner)
        @test Plots.legend_angle((20.0, 10.0)) == (20.0, 10.0)
    end
end

@testset "Output" begin
    @test Plots.defaultOutputFormat(plot()) == "png"
    @test Plots.addExtension("foo", "bar") == "foo.bar"

    fn = tempname()
    gr()
    let p = plot()
        Plots.png(p, fn)
        Plots.png(fn)
        savefig(p, "$fn.png")
        savefig("$fn.png")

        Plots.pdf(p, fn)
        Plots.pdf(fn)
        savefig(p, "$fn.pdf")
        savefig("$fn.pdf")

        Plots.ps(p, fn)
        Plots.ps(fn)
        savefig(p, "$fn.ps")
        savefig("$fn.ps")

        Plots.svg(p, fn)
        Plots.svg(fn)
        savefig(p, "$fn.svg")
        savefig("$fn.svg")
    end

    if Sys.islinux()
        pgfplotsx()
        let p = plot()
            Plots.tex(p, fn)
            Plots.tex(fn)
            savefig(p, "$fn.tex")
            savefig("$fn.tex")
        end
    end

    unicodeplots()
    let p = plot()
        Plots.txt(p, fn)
        Plots.txt(fn)
        savefig(p, "$fn.txt")
        savefig("$fn.txt")
    end

    plotlyjs()
    let p = plot()
        Plots.html(p, fn)
        Plots.html(fn)
        savefig(p, "$fn.html")
        savefig("$fn.html")

        if Sys.islinux()
            Plots.eps(p, fn)
            Plots.eps(fn)
            savefig(p, "$fn.eps")
            savefig("$fn.eps")
        end
    end

    @test_throws ErrorException savefig("$fn.foo")
end

gr()  # reset to default backend

for fn in (
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
const PLOTS_IMG_TOL = parse(
    Float64,
    get(ENV, "PLOTS_IMG_TOL", is_ci() ? Sys.iswindows() ? "2e-3" : "1e-4" : "1e-5"),
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
