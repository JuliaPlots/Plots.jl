@testset "Auto QUality Assurance" begin
    # JuliaTesting/Aqua.jl/issues/77
    # TODO: fix :Contour, :Latexify and :LaTeXStrings stale imports in Plots 2.0
    # :CondaPkg stale deps show up when running CI
    Aqua.test_all(
        PlotsBase;
        stale_deps = (;
            ignore = [:CondaPkg, :Contour, :UnitfulLatexify, :LaTeXStrings, :Latexify]
        ),
        ambiguities = false,
        deps_compat = false,  # FIXME: fails `CondaPkg`
        piracies = false,
    )
    Aqua.test_ambiguities(PlotsBase; exclude = [RecipesBase.apply_recipe])  # FIXME: remaining ambiguities
end
