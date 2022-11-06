is_ci() = get(ENV, "CI", "false") == "true"
ci_tol() =
    if Sys.islinux()
        "5e-4"
    elseif Sys.isapple()
        "1e-3"
    else
        "1e-2"
    end

const TESTS_MODULE = Module(:PlotsTestsModule)
const PLOTS_IMG_TOL = parse(Float64, get(ENV, "PLOTS_IMG_TOL", is_ci() ? ci_tol() : "1e-5"))

Base.eval(TESTS_MODULE, :(using Random, StableRNGs, Plots))

reference_dir(args...) =
    if (ref_dir = get(ENV, "PLOTS_REFERENCE_DIR", nothing)) !== nothing
        ref_dir
    else
        joinpath(homedir(), ".julia", "dev", "PlotReferenceImages.jl", args...)
    end
reference_path(backend, version) = reference_dir("Plots", string(backend), string(version))

if !isdir(reference_dir())
    mkpath(reference_dir())
    for i in 1:6
        try
            LibGit2.clone(
                "https://github.com/JuliaPlots/PlotReferenceImages.jl.git",
                reference_dir(),
            )
            break
        catch err
            @warn err
            sleep(20i)
        end
    end
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
    foreach(arg -> push!(expr.args, replace_rand(arg)), ex.args)
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
    @info "Testing plot: $pkg:$idx:$(example.header)"

    reffn = reference_file(pkg, idx, Plots._current_plots_version)
    newfn = joinpath(reference_path(pkg, Plots._current_plots_version), "ref$idx.png")

    imports = something(example.imports, :())
    exprs = quote
        Plots.debugplots($debug)
        backend($(QuoteNode(pkg)))
        theme(:default)
        rng = StableRNG(Plots.PLOTS_SEED)
        $(replace_rand(example.exprs))
    end
    @debug imports exprs

    func = fn -> Base.eval.(Ref(TESTS_MODULE), (imports, exprs, :(png($fn))))
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
    for i in setdiff(1:length(Plots._examples), skip)
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

with(:plotlyjs) do
    image_comparison_facts(:plotlyjs, tol = PLOTS_IMG_TOL, skip = Plots._backend_skips[:plotlyjs])
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
        pl = plot(rand(10))
        @test show(io, pl) isa Nothing

        pl = bar(randn(10))
        @test show(io, pl) isa Nothing

        pl = plot([1, 2], [3, 4])
        annotate!(pl, [(1.5, 3.2, Plots.text("Test", :red, :center))])
        hline!(pl, [3.1])
        @test show(io, pl) isa Nothing

        pl = plot([Dates.Date(2019, 1, 1), Dates.Date(2019, 2, 1)], [3, 4])
        hline!(pl, [3.1])
        annotate!(pl, [(Dates.Date(2019, 1, 15), 3.2, Plots.text("Test", :red, :center))])
        @test show(io, pl) isa Nothing

        pl = plot([Dates.Date(2019, 1, 1), Dates.Date(2019, 2, 1)], [3, 4])
        annotate!(pl, [(Dates.Date(2019, 1, 15), 3.2, :auto)])
        hline!(pl, [3.1])
        @test show(io, pl) isa Nothing

        pl = plot(map(plot, 1:4)..., layout = (2, 2))
        @test show(io, pl) isa Nothing

        pl = plot(map(plot, 1:2)..., layout = @layout([° _; _ °]))
        @test show(io, pl) isa Nothing

        redirect_stdout(devnull) do
            show(plot(1:2))
        end
    end
end

const blacklist = if VERSION.major == 1 && VERSION.minor == 9
    [41]  # FIXME: github.com/JuliaLang/julia/issues/47261
else
    []
end

@testset "GR - reference images" begin
    with(:gr) do
        # NOTE: use `ENV["VISUAL_REGRESSION_TESTS_AUTO"] = true;` to automatically replace reference images
        @test backend() == Plots.GRBackend()
        @test backend_name() === :gr
        withenv("PLOTS_TEST" => true, "GKSwstype" => "nul") do
            @static if haskey(ENV, "APPVEYOR")
                @info "Skipping GR image comparison tests on AppVeyor"
            else
                image_comparison_facts(
                    :gr,
                    tol = PLOTS_IMG_TOL,
                    skip = vcat(Plots._backend_skips[:gr], blacklist),
                )
            end
        end
    end
end

@testset "PlotlyJS" begin
    with(:plotlyjs) do
        @test backend() == Plots.PlotlyJSBackend()
        pl = plot(rand(10))
        @test pl isa Plot
        @test_broken display(pl) isa Nothing
    end
end

@testset "Examples" begin
    if Sys.islinux()
        callback(m, pkgname, i) = begin
            pl = m.Plots.current()
            save_func = (; pgfplotsx = m.Plots.pdf, unicodeplots = m.Plots.txt)  # fastest `savefig` for each backend
            fn = Base.invokelatest(
                get(save_func, pkgname, m.Plots.png),
                pl,
                tempname() * "_ex$i",
            )
            @test filesize(fn) > 1_000
        end
        for be in (:gr, :unicodeplots, :pgfplotsx, :plotlyjs, :pyplot, :inspectdr, :gaston)
            skip = vcat(Plots._backend_skips[be], blacklist)
            Plots.test_examples(be; skip, callback, disp = is_ci(), strict = true)  # `ci` display for coverage
            closeall()
        end
    end
end

@testset "coverage" begin
    with(:gr) do
        @test Plots.CurrentBackend(:gr).sym === :gr
        @test Plots.merge_with_base_supported([:annotations, :guide]) isa Set

        @test_logs (:warn, r".*not a valid backend package") withenv(
            "PLOTS_DEFAULT_BACKEND" => "invalid",
        ) do
            Plots._pick_default_backend()
        end
        @test withenv("PLOTS_DEFAULT_BACKEND" => "unicodeplots") do
            Plots._pick_default_backend()
        end == Plots.UnicodePlotsBackend()
        @test_logs (:warn, r".*is not a supported backend") backend(:invalid)

        @test Plots._pick_default_backend() == Plots.GRBackend()
    end
end
