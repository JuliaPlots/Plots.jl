
# Qwt

plot(::QwtPackage, args...; kw...) = Qwt.plot(args...; kw...)
subplot(::QwtPackage, args...; kw...) = Qwt.subplot(args...; kw...)
savepng(::QwtPackage, plt, fn::String, args...) = Qwt.savepng(plt, fn)
