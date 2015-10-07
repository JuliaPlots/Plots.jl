

# create a layout directly
SubplotLayout(rowcounts::AbstractVector{Int}) = SubplotLayout(sum(rowcounts), rowcounts)

# create a layout given counts... nr/nc == -1 implies we figure out a good number automatically
function SubplotLayout(numplts::Int, nr::Int, nc::Int)

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

  # create the rowcounts vector
  i = 0
  rowcounts = Int[]
  for r in 1:nr
    cnt = min(nc, numplts - i)
    push!(rowcounts, cnt)
    i += cnt
  end

  SubplotLayout(numplts, rowcounts)
end


Base.length(layout::SubplotLayout) = layout.numplts


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

doc"""
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
  # if haskey(d, :layout)
  if layoutarg != nothing
    layout = SubplotLayout(layoutarg)
  else
    if !haskey(d, :n) || d[:n] < 0
      error("You must specify either layout or n when creating a subplot: ", d)
    end
    layout = SubplotLayout(d[:n], get(d, :nr, -1), get(d, :nc, -1))
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
  subplt = Subplot(nothing, plts, pkg, length(layout), 0, layout, ds, false)
  subplot!(subplt, args...; kw...)

  subplt
end

doc"""
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
  for k in keys(_plotDefaults)
    delete!(d, k)
  end

  kwList, xmeta, ymeta = createKWargsList(subplt, args...; d...)

  # TODO: something useful with meta info?

  for (i,di) in enumerate(kwList)
    subplt.n += 1
    plt = getplot(subplt)  # get the Plot object where this series will be drawn
    di[:show] = false
    plot!(plt; di...)
  end

  # create the underlying object (each backend will do this differently)
  if !subplt.initialized
    buildSubplotObject!(subplt)
    subplt.initialized = true
  end

  # set this to be current
  current(subplt)

  # show it automatically?
  if haskey(d, :show) && d[:show]
    gui()
  end

  subplt
end


