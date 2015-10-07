
module PlotExamples

using Plots
using Colors

const DOCDIR = Pkg.dir("Plots") * "/docs"
const IMGDIR = Pkg.dir("Plots") * "/img"

doc"""
Holds all data needed for a documentation example... header, description, and plotting expression (Expr)
"""
type PlotExample
  header::AbstractString
  desc::AbstractString
  exprs::Vector{Expr}
end


function fakedata(sz...)
  y = Array(Float64, sz...)
  for r in 2:size(y,1)
    y[r,:] = 0.9 * y[r-1,:] + randn(size(y,2))'
  end
  y
end


# the examples we'll run for each
const examples = PlotExample[
  PlotExample("Lines",
              "A simple line plot of the columns.",
              [:(plot(fakedata(50,5), w=3))]),
  PlotExample("Functions",
              "Plot multiple functions.  You can also put the function first, or use the form `plot(f, xmin, xmax)` where f is a Function or AbstractVector{Function}.",
              [:(plot(0:0.01:4π, [sin,cos]))]),
  PlotExample("",
              "Or make a parametric plot (i.e. plot: (fx(u), fy(u))) with plot(fx, fy, umin, umax).",
              [:(plot(sin, x->sin(2x), 0, 2π, leg=false, fill=(0,:orange)))]),
  PlotExample("Colors",
              "Access predefined palettes (or build your own with the `colorscheme` method).  Line/marker colors are auto-generated from the plot's palette, unless overridden.  Set the `z` argument to turn on series gradients.",
              [:(y = rand(100)), :(plot(0:10:100,rand(11,4),lab="lines",w=3, palette=:grays, fill=(0.5,:auto))), :(scatter!(y, z=abs(y-.5), m=(10,:heat), lab="grad"))]),
  PlotExample("Global",
              "Change the guides/background/limits/ticks.  Convenience args `xaxis` and `yaxis` allow you to pass a tuple or value which will be mapped to the relevant args automatically.  The `xaxis` below will be replaced with `xlabel` and `xlims` args automatically during the preprocessing step. You can also use shorthand functions: `title!`, `xaxis!`, `yaxis!`, `xlabel!`, `ylabel!`, `xlims!`, `ylims!`, `xticks!`, `yticks!`",
              [:(plot(rand(20,3), title="TITLE", xaxis=("XLABEL",(-5,30),0:2:20,:flip), yaxis=("YLABEL",:log10), background_color = RGB(0.2,0.2,0.2), leg=false))]),
  PlotExample("Two-axis",
              "Use the `axis` arguments.\n\nNote: Currently only supported with Qwt and PyPlot",
              [:(plot(Vector[randn(100), randn(100)*100]; axis = [:l :r], ylabel="LEFT", yrightlabel="RIGHT"))]),
  PlotExample("Arguments",
              "Plot multiple series with different numbers of points.  Mix arguments that apply to all series (marker/markersize) with arguments unique to each series (colors).  Special arguments `line`, `marker`, and `fill` will automatically figure out what arguments to set (for example, we are setting the `linestyle`, `linewidth`, and `color` arguments with `line`.)  Note that we pass a matrix of colors, and this applies the colors to each series.",
              [:(plot(Vector[rand(10), rand(20)]; marker=(:ellipse,8), line=(:dot,3,[:black :orange])))]),
  PlotExample("Build plot in pieces",
              "Start with a base plot...",
              [:(plot(rand(100)/3, reg=true, fill=(0,:green)))]),
  PlotExample("",
              "and add to it later.",
              [:(scatter!(rand(100), markersize=6, c=:orange))]),
  PlotExample("Heatmaps",
              "",
              [:(heatmap(randn(10000),randn(10000), nbins=100))]),
  PlotExample("Line types",
              "",
              [:(types = intersect(supportedTypes(), [:line, :path, :steppre, :steppost, :sticks, :scatter])'),
                  :(n = length(types)),
                  :(x = Vector[sort(rand(20)) for i in 1:n]),
                  :(y = rand(20,n)),
                  :(plot(x, y, line=(types,3), lab=map(string,types), ms=15))]),
  PlotExample("Line styles",
              "",
              [:(styles = setdiff(supportedStyles(), [:auto])'), :(plot(cumsum(randn(20,length(styles)),1); style=:auto, label=map(string,styles), w=5))]),
  PlotExample("Marker types",
              "",
              [:(markers = setdiff(supportedMarkers(), [:none,:auto])'), :(scatter(0.5:9.5, [fill(i-0.5,10) for i=length(markers):-1:1]; marker=:auto, label=map(string,markers), ms=12))]),
  PlotExample("Bar",
              "x is the midpoint of the bar. (todo: allow passing of edges instead of midpoints)",
              [:(bar(randn(1000)))]),
  PlotExample("Histogram",
              "",
              [:(histogram(randn(1000), nbins=50))]),
  PlotExample("Subplots",
              """
                subplot and subplot! are distinct commands which create many plots and add series to them in a circular fashion.
                You can define the layout with keyword params... either set the number of plots `n` (and optionally number of rows `nr` or 
                number of columns `nc`), or you can set the layout directly with `layout`.
              """,
              [:(subplot(randn(100,5), layout=[1,1,3], t=[:line :hist :scatter :step :bar], nbins=10, leg=false))]),
  PlotExample("Adding to subplots",
              "Note here the automatic grid layout, as well as the order in which new series are added to the plots.",
              [:(subplot(randn(100,5), n=4))]),
  PlotExample("",
              "",
              [:(subplot!(randn(100,3)))]),
  PlotExample("Open/High/Low/Close",
              "Create an OHLC chart.  Pass in a vector of OHLC objects as your `y` argument.  Adjust the tick width with arg `markersize`.",
              [:(n=20), :(hgt=rand(n)+1), :(bot=randn(n)), :(openpct=rand(n)), :(closepct=rand(n)), :(y = [OHLC(openpct[i]*hgt[i]+bot[i], bot[i]+hgt[i], bot[i], closepct[i]*hgt[i]+bot[i]) for i in 1:n]), :(ohlc(y; markersize=8))]),
  PlotExample("Annotations",
              "Currently only text annotations are supported.  Pass in a tuple or vector-of-tuples: (x,y,text).  `annotate!(ann)` is shorthand for `plot!(; annotation=ann)`",
              [
                :(y = rand(10)),
                :(plot(y, ann=(3,y[3],"this is #3"))),
                :(annotate!([(5,y[5],"this is #5"),(9,y[10],"this is #10")]))
              ]),
  
]


function createStringOfMarkDownCodeValues(arr, prefix = "")
  string("`", prefix, join(arr, "`, `$prefix"), "`")
end
createStringOfMarkDownSymbols(arr) = isempty(arr) ? "" : createStringOfMarkDownCodeValues(arr, ":")


function generate_markdown(pkgname::Symbol)

  # set up the backend, and don't show the plots by default
  pkg = backend(pkgname)
  # default(:show, false)

  # mkdir if necessary
  try
    mkdir("$IMGDIR/$pkgname")
  end

  # open the markdown file
  md = open("$DOCDIR/$(pkgname)_examples.md", "w")

  write(md, "# Examples for backend: $pkgname\n\n")
  write(md, "- Supported arguments: $(createStringOfMarkDownCodeValues(supportedArgs(pkg)))\n")
  write(md, "- Supported values for axis: $(createStringOfMarkDownSymbols(supportedAxes(pkg)))\n")
  write(md, "- Supported values for linetype: $(createStringOfMarkDownSymbols(supportedTypes(pkg)))\n")
  write(md, "- Supported values for linestyle: $(createStringOfMarkDownSymbols(supportedStyles(pkg)))\n")
  write(md, "- Supported values for marker: $(createStringOfMarkDownSymbols(supportedMarkers(pkg)))\n")
  write(md, "- Is `subplot`/`subplot!` supported? $(subplotSupported(pkg) ? "Yes" : "No")\n\n")

  write(md, "### Initialize\n\n```julia\nusing Plots\n$(pkgname)()\n```\n\n")


  for (i,example) in enumerate(examples)

    try

      # we want to always produce consistent results
      srand(1234)

      # run the code
      map(eval, example.exprs)

      # save the png
      imgname = "$(pkgname)_example_$i.png"

      # NOTE: uncomment this to overwrite the images as well
      png("$IMGDIR/$pkgname/$imgname")

      # write out the header, description, code block, and image link
      write(md, "### $(example.header)\n\n")
      write(md, "$(example.desc)\n\n")
      write(md, "```julia\n$(join(map(string, example.exprs), "\n"))\n```\n\n")
      write(md, "![](../img/$pkgname/$imgname)\n\n")

    catch ex
      # TODO: put error info into markdown?
      warn("Example $pkgname:$i failed with: $ex")
    end

    #
  end

  close(md)

end


# make and display one plot
function test_example(pkgname::Symbol, idx::Int, debug = true)
  Plots._debugMode.on = debug
  println("Testing plot: $pkgname:$idx:$(examples[idx].header)")
  backend(pkgname)
  backend()
  map(eval, examples[idx].exprs)
  plt = current()
  gui(plt)
  plt
end

# generate all plots and create a dict mapping idx --> plt
function test_all_examples(pkgname::Symbol, debug = false)
  plts = Dict()
  for i in 1:length(examples)
    # if examples[i].header == "Subplots" && !subplotSupported()
    #   break
    # end

    try
      plt = test_example(pkgname, i, debug)
      plts[i] = plt
    catch ex
      # TODO: put error info into markdown?
      warn("Example $pkgname:$i:$(examples[i].header) failed with: $ex")
    end
  end
  plts
end

# axis            # :left or :right
# color           # can be a string ("red") or a symbol (:red) or a ColorsTypes.jl 
#                 #   Colorant (RGB(1,0,0)) or :auto (which lets the package pick)
# label           # string or symbol, applies to that line, may go in a legend
# width           # width of a line
# linetype        # :line, :step, :stepinverted, :sticks, :scatter, :none, :heatmap, :hexbin, :hist, :bar
# linestyle       # :solid, :dash, :dot, :dashdot, :dashdotdot
# marker          # :none, :ellipse, :rect, :diamond, :utriangle, :dtriangle,
#                 #   :cross, :xcross, :star1, :star2, :hexagon
# markercolor     # same choices as `color`, or :match will set the color to be the same as `color`
# markersize      # size of the marker
# nbins           # number of bins for heatmap/hexbin and histograms
# heatmap_c       # color cutoffs for Qwt heatmaps
# fill          # fill value for area plots
# title           # string or symbol, title of the plot
# xlabel          # string or symbol, label on the bottom (x) axis
# ylabel          # string or symbol, label on the left (y) axis
# yrightlabel     # string or symbol, label on the right (y) axis
# reg             # true or false, add a regression line for each line
# size            # (Int,Int), resize the enclosing window
# pos             # (Int,Int), move the enclosing window to this position
# windowtitle     # string or symbol, set the title of the enclosing windowtitle
# screen          # Integer, move enclosing window to this screen number (for multiscreen desktops)



const _ltdesc = Dict(
    :none => "No line",
    :line => "Lines with sorted x-axis",
    :path => "Lines",
    :steppre => "Step plot (vertical then horizontal)",
    :steppost => "Step plot (horizontal then vertical)",
    :sticks => "Vertical lines",
    :scatter => "Points, no lines",
    :heatmap => "Colored regions by density",
    :hexbin => "Similar to heatmap",
    :hist => "Histogram (doesn't use x)",
    :bar => "Bar plot (centered on x values)",
    :hline => "Horizontal line (doesn't use x)",
    :vline => "Vertical line (doesn't use x)",
    :ohlc => "Open/High/Low/Close chart (expects y is AbstractVector{Plots.OHLC})",
  )

function buildReadme()
  readme = readall("$DOCDIR/readme_template.md")

  # build keyword arg table
  table = "Keyword | Default | Type | Aliases \n---- | ---- | ---- | ----\n"
  for d in (Plots._seriesDefaults, Plots._plotDefaults)
    for k in Plots.sortedkeys(d)
      aliasstr = createStringOfMarkDownSymbols(aliases(Plots._keyAliases, k))
      table = string(table, "`:$k` | `$(d[k])` | $(d==Plots._seriesDefaults ? "Series" : "Plot") | $aliasstr  \n")
    end
  end
  readme = replace(readme, "[[KEYWORD_ARGS_TABLE]]", table)

  # build linetypes table
  table = "Type | Desc | Aliases\n---- | ---- | ----\n"
  for lt in Plots._allTypes
    aliasstr = createStringOfMarkDownSymbols(aliases(Plots._typeAliases, lt))
    table = string(table, "`:$lt` | $(_ltdesc[lt]) | $aliasstr  \n")
  end
  readme = replace(readme, "[[LINETYPES_TABLE]]", table)

  # build linestyles table
  table = "Type | Aliases\n---- | ----\n"
  for s in Plots._allStyles
    aliasstr = createStringOfMarkDownSymbols(aliases(Plots._styleAliases, s))
    table = string(table, "`:$s` | $aliasstr  \n")
  end
  readme = replace(readme, "[[LINESTYLES_TABLE]]", table)

  # build markers table
  table = "Type | Aliases\n---- | ----\n"
  for s in Plots._allMarkers
    aliasstr = createStringOfMarkDownSymbols(aliases(Plots._markerAliases, s))
    table = string(table, "`:$s` | $aliasstr  \n")
  end
  readme = replace(readme, "[[MARKERS_TABLE]]", table)

  readme_fn = Pkg.dir("Plots") * "/README.md"
  f = open(readme_fn, "w")
  write(f, readme)
  close(f)

  gadfly()
  Plots.dumpSupportGraphs()
end

default(size=(600,400))

# run it!
# note: generate separately so it's easy to comment out
# @osx_only generate_markdown(:unicodeplots)
# generate_markdown(:qwt)
# generate_markdown(:gadfly)
# generate_markdown(:pyplot)
# generate_markdown(:immerse)
# generate_markdown(:winston)


end # module

