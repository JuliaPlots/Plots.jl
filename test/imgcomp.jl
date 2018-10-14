
using VisualRegressionTests
# using ExamplePlots

if isinteractive()
    @eval Main import Gtk
end

# import DataFrames, RDatasets

# don't let pyplot use a gui... it'll crash
# note: Agg will set gui -> :none in PyPlot
# ENV["MPLBACKEND"] = "Agg"
# try
#   @eval import PyPlot
#   @info("Matplotlib version: $(PyPlot.matplotlib[:__version__])")
# end


using Plots
# using StatPlots
import PlotReferenceImages
using Random
using Test

default(size=(500,300))


# TODO: use julia's Condition type and the wait() and notify() functions to initialize a Window, then wait() on a condition that
#       is referenced in a button press callback (the button clicked callback will call notify() on that condition)

import Plots._current_plots_version


function image_comparison_tests(pkg::Symbol, idx::Int; debug = false, popup = isinteractive(), sigma = [1,1], tol = 1e-2)
    Plots._debugMode.on = debug
    example = Plots._examples[idx]
    @info("Testing plot: $pkg:$idx:$(example.header)")
    backend(pkg)
    backend()

    # ensure consistent results
    Random.seed!(1234)

    # reference image directory setup
    # refdir = joinpath(Pkg.dir("ExamplePlots"), "test", "refimg", string(pkg))
    refdir = joinpath(dirname(pathof(PlotReferenceImages)), "..", "Plots", string(pkg))
    fn = "ref$idx.png"

    # firgure out version info
    vns = filter(x->x[1] != '.', readdir(refdir))
    versions = sort(VersionNumber.(vns), rev = true)
    versions = filter(v -> v <= _current_plots_version, versions)
    # @show refdir fn versions

    newdir = joinpath(refdir, string(_current_plots_version))
    newfn = joinpath(newdir, fn)

    # figure out which reference file we should compare to, by finding the highest versioned file
    reffn = nothing
    for v in versions
        tmpfn = joinpath(refdir, string(v), fn)
        if isfile(tmpfn)
            reffn = tmpfn
            break
        end
    end

    # now we have the fn (if any)... do the comparison
    # @show reffn
    if reffn == nothing
        reffn = newfn
    end
    # @show reffn
    # return

    # test function
    func = (fn, idx) -> begin
        map(eval, example.exprs)
        png(fn)
    end

    # try
    #     run(`mkdir -p $newdir`)
    # catch err
    #     display(err)
    # end
    # # reffn = joinpath(refdir, "ref$idx.png")

    # the test
    vtest = VisualTest(func, reffn, idx)
    test_images(vtest, popup=popup, sigma=sigma, tol=tol, newfn = newfn)
end

function image_comparison_facts(pkg::Symbol;
                                skip = [],      # skip these examples (int index)
                                only = nothing, # limit to these examples (int index)
                                debug = false,  # print debug information?
                                sigma = [1,1],  # number of pixels to "blur"
                                tol = 1e-2)     # acceptable error (percent)
  for i in 1:length(Plots._examples)
    i in skip && continue
    if only == nothing || i in only
      @test image_comparison_tests(pkg, i, debug=debug, sigma=sigma, tol=tol) |> success == true
    end
  end
end
