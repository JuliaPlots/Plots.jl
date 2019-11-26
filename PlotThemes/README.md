# PlotThemes

[![Build Status](https://travis-ci.org/JuliaPlots/PlotThemes.jl.svg?branch=master)](https://travis-ci.org/JuliaPlots/PlotThemes.jl)

#### Primary author: Patrick Kofod Mogensen (@pkofod)

PlotThemes is a package to spice up the plots made with [Plots.jl](https://github.com/tbreloff/Plots.jl). To install:

```julia
Pkg.add("PlotThemes")
```

## Using PlotThemes

Currently the following themes are available:
- `:default`
- `:dark`
- `:ggplot2`
- `:juno`
- `:lime`
- `:orange`
- `:sand`
- `:solarized`
- `:solarized_light`
- `:wong`
- `:wong2`

When using Plots, a theme can be set using the `theme` function:
```julia
using Plots
theme(thm::Symbol; kwargs...)
```
`theme` accepts any Plots [attribute](http://docs.juliaplots.org/attributes/) as keyword argument and sets its value as default for subsequent plots.

Themes can be previewed using `Plots.showtheme(thm::Symbol)`:

### `:default`
![theme_default](https://user-images.githubusercontent.com/16589944/34177593-6a39d112-e504-11e7-9cff-5b18c8caf887.png)

### `:dark`
![theme_dark](https://user-images.githubusercontent.com/16589944/34177596-6d25b79c-e504-11e7-816f-9a1adbda41c2.png)

### `:ggplot2`
![theme_ggplot2](https://user-images.githubusercontent.com/16589944/34177605-7160e6a6-e504-11e7-9c46-8dbc65b7daf3.png)

### `:juno`
![theme_juno](https://user-images.githubusercontent.com/16589944/34177629-7d60212e-e504-11e7-832a-abadd22138ce.png)

### `:lime`
![theme_lime](https://user-images.githubusercontent.com/16589944/34177613-7586877c-e504-11e7-948a-32f0f96d947e.png)

### `:orange`
![theme_orange](https://user-images.githubusercontent.com/16589944/34177643-88c543c8-e504-11e7-8622-abd166f73e68.png)

### `:sand`
![theme_sand](https://user-images.githubusercontent.com/16589944/34177640-86233cec-e504-11e7-9046-841a40877d7b.png)

### `:solarized`
![theme_solarized](https://user-images.githubusercontent.com/16589944/34177636-83a6664c-e504-11e7-89f4-2fb350fdec15.png)

### `:solarized_light`
![theme_solarized_light](https://user-images.githubusercontent.com/16589944/34177634-803e867e-e504-11e7-8a09-50ec09b3112d.png)

### `:wong`
![theme_wong](https://user-images.githubusercontent.com/16589944/34177654-90f2c4da-e504-11e7-8c4e-1f02b9fa7a21.png)

### `:wong2`
![theme_wong2](https://user-images.githubusercontent.com/16589944/34177647-8bd7d116-e504-11e7-81a4-6ef7ccb0a7ed.png)

## Contributing
A theme specifies default values for different Plots [attributes](http://docs.juliaplots.org/attributes/).
At the moment these are typically colors, palettes and colorgradients, but any Plots attribute can be controlled by a theme in general.
PRs for new themes very welcome! Adding a new theme (e.g. `mytheme`) is as easy as adding a new file (mytheme.jl) that contains at least the following line:
```julia
_themes[:mytheme] = PlotTheme(; kwargs...)
```
The keyword arguments can be any collection of Plots attributes plus a colorgradient keyword argument.
