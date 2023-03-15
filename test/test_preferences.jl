
@testset "Preferences" begin
    Plots.set_default_backend!()  # start with empty preferences

    withenv("PLOTS_DEFAULT_BACKEND" => "invalid") do
        @test_logs (:warn, r".*is not a supported backend") Plots.load_default_backend()
    end
    @test_logs (:warn, r".*is not a supported backend") backend(:invalid)

    @test Plots.load_default_backend() == Plots.GRBackend()

    withenv("PLOTS_DEFAULT_BACKEND" => "unicodeplots") do
        @test_logs (:info, r".*environment variable") Plots.diagnostics(devnull)
        @test Plots.load_default_backend() == Plots.UnicodePlotsBackend()
    end

    @test Plots.load_default_backend() == Plots.GRBackend()
    @test Plots.backend_package_name() === :GR
    @test Plots.backend_name() === :gr

    @test_logs (:info, r".*fallback") Plots.diagnostics(devnull)

    @test Plots.merge_with_base_supported([:annotations, :guide]) isa Set
    @test Plots.CurrentBackend(:gr).sym === :gr

    @test_logs (:warn, r".*is not compatible with") Plots.set_default_backend!(:invalid)

    @testset "persistent backend" begin
        # this test mimics a restart, which is needed after a preferences change
        Plots.set_default_backend!(:unicodeplots)
        script = tempname()
        write(
            script,
            """
            using Pkg, Test; io = (devnull, stdout)[1]  # toggle for debugging
            Pkg.activate(; temp = true, io)
            Pkg.develop(; path = "$(escape_string(pkgdir(Plots)))", io)
            Pkg.develop(; path = "$(escape_string(joinpath(pkgdir(Plots), "RecipesPipeline")))", io)
            Pkg.develop(; path = "$(escape_string(joinpath(pkgdir(Plots), "RecipesBase")))", io)
            Pkg.add("UnicodePlots"; io)  # checked by Plots
            using Plots
            res = @testset "Prefs" begin
                @test_logs (:info, r".*Preferences") Plots.diagnostics(io)
                @test backend() == Plots.UnicodePlotsBackend()
            end
            exit(res.n_passed == 2 ? 0 : 1)
            """,
        )
        @test success(run(```$(Base.julia_cmd()) $script```))
    end

    is_pkgeval() || for be in TEST_BACKENDS
        (Sys.isapple() && be === :gaston) && continue  # FIXME: hangs
        (Sys.iswindows() && be === :plotlyjs && is_ci()) && continue # OutOfMemory
        @test_logs Plots.set_default_backend!(be)  # test the absence of warnings
        rm.(Base.find_all_in_cache_path(Base.module_keys[Plots]))  # make sure the compiled cache is removed
        @test success(run(```$(Base.julia_cmd()) -e 'using Plots'```))  # test default precompilation
    end

    Plots.set_default_backend!()  # clear `Preferences` key
end
