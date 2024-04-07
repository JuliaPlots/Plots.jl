struct NoBackend <: AbstractBackend end

backend_name(::NoBackend) = :none

for sym in (:attr, :seriestype, :marker, :style, :scale)
    f1 = Symbol("is_$(sym)_supported")
    f2 = Symbol("supported_$(sym)s")
    @eval begin
        $f1(::NoBackend, $sym::Symbol) = true
        $f2(::NoBackend) = $(getproperty(Commons, Symbol("_all_$(sym)s")))
    end
end

_display(::Plot{NoBackend}) =
    @info "No backend activated yet. Load the backend library and call the activation function to do so.\nE.g. `import GR; gr()` activates the GR backend."

const _backendSymbol        = Dict{DataType,Symbol}(NoBackend => :none)
const _backendType          = Dict{Symbol,DataType}(:none => NoBackend)
const _backend_packages     = (gaston = :Gaston, gr = :GR, unicodeplots = :UnicodePlots, pgfplotsx = :PGFPlotsX, pythonplot = :PythonPlot, plotly = nothing, plotlyjs = :PlotlyJS, hdf5 = :HDF5)
const _initialized_backends = Set{Symbol}()
const _supported_backends   = keys(_backend_packages)

function _check_installed(backend::Union{Module,AbstractString,Symbol}; warn = true)
    sym = Symbol(lowercase(string(backend)))
    if warn && !haskey(_backend_packages, sym)
        @warn "backend `$sym` is not compatible with `PlotsBase`."
        return
    end
    # lowercase -> CamelCase, falling back to the given input for `PlotlyBase` ...
    str = string(get(_backend_packages, sym, backend))
    str == "Plotly" && (str *= "Base")  # FIXME: `PlotsBase` inconsistency, `plotly` should be named `plotlybase`
    # check supported
    if warn && !haskey(_compat, str)
        @warn "backend `$str` is not compatible with `PlotsBase`."
        return
    end
    # check installed
    pkg_id = Base.identify_package(str)
    version = if pkg_id ≡ nothing
        nothing
    else
        get(Pkg.dependencies(), pkg_id.uuid, (; version = nothing)).version
    end
    version ≡ nothing && @warn "backend `$str` is not installed."
    version
end

_create_backend_figure(plt::Plot) = nothing
_initialize_subplot(plt::Plot, sp::Subplot) = nothing

_series_added(plt::Plot, series::Series) = nothing
_series_updated(plt::Plot, series::Series) = nothing

_before_layout_calcs(plt::Plot) = nothing

title_padding(sp::Subplot) = sp[:title] == "" ? 0mm : sp[:titlefontsize] * pt
guide_padding(axis::Axis) = axis[:guide] == "" ? 0mm : axis[:guidefontsize] * pt

closeall(::AbstractBackend) = nothing

mutable struct CurrentBackend
    sym::Symbol
    pkg::AbstractBackend
end

@inline backend_type(sym::Symbol) = get(_backendType, sym, NoBackend)
@inline backend_instance(sym::Symbol) = backend_type(sym)()
@inline backend(type::Type{<:AbstractBackend}) = backend(type())

CurrentBackend(sym::Symbol) = CurrentBackend(sym, backend_instance(sym))

"returns the current plotting package name. Initializes package on first call."
@inline backend() = CURRENT_BACKEND.pkg

"returns a list of supported backends."
@inline backends() = _supported_backends


const CURRENT_BACKEND = CurrentBackend(:none)

@inline backend_name() = CURRENT_BACKEND.sym
@inline backend_package_name(sym::Symbol = backend_name()) = get(_backend_packages, sym, nothing)

# Traits to be implemented by the extensions
backend_name(::AbstractBackend) = @info "`backend_name(::Backend) not implemented."
backend_package_name(::AbstractBackend) =
    @info "`backend_package_name(::Backend) not implemented."

initialized(sym::Symbol) = sym ∈ _initialized_backends

"set the plot backend."
function backend(pkg::AbstractBackend)
    sym = backend_name(pkg)
    if sym ∈ _supported_backends
        CURRENT_BACKEND.sym = sym
        CURRENT_BACKEND.pkg = pkg
    else
        @error "Unsupported backend $sym"
    end
    pkg
end

backend(sym::Symbol) =
    if sym ∈ _supported_backends
        if initialized(sym)
            backend(backend_type(sym))
        else
            name = backend_package_name(sym)
            @warn "`:$sym` is not initialized, import it first to trigger the extension --- e.g. $(name ≡ nothing ? '`' : string("`import ", name, ";")) $sym()`."
            backend()
        end
    else
        @error "Unsupported backend $sym"
    end

function get_backend_module(name::Symbol)
    ext = Base.get_extension(@__MODULE__, Symbol(name, "Ext"))
    if !isnothing(ext)
        return ext, ext.get_concrete_backend()
    else
        @error "Extension $name is not loaded yet, run `import $name` to load it"
        return nothing
    end
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
for sym in (:attr, :seriestype, :marker, :style, :scale)
    f1 = Symbol("is_$(sym)_supported")
    f2 = Symbol("supported_$(sym)s")
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
    for sym in (:attr, :seriestype, :marker, :style, :scale)
        be_syms = Symbol("_$(be)_$(sym)s")
        f1 = Symbol("is_$(sym)_supported")
        f2 = Symbol("supported_$(sym)s")
        push!(
            blk.args,
            :(PlotsBase.$f1(::$be_type, $sym::Symbol)::Bool = $sym in $be_syms),
            :(PlotsBase.$f2(::$be_type)::Vector = sort!(collect($be_syms))),
        )
    end
    blk
end

extension_init(::AbstractBackend) = nothing

"""
function __init__()
    PlotsBase._backendType[sym] = GRBackend
    PlotsBase._backendSymbol[GRBackend] = sym
    push!(PlotsBase._initialized_backends, sym)
    @debug "Initializing GR backend in PlotsBase; run `gr()` to activate it."
end
"""
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
    already_warned = get!(_already_warned, bend) do
        Set{Symbol}()
    end
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
        for k in sort(collect(_to_warn))
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
        if haskey(plotattributes, k)
            v = plotattributes[k]
            if !all(is_scale_supported.(Ref(pkg), v))
                @warn """
                scale $v is unsupported with $pkg.
                Choose from: $(supported_scales(pkg))
                """
            end
        end
    end
end
