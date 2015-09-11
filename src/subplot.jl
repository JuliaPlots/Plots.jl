

# create a layout directly
SubplotLayout(rowcounts::AbstractVector{Int}) = SubplotLayout(sum(rowcounts), rowcounts)

# create a layout given counts... numrows/numcols == -1 implies we figure out a good number automatically
function SubplotLayout(numplts::Int, numrows::Int, numcols::Int)

  # figure out how many rows/columns we need
  if numrows == -1
    if numcols == -1
      numrows = round(Int, sqrt(numplts))
      numcols = ceil(Int, numplts / numrows)
    else
      numrows = ceil(Int, numplts / numcols)
    end
  else
    numcols = ceil(Int, numplts / numrows)
  end

  # create the rowcounts vector
  i = 0
  rowcounts = Int[]
  for r in 1:numrows
    cnt = min(numcols, numplts - i)
    push!(rowcounts, cnt)
    i += cnt
  end

  SubplotLayout(numplts, rowcounts)
end


Base.length(layout::SubplotLayout) = layout.numplts


# ------------------------------------------------------------


Base.string(subplt::Subplot) = "Subplot{$(subplt.plotter) p=$(subplt.p) n=$(subplt.n)}"
Base.print(io::IO, subplt::Subplot) = print(io, string(subplt))
Base.show(io::IO, subplt::Subplot) = print(io, string(subplt))

getplot(subplt::Subplot) = subplt.plts[mod1(subplt.n, subplt.p)]

# ------------------------------------------------------------


doc"""
Create a series of plots:
  y = rand(100,3)
  subplot(y; n = 3)                # create an automatic grid, and let it figure out the numrows/numcols... will put plots 1 and 2 on the first row, and plot 3 by itself on the 2nd row
  subplot(y; n = 3, numrows = 1)   # create an automatic grid, but fix the number of rows to 1 (so there are n columns)
  subplot(y; n = 3, numcols = 1)   # create an automatic grid, but fix the number of columns to 1 (so there are n rows)
  subplot(y; layout = [1, 2])      # explicit layout by row... plot #1 goes by itself in the first row, plots 2 and 3 split the 2nd row (note the n kw is unnecessary)
"""
function subplot(args...; kw...)
  d = Dict(kw)

  # figure out the layout
  if haskey(d, :layout)
    layout = SubplotLayout(d[:layout])
  else
    if !haskey(d, :n)
      error("You must specify either layout or n when creating a subplot: ", d)
    end
    layout = SubplotLayout(d[:n], get(d, :numrows, -1), get(d, :numcols, -1))
  end

  # initialize the individual plots
  pkg = plotter()
  kw0 = getPlotKeywordArgs(kw, 1, 0)
  plts = Plot[plot(pkg; kw0..., show=false) for i in 1:length(layout)]

  # create the underlying object (each backend will do this differently)
  o = buildSubplotObject(plts, pkg, layout)

  # create the object and do the plotting
  subplt = Subplot(o, plts, pkg, length(layout), 0, layout)
  subplot!(subplt, args...; kw...)
end

doc"""
Adds to a subplot.
"""

# current subplot
function subplot!(args...; kw...)
  subplot!(currentPlot(), args...; kw...)
end


# not allowed:
function subplot!(plt::Plot, args...; kw...)
  error("Can't call subplot! on a Plot!")
end


# # this adds to a specific subplot... most plot commands will flow through here
function subplot!(subplt::Subplot, args...; kw...)
  kwList = createKWargsList(subplt, args...; kw...)
  for (i,d) in enumerate(kwList)
    subplt.n += 1
    plt = getplot(subplt)  # get the Plot object where this series will be drawn
    plot!(plt; d...)
  end

  currentPlot!(subplt)

  # do we want to show it?
  d = Dict(kw)
  if haskey(d, :show) && d[:show]
    display(subplt)
  end

  subplt
end


# # # this creates a new plot with args/kw and sets it to be the current plot
# # function plot(args...; kw...)
# #   plt = plot(plotter(); getPlotKeywordArgs(kw, 1, 0)...)  # create a new, blank plot
# #   plot!(plt, args...; kw...)  # add to it
# # end

# # # this adds to the current plot
# # function  plot!(args...; kw...)
# #   plot!(currentPlot(), args...; kw...)
# # end

# # this adds to a specific plot... most plot commands will flow through here
# function plot!(plt::Plot, args...; kw...)

#   kwList = createKWargsList(plt, args...; kw...)
#   for (i,d) in enumerate(kwList)
#     plt.n += 1
#     plot!(plt.plotter, plt; d...)
#   end

#   currentPlot!(plt)

#   # do we want to show it?
#   d = Dict(kw)
#   if haskey(d, :show) && d[:show]
#     display(plt)
#   end

#   plt
# end


