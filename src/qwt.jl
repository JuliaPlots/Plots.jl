
# https://github.com/tbreloff/Qwt.jl

immutable QwtPackage <: PlottingPackage end

# -------------------------------

function adjustQwtKeywords(iscreating::Bool; kw...)
  d = Dict(kw)
  d[:heatmap_n] = d[:nbins]

  if d[:linetype] == :hexbin
    d[:linetype] = :heatmap
  elseif d[:linetype] == :dots
    d[:linetype] = :none
    d[:marker] = :hexagon
  elseif !iscreating && d[:linetype] == :bar
    return barHack(; kw...)
  elseif !iscreating && d[:linetype] == :hist
    return barHack(; histogramHack(; kw...)...)
  end
  d
end

function plot(pkg::QwtPackage; kw...)
  kw = adjustQwtKeywords(true; kw...)
  plt = Plot(Qwt.plot(zeros(0,0); kw..., show=false), pkg, 0)
  plt
end

function plot!(::QwtPackage, plt::Plot; kw...)
  kw = adjustQwtKeywords(false; kw...)
  Qwt.oplot(plt.o; kw...)
end

function Base.display(::QwtPackage, plt::Plot)
  Qwt.refresh(plt.o)
  Qwt.showwidget(plt.o)
end

# -------------------------------

savepng(::QwtPackage, plt::PlottingObject, fn::String, args...) = Qwt.savepng(plt.o, fn)

# -------------------------------

# # create the underlying object (each backend will do this differently)
# o = buildSubplotObject(plts, pkg, layout)

function buildSubplotObject(plts::Vector{Plot}, pkg::QwtPackage, layout::SubplotLayout)
  Qwt.vsplitter([Qwt.hsplitter([plt.o for plt in plts[i:(i+rowcnt-1)]]...) for rowcnt in layout.rowcounts]...)
end


function Base.display(::QwtPackage, subplt::Subplot)
  for plt in subplt.plts
    Qwt.refresh(plt.o)
  end
  Qwt.showwidget(subplt.o)
end

