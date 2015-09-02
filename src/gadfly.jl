
# https://github.com/dcjones/Gadfly.jl

immutable GadflyPackage <: PlottingPackage end

# newplot(pkg::QwtPackage) = Plot(Qwt.plot(zeros(0,0)), pkg, AVec[], AVec[])
# plot!(::GadflyPackage, plt::Plot; kw...) = Qwt.oplot(plt.o; kw...)

# plot(::GadflyPackage, y; kw...) = Gadfly.plot(; x = 1:length(y), y = y, kw...)
# plot(::GadflyPackage, x, y; kw...) = Gadfly.plot(; x = x, y = y, kw...)
# plot(::GadflyPackage; kw...) = Gadfly.plot(; kw...)
# savepng(::GadflyPackage, plt, fn::String, args...) = Gadfly.draw(Gadfly.PNG(fn, args...), plt)
