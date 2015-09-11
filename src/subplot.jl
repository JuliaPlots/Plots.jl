
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
end

Base.string(subplt::SubPlot) = "SubPlot{$(subplt.plotter) p=$(subplt.p) n=$(subplt.n)}"
Base.print(io::IO, subplt::SubPlot) = print(io, string(subplt))
Base.show(io::IO, subplt::SubPlot) = print(io, string(subplt))

getplot(subplt::SubPlot, i::Int) = subplt.plts[mod1(i, subplt.p)]

# ------------------------------------------------------------


function subplot(args...; )
end

