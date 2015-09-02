module PlotsTests

using Plots
using FactCheck


facts("Qwt") do
  @fact plotter!(:qwt) --> nothing
  @fact plotter() --> Plots.QwtPackage()
  @fact typeof(plot(1:10, show=false)) --> Plot
end

facts("Gadfly") do
  @fact plotter!(:gadfly) --> nothing
  @fact plotter() --> Plots.GadflyPackage()
  @fact typeof(plot(1:10, show=false)) --> Plot
end

FactCheck.exitstatus()
end # module
