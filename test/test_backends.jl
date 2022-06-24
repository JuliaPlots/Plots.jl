
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

if !isdir(reference_dir())
    mkpath(reference_dir())
    LibGit2.clone(
        "https://github.com/JuliaPlots/PlotReferenceImages.jl.git",
        reference_dir(),
    )
end

# replace `f(args...)` with `f(rng, args...)` for `f ∈ (rand, randn)`
replace_rand!(ex) = nothing

function replace_rand!(ex::Expr)
    for arg in ex.args
        replace_rand!(arg)
    end
    if ex.head === :call && ex.args[1] ∈ (:rand, :randn, :(Plots.fakedata))
        pushfirst!(ex.args, ex.args[1])
        ex.args[2] = :rng
    end
end

function image_comparison_tests(
    pkg::Symbol,
    idx::Int;
    debug = false,
    popup = !is_ci(),
    sigma = [1, 1],
    tol = 1e-2,
)
    Plots._debugMode.on = debug
    example = Plots._examples[idx]
    Plots.theme(:default)
    @info("Testing plot: $pkg:$idx:$(example.header)")
    backend(pkg)
    backend()
    default(size = (500, 300))

    fn = "ref$idx.png"
    reffn = reference_file(pkg, idx, _current_plots_version)
    newfn = joinpath(reference_path(pkg, _current_plots_version), fn)
    @debug example.exprs

    # test function
    func = (fn, idx) -> begin
        eval(:(rng = StableRNG(PLOTS_SEED)))
        for the_expr in example.exprs
            expr = Expr(:block)
            push!(expr.args, the_expr)
            replace_rand!(expr)
            eval(expr)
        end
        png(fn)
    end

    # the test
    vtest = VisualTest(func, reffn, idx)
    test_images(vtest, popup = popup, sigma = sigma, tol = tol, newfn = newfn)
end

function image_comparison_facts(
    pkg::Symbol;
    skip = [],          # skip these examples (int index)
    only = nothing,     # limit to these examples (int index)
    debug = false,      # print debug information?
    sigma = [1, 1],     # number of pixels to "blur"
    tol = 1e-2,         # acceptable error (percent)
)
    for i in 1:length(Plots._examples)
        i in skip && continue
        if only === nothing || i in only
            @test image_comparison_tests(pkg, i, debug = debug, sigma = sigma, tol = tol) |>
                  success == true
        end
    end
end

Random.seed!(PLOTS_SEED)

default(show = false, reuse = true)  # don't actually show the plots

## Uncomment the following lines to update reference images for different backends
#=

gr()
@testset "GR" begin
    image_comparison_facts(:gr, tol = PLOTS_IMG_TOL, skip = Plots._backend_skips[:gr])
end

plotly()
@testset "Plotly" begin
    image_comparison_facts(:plotly, tol = PLOTS_IMG_TOL, skip = Plots._backend_skips[:plotlyjs])
end

pyplot()
@testset "PyPlot" begin
    image_comparison_facts(:pyplot, tol = PLOTS_IMG_TOL, skip = Plots._backend_skips[:pyplot])
end

pgfplotsx()
@testset "PGFPlotsX" begin
    image_comparison_facts(:pgfplotsx, tol = PLOTS_IMG_TOL, skip = Plots._backend_skips[:pgfplotsx])
end
=#

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
