using Plots, Test

const plots_path = replace("\"$(pkgdir(Plots))\"", raw"\" => raw"\\")

@testset "Default Backend" begin
    out = withenv("PLOTS_DEFAULT_BACKEND" => "Plotly") do
        run(```
           $(Base.julia_cmd()) -E """
               using Pkg
               Pkg.activate(; temp = true)
               Pkg.develop(path = $(plots_path))
               using Test
               using Plots
               @test backend() == Plots.PlotlyBackend()
               """
           ```)
    end
    @test out.exitcode == 0
end
