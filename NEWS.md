
# Plots.jl NEWS

#### notes on release changes, ongoing development, and future planned work

- All new development should target 0.9!
- Minor version 0.8 is the last one to support Julia 0.4!!
	- Critical bugfixes only

---

## 0.9 (current master/dev)

#### 0.9.0

- fixes to cycle
- add back single function recipe: `plot!(cos)`
- new axis formatter attribute... accepts functions to convert numbers to strings
- fix for inset plots
- GR:
	- fillrange fix
	- annotations fix
	- force double buffering in display

---

## 0.8

#### 0.8.2 (backported bug fixes for julia 0.4)

- plotly ticks fix
- unicodeplots size fix
- remove mkdir call in tests

#### 0.8.1

- manual drawing of axes/ticks/labels
- get_ticks uses optimize_ticks and Showoff
- changed PLOTS_DEFAULTS to be a global variable, not ENV key
- parameterized Segments for pushing tuples
- fix to axis extrema for Bool/nothing
- GR:
	- manually draw 2D axes... fixes several issues and missing features
	- fontsize fix
- PGFPlots: pass axis syle

#### 0.8.0

- added dependency on PlotUtils
- BREAKING: removed DataFrames support (now in StatPlots.jl)
- BREAKING: removed boxplot/violin/density recipes (now in StatPlots.jl)
- GR:
    - inline iterm2 support
    - trisurface support
    - heatmap fix
- PyPlot:
    - ijulia display fix
- GLVisualize:
    - first try with shapes
- iter_segments improvements
- bar_width support
- horizontal bars
- improve tick display
- better shape handling in pyplot, plotly
- improved padding calcs
- internal reorg of _plots method, add pipeline.jl

---

## 0.7

#### 0.7.5

- GR: LaTeX support
- Changed docs url to juliaplots.github.io
- added `contourf` seriestype
- allow `plt[1]` to return first Subplot
- allow `sp[1]` to return the first Series of the Subplot
- `series[k]` now passes through to `series.d[k]`
- allow calling `plot!(sp, ...)` to update a target Subplot
- PyPlot: zorder fix
- new DataFrames logic/recipe: more flexible/robust and allow Symbols for:
	- `(:fillrange, :line_z, :marker_z, :markersize, :ribbon, :weights, :xerror, :yerror)`
- new `display_type` and `extra_kwargs` plot attributes
- surface fix

#### 0.7.4

- added snooped precompiles, but left commented out
- GR fixes: markersize, shapes, legends
- fixes to recipes
- turned on Appveyor

#### 0.7.3

- rebuild violin and boxplot recipes
- "plot recipes"
- `cgrad` method for easy color gradient creation
- improvements to inset subplots
- Segments and iter_segments for NaN-separated vectors
- `bar` recipe now creates a `shape` series
- writemime fix for Interact.jl
- `link = :square` option
- !!! set `shape` attributes with line/fill, NOT marker/markerstroke !!!
- basic DPI support
- moved chorddiagram to PlotRecipes
- GR:
	- use temp files for img output
	- basic support for marker strokes and other marker fixes
- PyPlot:
	- Switch to recipes for bar, histogram, histogram2d
- GLVisualize
	- subplots
	- path/scatter and path3d/scatter3d
	- initial drawing of axes
- many smaller fixes and improvements

#### 0.7.2

- line_z arg for multicolored line segments
- pyplot
	- line_z (2d and 3d)
	- pushed all fig updates into display pipeline
	- remove native sticks/hline/vline in favor of recipes
- unicodeplots cleanup, ijulia fixes, ascii canvas
- `curves` series type
- `iter_segments` iterator
- moved arcdiagram out and into PlotRecipes (thanks @diegozea)
- several other fixes/checks

#### 0.7.1

- inset (floating) subplots
- change: when setting subplot/axis args from user recipes, they should apply only to their own subplot
- trim for violin/boxplot
- scatter3d recipe
- removed plotly.js in favor of build.jl download
- improvements/fixes to pgfplots backend
- improvements/fixes to plotly/plotlyjs backends
	- titles are annotations and properly placed with title_position
	- hover attribute
	- shapes (almost)
	- scattergl
- minimum perimeter logic in layout calc... fixed misaligned subplots
- new clims attribute
- more options for test_examples
- GR refactor
	- added transparency
	- moved axis/grid logic out of series loop
	- generalized 3d and polar projections
- renamed get_mod to Base.cycle
- pyplot log scale fixes
- PLOTS_DEFAULTS environment var processing
- rename :ellipse to :circle, :ellipse is now an alias
- supported args/types cleanup
- seriestype dependency methods and `@deps` macro
- bbox `h_anchor`/`v_anchor`
- new axis arg: `:link` is a list of subplots to link axes with
- cleanup/simplification of glvisualize backend


#### 0.7.0

- Check out [the summary](http://juliaplots.github.io/plots_v0.7/)
- Revamped and simplified internals
- [Recipes, recipes, recipes](https://github.com/JuliaPlots/RecipesBase.jl/issues/6)
- [Layouts and Subplots](https://github.com/tbreloff/Plots.jl/issues/60)
- DataFrames is loaded automatically when installed
- Overhaul to GroupBy mechanic (now offloads to a recipe)
- Replaced much of the argument processing with recipes
- Added series recipes, and began to strip down un-needed backend code.  Some recipes:
	- line, step, sticks, bar, histogram, histogram2d, boxplot, violin, quiver, errorbars, density, ohlc
- Added `@shorthands` and `@userplot` macros for recipe convenience
- Better handling of errorbars and ribbons
- New Axis type
	- Tracks extrema and discrete values
	- New `link_axes` functionality
- `linetype` has been renamed `seriestype` (the alias is reversed)
- Many fixes and huge cleanup in GR
- Brand new subplot layout mechanics:
	- `@layout` macro
	- AbstractLayout, Subplot, GridLayout, and everything related
	- Added dependency on Measures.jl
	- Computations of axis/guide sizes and precise positioning
- Refactored and compartmentalized default dictionaries for attributes
- Deprecated Gadfly and Immerse backends
- Added `series_annotations` attribute (previously that functionality was merged with `annotations`, which are not series-specific)
- Removed `axis` attribute... currently not supporting twin (right) y axes
- Check for `ENV["PLOTS_USE_ATOM_PLOTPANE"]` and default to false
- Improved backend interface to reduce redundant code.  Template updated.
- Added `html_output_format`, primarily for choosing between png and svg output in IJulia.
- Partial support of Julia v0.5
- Switched testing to dump reference images to JuliaPlots/PlotReferenceImages.jl
- Moved docs-specific code to new JuliaPlots/PlotDocs.jl
- Moved example list from ExamplePlots into Plots.
- Added several examples and improved others.
- Many other smaller changes and bug fixes.


---

## Version 0.6

#### 0.6.2

- `linewidth` fixes
- `markershape` fix
- converted center calc to centroid for shapes
- new dependency on [RecipesBase](https://github.com/JuliaPlots/RecipesBase.jl)
- REQUIRE upper limit for RecipesBase: 0.0.1
- GR fixes/improvements (@jheinen)
  - support `zlims`, `bins`
  - allow Plots colormaps
  - other bug fixes
  - native image support
- PGFPlots fixes/improvements (@pkofod)
- DataFrames are handled by recipes
- Plotly: zaxis, tick rotation, 3d axis fix
- Improvements in handling discrete data
- Support for image display
- `arrow` keyword and support for adding arrows to paths
- changed quiver recipe to use arrows
- Bug fixes for boxplots, heatmaps, and more

#### 0.6.1

- `rotation` keyword
- improved supported graphs
- subplot bug fix

#### 0.6.0

- `apply_series_recipe` framework for built-in recipes
- [boxplot/violin recipes](https://github.com/tbreloff/ExamplePlots.jl/blob/master/notebooks/boxplot.ipynb)
- [errorbar/ribbon recipes](https://github.com/tbreloff/ExamplePlots.jl/blob/master/notebooks/errorbars.ipynb)
- [quiver recipe](https://github.com/tbreloff/ExamplePlots.jl/blob/master/notebooks/quiver.ipynb)
- `polar` coordinates
- better support for shapes and custom polygons (see [batman](https://github.com/tbreloff/ExamplePlots.jl/blob/master/notebooks/batman.ipynb))
- z-axis keywords
- 3D indexing overhaul: `push!`, `append!` support
- matplotlib colormap constants (`:inferno` is the new default colormap for Plots)
- `typealias KW Dict{Symbol,Any}` used in place of splatting in many places
- png generation for plotly backend using wkhtmltoimage
- `normalize` and `weights` keywords
- background/foreground subcategories for fine-tuning of looks
- `add_theme`/`set_theme` and ggplot2 theme (see [this issue](https://github.com/tbreloff/Plots.jl/issues/201))
- `PLOTS_DEFAULT_BACKEND` environment variable
- `barh` linetype
- support for non-gridded surfaces with pyplot's trisurface
- pyplot surface zcolor
- internal refactor of supported.jl
- `wrap` method to bypass input processing
- `translate`, `scale` and `rotate` methods for coordinates and shapes
- and many more minor fixes and improvements

---

## Version 0.5

#### 0.5.4

- old heatmaps have been renamed to hist2d, and true heatmaps implemented (see https://github.com/tbreloff/Plots.jl/issues/147)
- lots of reorganization and redesign of the internals
- lots of renaming to keep to conventions: AbstractPlot, AbstractBackend, etc
- initial redesign of layouts
- integration with Atom PlotPane
- arc diagram and chord diagram (thanks to @diegozea: see https://github.com/tbreloff/Plots.jl/issues/163)
- work on GR, GLVisualize, and PGFPlots backends (thanks @jheinen @dlfivefifty @pkofod)
- improvements to Plotly setup (thanks @spencerlyon2)
- overhaul to series creation logic and groupby mechanic
- replace Dict with `typealias KW Dict{Symbol,Any}` in many places, also replacing keyword arg splatting
- new `shape` linetype for plotting polygons in plot-coordinates (see https://github.com/tbreloff/ExamplePlots.jl/blob/master/notebooks/batman.ipynb)
- many other fixes

#### 0.5.3

- `@gif` macro with `every`/`when` syntax
- bezier curves and other graph drawing helpers
- added FixedSizeArrays dependency with relevant functionality
- merged lots of improvements to GR (thanks @jheinen)
- `overwrite_figure`/`reuse` arg for reusing the same figure window
- deprecated Qwt, Winston, and Bokeh backends
- improved handling of 3D inputs (call `z=rand(10,10); surface(z)` for example)
- fix IJulia display issue
- lots of progress on PlotlyJS backend
- and many other changes and fixes...

#### 0.5.2

- Added [GR.jl](https://github.com/jheinen/GR.jl) as a backend (unfinished but functional) All credit to @jheinen
- Set defaults within backend calls (i.e. `gadfly(legend=false)`)
- `abline!`; also extrema allows plotting functions without giving x (i.e. `plot(cos, 0, 10); plot!(sin)`) @pkofod @joshday
- Integration with [PlotlyJS.jl](https://github.com/spencerlyon2/PlotlyJS.jl) for using Plotly inside a Blink window @spencerlyon2
- The Plotly backend has been split into my built-in version (`plotly()`) and @spencerlyon2's backend (`plotlyjs()`)
- Revamped backend setup code for easily adding new backends
- New docs (WIP) at http://juliaplots.github.io/
- Overhaul to `:legend` keyword (see https://github.com/tbreloff/Plots.jl/issues/135)
- New dependency on Requires, allows auto-loading of DataFrames support
- Support for plotting lists of Tuples and FixedSizeArrays
- new `@animate` macro for super simple animations (see https://github.com/tbreloff/Plots.jl/issues/111#issuecomment-181515616)
- allow Function for `:fillrange` and `zcolor` arguments (for example: `scatter(sin, 0:10, marker=15, fill=(cos,0.4), zcolor=sin)`)
- allow vectors of PlotText without x/y coords (for example: `scatter(rand(10), m=20, ann=map(text, 1:10))`)
- Lots and lots of fixes

#### 0.5.1

#### 0.5.0

- `with` function for temporary defaults
- contours
- basic 3D plotting
- preliminary support for Bokeh
- `stroke` and `brush` for more fine-tuned control over visuals
- smarter "magic" arguments: `line`, `marker`
