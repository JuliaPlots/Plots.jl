module PlotsTests

using Plots
using FactCheck

# don't actually show the plots
default(show=false)
srand(1234)

# note: we wrap in a try block so that the tests only run if we have the backend installed
try
  Pkg.installed("Gadfly")
  facts("Gadfly") do
    @fact backend(:gadfly) --> Plots.GadflyPackage()
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
    # @fact_throws plot!(rand(10,3), rand(10,2))


    # plot(x::AVec, y::AVec{AVec}; kw...)        # multiple lines, will assert length(x) == length(y[i])


    # plot(x::AVec{AVec}, y::AVec{AVec}; kw...)  # multiple lines, will assert length(x[i]) == length(y[i])
    # plot(n::Integer; kw...)                    # n lines, all empty (for updating plots)
  end
end

# note: we wrap in a try block so that the tests only run if we have the backend installed
try
  Pkg.installed("Qwt")
  facts("Qwt") do
    @fact backend(:qwt) --> Plots.QwtPackage()
    @fact backend() --> Plots.QwtPackage()
    @fact typeof(plot(1:10)) --> Plots.Plot{Plots.QwtPackage}

    # plot(y::AVec; kw...)                       # one line... x = 1:length(y)
    @fact plot(1:10) --> not(nothing)
    @fact length(current().o.lines) --> 1

    # plot(x::AVec, f::Function; kw...)          # one line, y = f(x)
    @fact plot(1:10, sin) --> not(nothing)
    @fact current().o.lines[1].y --> sin(collect(1:10))

    # plot(x::AMat, f::Function; kw...)          # multiple lines, yᵢⱼ = f(xᵢⱼ)
    @fact plot(rand(10,2), sin) --> not(nothing)
    @fact length(current().o.lines) --> 2

    # plot(y::AMat; kw...)                       # multiple lines (one per column of x), all sharing x = 1:size(y,1)
    @fact plot!(rand(10,2)) --> not(nothing)
    @fact length(current().o.lines) --> 4

    # plot(x::AVec, fs::AVec{Function}; kw...)   # multiple lines, yᵢⱼ = fⱼ(xᵢ)
    @fact plot(1:10, Function[sin,cos]) --> not(nothing)
    @fact current().o.lines[1].y --> sin(collect(1:10))
    @fact current().o.lines[2].y --> cos(collect(1:10))

    # plot(y::AVec{AVec}; kw...)                 # multiple lines, each with x = 1:length(y[i])
    @fact plot([11:20 ; rand(10)]) --> not(nothing)
    @fact current().o.lines[1].x[4] --> 4
    @fact current().o.lines[1].y[4] --> 14
  end
end


FactCheck.exitstatus()
end # module
