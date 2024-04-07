const _default_supported_syms = :attr, :seriestype, :marker, :style, :scale

_f1_sym(sym::Symbol) = Symbol("is_$(sym)_supported")
_f2_sym(sym::Symbol) = Symbol("supported_$(sym)s")

struct NoBackend <: AbstractBackend end

backend_name(::NoBackend) = :none
should_warn_on_unsupported(::NoBackend) = false

for sym in _default_supported_syms
    @eval begin
        $(_f1_sym(sym))(::NoBackend, $sym::Symbol) = true
        $(_f2_sym(sym))(::NoBackend) = Commons.$(Symbol("_all_$(sym)s"))
    end
end

_display(::Plot{NoBackend}) =
    @warn "No backend activated yet. Load the backend library and call the activation function to do so.\nE.g. `import GR; gr()` activates the GR backend."

const _backendSymbol        = Dict{DataType,Symbol}(NoBackend => :none)
const _backendType          = Dict{Symbol,DataType}(:none => NoBackend)
const _backend_packages     = (unicodeplots = :UnicodePlots, pythonplot = :PythonPlot, pgfplotsx = :PGFPlotsX, plotlyjs = :PlotlyJS, gaston = :Gaston, plotly = nothing, none = nothing, hdf5 = :HDF5, gr = :GR)
const _supported_backends   = keys(_backend_packages)
const _initialized_backends = Set([:none])

function _check_installed(pkg::Union{Module,AbstractString,Symbol}; warn = true)
    name = Symbol(lowercase(string(pkg)))
    if warn && !haskey(_backend_packages, name)
        @warn "backend `$name` is not compatible with `PlotsBase`."
        return
    end
    # lowercase -> CamelCase, falling back to the given input for `PlotlyBase` ...
    pkg_str = string(get(_backend_packages, name, pkg))
    pkg_str == "Plotly" && (pkg_str *= "Base")  # FIXME: `PlotsBase` inconsistency, `plotly` should be named `plotlybase`
    # check supported
    if warn && !haskey(_compat, pkg_str)
        @warn "package `$pkg_str` is not compatible with `PlotsBase`."
        return
    end
    # check installed
    version = if (pkg_id = Base.identify_package(pkg_str)) ≡ nothing
        nothing
    else
        get(Pkg.dependencies(), pkg_id.uuid, (; version = nothing)).version
    end
    version ≡ nothing && @warn "`package $pkg_str` is not installed."
    version
end

_create_backend_figure(::Plot) = nothing
_initialize_subplot(::Plot, ::Subplot) = nothing

_series_added(::Plot, ::Series) = nothing
_series_updated(::Plot, ::Series) = nothing

_before_layout_calcs(plt::Plot) = nothing

title_padding(sp::Subplot) = sp[:title] == "" ? 0mm : sp[:titlefontsize] * pt
guide_padding(axis::Axis) = axis[:guide] == "" ? 0mm : axis[:guidefontsize] * pt

closeall(::AbstractBackend) = nothing

mutable struct CurrentBackend
    name::Symbol
    instance::AbstractBackend
end

@inline backend_type(name::Symbol) = _backendType[name]
@inline backend_instance(name::Symbol) = backend_type(name)()
@inline backend(type::Type{<:AbstractBackend}) = backend(type())

CurrentBackend(name::Symbol) = CurrentBackend(name, backend_instance(name))

const CURRENT_BACKEND = CurrentBackend(:none)

"returns the current plotting package backend. Initializes package on first call."
@inline backend() = CURRENT_BACKEND.instance

"returns a list of supported backends."
@inline backends() = _supported_backends

@inline backend_name() = CURRENT_BACKEND.name
@inline backend_package_name(name::Symbol = backend_name()) =
    get(_backend_packages, name, nothing)

# Traits to be implemented by the extensions
backend_name(::AbstractBackend) = @info "`backend_name(::Backend) not implemented."
backend_package_name(::AbstractBackend) =
    @info "`backend_package_name(::Backend) not implemented."

"set the plot backend."
function backend(instance::AbstractBackend)
    name = backend_name(instance)
    if name ∈ _supported_backends
        CURRENT_BACKEND.name = name
        CURRENT_BACKEND.instance = instance
    else
        @error "Unsupported backend $name"
    end
    instance
end

backend(name::Symbol) =
    if name ∈ _supported_backends
        if name ∈ _initialized_backends
            backend(backend_type(name))
        else
            pkg_name = backend_package_name(name)
            @warn "`:$name` is not initialized, import it first to trigger the extension --- e.g. `$(pkg_name ≡ nothing ? "" : "import $pkg_name; ")$name()`."
            backend()
        end
    else
        @error "Unsupported backend $name"
    end

function get_backend_module(pkg_name::Symbol)
    ext = Base.get_extension(@__MODULE__, Symbol("$(pkg_name)Ext"))
    concrete_backend = if ext ≡ nothing
        @error "Extension $pkg_name is not loaded yet, run `import $pkg_name` to load it"
        nothing
    else
        ext.get_concrete_backend()
    end
    ext, concrete_backend
end

# create backend init functions by hand as the corresponding structs do not exist yet
for be in _supported_backends
    @eval begin
        function $be(; kw...)
            default(; reset = false, kw...)
            backend(Symbol($be))
        end
        export $be
    end
end

# create the various `is_xxx_supported` and `supported_xxxs` methods
# these methods should be overloaded (dispatched) by each backend in its init_code
for sym in _default_supported_syms
    f1 = _f1_sym(sym)
    f2 = _f2_sym(sym)
    @eval begin
        $f1(::AbstractBackend, $sym) = false
        $f1(be::AbstractBackend, $sym::AbstractVector) = all(v -> $f1(be, v), $sym)
        $f1($sym) = $f1(backend(), $sym)
        $f2() = $f2(backend())
    end
end

function backend_defines(be_type::Symbol, be::Symbol)
    be_sym = QuoteNode(be)
    blk = Expr(
        :block,
        :(get_concrete_backend() = $be_type),
        :(PlotsBase.backend_name(::$be_type)::Symbol = $be_sym),
        :(
            PlotsBase.backend_package_name(::$be_type)::Symbol =
                PlotsBase.backend_package_name($be_sym)
        ),
    )
    #=
    Overload (dispatch) abstract `is_xxx_supported` and `supported_xxxs` methods,
    results in:
        PlotsBase.is_attr_supported(::GRbackend, attrname) -> Bool
        ...
        PlotsBase.supported_attrs(::GRbackend) -> ::Vector{Symbol}
        ...
        PlotsBase.supported_scales(::GRbackend) -> ::Vector{Symbol}
    =#
    for sym in _default_supported_syms
        be_syms = Symbol("_$(be)_$(sym)s")
        push!(
            blk.args,
            :(PlotsBase.$(_f1_sym(sym))(::$be_type, $sym::Symbol)::Bool = $sym in $be_syms),
            :(PlotsBase.$(_f2_sym(sym))(::$be_type)::Vector = sort!(collect($be_syms))),
        )
    end
    blk
end

"extra init step for an extension"
extension_init(::AbstractBackend) = nothing

"generate extension `__init__` function, and common defines"
macro extension_static(be_type, be)
    be_sym = QuoteNode(be)
    quote
        $(PlotsBase.backend_defines(be_type, be))
        function __init__()
            PlotsBase._backendType[$be_sym] = $be_type
            PlotsBase._backendSymbol[$be_type] = $be_sym
            push!(PlotsBase._initialized_backends, $be_sym)
            ccall(:jl_generating_output, Cint, ()) == 1 && return
            PlotsBase.extension_init($be_type())
            @debug "Initialized $be_type backend in PlotsBase; run `$be()` to activate it."
        end
    end |> esc
end

should_warn_on_unsupported(::AbstractBackend) = _plot_defaults[:warn_on_unsupported]

const _already_warned = Dict{Symbol,Set{Symbol}}()
function warn_on_unsupported_attrs(pkg::AbstractBackend, plotattributes)
    _to_warn = Set{Symbol}()
    bend = backend_name(pkg)
    already_warned = get!(() -> Set{Symbol}(), _already_warned, bend)
    extra_kwargs = Dict{Symbol,Any}()
    for k in PlotsBase.explicitkeys(plotattributes)
        (is_attr_supported(pkg, k) && k ∉ keys(Commons._deprecated_attributes)) && continue
        k in Commons._suppress_warnings && continue
        if ismissing(default(k))
            extra_kwargs[k] = pop_kw!(plotattributes, k)
        elseif plotattributes[k] != default(k)
            k in already_warned || push!(_to_warn, k)
        end
    end

    if !isempty(_to_warn) &&
       get(plotattributes, :warn_on_unsupported, should_warn_on_unsupported(pkg))
        for k in sort!(collect(_to_warn))
            push!(already_warned, k)
            if k in keys(Commons._deprecated_attributes)
                @warn """
                Keyword argument `$k` is deprecated.
                Please use `$(Commons._deprecated_attributes[k])` instead.
                """
            else
                @warn "Keyword argument $k not supported with $pkg.  Choose from: $(join(supported_attrs(pkg), ", "))"
            end
        end
    end
    extra_kwargs
end

function warn_on_unsupported(pkg::AbstractBackend, plotattributes)
    get(plotattributes, :warn_on_unsupported, should_warn_on_unsupported(pkg)) || return
    is_seriestype_supported(pkg, plotattributes[:seriestype]) ||
        @warn "seriestype $(plotattributes[:seriestype]) is unsupported with $pkg. Choose from: $(supported_seriestypes(pkg))"
    is_style_supported(pkg, plotattributes[:linestyle]) ||
        @warn "linestyle $(plotattributes[:linestyle]) is unsupported with $pkg. Choose from: $(supported_styles(pkg))"
    is_marker_supported(pkg, plotattributes[:markershape]) ||
        @warn "markershape $(plotattributes[:markershape]) is unsupported with $pkg. Choose from: $(supported_markers(pkg))"
end

function warn_on_unsupported_scales(pkg::AbstractBackend, plotattributes::AKW)
    get(plotattributes, :warn_on_unsupported, should_warn_on_unsupported(pkg)) || return
    for k in (:xscale, :yscale, :zscale, :scale)
        haskey(plotattributes, k) || continue
        v = plotattributes[k]
        if !all(is_scale_supported.(Ref(pkg), v))
            @warn """
            scale $v is unsupported with $pkg.
            Choose from: $(supported_scales(pkg))
            """
        end
    end
end
