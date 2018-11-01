using Pkg

struct NoBackend <: AbstractBackend end

const _backendType = Dict{Symbol, DataType}(:none => NoBackend)
const _backendSymbol = Dict{DataType, Symbol}(NoBackend => :none)
const _backends = Symbol[]
const _initialized_backends = Set{Symbol}()
const _default_backends = (:none, :gr, :plotly)
const _backendPackage = Dict{Symbol, Symbol}()

"Returns a list of supported backends"
backends() = _backends

"Returns the name of the current backend"
backend_name() = CURRENT_BACKEND.sym
_backend_instance(sym::Symbol) = haskey(_backendType, sym) ? _backendType[sym]() : error("Unsupported backend $sym")
backend_package(pkg::Symbol) = pkg in _default_backends ? :Plots : Symbol("Plots", _backendPackage[pkg])
backend_package_name(sym::Symbol) = sym in _default_backends ? :Plots : _backendPackage[sym]

macro init_backend(s)
    package_str = string(s)
    str = lowercase(package_str)
    sym = Symbol(str)
    T = Symbol(string(s) * "Backend")
    esc(quote
        struct $T <: AbstractBackend end
        export $sym
        $sym(; kw...) = (default(; kw...); backend(Symbol($str)))
        backend_name(::$T) = Symbol($str)
        backend_package_name(pkg::$T) = backend_package_name(Symbol($str))
        push!(_backends, Symbol($str))
        _backendType[Symbol($str)] = $T
        _backendSymbol[$T] = Symbol($str)
        _backendPackage[Symbol($str)] = Symbol($package_str)
        # include("backends/" * $str * ".jl")
    end)
end

# include("backends/web.jl")
# include("backends/supported.jl")

# ---------------------------------------------------------

function add_backend(pkg::Symbol)
    @info("To do a standard install of $pkg, copy and run this:\n\n")
    println(add_backend_string(_backend_instance(pkg)))
    println()
end

# don't do anything as a default
_create_backend_figure(plt::Plot) = nothing
_prepare_plot_object(plt::Plot) = nothing
_initialize_subplot(plt::Plot, sp::Subplot) = nothing

_series_added(plt::Plot, series::Series) = nothing
_series_updated(plt::Plot, series::Series) = nothing

_before_layout_calcs(plt::Plot) = nothing

title_padding(sp::Subplot) = sp[:title] == "" ? 0mm : sp[:titlefontsize] * pt
guide_padding(axis::Axis) = axis[:guide] == "" ? 0mm : axis[:guidefontsize] * pt

"Returns the (width,height) of a text label."
function text_size(lablen::Int, sz::Number, rot::Number = 0)
    # we need to compute the size of the ticks generically
    # this means computing the bounding box and then getting the width/height
    # note:
    ptsz = sz * pt
    width = 0.8lablen * ptsz

    # now compute the generalized "height" after rotation as the "opposite+adjacent" of 2 triangles
    height = abs(sind(rot)) * width + abs(cosd(rot)) * ptsz
    width = abs(sind(rot+90)) * width + abs(cosd(rot+90)) * ptsz
    width, height
end
text_size(lab::AbstractString, sz::Number, rot::Number = 0) = text_size(length(lab), sz, rot)

# account for the size/length/rotation of tick labels
function tick_padding(axis::Axis)
    ticks = get_ticks(axis)
    if ticks == nothing
        0mm
    else
        vals, labs = ticks
        isempty(labs) && return 0mm
        # ptsz = axis[:tickfont].pointsize * pt
        longest_label = maximum(length(lab) for lab in labs)

        # generalize by "rotating" y labels
        rot = axis[:rotation] + (axis[:letter] == :y ? 90 : 0)

        # # we need to compute the size of the ticks generically
        # # this means computing the bounding box and then getting the width/height
        # labelwidth = 0.8longest_label * ptsz
        #
        #
        # # now compute the generalized "height" after rotation as the "opposite+adjacent" of 2 triangles
        # hgt = abs(sind(rot)) * labelwidth + abs(cosd(rot)) * ptsz + 1mm
        # hgt

        # get the height of the rotated label
        text_size(longest_label, axis[:tickfontsize], rot)[2]
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


mutable struct CurrentBackend
  sym::Symbol
  pkg::AbstractBackend
end
CurrentBackend(sym::Symbol) = CurrentBackend(sym, _backend_instance(sym))

# ---------------------------------------------------------

function pickDefaultBackend()
    env_default = get(ENV, "PLOTS_DEFAULT_BACKEND", "")
    if env_default != ""
        sym = Symbol(lowercase(env_default))
        if sym in _backends
            if sym in _initialized_backends
                return backend(sym)
            else
                @warn("You have set `PLOTS_DEFAULT_BACKEND=$env_default` but `$(backend_package_name(sym))` is not loaded.")
            end
        else
            @warn("You have set PLOTS_DEFAULT_BACKEND=$env_default but it is not a valid backend package.  Choose from:\n\t" *
                 join(sort(_backends), "\n\t"))
        end
    end

    # the ordering/inclusion of this package list is my semi-arbitrary guess at
    # which one someone will want to use if they have the package installed...accounting for
    # features, speed, and robustness
    # for pkgstr in ("GR", "PyPlot", "PlotlyJS", "PGFPlots", "UnicodePlots", "InspectDR")
    #     if pkgstr in keys(Pkg.installed())
    #         return backend(Symbol(lowercase(pkgstr)))
    #     end
    # end

    # the default if nothing else is installed
    backend(:gr)
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

  CURRENT_BACKEND.pkg
end

"""
Set the plot backend.
"""
function backend(pkg::AbstractBackend)
    sym = backend_name(pkg)
    if sym in _initialized_backends
        CURRENT_BACKEND.sym = backend_name(pkg)
        CURRENT_BACKEND.pkg = pkg
    else
        # try
            _initialize_backend(pkg)
            push!(_initialized_backends, sym)
            CURRENT_BACKEND.sym = backend_name(pkg)
            CURRENT_BACKEND.pkg = pkg
        # catch
        #     add_backend(sym)
        # end
    end
    backend()
end

function backend(sym::Symbol)
    if sym in _backends
        backend(_backend_instance(sym))
    else
        @warn("`:$sym` is not a supported backend.")
    end
    backend()
end

const _deprecated_backends = [:qwt, :winston, :bokeh, :gadfly, :immerse, :glvisualize]

function warn_on_deprecated_backend(bsym::Symbol)
    if bsym in _deprecated_backends
        @warn("Backend $bsym has been deprecated.")
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



@init_backend PyPlot
@init_backend UnicodePlots
@init_backend Plotly
@init_backend PlotlyJS
@init_backend GR
@init_backend PGFPlots
@init_backend InspectDR
@init_backend HDF5

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


################################################################################
# initialize the backends

function _initialize_backend(pkg::AbstractBackend)
    sym = backend_package_name(pkg)
    @eval Main begin
        import $sym
        export $sym
    end
end

_initialize_backend(pkg::GRBackend) = nothing

_initialize_backend(pkg::PlotlyBackend) = nothing


function add_backend_string(pkg::AbstractBackend)
    sym = backend_package_name(pkg)
    """
    using Pkg
    Pkg.add("$sym")
    """
end

# ------------------------------------------------------------------------------
# gr

const _gr_attr = merge_with_base_supported([
    :annotations,
    :background_color_legend, :background_color_inside, :background_color_outside,
    :foreground_color_legend, :foreground_color_grid, :foreground_color_axis,
    :foreground_color_text, :foreground_color_border,
    :label,
    :seriescolor, :seriesalpha,
    :linecolor, :linestyle, :linewidth, :linealpha,
    :markershape, :markercolor, :markersize, :markeralpha,
    :markerstrokewidth, :markerstrokecolor, :markerstrokealpha,
    :fillrange, :fillcolor, :fillalpha,
    :bins,
    :layout,
    :title, :window_title,
    :guide, :lims, :ticks, :scale, :flip,
    :match_dimensions,
    :titlefontfamily, :titlefontsize, :titlefonthalign, :titlefontvalign,
    :titlefontrotation, :titlefontcolor,
    :legendfontfamily, :legendfontsize, :legendfonthalign, :legendfontvalign,
    :legendfontrotation, :legendfontcolor,
    :tickfontfamily, :tickfontsize, :tickfonthalign, :tickfontvalign,
    :tickfontrotation, :tickfontcolor,
    :guidefontfamily, :guidefontsize, :guidefonthalign, :guidefontvalign,
    :guidefontrotation, :guidefontcolor,
    :grid, :gridalpha, :gridstyle, :gridlinewidth,
    :legend, :legendtitle, :colorbar, :colorbar_title,
    :fill_z, :line_z, :marker_z, :levels,
    :ribbon, :quiver,
    :orientation,
    :overwrite_figure,
    :polar,
    :aspect_ratio,
    :normalize, :weights,
    :inset_subplots,
    :bar_width,
    :arrow,
    :framestyle,
    :tick_direction,
    :camera,
    :contour_labels,
])
const _gr_seriestype = [
    :path, :scatter, :straightline,
    :heatmap, :pie, :image,
    :contour, :path3d, :scatter3d, :surface, :wireframe,
    :shape
]
const _gr_style = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]
const _gr_marker = _allMarkers
const _gr_scale = [:identity, :log10]
is_marker_supported(::GRBackend, shape::Shape) = true

function add_backend_string(::GRBackend)
    """
    Pkg.add("GR")
    Pkg.build("GR")
    """
end

# ------------------------------------------------------------------------------
# plotly

const _plotly_attr = merge_with_base_supported([
    :annotations,
    :background_color_legend, :background_color_inside, :background_color_outside,
    :foreground_color_legend, :foreground_color_guide,
    :foreground_color_grid, :foreground_color_axis,
    :foreground_color_text, :foreground_color_border,
    :foreground_color_title,
    :label,
    :seriescolor, :seriesalpha,
    :linecolor, :linestyle, :linewidth, :linealpha,
    :markershape, :markercolor, :markersize, :markeralpha,
    :markerstrokewidth, :markerstrokecolor, :markerstrokealpha, :markerstrokestyle,
    :fillrange, :fillcolor, :fillalpha,
    :bins,
    :title, :title_location,
    :titlefontfamily, :titlefontsize, :titlefonthalign, :titlefontvalign,
    :titlefontcolor,
    :legendfontfamily, :legendfontsize, :legendfontcolor,
    :tickfontfamily, :tickfontsize, :tickfontcolor,
    :guidefontfamily, :guidefontsize, :guidefontcolor,
    :window_title,
    :guide, :lims, :ticks, :scale, :flip, :rotation,
    :tickfont, :guidefont, :legendfont,
    :grid, :gridalpha, :gridlinewidth,
    :legend, :colorbar, :colorbar_title,
    :marker_z, :fill_z, :line_z, :levels,
    :ribbon, :quiver,
    :orientation,
    # :overwrite_figure,
    :polar,
    :normalize, :weights,
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
  ])

const _plotly_seriestype = [
    :path, :scatter, :pie, :heatmap,
    :contour, :surface, :wireframe, :path3d, :scatter3d, :shape, :scattergl,
    :straightline
]
const _plotly_style = [:auto, :solid, :dash, :dot, :dashdot]
const _plotly_marker = [
    :none, :auto, :circle, :rect, :diamond, :utriangle, :dtriangle,
    :cross, :xcross, :pentagon, :hexagon, :octagon, :vline, :hline
]
const _plotly_scale = [:identity, :log10]

# ------------------------------------------------------------------------------
# pgfplots

function add_backend_string(::PGFPlotsBackend)
    """
    using Pkg
    Pkg.add("PGFPlots")
    Pkg.build("PGFPlots")
    """
end

const _pgfplots_attr = merge_with_base_supported([
    :annotations,
    :background_color_legend,
    :background_color_inside,
    # :background_color_outside,
    # :foreground_color_legend,
    :foreground_color_grid, :foreground_color_axis,
    :foreground_color_text, :foreground_color_border,
    :label,
    :seriescolor, :seriesalpha,
    :linecolor, :linestyle, :linewidth, :linealpha,
    :markershape, :markercolor, :markersize, :markeralpha,
    :markerstrokewidth, :markerstrokecolor, :markerstrokealpha, :markerstrokestyle,
    :fillrange, :fillcolor, :fillalpha,
    :bins,
    # :bar_width, :bar_edges,
    :title,
    # :window_title,
    :guide, :guide_position, :lims, :ticks, :scale, :flip, :rotation,
    :tickfont, :guidefont, :legendfont,
    :grid, :legend,
    :colorbar, :colorbar_title,
    :fill_z, :line_z, :marker_z, :levels,
    # :ribbon, :quiver, :arrow,
    # :orientation,
    # :overwrite_figure,
    :polar,
    # :normalize, :weights, :contours,
    :aspect_ratio,
    # :match_dimensions,
    :tick_direction,
    :framestyle,
    :camera,
    :contour_labels,
])
const _pgfplots_seriestype = [:path, :path3d, :scatter, :steppre, :stepmid, :steppost, :histogram2d, :ysticks, :xsticks, :contour, :shape, :straightline,]
const _pgfplots_style = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]
const _pgfplots_marker = [:none, :auto, :circle, :rect, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star5, :pentagon, :hline] #vcat(_allMarkers, Shape)
const _pgfplots_scale = [:identity, :ln, :log2, :log10]

# ------------------------------------------------------------------------------
# plotlyjs

function _initialize_backend(pkg::PlotlyJSBackend)
    sym = backend_package_name(pkg)
    @eval Main begin
        import PlotlyJS, ORCA
        export PlotlyJS
    end
end

function add_backend_string(::PlotlyJSBackend)
    """
    using Pkg
    Pkg.add(["PlotlyJS", "Blink", "ORCA"])
    import Blink
    Blink.AtomShell.install()
    """
end

const _plotlyjs_attr        = _plotly_attr
const _plotlyjs_seriestype  = _plotly_seriestype
const _plotlyjs_style       = _plotly_style
const _plotlyjs_marker      = _plotly_marker
const _plotlyjs_scale       = _plotly_scale

# ------------------------------------------------------------------------------
# pyplot

function _initialize_backend(::PyPlotBackend)
    @eval Main begin
        import PyPlot

        export PyPlot

        # we don't want every command to update the figure
        PyPlot.ioff()
    end
end

function add_backend_string(::PyPlotBackend)
    """
    using Pkg
    withenv("PYTHON" => "") do
        Pkg.add("PyPlot")
        Pkg.build("PyPlot")
    end
    """
end

const _pyplot_attr = merge_with_base_supported([
    :annotations,
    :background_color_legend, :background_color_inside, :background_color_outside,
    :foreground_color_grid, :foreground_color_legend, :foreground_color_title,
    :foreground_color_axis, :foreground_color_border, :foreground_color_guide, :foreground_color_text,
    :label,
    :linecolor, :linestyle, :linewidth, :linealpha,
    :markershape, :markercolor, :markersize, :markeralpha,
    :markerstrokewidth, :markerstrokecolor, :markerstrokealpha,
    :fillrange, :fillcolor, :fillalpha,
    :bins, :bar_width, :bar_edges, :bar_position,
    :title, :title_location, :titlefont,
    :window_title,
    :guide, :guide_position, :lims, :ticks, :scale, :flip, :rotation,
    :titlefontfamily, :titlefontsize, :titlefontcolor,
    :legendfontfamily, :legendfontsize, :legendfontcolor,
    :tickfontfamily, :tickfontsize, :tickfontcolor,
    :guidefontfamily, :guidefontsize, :guidefontcolor,
    :grid, :gridalpha, :gridstyle, :gridlinewidth,
    :legend, :legendtitle, :colorbar,
    :marker_z, :line_z, :fill_z,
    :levels,
    :ribbon, :quiver, :arrow,
    :orientation,
    :overwrite_figure,
    :polar,
    :normalize, :weights,
    :contours, :aspect_ratio,
    :match_dimensions,
    :clims,
    :inset_subplots,
    :dpi,
    :colorbar_title,
    :stride,
    :framestyle,
    :tick_direction,
    :camera,
    :contour_labels,
  ])
const _pyplot_seriestype = [
        :path, :steppre, :steppost, :shape, :straightline,
        :scatter, :hexbin, #:histogram2d, :histogram,
        # :bar,
        :heatmap, :pie, :image,
        :contour, :contour3d, :path3d, :scatter3d, :surface, :wireframe
    ]
const _pyplot_style = [:auto, :solid, :dash, :dot, :dashdot]
const _pyplot_marker = vcat(_allMarkers, :pixel)
const _pyplot_scale = [:identity, :ln, :log2, :log10]

# ------------------------------------------------------------------------------
# unicodeplots

function add_backend_string(::UnicodePlotsBackend)
    """
    using Pkg
    Pkg.add("UnicodePlots")
    Pkg.build("UnicodePlots")
    """
end

const _unicodeplots_attr = merge_with_base_supported([
    :label,
    :legend,
    :seriescolor,
    :seriesalpha,
    :linestyle,
    :markershape,
    :bins,
    :title,
    :guide, :lims,
  ])
const _unicodeplots_seriestype = [
    :path, :scatter, :straightline,
    # :bar,
    :shape,
    :histogram2d,
    :spy
]
const _unicodeplots_style = [:auto, :solid]
const _unicodeplots_marker = [:none, :auto, :circle]
const _unicodeplots_scale = [:identity]

# ------------------------------------------------------------------------------
# hdf5

const _hdf5_attr = merge_with_base_supported([
    :annotations,
    :background_color_legend, :background_color_inside, :background_color_outside,
    :foreground_color_grid, :foreground_color_legend, :foreground_color_title,
    :foreground_color_axis, :foreground_color_border, :foreground_color_guide, :foreground_color_text,
    :label,
    :linecolor, :linestyle, :linewidth, :linealpha,
    :markershape, :markercolor, :markersize, :markeralpha,
    :markerstrokewidth, :markerstrokecolor, :markerstrokealpha,
    :fillrange, :fillcolor, :fillalpha,
    :bins, :bar_width, :bar_edges, :bar_position,
    :title, :title_location, :titlefont,
    :window_title,
    :guide, :lims, :ticks, :scale, :flip, :rotation,
    :tickfont, :guidefont, :legendfont,
    :grid, :legend, :colorbar,
    :marker_z, :line_z, :fill_z,
    :levels,
    :ribbon, :quiver, :arrow,
    :orientation,
    :overwrite_figure,
    :polar,
    :normalize, :weights,
    :contours, :aspect_ratio,
    :match_dimensions,
    :clims,
    :inset_subplots,
    :dpi,
    :colorbar_title,
  ])
const _hdf5_seriestype = [
        :path, :steppre, :steppost, :shape, :straightline,
        :scatter, :hexbin, #:histogram2d, :histogram,
        # :bar,
        :heatmap, :pie, :image,
        :contour, :contour3d, :path3d, :scatter3d, :surface, :wireframe
    ]
const _hdf5_style = [:auto, :solid, :dash, :dot, :dashdot]
const _hdf5_marker = vcat(_allMarkers, :pixel)
const _hdf5_scale = [:identity, :ln, :log2, :log10]

# ------------------------------------------------------------------------------
# inspectdr

const _inspectdr_attr = merge_with_base_supported([
    :annotations,
    :background_color_legend, :background_color_inside, :background_color_outside,
    # :foreground_color_grid,
    :foreground_color_legend, :foreground_color_title,
    :foreground_color_axis, :foreground_color_border, :foreground_color_guide, :foreground_color_text,
    :label,
    :seriescolor, :seriesalpha,
    :linecolor, :linestyle, :linewidth, :linealpha,
    :markershape, :markercolor, :markersize, :markeralpha,
    :markerstrokewidth, :markerstrokecolor, :markerstrokealpha,
    :markerstrokestyle, #Causes warning not to have it... what is this?
    :fillcolor, :fillalpha, #:fillrange,
#    :bins, :bar_width, :bar_edges, :bar_position,
    :title, :title_location,
    :window_title,
    :guide, :lims, :scale, #:ticks, :flip, :rotation,
    :titlefontfamily, :titlefontsize, :titlefontcolor,
    :legendfontfamily, :legendfontsize, :legendfontcolor,
    :tickfontfamily, :tickfontsize, :tickfontcolor,
    :guidefontfamily, :guidefontsize, :guidefontcolor,
    :grid, :legend, #:colorbar,
#    :marker_z,
#    :line_z,
#    :levels,
 #   :ribbon, :quiver, :arrow,
#    :orientation,
    :overwrite_figure,
    :polar,
#    :normalize, :weights,
#    :contours, :aspect_ratio,
    :match_dimensions,
#    :clims,
#    :inset_subplots,
    :dpi,
#    :colorbar_title,
  ])
const _inspectdr_style = [:auto, :solid, :dash, :dot, :dashdot]
const _inspectdr_seriestype = [
        :path, :scatter, :shape, :straightline, #, :steppre, :steppost
    ]
#see: _allMarkers, _shape_keys
const _inspectdr_marker = Symbol[
    :none, :auto,
    :circle, :rect, :diamond,
    :cross, :xcross,
    :utriangle, :dtriangle, :rtriangle, :ltriangle,
    :pentagon, :hexagon, :heptagon, :octagon,
    :star4, :star5, :star6, :star7, :star8,
    :vline, :hline, :+, :x,
]

const _inspectdr_scale = [:identity, :ln, :log2, :log10]
