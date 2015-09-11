
abstract SubPlotLayout

type AutoGridLayout
  maxplts::Int
  maxrows::Int
  maxcols::Int
end

# create a grid structure that optimally fits in numplts, optionally fixing the numrows/numcols
function AutoGridLayout(numplts::Int; numrows::Int = -1, numcols::Int = -1)
end


# ------------------------------------------------------------

doc"""
y = rand(100,3)
subplot(y; layout=(2,2), kw...)           # creates 3 lines going into 3 separate plots, laid out on a 2x2 grid (last row is filled with plot #3)
subplot(y; layout=(1,3), kw...)           # again 3 plots, all in the same row
subplot(y; layout=[1,[2,3]])              # pass a nested Array to fully specify the layout.  here the first plot will take up the first row, 
                                          # and the others will share the second row
"""
type SubPlot <: PlottingObject
  plts::Vector{Plot}  # the underlying object
  plotter::PlottingPackage
  p::Int # number of plots
  n::Int # number of series
  layout::SubPlotLayout
end

Base.string(subplt::SubPlot) = "SubPlot{$(subplt.plotter) p=$(subplt.p) n=$(subplt.n)}"
Base.print(io::IO, subplt::SubPlot) = print(io, string(subplt))
Base.show(io::IO, subplt::SubPlot) = print(io, string(subplt))

getplot(subplt::SubPlot, i::Int) = subplt.plts[mod1(i, subplt.p)]

# ------------------------------------------------------------


function subplot(args...; kw...)
  subplt = SubPlot(Plot[], plotter(), 0, 0)

  d = Dict(kw)

  # figure out the layouts
  if !haskey(d, :layout) || d[:layout] == :auto
    # do an automatic grid layout

  else
    layout = d[:layout]
  end
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

