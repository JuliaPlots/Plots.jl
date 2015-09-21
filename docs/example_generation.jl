
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


# the examples we'll run for each
const examples = PlotExample[
  PlotExample("Lines",
              "A simple line plot of the 3 columns.",
              [:(plot(rand(100,3)))]),
  PlotExample("Functions",
              "Plot multiple functions.  You can also put the function first.",
              [:(plot(0:0.01:4π, [sin,cos]))]),
  PlotExample("",
              "You can also call it with plot(f, xmin, xmax).",
              [:(plot([sin,cos], 0, 4π))]),
  PlotExample("",
              "Or make a parametric plot (i.e. plot: (fx(u), fy(u))) with plot(fx, fy, umin, umax).",
              [:(plot(sin, x->sin(2x), 0, 2π, legend=false))]),
  PlotExample("Global",
              "Change the guides/background without a separate call.",
              [:(plot(rand(10); title="TITLE", xlabel="XLABEL", ylabel="YLABEL", background_color = RGB(0.5,0.5,0.5)))]),
  PlotExample("Two-axis",
              "Use the `axis` or `axiss` arguments.\n\nNote: Currently only supported with Qwt and PyPlot",
              [:(plot(Vector[randn(100), randn(100)*100]; axiss = [:left,:right], ylabel="LEFT", yrightlabel="RIGHT"))]),
  PlotExample("Vectors w/ pluralized args",
              "Plot multiple series with different numbers of points.  Mix arguments that apply to all series (singular... see `marker`) with arguments unique to each series (pluralized... see `colors`).",
              [:(plot(Vector[rand(10), rand(20)]; marker=:ellipse, markersize=8, colors=[:red,:blue]))]),
  PlotExample("Build plot in pieces",
              "Start with a base plot...",
              [:(plot(rand(100)/3; reg=true, fillto=0))]),
  PlotExample("",
              "and add to it later.",
              [:(scatter!(rand(100); markersize=6, color=:blue))]),
  PlotExample("Heatmaps",
              "",
              [:(heatmap(randn(10000),randn(10000); nbins=100))]),
  PlotExample("Line types",
              "",
              [:(types = intersect(supportedTypes(), [:line, :path, :steppre, :steppost, :sticks, :scatter])),
                  :(n = length(types)),
                  :(x = Vector[sort(rand(20)) for i in 1:n]),
                  :(y = rand(20,n)),
                  :(plot(x, y; linetypes=types, labels=map(string,types)))]),
  PlotExample("Line styles",
              "",
              [:(styles = setdiff(supportedStyles(), [:auto])), :(plot(cumsum(randn(20,length(styles)),1); linestyle=:auto, labels=map(string,styles), width=5))]),
  PlotExample("Marker types",
              "",
              [:(markers = setdiff(supportedMarkers(), [:none,:auto])), :(scatter(0.5:9.5, [fill(i-0.5,10) for i=length(markers):-1:1]; marker=:auto, labels=map(string,markers), markersize=10))]),
  PlotExample("Bar",
              "x is the midpoint of the bar. (todo: allow passing of edges instead of midpoints)",
              [:(bar(randn(1000)))]),
  PlotExample("Histogram",
              "note: fillto isn't supported on all backends",
              [:(histogram(randn(1000); nbins=50, fillto=20))]),
  PlotExample("Subplots",
              """
                subplot and subplot! are distinct commands which create many plots and add series to them in a circular fashion.
                You can define the layout with keyword params... either set the number of plots `n` (and optionally number of rows `nr` or 
                number of columns `nc`), or you can set the layout directly with `layout`.  

                Note: Gadfly is not very friendly here, and although you can create a plot and save a PNG, I haven't been able to actually display it.
              """,
              [:(subplot(randn(100,5); layout=[1,1,3], linetypes=[:line,:hist,:scatter,:step,:bar], nbins=10, legend=false))]),
  PlotExample("Adding to subplots",
              "Note here the automatic grid layout, as well as the order in which new series are added to the plots.",
              [:(subplot(randn(100,5); n=4))]),
  PlotExample("",
              "",
              [:(subplot!(randn(100,3)))]),
  PlotExample("Open/High/Low/Close",
              "Create an OHLC chart.  Pass in a vector of 4-tuples as your `y` argument.  Adjust the tick width with arg `markersize`.",
              [:(n=20), :(hgt=rand(n)+1), :(bot=randn(n)), :(openpct=rand(n)), :(closepct=rand(n)), :(y = [(openpct[i]*hgt[i]+bot[i], bot[i]+hgt[i], bot[i], closepct[i]*hgt[i]+bot[i]) for i in 1:n]), :(ohlc(y; markersize=8))]),

  
]


function createStringOfMarkDownCodeValues(arr, prefix = "")
  string("`", prefix, join(arr, "`, `$prefix"), "`")
end
createStringOfMarkDownSymbols(arr) = createStringOfMarkDownCodeValues(arr, ":")


function generate_markdown(pkgname::Symbol)

  # set up the plotter, and don't show the plots by default
  pkg = plotter!(pkgname)
  # plotDefault!(:show, false)

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

  write(md, "### Initialize\n\n```julia\nusing Plots\n$(pkgname)!()\n```\n\n")


  for (i,example) in enumerate(examples)

    try

      # we want to always produce consistent results
      srand(1234)

      # run the code
      map(eval, example.exprs)

      # save the png
      imgname = "$(pkgname)_example_$i.png"

      # NOTE: uncomment this to overwrite the images as well
      # savepng("$IMGDIR/$pkgname/$imgname")

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
function test_example(pkgname::Symbol, idx::Int)
  println("Testing plot: $pkgname:$idx:$(examples[idx].header)")
  plotter!(pkgname)
  plotter()
  map(eval, examples[idx].exprs)
  plt = currentPlot()
  display(plt)
  plt
end

# generate all plots and create a dict mapping idx --> plt
function test_all_examples(pkgname::Symbol)
  plts = Dict()
  for i in 1:length(examples)
    if examples[i].header == "Subplots" && !subplotSupported()
      break
    end

    try
      plt = test_example(pkgname, i)
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
# fillto          # fillto value for area plots
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
    :ohlc => "Open/High/Low/Close chart (expects y is vector of 4-tuples)",
  )

function buildReadme()
  readme = readall("$DOCDIR/readme_template.md")

  # build keyword arg table
  table = "Keyword | Default | Type | Aliases \n---- | ---- | ---- | ----\n"
  for d in (Plots._seriesDefaults, Plots._plotDefaults)
    for k in sort(collect(keys(d)))
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
end

# run it!
# note: generate separately so it's easy to comment out
# @osx_only generate_markdown(:unicodeplots)
# generate_markdown(:qwt)
# generate_markdown(:gadfly)
# generate_markdown(:pyplot)
# generate_markdown(:immerse)
# generate_markdown(:winston)


end # module

