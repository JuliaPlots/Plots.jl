
using VisualRegressionTests
using ExamplePlots

# don't let pyplot use a gui... it'll crash
# note: Agg will set gui -> :none in PyPlot
ENV["MPLBACKEND"] = "Agg"
try
  @eval import PyPlot
  info("Matplotlib version: $(PyPlot.matplotlib[:__version__])")
end


using Plots, FactCheck

default(size=(500,300))


# TODO: use julia's Condition type and the wait() and notify() functions to initialize a Window, then wait() on a condition that 
#       is referenced in a button press callback (the button clicked callback will call notify() on that condition)

function image_comparison_tests(pkg::Symbol, idx::Int; debug = false, popup = isinteractive(), sigma = [1,1], eps = 1e-2)
  
  # first 
  Plots._debugMode.on = debug
  example = ExamplePlots._examples[idx]
  info("Testing plot: $pkg:$idx:$(example.header)")
  backend(pkg)
  backend()

  # ensure consistent results
  srand(1234)

  # reference image directory setup
  refdir = joinpath(Pkg.dir("ExamplePlots"), "test", "refimg", string(pkg))

  # test function
  func = (fn, idx) -> begin
    map(eval, example.exprs)
    png(fn)
  end

  try
    run(`mkdir -p $refdir`)
  catch err
    display(err)
  end
  reffn = joinpath(refdir, "ref$idx.png")

  # the test
  vtest = VisualTest(func, reffn, idx)
  test_images(vtest, popup=popup, sigma=sigma, eps=eps)
end

function image_comparison_facts(pkg::Symbol;
                                skip = [],      # skip these examples (int index)
                                only = nothing, # limit to these examples (int index)
                                debug = false,  # print debug information?
                                sigma = [1,1],  # number of pixels to "blur"
                                eps = 1e-2)     # acceptable error (percent)
  for i in 1:length(ExamplePlots._examples)
    i in skip && continue
    if only == nothing || i in only
      @fact image_comparison_tests(pkg, i, debug=debug, sigma=sigma, eps=eps) |> success --> true
    end
  end
end
