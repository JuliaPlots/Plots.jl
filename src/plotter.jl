

immutable GadflyPackage       <: PlottingPackage end
immutable ImmersePackage      <: PlottingPackage end
immutable PyPlotPackage       <: PlottingPackage end
immutable QwtPackage          <: PlottingPackage end
immutable UnicodePlotsPackage <: PlottingPackage end
immutable WinstonPackage      <: PlottingPackage end
immutable BokehPackage        <: PlottingPackage end
immutable PlotlyPackage       <: PlottingPackage end
immutable GRPackage           <: PlottingPackage end
immutable GLVisualizePackage  <: PlottingPackage end
immutable NoPackage           <: PlottingPackage end

typealias GadflyOrImmerse @compat(Union{GadflyPackage, ImmersePackage})

export
  gadfly,
  immerse,
  pyplot,
  qwt,
  unicodeplots,
  bokeh,
  plotly,
  gr,
  glvisualize
  # winston

gadfly()        = backend(:gadfly)
immerse()       = backend(:immerse)
pyplot()        = backend(:pyplot)
qwt()           = backend(:qwt)
unicodeplots()  = backend(:unicodeplots)
bokeh()         = backend(:bokeh)
plotly()        = backend(:plotly)
gr()            = backend(:gr)
glvisualize()   = backend(:glvisualize)
# winston()       = backend(:winston)

backend_name(::GadflyPackage)       = :gadfly
backend_name(::ImmersePackage)      = :immerse
backend_name(::PyPlotPackage)       = :pyplot
backend_name(::UnicodePlotsPackage) = :unicodeplots
backend_name(::QwtPackage)          = :qwt
backend_name(::BokehPackage)        = :bokeh
backend_name(::PlotlyPackage)       = :plotly
backend_name(::GRPackage)           = :gr
backend_name(::GLVisualizePackage)  = :glvisualize
backend_name(::NoPackage)           = :none

include("backends/supported.jl")

include("backends/qwt.jl")
include("backends/gadfly.jl")
include("backends/unicodeplots.jl")
include("backends/pyplot.jl")
include("backends/immerse.jl")
include("backends/winston.jl")

include("backends/web.jl")
include("backends/bokeh.jl")
include("backends/plotly.jl")
include("backends/gr.jl")

include("backends/glvisualize.jl")


# ---------------------------------------------------------


plot(pkg::PlottingPackage; kw...) = error("plot($pkg; kw...) is not implemented")
plot!(pkg::PlottingPackage, plt::Plot; kw...) = error("plot!($pkg, plt; kw...) is not implemented")
_update_plot(pkg::PlottingPackage, plt::Plot, d::Dict) = error("_update_plot($pkg, plt, d) is not implemented")
# Base.display(pkg::PlottingPackage, plt::Plot) = error("display($pkg, plt) is not implemented")

_update_plot_pos_size{P<:PlottingPackage}(plt::PlottingObject{P}, d::Dict) = nothing #error("_update_plot_pos_size(plt,d) is not implemented for $P")

subplot(pkg::PlottingPackage; kw...) = error("subplot($pkg; kw...) is not implemented")
subplot!(pkg::PlottingPackage, subplt::Subplot; kw...) = error("subplot!($pkg, subplt; kw...) is not implemented")
# Base.display(pkg::PlottingPackage, subplt::Subplot) = error("display($pkg, subplt) is not implemented")

# ---------------------------------------------------------


const BACKENDS = [:qwt, :gadfly, :unicodeplots, :pyplot, :immerse, :bokeh, :plotly, :gr]
const INITIALIZED_BACKENDS = Set{Symbol}()
backends() = BACKENDS


function backendInstance(sym::Symbol)
  sym == :qwt && return QwtPackage()
  sym == :gadfly && return GadflyPackage()
  sym == :unicodeplots && return UnicodePlotsPackage()
  sym == :pyplot && return PyPlotPackage()
  sym == :immerse && return ImmersePackage()
  sym == :winston && return WinstonPackage()
  sym == :bokeh && return BokehPackage()
  sym == :plotly && return PlotlyPackage()
  sym == :gr && return GRPackage()
  sym == :glvisualize && return GLVisualizePackage()
  sym == :none && return NoPackage()
  error("Unsupported backend $sym")
end


type CurrentBackend
  sym::Symbol
  pkg::PlottingPackage
end
CurrentBackend(sym::Symbol) = CurrentBackend(sym, backendInstance(sym))

# ---------------------------------------------------------

function pickDefaultBackend()
  for pkgstr in ("PyPlot", "Gr", "Immerse", "Qwt", "Gadfly", "UnicodePlots", "Bokeh", "GLVisualize")
    if Pkg.installed(pkgstr) != nothing
      return backend(symbol(lowercase(pkgstr)))
    end
  end
  backend(:plotly)
end


# ---------------------------------------------------------

"""
Returns the current plotting package name.  Initializes package on first call.
"""
function backend()

  global CURRENT_BACKEND
  if CURRENT_BACKEND.sym == :none
    pickDefaultBackend()
  end

  currentBackendSymbol = CURRENT_BACKEND.sym
  if !(currentBackendSymbol in INITIALIZED_BACKENDS)

    # initialize
    println("[Plots.jl] Initializing backend: ", CURRENT_BACKEND.sym)
    if currentBackendSymbol == :qwt
      try
        @eval import Qwt
        @eval export Qwt
      catch err
        warn("Couldn't import Qwt.  Install it with: Pkg.clone(\"https://github.com/tbreloff/Qwt.jl.git\")\n  (Note: also requires pyqt and pyqwt).")
        rethrow(err)
      end

    elseif currentBackendSymbol == :gadfly
      try
        @eval import Gadfly, Compose
        @eval export Gadfly, Compose
        @eval include(joinpath(Pkg.dir("Plots"), "src", "backends", "gadfly_shapes.jl"))
      catch err
        warn("Couldn't import Gadfly.  Install it with: Pkg.add(\"Gadfly\").")
        rethrow(err)
      end

    elseif currentBackendSymbol == :unicodeplots
      try
        @eval import UnicodePlots
        @eval export UnicodePlots
      catch err
        warn("Couldn't import UnicodePlots.  Install it with: Pkg.add(\"UnicodePlots\").")
        rethrow(err)
      end

    elseif currentBackendSymbol == :pyplot
      try
        @eval import PyPlot
        @eval export PyPlot
        @eval const pycolors = PyPlot.pywrap(PyPlot.pyimport("matplotlib.colors"))
        @eval const pypath = PyPlot.pywrap(PyPlot.pyimport("matplotlib.path"))
        @eval const mplot3d = PyPlot.pywrap(PyPlot.pyimport("mpl_toolkits.mplot3d"))
        # @eval const pycolorbar = PyPlot.pywrap(PyPlot.pyimport("matplotlib.colorbar"))
        if !isa(Base.Multimedia.displays[end], Base.REPL.REPLDisplay)
          PyPlot.ioff()  # stops wierd behavior of displaying incomplete graphs in IJulia

          # # TODO: how the hell can I use PyQt4??
          # "pyqt4"=>:qt_pyqt4
          # PyPlot.backend[1] = "pyqt4"
          # PyPlot.gui[1] = :qt_pyqt4
          # PyPlot.switch_backend("Qt4Agg")

          # only turn on the gui if we want it
          if PyPlot.gui != :none
            PyPlot.pygui(true)
          end

        end
      catch err
        warn("Couldn't import PyPlot.  Install it with: Pkg.add(\"PyPlot\").")
        rethrow(err)
      end

    elseif currentBackendSymbol == :immerse
      try
        @eval import Immerse, Gadfly, Compose, Gtk
        @eval export Immerse, Gadfly, Compose, Gtk
        @eval include(joinpath(Pkg.dir("Plots"), "src", "backends", "gadfly_shapes.jl"))
      catch err
        # error("Couldn't import Immerse.  Install it with: Pkg.add(\"Immerse\").\n   Error: ", err)
        warn("Couldn't import Immerse.  Install it with: Pkg.add(\"Immerse\").")
        rethrow(err)
      end

    elseif currentBackendSymbol == :bokeh
      try
        @eval import Bokeh
        @eval export Bokeh
      catch err
        warn("Couldn't import Bokeh.  Install it with: Pkg.add(\"Bokeh\").")
        rethrow(err)
      end

    elseif currentBackendSymbol == :plotly
      try
        @eval begin
          import JSON
          JSON._print(io::IO, state::JSON.State, dt::Union{Date,DateTime}) = print(io, '"', dt, '"')

          ############################
          # borrowed from https://github.com/spencerlyon2/Plotlyjs.jl/blob/master/src/display.jl
          _js_path = joinpath(Pkg.dir("Plots"), "deps", "plotly-latest.min.js")

          # if we're in IJulia call setupnotebook to load js and css
          if isijulia()
              # the first script is some hack I needed to do in order for the notebook
              # to not complain about Plotly being undefined
              display("text/html", """
                  <script type="text/javascript">
                      require=requirejs=define=undefined;
                  </script>
                  <script type="text/javascript">
                      $(open(readall, _js_path, "r"))
                  </script>
               """)
              # display("text/html", "<p>Plotly javascript loaded.</p>")
          end
          # end borrowing (thanks :)
          ###########################

          # try
          #   include(joinpath(Pkg.dir("Plots"), "src", "backends", "plotly_blink.jl"))
          # catch err
          #   warn("Error including Plotlyjs: $err\n  Note: Will fall back to built-in display.")
          # end

        end
      catch err
        warn("Couldn't setup Plotly")
        rethrow(err)
      end

    elseif currentBackendSymbol == :gr
      try
        @eval import GR
      catch err
        warn("Couldn't import GR.  Install it with: Pkg.add(\"GR\").")
      end

    elseif currentBackendSymbol == :glvisualize
      try
        @eval import GLVisualize
        @eval export GLVisualize
      catch err
        warn("Couldn't setup GLVisualize")
        rethrow(err)
      end

    elseif currentBackendSymbol == :winston
      warn("Winston support is deprecated and broken.  Try another backend: $BACKENDS")
      try
        @eval ENV["WINSTON_OUTPUT"] = "gtk"
        @eval import Winston, Gtk
        @eval export Winston, Gtk
      catch err
        warn("Couldn't import Winston.  Install it with: Pkg.add(\"Winston\").")
        rethrow(err)
      end

    else
      error("Unknown backend $currentBackendSymbol.  Choose from: $BACKENDS")
    end
    push!(INITIALIZED_BACKENDS, currentBackendSymbol)

  end
  CURRENT_BACKEND.pkg
end

"""
Set the plot backend.  Choose from:  :qwt, :gadfly, :unicodeplots, :immerse, :pyplot
"""
function backend(pkg::PlottingPackage)
  CURRENT_BACKEND.sym = backend_name(pkg)
  CURRENT_BACKEND.pkg = pkg
end

function backend(modname)

  # set the PlottingPackage
  if modname == :qwt
    CURRENT_BACKEND.pkg = QwtPackage()
  elseif modname == :gadfly
    CURRENT_BACKEND.pkg = GadflyPackage()
  elseif modname == :unicodeplots
    CURRENT_BACKEND.pkg = UnicodePlotsPackage()
  elseif modname == :pyplot
    CURRENT_BACKEND.pkg = PyPlotPackage()
  elseif modname == :immerse
    CURRENT_BACKEND.pkg = ImmersePackage()
  elseif modname == :winston
    CURRENT_BACKEND.pkg = WinstonPackage()
  elseif modname == :bokeh
    CURRENT_BACKEND.pkg = BokehPackage()
  elseif modname == :plotly
    CURRENT_BACKEND.pkg = PlotlyPackage()
  elseif modname == :gr
    CURRENT_BACKEND.pkg = GRPackage()
  elseif modname == :glvisualize
    CURRENT_BACKEND.pkg = GLVisualizePackage()
  else
    error("Unknown backend $modname.  Choose from: $BACKENDS")
  end

  # update the symbol
  CURRENT_BACKEND.sym = modname
  # println("[Plots.jl] Switched to backend: ", modname)

  # return the package
  CURRENT_BACKEND.pkg
end
