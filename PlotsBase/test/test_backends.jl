
is_pkgeval() || @testset "Examples" begin
    callback(m, pkgname, i) = begin
        save_func = (; pgfplotsx = m.PlotsBase.pdf, unicodeplots = m.PlotsBase.txt)  # fastest `savefig` for each backend
        pl = m.PlotsBase.current()
        fn = Base.invokelatest(
            get(save_func, pkgname, m.PlotsBase.png),
            pl,
            tempname() * ref_name(i),
        )
        @test filesize(fn) > 1_000
    end
    Sys.islinux() && for be in TEST_BACKENDS
        skip = vcat(PlotsBase._backend_skips[be], blacklist)
        PlotsBase.test_examples(be; skip, callback, disp = is_ci(), strict = true)  # `ci` display for coverage
        closeall()
    end
end
