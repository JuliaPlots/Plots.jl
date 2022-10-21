@testset "allocations" begin
    if Sys.islinux()
        with(:gr) do
            stats = @timed plot(1:2)
            ref_bytes = 53_196_261  # measured on v1.35.5 - 1.8.2
            if stats.bytes > ref_bytes
                @warn "Allocations might have increased ($(stats.bytes) > $ref_bytes)"
            end
        end
    end
end

@testset "Auto QUality Assurance" begin
    # JuliaTesting/Aqua.jl/issues/77
    # TODO: fix :Contour, :Latexify and :LaTeXStrings stale imports in Plots 2.0
    # :PyCall and :Conda stale deps show up when running CI
    Aqua.test_all(
        Plots;
        stale_deps = (; ignore = [:PyCall, :Conda, :Contour, :Latexify, :LaTeXStrings]),
        ambiguities = false,
    )
    Aqua.test_ambiguities(Plots; exclude = [RecipesBase.apply_recipe])  # FIXME: remaining ambiguities
end
