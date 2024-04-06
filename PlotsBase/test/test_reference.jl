ci_tol() =
    if Sys.islinux()
        is_pkgeval() ? "1e-2" : "5e-4"
    elseif Sys.isapple()
        "1e-3"
    else
        "1e-1"
    end

const TESTS_MODULE = Module(:PlotsBaseTestModule)
const PLOTS_IMG_TOL = parse(Float64, get(ENV, "PLOTS_IMG_TOL", is_ci() ? ci_tol() : "1e-5"))

Base.eval(TESTS_MODULE, :(using Random, StableRNGs, PlotsBase))

reference_dir(args...) =
    if (ref_dir = get(ENV, "PLOTS_REFERENCE_DIR", nothing)) ≢ nothing
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
    if (ver = PlotsBase._current_plots_version).prerelease |> isempty
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

function reference_file(backend, version, i)
    # NOTE: keep ref[...].png naming consistent with `PlotDocs`
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
    example = PlotsBase._examples[idx]
    @info "Testing plot: $pkg:$idx:$(example.header)"

    ver = PlotsBase._current_plots_version
    ver = VersionNumber(ver.major, ver.minor, ver.patch)
    reffn = reference_file(pkg, ver, idx)
    newfn = joinpath(reference_path(pkg, ver), ref_name(idx) * ".png")

    imports = something(example.imports, :())
    exprs = quote
        PlotsBase.Commons.debug!($debug)
        backend($(QuoteNode(pkg)))
        theme(:default)
        rng = StableRNG(PlotsBase.PLOTS_SEED)
        $(PlotsBase.replace_rand(example.exprs))
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
    for i in setdiff(1:length(PlotsBase._examples), skip)
        if only ≡ nothing || i in only
            @test success(image_comparison_tests(pkg, i; debug, sigma, tol))
        end
    end
end

## Uncomment the following lines to update reference images for different backends
#=

with(:gr) do
    image_comparison_facts(:gr, tol = PLOTS_IMG_TOL, skip = PlotsBase._backend_skips[:gr])
end

with(:plotlyjs) do
    image_comparison_facts(:plotlyjs, tol = PLOTS_IMG_TOL, skip = PlotsBase._backend_skips[:plotlyjs])
end

with(:pgfplotsx) do
    image_comparison_facts(:pgfplotsx, tol = PLOTS_IMG_TOL, skip = PlotsBase._backend_skips[:pgfplotsx])
end
=#

@testset "UnicodePlots" begin
    with(:unicodeplots) do
        @test backend() == PlotsBase.backend_instance(:unicodeplots)

        io = IOContext(IOBuffer(), :color => true)

        # lets just make sure it runs without error
        pl = plot(rand(10))
        @test show(io, pl) isa Nothing

        pl = bar(randn(10))
        @test show(io, pl) isa Nothing

        pl = plot([1, 2], [3, 4])
        annotate!(pl, [(1.5, 3.2, PlotsBase.text("Test", :red, :center))])
        hline!(pl, [3.1])
        @test show(io, pl) isa Nothing

        pl = plot([Dates.Date(2019, 1, 1), Dates.Date(2019, 2, 1)], [3, 4])
        hline!(pl, [3.1])
        annotate!(
            pl,
            [(Dates.Date(2019, 1, 15), 3.2, PlotsBase.text("Test", :red, :center))],
        )
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

@testset "GR - reference images" begin
    with(:gr) do
        # NOTE: use `ENV["VISUAL_REGRESSION_TESTS_AUTO"] = true;` to automatically replace reference images
        @test backend() == PlotsBase.backend_instance(:gr)
        @test backend_name() ≡ :gr
        image_comparison_facts(
            :gr,
            tol = PLOTS_IMG_TOL,
            skip = vcat(PlotsBase._backend_skips[:gr], blacklist),
        )
    end
end

(is_pkgeval() || is_ci()) || @testset "PlotlyJS" begin
    with(:plotlyjs) do
        PlotlyJSExt = Base.get_extension(PlotsBase, :PlotlyJSExt)
        @test backend() == PlotlyJSExt.PlotlyJSBackend()
        pl = plot(rand(10))
        @test pl isa Plot
        display(pl)
    end
end