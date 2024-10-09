struct NoBackend <: AbstractBackend end

lazyloadPkg() = Base.require(@__MODULE__, :Pkg)

const _current_plots_version = VersionNumber(TOML.parsefile(normpath(@__DIR__, "..", "Project.toml"))["version"])
const _plots_compats         = TOML.parsefile(normpath(@__DIR__, "..", "Project.toml"))["compat"]

const _backendSymbol        = Dict{DataType,Symbol}(NoBackend => :none)
const _backendType          = Dict{Symbol,DataType}(:none => NoBackend)
const _backend_packages     = Dict{Symbol,Symbol}()
const _initialized_backends = Set{Symbol}()
const _backends             = Symbol[]

const _plots_deps = let toml = TOML.parsefile(normpath(@__DIR__, "..", "Project.toml"))
    merge(toml["deps"], toml["extras"])
end

function _check_installed(backend::Union{Module,AbstractString,Symbol}; warn = true)
    sym = Symbol(lowercase(string(backend)))
    if warn && !haskey(_backend_packages, sym)
        @warn "backend `$sym` is not compatible with `Plots`."
        return
    end
    # lowercase -> CamelCase, falling back to the given input for `PlotlyBase` ...
    str = string(get(_backend_packages, sym, backend))
    str == "Plotly" && (str *= "Base")  # FIXME: `Plots` inconsistency, `plotly` should be named `plotlybase`
    # check supported
    if warn && !haskey(_plots_compats, str)
        @warn "backend `$str` is not compatible with `Plots`."
        return
    end
    # check installed
    pkg_id = if str == "GR"
        # FIXME: remove in `Plots2.0` (`GR` won't be a hard Plots dependency anymore).
        Base.identify_package(Plots, str)  # GR can be in the Manifest or in the Project
    else
        Base.identify_package(str)  # a Project dependency
    end
    version = if pkg_id === nothing
        nothing
    else
        pkg = lazyloadPkg()
        get(Base.invokelatest(pkg.dependencies), pkg_id.uuid, (; version = nothing)).version
    end
    version === nothing && @warn "backend `$str` is not installed."
    version
end

function _check_compat(m::Module; warn = true)
    (be_v = _check_installed(m; warn)) === nothing && return
    be_c = _plots_compats[string(m)]
    pkg = lazyloadPkg()
    semver = Base.invokelatest(pkg.Types.semver_spec, be_c)
    if Base.invokelatest(∉, be_v, semver)
        @warn "`$m` $be_v is not compatible with this version of `Plots`. The declared compatibility is $(be_c)."
    end
    nothing
end

_path(sym::Symbol) =
    if sym ∈ (:pgfplots, :pyplot)
        @path joinpath(@__DIR__, "backends", "deprecated", "$sym.jl")
    else
        @path joinpath(@__DIR__, "backends", "$sym.jl")
    end

"Returns a list of supported backends"
backends() = _backends

"Returns the name of the current backend"
backend_name() = CURRENT_BACKEND.sym

_backend_instance(sym::Symbol)::AbstractBackend =
    haskey(_backendType, sym) ? _backendType[sym]() : error("Unsupported backend $sym")

backend_package_name(sym::Symbol = backend_name()) = _backend_packages[sym]

macro init_backend(s)
    package_str = string(s)
    str = lowercase(package_str)
    sym = Symbol(str)
    T = Symbol(string(s) * "Backend")
    quote
        struct $T <: AbstractBackend end
        export $sym
        $sym(; kw...) = (default(; reset = false, kw...); backend($T()))
        backend_name(::$T) = Symbol($str)
        backend_package_name(::$T) = backend_package_name(Symbol($str))
        push!(_backends, Symbol($str))
        _backendType[Symbol($str)] = $T
        _backendSymbol[$T] = Symbol($str)
        _backend_packages[Symbol($str)] = Symbol($package_str)
    end |> esc
end

macro require_backend(pkg)
    be = QuoteNode(Symbol(lowercase("$pkg")))
    quote
        backend_name() === $be || @require $pkg = $(_plots_deps["$pkg"]) begin
            include(_path($be))
        end
    end |> esc
end

# ---------------------------------------------------------

# don't do anything as a default
_create_backend_figure(plt::Plot) = nothing
_initialize_subplot(plt::Plot, sp::Subplot) = nothing

_series_added(plt::Plot, series::Series) = nothing
_series_updated(plt::Plot, series::Series) = nothing

_before_layout_calcs(plt::Plot) = nothing

title_padding(sp::Subplot) = sp[:title] == "" ? 0mm : sp[:titlefontsize] * pt
guide_padding(axis::Axis) = axis[:guide] == "" ? 0mm : axis[:guidefontsize] * pt

closeall(::AbstractBackend) = nothing

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

mutable struct CurrentBackend
    sym::Symbol
    pkg::AbstractBackend
end
CurrentBackend(sym::Symbol) = CurrentBackend(sym, _backend_instance(sym))

# ---------------------------------------------------------
const PLOTS_DEFAULT_BACKEND = "gr"

function load_default_backend()
    CURRENT_BACKEND.sym = :gr
    backend(CURRENT_BACKEND.sym)
end

function diagnostics(io::IO = stdout)
    origin = if has_preference(Plots, "default_backend")
        "`Preferences`"
    elseif haskey(ENV, "PLOTS_DEFAULT_BACKEND")
        "environment variable"
    else
        "fallback"
    end
    if (be = backend_name()) === :none
        @info "no `Plots` backends currently initialized"
    else
        be_name = string(backend_package_name(be))
        @info "selected `Plots` backend: $be_name, from $origin"
        pkg = lazyloadPkg()
        Base.invokelatest(
            pkg.status,
            ["Plots", "RecipesBase", "RecipesPipeline", be_name];
            mode = pkg.PKGMODE_MANIFEST,
            io,
        )
    end
    nothing
end

# ---------------------------------------------------------

"""
Returns the current plotting package name.  Initializes package on first call.
"""
function backend()
    CURRENT_BACKEND.sym === :none && load_default_backend()
    CURRENT_BACKEND.pkg
end

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
        @warn "`:$sym` is not a supported backend."
        backend()
    end

const _deprecated_backends =
    [:qwt, :winston, :bokeh, :gadfly, :immerse, :glvisualize, :pgfplots]

# ---------------------------------------------------------

# these are args which every backend supports because they're not used in the backend code
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

@init_backend PyPlot
@init_backend PythonPlot
@init_backend UnicodePlots
@init_backend Plotly
@init_backend PlotlyJS
@init_backend GR
@init_backend PGFPlots
@init_backend PGFPlotsX
@init_backend InspectDR
@init_backend HDF5
@init_backend Gaston

# ---------------------------------------------------------

# create the various `is_xxx_supported` and `supported_xxxs` methods
# by default they pass through to checking membership in `_gr_xxx`
for s in (:attr, :seriestype, :marker, :style, :scale)
    f1 = Symbol("is_", s, "_supported")
    f2 = Symbol("supported_", s, "s")
    @eval begin
        $f1(::AbstractBackend, $s) = false
        $f1(be::AbstractBackend, $s::AbstractVector) = all(v -> $f1(be, v), $s)
        $f1($s) = $f1(backend(), $s)
        $f2() = $f2(backend())
    end

    for be in backends()
        be_type = typeof(_backend_instance(be))
        v = Symbol("_", be, "_", s)
        @eval begin
            $f1(::$be_type, $s::Symbol) = $s in $v
            $f2(::$be_type) = sort(collect($v))
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
    _pre_imports(pkg)
    name = backend_package_name(pkg)
    # NOTE: this is a hack importing in `Main` (expecting the package to be in `Project.toml`, remove in `Plots@2.0`)
    # FIXME: remove hard `GR` dependency in `Plots@2.0`
    @eval name === :GR ? Plots : Main begin
        import $name
        export $name
        if $(QuoteNode(name)) !== :GR
            $(_check_compat)($name)
        end
    end
    _post_imports(pkg)
    _runtime_init(pkg)
    nothing
end

# ------------------------------------------------------------------------------
# gr
_post_imports(::GRBackend) = nothing

const _gr_attr = merge_with_base_supported([
    :annotations,
    :annotationrotation,
    :annotationhalign,
    :annotationfontsize,
    :annotationfontfamily,
    :annotationcolor,
    :annotationvalign,
    :legend_background_color,
    :background_color_inside,
    :background_color_outside,
    :legend_foreground_color,
    :foreground_color_grid,
    :foreground_color_axis,
    :foreground_color_text,
    :foreground_color_border,
    :label,
    :seriescolor,
    :seriesalpha,
    :linecolor,
    :linestyle,
    :linewidth,
    :linealpha,
    :markershape,
    :markercolor,
    :markersize,
    :markeralpha,
    :markerstrokewidth,
    :markerstrokecolor,
    :markerstrokealpha,
    :fillrange,
    :fillcolor,
    :fillalpha,
    :fillstyle,
    :bins,
    :layout,
    :title,
    :window_title,
    :guide,
    :widen,
    :lims,
    :ticks,
    :scale,
    :flip,
    :titlefontfamily,
    :titlefontsize,
    :titlefonthalign,
    :titlefontvalign,
    :titlefontrotation,
    :titlefontcolor,
    :legend_font_family,
    :legend_font_pointsize,
    :legend_font_halign,
    :legend_font_valign,
    :legend_font_rotation,
    :legend_font_color,
    :tickfontfamily,
    :tickfontsize,
    :tickfonthalign,
    :tickfontvalign,
    :tickfontrotation,
    :tickfontcolor,
    :guidefontfamily,
    :guidefontsize,
    :guidefonthalign,
    :guidefontvalign,
    :guidefontrotation,
    :guidefontcolor,
    :grid,
    :gridalpha,
    :gridstyle,
    :gridlinewidth,
    :legend_position,
    :legend_title,
    :colorbar,
    :colorbar_title,
    :colorbar_titlefont,
    :colorbar_titlefontsize,
    :colorbar_titlefontrotation,
    :colorbar_titlefontcolor,
    :colorbar_entry,
    :colorbar_scale,
    :clims,
    :fill,
    :fill_z,
    :fontfamily,
    :fontfamily_subplot,
    :line_z,
    :marker_z,
    :legend_column,
    :legend_font,
    :legend_title,
    :legend_title_font_color,
    :legend_title_font_family,
    :legend_title_font_rotation,
    :legend_title_font_pointsize,
    :legend_title_font_valigm,
    :levels,
    :line,
    :ribbon,
    :quiver,
    :orientation,
    :overwrite_figure,
    :plot_title,
    :plot_titlefontcolor,
    :plot_titlefontfamily,
    :plot_titlefontrotation,
    :plot_titlefontsize,
    :plot_titlelocation,
    :plot_titlevspan,
    :polar,
    :aspect_ratio,
    :normalize,
    :weights,
    :inset_subplots,
    :bar_width,
    :arrow,
    :framestyle,
    :tick_direction,
    :camera,
    :contour_labels,
    :connections,
    :axis,
    :thickness_scaling,
    :minorgrid,
    :minorgridalpha,
    :minorgridlinewidth,
    :minorgridstyle,
    :minorticks,
    :mirror,
    :rotation,
    :showaxis,
    :tickfonthalign,
    :formatter,
    :mirror,
    :guidefont,
])
const _gr_seriestype = [
    :path,
    :scatter,
    :straightline,
    :heatmap,
    :image,
    :contour,
    :path3d,
    :scatter3d,
    :surface,
    :wireframe,
    :mesh3d,
    :volume,
    :shape,
]
const _gr_style = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]
const _gr_marker = vcat(_allMarkers, :pixel)
const _gr_scale = [:identity, :ln, :log2, :log10]
is_marker_supported(::GRBackend, shape::Shape) = true

# ------------------------------------------------------------------------------
# plotly
_pre_imports(::PlotlyBackend) = nothing
_post_imports(::PlotlyBackend) = @eval begin
    const PlotlyBase    = Main.PlotlyBase
    const PlotlyKaleido = Main.PlotlyKaleido
    # FIXME: in Plots `2.0`, `plotly` backend should be re-named to `plotlybase`
    # so that we can trigger include on `@require` instead of this
    PLOTS_DEFAULT_BACKEND == "plotly" || include(_path(:plotly))
    include(_path(:plotlybase))
end
function _initialize_backend(pkg::PlotlyBackend)
    try
        _pre_imports(pkg)
        @eval Main begin
            import PlotlyBase
            import PlotlyKaleido
            $(_check_compat)(PlotlyBase; warn = false)  # NOTE: don't warn, since those are not backends, but deps
            $(_check_compat)(PlotlyKaleido, warn = false)
        end
        _post_imports(pkg)
        _runtime_init(pkg)
    catch err
        if err isa ArgumentError
            @warn "Failed to load integration with PlotlyBase & PlotlyKaleido." exception =
                (err, catch_backtrace())
        else
            rethrow(err)
        end
        # NOTE: `plotly` is special in the way that it does not require dependencies for displaying a plot
        # as a result, we cannot rely on the `@require` mechanism for loading glue code
        # this is why it must be done here.
        PLOTS_DEFAULT_BACKEND == "plotly" || @eval include(_path(:plotly))
    end
    @static if isdefined(Base.Experimental, :register_error_hint)
        Base.Experimental.register_error_hint(MethodError) do io, exc, argtypes, kwargs
            if exc.f === _show &&
               length(argtypes) == 3 &&
               argtypes[2] <: MIME"image/png" &&
               argtypes[3] <: Plot{PlotlyBackend}
                println(
                    io,
                    "\n\nTip: For saving/rendering as png with the `Plotly` backend `PlotlyBase` and `PlotlyKaleido` need to be installed.",
                )
            end
        end
    end
end

const _plotly_attr = merge_with_base_supported([
    :annotations,
    :legend_background_color,
    :background_color_inside,
    :background_color_outside,
    :legend_foreground_color,
    :foreground_color_guide,
    :foreground_color_grid,
    :foreground_color_axis,
    :foreground_color_text,
    :foreground_color_border,
    :foreground_color_title,
    :label,
    :seriescolor,
    :seriesalpha,
    :linecolor,
    :linestyle,
    :linewidth,
    :linealpha,
    :markershape,
    :markercolor,
    :markersize,
    :markeralpha,
    :markerstrokewidth,
    :markerstrokecolor,
    :markerstrokealpha,
    :markerstrokestyle,
    :fill,
    :fillrange,
    :fillcolor,
    :fillalpha,
    :fontfamily,
    :fontfamily_subplot,
    :bins,
    :title,
    :titlelocation,
    :titlefontfamily,
    :titlefontsize,
    :titlefonthalign,
    :titlefontvalign,
    :titlefontcolor,
    :legend_column,
    :legend_font,
    :legend_font_family,
    :legend_font_pointsize,
    :legend_font_color,
    :legend_title,
    :legend_title_font_color,
    :legend_title_font_family,
    :legend_title_font_pointsize,
    :tickfontfamily,
    :tickfontsize,
    :tickfontcolor,
    :guidefontfamily,
    :guidefontsize,
    :guidefontcolor,
    :window_title,
    :arrow,
    :guide,
    :widen,
    :lims,
    :line,
    :ticks,
    :scale,
    :flip,
    :rotation,
    :tickfont,
    :guidefont,
    :legendfont,
    :grid,
    :gridalpha,
    :gridlinewidth,
    :legend,
    :colorbar,
    :colorbar_title,
    :colorbar_entry,
    :marker_z,
    :fill_z,
    :line_z,
    :levels,
    :ribbon,
    :quiver,
    :orientation,
    # :overwrite_figure,
    :polar,
    :plot_title,
    :plot_titlefontcolor,
    :plot_titlefontfamily,
    :plot_titlefontsize,
    :plot_titlelocation,
    :plot_titlevspan,
    :normalize,
    :weights,
    # :contours,
    :aspect_ratio,
    :hover,
    :inset_subplots,
    :bar_width,
    :clims,
    :framestyle,
    :tick_direction,
    :camera,
    :contour_labels,
    :connections,
    :xformatter,
    :xshowaxis,
    :xguidefont,
    :yformatter,
    :yshowaxis,
    :yguidefont,
    :zformatter,
    :zguidefont,
])

const _plotly_seriestype = [
    :path,
    :scatter,
    :heatmap,
    :contour,
    :surface,
    :wireframe,
    :path3d,
    :scatter3d,
    :shape,
    :scattergl,
    :straightline,
    :mesh3d,
]
const _plotly_style = [:auto, :solid, :dash, :dot, :dashdot]
const _plotly_marker = [
    :none,
    :auto,
    :circle,
    :rect,
    :diamond,
    :utriangle,
    :dtriangle,
    :cross,
    :xcross,
    :pentagon,
    :hexagon,
    :octagon,
    :vline,
    :hline,
    :x,
]
const _plotly_scale = [:identity, :log10]

defaultOutputFormat(plt::Plot{Plots.PlotlyBackend}) = "html"

# ------------------------------------------------------------------------------
# pgfplots

const _pgfplots_attr = merge_with_base_supported([
    :annotations,
    :legend_background_color,
    :background_color_inside,
    # :background_color_outside,
    # :legend_foreground_color,
    :foreground_color_grid,
    :foreground_color_axis,
    :foreground_color_text,
    :foreground_color_border,
    :label,
    :seriescolor,
    :seriesalpha,
    :linecolor,
    :linestyle,
    :linewidth,
    :linealpha,
    :markershape,
    :markercolor,
    :markersize,
    :markeralpha,
    :markerstrokewidth,
    :markerstrokecolor,
    :markerstrokealpha,
    :markerstrokestyle,
    :fillrange,
    :fillcolor,
    :fillalpha,
    :bins,
    # :bar_width, :bar_edges,
    :title,
    # :window_title,
    :guide,
    :guide_position,
    :widen,
    :lims,
    :ticks,
    :scale,
    :flip,
    :rotation,
    :tickfont,
    :guidefont,
    :legendfont,
    :grid,
    :legend,
    :colorbar,
    :colorbar_title,
    :fill_z,
    :line_z,
    :marker_z,
    :levels,
    # :ribbon, :quiver, :arrow,
    # :orientation,
    # :overwrite_figure,
    :polar,
    # :normalize, :weights, :contours,
    :aspect_ratio,
    :tick_direction,
    :framestyle,
    :camera,
    :contour_labels,
])
const _pgfplots_seriestype = [
    :path,
    :path3d,
    :scatter,
    :steppre,
    :stepmid,
    :steppost,
    :histogram2d,
    :ysticks,
    :xsticks,
    :contour,
    :shape,
    :straightline,
]
const _pgfplots_style = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]
const _pgfplots_marker = [
    :none,
    :auto,
    :circle,
    :rect,
    :diamond,
    :utriangle,
    :dtriangle,
    :cross,
    :xcross,
    :star5,
    :pentagon,
    :hline,
    :vline,
] #vcat(_allMarkers, Shape)
const _pgfplots_scale = [:identity, :ln, :log2, :log10]

# ------------------------------------------------------------------------------
# plotlyjs

const _plotlyjs_attr       = _plotly_attr
const _plotlyjs_seriestype = _plotly_seriestype
const _plotlyjs_style      = _plotly_style
const _plotlyjs_marker     = _plotly_marker
const _plotlyjs_scale      = _plotly_scale

# ------------------------------------------------------------------------------
# pyplot

_post_imports(::PyPlotBackend) = @eval begin
    const PyPlot = Main.PyPlot
    const PyCall = Main.PyPlot.PyCall
end
_runtime_init(::PyPlotBackend) = @eval begin
    pycolors   = PyCall.pyimport("matplotlib.colors")
    pypath     = PyCall.pyimport("matplotlib.path")
    mplot3d    = PyCall.pyimport("mpl_toolkits.mplot3d")
    axes_grid1 = PyCall.pyimport("mpl_toolkits.axes_grid1")
    pypatches  = PyCall.pyimport("matplotlib.patches")
    pyticker   = PyCall.pyimport("matplotlib.ticker")
    pycmap     = PyCall.pyimport("matplotlib.cm")
    pynp       = PyCall.pyimport("numpy")

    pynp."seterr"(invalid = "ignore")

    PyPlot.ioff()  # we don't want every command to update the figure
end

function _initialize_backend(pkg::PyPlotBackend)
    _pre_imports(pkg)
    @eval Main begin
        import PyPlot
        export PyPlot
        $(_check_compat)(PyPlot)
    end
    _post_imports(pkg)
    _runtime_init(pkg)
end

const _pyplot_attr = merge_with_base_supported([
    :annotations,
    :annotationrotation,
    :annotationhalign,
    :annotationfontsize,
    :annotationfontfamily,
    :annotationcolor,
    :annotationvalign,
    :legend_background_color,
    :background_color_inside,
    :background_color_outside,
    :foreground_color_grid,
    :legend_foreground_color,
    :foreground_color_title,
    :foreground_color_axis,
    :foreground_color_border,
    :foreground_color_guide,
    :foreground_color_text,
    :label,
    :linecolor,
    :linestyle,
    :linewidth,
    :linealpha,
    :markershape,
    :markercolor,
    :markersize,
    :markeralpha,
    :markerstrokewidth,
    :markerstrokecolor,
    :markerstrokealpha,
    :fillrange,
    :fillcolor,
    :fillalpha,
    :fillstyle,
    :bins,
    :bar_width,
    :bar_edges,
    :bar_position,
    :title,
    :titlelocation,
    :titlefont,
    :window_title,
    :guide,
    :guide_position,
    :widen,
    :lims,
    :ticks,
    :scale,
    :flip,
    :rotation,
    :titlefontfamily,
    :titlefontsize,
    :titlefontcolor,
    :legend_font_family,
    :legend_font_pointsize,
    :legend_font_color,
    :tickfontfamily,
    :tickfontsize,
    :tickfontcolor,
    :guidefontfamily,
    :guidefontsize,
    :guidefontcolor,
    :grid,
    :gridalpha,
    :gridstyle,
    :gridlinewidth,
    :legend_position,
    :legend_title,
    :colorbar,
    :colorbar_title,
    :colorbar_entry,
    :colorbar_ticks,
    :colorbar_tickfontfamily,
    :colorbar_tickfontsize,
    :colorbar_tickfonthalign,
    :colorbar_tickfontvalign,
    :colorbar_tickfontrotation,
    :colorbar_tickfontcolor,
    :colorbar_titlefontcolor,
    :colorbar_titlefontsize,
    :colorbar_scale,
    :marker_z,
    :line,
    :line_z,
    :fill,
    :fill_z,
    :fontfamily,
    :fontfamily_subplot,
    :legend_column,
    :legend_font,
    :legend_title,
    :legend_title_font_color,
    :legend_title_font_family,
    :legend_title_font_pointsize,
    :levels,
    :ribbon,
    :quiver,
    :arrow,
    :orientation,
    :overwrite_figure,
    :polar,
    :plot_title,
    :plot_titlefontcolor,
    :plot_titlefontfamily,
    :plot_titlefontsize,
    :plot_titlelocation,
    :plot_titlevspan,
    :normalize,
    :weights,
    :contours,
    :aspect_ratio,
    :clims,
    :inset_subplots,
    :dpi,
    :stride,
    :framestyle,
    :tick_direction,
    :thickness_scaling,
    :camera,
    :contour_labels,
    :connections,
    :thickness_scaling,
    :axis,
    :minorgrid,
    :minorgridalpha,
    :minorgridlinewidth,
    :minorgridstyle,
    :minorticks,
    :mirror,
    :showaxis,
    :tickfontrotation,
    :formatter,
    :guidefont,
])
const _pyplot_seriestype = [
    :path,
    :steppre,
    :stepmid,
    :steppost,
    :shape,
    :straightline,
    :scatter,
    :hexbin,
    :heatmap,
    :image,
    :contour,
    :contour3d,
    :path3d,
    :scatter3d,
    :mesh3d,
    :surface,
    :wireframe,
]
const _pyplot_style = [:auto, :solid, :dash, :dot, :dashdot]
const _pyplot_marker = vcat(_allMarkers, :pixel)
const _pyplot_scale = [:identity, :ln, :log2, :log10]

# ------------------------------------------------------------------------------
# pythonplot

_post_imports(::PythonPlotBackend) = @eval begin
    const PythonPlot = Main.PythonPlot
    const PythonCall = Main.PythonPlot.PythonCall
    const mpl_toolkits = PythonPlot.pyimport("mpl_toolkits")
    const mpl = PythonPlot.pyimport("matplotlib")
    const numpy = PythonPlot.pyimport("numpy")

    PythonPlot.pyimport("mpl_toolkits.axes_grid1")
    numpy.seterr(invalid = "ignore")

    const pyisnone = if isdefined(PythonCall, :pyisnone)
        PythonCall.pyisnone
    else
        PythonCall.Core.pyisnone
    end

    PythonPlot.ioff() # we don't want every command to update the figure
end
_runtime_init(::PythonPlotBackend) = nothing

function _initialize_backend(pkg::PythonPlotBackend)
    _pre_imports(pkg)
    @eval Main begin
        import PythonPlot
        $(_check_compat)(PythonPlot)
    end
    _post_imports(pkg)
    _runtime_init(pkg)
end

const _pythonplot_seriestype = _pyplot_seriestype
const _pythonplot_marker     = _pyplot_marker
const _pythonplot_style      = _pyplot_style
const _pythonplot_scale      = _pyplot_scale

const _pythonplot_attr = merge_with_base_supported([
    :annotations,
    :legend_background_color,
    :background_color_inside,
    :background_color_outside,
    :foreground_color_grid,
    :legend_foreground_color,
    :foreground_color_title,
    :foreground_color_axis,
    :foreground_color_border,
    :foreground_color_guide,
    :foreground_color_text,
    :label,
    :linecolor,
    :linestyle,
    :linewidth,
    :linealpha,
    :markershape,
    :markercolor,
    :markersize,
    :markeralpha,
    :markerstrokewidth,
    :markerstrokecolor,
    :markerstrokealpha,
    :fillrange,
    :fillcolor,
    :fillalpha,
    :fillstyle,
    :bins,
    :bar_width,
    :bar_edges,
    :bar_position,
    :title,
    :titlelocation,
    :titlefont,
    :window_title,
    :guide,
    :guide_position,
    :widen,
    :lims,
    :ticks,
    :scale,
    :flip,
    :rotation,
    :titlefontfamily,
    :titlefontsize,
    :titlefontcolor,
    :legend_font_family,
    :legend_font_pointsize,
    :legend_font_color,
    :tickfontfamily,
    :tickfontsize,
    :tickfontcolor,
    :guidefontfamily,
    :guidefontsize,
    :guidefontcolor,
    :grid,
    :gridalpha,
    :gridstyle,
    :gridlinewidth,
    :legend_position,
    :legend_title,
    :colorbar,
    :colorbar_title,
    :colorbar_entry,
    :colorbar_ticks,
    :colorbar_tickfontfamily,
    :colorbar_tickfontsize,
    :colorbar_tickfonthalign,
    :colorbar_tickfontvalign,
    :colorbar_tickfontrotation,
    :colorbar_tickfontcolor,
    :colorbar_titlefontcolor,
    :colorbar_titlefontsize,
    :colorbar_scale,
    :marker_z,
    :line,
    :line_z,
    :fill,
    :fill_z,
    :fontfamily,
    :fontfamily_subplot,
    :legend_column,
    :legend_font,
    :legend_title,
    :legend_title_font_color,
    :legend_title_font_family,
    :legend_title_font_pointsize,
    :levels,
    :ribbon,
    :quiver,
    :arrow,
    :orientation,
    :overwrite_figure,
    :polar,
    :normalize,
    :weights,
    :contours,
    :aspect_ratio,
    :clims,
    :inset_subplots,
    :dpi,
    :stride,
    :framestyle,
    :tick_direction,
    :camera,
    :contour_labels,
    :connections,
])

# ------------------------------------------------------------------------------
# gaston

const _gaston_attr = merge_with_base_supported([
    :annotations,
    # :background_color_legend,
    # :background_color_inside,
    # :background_color_outside,
    # :foreground_color_legend,
    # :foreground_color_grid, :foreground_color_axis,
    # :foreground_color_text, :foreground_color_border,
    :label,
    :seriescolor,
    :seriesalpha,
    :linecolor,
    :linestyle,
    :linewidth,
    :linealpha,
    :markershape,
    :markercolor,
    :markersize,
    :markeralpha,
    # :markerstrokewidth, :markerstrokecolor, :markerstrokealpha, :markerstrokestyle,
    # :fillrange, :fillcolor, :fillalpha,
    # :bins,
    # :bar_width, :bar_edges,
    :title,
    :window_title,
    :guide,
    :guide_position,
    :widen,
    :lims,
    :ticks,
    :scale,
    :flip,
    :rotation,
    :tickfont,
    :guidefont,
    :legendfont,
    :grid,
    :legend,
    # :colorbar, :colorbar_title,
    # :fill_z, :line_z, :marker_z, :levels,
    # :ribbon,
    :quiver,
    :arrow,
    # :orientation, :overwrite_figure,
    :polar,
    # :normalize, :weights, :contours,
    :aspect_ratio,
    :tick_direction,
    # :framestyle,
    # :camera,
    # :contour_labels,
    :connections,
])

const _gaston_seriestype = [
    :path,
    :path3d,
    :scatter,
    :steppre,
    :stepmid,
    :steppost,
    :ysticks,
    :xsticks,
    :contour,
    :shape,
    :straightline,
    :scatter3d,
    :contour3d,
    :wireframe,
    :heatmap,
    :surface,
    :mesh3d,
    :image,
]

const _gaston_style = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]

const _gaston_marker = [
    :none,
    :auto,
    :pixel,
    :cross,
    :xcross,
    :+,
    :x,
    :star5,
    :rect,
    :circle,
    :utriangle,
    :dtriangle,
    :diamond,
    :pentagon,
    # :hline,
    # :vline,
]

const _gaston_scale = [:identity, :ln, :log2, :log10]

# ------------------------------------------------------------------------------
# unicodeplots

const _unicodeplots_attr = merge_with_base_supported([
    :annotations,
    :bins,
    :guide,
    :widen,
    :grid,
    :label,
    :layout,
    :legend,
    :legend_title_font_color,
    :lims,
    :line,
    :linealpha,
    :linecolor,
    :linestyle,
    :markershape,
    :plot_title,
    :quiver,
    :arrow,
    :seriesalpha,
    :seriescolor,
    :scale,
    :flip,
    :title,
    # :marker_z,
    :line_z,
])
const _unicodeplots_seriestype = [
    :path,
    :path3d,
    :scatter,
    :scatter3d,
    :straightline,
    # :bar,
    :shape,
    :histogram2d,
    :heatmap,
    :contour,
    # :contour3d,
    :image,
    :spy,
    :surface,
    :wireframe,
    :mesh3d,
]
const _unicodeplots_style = [:auto, :solid]
const _unicodeplots_marker = [
    :none,
    :auto,
    :pixel,
    # vvvvvvvvvv shapes
    :circle,
    :rect,
    :star5,
    :diamond,
    :hexagon,
    :cross,
    :xcross,
    :utriangle,
    :dtriangle,
    :rtriangle,
    :ltriangle,
    :pentagon,
    # :heptagon,
    # :octagon,
    :star4,
    :star6,
    # :star7,
    :star8,
    :vline,
    :hline,
    :+,
    :x,
]
const _unicodeplots_scale = [:identity, :ln, :log2, :log10]

# ------------------------------------------------------------------------------
# hdf5

const _hdf5_attr = merge_with_base_supported([
    :annotations,
    :legend_background_color,
    :background_color_inside,
    :background_color_outside,
    :foreground_color_grid,
    :legend_foreground_color,
    :foreground_color_title,
    :foreground_color_axis,
    :foreground_color_border,
    :foreground_color_guide,
    :foreground_color_text,
    :label,
    :linecolor,
    :linestyle,
    :linewidth,
    :linealpha,
    :markershape,
    :markercolor,
    :markersize,
    :markeralpha,
    :markerstrokewidth,
    :markerstrokecolor,
    :markerstrokealpha,
    :fillrange,
    :fillcolor,
    :fillalpha,
    :bins,
    :bar_width,
    :bar_edges,
    :bar_position,
    :title,
    :titlelocation,
    :titlefont,
    :window_title,
    :guide,
    :widen,
    :lims,
    :ticks,
    :scale,
    :flip,
    :rotation,
    :tickfont,
    :guidefont,
    :legendfont,
    :grid,
    :legend,
    :colorbar,
    :marker_z,
    :line_z,
    :fill_z,
    :levels,
    :ribbon,
    :quiver,
    :arrow,
    :orientation,
    :overwrite_figure,
    :polar,
    :normalize,
    :weights,
    :contours,
    :aspect_ratio,
    :clims,
    :inset_subplots,
    :dpi,
    :colorbar_title,
])
const _hdf5_seriestype = [
    :path,
    :steppre,
    :stepmid,
    :steppost,
    :shape,
    :straightline,
    :scatter,
    :hexbin,
    :heatmap,
    :image,
    :contour,
    :contour3d,
    :path3d,
    :scatter3d,
    :surface,
    :wireframe,
]
const _hdf5_style = [:auto, :solid, :dash, :dot, :dashdot]
const _hdf5_marker = vcat(_allMarkers, :pixel)
const _hdf5_scale = [:identity, :ln, :log2, :log10]

# Additional constants
# Dict has problems using "Types" as keys.  Initialize in "_initialize_backend":
const HDF5PLOT_MAP_STR2TELEM = Dict{String,Type}()
const HDF5PLOT_MAP_TELEM2STR = Dict{Type,String}()

# Don't really like this global variable... Very hacky
mutable struct HDF5Plot_PlotRef
    ref::Union{Plot,Nothing}
end
const HDF5PLOT_PLOTREF = HDF5Plot_PlotRef(nothing)

# ------------------------------------------------------------------------------
# inspectdr

const _inspectdr_attr = merge_with_base_supported([
    :annotations,
    :legend_background_color,
    :background_color_inside,
    :background_color_outside,
    # :foreground_color_grid,
    :legend_foreground_color,
    :foreground_color_title,
    :foreground_color_axis,
    :foreground_color_border,
    :foreground_color_guide,
    :foreground_color_text,
    :label,
    :seriescolor,
    :seriesalpha,
    :line,
    :linecolor,
    :linestyle,
    :linewidth,
    :linealpha,
    :markershape,
    :markercolor,
    :markersize,
    :markeralpha,
    :markerstrokewidth,
    :markerstrokecolor,
    :markerstrokealpha,
    :markerstrokestyle, #Causes warning not to have it... what is this?
    :fillcolor,
    :fillalpha, #:fillrange,
    #    :bins, :bar_width, :bar_edges, :bar_position,
    :title,
    :titlelocation,
    :window_title,
    :guide,
    :widen,
    :lims,
    :scale, #:ticks, :flip, :rotation,
    :titlefontfamily,
    :titlefontsize,
    :titlefontcolor,
    :legend_font_family,
    :legend_font_pointsize,
    :legend_font_color,
    :tickfontfamily,
    :tickfontsize,
    :tickfontcolor,
    :guidefontfamily,
    :guidefontsize,
    :guidefontcolor,
    :grid,
    :legend_position, #:colorbar,
    #    :marker_z,
    #    :line_z,
    #    :levels,
    #   :ribbon, :quiver, :arrow,
    #    :orientation,
    :overwrite_figure,
    :polar,
    #    :normalize, :weights,
    #    :contours, :aspect_ratio,
    #    :clims,
    #    :inset_subplots,
    :dpi,
    #    :colorbar_title,
])
const _inspectdr_style = [:auto, :solid, :dash, :dot, :dashdot]
const _inspectdr_seriestype = [
    :path,
    :scatter,
    :shape,
    :straightline, #, :steppre, :stepmid, :steppost
]
#see: _allMarkers, _shape_keys
const _inspectdr_marker = Symbol[
    :none,
    :auto,
    :circle,
    :rect,
    :diamond,
    :cross,
    :xcross,
    :utriangle,
    :dtriangle,
    :rtriangle,
    :ltriangle,
    :pentagon,
    :hexagon,
    :heptagon,
    :octagon,
    :star4,
    :star5,
    :star6,
    :star7,
    :star8,
    :vline,
    :hline,
    :+,
    :x,
]

const _inspectdr_scale = [:identity, :ln, :log2, :log10]
# ------------------------------------------------------------------------------
# pgfplotsx

_pre_imports(::PGFPlotsXBackend) = @eval Plots begin
    import LaTeXStrings: LaTeXString
    import UUIDs: uuid4
    import Latexify
    import Contour
    @require_backend PGFPlotsX
end

function _initialize_backend(pkg::PGFPlotsXBackend)
    _pre_imports(pkg)
    @eval Main begin
        import PGFPlotsX
        export PGFPlotsX
        $(_check_compat)(PGFPlotsX)
    end
    _post_imports(pkg)
    _runtime_init(pkg)
end

const _pgfplotsx_attr = merge_with_base_supported([
    :annotations,
    :annotationrotation,
    :annotationhalign,
    :annotationfontsize,
    :annotationfontfamily,
    :annotationcolor,
    :legend_background_color,
    :background_color_inside,
    :background_color_outside,
    :legend_foreground_color,
    :foreground_color_grid,
    :foreground_color_axis,
    :foreground_color_text,
    :foreground_color_border,
    :label,
    :seriescolor,
    :seriesalpha,
    :line,
    :linecolor,
    :linestyle,
    :linewidth,
    :linealpha,
    :markershape,
    :markercolor,
    :markersize,
    :markeralpha,
    :markerstrokewidth,
    :markerstrokecolor,
    :markerstrokealpha,
    :fillrange,
    :fillcolor,
    :fillalpha,
    :bins,
    :layout,
    :title,
    :window_title,
    :guide,
    :widen,
    :lims,
    :ticks,
    :scale,
    :flip,
    :titlefontfamily,
    :titlefontsize,
    :titlefonthalign,
    :titlefontvalign,
    :titlefontrotation,
    :titlefontcolor,
    :legend_font_family,
    :legend_font_pointsize,
    :legend_font_halign,
    :legend_font_valign,
    :legend_font_rotation,
    :legend_font_color,
    :tickfontfamily,
    :tickfontsize,
    :tickfonthalign,
    :tickfontvalign,
    :tickfontrotation,
    :tickfontcolor,
    :guidefontfamily,
    :guidefontsize,
    :guidefonthalign,
    :guidefontvalign,
    :guidefontrotation,
    :guidefontcolor,
    :grid,
    :gridalpha,
    :gridstyle,
    :gridlinewidth,
    :legend_position,
    :legend_title,
    :colorbar,
    :colorbar_title,
    :colorbar_titlefontsize,
    :colorbar_titlefontcolor,
    :colorbar_titlefontrotation,
    :colorbar_entry,
    :fill,
    :fill_z,
    :line_z,
    :marker_z,
    :levels,
    :legend_column,
    :legend_title,
    :legend_title_font_color,
    :legend_title_font_pointsize,
    :ribbon,
    :quiver,
    :orientation,
    :overwrite_figure,
    :polar,
    :plot_title,
    :plot_titlefontcolor,
    :plot_titlefontrotation,
    :plot_titlefontsize,
    :plot_titlevspan,
    :aspect_ratio,
    :normalize,
    :weights,
    :inset_subplots,
    :bar_width,
    :arrow,
    :framestyle,
    :tick_direction,
    :thickness_scaling,
    :camera,
    :contour_labels,
    :connections,
    :thickness_scaling,
    :axis,
    :draw_arrow,
    :minorgrid,
    :minorgridalpha,
    :minorgridlinewidth,
    :minorgridstyle,
    :minorticks,
    :mirror,
    :rotation,
    :showaxis,
    :tickfontrotation,
    :draw_arrow,
])
const _pgfplotsx_seriestype = [
    :path,
    :scatter,
    :straightline,
    :path3d,
    :scatter3d,
    :surface,
    :wireframe,
    :heatmap,
    :mesh3d,
    :contour,
    :contour3d,
    :quiver,
    :shape,
    :steppre,
    :stepmid,
    :steppost,
    :ysticks,
    :xsticks,
]
const _pgfplotsx_style = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]
const _pgfplotsx_marker = [
    :none,
    :auto,
    :circle,
    :rect,
    :diamond,
    :utriangle,
    :dtriangle,
    :ltriangle,
    :rtriangle,
    :cross,
    :xcross,
    :x,
    :+,
    :star5,
    :star6,
    :pentagon,
    :hline,
    :vline,
]
const _pgfplotsx_scale = [:identity, :ln, :log2, :log10]
is_marker_supported(::PGFPlotsXBackend, shape::Shape) = true

# additional constants
const _pgfplotsx_series_ids = KW()
