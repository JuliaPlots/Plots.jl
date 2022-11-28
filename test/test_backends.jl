ci_tol() =
    if Sys.islinux()
        is_pkgeval() ? "1e-2" : "5e-4"
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

function checkout_reference_dir(dn::AbstractString)
    mkpath(dn)
    local repo
    for i in 1:6
        try
            repo = LibGit2.clone(
                "https://github.com/JuliaPlots/PlotReferenceImages.jl.git",
                dn,
            )
            break
        catch err
            @warn err
            sleep(20i)
        end
    end
    if (ver = Plots._current_plots_version).prerelease |> isempty
        try
            tag = LibGit2.GitObject(repo, "v$ver")
            hash = string(LibGit2.target(tag))
            LibGit2.checkout!(repo, hash)
        catch err
            @warn err
        end
    end
    LibGit2.peel(LibGit2.head(repo)) |> println  # print some information
    nothing
end

let dn = reference_dir()
    isdir(dn) || checkout_reference_dir(dn)
end

ref_name(i) = "ref" * lpad(i, 3, '0')

function reference_file(backend, version, i)
    # NOTE: keep ref-[...].png naming consistent with `PlotDocs`
    refdir = reference_dir("Plots", string(backend))
    fn = ref_name(i) * ".png"
    reffn = joinpath(refdir, string(version), fn)
    for ver in sort(VersionNumber.(readdir(refdir)), rev = true)
        if (tmpfn = joinpath(refdir, string(ver), fn)) |> isfile
            reffn = tmpfn
            break
        end
    end
    return reffn
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

    reffn = reference_file(pkg, Plots._current_plots_version, idx)
    newfn =
        joinpath(reference_path(pkg, Plots._current_plots_version), ref_name(idx) * ".png")

    imports = something(example.imports, :())
    exprs = quote
        Plots.debug!($debug)
        backend($(QuoteNode(pkg)))
        theme(:default)
        rng = StableRNG(Plots.PLOTS_SEED)
        $(Plots.replace_rand(example.exprs))
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
            @test success(image_comparison_tests(pkg, i; debug, sigma, tol))
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

@testset "Preferences" begin
    @test Plots.merge_with_base_supported([:annotations, :guide]) isa Set
    @test Plots.CurrentBackend(:gr).sym === :gr

    Plots.set_backend!(:gaston; force = true)
    @test Plots.load_default_backend() == Plots.GastonBackend()
    proc = ```
    $(Base.julia_cmd()) -e "
        ENV[\"PLOTS_PRECOMPILE\"] = false
        using Pkg
        Pkg.activate(; temp = true)
        Pkg.develop(; path = \"$(pkgdir(Plots))\")
        using Plots, Test
        @test backend() == Plots.GastonBackend()
    "``` |> run
    @test success(proc)
    Plots.set_backend!(; force = true)

    @test_logs (:warn, r".*is not a supported backend") withenv(
        "PLOTS_DEFAULT_BACKEND" => "invalid",
    ) do
        Plots.load_default_backend()
    end
    @test_logs (:warn, r".*is not a supported backend") backend(:invalid)

    @test Plots.load_default_backend() == Plots.GRBackend()

    @test withenv("PLOTS_DEFAULT_BACKEND" => "unicodeplots") do
        Plots.load_default_backend()
    end == Plots.UnicodePlotsBackend()

    @test Plots.load_default_backend() == Plots.GRBackend()
end

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

        pl = plot(map(plot, 1:3)..., layout = (2, 2))
        @test show(io, pl) isa Nothing

        pl = plot(map(plot, 1:2)..., layout = @layout([° _; _ °]))
        @test show(io, pl) isa Nothing

        redirect_stdout(devnull) do
            show(plot(1:2))
        end
    end
end

const blacklist = if VERSION.major == 1 && VERSION.minor ∈ (9, 10)
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
    is_pkgeval() || with(:plotlyjs) do
        @test backend() == Plots.PlotlyJSBackend()
        pl = plot(rand(10))
        @test pl isa Plot
        @test_broken display(pl) isa Nothing
    end
end

@testset "Examples" begin
    if Sys.islinux() && !is_pkgeval()
        callback(m, pkgname, i) = begin
            pl = m.Plots.current()
            save_func = (; pgfplotsx = m.Plots.pdf, unicodeplots = m.Plots.txt)  # fastest `savefig` for each backend
            fn = Base.invokelatest(
                get(save_func, pkgname, m.Plots.png),
                pl,
                tempname() * ref_name(i),
            )
            @test filesize(fn) > 1_000
        end
        for be in (
            :gr,
            :unicodeplots,
            :pgfplotsx,
            :plotlyjs,
            :pyplot,
            :pythonplot,
            :inspectdr,
            :gaston,
        )
            skip = vcat(Plots._backend_skips[be], blacklist)
            Plots.test_examples(be; skip, callback, disp = is_ci(), strict = true)  # `ci` display for coverage
            closeall()
        end
    end
end
