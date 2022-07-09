is_ci() = get(ENV, "CI", "false") == "true"

const TEST_MODULE = Module(:PlotsTestModule)
const PLOTS_IMG_TOL = parse(Float64, get(ENV, "PLOTS_IMG_TOL", is_ci() ? "1e-4" : "1e-5"))

Base.eval(TEST_MODULE, quote
    using Random, StableRNGs, Plots
    rng = StableRNG($PLOTS_SEED)
end)

reference_dir(args...) =
    joinpath(homedir(), ".julia", "dev", "PlotReferenceImages", args...)
reference_path(backend, version) = reference_dir("Plots", string(backend), string(version))

if !isdir(reference_dir())
    mkpath(reference_dir())
    LibGit2.clone(
        "https://github.com/JuliaPlots/PlotReferenceImages.jl.git",
        reference_dir(),
    )
end

function reference_file(backend, i, version)
    refdir, fn = reference_dir("Plots", string(backend)), "ref$i.png"
    reffn = joinpath(refdir, string(version), fn)
    for ver in sort(VersionNumber.(readdir(refdir)), rev = true)
        if (tmpfn = joinpath(refdir, string(ver), fn)) |> isfile
            reffn = tmpfn
            break
        end
    end
    return reffn
end

# replace `f(args...)` with `f(rng, args...)` for `f ∈ (rand, randn)`
replace_rand(ex) = ex

function replace_rand(ex::Expr)
    expr = Expr(ex.head)
    for arg in ex.args
        push!(expr.args, replace_rand(arg))
    end
    if Meta.isexpr(ex, :call) && ex.args[1] ∈ (:rand, :randn, :(Plots.fakedata))
        pushfirst!(expr.args, ex.args[1])
        expr.args[2] = :rng
    end
    expr
end

function image_comparison_tests(
    pkg::Symbol,
    idx::Int;
    debug = false,
    popup = !is_ci(),
    sigma = [1, 1],
    tol = 1e-2,
)
    example = Plots._examples[idx]
    @info("Testing plot: $pkg:$idx:$(example.header)")

    reffn = reference_file(pkg, idx, Plots._current_plots_version)
    newfn = joinpath(reference_path(pkg, Plots._current_plots_version), "ref$idx.png")
    @debug example.exprs

    # test function
    func =
        fn -> begin
            for ex in (
                :(Plots._debugMode.on = $debug),
                :(backend($(QuoteNode(pkg)))),
                :(theme(:default)),
                :(default(size = (500, 300), show = false, reuse = true)),
                :(Random.seed!(rng, $PLOTS_SEED)),
                replace_rand.(example.exprs)...,
                :(png($fn)),
            )
                Base.eval(TEST_MODULE, ex)
            end
        end

    test_images(
        VisualTest(func, reffn),
        newfn = newfn,
        popup = popup,
        sigma = sigma,
        tol = tol,
    )
end

function image_comparison_facts(
    pkg::Symbol;
    skip = [],          # skip these examples (int index)
    only = nothing,     # limit to these examples (int index)
    debug = false,      # print debug information ?
    sigma = [1, 1],     # number of pixels to "blur"
    tol = 1e-2,         # acceptable error (percent)
)
    for i in 1:length(Plots._examples)
        i in skip && continue
        if only === nothing || i in only
            @test success(
                image_comparison_tests(pkg, i, debug = debug, sigma = sigma, tol = tol),
            )
        end
    end
end

## Uncomment the following lines to update reference images for different backends
#=

with(:gr) do
    image_comparison_facts(:gr, tol = PLOTS_IMG_TOL, skip = Plots._backend_skips[:gr])
end

with(:plotly) do
    image_comparison_facts(:plotly, tol = PLOTS_IMG_TOL, skip = Plots._backend_skips[:plotlyjs])
end

with(:pyplot) do
    image_comparison_facts(:pyplot, tol = PLOTS_IMG_TOL, skip = Plots._backend_skips[:pyplot])
end

with(:pgfplotsx) do
    image_comparison_facts(:pgfplotsx, tol = PLOTS_IMG_TOL, skip = Plots._backend_skips[:pgfplotsx])
end
=#

@testset "UnicodePlots" begin
    with(:unicodeplots) do
        @test backend() == Plots.UnicodePlotsBackend()

        io = IOContext(IOBuffer(), :color => true)

        # lets just make sure it runs without error
        p = plot(rand(10))
        @test p isa Plot
        @test show(io, p) isa Nothing

        p = bar(randn(10))
        @test p isa Plot
        @test show(io, p) isa Nothing

        p = plot([1, 2], [3, 4])
        annotate!(p, [(1.5, 3.2, Plots.text("Test", :red, :center))])
        hline!(p, [3.1])
        @test p isa Plot
        @test show(io, p) isa Nothing

        p = plot([Dates.Date(2019, 1, 1), Dates.Date(2019, 2, 1)], [3, 4])
        hline!(p, [3.1])
        annotate!(p, [(Dates.Date(2019, 1, 15), 3.2, Plots.text("Test", :red, :center))])
        @test p isa Plot
        @test show(io, p) isa Nothing

        p = plot([Dates.Date(2019, 1, 1), Dates.Date(2019, 2, 1)], [3, 4])
        annotate!(p, [(Dates.Date(2019, 1, 15), 3.2, :auto)])
        hline!(p, [3.1])
        @test p isa Plot
        @test show(io, p) isa Nothing

        p = plot((plot(i) for i in 1:4)..., layout = (2, 2))
        @test p isa Plot
        @test show(io, p) isa Nothing
    end
end

@testset "GR - reference images" begin
    with(:gr) do
        ENV["PLOTS_TEST"] = "true"
        ENV["GKSwstype"] = "nul"
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

@testset "PlotlyJS" begin
    with(:plotlyjs) do
        @test backend() == Plots.PlotlyJSBackend()

        p = plot(rand(10))
        @test p isa Plot
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
