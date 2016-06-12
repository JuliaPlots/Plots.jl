
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
    sym = Symbol(str)
    T = Symbol(string(s) * "Backend")
    esc(quote
        immutable $T <: AbstractBackend end
        export $sym
        $sym(; kw...) = (default(; kw...); backend(Symbol($str)))
        backend_name(::$T) = Symbol($str)
        push!(_backends, Symbol($str))
        _backendType[Symbol($str)] = $T
        _backendSymbol[$T] = Symbol($str)
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
# include("backends/supported.jl")

# ---------------------------------------------------------

# don't do anything as a default
_create_backend_figure(plt::Plot) = nothing
_prepare_plot_object(plt::Plot) = nothing
_initialize_subplot(plt::Plot, sp::Subplot) = nothing

_series_added(plt::Plot, series::Series) = nothing
_series_updated(plt::Plot, series::Series) = nothing

_before_layout_calcs(plt::Plot) = nothing

title_padding(sp::Subplot) = sp[:title] == "" ? 0mm : sp[:titlefont].pointsize * pt
guide_padding(axis::Axis) = axis[:guide] == "" ? 0mm : axis[:guidefont].pointsize * pt

# Set the (left, top, right, bottom) minimum padding around the plot area
# to fit ticks, tick labels, guides, colorbars, etc.
function _update_min_padding!(sp::Subplot)
    leftpad   = 10mm + sp[:left_margin]   + guide_padding(sp[:yaxis])
    toppad    =  2mm + sp[:top_margin]    + title_padding(sp)
    rightpad  =  3mm + sp[:right_margin]
    bottompad =  5mm + sp[:bottom_margin] + guide_padding(sp[:xaxis])
    # @show (leftpad, toppad, rightpad, bottompad)
    sp.minpad = (leftpad, toppad, rightpad, bottompad)
end

_update_plot_object(plt::Plot) = nothing

# ---------------------------------------------------------


type CurrentBackend
  sym::Symbol
  pkg::AbstractBackend
end
CurrentBackend(sym::Symbol) = CurrentBackend(sym, _backend_instance(sym))

# ---------------------------------------------------------

function pickDefaultBackend()
    env_default = get(ENV, "PLOTS_DEFAULT_BACKEND", "")
    if env_default != ""
        try
            Pkg.installed(env_default)  # this will error if not installed
            sym = Symbol(lowercase(env_default))
            if haskey(_backendType, sym)
                return backend(sym)
            else
                warn("You have set PLOTS_DEFAULT_BACKEND=$env_default but it is not a valid backend package.  Choose from:\n\t",
                     join(sort(_backends), "\n\t"))
            end
        catch
            warn("You have set PLOTS_DEFAULT_BACKEND=$env_default but it is not installed.")
        end
    end

    # the ordering/inclusion of this package list is my semi-arbitrary guess at
    # which one someone will want to use if they have the package installed...accounting for
    # features, speed, and robustness
    for pkgstr in ("PyPlot", "GR", "PlotlyJS", "Immerse", "Gadfly", "UnicodePlots")
        if Pkg.installed(pkgstr) != nothing
            return backend(Symbol(lowercase(pkgstr)))
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
    warn_on_deprecated_backend(CURRENT_BACKEND.sym)
    CURRENT_BACKEND.pkg = pkg
end

function backend(modname::Symbol)
    warn_on_deprecated_backend(modname)
    CURRENT_BACKEND.sym = modname
    CURRENT_BACKEND.pkg = _backend_instance(modname)
end

const _deprecated_backends = [:qwt, :winston, :bokeh, :gadfly, :immerse]

function warn_on_deprecated_backend(bsym::Symbol)
    if bsym in _deprecated_backends
        warn("Backend $bsym has been deprecated.  It may not work as originally intended.")
    end
end

# ---------------------------------------------------------

supported_types(::AbstractBackend) = []
supported_styles(::AbstractBackend) = [:solid]
supported_markers(::AbstractBackend) = [:none]
supported_scales(::AbstractBackend) = [:identity]
is_subplot_supported(::AbstractBackend) = false
is_string_supported(::AbstractBackend) = false
nativeImagesSupported(b::AbstractBackend) = :image in supported_types(b)

supported_types() = supported_types(backend())
supported_styles() = supported_styles(backend())
supported_markers() = supported_markers(backend())
supported_scales() = supported_scales(backend())
is_subplot_supported() = is_subplot_supported(backend())
is_string_supported() = is_string_supported(backend())
nativeImagesSupported() = nativeImagesSupported(backend())

# ---------------------------------------------------------
