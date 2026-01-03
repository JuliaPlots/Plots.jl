ci_tol() =
if Sys.islinux()
    is_pkgeval() ? "1e-2" : "5e-4"
elseif Sys.isapple()
    "1e-3"
else
    "1e-1"
end

const TESTS_MODULE = Module(:PlotsBaseTestModule)
const PLOTSBASE_IMG_TOL =
    parse(Float64, get(ENV, "PLOTSBASE_IMG_TOL", is_ci() ? ci_tol() : "1e-5"))

Base.eval(TESTS_MODULE, :(using Random, StableRNGs, PlotsBase))

assets_path(args...) = normpath(@__DIR__, "..", "..", "assets", "PlotsBase", args...)

function reference_file(backend, version, i)
    # NOTE: keep ref[...].png naming consistent with `PlotDocs`
    refdir = assets_path(string(backend)) |> mkpath
    fn = PlotsBase.ref_name(i) * ".png"
    reffn = assets_path(string(backend), string(version), fn)
    for ver in sort(VersionNumber.(readdir(refdir)), rev = true)
        if (tmpfn = assets_path(string(backend), string(ver), fn)) |> isfile
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
        tol = 1.0e-2,
    )
    example = PlotsBase._examples[idx]
    @info "Testing plot: $pkg:$idx:$(example.header)"

    ver = PlotsBase._version
    ver = VersionNumber(ver.major, ver.minor, ver.patch)
    reffn = reference_file(pkg, ver, idx)
    newfn = assets_path(string(pkg), string(ver), PlotsBase.ref_name(idx) * ".png")

    imports = something(example.imports, :())
    exprs = quote
        PlotsBase.Commons.debug!($debug)
        backend($(QuoteNode(pkg)))
        theme(:default)
        rng = StableRNG(PlotsBase.SEED)
        $(PlotsBase.replace_rand(example.exprs))
    end
    @debug imports exprs

    func = fn -> Base.eval.(Ref(TESTS_MODULE), (imports, exprs, :(png($fn))))
    return test_images(
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
        broken = [],        # known broken examples (int index)
        only = nothing,     # limit to these examples (int index)
        debug = false,      # print debug information ?
        sigma = [1, 1],     # number of pixels to "blur"
        tol = 1.0e-2,         # acceptable error (percent)
    )
    for i in setdiff(1:length(PlotsBase._examples), skip)
        if only ≡ nothing || i in only
            test = image_comparison_tests(pkg, i; debug, sigma, tol)
            if i ∈ broken
                @test_broken success(test)
            elseif is_auto()
                nothing
            else
                @test success(test)
            end
        end
    end
    return
end

## Uncomment the following lines to update reference images for different backends
#=

with(:gr) do
    image_comparison_facts(:gr, tol = PLOTSBASE_IMG_TOL, skip = PlotsBase._backend_skips[:gr])
end

with(:plotlyjs) do
    image_comparison_facts(:plotlyjs, tol = PLOTSBASE_IMG_TOL, skip = PlotsBase._backend_skips[:plotlyjs])
end

with(:pgfplotsx) do
    image_comparison_facts(:pgfplotsx, tol = PLOTSBASE_IMG_TOL, skip = PlotsBase._backend_skips[:pgfplotsx])
end
=#

@testset "GR - reference images" begin
    with(:gr) do
        # NOTE: use `ENV["VISUAL_REGRESSION_TESTS_AUTO"] = true;` to automatically replace reference images
        @test backend() == PlotsBase.backend_instance(:gr)
        @test backend_name() ≡ :gr
        image_comparison_facts(
            :gr,
            tol = PLOTSBASE_IMG_TOL,
            skip = vcat(PlotsBase._backend_skips[:gr], skipped_examples),
            broken = broken_examples,
        )
    end
end
