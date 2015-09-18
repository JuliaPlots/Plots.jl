
# https://github.com/tbreloff/Qwt.jl

immutable QwtPackage <: PlottingPackage end

export qwt!
qwt!() = plotter!(:qwt)

supportedTypes(::QwtPackage) = [:none, :line, :step, :stepinverted, :sticks, :scatter, :heatmap, :hexbin, :hist, :bar]

# -------------------------------

function adjustQwtKeywords(iscreating::Bool; kw...)
  d = Dict(kw)
  d[:heatmap_n] = d[:nbins]

  if d[:linetype] == :hexbin
    d[:linetype] = :heatmap
  elseif d[:linetype] == :scatter
    d[:linetype] = :none
    if d[:marker] == :none
      d[:marker] = :ellipse
    end
  elseif !iscreating && d[:linetype] == :bar
    return barHack(; kw...)
  elseif !iscreating && d[:linetype] == :hist
    return barHack(; histogramHack(; kw...)...)
  end
  d
end

function plot(pkg::QwtPackage; kw...)
  d = adjustQwtKeywords(true; kw...)
  o = Qwt.plot(zeros(0,0); d..., show=false)
  plt = Plot(o, pkg, 0, d, Dict[])
  plt
end

function plot!(::QwtPackage, plt::Plot; kw...)
  d = adjustQwtKeywords(false; kw...)
  Qwt.oplot(plt.o; d...)
  push!(plt.seriesargs, d)
  plt
end

function Base.display(::QwtPackage, plt::Plot)
  Qwt.refresh(plt.o)
  Qwt.showwidget(plt.o)
end

# -------------------------------

savepng(::QwtPackage, plt::PlottingObject, fn::AbstractString, args...) = Qwt.savepng(plt.o, fn)

# -------------------------------

# create the underlying object (each backend will do this differently)
function buildSubplotObject!(::QwtPackage, subplt::Subplot)
  i = 0
  rows = []
  for rowcnt in subplt.layout.rowcounts
    push!(rows, Qwt.hsplitter([plt.o for plt in subplt.plts[(1:rowcnt) + i]]...))
    i += rowcnt
  end
  subplt.o = Qwt.vsplitter(rows...)
  Qwt.resizewidget(subplt.o, subplt.initargs[:size]...)
  Qwt.moveToLastScreen(subplt.o)  # hack so it goes to my center monitor... sorry
end


function Base.display(::QwtPackage, subplt::Subplot)
  for plt in subplt.plts
    Qwt.refresh(plt.o)
  end

  Qwt.showwidget(subplt.o)
end

