module PlotsTests

include("imgcomp.jl")

# don't actually show the plots
srand(1234)
default(show=false, reuse=true)
img_eps = isinteractive() ? 1e-2 : 10e-2

# facts("Gadfly") do
#     @fact gadfly() --> Plots.GadflyBackend()
#     @fact backend() --> Plots.GadflyBackend()
#
#     @fact typeof(plot(1:10)) --> Plots.Plot{Plots.GadflyBackend}
#     @fact plot(Int[1,2,3], rand(3)) --> not(nothing)
#     @fact plot(sort(rand(10)), rand(Int, 10, 3)) --> not(nothing)
#     @fact plot!(rand(10,3), rand(10,3)) --> not(nothing)
#
#     image_comparison_facts(:gadfly, skip=[4,6,23,24,27], eps=img_eps)
# end

facts("PyPlot") do
    @fact pyplot() --> Plots.PyPlotBackend()
    @fact backend() --> Plots.PyPlotBackend()

    image_comparison_facts(:pyplot, skip=[], eps=img_eps)
end

facts("GR") do
    @fact gr() --> Plots.GRBackend()
    @fact backend() --> Plots.GRBackend()

    @linux_only image_comparison_facts(:gr, skip=[], eps=img_eps)
end

facts("Plotly") do
    @fact plotly() --> Plots.PlotlyBackend()
    @fact backend() --> Plots.PlotlyBackend()

    # # until png generation is reliable on OSX, just test on linux
    # @linux_only image_comparison_facts(:plotly, only=[1,3,4,7,8,9,10,11,12,14,15,20,22,23,27], eps=img_eps)
end


# facts("Immerse") do
#     @fact immerse() --> Plots.ImmerseBackend()
#     @fact backend() --> Plots.ImmerseBackend()
#
#     # as long as we can plot anything without error, it should be the same as Gadfly
#     image_comparison_facts(:immerse, only=[1], eps=img_eps)
# end


# facts("PlotlyJS") do
#     @fact plotlyjs() --> Plots.PlotlyJSBackend()
#     @fact backend() --> Plots.PlotlyJSBackend()
#
#     # as long as we can plot anything without error, it should be the same as Plotly
#     image_comparison_facts(:plotlyjs, only=[1], eps=img_eps)
# end


facts("UnicodePlots") do
    @fact unicodeplots() --> Plots.UnicodePlotsBackend()
    @fact backend() --> Plots.UnicodePlotsBackend()

    # lets just make sure it runs without error
    @fact isa(plot(rand(10)), Plot) --> true
end



facts("Axes") do
    p = plot()
    axis = p.subplots[1][:xaxis]
    @fact typeof(axis) --> Axis
    @fact Plots.discrete_value!(axis, "HI") --> (0.5, 1)
    @fact Plots.discrete_value!(axis, :yo) --> (1.5, 2)
    @fact extrema(axis) --> (0.5,1.5)
    @fact axis[:discrete_map] --> Dict{Any,Any}(:yo  => 2, "HI" => 1)

    Plots.discrete_value!(axis, ["x$i" for i=1:5])
    Plots.discrete_value!(axis, ["x$i" for i=0:2])
    @fact extrema(axis) --> (0.5, 7.5)
end




FactCheck.exitstatus()
end # module
