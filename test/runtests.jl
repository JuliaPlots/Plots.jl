module PlotsTests

include("imgcomp.jl")

# don't actually show the plots
srand(1234)
default(show=false)
img_eps = 5e-2

facts("Gadfly") do
    @fact gadfly() --> Plots.GadflyBackend()
    @fact backend() --> Plots.GadflyBackend()

    @fact typeof(plot(1:10)) --> Plots.Plot{Plots.GadflyBackend}
    @fact plot(Int[1,2,3], rand(3)) --> not(nothing)
    @fact plot(sort(rand(10)), rand(Int, 10, 3)) --> not(nothing)
    @fact plot!(rand(10,3), rand(10,3)) --> not(nothing)

    image_comparison_facts(:gadfly, skip=[4,6,19,23,24,27], eps=img_eps)
end

facts("PyPlot") do
    @fact pyplot() --> Plots.PyPlotBackend()
    @fact backend() --> Plots.PyPlotBackend()

    image_comparison_facts(:pyplot, skip=[4,10,13,19,21,23,27], eps=img_eps)
end

facts("GR") do
    @fact gr() --> Plots.GRBackend()
    @fact backend() --> Plots.GRBackend()

    # image_comparison_facts(:gr, only=[1], eps=img_eps)
end

facts("Plotly") do
    @fact plotly() --> Plots.PlotlyBackend()
    @fact backend() --> Plots.PlotlyBackend()

    # # until png generation is reliable on OSX, just test on linux
    # @linux_only image_comparison_facts(:plotly, only=[1,3,4,7,8,9,10,11,12,14,15,20,22,23,27], eps=img_eps)
end

FactCheck.exitstatus()
end # module
