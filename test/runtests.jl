module PlotsTests

using Plots
using FactCheck

# note: wrap first include in a try block because of the ImageMagick init_deps bug
try
    include("imgcomp.jl")
end
include("imgcomp.jl")

# don't actually show the plots
srand(1234)

# note: we wrap in a try block so that the tests only run if we have the backend installed
# try
  Pkg.installed("Gadfly")
  gadfly()
  backend()
  facts("Gadfly") do
    @fact backend(:gadfly) --> Plots.GadflyPackage()
    default(show=false)
    @fact backend() --> Plots.GadflyPackage()
    @fact typeof(plot(1:10)) --> Plots.Plot{Plots.GadflyPackage}


    # plot(x::AVec, y::AVec; kw...)              # one line (will assert length(x) == length(y))
    @fact plot(Int[1,2,3], rand(3)) --> not(nothing)
    @fact_throws plot(1:5, 1:4)

    # plot(x::AVec, y::AMat; kw...)              # multiple lines (one per column of x), all sharing x (will assert length(x) == size(y,1))
    @fact plot(sort(rand(10)), rand(Int, 10, 3)) --> not(nothing)
    @fact_throws(plot!(rand(10), rand(9,2)))

    # plot(x::AMat, y::AMat; kw...)              # multiple lines (one per column of x/y... will assert size(x) == size(y))
    @fact plot!(rand(10,3), rand(10,3)) --> not(nothing)

    image_comparison_tests(:gadfly, skip=[4,19], eps=1e-2)

  end
# catch err
#     warn("Skipped Gadfly due to: ", string(err))
# end

# # note: we wrap in a try block so that the tests only run if we have the backend installed
# try
#   Pkg.installed("Qwt")
#   qwt()
#   backend()
#   facts("Qwt") do
#     @fact backend(:qwt) --> Plots.QwtPackage()
#     @fact backend() --> Plots.QwtPackage()
#     @fact typeof(plot(1:10)) --> Plots.Plot{Plots.QwtPackage}

#     # plot(y::AVec; kw...)                       # one line... x = 1:length(y)
#     @fact plot(1:10) --> not(nothing)
#     @fact length(current().o.lines) --> 1

#     # plot(x::AVec, f::Function; kw...)          # one line, y = f(x)
#     @fact plot(1:10, sin) --> not(nothing)
#     @fact current().o.lines[1].y --> sin(collect(1:10))

#     # plot(x::AMat, f::Function; kw...)          # multiple lines, yᵢⱼ = f(xᵢⱼ)
#     @fact plot(rand(10,2), sin) --> not(nothing)
#     @fact length(current().o.lines) --> 2

#     # plot(y::AMat; kw...)                       # multiple lines (one per column of x), all sharing x = 1:size(y,1)
#     @fact plot!(rand(10,2)) --> not(nothing)
#     @fact length(current().o.lines) --> 4

#     # plot(x::AVec, fs::AVec{Function}; kw...)   # multiple lines, yᵢⱼ = fⱼ(xᵢ)
#     @fact plot(1:10, Function[sin,cos]) --> not(nothing)
#     @fact current().o.lines[1].y --> sin(collect(1:10))
#     @fact current().o.lines[2].y --> cos(collect(1:10))

#     # plot(y::AVec{AVec}; kw...)                 # multiple lines, each with x = 1:length(y[i])
#     @fact plot([11:20 ; rand(10)]) --> not(nothing)
#     @fact current().o.lines[1].x[4] --> 4
#     @fact current().o.lines[1].y[4] --> 14
#   end
# catch err
#     warn("Skipped Qwt due to: ", string(err))
# end

# try
    # Pkg.installed("PyPlot")
    # pyplot()
    # backend()
    # facts("PyPlot") do
    #     @fact backend(:pyplot) --> Plots.PyPlotPackage()
    #     @fact backend() --> Plots.PyPlotPackage()
    #     @fact typeof(plot(1:10)) --> Plots.Plot{Plots.PyPlotPackage}

    #     # image_comparison_tests(:pyplot, skip=[19])
    # end
# catch err
#     warn("Skipped PyPlot due to: ", string(err))
# end


# try
#     Pkg.installed("UnicodePlots")
#     unicodeplots()
#     backend()
#     facts("UnicodePlots") do
#         @fact backend(:unicodeplots) --> Plots.UnicodePlotsPackage()
#         @fact backend() --> Plots.UnicodePlotsPackage()
#         @fact typeof(plot(1:10)) --> Plots.Plot{Plots.UnicodePlotsPackage}
#     end
# catch err
#     warn("Skipped UnicodePlots due to: ", string(err))
# end


# try
#     Pkg.installed("Winston")
#     winston()
#     backend()
#     facts("Winston") do
#         @fact backend(:winston) --> Plots.WinstonPackage()
#         @fact backend() --> Plots.WinstonPackage()
#         @fact typeof(plot(1:10)) --> Plots.Plot{Plots.WinstonPackage}
#     end
# catch err
#     warn("Skipped Winston due to: ", string(err))
# end


FactCheck.exitstatus()
end # module
