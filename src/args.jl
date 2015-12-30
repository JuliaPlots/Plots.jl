

const _allAxes = [:auto, :left, :right]
@compat const _axesAliases = Dict(
    :a => :auto,
    :l => :left,
    :r => :right
  )

const _3dTypes = [:path3d, :scatter3d, :surface, :wireframe]
const _allTypes = vcat([
                        :none, :line, :path, :steppre, :steppost, :sticks, :scatter,
                        :heatmap, :hexbin, :hist, :density, :bar, :hline, :vline, :ohlc,
                        :contour, :pie
                       ], _3dTypes)
@compat const _typeAliases = Dict(
    :n             => :none,
    :no            => :none,
    :l             => :line,
    :p             => :path,
    :stepinv       => :steppre,
    :stepsinv      => :steppre,
    :stepinverted  => :steppre,
    :stepsinverted => :steppre,
    :step          => :steppost,
    :steps         => :steppost,
    :stair         => :steppost,
    :stairs        => :steppost,
    :stem          => :sticks,
    :stems         => :sticks,
    :dots          => :scatter,
    :histogram     => :hist,
    :pdf           => :density,
    :contours      => :contour,
    :line3d        => :path3d,
    :surf          => :surface,
    :wire          => :wireframe,
  )

ishistlike(lt::Symbol) = lt in (:hist, :density)
islinelike(lt::Symbol) = lt in (:line, :path, :steppre, :steppost)
isheatmaplike(lt::Symbol) = lt in (:heatmap, :hexbin)


const _allStyles = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]
@compat const _styleAliases = Dict(
    :a    => :auto,
    :s    => :solid,
    :d    => :dash,
    :dd   => :dashdot,
    :ddd  => :dashdotdot,
  )

# const _allMarkers = [:none, :auto, :ellipse, :rect, :diamond, :utriangle, :dtriangle,
#                      :cross, :xcross, :star5, :star8, :hexagon, :octagon, Shape]
const _allMarkers = vcat(:none, :auto, sort(collect(keys(_shapes))))
@compat const _markerAliases = Dict(
    :n            => :none,
    :no           => :none,
    :a            => :auto,
    :circle       => :ellipse,
    :c            => :ellipse,
    :square       => :rect,
    :sq           => :rect,
    :r            => :rect,
    :d            => :diamond,
    :^            => :utriangle,
    :ut           => :utriangle,
    :utri         => :utriangle,
    :uptri        => :utriangle,
    :uptriangle   => :utriangle,
    :v            => :dtriangle,
    :V            => :dtriangle,
    :dt           => :dtriangle,
    :dtri         => :dtriangle,
    :downtri      => :dtriangle,
    :downtriangle => :dtriangle,
    :+            => :cross,
    :plus         => :cross,
    :x            => :xcross,
    :X            => :xcross,
    :star         => :star5,
    :s            => :star5,
    :star1        => :star5,
    :s2           => :star8,
    :star2        => :star8,
    :p            => :pentagon,
    :pent         => :pentagon,
    :h            => :hexagon,
    :hex          => :hexagon,
    :hep          => :heptagon,
    :o            => :octagon,
    :oct          => :octagon,
    :spike        => :vline,
  )

const _allScales = [:identity, :ln, :log2, :log10, :asinh, :sqrt]
@compat const _scaleAliases = Dict(
    :none => :identity,
    :log  => :log10,
  )

# -----------------------------------------------------------------------------

const _seriesDefaults = Dict{Symbol, Any}()

# series-specific
_seriesDefaults[:axis]            = :left
_seriesDefaults[:label]           = "AUTO"
_seriesDefaults[:linetype]        = :path
_seriesDefaults[:linestyle]       = :solid
_seriesDefaults[:linewidth]       = 1
_seriesDefaults[:linecolor]       = :auto
_seriesDefaults[:linealpha]       = nothing
# _seriesDefaults[:linestroke]      = Stroke(1, :auto, nothing, :solid)  # linewidth, linecolor, linealpha, linestyle
# _seriesDefaults[:fillbrush]       = Brush(nothing, :match, nothing)  # fillrange, fillcolor, fillalpha
_seriesDefaults[:fillrange]       = nothing   # ribbons, areas, etc
_seriesDefaults[:fillcolor]       = :match
_seriesDefaults[:fillalpha]       = nothing
_seriesDefaults[:markershape]     = :none
# _seriesDefaults[:markerstroke]    = Stroke(1, :match_foreground, nothing, :solid)
# _seriesDefaults[:markerbrush]     = Brush(6, :match, nothing)
_seriesDefaults[:markercolor]     = :match
_seriesDefaults[:markeralpha]     = nothing
_seriesDefaults[:markersize]      = 6
_seriesDefaults[:markerstrokestyle] = :solid
_seriesDefaults[:markerstrokewidth] = 1
_seriesDefaults[:markerstrokecolor] = :match
_seriesDefaults[:markerstrokealpha] = nothing
# _seriesDefaults[:ribbon]          = nothing
# _seriesDefaults[:ribboncolor]     = :match
_seriesDefaults[:nbins]           = 30               # number of bins for heatmaps and hists
_seriesDefaults[:smooth]          = false               # regression line?
_seriesDefaults[:group]           = nothing           # groupby vector
# _seriesDefaults[:annotation]      = nothing           # annotation tuple(s)... (x,y,annotation)
_seriesDefaults[:x]               = nothing
_seriesDefaults[:y]               = nothing
_seriesDefaults[:z]               = nothing           # depth for contour, surface, etc
_seriesDefaults[:zcolor]          = nothing           # value for color scale
# _seriesDefaults[:surface]         = nothing
_seriesDefaults[:nlevels]         = 15
_seriesDefaults[:levels]          = nothing
_seriesDefaults[:orientation]     = :vertical


const _plotDefaults = Dict{Symbol, Any}()

# plot globals
_plotDefaults[:title]             = ""
_plotDefaults[:xlabel]            = ""
_plotDefaults[:ylabel]            = ""
_plotDefaults[:yrightlabel]       = ""
_plotDefaults[:legend]            = true
_plotDefaults[:background_color]  = colorant"white"
_plotDefaults[:foreground_color]  = :auto
_plotDefaults[:xlims]             = :auto
_plotDefaults[:ylims]             = :auto
_plotDefaults[:xticks]            = :auto
_plotDefaults[:yticks]            = :auto
_plotDefaults[:xscale]            = :identity
_plotDefaults[:yscale]            = :identity
_plotDefaults[:xflip]             = false
_plotDefaults[:yflip]             = false
_plotDefaults[:size]              = (600,400)
_plotDefaults[:pos]               = (0,0)
_plotDefaults[:windowtitle]       = "Plots.jl"
_plotDefaults[:show]              = false
_plotDefaults[:layout]            = nothing
_plotDefaults[:n]                 = -1
_plotDefaults[:nr]                = -1
_plotDefaults[:nc]                = -1
_plotDefaults[:color_palette]     = :auto
_plotDefaults[:link]              = false
_plotDefaults[:linkx]             = false
_plotDefaults[:linky]             = false
_plotDefaults[:linkfunc]          = nothing
_plotDefaults[:tickfont]          = font(8)
_plotDefaults[:guidefont]         = font(11)
_plotDefaults[:legendfont]        = font(8)
_plotDefaults[:grid]              = true
_plotDefaults[:annotation]      = nothing           # annotation tuple(s)... (x,y,annotation)



# TODO: x/y scales

const _allArgs = sort(collect(union(keys(_seriesDefaults), keys(_plotDefaults))))
supportedArgs(::PlottingPackage) = _allArgs
supportedArgs() = supportedArgs(backend())



# -----------------------------------------------------------------------------

makeplural(s::Symbol) = symbol(string(s,"s"))

autopick(arr::AVec, idx::Integer) = arr[mod1(idx,length(arr))]
autopick(notarr, idx::Integer) = notarr

autopick_ignore_none_auto(arr::AVec, idx::Integer) = autopick(setdiff(arr, [:none, :auto]), idx)
autopick_ignore_none_auto(notarr, idx::Integer) = notarr

function aliasesAndAutopick(d::Dict, sym::Symbol, aliases::Dict, options::AVec, plotIndex::Int)
  if d[sym] == :auto
    d[sym] = autopick_ignore_none_auto(options, plotIndex)
  elseif haskey(aliases, d[sym])
    d[sym] = aliases[d[sym]]
  end
end

function aliases(aliasMap::Dict, val)
  # sort(vcat(val, collect(keys(filter((k,v)-> v==val, aliasMap)))))
  sortedkeys(filter((k,v)-> v==val, aliasMap))
end

# -----------------------------------------------------------------------------

# Alternate args

@compat const _keyAliases = Dict(
    :c                  => :linecolor,
    :color              => :linecolor,
    :colour             => :linecolor,
    :lab                => :label,
    :l                  => :line,
    :w                  => :linewidth,
    :width              => :linewidth,
    :lw                 => :linewidth,
    :la                 => :linealpha,
    :lineopacity        => :linealpha,
    :type               => :linetype,
    :lt                 => :linetype,
    :t                  => :linetype,
    :style              => :linestyle,
    :s                  => :linestyle,
    :ls                 => :linestyle,
    :m                  => :marker,
    :mark               => :marker,
    :shape              => :markershape,
    :mc                 => :markercolor,
    :mcolor             => :markercolor,
    :markercolour       => :markercolor,
    :ms                 => :markersize,
    :msize              => :markersize,
    :ma                 => :markeralpha,
    :alpha              => :markeralpha,
    :opacity            => :markeralpha,
    :markeropacity      => :markeralpha,
    :f                  => :fill,
    :area               => :fill,
    :fillrng            => :fillrange,
    :fc                 => :fillcolor,
    :fcolor             => :fillcolor,
    :fillcolour         => :fillcolor,
    :fa                 => :fillalpha,
    :fillopacity        => :fillalpha,
    :g                  => :group,
    :nb                 => :nbins,
    :nbin               => :nbins,
    :rib                => :ribbon,
    :ann                => :annotation,
    :anns               => :annotation,
    :annotate           => :annotation,
    :annotations        => :annotation,
    :xlab               => :xlabel,
    :ylab               => :ylabel,
    :yrlab              => :yrightlabel,
    :ylabr              => :yrightlabel,
    :y2lab              => :yrightlabel,
    :ylab2              => :yrightlabel,
    :ylabelright        => :yrightlabel,
    :ylabel2            => :yrightlabel,
    :y2label            => :yrightlabel,
    :leg                => :legend,
    :bg                 => :background_color,
    :bgcolor            => :background_color,
    :bg_color           => :background_color,
    :background         => :background_color,
    :background_colour  => :background_color,
    :fg                 => :foreground_color,
    :fgcolor            => :foreground_color,
    :fg_color           => :foreground_color,
    :foreground         => :foreground_color,
    :foreground_colour  => :foreground_color,
    :regression         => :smooth,
    :reg                => :smooth,
    :xlim               => :xlims,
    :xlimit             => :xlims,
    :xlimits            => :xlims,
    :ylim               => :ylims,
    :ylimit             => :ylims,
    :ylimits            => :ylims,
    :xtick              => :xticks,
    :ytick              => :yticks,
    :windowsize         => :size,
    :wsize              => :size,
    :wtitle             => :windowtitle,
    :gui                => :show,
    :display            => :show,
    :palette            => :color_palette,
    :xlink              => :linkx,
    :ylink              => :linky,
  )

# add all pluralized forms to the _keyAliases dict
for arg in keys(_seriesDefaults)
  _keyAliases[makeplural(arg)] = arg
end



# -----------------------------------------------------------------------------

# update the defaults globally

"""
`default(key)` returns the current default value for that key
`default(key, value)` sets the current default value for that key
`default(; kw...)` will set the current default value for each key/value pair
"""

function default(k::Symbol)
  k = get(_keyAliases, k, k)
  if haskey(_seriesDefaults, k)
    return _seriesDefaults[k]
  elseif haskey(_plotDefaults, k)
    return _plotDefaults[k]
  else
    error("Unknown key: ", k)
  end
end

function default(k::Symbol, v)
  k = get(_keyAliases, k, k)
  if haskey(_seriesDefaults, k)
    _seriesDefaults[k] = v
  elseif haskey(_plotDefaults, k)
    _plotDefaults[k] = v
  else
    error("Unknown key: ", k)
  end
end

function default(; kw...)
  for (k,v) in kw
    default(k, v)
  end
end

# -----------------------------------------------------------------------------

wraptuple(x::@compat(Tuple)) = x
wraptuple(x) = (x,)

trueOrAllTrue(f::Function, x::AbstractArray) = all(f, x)
trueOrAllTrue(f::Function, x) = f(x)

function handleColors!(d::Dict, arg, csym::Symbol)
  try
    if arg == :auto
      d[csym] = :auto
    else
      c = colorscheme(arg)
      d[csym] = c
    end
    return true
  end
  false
end

# given one value (:log, or :flip, or (-1,1), etc), set the appropriate arg
# TODO: use trueOrAllTrue for subplots which can pass vectors for these
function processAxisArg(d::Dict, axisletter::@compat(AbstractString), arg)
  T = typeof(arg)
  # if T <: Symbol

  arg = get(_scaleAliases, arg, arg)

  if arg in _allScales
    d[symbol(axisletter * "scale")] = arg

  elseif arg in (:flip, :invert, :inverted)
    d[symbol(axisletter * "flip")] = true

  elseif T <: @compat(AbstractString)
    d[symbol(axisletter * "label")] = arg

  # xlims/ylims
  elseif (T <: Tuple || T <: AVec) && length(arg) == 2
    d[symbol(axisletter * "lims")] = arg

  # xticks/yticks
  elseif T <: AVec
    d[symbol(axisletter * "ticks")] = arg

  elseif arg == nothing
    d[symbol(axisletter * "ticks")] = []

  else
    warn("Skipped $(axisletter)axis arg $arg")

  end
end


function processLineArg(d::Dict, arg)

  # linetype
  if trueOrAllTrue(a -> get(_typeAliases, a, a) in _allTypes, arg)
    d[:linetype] = arg

  # linestyle
  elseif trueOrAllTrue(a -> get(_styleAliases, a, a) in _allStyles, arg)
    d[:linestyle] = arg

  elseif typeof(arg) <: Stroke
    arg.width == nothing || (d[:linewidth] = arg.width)
    arg.color == nothing || (d[:linecolor] = arg.color == :auto ? :auto : colorscheme(arg.color))
    arg.alpha == nothing || (d[:linealpha] = arg.alpha)
    arg.style == nothing || (d[:linestyle] = arg.style)

  elseif typeof(arg) <: Brush
    arg.size  == nothing || (d[:fillrange] = arg.size)
    arg.color == nothing || (d[:fillcolor] = arg.color == :auto ? :auto : colorscheme(arg.color))
    arg.alpha == nothing || (d[:fillalpha] = arg.alpha)

  # linealpha
  elseif trueOrAllTrue(a -> typeof(a) <: Real && a > 0 && a < 1, arg)
    d[:linealpha] = arg

  # linewidth
  elseif trueOrAllTrue(a -> typeof(a) <: Real, arg)
    d[:linewidth] = arg

  # color
  elseif !handleColors!(d, arg, :linecolor)
    warn("Skipped line arg $arg.")

  end
end


function processMarkerArg(d::Dict, arg)

  # markershape
  if trueOrAllTrue(a -> get(_markerAliases, a, a) in _allMarkers, arg)
    d[:markershape] = arg
  elseif trueOrAllTrue(a -> isa(a, Shape), arg)
    d[:markershape] = arg

  # stroke style
  elseif trueOrAllTrue(a -> get(_styleAliases, a, a) in _allStyles, arg)
    d[:markerstrokestyle] = arg

  elseif typeof(arg) <: Stroke
    arg.width == nothing || (d[:markerstrokewidth] = arg.width)
    arg.color == nothing || (d[:markerstrokecolor] = arg.color == :auto ? :auto : colorscheme(arg.color))
    arg.alpha == nothing || (d[:markerstrokealpha] = arg.alpha)
    arg.style == nothing || (d[:markerstrokestyle] = arg.style)

  elseif typeof(arg) <: Brush
    arg.size  == nothing || (d[:markersize]  = arg.size)
    arg.color == nothing || (d[:markercolor] = arg.color == :auto ? :auto : colorscheme(arg.color))
    arg.alpha == nothing || (d[:markeralpha] = arg.alpha)

  # linealpha
  elseif trueOrAllTrue(a -> typeof(a) <: Real && a > 0 && a < 1, arg)
    d[:markeralpha] = arg

  # markersize
  elseif trueOrAllTrue(a -> typeof(a) <: Real, arg)
    d[:markersize] = arg

  # markercolor
  elseif !handleColors!(d, arg, :markercolor)
    warn("Skipped marker arg $arg.")

  end
end


function processFillArg(d::Dict, arg)

  if typeof(arg) <: Brush
    arg.size  == nothing || (d[:fillrange] = arg.size)
    arg.color == nothing || (d[:fillcolor] = arg.color == :auto ? :auto : colorscheme(arg.color))
    arg.alpha == nothing || (d[:fillalpha] = arg.alpha)

  elseif !handleColors!(d, arg, :fillcolor)
    d[:fillrange] = arg
  end
end

"Handle all preprocessing of args... break out colors/sizes/etc and replace aliases."
function preprocessArgs!(d::Dict)
  replaceAliases!(d, _keyAliases)

  # handle axis args
  for axisletter in ("x", "y")
    asym = symbol(axisletter * "axis")
    for arg in wraptuple(get(d, asym, ()))
      processAxisArg(d, axisletter, arg)
    end
    delete!(d, asym)
  end

  # handle line args
  for arg in wraptuple(get(d, :line, ()))
    processLineArg(d, arg)
  end
  delete!(d, :line)

  # handle marker args... default to ellipse if shape not set
  anymarker = false
  for arg in wraptuple(get(d, :marker, ()))
    processMarkerArg(d, arg)
    anymarker = true
  end
  delete!(d, :marker)
  if anymarker && !haskey(d, :markershape)
    d[:markershape] = :ellipse
  end

  # handle fill
  for arg in wraptuple(get(d, :fill, ()))
    processFillArg(d, arg)
  end
  delete!(d, :fill)

  # convert into strokes and brushes

  # handle subplot links
  if haskey(d, :link)
    l = d[:link]
    if isa(l, Bool)
      d[:linkx] = l
      d[:linky] = l
    elseif isa(l, Function)
      d[:linkx] = true
      d[:linky] = true
      d[:linkfunc] = l
    else
      warn("Unhandled/invalid link $l.  Should be a Bool or a function mapping (row,column) -> (linkx, linky), where linkx/y can be Bool or Void (nothing)")
    end
    delete!(d, :link)
  end

  return
end

# -----------------------------------------------------------------------------

"A special type that will break up incoming data into groups, and allow for easier creation of grouped plots"
type GroupBy
  groupLabels::Vector{UTF8String}   # length == numGroups
  groupIds::Vector{Vector{Int}}     # list of indices for each group
end


# this is when given a vector-type of values to group by
function extractGroupArgs(v::AVec, args...)
  groupLabels = sort(collect(unique(v)))
  n = length(groupLabels)
  if n > 20
    error("Too many group labels. n=$n  Is that intended?")
  end
  groupIds = Vector{Int}[filter(i -> v[i] == glab, 1:length(v)) for glab in groupLabels]
  GroupBy(map(string, groupLabels), groupIds)
end


# expecting a mapping of "group label" to "group indices"
function extractGroupArgs{T, V<:AVec{Int}}(idxmap::Dict{T,V}, args...)
  groupLabels = sortedkeys(idxmap)
  groupIds = VecI[collect(idxmap[k]) for k in groupLabels]
  GroupBy(groupLabels, groupIds)
end


# -----------------------------------------------------------------------------

function warnOnUnsupportedArgs(pkg::PlottingPackage, d::Dict)
  for k in sortedkeys(d)
    if (!(k in supportedArgs(pkg))
        && k != :subplot
        && d[k] != default(k))
      warn("Keyword argument $k not supported with $pkg.  Choose from: $(supportedArgs(pkg))")
    end
  end
end


function warnOnUnsupported(pkg::PlottingPackage, d::Dict)
  (d[:axis] in supportedAxes(pkg)
    || warn("axis $(d[:axis]) is unsupported with $pkg.  Choose from: $(supportedAxes(pkg))"))
  (d[:linetype] == :none
    || d[:linetype] in supportedTypes(pkg)
    || warn("linetype $(d[:linetype]) is unsupported with $pkg.  Choose from: $(supportedTypes(pkg))"))
  (d[:linestyle] in supportedStyles(pkg)
    || warn("linestyle $(d[:linestyle]) is unsupported with $pkg.  Choose from: $(supportedStyles(pkg))"))
  (d[:markershape] == :none
    || d[:markershape] in supportedMarkers(pkg)
    || (Shape in supportedMarkers(pkg) && typeof(d[:markershape]) <: Shape)
    || warn("markershape $(d[:markershape]) is unsupported with $pkg.  Choose from: $(supportedMarkers(pkg))"))
end

function warnOnUnsupportedScales(pkg::PlottingPackage, d::Dict)
  for k in (:xscale, :yscale)
    if haskey(d, k)
      d[k] in supportedScales(pkg) || warn("scale $(d[k]) is unsupported with $pkg.  Choose from: $(supportedScales(pkg))")
    end
  end
end


# -----------------------------------------------------------------------------

# 1-row matrices will give an element
# multi-row matrices will give a column
# anything else is returned as-is
# getArgValue(v::Tuple, idx::Int) = v[mod1(idx, length(v))]
function getArgValue(v::AMat, idx::Int)
  c = mod1(idx, size(v,2))
  size(v,1) == 1 ? v[1,c] : v[:,c]
end
getArgValue(v, idx) = v


# given an argument key (k), we want to extract the argument value for this index.
# if nothing is set (or container is empty), return the default.
function setDictValue(d_in::Dict, d_out::Dict, k::Symbol, idx::Int, defaults::Dict)
  if haskey(d_in, k) && !(typeof(d_in[k]) <: @compat(Union{AbstractArray, Tuple}) && isempty(d_in[k]))
    d_out[k] = getArgValue(d_in[k], idx)
  else
    d_out[k] = defaults[k]
  end
end

# -----------------------------------------------------------------------------

# build the argument dictionary for the plot
function getPlotArgs(pkg::PlottingPackage, kw, idx::Int; set_defaults = true)
  kwdict = Dict(kw)
  d = Dict()

  # add defaults?
  if set_defaults
    for k in keys(_plotDefaults)
      setDictValue(kwdict, d, k, idx, _plotDefaults)
    end
  end

  for k in (:xscale, :yscale)
    if haskey(_scaleAliases, d[k])
      d[k] = _scaleAliases[d[k]]
    end
  end

  # convert color
  handlePlotColors(pkg, d)

  # no need for these
  delete!(d, :x)
  delete!(d, :y)

  d
end



# build the argument dictionary for a series
function getSeriesArgs(pkg::PlottingPackage, plotargs::Dict, kw, commandIndex::Int, plotIndex::Int, globalIndex::Int)  # TODO, pass in plotargs, not plt
  kwdict = Dict(kw)
  d = Dict()

  # add defaults?
  for k in keys(_seriesDefaults)
    setDictValue(kwdict, d, k, commandIndex, _seriesDefaults)
  end

  # groupby args?
  for k in (:idxfilter, :numUncounted, :dataframe)
    if haskey(kwdict, k)
      d[k] = kwdict[k]
    end
  end

  if haskey(_typeAliases, d[:linetype])
    d[:linetype] = _typeAliases[d[:linetype]]
  end

  aliasesAndAutopick(d, :axis, _axesAliases, supportedAxes(pkg), plotIndex)
  aliasesAndAutopick(d, :linestyle, _styleAliases, supportedStyles(pkg), plotIndex)
  aliasesAndAutopick(d, :markershape, _markerAliases, supportedMarkers(pkg), plotIndex)

  # update color
  d[:linecolor] = getSeriesRGBColor(d[:linecolor], plotargs, plotIndex)

  # update markercolor
  c = d[:markercolor]
  c = (c == :match ? d[:linecolor] : getSeriesRGBColor(c, plotargs, plotIndex))
  d[:markercolor] = c

  # update markerstrokecolor
  c = d[:markerstrokecolor]
  c = (c == :match ? plotargs[:foreground_color] : getSeriesRGBColor(c, plotargs, plotIndex))
  d[:markerstrokecolor] = c

  # update fillcolor
  c = d[:fillcolor]
  c = (c == :match ? d[:linecolor] : getSeriesRGBColor(c, plotargs, plotIndex))
  d[:fillcolor] = c

  # TODO: rebuild

  # set label
  label = d[:label]
  label = (label == "AUTO" ? "y$globalIndex" : label)
  if d[:axis] == :right && !(length(label) >= 4 && label[end-3:end] != " (R)")
    label = string(label, " (R)")
  end
  d[:label] = label

  warnOnUnsupported(pkg, d)


  d
end


