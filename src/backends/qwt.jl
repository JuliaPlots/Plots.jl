
# https://github.com/tbreloff/Qwt.jl

immutable QwtPackage <: PlottingPackage end

export qwt
qwt() = backend(:qwt)

# supportedArgs(::QwtPackage) = setdiff(_allArgs, [:xlims, :ylims, :xticks, :yticks])
supportedArgs(::QwtPackage) = [
    :annotation,
    :args,
    :axis,
    :background_color,
    :color,
    :fillto,
    :foreground_color,
    :group,
    :heatmap_c,
    :kwargs,
    :label,
    :layout,
    :legend,
    :linestyle,
    :linetype,
    :marker,
    :markercolor,
    :markersize,
    :n,
    :nbins,
    :nc,
    :nr,
    :pos,
    :reg,
    # :ribbon,
    :show,
    :size,
    :title,
    :width,
    :windowtitle,
    :x,
    :xlabel,
    # :xlims,
    # :xticks,
    :y,
    :ylabel,
    # :ylims,
    :yrightlabel,
    # :yticks,
  ]
supportedTypes(::QwtPackage) = [:none, :line, :path, :steppre, :steppost, :sticks, :scatter, :heatmap, :hexbin, :hist, :bar]
supportedMarkers(::QwtPackage) = [:none, :auto, :rect, :ellipse, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star1, :star2, :hexagon]

# -------------------------------

const _qwtAliases = Dict(
    :nbins => :heatmap_n,
    :hexbin => :heatmap,
    :path => :line,
    :steppost => :step,
    :steppre => :stepinverted,
  )

function replaceLinetypeAlias(d)
  if haskey(_qwtAliases, d[:linetype])
    d[:linetype] = _qwtAliases[d[:linetype]]
  end
end

function adjustQwtKeywords(iscreating::Bool; kw...)
  d = Dict(kw)
  if d[:linetype] == :scatter
    d[:linetype] = :none
    if d[:marker] == :none
      d[:marker] = :ellipse
    end
  elseif !iscreating && d[:linetype] == :bar
    d = barHack(; kw...)
  elseif !iscreating && d[:linetype] == :hist
    d = barHack(; histogramHack(; kw...)...)
  end

  replaceLinetypeAlias(d)
  d
end

function plot(pkg::QwtPackage; kw...)
  d = Dict(kw)
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

function updatePlotItems(plt::Plot{QwtPackage}, d::Dict)
  haskey(d, :title) && Qwt.title(plt.o, d[:title])
  haskey(d, :xlabel) && Qwt.xlabel(plt.o, d[:xlabel])
  haskey(d, :ylabel) && Qwt.ylabel(plt.o, d[:ylabel])
end



# ----------------------------------------------------------------

# accessors for x/y data

function Base.getindex(plt::Plot{QwtPackage}, i::Int)
  series = plt.o.lines[i]
  series.x, series.y
end

function Base.setindex!(plt::Plot{QwtPackage}, xy::Tuple, i::Integer)
  series = plt.o.lines[i]
  series.x, series.y = xy
  plt
end


# -------------------------------

# savepng(::QwtPackage, plt::PlottingObject, fn::AbstractString, args...) = Qwt.savepng(plt.o, fn)

# -------------------------------

# create the underlying object (each backend will do this differently)
function buildSubplotObject!(subplt::Subplot{QwtPackage})
  i = 0
  rows = []
  for rowcnt in subplt.layout.rowcounts
    push!(rows, Qwt.hsplitter([plt.o for plt in subplt.plts[(1:rowcnt) + i]]...))
    i += rowcnt
  end
  subplt.o = Qwt.vsplitter(rows...)
  Qwt.resizewidget(subplt.o, subplt.initargs[1][:size]...)
  Qwt.moveToLastScreen(subplt.o)  # hack so it goes to my center monitor... sorry
end

# ----------------------------------------------------------------

function Base.writemime(io::IO, ::MIME"image/png", plt::PlottingObject{QwtPackage})
  Qwt.savepng(plt.o, "/tmp/dfskjdhfkh.png")
  write(io, readall("/tmp/dfskjdhfkh.png"))
end


function Base.display(::PlotsDisplay, plt::Plot{QwtPackage})
  Qwt.refresh(plt.o)
  Qwt.showwidget(plt.o)
end

function Base.display(::PlotsDisplay, subplt::Subplot{QwtPackage})
  for plt in subplt.plts
    Qwt.refresh(plt.o)
  end

  Qwt.showwidget(subplt.o)
end

