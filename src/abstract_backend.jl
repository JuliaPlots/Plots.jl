const _plots_project         = Pkg.Types.read_package(normpath(@__DIR__, "..", "Project.toml"))
const _current_plots_version = _plots_project.version
const _plots_compats         = _plots_project.compat

const _backendSymbol        = Dict{DataType,Symbol}(NoBackend => :none)
const _backendType          = Dict{Symbol,DataType}(:none => NoBackend)
const _backend_packages     = (gr = :GR, unicodeplots = :UnicodePlots, pgfplotsx = :PGFPlotsX, pythonplot = :PythonPlot, plotly = nothing, plotlyjs = :PlotlyJS, inspectdr = :InspectDR, gaston = :Gaston, hdf5 = :HDF5)
const _initialized_backends = Set{Symbol}()
const _backends             = keys(_backend_packages)

const _plots_deps = let toml = Pkg.TOML.parsefile(normpath(@__DIR__, "..", "Project.toml"))
    merge(toml["deps"], toml["extras"])
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

"""
Returns the current plotting package name.  Initializes package on first call.
"""
backend() = CURRENT_BACKEND.pkg

"Returns a list of supported backends"
backends() = _backends

backend_name() = CURRENT_BACKEND.sym
_backend_instance(sym::Symbol)::AbstractBackend = _backendType[sym]()

backend_package_name(sym::Symbol = backend_name()) = _backend_packages[sym]

# Traits to be implemented by the extensions
backend_name(::AbstractBackend) = @info "`backend_name(::Backend) not implemented."
backend_package_name(::AbstractBackend) =
    @info "`backend_package_name(::Backend) not implemented."

initialized(sym::Symbol) = sym ∈ _initialized_backends

"""
Set the plot backend.
"""
function backend(pkg::AbstractBackend)
    sym = backend_name(pkg)
    if !initialized(sym)
        _initialize_backend(pkg)
        push!(_initialized_backends, sym)
    end
    CURRENT_BACKEND.sym = sym
    CURRENT_BACKEND.pkg = pkg
    pkg
end

backend(sym::Symbol) =
    if sym in _backends
        if initialized(sym)
            backend(_backend_instance(sym))
        else
            name = backend_package_name(sym)
            @warn "`:$sym` is not initialized, import it first to trigger the extension --- e.g. $(name === nothing ? '`' : string("`import ", name, ";")) $sym()`."
            backend()
        end
    else
        error("Unsupported backend $sym")
    end

function get_backend_module(name::Symbol)
    ext_name = Symbol("Plots", name, "Ext")
    ext = Base.get_extension(@__MODULE__, ext_name)
    if !isnothing(ext)
        module_name = ext
        # Concrete as opposed to abstract
        ConcreteBackend = ext.get_concrete_backend()
        return (module_name, ConcreteBackend)
    else
        @error "Extension $name is not loaded yet, run `import $name` to load it"
        return nothing
    end
end

# -- Create backend init functions by hand as the corresponding structs do not
# exist yet

for be in _backends
    @eval begin
        function $be(; kw...)
            default(; reset = false, kw...)
            backend(Symbol($be))
        end
        export $be
    end
end

# ---------------------------------------------------------
# create the various `is_xxx_supported` and `supported_xxxs` methods
# these methods should be overloaded (dispatched) by each backend in its init_code
for s in (:attr, :seriestype, :marker, :style, :scale)
    f1 = Symbol("is_", s, "_supported")
    f2 = Symbol("supported_", s, "s")
    @eval begin
        $f1(::AbstractBackend, $s) = false
        $f1(be::AbstractBackend, $s::AbstractVector) = all(v -> $f1(be, v), $s)
        $f1($s) = $f1(backend(), $s)
        $f2() = $f2(backend())
    end
end
# -----------------------------------------------------------------------------

should_warn_on_unsupported(::AbstractBackend) = _plot_defaults[:warn_on_unsupported]

const _already_warned = Dict{Symbol,Set{Symbol}}()
function warn_on_unsupported_attrs(pkg::AbstractBackend, plotattributes)
    _to_warn = Set{Symbol}()
    bend = backend_name(pkg)
    already_warned = get!(_already_warned, bend) do
        Set{Symbol}()
    end
    extra_kwargs = Dict{Symbol,Any}()
    for k in Plots.explicitkeys(plotattributes)
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
