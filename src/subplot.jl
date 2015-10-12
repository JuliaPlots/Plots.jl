
function subplotlayout(sz::@compat(Tuple{Int,Int}))
  # create a GridLayout
  GridLayout(sz...)
end

function subplotlayout(rowcounts::AVec{Int})
  # create a FlexLayout
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

# # create a layout directly
# SubplotLayout(rowcounts::AbstractVector{Int}) = SubplotLayout(sum(rowcounts), rowcounts)

# # create a layout given counts... nr/nc == -1 implies we figure out a good number automatically
# function SubplotLayout(numplts::Int, nr::Int, nc::Int)

#   # figure out how many rows/columns we need
#   if nr == -1
#     if nc == -1
#       nr = round(Int, sqrt(numplts))
#       nc = ceil(Int, numplts / nr)
#     else
#       nr = ceil(Int, numplts / nc)
#     end
#   else
#     nc = ceil(Int, numplts / nr)
#   end

#   # create the rowcounts vector
#   i = 0
#   rowcounts = Int[]
#   for r in 1:nr
#     cnt = min(nc, numplts - i)
#     push!(rowcounts, cnt)
#     i += cnt
#   end

#   SubplotLayout(numplts, rowcounts)
# end


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

# handle "linking" the subplot axes together
# each backend should implement the handleLinkInner and expandLimits! methods
function linkAxis(subplt::Subplot, isx::Bool)

  # collect the list of plots and the expanded limits for those plots that should be linked on this axis
  includedPlots = Any[]
  lims = [Inf, -Inf]
  for (i,(r,c)) in enumerate(subplt.layout)

    # shouldlink will be a bool or nothing.  if nothing, then use linkx/y (which is true if we get to this code)
    shouldlink = subplt.linkfunc(r,c)[isx ? 1 : 2]
    if shouldlink == nothing || shouldlink
      plt = subplt.plts[i]
      isinner = (isx && r < nrows(subplt.layout)) || (!isx && c > 1)
      push!(includedPlots, (plt, isinner))
      expandLimits!(lims, plt, isx)
    end

  end

  # do the axis adjustments
  for (plt, isinner) in includedPlots
    if isinner
      handleLinkInner(plt, isx)
    end
    (isx ? xlims! : ylims!)(plt, lims...)
  end
end



# ------------------------------------------------------------


Base.string(subplt::Subplot) = "Subplot{$(subplt.backend) p=$(subplt.p) n=$(subplt.n)}"
Base.print(io::IO, subplt::Subplot) = print(io, string(subplt))
Base.show(io::IO, subplt::Subplot) = print(io, string(subplt))

getplot(subplt::Subplot, idx::Int = subplt.n) = subplt.plts[mod1(idx, subplt.p)]
getinitargs(subplt::Subplot, idx::Int) = getplot(subplt, idx).initargs
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
  plts = Plot[]
  ds = Dict[]
  for i in 1:length(layout)
    push!(ds, getPlotArgs(pkg, d, i))
    push!(plts, plot(pkg; ds[i]...))
  end

  # tmpd = getPlotKeywordArgs(pkg, kw, 1, 0)   # TODO: this should happen in the plot creation loop... think... what if we want to set a title per subplot??
  # # shouldShow = tmpd[:show]
  # # tmpd[:show] = false
  # plts = Plot[plot(pkg; tmpd...) for i in 1:length(layout)]
  # # tmpd[:show] = shouldShow

  # create the object and do the plotting
  subplt = Subplot(nothing, plts, pkg, length(layout), 0, layout, ds, false, false, false, (r,c) -> (nothing,nothing))
  subplot!(subplt, args...; kw...)

  subplt
end

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
  validateSubplotSupported()
  # if !subplotSupported()
  #   error(CURRENT_BACKEND.sym, " does not support the subplot/subplot! commands at this time.  Try one of: ", join(filter(pkg->subplotSupported(backendInstance(pkg)), backends()),", "))
  # end

  d = Dict(kw)
  preprocessArgs!(d)
  dumpdict(d, "After subplot! preprocessing")

  haskey(d, :linkx) && (subplt.linkx = d[:linkx])
  haskey(d, :linky) && (subplt.linky = d[:linky])
  if get(d, :linkfunc, nothing) != nothing
    subplt.linkfunc = d[:linkfunc]
  end

  kwList, xmeta, ymeta = createKWargsList(subplt, args...; d...)

  # TODO: something useful with meta info?

  for (i,di) in enumerate(kwList)
    subplt.n += 1
    plt = getplot(subplt)  # get the Plot object where this series will be drawn
    di[:show] = false
    dumpdict(di, "subplot! kwList $i")
    plot!(plt; di...)
  end

  # create the underlying object (each backend will do this differently)
  if !subplt.initialized
    buildSubplotObject!(subplt)
    subplt.initialized = true
  end


  # add title, axis labels, ticks, etc
  for (i,plt) in enumerate(subplt.plts)
    di = copy(d)
    for (k,v) in di
      if typeof(v) <: AVec
        di[k] = v[mod1(i, length(v))]
      end
    end
    dumpdict(di, "Updating sp $i")
    updatePlotItems(plt, di)
  end

  subplt.linkx && linkAxis(subplt, true)
  subplt.linky && linkAxis(subplt, false)

  # set this to be current
  current(subplt)

  # show it automatically?
  if haskey(d, :show) && d[:show]
    gui()
  end

  subplt
end


