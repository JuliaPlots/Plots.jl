
@testset "Preferences" begin
    Plots.set_default_backend!()  # start with empty preferences

    withenv("PLOTS_DEFAULT_BACKEND" => "invalid") do
        @test_logs (:error, r"Unsupported backend.*") Plots.load_default_backend()
    end
    @test_logs (:error, r"Unsupported backend.*") backend(:invalid)

    @test Plots.load_default_backend() == Base.get_extension(PlotsBase, :GRExt).GRBackend()

    withenv("PLOTS_DEFAULT_BACKEND" => "unicodeplots") do
        @test_logs (:info, r".*environment variable") Plots.diagnostics(devnull)
        @test Plots.load_default_backend() == Base.get_extension(PlotsBase, :UnicodePlotsExt).UnicodePlotsBackend()
    end

    @test Plots.load_default_backend() == Base.get_extension(PlotsBase, :GRExt).GRBackend()
    @test Plots.PlotsBase.backend_package_name() ≡ :GR
    @test Plots.backend_name() ≡ :gr

    @test_logs (:info, r".*fallback") Plots.diagnostics(devnull)

    @test Plots.PlotsBase.merge_with_base_supported([:annotations, :guide]) isa Set
    @test Plots.PlotsBase.CurrentBackend(:gr).sym ≡ :gr

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
            Pkg.add("UnicodePlots"; io)  # checked by Plots
            import UnicodePlots
            using Plots
            res = @testset "Prefs" begin
                @test_logs (:info, r".*Preferences") Plots.diagnostics(io)
                @test backend() == Base.get_extension(PlotsBase, :UnicodePlotsExt).UnicodePlotsBackend()
            end
            exit(res.n_passed == 2 ? 0 : 1)
            """,
        )
        @test success(run(```$(Base.julia_cmd()) $script```))
    end

    is_pkgeval() || for pkg in TEST_PACKAGES
        be = Symbol(lowercase(pkg))
        (Sys.isapple() && be ≡ :gaston) && continue  # FIXME: hangs
        (Sys.iswindows() && be ≡ :plotlyjs && is_ci()) && continue  # FIXME: OutOfMemory
        @test_logs Plots.set_default_backend!(be)  # test the absence of warnings
        rm.(Base.find_all_in_cache_path(Base.module_keys[Plots]))  # make sure the compiled cache is removed
        script = tempname()
        write(script, "import :$pkg; using Test, Plots; @test Plots.backend_name() == $be")
        @test success(run(```$(Base.julia_cmd()) $script```))  # test default precompilation
    end

    Plots.set_default_backend!()  # clear `Preferences` key
end
