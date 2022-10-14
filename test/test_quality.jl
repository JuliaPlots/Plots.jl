@testset "Aqua" begin
    # JuliaTesting/Aqua.jl/issues/77
    Aqua.test_all(Plots; ambiguities = false)
    # Aqua.test_ambiguities(Plots)
end
