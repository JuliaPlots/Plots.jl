### Install
First, add the package:

```julia
import Pkg
Pkg.add("Plots")  # ≡ `PlotsBase` + `GR` backend

Pkg.add("PlotBase", "PythonPlot")  # `PlotsBase` + `PythonPlot` backend, which avoids installing the `GR` backend

# if you want the latest features:
Pkg.pkg"add Plots#v2"
```

The GR [backend](@ref backends) is included by default, but you can install additional plotting packages if you need a different backend.

Tier 1 support backends (in alphabetical order):
```julia
Pkg.add("GR")
# You do not need to add this package because it is the default backend and
# therefore it is automatically installed with Plots.jl. Note that you might
# need to install additional system packages if you are on Linux, see
# https://gr-framework.org/julia.html#installation

Pkg.add("UnicodePlots")  # simplest terminal based backend (guaranteed to work from a cluster, e.g. without X forwarding)

Pkg.add("PythonPlot")  # depends only on PythonPlot package

Pkg.add("PGFPlotsX")  # you need to have LaTeX installed on your system

Pkg.add("PlotlyJS")
# Note that you only need to add this if you need Electron windows and
# additional output formats, otherwise `plotly()` comes shipped with Plots.jl.
# In order to have a good experience with Jupyter, refer to Plotly-specific
# Jupyter installation (https://github.com/plotly/plotly.py#installation)

Pkg.add("Gaston")  # Gnuplot based backend
```

Learn more about backends [here](https://docs.juliaplots.org/latest/backends/).

Finally, you may wish to add some extensions from the [Plots ecosystem](@ref ecosystem):

```julia
Pkg.add("StatsPlots")
Pkg.add("GraphRecipes")
```

---

### Initialize
```julia
using Plots  # or StatsPlots
# using GraphRecipes  # if you wish to use GraphRecipes package too

# or alternatively
import PythonPlot  # select installed backend (triggered by packages extensions: https://docs.julialang.org/en/v1/manual/code-loading/#man-extensions)
using PlotsBase
pythonplot()  # activate the chosen backend
```

Optionally, [choose a backend](@ref backends) and/or override default settings at the same time:

```julia
gr(size = (300, 300), legend = false)  # provide optional defaults
unicodeplots()                         # plot in terminal
pgfplotsx()
plotly(ticks=:native)                  # plotlyjs for richer saving options
pythonplot()                           # backends are selected with lowercase names
```

!!! tip
    Plots will use the GR backend by default. You can override this choice by setting an environment variable in your `~/.julia/config/startup.jl` file (if the file does not exist, create it). To do this, add e.g. the following line of code: `ENV["PLOTSBASE_DEFAULT_BACKEND"] = "UnicodePlots"`.

!!! tip
    You can override standard default values in your `~/.julia/config/startup.jl` file, for example `PLOTSBASE_DEFAULTS = Dict(:markersize => 10, :legend => false, :warn_on_unsupported => false)`.
---
