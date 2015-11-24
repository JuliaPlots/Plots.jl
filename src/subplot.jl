
function subplotlayout(sz::@compat(Tuple{Int,Int}))
  GridLayout(sz...)
end

function subplotlayout(rowcounts::AVec{Int})
  FlexLayout(sum(rowcounts), rowcounts)
end

function subplotlayout(numplts::Int, nr::Int, nc::Int)

  # figure out how many rows/columns we need
  if nr == -1
    if nc == -1
      nr = round(Int, sqrt(numplts))
      nc = ceil(Int, numplts / nr)
    else
      nr = ceil(Int, numplts / nc)
    end
  else
    nc = ceil(Int, numplts / nr)
  end

  # if it's a perfect rectangle, just create a grid
  if numplts == nr * nc
    return GridLayout(nr, nc)
  end

  # create the rowcounts vector
  i = 0
  rowcounts = Int[]
  for r in 1:nr
    cnt = min(nc, numplts - i)
    push!(rowcounts, cnt)
    i += cnt
  end

  FlexLayout(numplts, rowcounts)
end



Base.length(layout::FlexLayout) = layout.numplts
Base.start(layout::FlexLayout) = 1
Base.done(layout::FlexLayout, state) = state > length(layout)
function Base.next(layout::FlexLayout, state)
  r = 1
  c = 0
  for i = 1:state
    c += 1
    if c > layout.rowcounts[r]
      r += 1
      c = 1
    end
  end
  (r,c), state + 1
end

nrows(layout::FlexLayout) = length(layout.rowcounts)
ncols(layout::FlexLayout, row::Int) = row < 1 ? 0 : (row > nrows(layout) ? 0 : layout.rowcounts[row])

# get the plot index given row and column
Base.getindex(layout::FlexLayout, r::Int, c::Int) = sum(layout.rowcounts[1:r-1]) + c

Base.length(layout::GridLayout) = layout.nr * layout.nc
Base.start(layout::GridLayout) = 1
Base.done(layout::GridLayout, state) = state > length(layout)
function Base.next(layout::GridLayout, state)
  r = div(state-1, layout.nc) + 1
  c = mod1(state, layout.nc)
  (r,c), state + 1
end

nrows(layout::GridLayout) = layout.nr
ncols(layout::GridLayout) = layout.nc
ncols(layout::GridLayout, row::Int) = layout.nc

# get the plot index given row and column
Base.getindex(layout::GridLayout, r::Int, c::Int) = (r-1) * layout.nc + c

Base.getindex(subplt::Subplot, args...) = subplt.plts[subplt.layout[args...]]

# handle "linking" the subplot axes together
# each backend should implement the _remove_axis and _expand_limits methods
function link_axis(subplt::Subplot, isx::Bool)

  # collect the list of plots and the expanded limits for those plots that should be linked on this axis
  includedPlots = Any[]
  # lims = [Inf, -Inf]
  lims = Dict{Int,Any}()  # maps column to xlim
  for (i,(r,c)) in enumerate(subplt.layout)

    # shouldlink will be a bool or nothing.  if nothing, then use linkx/y (which is true if we get to this code)
    shouldlink = subplt.linkfunc(r,c)[isx ? 1 : 2]
    if shouldlink == nothing || shouldlink
      plt = subplt.plts[i]

      # if we don't have this
      k = isx ? c : r
      if (firstone = !haskey(lims, k))
        lims[k] = [Inf, -Inf]
      end

      isinner = (isx && r < nrows(subplt.layout)) || (!isx && !firstone)
      push!(includedPlots, (plt, isinner, k))

      _expand_limits(lims[k], plt, isx)
    end

  end

  # do the axis adjustments
  for (plt, isinner, k) in includedPlots
    if isinner
      _remove_axis(plt, isx)
    end
    (isx ? xlims! : ylims!)(plt, lims[k]...)
  end
end



# ------------------------------------------------------------


Base.string(subplt::Subplot) = "Subplot{$(subplt.backend) p=$(subplt.p) n=$(subplt.n)}"
Base.print(io::IO, subplt::Subplot) = print(io, string(subplt))
Base.show(io::IO, subplt::Subplot) = print(io, string(subplt))

getplot(subplt::Subplot, idx::Int = subplt.n) = subplt.plts[mod1(idx, subplt.p)]
getplotargs(subplt::Subplot, idx::Int) = getplot(subplt, idx).plotargs
convertSeriesIndex(subplt::Subplot, n::Int) = ceil(Int, n / subplt.p)

# ------------------------------------------------------------

function validateSubplotSupported()
  if !subplotSupported()
    error(CURRENT_BACKEND.sym, " does not support the subplot/subplot! commands at this time.  Try one of: ", join(filter(pkg->subplotSupported(backendInstance(pkg)), backends()),", "))
  end
end

"""
Create a series of plots:
```
  y = rand(100,3)
  subplot(y; n = 3)             # create an automatic grid, and let it figure out the nr/nc... will put plots 1 and 2 on the first row, and plot 3 by itself on the 2nd row
  subplot(y; n = 3, nr = 1)     # create an automatic grid, but fix the number of rows to 1 (so there are n columns)
  subplot(y; n = 3, nc = 1)     # create an automatic grid, but fix the number of columns to 1 (so there are n rows)
  subplot(y; layout = [1, 2])   # explicit layout by row... plot #1 goes by itself in the first row, plots 2 and 3 split the 2nd row (note the n kw is unnecessary)
  subplot(plts, n; nr = -1, nc = -1)  # build a layout from existing plots
  subplot(plts, layout)               # build a layout from existing plots
```
"""
function subplot(args...; kw...)
  validateSubplotSupported()
  d = Dict(kw)
  preprocessArgs!(d)

  # figure out the layout
  layoutarg = get(d, :layout, nothing)
  if layoutarg != nothing
    layout = subplotlayout(layoutarg)
  else
    n = get(d, :n, -1)
    if n < 0
      error("You must specify either layout or n when creating a subplot: ", d)
    end
    layout = subplotlayout(n, get(d, :nr, -1), get(d, :nc, -1))
  end

  # initialize the individual plots
  pkg = backend()
  plts = Plot{typeof(pkg)}[]
  for i in 1:length(layout)
    di = getPlotArgs(pkg, d, i)
    di[:subplot] = true
    dumpdict(di, "Plot args (subplot $i)")
    push!(plts, _create_plot(pkg; di...))
  end

  # create the object and do the plotting
  subplt = Subplot(nothing, plts, pkg, length(layout), 0, layout, d, false, false, false, (r,c) -> (nothing,nothing))
  subplot!(subplt, args...; kw...)

  subplt
end

# ------------------------------------------------------------------------------------------------

# NOTE: for the subplot calls building from existing plots, we need the first plot to be separate to ensure dispatch calls this instead of the more general subplot(args...; kw...)

# grid layout
function subplot{P}(plt1::Plot{P}, plts::Plot{P}...; kw...)
  d = Dict(kw)
  layout = subplotlayout(length(plts)+1, get(d, :nr, -1), get(d, :nc, -1))
  subplot(vcat(plt1, plts...), layout, d)
end

# explicit layout
function subplot{P,I<:Integer}(pltsPerRow::AVec{I}, plt1::Plot{P}, plts::Plot{P}...; kw...)
  layout = subplotlayout(pltsPerRow)
  subplot(vcat(plt1, plts...), layout, Dict(kw))
end

# this will be called internally
function subplot{P<:PlottingPackage}(plts::AVec{Plot{P}}, layout::SubplotLayout, d::Dict)
  validateSubplotSupported()
  p = length(layout)
  n = sum([plt.n for plt in plts])
  subplt = Subplot(nothing, collect(plts), P(), p, n, layout, Dict(), false, false, false, (r,c) -> (nothing,nothing))

  _preprocess_subplot(subplt, d)
  _postprocess_subplot(subplt, d)

  subplt
end

# TODO: hcat/vcat subplots and plots together arbitrarily

# ------------------------------------------------------------------------------------------------


function _preprocess_subplot(subplt::Subplot, d::Dict, args = ())
  validateSubplotSupported()
  preprocessArgs!(d)

  # for plotting recipes, swap out the args and update the parameter dictionary
  args = _apply_recipe(d, args...; d...)

  dumpdict(d, "After subplot! preprocessing")

  # get the full plotargs, overriding any new settings
  # TODO: subplt.plotargs should probably be merged sooner and actually used
  #       for color selection, etc.  (i.e. if we overwrite the subplot palettes to [:heat :rainbow])
  #       then we need to overwrite plt[1].plotargs[:color_palette] to :heat before it's actually used
  #       for color selection!

  # first merge the new args into the subplot's plotargs. then process the plot args and merge
  # those into the plot's plotargs.  (example... `palette = [:blues :reds]` goes into subplt.plotargs,
  # then the ColorGradient for :blues/:reds is merged into plot 1/2 plotargs, which is then used for color selection)
  for i in 1:length(subplt.layout)
    subplt.plts[i].plotargs = getPlotArgs(backend(), merge(subplt.plts[i].plotargs, d), i)
  end
  merge!(subplt.plotargs, d)

  # process links.  TODO: extract to separate function
  for s in (:linkx, :linky, :linkfunc)
    if haskey(d, s)
      setfield!(subplt, s, d[s])
      delete!(d, s)
    end
  end

  args
end

function _postprocess_subplot(subplt::Subplot, d::Dict)
  # init (after plot creation)
  if !subplt.initialized
    subplt.initialized = _create_subplot(subplt, false)
  end

  # add title, axis labels, ticks, etc
  for (i,plt) in enumerate(subplt.plts)
    di = plt.plotargs
    dumpdict(di, "Updating sp $i")
    _update_plot(plt, di)
  end

  _update_plot_pos_size(subplt, d)

  # handle links
  subplt.linkx && link_axis(subplt, true)
  subplt.linky && link_axis(subplt, false)

  # set this to be current
  current(subplt)
end

# ------------------------------------------------------------------------------------------------

"""
Adds to a subplot.
"""

# current subplot
function subplot!(args...; kw...)
  validateSubplotSupported()
  subplot!(current(), args...; kw...)
end


# not allowed:
function subplot!(plt::Plot, args...; kw...)
  error("Can't call subplot! on a Plot!")
end


# # this adds to a specific subplot... most plot commands will flow through here
function subplot!(subplt::Subplot, args...; kw...)
  # validateSubplotSupported()

  d = Dict(kw)
  args = _preprocess_subplot(subplt, d, args)

  # create the underlying object (each backend will do this differently)
  # note: we call it once before doing the individual plots, and once after
  #       this is because some backends need to set up the subplots and then plot, 
  #       and others need to do it the other way around
  if !subplt.initialized
    subplt.initialized = _create_subplot(subplt, true)
  end

  # handle grouping
  group = get(d, :group, nothing)
  if group == nothing
    groupargs = []
  else
    groupargs = [extractGroupArgs(d[:group], args...)]
    delete!(d, :group)
  end


  kwList, xmeta, ymeta = createKWargsList(subplt, groupargs..., args...; d...)

  # TODO: something useful with meta info?

  for (i,di) in enumerate(kwList)

    subplt.n += 1
    plt = getplot(subplt)
    plt.n += 1

    # cleanup the dictionary that we pass into the plot! command
    di[:show] = false
    di[:subplot] = true
    for k in (:title, :xlabel, :xticks, :xlims, :xscale, :xflip,
                      :ylabel, :yticks, :ylims, :yscale, :yflip)
      delete!(di, k)
    end
    dumpdict(di, "subplot! kwList $i")
    dumpdict(plt.plotargs, "plt.plotargs before plotting")
    
    _add_series_subplot(plt; di...)
  end

  _postprocess_subplot(subplt, d)

  # show it automatically?
  if haskey(d, :show) && d[:show]
    gui()
  end

  subplt
end



function _add_series_subplot(plt::Plot, args...; kw...)
  d = Dict(kw)

  setTicksFromStringVector(d, d, :x, :xticks)
  setTicksFromStringVector(d, d, :y, :yticks)

  _add_series(plt.backend, plt; d...)
  
  _add_annotations(plt, d)
  warnOnUnsupportedScales(plt.backend, d)
end



# --------------------------------------------------------------------

function Base.copy(subplt::Subplot)
  subplot(subplt.plts, subplt.layout, subplt.plotargs)
end
