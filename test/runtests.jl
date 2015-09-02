module PlotsTests

using Plots
using FactCheck


facts("Qwt") do
  @fact plotter!(:qwt) --> nothing
  @fact plotter() --> :qwt
  @fact tpye(plot(1:10, show=false)) --> Plot
end

facts("Gadfly") do
  @fact plotter!(:gadfly) --> nothing
  @fact plotter() --> :gadfly
  @fact tpye(plot(1:10, show=false)) --> Plot
end

end # module
