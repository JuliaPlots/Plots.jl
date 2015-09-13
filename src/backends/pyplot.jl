
# https://github.com/tbreloff/Qwt.jl

immutable PyPlotPackage <: PlottingPackage end

pyplot!() = plotter!(:pyplot)

# -------------------------------

# function adjustQwtKeywords(iscreating::Bool; kw...)
#   d = Dict(kw)
#   d[:heatmap_n] = d[:nbins]

#   if d[:linetype] == :hexbin
#     d[:linetype] = :heatmap
#   elseif d[:linetype] == :dots
#     d[:linetype] = :none
#     d[:marker] = :hexagon
#   elseif !iscreating && d[:linetype] == :bar
#     return barHack(; kw...)
#   elseif !iscreating && d[:linetype] == :hist
#     return barHack(; histogramHack(; kw...)...)
#   end
#   d
# end

function plot(pkg::PyPlotPackage; kw...)
  # kw = adjustQwtKeywords(true; kw...)
  # o = Qwt.plot(zeros(0,0); kw..., show=false)
  plt = Plot(o, pkg, 0, kw, Dict[])
  plt
end

function plot!(::PyPlotPackage, plt::Plot; kw...)
  # kw = adjustQwtKeywords(false; kw...)
  # Qwt.oplot(plt.o; kw...)
  push!(plt.seriesargs, kw)
  plt
end

function Base.display(::PyPlotPackage, plt::Plot)
  # Qwt.refresh(plt.o)
  # Qwt.showwidget(plt.o)
  display(plt.o)
end

# -------------------------------

savepng(::PyPlotPackage, plt::PlottingObject, fn::String, args...) = error("unsupported")

# -------------------------------

# create the underlying object (each backend will do this differently)
function buildSubplotObject!(::PyPlotPackage, subplt::Subplot)
  # i = 0
  # rows = []
  # for rowcnt in subplt.layout.rowcounts
  #   push!(rows, Qwt.hsplitter([plt.o for plt in subplt.plts[(1:rowcnt) + i]]...))
  #   i += rowcnt
  # end
  # subplt.o = Qwt.vsplitter(rows...)
  error("unsupported")
end


function Base.display(::PyPlotPackage, subplt::Subplot)
  # for plt in subplt.plts
  #   Qwt.refresh(plt.o)
  # end
  # Qwt.showwidget(subplt.o)
  display(subplt.o)
end

