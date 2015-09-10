
module PlotExamples

using Plots

const DOCDIR = Pkg.dir("Plots") * "/docs"

doc"""
Holds all data needed for a documentation example... header, description, and plotting expression (Expr)
"""
type PlotExample
  header::String
  desc::String
  expr::Expr
end

examples = PlotExample[
  PlotExample("Lines",
              "A simple line plot of the 3 columns.",
              :(plot(rand(100,3)))),
  PlotExample("Functions",
              "Plot multiple functions",
              :(plot(0:0.01:4π, [sin,cos]))),
  PlotExample("Global",
              "Change the guides/background without a separate call.",
              :(plot(rand(10); title="TITLE", xlabel="XLABEL", ylabel="YLABEL", background_color=:red))),
  PlotExample("Vectors",
              "Plot multiple series with different numbers of points.",
              :(plot(Vector[rand(10), rand(20)]; marker=:ellipse, markersize=8))),
  PlotExample("Vectors w/ pluralized args",
              "Mix arguments that apply to all series with arguments unique to each series.",
              :(plot(Vector[rand(10), rand(20)]; marker=:ellipse, markersize=8, markercolors=[:red,:blue]))),
]


function generate_markdown(modname)
  plotter!(modname)
  
end

# run it!
map(generate_markdown, (:qwt, :gadfly))


end # module

