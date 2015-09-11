
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
              "Plot multiple functions",
              [:(plot(0:0.01:4π, [sin,cos]))]),
  PlotExample("Global",
              "Change the guides/background without a separate call.",
              [:(plot(rand(10); title="TITLE", xlabel="XLABEL", ylabel="YLABEL", background_color = RGB(0.5,0.5,0.5)))]),
  PlotExample("Two-axis",
              "Use the `axis` or `axiss` arguments.\n\nNote: This is only supported with Qwt right now",
              [:(plot(Vector[randn(100), randn(100)*100]; axiss = [:left,:right]))]),
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
              [:(heatmap(randn(10000),randn(10000); nbins=200))]),
  PlotExample("Lots of line types",
              "Options: (:line, :step, :stepinverted, :sticks, :dots, :none, :heatmap, :hexbin, :hist, :bar)  \nNote: some may not work with all backends",
              [:(plot(rand(20,4); linetypes=[:line, :step, :sticks, :dots]))]),
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
              [:(subplot(randn(100,5); layout=[1,1,3], linetypes=[:line,:hist,:dots,:step,:bar], nbins=10, legend=false))]),
  PlotExample("Adding to subplots",
              "Note here the automatic grid layout, as well as the order in which new series are added to the plots.",
              [:(subplot(randn(100,5); n=4))]),
  PlotExample("",
              "",
              [:(subplot!(randn(100,3)))]),

  
]


function generate_markdown(pkgname::Symbol)

  # set up the plotter, and don't show the plots by default
  plotter!(pkgname)
  plotDefault!(:show, false)

  # open the markdown file
  md = open("$DOCDIR/$(pkgname)_examples.md", "w")

  for (i,example) in enumerate(examples)

    try

      # run the code
      map(eval, example.exprs)

      # save the png
      imgname = "$(pkgname)_example_$i.png"
      savepng("$IMGDIR/$imgname")

      # write out the header, description, code block, and image link
      write(md, "### $(example.header)\n\n")
      write(md, "$(example.desc)\n\n")
      write(md, "```julia\n$(join(map(string, example.exprs), "\n"))\n```\n\n")
      write(md, "![](../img/$imgname)\n\n")

    catch ex
      # TODO: put error info into markdown?
      warn("Example $pkgname:$i failed with: $ex")
    end

    #
  end

  close(md)

end

# run it!
map(generate_markdown, (:qwt, :gadfly))


end # module

