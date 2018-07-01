module PlotsTests

# The backends to test may be listed in a colon-delimited environment
# variable
backends2test = Symbol.(lowercase.(
    split(get(ENV,"PLOTS_TEST_BACKENDS","GR:UnicodePlots"),":")))

include("imgcomp.jl")

# don't actually show the plots
srand(1234)
default(show=false, reuse=true)
img_eps = isinteractive() ? 1e-2 : 10e-2

if :gr ∈ backends2test
@testset "GR" begin
    ENV["PLOTS_TEST"] = "true"
    ENV["GKSwstype"] = "100"
    @test gr() == Plots.GRBackend()
    @test backend() == Plots.GRBackend()

    # image_comparison_facts(:gr, eps=img_eps)
    info("Let's just get ONE working first...")
    image_comparison_facts(:gr, skip=collect(range(2,stop=35)), eps=img_eps)
end
end

if :pyplot ∈ backends2test
@testset "PyPlot" begin
    @test pyplot() == Plots.PyPlotBackend()
    @test backend() == Plots.PyPlotBackend()

    image_comparison_facts(:pyplot, eps=img_eps)
end
end

if :unicodeplots ∈ backends2test
@testset "UnicodePlots" begin
    @test unicodeplots() == Plots.UnicodePlotsBackend()
    @test backend() == Plots.UnicodePlotsBackend()

    # lets just make sure it runs without error
    @test isa(plot(rand(10)), Plots.Plot) == true
end
end

# The plotlyjs testimages return a connection error on travis:
# connect: connection refused (ECONNREFUSED)

if :plotlyjs ∈ backends2test
@testset "PlotlyJS" begin
    @test plotlyjs() == Plots.PlotlyJSBackend()
    @test backend() == Plots.PlotlyJSBackend()
    if is_linux() && isinteractive()
        image_comparison_facts(:plotlyjs,
            skip=[
                2,  # animation (skipped for speed)
                27, # (polar plots) takes very long / not working
                31, # animation (skipped for speed)
            ],
            eps=img_eps)
    end
end
end

# InspectDR returns that error on travis:
# ERROR: LoadError: InitError: Cannot open display:
#  in Gtk.GLib.GError(::Gtk.##229#230) at /home/travis/.julia/v0.5/Gtk/src/GLib/gerror.jl:17

if :inspectdr ∈ backends2test
@testset "InspectDR" begin
    @test inspectdr() == Plots.InspectDRBackend()
    @test backend() == Plots.InspectDRBackend()

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
end

if :plotly ∈ backends2test
@testset "Plotly" begin
    @test plotly() == Plots.PlotlyBackend()
    @test backend() == Plots.PlotlyBackend()

    # until png generation is reliable on OSX, just test on linux
    @static is_linux() && image_comparison_facts(:plotly, only=[1,3,4,7,8,9,10,11,12,14,15,20,22,23,27], eps=img_eps)
end
end

# @testset "Immerse" begin
#     @test immerse() == Plots.ImmerseBackend()
#     @test backend() == Plots.ImmerseBackend()
#
#     # as long as we can plot anything without error, it should be the same as Gadfly
#     image_comparison_facts(:immerse, only=[1], eps=img_eps)
# end


# @testset "PlotlyJS" begin
#     @test plotlyjs() == Plots.PlotlyJSBackend()
#     @test backend() == Plots.PlotlyJSBackend()
#
#     # as long as we can plot anything without error, it should be the same as Plotly
#     image_comparison_facts(:plotlyjs, only=[1], eps=img_eps)
# end


# @testset "Gadfly" begin
#     @test gadfly() == Plots.GadflyBackend()
#     @test backend() == Plots.GadflyBackend()
#
#     @test typeof(plot(1:10)) == Plots.Plot{Plots.GadflyBackend}
#     @test plot(Int[1,2,3], rand(3)) == not(nothing)
#     @test plot(sort(rand(10)), rand(Int, 10, 3)) == not(nothing)
#     @test plot!(rand(10,3), rand(10,3)) == not(nothing)
#
#     image_comparison_facts(:gadfly, skip=[4,6,23,24,27], eps=img_eps)
# end




@testset "Axes" begin
    p = plot()
    axis = p.subplots[1][:xaxis]
    @test typeof(axis) == Plots.Axis
    @test Plots.discrete_value!(axis, "HI") == (0.5, 1)
    @test Plots.discrete_value!(axis, :yo) == (1.5, 2)
    @test Plots.ignorenan_extrema(axis) == (0.5,1.5)
    @test axis[:discrete_map] == Dict{Any,Any}(:yo  => 2, "HI" => 1)

    Plots.discrete_value!(axis, ["x$i" for i=1:5])
    Plots.discrete_value!(axis, ["x$i" for i=0:2])
    @test Plots.ignorenan_extrema(axis) == (0.5, 7.5)
end

@testset "NoFail" begin
    histogram([1, 0, 0, 0, 0, 0])
end

# tests for preprocessing recipes

# @testset "recipes" begin

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


end # module
