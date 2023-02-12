@testset "Auto QUality Assurance" begin
    # JuliaTesting/Aqua.jl/issues/77
    # TODO: fix :Contour, :Latexify and :LaTeXStrings stale imports in Plots 2.0
    # :PyCall and :Conda stale deps show up when running CI
    Aqua.test_all(
        Plots;
        stale_deps = (;
            ignore = [:GR, :CondaPkg, :Contour, :Latexify, :LaTeXStrings, :Requires]
        ),
        project_toml_formatting = false,  # issues since weak deps
        ambiguities = false,
        deps_compat = false,  # FIXME: fails `CondaPkg`
        piracy = false,
    )
    Aqua.test_ambiguities(Plots; exclude = [RecipesBase.apply_recipe])  # FIXME: remaining ambiguities
end
