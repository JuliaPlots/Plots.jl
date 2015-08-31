module PlotsTests

using Plots
using FactCheck


facts("Qwt") do
  @fact plotter(:qwt) --> nothing
end

facts("Gadfly") do
  @fact plotter(:gadfly) --> nothing
end

end # module
