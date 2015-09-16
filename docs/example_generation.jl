
module PlotExamples

using Plots
using Colors

const DOCDIR = Pkg.dir("Plots") * "/docs"
const IMGDIR = Pkg.dir("Plots") * "/img"

doc"""
Holds all data needed for a documentation example... header, description, and plotting expression (Expr)
"""
type PlotExample
  header::String
  desc::String
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
              [:(plot(sin, x->sin(2x), 0, 2π))]),
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
  PlotExample("Suported line types",
              "All options: (:line, :orderedline, :step, :stepinverted, :sticks, :scatter, :none, :heatmap, :hexbin, :hist, :bar)",
              [:(types = intersect(supportedTypes(), [:line, :step, :stepinverted, :sticks, :scatter])),
                  :(n = length(types)),
                  :(x = Vector[sort(rand(20)) for i in 1:n]),
                  :(y = rand(20,n)),
                  :(plot(x, y; linetypes=types, labels=map(string,types)))]),
  PlotExample("Supported line styles",
              "All options: (:solid, :dash, :dot, :dashdot, :dashdotdot)",
              [:(styles = setdiff(supportedStyles(), [:auto])), :(plot(rand(20,length(styles)); linestyle=:auto, labels=map(string,styles)))]),
  PlotExample("Supported marker types",
              "All options: (:none, :auto, :ellipse, :rect, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star1, :star2, :hexagon)",
              [:(markers = setdiff(supportedMarkers(), [:none,:auto])), :(plot([fill(i,10) for i=1:length(markers)]; marker=:auto, labels=map(string,markers), markersize=10))]),
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

# run it!
# note: generate separately so it's easy to comment out
# @osx_only generate_markdown(:unicodeplots)
# generate_markdown(:qwt)
# generate_markdown(:gadfly)
# generate_markdown(:pyplot)
# generate_markdown(:immerse)
# generate_markdown(:winston)


end # module

