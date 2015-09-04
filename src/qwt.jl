
# https://github.com/tbreloff/Qwt.jl

immutable QwtPackage <: PlottingPackage end

plot(pkg::QwtPackage; kw...) = Plot(Qwt.plot(zeros(0,0); kw...), pkg, AVec[], AVec[])
plot!(::QwtPackage, plt::Plot; kw...) = Qwt.oplot(plt.o; kw...)
function Base.display(::QwtPackage, plt::Plot)
  Qwt.refresh(plt.o)
  Qwt.showwidget(plt.o)
end

savepng(::QwtPackage, plt::Plot, fn::String, args...) = Qwt.savepng(plt.o, fn)

# subplot(::QwtPackage, args...; kw...) = Qwt.subplot(args...; kw...)
