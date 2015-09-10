
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
  expr::Expr
end


# the examples we'll run for each
const examples = PlotExample[
  PlotExample("Lines",
              "A simple line plot of the 3 columns.",
              :(plot(rand(100,3)))),
  PlotExample("Functions",
              "Plot multiple functions",
              :(plot(0:0.01:4π, [sin,cos]))),
  PlotExample("Global",
              "Change the guides/background without a separate call.",
              :(plot(rand(10); title="TITLE", xlabel="XLABEL", ylabel="YLABEL", background_color = RGB(0.5, 0.5, 0.5)))),
  PlotExample("Vectors",
              "Plot multiple series with different numbers of points.",
              :(plot(Vector[rand(10), rand(20)]; marker=:ellipse, markersize=8))),
  PlotExample("Vectors w/ pluralized args",
              "Mix arguments that apply to all series with arguments unique to each series.",
              :(plot(Vector[rand(10), rand(20)]; marker=:ellipse, markersize=8, markercolors=[:red,:blue]))),
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
      eval(example.expr)

      # save the png
      imgname = "$(pkgname)_example_$i.png"
      savepng("$IMGDIR/$imgname")

      # write out the header, description, code block, and image link
      write(md, "### $(example.header)\n\n")
      write(md, "$(example.desc)\n\n")
      write(md, "```julia\n$(string(example.expr))\n```\n\n")
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

