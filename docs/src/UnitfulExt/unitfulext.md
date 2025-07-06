*for plotting data with units seamlessly in Julia*

`Plots` provides `Unitful` recipes for plotting figures when using data with [Unitful.jl](https://github.com/PainterQubits/Unitful.jl) units.

!!! note
    Since julia `1.9`, the module formerly known as `UnitfulRecipes` has been moved to a weak dependency called `UnitfulExt`.

---

### Documentation

The goal is that if you can plot something with [Plots.jl](https://github.com/JuliaPlots/Plots.jl) then you should be able to plot the same thing with units.

Essentially, `Unitful` recipes strips the units of your data and appends them to the corresponding axis labels.

Pictures speak louder than words, so we wrote some examples (accessible through the links on the left) for you to get an idea of what this package does or to simply try it out for yourself!

!!! note "You can run the examples!"
    These examples are available as Jupyter notebooks (through [nbviewer](https://nbviewer.jupyter.org/) or [binder](https://mybinder.org/))!

---

### Ommissions, bugs, and contributing

Please do not hesitate to raise an [issue](https://github.com/JuliaPlots/Plots.jl/issues) or submit a [PR](https://github.com/JuliaPlots/Plots.jl/pulls) if you would like a new recipe to be added.
