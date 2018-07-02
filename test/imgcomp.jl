
using VisualRegressionTests
# using ExamplePlots

import DataFrames, RDatasets

# FIXME: pending update of PlotReferenceImages to a proper package
# import PlotReferenceImages

if !isdefined(@__MODULE__,:backends2test)
    backends2test = Symbol.(lowercase.(
        split(get(ENV,"PLOTS_TEST_BACKENDS","GR:UnicodePlots"),":")))
end

if :pyplot ∈ backends2test
    # don't let pyplot use a gui... it'll crash
    # note: Agg will set gui -> :none in PyPlot
    ENV["MPLBACKEND"] = "Agg"
    try
        @eval import PyPlot
        info("Matplotlib version: $(PyPlot.matplotlib[:__version__])")
    catch
    end
end

using Plots
info("Suppressing StatPlots until dependencies are ready")
# using StatPlots
using Base.Test

default(size=(500,300))


# TODO: use julia's Condition type and the wait() and notify() functions to initialize a Window, then wait() on a condition that
#       is referenced in a button press callback (the button clicked callback will call notify() on that condition)

const _current_plots_version = v"0.17.3"


function image_comparison_tests(pkg::Symbol, idx::Int; debug = false, popup = isinteractive(), sigma = [1,1], eps = 1e-2)
    Plots._debugMode.on = debug
    example = Plots._examples[idx]
    info("Testing plot: $pkg:$idx:$(example.header)")
    backend(pkg)
    backend()

    # ensure consistent results
    srand(1234)

    # reference image directory setup
    # refdir = joinpath(Pkg.dir("ExamplePlots"), "test", "refimg", string(pkg))

    # FIXME: this needs for PlotReferenceImages to be properly instantiated
    # refdir0 = Base.find_package(@__MODULE__,"PlotReferenceImages")
    refdir0 = joinpath(ENV["HOME"],".julia","packages","PlotReferenceImages","Rtul")

    refdir0 == nothing && error("Failed to find PlotReferenceImages")
    refdir = joinpath(refdir0, "Plots", string(pkg))
    isdir(refdir) || error("$pkg not found in PlotReferenceImages")
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
    test_images(vtest, popup=popup, sigma=sigma, eps=eps, newfn = newfn)
end

function image_comparison_facts(pkg::Symbol;
                                skip = [],      # skip these examples (int index)
                                only = nothing, # limit to these examples (int index)
                                debug = false,  # print debug information?
                                sigma = [1,1],  # number of pixels to "blur"
                                eps = 1e-2)     # acceptable error (percent)
  for i in 1:length(Plots._examples)
    i in skip && continue
    if only == nothing || i in only
      @test image_comparison_tests(pkg, i, debug=debug, sigma=sigma, eps=eps) |> success == true
    end
  end
end
