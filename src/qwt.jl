
# https://github.com/tbreloff/Qwt.jl

immutable QwtPackage <: PlottingPackage end

plot(pkg::QwtPackage; kw...) = Plot(Qwt.plot(zeros(0,0); kw...), pkg, AVec[], AVec[])
plot!(::QwtPackage, plt::Plot; kw...) = Qwt.oplot(plt.o; kw...)
function display(::QwtPackage, plt::Plot)
  Qwt.refresh(plt.o)
  Qwt.showwidget(plt.o)
end

# subplot(::QwtPackage, args...; kw...) = Qwt.subplot(args...; kw...)
# savepng(::QwtPackage, plt, fn::String, args...) = Qwt.savepng(plt, fn)
