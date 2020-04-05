using AbstractPlotting, CairoMakie
using MakieRecipes
using MakieRecipes.RecipesBase
using DifferentialEquations, MarketData, TimeSeries

sc = Scene()
# # The simplest example model
struct T end
RecipesBase.@recipe function plot(::T, n = 1)
    markershape --> :auto        # if markershape is unset, make it :auto
    markercolor :=  :green  # force markercolor to be customcolor
    xrotation   --> 45           # if xrotation is unset, make it 45
    zrotation   --> 90           # if zrotation is unset, make it 90
    rand(10,n)                   # return the arguments (input data) for the next recipe
end

@test_nowarn recipeplot(T(); seriestype = :path)

RecipesBase.is_key_supported(::Symbol) = true
# AbstractPlotting.scatter!(sc, rand(10))

sc = Scene()
@test_nowarn recipeplot!(sc, rand(10, 2); seriestype = :scatter)
@test_nowarn recipeplot!(sc, 1:10, rand(10, 1); seriestype = :path)

f(u,p,t) = 1.01.*u
u0 = [1/2, 1]
tspan = (0.0,1.0)
prob = ODEProblem(f,u0,tspan)
sol = solve(prob, Tsit5(), reltol=1e-8, abstol=1e-8)
@test_nowarn recipeplot(sol)

A  = [1. 0  0 -5
      4 -2  4 -3
     -4  0  0  1
      5 -2  2  3]
u0 = rand(4,2)
tspan = (0.0,1.0)
f(u,p,t) = A*u
prob = ODEProblem(f,u0,tspan)
sol = solve(prob, Tsit5(), reltol=1e-8, abstol=1e-8)
@test_nowarn recipeplot(sol)

f(du,u,p,t) = (du .= u)
g(du,u,p,t) = (du .= u)
u0 = rand(4,2)
W = WienerProcess(0.0,0.0,0.0)
prob = SDEProblem(f,g,u0,(0.0,1.0),noise=W)
sol = solve(prob,SRIW1())
@test_nowarn recipeplot(sol)

@test_nowarn recipeplot(AbstractPlotting.peaks(); seriestype = :surface, cgrad = :inferno)
@test_nowarn recipeplot(AbstractPlotting.peaks(); seriestype = :heatmap, cgrad = :RdYlBu)
# Timeseries with market data
@test_nowarn recipeplot(MarketData.ohlc; seriestype = :path)
