using Plots, Test

const plots_path = escape_string(pkgdir(Plots))

@testset "Default Backend" begin
    set_preferences!(Plots, "default_backend" => "plotly")
    out = run(```
           $(Base.julia_cmd()) -E """
               using Pkg
               Pkg.activate(; temp = true)
               Pkg.develop(path = \"$(plots_path)\")
               using Test
               using Plots
               @test backend() == Plots.PlotlyBackend()
               """
           ```)
    @test out.exitcode == 0
    set_preferences!(Plots, "default_backend" => Plots._fallback_default_backend(), force = true)
end
