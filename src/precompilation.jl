if get(ENV, "PLOTS_PRECOMPILE", "true") == "true"
    pl = plot(Plots.fakedata(50, 5), w = 3)
    fn = tempname()
    savefig(pl, "$fn.png")
end