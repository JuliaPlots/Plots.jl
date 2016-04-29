# Plots

[![Build Status](https://travis-ci.org/tbreloff/Plots.jl.svg?branch=master)](https://travis-ci.org/tbreloff/Plots.jl)
[![Join the chat at https://gitter.im/tbreloff/Plots.jl](https://badges.gitter.im/tbreloff/Plots.jl.svg)](https://gitter.im/tbreloff/Plots.jl?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
<!-- [![Plots](http://pkg.julialang.org/badges/Plots_0.3.svg)](http://pkg.julialang.org/?pkg=Plots&ver=0.3) -->
<!-- [![Plots](http://pkg.julialang.org/badges/Plots_0.4.svg)](http://pkg.julialang.org/?pkg=Plots&ver=0.4) -->
<!-- [![Coverage Status](https://coveralls.io/repos/tbreloff/Plots.jl/badge.svg?branch=master)](https://coveralls.io/r/tbreloff/Plots.jl?branch=master) -->
<!-- [![codecov.io](http://codecov.io/github/tbreloff/Plots.jl/coverage.svg?branch=master)](http://codecov.io/github/tbreloff/Plots.jl?branch=master) -->

#### Author: Thomas Breloff (@tbreloff)

Plots is a plotting API and toolset.  My goals with the package are:

- **Powerful**.  Do more with less.  Complex visualizations become easy.
- **Intuitive**.  Start generating plots without reading volumes of documentation.  Commands should "just work".
- **Concise**.  Less code means fewer mistakes and more efficient development/analysis.
- **Flexible**.  Produce your favorite plots from your favorite package, but quicker and simpler.
- **Consistent**.  Don't commit to one graphics package.  Use the same code and access the strengths of all backends.
- **Lightweight**.  Very few dependencies, since backends are loaded and initialized dynamically.

Use the preprocessing pipeline in Plots to fully describe your visualization before it calls the backend code.  This maintains modularity and allows for efficient separation of front end code, algorithms, and backend graphics.  New graphical backends can be added with minimal effort.

```julia
using Plots
pyplot(reuse=true)

@gif for i in linspace(0,2π,100)
    X = Y = linspace(-5,5,40)
    surface(X, Y, (x,y) -> sin(x+10sin(i))+cos(y))
end
```

![waves](http://plots.readthedocs.io/en/latest/examples/img/waves.gif)

View the [full documentation](http://plots.readthedocs.org).
