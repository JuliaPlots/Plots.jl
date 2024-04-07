# get `Preferences` set backend, if any
const PREVIOUS_DEFAULT_BACKEND = load_preference(PlotsBase, "default_backend")
# -----------------------------------------------------------------------------

PlotsBase.set_default_backend!()  # start with empty preferences

withenv("PLOTSBASE_DEFAULT_BACKEND" => "test_invalid_backend") do
    @test_logs (:error, r"Unsupported backend.*") PlotsBase.default_backend()
end
@test_logs (:error, r"Unsupported backend.*") backend(:test_invalid_backend)

@test PlotsBase.default_backend() == Base.get_extension(PlotsBase, :GRExt).GRBackend()

withenv("PLOTSBASE_DEFAULT_BACKEND" => "unicodeplots") do
    @test_logs (:info, r".*environment variable") PlotsBase.diagnostics(devnull)
    @test PlotsBase.default_backend() ==
          Base.get_extension(PlotsBase, :UnicodePlotsExt).UnicodePlotsBackend()
end

@test PlotsBase.default_backend() == Base.get_extension(PlotsBase, :GRExt).GRBackend()
@test PlotsBase.backend_package_name() ≡ :GR
@test PlotsBase.backend_name() ≡ :gr

@test_logs (:info, r".*fallback") PlotsBase.diagnostics(devnull)

@test PlotsBase.merge_with_base_supported([:annotations, :guide]) isa Set
@test PlotsBase.CurrentBackend(:gr).name ≡ :gr

@test_logs (:warn, r".*is not compatible with") PlotsBase.set_default_backend!(
    :test_invalid_backend,
)

const DEBUG = false
@testset "persistent backend - restart" begin
    # this test mimics a restart, which is needed after a preferences change
    PlotsBase.set_default_backend!(:unicodeplots)
    script = tempname()
    dn = pkgdir(PlotsBase) |> escape_string
    write(
        script,
        """
        using Pkg, Test; io = (devnull, stdout)[1]  # toggle for debugging
        Pkg.activate(; temp = true, io)
        Pkg.develop(; path = joinpath("$dn", "..", "RecipesBase"), io)
        Pkg.develop(; path = joinpath("$dn", "..", "RecipesPipeline"), io)
        Pkg.develop(; path = "$dn", io)
        Pkg.add("UnicodePlots"; io)  # checked by Plots
        import UnicodePlots
        using PlotsBase
        unicodeplots()
        res = @testset "Preferences UnicodePlots" begin
            @test_logs (:info, r".*Preferences") PlotsBase.diagnostics(io)
            @test backend() == Base.get_extension(PlotsBase, :UnicodePlotsExt).UnicodePlotsBackend()
        end
        exit(res.n_passed == 2 ? 0 : 123)
        """,
    )
    DEBUG && print(read(script, String))
    @test run(```$(Base.julia_cmd()) $script```) |> success
end

is_pkgeval() || for pkg in TEST_PACKAGES
    be = TEST_BACKENDS[pkg]
    if is_ci()
        (Sys.isapple() && be ≡ :gaston) && continue  # FIXME: hangs
        (Sys.iswindows() && be ≡ :plotlyjs) && continue  # FIXME: OutOfMemory
    end
    @test_logs PlotsBase.set_default_backend!(be)  # test the absence of warnings
    rm.(Base.find_all_in_cache_path(Base.module_keys[PlotsBase]))  # make sure the compiled cache is removed
    script = tempname()
    write(
        script,
        """
        import $pkg
        using Test, PlotsBase
        $be()
        res = @testset "Persistent backend $pkg" begin
            @test PlotsBase.backend_name() ≡ :$be
        end
        exit(res.n_passed == 1 ? 0 : 123)
        """,
    )
    DEBUG && print(read(script, String))
    @test run(```$(Base.julia_cmd()) $script```) |> success  # test default precompilation
end

PlotsBase.set_default_backend!()  # clear `Preferences` key

# -----------------------------------------------------------------------------
if PREVIOUS_DEFAULT_BACKEND ≡ nothing
    delete_preferences!(PlotsBase, "default_backend")  # restore the absence of a preference
else
    set_default_backend!(PREVIOUS_DEFAULT_BACKEND)  # reset to previous state
end
