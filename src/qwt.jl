
# https://github.com/tbreloff/Qwt.jl

immutable QwtPackage <: PlottingPackage end

function adjustQwtKeywords(; kw...)
  d = Dict(kw)
  if d[:linetype] == :hexbin
    d[:linetype] = :heatmap
  end
  d
end

function plot(pkg::QwtPackage; kw...)
  kw = adjustQwtKeywords(;kw...)
  plt = Plot(Qwt.plot(zeros(0,0); kw..., show=false), pkg, 0)
  # d = Dict(kw)
  # if haskey(d, :background_color)
  #   Qwt.background!(plt.o, Dict(kw)[:background_color])
  # end
  plt
end

function plot!(::QwtPackage, plt::Plot; kw...)
  kw = adjustQwtKeywords(;kw...)
  # d = Dict(kw)
  # if haskey(d, :background_color)
  #   Qwt.background!(plt.o, Dict(kw)[:background_color])
  # end
  Qwt.oplot(plt.o; kw...)
end

function Base.display(::QwtPackage, plt::Plot)
  Qwt.refresh(plt.o)
  Qwt.showwidget(plt.o)
end

savepng(::QwtPackage, plt::Plot, fn::String, args...) = Qwt.savepng(plt.o, fn)

# subplot(::QwtPackage, args...; kw...) = Qwt.subplot(args...; kw...)
