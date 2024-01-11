struct NoBackend <: AbstractBackend end

const _plots_project         = Pkg.Types.read_package(normpath(@__DIR__, "..", "Project.toml"))
const _current_plots_version = _plots_project.version
const _plots_compats         = _plots_project.compat

const _backendSymbol        = Dict{DataType,Symbol}(NoBackend => :none)
const _backendType          = Dict{Symbol,DataType}(:none => NoBackend)
const _backend_packages     = Dict{Symbol,Symbol}()
const _initialized_backends = Set{Symbol}()
const _backends             = Symbol[]

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
_backend_instance(sym::Symbol)::AbstractBackend =
    haskey(_backendType, sym) ? _backendType[sym]() : error("Unsupported backend $sym")

backend_package_name(sym::Symbol = backend_name()) = _backend_packages[sym]

# Traits to be implemented by the extensions
backend_name(::AbstractBackend) = nothing
backend_package_name(::AbstractBackend) = nothing

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
        backend(_backend_instance(sym))
    else
        @warn "`:$sym` is not initialized, import it first to trigger the extension --- e.g. `import GR; gr()`."
        backend()
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

const _base_supported_args = [
    :color_palette,
    :background_color,
    :background_color_subplot,
    :foreground_color,
    :foreground_color_subplot,
    :group,
    :seriestype,
    :seriescolor,
    :seriesalpha,
    :smooth,
    :xerror,
    :yerror,
    :zerror,
    :subplot,
    :x,
    :y,
    :z,
    :show,
    :size,
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
    :show_empty_bins,
    :z_order,
    :permute,
    :unitformat,
]

function merge_with_base_supported(v::AVec)
    v = vcat(v, _base_supported_args)
    for vi in v
        if haskey(_axis_defaults, vi)
            for letter in (:x, :y, :z)
                push!(v, get_attr_symbol(letter, vi))
            end
        end
    end
    Set(v)
end

# -- Create backend init functions by hand as the corresponding structs do not
# exist yet

function gr(; kw...)
    default(; reset = false, kw...)
    backend(:gr)
end
export gr

# $sym(; kw...) = (default(; reset = false, kw...); backend($T()))
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
function warn_on_unsupported_args(pkg::AbstractBackend, plotattributes)
    _to_warn = Set{Symbol}()
    bend = Plots.backend_name(pkg)
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

################################################################################
# custom hooks

# @require and imports
function _pre_imports(pkg::AbstractBackend)
    @eval @require_backend $(backend_package_name(pkg))
    nothing
end

# global definitions `const` and `include`
function _post_imports(pkg::AbstractBackend)
    name = backend_package_name(pkg)
    @eval const $name = Main.$name  # so that the module is available in `Plots`
    nothing
end

# function calls, pointer initializations, ...
_runtime_init(::AbstractBackend) = nothing

################################################################################
# initialize the backends
function _initialize_backend(pkg::AbstractBackend)
    _runtime_init(pkg)
    nothing
end

# Not sure why these function are here
# They belong in something like "alignment.jl"
# ----------------------------------------------------------
"Returns the (width,height) of a text label."
function text_size(lablen::Int, sz::Number, rot::Number = 0)
    # we need to compute the size of the ticks generically
    # this means computing the bounding box and then getting the width/height
    # note:
    ptsz = sz * pt
    width = 0.8lablen * ptsz

    # now compute the generalized "height" after rotation as the "opposite+adjacent" of 2 triangles
    height = abs(sind(rot)) * width + abs(cosd(rot)) * ptsz
    width = abs(sind(rot + 90)) * width + abs(cosd(rot + 90)) * ptsz
    width, height
end
text_size(lab::AbstractString, sz::Number, rot::Number = 0) =
    text_size(length(lab), sz, rot)
text_size(lab::PlotText, sz::Number, rot::Number = 0) = text_size(length(lab.str), sz, rot)

# account for the size/length/rotation of tick labels
function tick_padding(sp::Subplot, axis::Axis)
    if (ticks = get_ticks(sp, axis)) === nothing
        0mm
    else
        vals, labs = ticks
        isempty(labs) && return 0mm
        # ptsz = axis[:tickfont].pointsize * pt
        longest_label = maximum(length(lab) for lab in labs)

        # generalize by "rotating" y labels
        rot = axis[:rotation] + (axis[:letter] === :y ? 90 : 0)

        # # we need to compute the size of the ticks generically
        # # this means computing the bounding box and then getting the width/height
        # labelwidth = 0.8longest_label * ptsz
        #
        #
        # # now compute the generalized "height" after rotation as the "opposite+adjacent" of 2 triangles
        # hgt = abs(sind(rot)) * labelwidth + abs(cosd(rot)) * ptsz + 1mm

        # get the height of the rotated label
        text_size(longest_label, axis[:tickfontsize], rot)[2]
    end
end

# Set the (left, top, right, bottom) minimum padding around the plot area
# to fit ticks, tick labels, guides, colorbars, etc.
function _update_min_padding!(sp::Subplot)
    # TODO: something different when `RecipesPipeline.is3d(sp) == true`
    leftpad   = tick_padding(sp, sp[:yaxis]) + sp[:left_margin] + guide_padding(sp[:yaxis])
    toppad    = sp[:top_margin] + title_padding(sp)
    rightpad  = sp[:right_margin]
    bottompad = tick_padding(sp, sp[:xaxis]) + sp[:bottom_margin] + guide_padding(sp[:xaxis])

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