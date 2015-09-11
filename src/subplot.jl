
type SubPlotLayout
  numplts::Int
  rowcounts::AbstractVector{Int}
end

# create a layout directly
SubPlotLayout(rowcounts::AbstractVector{Int}) = SubPlotLayout(sum(rowcounts), rowcounts)

# create a layout given counts... numrows/numcols == -1 implies we figure out a good number automatically
function SubPlotLayout(numplts::Int, numrows::Int, numcols::Int)

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

  SubPlotLayout(numplts, rowcounts)
end


Base.length(layout::SubPlotLayout) = layout.numplts


# ------------------------------------------------------------

type SubPlot <: PlottingObject
  o                           # the underlying object
  plts::Vector{Plot}          # the individual plots
  plotter::PlottingPackage
  p::Int                      # number of plots
  n::Int                      # number of series
  layout::SubPlotLayout
end

Base.string(subplt::SubPlot) = "SubPlot{$(subplt.plotter) p=$(subplt.p) n=$(subplt.n)}"
Base.print(io::IO, subplt::SubPlot) = print(io, string(subplt))
Base.show(io::IO, subplt::SubPlot) = print(io, string(subplt))

getplot(subplt::SubPlot, i::Int) = subplt.plts[mod1(i, subplt.p)]

# ------------------------------------------------------------


doc"""
y = rand(100,3)
subplot(y; n = 3)                # create an automatic grid, and let it figure out the numrows/numcols... will put plots 1 and 2 on the first row, and plot 3 by itself on the 2nd row
subplot(y; n = 3, numrows = 1)   # create an automatic grid, but fix the number of rows to 1 (so there are n columns)
subplot(y; n = 3, numcols = 1)   # create an automatic grid, but fix the number of columns to 1 (so there are n rows)
subplot(y; layout = [1, 2])      # explicit layout by row... plot #1 goes by itself in the first row, plots 2 and 3 split the 2nd row (note the n kw is unnecessary)
"""
function subplot(args...; kw...)
  d = Dict(kw)

  # figure out the layout
  if !haskey(d, :layout)
    layout = FixedLayout(d[:layout])
  else
    if !haskey(d, :n)
      error("You must specify either layout or n when creating a subplot: ", d)
    end
    layout = AutoGridLayout(d[:n], get(d, :numrows, -1), get(d, :numcols, -1))
  end

  # initialize the individual plots
  pkg = plotter()
  kw0 = getPlotKeywordArgs(kw, 1, 0)
  plts = Plot[plot(pkg; kw0..., show=false) for i in 1:length(layout)]

  # create the underlying object (each backend will do this differently)
  o = buildSubplotObject(plts, pkg, layout)

  # create the object and do the plotting
  subplt = SubPlot(o, plts, pkg, length(layout), 0, layout)
  subplot!(subplt, args...; kw...)
end



# # this creates a new plot with args/kw and sets it to be the current plot
# function plot(args...; kw...)
#   plt = plot(plotter(); getPlotKeywordArgs(kw, 1, 0)...)  # create a new, blank plot
#   plot!(plt, args...; kw...)  # add to it
# end

# # this adds to the current plot
# function  plot!(args...; kw...)
#   plot!(currentPlot(), args...; kw...)
# end

# # this adds to a specific plot... most plot commands will flow through here
# function plot!(plt::Plot, args...; kw...)

#   # increment n if we're going directly to the package's plot method
#   if length(args) == 0
#     plt.n += 1
#   end

#   plot!(plt.plotter, plt, args...; kw...)
#   currentPlot!(plt)

#   # do we want to show it?
#   d = Dict(kw)
#   if haskey(d, :show) && d[:show]
#     display(plt)
#   end

#   plt
# end

# # show/update the plot
# function Base.display(plt::Plot)
#   display(plt.plotter, plt)
# end


# # most calls should flow through here now... we create a Dict with the keyword args for each series, and plot them
# function plot!(pkg::PlottingPackage, plt::Plot, args...; kw...)
#   kwList = createKWargsList(plt, args...; kw...)
#   for (i,d) in enumerate(kwList)
#     plt.n += 1
#     plot!(pkg, plt; d...)
#   end
#   plt
# end

