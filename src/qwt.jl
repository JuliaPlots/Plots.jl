
# https://github.com/tbreloff/Qwt.jl

immutable QwtPackage <: PlottingPackage end

function adjustQwtKeywords(; kw...)
  d = Dict(kw)
  if d[:linetype] == :hexbin
    d[:linetype] = :heatmap
  elseif d[:linetype] == :dots
    d[:linetype] = :none
    d[:marker] = :hexagon
  end
  d[:heatmap_n] = d[:nbins]
  d
end

function plot(pkg::QwtPackage; kw...)
  kw = adjustQwtKeywords(;kw...)
  plt = Plot(Qwt.plot(zeros(0,0); kw..., show=false), pkg, 0)
  plt
end

function plot!(::QwtPackage, plt::Plot; kw...)
  kw = adjustQwtKeywords(;kw...)
  Qwt.oplot(plt.o; kw...)
end

function Base.display(::QwtPackage, plt::Plot)
  Qwt.refresh(plt.o)
  Qwt.showwidget(plt.o)
end

savepng(::QwtPackage, plt::Plot, fn::String, args...) = Qwt.savepng(plt.o, fn)

# subplot(::QwtPackage, args...; kw...) = Qwt.subplot(args...; kw...)
