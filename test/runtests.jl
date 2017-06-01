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

facts("GR") do
    @fact gr() --> Plots.GRBackend()
    @fact backend() --> Plots.GRBackend()

    image_comparison_facts(:gr, eps=img_eps)
end

facts("PyPlot") do
    @fact pyplot() --> Plots.PyPlotBackend()
    @fact backend() --> Plots.PyPlotBackend()

    image_comparison_facts(:pyplot,
        skip=[
            2,  # animation (skipped for speed)
            31, # animation (skipped for speed)
        ],
        eps=img_eps)
end

facts("PlotlyJS") do
    @fact plotlyjs() --> Plots.PlotlyJSBackend()
    @fact backend() --> Plots.PlotlyJSBackend()

    if is_linux()
        image_comparison_facts(:plotlyjs,
            skip=[
                2,  # animation (skipped for speed)
                27, # (polar plots) takes very long / not working
                31, # animation (skipped for speed)
            ],
            eps=img_eps)
    end
end

facts("InspectDR") do
    @fact inspectdr() --> Plots.InspectDRBackend()
    @fact backend() --> Plots.InspectDRBackend()

    image_comparison_facts(:inspectdr,
        skip=[
            2,  # animation
            6,  # heatmap not defined
            10, # heatmap not defined
            22, # contour not defined
            23, # pie not defined
            27, # polar plot not working
            28, # heatmap not defined
            31, # animation
        ],
        eps=img_eps)
end

# facts("Plotly") do
#     @fact plotly() --> Plots.PlotlyBackend()
#     @fact backend() --> Plots.PlotlyBackend()
#
#     # # until png generation is reliable on OSX, just test on linux
#     # @static is_linux() && image_comparison_facts(:plotly, only=[1,3,4,7,8,9,10,11,12,14,15,20,22,23,27], eps=img_eps)
#     image_comparison_facts(:plotly, eps=img_eps)
# end

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
    @fact isa(plot(rand(10)), Plots.Plot) --> true
end



facts("Axes") do
    p = plot()
    axis = p.subplots[1][:xaxis]
    @fact typeof(axis) --> Plots.Axis
    @fact Plots.discrete_value!(axis, "HI") --> (0.5, 1)
    @fact Plots.discrete_value!(axis, :yo) --> (1.5, 2)
    @fact extrema(axis) --> (0.5,1.5)
    @fact axis[:discrete_map] --> Dict{Any,Any}(:yo  => 2, "HI" => 1)

    Plots.discrete_value!(axis, ["x$i" for i=1:5])
    Plots.discrete_value!(axis, ["x$i" for i=0:2])
    @fact extrema(axis) --> (0.5, 7.5)
end


# tests for preprocessing recipes

# facts("recipes") do

    # user recipe

    # type T end
    # @recipe function f(::T)
    #     line := (3,0.3,:red)
    #     marker := (20,0.5,:blue,:o)
    #     bg := :yellow
    #     rand(10)
    # end
    # plot(T())

    # plot recipe

    # @recipe function f(::Type{Val{:hiplt}},plt::Plot)
    #     line := (3,0.3,:red)
    #     marker := (20,0.5,:blue,:o)
    #     t := :path
    #     bg:=:green
    #     ()
    # end
    # plot(rand(10),t=:hiplt)

    # series recipe

    # @recipe function f(::Type{Val{:hi}},x,y,z)
    #     line := (3,0.3,:red)
    #     marker := (20,0.5,:blue,:o)
    #     t := :path
    #     ()
    # end
    # plot(rand(10),t=:hiplt)

# end



FactCheck.exitstatus()
end # module
