
immutable NoBackend <: AbstractBackend end

const _backendType = Dict{Symbol, DataType}(:none => NoBackend)
const _backendSymbol = Dict{DataType, Symbol}(NoBackend => :none)
const _backends = Symbol[]
const _initialized_backends = Set{Symbol}()

backends() = _backends
backend_name() = CURRENT_BACKEND.sym
_backend_instance(sym::Symbol) = haskey(_backendType, sym) ? _backendType[sym]() : error("Unsupported backend $sym")

macro init_backend(s)
    str = lowercase(string(s))
    sym = symbol(str)
    T = symbol(string(s) * "Backend")
    esc(quote
        immutable $T <: AbstractBackend end
        export $sym
        $sym(; kw...) = (default(; kw...); backend(symbol($str)))
        backend_name(::$T) = symbol($str)
        push!(_backends, symbol($str))
        _backendType[symbol($str)] = $T
        _backendSymbol[$T] = symbol($str)
        include("backends/" * $str * ".jl")
    end)
end

@init_backend Immerse
@init_backend Gadfly
@init_backend PyPlot
@init_backend Qwt
@init_backend UnicodePlots
@init_backend Winston
@init_backend Bokeh
@init_backend Plotly
@init_backend PlotlyJS
@init_backend GR
@init_backend GLVisualize
@init_backend PGFPlots

include("backends/web.jl")
include("backends/supported.jl")

# ---------------------------------------------------------


plot(pkg::AbstractBackend; kw...)                       = error("plot($pkg; kw...) is not implemented")
plot!(pkg::AbstractBackend, plt::Plot; kw...)           = error("plot!($pkg, plt; kw...) is not implemented")
_update_plot(pkg::AbstractBackend, plt::Plot, d::Dict)  = error("_update_plot($pkg, plt, d) is not implemented")
_update_plot_pos_size{P<:AbstractBackend}(plt::AbstractPlot{P}, d::Dict) = nothing
subplot(pkg::AbstractBackend; kw...)                    = error("subplot($pkg; kw...) is not implemented")
subplot!(pkg::AbstractBackend, subplt::Subplot; kw...)  = error("subplot!($pkg, subplt; kw...) is not implemented")

# ---------------------------------------------------------


type CurrentBackend
  sym::Symbol
  pkg::AbstractBackend
end
CurrentBackend(sym::Symbol) = CurrentBackend(sym, _backend_instance(sym))

# ---------------------------------------------------------

function pickDefaultBackend()
  for pkgstr in ("PyPlot", "Immerse", "Qwt", "Gadfly", "GR", "UnicodePlots", "Bokeh", "GLVisualize")
    if Pkg.installed(pkgstr) != nothing
      return backend(symbol(lowercase(pkgstr)))
    end
  end

  # the default if nothing else is installed
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

  sym = CURRENT_BACKEND.sym
  if !(sym in _initialized_backends)

    # initialize
    println("[Plots.jl] Initializing backend: ", sym)

    inst = _backend_instance(sym)
    try
      _initialize_backend(inst)
    catch err
      warn("Couldn't initialize $sym.  (might need to install it?)")
      rethrow(err)
    end

    push!(_initialized_backends, sym)

  end
  CURRENT_BACKEND.pkg
end

"""
Set the plot backend.
"""
function backend(pkg::AbstractBackend)
  CURRENT_BACKEND.sym = backend_name(pkg)
  CURRENT_BACKEND.pkg = pkg
end

function backend(modname::Symbol)
  CURRENT_BACKEND.sym = modname
  CURRENT_BACKEND.pkg = _backend_instance(modname)
end
