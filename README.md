# Plot

[![Build Status](https://travis-ci.org/tbreloff/Plot.jl.svg?branch=master)](https://travis-ci.org/tbreloff/Plot.jl)

Plotting interface and wrapper for several plotting packages.

First, clone the package, and get any plotting packages you need:

```
Pkg.clone("https://github.com/JuliaPlot/Plot.jl.git")
Pkg.clone("https://github.com/tbreloff/Qwt.jl.git")   # requires pyqt and pyqwt
Pkg.add("Gadfly")  # might also need to Pkg.checkout("Gadfly") and maybe Colors/Compose... I had trouble with it
```

Now load it in:

```
using Plot
```

Do a plot in Qwt, then save a png:

```
plotter(:Qwt)
plot(1:10)
savepng(ans, Plot.IMG_DIR * "qwt1.png")
```

which saves:

![qwt_plt](img/qwt1.png)


Do a plot in Gadfly, then save a png:

```
plotter(:Gadfly)
plot(1:10)
savepng(ans, Plot.IMG_DIR * "gadfly1.png", 6Gadfly.inch, 4Gadfly.inch)
```

which saves:

![gadfly_plt](img/gadfly1.png)



# Author

Thomas Breloff (@tbreloff)

