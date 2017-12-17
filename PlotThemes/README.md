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
![theme_default](https://user-images.githubusercontent.com/16589944/34081411-90c3699c-e34c-11e7-9c64-ea7aae0f066d.png)

### `:dark`
![theme_dark](https://user-images.githubusercontent.com/16589944/34081412-928bd96c-e34c-11e7-95be-744a9f1eb19a.png)

### `:ggplot2`
![theme_ggplot2](https://user-images.githubusercontent.com/16589944/34081416-943c5ca0-e34c-11e7-8b45-74f61d958c47.png)

### `:juno`
![theme_juno](https://user-images.githubusercontent.com/16589944/34081419-9632675c-e34c-11e7-8673-d959eb242059.png)

### `:lime`
![theme_lime](https://user-images.githubusercontent.com/16589944/34081420-97ff3c4a-e34c-11e7-96fc-4ce5d569180c.png)

### `:orange`
![theme_orange](https://user-images.githubusercontent.com/16589944/34081422-9a4d009a-e34c-11e7-816a-ccb796d61e4b.png)

### `:sand`
![theme_sand](https://user-images.githubusercontent.com/16589944/34081423-9c79b660-e34c-11e7-8861-efc2d13efd30.png)

### `:solarized`
![theme_solarized](https://user-images.githubusercontent.com/16589944/34081424-9de1d9b0-e34c-11e7-9aa2-efa112e77e2d.png)

### `:solarized_light`
![theme_solarized_light](https://user-images.githubusercontent.com/16589944/34081426-9f4371e2-e34c-11e7-8f9c-838232d51843.png)

### `:wong`
![theme_wong](https://user-images.githubusercontent.com/16589944/34081427-a12508d6-e34c-11e7-8767-b66fa276b298.png)

### `:wong2`
![theme_wong2](https://user-images.githubusercontent.com/16589944/34081428-a340fa3a-e34c-11e7-83a4-d671ba25a441.png)

## Contributing
A theme specifies default values for different Plots [attributes](http://docs.juliaplots.org/attributes/).
At the moment these are typically colors, palettes and gradients, but any Plots attribute can be controlled by a theme in general.
PRs for new themes very welcome! Adding a new theme (e.g. `mytheme`) is as easy as adding a new file (mytheme.jl) that contains at least the following line:
```julia
_themes[:mytheme] = PlotTheme(; kwargs...)
```
The keyword arguments can be any collection of Plots attributes.
