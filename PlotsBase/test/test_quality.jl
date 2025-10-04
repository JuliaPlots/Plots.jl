@testset "Auto QUality Assurance" begin
    # JuliaTesting/Aqua.jl/issues/77
    # :CondaPkg stale deps show up when running CI
    Aqua.test_all(
        PlotsBase;
        stale_deps = (; ignore = [:Colors, :Contour, :LaTeXStrings, :Latexify, :CondaPkg]),
        persistent_tasks = false,
        ambiguities = false,
        deps_compat = false,  # FIXME: fails `CondaPkg`
        piracies = false,
    )
    Aqua.test_ambiguities(PlotsBase; exclude = [RecipesBase.apply_recipe])  # FIXME: remaining ambiguities
end
