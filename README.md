# Plot

[![Build Status](https://travis-ci.org/tbreloff/Plot.jl.svg?branch=master)](https://travis-ci.org/tbreloff/Plot.jl)

Plotting interface and wrapper for several plotting packages.

#### This is under development... please add your wishlist for the plotting interface to issue #1.

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


Note that you do not need all underlying packages to use this.  I use Requires.jl to 
perform lazy loading of the modules, so there's no initialization until you call `plotter()`.
This has an added benefit that you can call `using Plot` and it should return quickly... 
no more waiting for a plotting package to load when you don't even use it.  :)

```
julia> tic(); using Plot; toc();
elapsed time: 0.356158445 seconds

julia> tic(); using Gadfly; toc();
WARNING: using Gadfly.Plot in module Main conflicts with an existing identifier.
elapsed time: 3.1334697 seconds
```

# Author

Thomas Breloff (@tbreloff)

