
# Plots.jl NEWS

#### notes on release changes, ongoing development, and future planned work

## NOTE: this file is deprecated, see the [TagBot](https://github.com/marketplace/actions/julia-tagbot) auto-generated changelogs instead

## 0.28.3
- support generalized array interface
- save to pdf, svg and eps in plotlyjs
- fix for clims in line_z
- optimize heatmap logic in gr

## 0.26.3
- fix `vline` with dates
- fix PyPlot logscale bug
- avoid annotation clipping for PyPlot
- allow plotting of Any vectors and 3D plotting again in convertToAnyVector
- specify legend title font in GR and PyPlot
- delete `pushtomaster.sh`
- use `=== nothing`

## 0.26.2
- improve empty animation build error
- fix GR axis flip for heatmaps and images
- fix ribbons specified as tuples
- add Char recipe
- fix Plotly plots with single-element series
- rewrite PlotlyJS backend

## 0.26.1
- handle `Char`s as input data
- fix html saving for Plotly
- expand ~ in paths on UNIX systems
- convertToAnyVector clean-up
- fix color_palette grouping issue

## 0.26.0
- use FFMPEG.jl
- add missing method for convertToAnyVector

## 0.25.3
- add areaplot
- allow missing in z_color arguments
- more general tuple recipe
- stephist logscale improvements

## 0.25.2
- improvements to handle missings
- pyplot: allow setting the color gradient for z values
- document :colorbar_entry
- limit number of automatic bins
- fix ENV['PLOTS_DEFAULT_BACKEND']
- don't let aspect_ratio impact subplot size
- implement arrowstyle for GR
- fix bug in plotly_convert_to_datetime
- improve missing support
- gr: polar heatmaps
- make sure show returns nothing

## 0.25.1
- fix gr_display

## 0.25.0
- Replace StaticArrays with GeometryTypes
- Contour fixes for GR

## 0.24.0
- Update to the new PyCall and PyPlot API
- fix drawing of ticks
- fix y label position with GR

## 0.23.2
- pyplot fixes
- Add option :tex_output_standalone to set the 'include_preamble' argument in the PGFPlots backend.
- fix ticks
- support plotly json mime
- fix image axis limits
- default to radius 0 at center for polar plots

## 0.23.1
- slightly faster load time
- fixed errant MethodError
- fix bar plots with unicodeplots
- better colorbars for contour
- add volume seriestype for GR
- fix passing a tuple to custom ticks
- add vline to pgfplots
- add tex output for pyplot
- better 3d axis labels for GR

## 0.23.0
- compatible with StatPlots -> StatsPlots name shift
- fix histograms for vectors with NaN and Inf
- change gif behaviour (remove cache-busting)
- improved docstrings for shorthands functions
- fix font rotation for pyplot
- fix greyscale images for pyplot
- clamp greyscale images with values outside 0,1
- support keyword argument for font options
- allow vector of markers for pyplot scatter

## 0.22.5
- improve behaviour of plotlyjs backend

## 0.22.4
- Add support for discrete contourf plots with GR

## 0.22.3
- Fix the `showtheme` function

## 0.22.2
- Allow annotations to accept a Tuple instead of the result of a text call (making it possible to specify font characteristics in recipes). E.g. `annotations = (2, 4, ("test", :right, 8, :red))` is the same as `annotations = (2, 4, text("test", :right, 8, :red))`

## 0.22.1
- push PlotsDisplay just after REPLDisplay

## 0.22.0
- deprecate GLVisualize
- allow 1-row and 1-column heatmaps
- add portfoliodecomposition recipe from PlotRecipes
- solve Shape bug
- simplify PyPlot backend installation
- fix wireframe bug in PyPlot
- fix color bug in PyPlot
- minor bug fixes in gr and pyplot

## 0.21.0
- Compatibility with StaticArrays 0.9.0
- Up GR min version to 0.35
- fix :mirror

## 0.20.6
- fixes for PlotDocs.jl
- fix gr axis color argument
- Shapes for inspectdr
- don't load plotly js file by default

## 0.20.5
- fix precompilation issue when depending on Plots

## 0.20.4
- honour `html_output_format` in Juno

## 0.20.3
- implement guide position in gr, pyplot and pgfplots
- inspectdr fixes
- default appveyor
- rudimentary missings support
- deprecation fixes for PGFPlots

## 0.20.0
Many updates, min julia 1.0
- change display type to use PlotsDisplay (fixes Juno integration)
- change all internal uses of `d` to `plotattributes` (no user change)
- change spy implementation to use `scatter` not `heatmap`
- sort x axes when passing a vector of strings as x
- improve performance of marker_z
- update CI to 1.0
- minor depwarn ifixes
- only draw one colorbar with GR
- add colorbar_title to GR and pgfplots
- fix savefig with latexstrings for PyPlot
- fix NamedTuple integration
- don't export `P2` and `P3`
- make it possible to use 2-argument function as argument to marker_z
- make `plotattr` work again

## 0.19.3
- fix some julia 0.7 deprecations
- fix 32-bit OS functionality

## 0.19.2
- several small fixes for 1.0 compatibility

## 0.19.1
- don't broadcast plot_color

## 0.19.0
- Refactor conditional loading to use Requires
- Many fixes for 1.0 compatibility

## 0.18.0
- update minor version to 0.7

## 0.17.4
- fix thickness_scaling for pyplot

## 0.17.3
- Log-scale heatmap edge computation
- Fix size and dpi for GR and PyPlot
- Fix fillrange with line segments on PyPlot and Plotly
- fix flip for heatmap and image on GR
- New attributes for PGFPlots
- Widen axes for most series types and log scales
- Plotly: fix log scale with no ticks
- Fix axis flip on Plotly
- Fix hover and zcolor interaction in Plotly
- WebIO integration for PlotlyJS backend

## 0.17.2
- fix single subplot in plotly
- implement `(xyz)lims = :round`
- PyPlot: fix bg_legend = invisible()
- set fallback tick specification for axes with discrete values
- restructure of show methods

## 0.17.1
- Fix contour for PGFPlots
- 32Bit fix: Int64 -> Int
- Make series of shapes and segments toggle together in Plotly(JS)
- Fix marker arguments
- Fix processing order of series recipes
- Fix Plotly(JS) ribbon
- Contour plots with x,y in grid form on PyPlot

## 0.17.0
- Add GR dependency to make it the default backend
- Improve histogram2d bin estimation
- Allow vector arguments for certain series attributes and support line_z and fill_z on GR, PyPlot, Plotly(JS) and PGFPlots
- Automatic scientific notation for tick labels
- Allow to set the theme in PLOTS_DEFAULTS
- Implement plots_heatmap seriestype providing a Plots recipe for heatmaps

## 0.16.0
- fix 3D plotting in PyPlot
- Infinite objects

## 0.15.1

- fix scientific notation for labels in GR
- fix labels with logscale
- fix image cropping with GR
- fix grouping of annotations
- fix annotations in Plotly
- allow saving notebook with plots as pdf from IJulia
- fix fillrange and ribbon for step recipes
- implement native ticks that respond to zoom
- fix bar plot with one bar
- contour labels and colorbar fixes
- interactive linked axis for PyPlot
- add `NamedTuple` syntax to group with named legend
- use bar recipe in Plotly
- implement categorical ticks

## 0.15.0

- improve resolution of png output of GR with savefig()
- add check for ticks=nothing
- allow transparency in heatmaps
- fix line_z for GR
- fix legendcolor for pyplot
- fix pyplot ignoring alpha values of images
- don't let `abline!` change subplot limits
- update showtheme recipe

## 0.14.2

- fix plotly bar lines bug
- allow passing multiple series to `ribbon`
- add a new example for `line_z`

## 0.14.1

- Add linestyle argument to the legend
- Plotly: bar_width and stroke_width support for bar plots
- abline! does not change axis limits
- Fix default log scale ticks in GR backend
- Use the :fontsize keys so the scalefontsizes command works
- Prepare support for new PlotTheme type in PlotThemes

## 0.14.0

- remove use of imagemagick; saving gifs now requires ffmpeg
- improvements to ffmpeg gif quality and speed
- overhaul of fonts, allows setting fonts in recipes and with magic arguments
- added `camera` attribute to control camera position for 3d plots
- added `showaxis` attribute to control which axes to display
- improvements of polar plots axes, and better backend consistency
- changed the 'spy' recipe back to using heatmap
- added `scatterpath` seriestype
- allow plotlyjs to save svg
- add `reset_defaults()` function to reset plot defaults
- update syntax to 0.6
- make `fill = true` fill to 0 rather than to 1
- use new `@df` syntax in StatsPlots examples
- allow changing the color of legend box
- implement `title_location` for gr
- add `hline` marker to pgfplots - fixes errorbars
- pyplot legends now show marker types
- pyplot colorbars take font style from y axis
- pyplot tickmarks color the same as axis color
- allow setting linewidth for contour in gr
- allow legend to be outside plot area for pgfplots
- expand axis extrema for heatmap
- extendg grid lines to axis limits
- fix `line_z` for pyplot and gr
- fixed colorbar problem for flipped axes with gr
- fix marker_z for 3d plots in gr
- fix `weights` functionality for histograms
- fix gr annotations with colorbar
- fix aspect ratio in gr
- fix "hidden window" problem after savefig in gr
- fix pgfplots logscale ticks error
- fix pgfplots legends symbols
- fix axis linking for plotlyjs
- fix plotting of grayscale images

## 0.13.1

- fix a bug when passing a vector of functions with no bounds (e.g. `plot([sin, cos])`)
- export `pct` and `px` from Plots.PlotMeasures

## 0.13.0

- support `plotattributes` rather than `d` in recipes
- no longer export `w`, `h` and names from Measures.jl; use `using Plots.PlotMeasures` to get these names back
- `bar_width` now depends on the minimum distance between bars, not the mean
- better automatic x axis limits for plotting Functions
- `tick_direction` attribute now allows ticks to be on the inside of the plot border
- removed a bug where `p1 = plot(randn(10)); plot(p1, p2)` made `display(p1)` impossible
- allow `plot([])` to generate an empty plot
- add `origin` framestyle
- ensure finite bin number on histograms with only one unique value
- better automatic histogram bins for 2d histograms
- more informative error message on passing unsupported seriestype in a recipe
- allow grouping in user recipes
- GR now has `line_z` and `fill_z` attributes for determining the color of shapes and lines
- change GR default view angle for 3D plots to match that of PyPlot
- fix `clims` on GR
- fix `marker_z` for plotly backend
- implement `framestyle` for plotly
- fix logscale bug error for values < 1e-16 on pyplot
- fix an issue on pyplot where >1 colorbar would be shown if there was >1 series
- fix `writemime` for eps

## 0.12.4

- added a new `framestyle` argument with choices: :box, :semi, :axes, :grid and :none
- changed the default bar width to 0.8
- added working ribbon to plotly backend
- ensure that automatic ticks always generate 4 to 8 ticks
- group now groups keyword arguments of the same length as the input
- allow passing DateTime objects as ticks
- allow specifying the number of ticks as an integre
- fix bug on errorbars in gr
- fixed some but not all world age issues
- better margin with room for text
- added a `match` option for linecolor
- better error message un unsupported series types
- add a 'stride' keyword for the pyplot backend

## 0.12.3

- new grid line style defaults
- `grid` is now an axis attribute and a magic argument: it is now possible to modify the grid line style, alpha and line width
- Enforce plot order in user recipes
- import `plot!` from RecipesBase
- GR no longer automatically handles _ and ^ in texts
- fix GR colorbar for scatter plots

#### 0.12.2

- fix an issue with Juno/PlotlyJS compatibility on new installations
- fix markers not showing up in seriesrecipes using :scatter
- don't use pywrap in the pyplot backend
- improve the bottom margin for the gr backend

#### 0.12.1

- fix deprecation warnings
- switch from FixedSizeArrays to StaticArrays.FixedSizeArrays
- drop FactCheck in tests
- remove julia 0.5 compliant uses of transpose operator
- fix GR heatmap bugs
- fix GR guide padding
- improve legend markers in GR
- add surface alpha for Plotly(JS)
- add fillrange to Plotly(JS)
- allow usage of Matplotlib 1.5 with PyPlot
- fix GLVisualize for julia 0.6
- conform to changes in InspectDR

#### 0.12.0

- 0.6 only

#### 0.11.3

- add HDF5 backend
- GR replaces PyPlot as first-choice backend
- support for legend position in GR
- smaller markers in GR
- better viewport size in GR
- fix glvisualize support
- remove bug with three-argument method of `text`
- `legendtitle` attribute added
- add test for `spy`

#### 0.11.0

- julia 0.6 compatibility
- matplotlib 2.0 compatibility
- add inspectdr backend
- improved histogram functionality:
- added a `:stephist` and `:scatterhist` series type as well as ``:barhist` (the default)
- support for log scale axes with histograms
- support for plotting `StatsBase.Histogram`
- allowing bins to be specified as `:sturges`, `:rice`, `:scott` or :fd
- allow `normalization` to be specified as :density (for unequal bins) or :pdf (sum to 1)
- add a `plotattr` function to access documentation for Plots attribute
- add `fill_z` attribute for pyplot
- add colorbar_title to plotlyjs
- enable standalone window for plotlyjs
- improved support for pgfplots, ticks rotation, clims, series_annotations
- restore colorbars for GR
- better axis labels for heatmap in GR
- better marker sizes in GR
- fix color representation in GR
- update GR legend
- fix image bug on GR
- fix glvisualize dependencies
- set dotted grid lines for pyplot
- several improvements to inspectdr
- improved tick positions for TimeType x axes
- support for improved color gradient capability in PlotUtils
- add a showlibrary recipe to display color libraries
- add a showgradient recipe to display color gradients
- add `vectorfield` as an alias for `quiver`
- use `PlotUtils.adaptedgrid` for functions


#### 0.9.5

- added dependency on PlotThemes
- set_theme --> theme
- remove Compat from REQUIRE
- warning for DataFrames without StatsPlots
- closeall exported and implemented for gr/pyplot
- fix DateTime recipe
- reset theme with theme(:none)
- fix link_axes! for nested subplots
- fix plotly lims for log scale

#### 0.9.4

- optimizations surrounding Subplot.series_list
- better Atom support, support plotlyjs
- gr:
    - gks_wstype defaults and gr_set_output
    - heatmap uses GR.drawimage
- histogram2d puts NaN for zeros
- improved support of NaN in heatmaps
- rebuilt spy recipes to output scatters with marker_z set
- deprecate png support in plotly... point to plotlyjs
- fixes:
    - axis widen with lims set
    - reset_extrema, setxyz
    - bar plot widen
    - better tick padding
    - consistent tick rotation
    - consistent aspect_ratio
    - pyplot dpi
    - plotly horizontal bars
    - handle series attributes when combining subplots
    - gr images transposed
    - converted Date/DateTime to new type recipe approach for arrays
- issues closed include: #505 #513 #479 #523 #526 #529

#### 0.9.3

- support pdf and eps in plotlyjs backend
- allow curly after grid: `@layout [a b; grid(4,4){0.8h}]`
- add_backend redesign

#### 0.9.2

- glvisualize backend (@SimonDanisch)
    - too much to list! ready for alpha testing
- Volume and volume seriestype
- Atom: support for PlotPane and proper gui display
- gr:
    - clims
    - aspect ratio
- pgfplots:
    - fixes for ticks, axes, and more
- pyplot:
    - font families
    - colorbar guide
    - pixel marker
- unicodeplots
    - basic support for shapes
- improved add_backend
- refactor of is_supported methods
- element-wise type recipes (see https://github.com/tbreloff/Plots.jl/issues/460#issuecomment-248428908)
- several other fixes/improvements

#### 0.9.1

- Pkg.dir --> dirname (@tkelman)
- `axis = nothing` magic
- fixes:
    - clim for line_z
    - sticks default range for log scale
    - rotate method
    - pyplot heatmap
    - spurious scale warnings
    - gr image/alpha
    - plotly.js path
    - orientation extrema
    - bar, reset orientation
- switch transpose_z to use permutedims
- skinny x/+ markers
- ticks in pgfplots
- eps in savefig (@anriseth)
- add_backend convenience
- type recipes for Date/DateTime (@maximsch2)
- mirror attribute and twinx convenience
- Axis.sp --> Axis.sps
- recipe postprocessing for allowing aliases and magic args in recipe bodies



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
- BREAKING: removed DataFrames support (now in StatsPlots.jl)
- BREAKING: removed boxplot/violin/density recipes (now in StatsPlots.jl)
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
- `const KW = Dict{Symbol,Any}` used in place of splatting in many places
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
