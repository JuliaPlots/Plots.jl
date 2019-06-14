import Plots._current_plots_version

function image_comparison_tests(pkg::Symbol, idx::Int; debug = false, popup = !is_ci(), sigma = [1,1], tol = 1e-2)
    Plots._debugMode.on = debug
    example = Plots._examples[idx]
    Plots.theme(:default)
    @info("Testing plot: $pkg:$idx:$(example.header)")
    backend(pkg)
    backend()
    default(size=(500,300))
    # ensure consistent results
    Random.seed!(1234)

    fn = "ref$idx.png"
    reffn = reference_file(pkg, idx, _current_plots_version)
    newfn = joinpath(reference_path(pkg, _current_plots_version), fn)
>>>>>>> use PlotReferenceImages Julia Package for tests

    # test function
    func = (fn, idx) -> begin
        expr = Expr(:block)
        append!(expr.args, example.exprs)
        eval(expr)
        png(fn)
    end

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
    if only === nothing || i in only
      @test image_comparison_tests(pkg, i, debug=debug, sigma=sigma, tol=tol) |> success == true
    end
  end
end
