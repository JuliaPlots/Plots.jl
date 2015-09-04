
# https://github.com/dcjones/Gadfly.jl

immutable GadflyPackage <: PlottingPackage end

plot(pkg::GadflyPackage) = Plot(Qwt.plot(zeros(0,0)), pkg, AVec[], AVec[])
plot!(::GadflyPackage, plt::Plot; kw...) = Qwt.oplot(plt.o; kw...)


# create a blank Gadfly.Plot object
function plot(pkg::GadflyPackage)
  plt = Gadfly.Plot()
  plt.mapping = Dict()
  plt.data_source = DataFrame()
  plt.layers = plt.layers[1:0]
  Plot(plt, pkg, AVec[], AVec[])
end

# plot one data series
function plot!(::GadflyPackage, plt::Plot; kw...)
  d = Dict(kw)
  gd = Dict()  # the kwargs for the call to Gadfly.layer


  append!(plt.o.layers, layer(; gd...))
  plt
end

function Base.display(::GadflyPackage, plt::Plot)
  display(plt.o)
end

# julia> append!(plt.layers, layer(x=collect(1:10), y=collect(1:10), Geom.line(), Geom.point()))
# 2-element Array{Gadfly.Layer,1}:
#  Gadfly.Layer(nothing,Dict{Symbol,Union{AbstractArray{T,N},AbstractString,Distributions.Distribution{F<:Distributions.VariateForm,S<:Distributions.ValueSupport},Expr,Function,Integer,Symbol,Void}}(:y=>[1,2,3,4,5,6,7,8,9,10],:x=>[1,2,3,4,5,6,7,8,9,10]),Gadfly.Stat.Nil(),Gadfly.Geom.LineGeometry(Gadfly.Stat.Identity(),false,2),nothing,0)
#  Gadfly.Layer(nothing,Dict{Symbol,Union{AbstractArray{T,N},AbstractString,Distributions.Distribution{F<:Distributions.VariateForm,S<:Distributions.ValueSupport},Expr,Function,Integer,Symbol,Void}}(:y=>[1,2,3,4,5,6,7,8,9,10],:x=>[1,2,3,4,5,6,7,8,9,10]),Gadfly.Stat.Nil(),Gadfly.Geom.PointGeometry(),nothing,0)

# julia> append!(plt.layers, layer(x=collect(1:10), y=rand(10), Geom.point()))
# 3-element Array{Gadfly.Layer,1}:
#  Gadfly.Layer(nothing,Dict{Symbol,Union{AbstractArray{T,N},AbstractString,Distributions.Distribution{F<:Distributions.VariateForm,S<:Distributions.ValueSupport},Expr,Function,Integer,Symbol,Void}}(:y=>[1,2,3,4,5,6,7,8,9,10],:x=>[1,2,3,4,5,6,7,8,9,10]),Gadfly.Stat.Nil(),Gadfly.Geom.LineGeometry(Gadfly.Stat.Identity(),false,2),nothing,0)
#  Gadfly.Layer(nothing,Dict{Symbol,Union{AbstractArray{T,N},AbstractString,Distributions.Distribution{F<:Distributions.VariateForm,S<:Distributions.ValueSupport},Expr,Function,Integer,Symbol,Void}}(:y=>[1,2,3,4,5,6,7,8,9,10],:x=>[1,2,3,4,5,6,7,8,9,10]),Gadfly.Stat.Nil(),Gadfly.Geom.PointGeometry(),nothing,0)
#  Gadfly.Layer(nothing,Dict{Symbol,Union{AbstractArray{T,N},AbstractString,Distributions.Distribution{F<:Distributions.VariateForm,S<:Distributions.ValueSupport},Expr,Function,Integer,Symbol,Void}}(:y=>[0.6084907709968024,0.05206084912131548,0.14212960794916185,0.10981085500127885,0.9921993333039756,0.9552243188578231,0.3255950301920405,0.1328008877835145,0.8717471404048149,0.18183756751204538],:x=>[1,2,3,4,5,6,7,8,9,10]),Gadfly.Stat.Nil(),Gadfly.Geom.PointGeometry(),nothing,0)

# julia> display(plt)

# # plot(::GadflyPackage, y; kw...) = Gadfly.plot(; x = 1:length(y), y = y, kw...)
# # plot(::GadflyPackage, x, y; kw...) = Gadfly.plot(; x = x, y = y, kw...)
# # plot(::GadflyPackage; kw...) = Gadfly.plot(; kw...)
# # savepng(::GadflyPackage, plt, fn::String, args...) = Gadfly.draw(Gadfly.PNG(fn, args...), plt)
