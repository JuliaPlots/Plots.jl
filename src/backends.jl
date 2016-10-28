
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

include("backends/web.jl")
# include("backends/supported.jl")

# ---------------------------------------------------------

function add_backend(pkg::Symbol)
    info("To do a standard install of $pkg, copy and run this:\n\n")
    println(add_backend_string(_backend_instance(pkg)))
    println()
end
add_backend_string(b::AbstractBackend) = warn("No custom install defined for $(backend_name(b))")

# don't do anything as a default
_create_backend_figure(plt::Plot) = nothing
_prepare_plot_object(plt::Plot) = nothing
_initialize_subplot(plt::Plot, sp::Subplot) = nothing

_series_added(plt::Plot, series::Series) = nothing
_series_updated(plt::Plot, series::Series) = nothing

_before_layout_calcs(plt::Plot) = nothing

title_padding(sp::Subplot) = sp[:title] == "" ? 0mm : sp[:titlefont].pointsize * pt
guide_padding(axis::Axis) = axis[:guide] == "" ? 0mm : axis[:guidefont].pointsize * pt

# account for the size/length/rotation of tick labels
function tick_padding(axis::Axis)
    ticks = get_ticks(axis)
    if ticks == nothing
        0mm
    else
        vals, labs = ticks
        isempty(labs) && return 0mm
        ptsz = axis[:tickfont].pointsize * pt

        # we need to compute the size of the ticks generically
        # this means computing the bounding box and then getting the width/height
        longest_label = maximum(length(lab) for lab in labs)
        labelwidth = 0.8longest_label * ptsz

        # generalize by "rotating" y labels
        rot = axis[:rotation] + (axis[:letter] == :y ? 90 : 0)

        # now compute the generalized "height" after rotation as the "opposite+adjacent" of 2 triangles
        hgt = abs(sind(rot)) * labelwidth + abs(cosd(rot)) * ptsz + 1mm
        hgt
    end
end

# Set the (left, top, right, bottom) minimum padding around the plot area
# to fit ticks, tick labels, guides, colorbars, etc.
function _update_min_padding!(sp::Subplot)
    # TODO: something different when `is3d(sp) == true`
    leftpad   = tick_padding(sp[:yaxis]) + sp[:left_margin]   + guide_padding(sp[:yaxis])
    toppad    = sp[:top_margin]    + title_padding(sp)
    rightpad  = sp[:right_margin]
    bottompad = tick_padding(sp[:xaxis]) + sp[:bottom_margin] + guide_padding(sp[:xaxis])

    # switch them?
    if sp[:xaxis][:mirror]
        bottompad, toppad = toppad, bottompad
    end
    if sp[:yaxis][:mirror]
        leftpad, rightpad = rightpad, leftpad
    end

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

    # # initialize
    # println("[Plots.jl] Initializing backend: ", sym)

    inst = _backend_instance(sym)
    try
      _initialize_backend(inst)
    catch err
      warn("Couldn't initialize $sym.  (might need to install it?)")
      add_backend(sym)
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
    backend()
end

function backend(modname::Symbol)
    warn_on_deprecated_backend(modname)
    CURRENT_BACKEND.sym = modname
    CURRENT_BACKEND.pkg = _backend_instance(modname)
    backend()
end

const _deprecated_backends = [:qwt, :winston, :bokeh, :gadfly, :immerse]

function warn_on_deprecated_backend(bsym::Symbol)
    if bsym in _deprecated_backends
        warn("Backend $bsym has been deprecated.  It may not work as originally intended.")
    end
end



# ---------------------------------------------------------

# these are args which every backend supports because they're not used in the backend code
const _base_supported_args = [
    :color_palette,
    :background_color, :background_color_subplot,
    :foreground_color, :foreground_color_subplot,
    :group,
    :seriestype,
    :seriescolor, :seriesalpha,
    :smooth,
    :xerror, :yerror,
    :subplot,
    :x, :y, :z,
    :show, :size,
    :margin,
    :left_margin,
    :right_margin,
    :top_margin,
    :bottom_margin,
    :html_output_format,
    :layout,
    :link,
    :primary,
    :series_annotations,
    :subplot_index,
    :discrete_values,
    :projection,

]

function merge_with_base_supported(v::AVec)
    v = vcat(v, _base_supported_args)
    for vi in v
        if haskey(_axis_defaults, vi)
            for letter in (:x,:y,:z)
                push!(v, Symbol(letter,vi))
            end
        end
    end
    Set(v)
end



# @init_backend Immerse
# @init_backend Gadfly
@init_backend PyPlot
# @init_backend Qwt
@init_backend UnicodePlots
# @init_backend Winston
# @init_backend Bokeh
@init_backend Plotly
@init_backend PlotlyJS
@init_backend GR
@init_backend GLVisualize
@init_backend PGFPlots

# ---------------------------------------------------------

# create the various `is_xxx_supported` and `supported_xxxs` methods
# by default they pass through to checking membership in `_gr_xxx`
for s in (:attr, :seriestype, :marker, :style, :scale)
    f = Symbol("is_", s, "_supported")
    f2 = Symbol("supported_", s, "s")
    @eval begin
        $f(::AbstractBackend, $s) = false
        $f(bend::AbstractBackend, $s::AbstractVector) = all(v -> $f(bend, v), $s)
        $f($s) = $f(backend(), $s)
        $f2() = $f2(backend())
    end

    for bend in backends()
        bend_type = typeof(_backend_instance(bend))
        v = Symbol("_", bend, "_", s)
        @eval begin
            $f(::$bend_type, $s::Symbol) = $s in $v
            $f2(::$bend_type) = $v
        end
    end
end

# is_subplot_supported(::AbstractBackend) = false
# is_subplot_supported() = is_subplot_supported(backend())
