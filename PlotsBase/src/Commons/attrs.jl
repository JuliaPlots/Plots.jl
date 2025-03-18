makeplural(s::Symbol) = last(string(s)) == 's' ? s : Symbol(string(s, "s"))
make_non_underscore(s::Symbol) = Symbol(replace(string(s), "_" => ""))

const _keyAliases = Dict{Symbol,Symbol}()

function add_aliases(sym::Symbol, aliases::Symbol...)
    for alias ∈ aliases
        (haskey(_keyAliases, alias) || alias ≡ sym) && return
        _keyAliases[alias] = sym
    end
    nothing
end

function add_axes_aliases(sym::Symbol, aliases::Symbol...; generic::Bool = true)
    sym in keys(_axis_defaults) || throw(ArgumentError("Invalid `$sym`"))
    generic && add_aliases(sym, aliases...)
    for letter ∈ (:x, :y, :z)
        add_aliases(Symbol(letter, sym), (Symbol(letter, a) for a ∈ aliases)...)
    end
end

function add_non_underscore_aliases!(aliases::Dict{Symbol,Symbol})
    for (k, v) ∈ aliases
        if '_' in string(k)
            aliases[make_non_underscore(k)] = v
        end
    end
end

replaceAlias!(plotattributes::AKW, k::Symbol, aliases::Dict{Symbol,Symbol}) =
    if haskey(aliases, k)
        plotattributes[aliases[k]] = RecipesPipeline.pop_kw!(plotattributes, k)
    end

replaceAliases!(plotattributes::AKW, aliases::Dict{Symbol,Symbol}) =
    foreach(k -> replaceAlias!(plotattributes, k, aliases), collect(keys(plotattributes)))

macro attributes(expr::Expr)
    RecipesBase.process_recipe_body!(expr)
    expr
end

# ------------------------------------------------------------

const _all_axes = [:auto, :left, :right]
const _axes_aliases = Dict{Symbol,Symbol}(:a => :auto, :l => :left, :r => :right)

const _3dTypes = [:path3d, :scatter3d, :surface, :wireframe, :contour3d, :volume, :mesh3d]
const _all_seriestypes = vcat(
    [
        :none,
        :line,
        :path,
        :steppre,
        :stepmid,
        :steppost,
        :sticks,
        :scatter,
        :heatmap,
        :hexbin,
        :barbins,
        :barhist,
        :histogram,
        :scatterbins,
        :scatterhist,
        :stepbins,
        :stephist,
        :bins2d,
        :histogram2d,
        :histogram3d,
        :density,
        :bar,
        :hline,
        :vline,
        :contour,
        :pie,
        :shape,
        :image,
    ],
    _3dTypes,
)

const _z_colored_series = [:contour, :contour3d, :heatmap, :histogram2d, :surface, :hexbin]

const _typeAliases = Dict{Symbol,Symbol}(
    :n             => :none,
    :no            => :none,
    :l             => :line,
    :p             => :path,
    :stepinv       => :steppre,
    :stepsinv      => :steppre,
    :stepinverted  => :steppre,
    :stepsinverted => :steppre,
    :step          => :steppost,
    :steps         => :steppost,
    :stair         => :steppost,
    :stairs        => :steppost,
    :stem          => :sticks,
    :stems         => :sticks,
    :dots          => :scatter,
    :pdf           => :density,
    :contours      => :contour,
    :line3d        => :path3d,
    :surf          => :surface,
    :wire          => :wireframe,
    :shapes        => :shape,
    :poly          => :shape,
    :polygon       => :shape,
    :box           => :boxplot,
    :velocity      => :quiver,
    :vectorfield   => :quiver,
    :gradient      => :quiver,
    :img           => :image,
    :imshow        => :image,
    :imagesc       => :image,
    :hist          => :histogram,
    :hist2d        => :histogram2d,
    :bezier        => :curves,
    :bezier_curves => :curves,
)

add_non_underscore_aliases!(_typeAliases)

const _histogram_like = [:histogram, :barhist, :barbins]
const _line_like = [:line, :path, :steppre, :stepmid, :steppost]
const _surface_like =
    [:contour, :contourf, :contour3d, :heatmap, :surface, :wireframe, :image]

like_histogram(seriestype::Symbol) = seriestype in _histogram_like
like_line(seriestype::Symbol)      = seriestype in _line_like
like_surface(seriestype::Symbol)   = RecipesPipeline.is_surface(seriestype)

# ------------------------------------------------------------

const _all_styles = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]
const _styleAliases = Dict{Symbol,Symbol}(
    :a   => :auto,
    :s   => :solid,
    :d   => :dash,
    :dd  => :dashdot,
    :ddd => :dashdotdot,
)

const _shape_keys = Symbol[
    :circle,
    :rect,
    :diamond,
    :hexagon,
    :cross,
    :xcross,
    :utriangle,
    :dtriangle,
    :rtriangle,
    :ltriangle,
    :pentagon,
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
    :uparrow,
    :downarrow,
]

const _all_markers = vcat(:none, :auto, _shape_keys)  # sort(collect(keys(_shapes))))
const _marker_aliases = Dict{Symbol,Symbol}(
    :n             => :none,
    :no            => :none,
    :a             => :auto,
    :ellipse       => :circle,
    :c             => :circle,
    :circ          => :circle,
    :square        => :rect,
    :sq            => :rect,
    :r             => :rect,
    :d             => :diamond,
    :^             => :utriangle,
    :ut            => :utriangle,
    :utri          => :utriangle,
    :uptri         => :utriangle,
    :uptriangle    => :utriangle,
    :v             => :dtriangle,
    :V             => :dtriangle,
    :dt            => :dtriangle,
    :dtri          => :dtriangle,
    :downtri       => :dtriangle,
    :downtriangle  => :dtriangle,
    :>             => :rtriangle,
    :rt            => :rtriangle,
    :rtri          => :rtriangle,
    :righttri      => :rtriangle,
    :righttriangle => :rtriangle,
    :<             => :ltriangle,
    :lt            => :ltriangle,
    :ltri          => :ltriangle,
    :lighttri      => :ltriangle,
    :lighttriangle => :ltriangle,
    # :+           => :cross,
    :plus => :cross,
    # :x           => :xcross,
    :X     => :xcross,
    :star  => :star5,
    :s     => :star5,
    :star1 => :star5,
    :s2    => :star8,
    :star2 => :star8,
    :p     => :pentagon,
    :pent  => :pentagon,
    :h     => :hexagon,
    :hex   => :hexagon,
    :hep   => :heptagon,
    :o     => :octagon,
    :oct   => :octagon,
    :spike => :vline,
)

const _position_aliases = Dict{Symbol,Symbol}(
    :top_left      => :topleft,
    :tl            => :topleft,
    :top_center    => :topcenter,
    :tc            => :topcenter,
    :top_right     => :topright,
    :tr            => :topright,
    :bottom_left   => :bottomleft,
    :bl            => :bottomleft,
    :bottom_center => :bottomcenter,
    :bc            => :bottomcenter,
    :bottom_right  => :bottomright,
    :br            => :bottomright,
)

const _all_grid_syms = [
    :x,
    :y,
    :z,
    :xy,
    :xz,
    :yx,
    :yz,
    :zx,
    :zy,
    :xyz,
    :xzy,
    :yxz,
    :yzx,
    :zxy,
    :zyx,
    :all,
    :both,
    :on,
    :yes,
    :show,
    :none,
    :off,
    :no,
    :hide,
]
const _all_grid_attrs = [_all_grid_syms; string.(_all_grid_syms); nothing]
hasgrid(arg::Nothing, letter) = false
hasgrid(arg::Bool, letter) = arg
function hasgrid(arg::Symbol, letter)
    if arg in _all_grid_syms
        arg in (:all, :both, :on) || occursin(string(letter), string(arg))
    else
        @warn "Unknown grid argument $arg; $(get_attr_symbol(letter, :grid)) was set to `true` instead."
        true
    end
end
hasgrid(arg::AbstractString, letter) = hasgrid(Symbol(arg), letter)

const _all_showaxis_syms = [
    :x,
    :y,
    :z,
    :xy,
    :xz,
    :yx,
    :yz,
    :zx,
    :zy,
    :xyz,
    :xzy,
    :yxz,
    :yzx,
    :zxy,
    :zyx,
    :all,
    :both,
    :on,
    :yes,
    :show,
    :off,
    :no,
    :hide,
]
const _all_showaxis_attrs = [_all_grid_syms; string.(_all_grid_syms)]
showaxis(arg::Nothing, letter) = false
showaxis(arg::Bool, letter) = arg
function showaxis(arg::Symbol, letter)
    if arg in _all_grid_syms
        arg in (:all, :both, :on, :yes) || occursin(string(letter), string(arg))
    else
        @warn "Unknown showaxis argument $arg; $(get_attr_symbol(letter, :showaxis)) was set to `true` instead."
        true
    end
end
showaxis(arg::AbstractString, letter) = hasgrid(Symbol(arg), letter)

const _all_framestyles = [:box, :semi, :axes, :origin, :zerolines, :grid, :none]
const _framestyle_aliases = Dict{Symbol,Symbol}(
    :frame           => :box,
    :border          => :box,
    :on              => :box,
    :transparent     => :semi,
    :semitransparent => :semi,
)

const _bar_width = 0.8
# -----------------------------------------------------------------------------

const _series_defaults = KW(
    :label              => :auto,
    :colorbar_entry     => true,
    :seriescolor        => :auto,
    :seriesalpha        => nothing,
    :seriestype         => :path,
    :linestyle          => :solid,
    :linewidth          => :auto,
    :linecolor          => :auto,
    :linealpha          => nothing,
    :fillrange          => nothing,   # ribbons, areas, etc
    :fillcolor          => :match,
    :fillalpha          => nothing,
    :fillstyle          => nothing,
    :markershape        => :none,
    :markercolor        => :match,
    :markeralpha        => nothing,
    :markersize         => 4,
    :markerstrokestyle  => :solid,
    :markerstrokewidth  => 1,
    :markerstrokecolor  => :match,
    :markerstrokealpha  => nothing,
    :bins               => :auto,        # number of bins for hists
    :smooth             => false,     # regression line?
    :group              => nothing,   # groupby vector
    :x                  => nothing,
    :y                  => nothing,
    :z                  => nothing,   # depth for contour, surface, etc
    :marker_z           => nothing,   # value for color scale
    :line_z             => nothing,
    :fill_z             => nothing,
    :levels             => 15,
    :bar_position       => :overlay,  # for bar plots and histograms: could also be stack (stack up) or dodge (side by side)
    :bar_width          => nothing,
    :bar_edges          => false,
    :xerror             => nothing,
    :yerror             => nothing,
    :zerror             => nothing,
    :ribbon             => nothing,
    :quiver             => nothing,
    :arrow              => nothing,   # allows for adding arrows to line/path... call `arrow(args...)`
    :normalize          => false,     # do we want a normalized histogram?
    :weights            => nothing,   # optional weights for histograms (1D and 2D)
    :show_empty_bins    => false,     # should empty bins in 2D histogram be colored as zero (otherwise they are transparent)
    :contours           => false,     # add contours to 3d surface and wireframe plots
    :contour_labels     => false,
    :subplot            => :auto,     # which subplot(s) does this series belong to?
    :series_annotations => nothing,       # a list of annotations which apply to the coordinates of this series
    :primary            => true,     # when true, this "counts" as a series for color selection, etc.  the main use is to allow
    #     one logical series to be broken up (path and markers, for example)
    :hover        => nothing,  # text to display when hovering over the data points
    :stride       => (1, 1),    # array stride for wireframe/surface, the first element is the row stride and the second is the column stride.
    :connections  => nothing,  # tuple of arrays to specify connectivity of a 3d mesh
    :z_order      => :front, # one of :front, :back or integer in 1:length(sp.series_list)
    :permute      => :none, # tuple of two symbols to be permuted
    :extra_kwargs => Dict(),
)

const _plot_defaults = KW(
    :plot_title               => "",
    :plot_titleindex          => 0,
    :plot_titlefontsize       => 16,
    :plot_titlelocation       => :center,           # also :left or :right
    :plot_titlefontfamily     => :match,
    :plot_titlefonthalign     => :hcenter,
    :plot_titlefontvalign     => :vcenter,
    :plot_titlefontrotation   => 0.0,
    :plot_titlefontcolor      => :match,
    :plot_titlevspan          => 0.05,              # vertical span of the plot title, here 5%
    :background_color         => colorant"white",   # default for all backgrounds,
    :background_color_outside => :match,            # background outside grid,
    :foreground_color         => :auto,             # default for all foregrounds, and title color,
    :fontfamily               => "sans-serif",
    :size                     => (600, 400),
    :pos                      => (0, 0),
    :window_title             => "Plots.jl",
    :show                     => false,
    :layout                   => 1,
    :link                     => :none,
    :overwrite_figure         => true,
    :html_output_format       => :auto,
    :tex_output_standalone    => false,
    :inset_subplots           => nothing,   # optionally pass a vector of (parent,bbox) tuples which are
    # the parent layout and the relative bounding box of inset subplots
    :dpi                 => DPI,        # dots per inch for images, etc
    :thickness_scaling   => 1,
    :display_type        => :auto,
    :warn_on_unsupported => true,
    :safe_saving         => true,
    :extra_plot_kwargs   => Dict(),
    :extra_kwargs        => :series,    # directs collection of extra_kwargs
)

const _subplot_defaults = KW(
    :title => "",
    :titlelocation => :center,           # also :left or :right
    :fontfamily_subplot => :match,
    :titlefontfamily => :match,
    :titlefontsize => 14,
    :titlefonthalign => :hcenter,
    :titlefontvalign => :vcenter,
    :titlefontrotation => 0.0,
    :titlefontcolor => :match,
    :background_color_subplot => :match,            # default for other bg colors... match takes plot default
    :background_color_inside => :match,            # background inside grid
    :foreground_color_subplot => :match,            # default for other fg colors... match takes plot default
    :foreground_color_title => :match,            # title color
    :color_palette => :auto,
    :colorbar => :legend,
    :clims => :auto,
    :colorbar_fontfamily => :match,
    :colorbar_ticks => :auto,
    :colorbar_tickfontfamily => :match,
    :colorbar_tickfontsize => 8,
    :colorbar_tickfonthalign => :hcenter,
    :colorbar_tickfontvalign => :vcenter,
    :colorbar_tickfontrotation => 0.0,
    :colorbar_tickfontcolor => :match,
    :colorbar_scale => :identity,
    :colorbar_formatter => :auto,
    :colorbar_discrete_values => [],
    :colorbar_continuous_values => zeros(0),
    :annotations => [],                # annotation tuples... list of (x,y,annotation)
    :annotationfontfamily => :match,
    :annotationfontsize => 14,
    :annotationhalign => :hcenter,
    :annotationvalign => :vcenter,
    :annotationrotation => 0.0,
    :annotationcolor => :match,
    :projection => :none,             # can also be :polar or :3d
    :projection_type => :auto,        # can also be :ortho(graphic) or :persp(ective)
    :aspect_ratio => :auto,           # choose from :none or :equal
    :margin => 1mm,
    :left_margin => :match,
    :top_margin => :match,
    :right_margin => :match,
    :bottom_margin => :match,
    :subplot_index => -1,
    :colorbar_title => "",
    :colorbar_titlefontsize => 10,
    :colorbar_title_location => :center,           # also :left or :right
    :colorbar_fontfamily => :match,
    :colorbar_titlefontfamily => :match,
    :colorbar_titlefonthalign => :hcenter,
    :colorbar_titlefontvalign => :vcenter,
    :colorbar_titlefontrotation => 0.0,
    :colorbar_titlefontcolor => :match,
    :framestyle => :axes,
    :camera => (30, 30),
    :extra_kwargs => Dict(),
)

const _axis_defaults = KW(
    :guide                       => "",
    :guide_position              => :auto,
    :lims                        => :auto,
    :ticks                       => :auto,
    :scale                       => :identity,
    :rotation                    => 0,
    :flip                        => false,
    :link                        => [],
    :tickfontfamily              => :match,
    :tickfontsize                => 8,
    :tickfonthalign              => :hcenter,
    :tickfontvalign              => :vcenter,
    :tickfontrotation            => 0.0,
    :tickfontcolor               => :match,
    :guidefontfamily             => :match,
    :guidefontsize               => 11,
    :guidefonthalign             => :hcenter,
    :guidefontvalign             => :vcenter,
    :guidefontrotation           => 0.0,
    :guidefontcolor              => :match,
    :foreground_color_axis       => :match,            # axis border/tick colors,
    :foreground_color_border     => :match,            # plot area border/spines,
    :foreground_color_text       => :match,            # tick text color,
    :foreground_color_guide      => :match,            # guide text color,
    :discrete_values             => [],
    :formatter                   => :auto,
    :mirror                      => false,
    :grid                        => true,
    :foreground_color_grid       => :match,            # grid color
    :gridalpha                   => 0.1,
    :gridstyle                   => :solid,
    :gridlinewidth               => 0.5,
    :foreground_color_minor_grid => :match,            # grid color
    :minorgridalpha              => 0.05,
    :minorgridstyle              => :solid,
    :minorgridlinewidth          => 0.5,
    :tick_direction              => :in,
    :minorticks                  => :auto,
    :minorgrid                   => false,
    :showaxis                    => true,
    :widen                       => :auto,
    :draw_arrow                  => false,
    :unitformat                  => :round,
)

# add defaults for the letter versions
const _axis_defaults_byletter = KW()

reset_axis_defaults_byletter!() =
    for letter ∈ (:x, :y, :z)
        _axis_defaults_byletter[letter] = KW()
        for (k, v) ∈ _axis_defaults
            _axis_defaults_byletter[letter][k] = v
        end
    end
reset_axis_defaults_byletter!()

const _suppress_warnings = Set{Symbol}([
    :x_discrete_indices,
    :y_discrete_indices,
    :z_discrete_indices,
    :subplot,
    :subplot_index,
    :series_plotindex,
    :series_index,
    :link,
    :plot_object,
    :primary,
    :smooth,
    :relative_bbox,
    :force_minpad,
    :x_extrema,
    :y_extrema,
    :z_extrema,
])

const _internal_attrs = [
    :plot_object,
    :series_plotindex,
    :series_index,
    :markershape_to_add,
    :letter,
    :idxfilter,
]

const _axis_attrs = Set(keys(_axis_defaults))
const _series_attrs = Set(keys(_series_defaults))
const _subplot_attrs = Set(keys(_subplot_defaults))
const _plot_attrs = Set(keys(_plot_defaults))

const _magic_axis_attrs = [:axis, :tickfont, :guidefont, :grid, :minorgrid]
const _magic_subplot_attrs =
    [:title_font, :legend_font, :legend_title_font, :plot_title_font, :colorbar_titlefont]
const _magic_series_attrs = [:line, :marker, :fill]
const _all_magic_attrs =
    Set(union(_magic_axis_attrs, _magic_series_attrs, _magic_subplot_attrs))

const _all_axis_attrs = union(_axis_attrs, _magic_axis_attrs)
const _lettered_all_axis_attrs =
    Set([Symbol(letter, kw) for letter ∈ (:x, :y, :z) for kw ∈ _all_axis_attrs])
const _all_subplot_attrs = union(_subplot_attrs, _magic_subplot_attrs)
const _all_series_attrs = union(_series_attrs, _magic_series_attrs)
const _all_plot_attrs = _plot_attrs

const _all_attrs =
    union(_lettered_all_axis_attrs, _all_subplot_attrs, _all_series_attrs, _all_plot_attrs)

const _deprecated_attributes = Dict{Symbol,Symbol}()
const _all_defaults = KW[_series_defaults, _plot_defaults, _subplot_defaults]

const _initial_defaults = deepcopy(_all_defaults)
const _initial_axis_defaults = deepcopy(_axis_defaults)

# to be able to reset font sizes to initial values
const _initial_plt_fontsizes =
    Dict(:plot_titlefontsize => _plot_defaults[:plot_titlefontsize])

const _initial_sp_fontsizes = Dict(
    :titlefontsize => _subplot_defaults[:titlefontsize],
    :annotationfontsize => _subplot_defaults[:annotationfontsize],
    :colorbar_tickfontsize => _subplot_defaults[:colorbar_tickfontsize],
    :colorbar_titlefontsize => _subplot_defaults[:colorbar_titlefontsize],
)

const _initial_ax_fontsizes = Dict(
    :tickfontsize  => _axis_defaults[:tickfontsize],
    :guidefontsize => _axis_defaults[:guidefontsize],
)

const _initial_fontsizes =
    merge(_initial_plt_fontsizes, _initial_sp_fontsizes, _initial_ax_fontsizes)

const _base_supported_attrs = [
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
    v = vcat(v, _base_supported_attrs)
    for vi ∈ v
        if haskey(_axis_defaults, vi)
            for letter ∈ (:x, :y, :z)
                push!(v, get_attr_symbol(letter, vi))
            end
        end
    end
    Set(v)
end

is_subplot_attrs(k) = k in _all_subplot_attrs
is_series_attrs(k) = k in _all_series_attrs
is_axis_attrs(k) = Symbol(chop(string(k); head = 1, tail = 0)) in _all_axis_attrs
is_axis_attr_noletter(k) = k in _all_axis_attrs

RecipesBase.is_key_supported(k::Symbol) = PlotsBase.is_attr_supported(k)

# -----------------------------------------------------------------------------
include("aliases.jl")
# -----------------------------------------------------------------------------

function parse_axis_kw(s::Symbol)
    s = string(s)
    for letter ∈ ('x', 'y', 'z')
        startswith(s, letter) &&
            return (Symbol(letter), Symbol(chop(s, head = 1, tail = 0)))
    end
    nothing
end

# update the defaults globally

"""
`default(key)` returns the current default value for that key.

`default(key, value)` sets the current default value for that key.

`default(; kw...)` will set the current default value for each key/value pair.

`default(plotattributes, key)` returns the key from plotattributes if it exists, otherwise `default(key)`.

"""
function default(k::Symbol)
    k = get(_keyAliases, k, k)
    for defaults ∈ _all_defaults
        haskey(defaults, k) && return defaults[k]
    end
    haskey(_axis_defaults, k) && return _axis_defaults[k]
    if (axis_k = parse_axis_kw(k)) ≢ nothing
        letter, key = axis_k
        return _axis_defaults_byletter[letter][key]
    end
    k ≡ :letter && return k # for type recipe processing
    missing
end

function default(k::Symbol, v)
    k = get(_keyAliases, k, k)
    for defaults ∈ _all_defaults
        if haskey(defaults, k)
            defaults[k] = v
            return v
        end
    end
    if haskey(_axis_defaults, k)
        _axis_defaults[k] = v
        return v
    end
    if (axis_k = parse_axis_kw(k)) ≢ nothing
        letter, key = axis_k
        _axis_defaults_byletter[letter][key] = v
        return v
    end
    k in _suppress_warnings || error("Unknown key: ", k)
end

function default(; reset = true, kw...)
    (reset && isempty(kw)) && reset_defaults()
    kw = KW(kw)
    preprocess_attributes!(kw)
    for (k, v) ∈ kw
        default(k, v)
    end
end

default(plotattributes::AKW, k::Symbol) = get(plotattributes, k, default(k))

function reset_defaults()
    foreach(merge!, _all_defaults, _initial_defaults)
    merge!(_axis_defaults, _initial_axis_defaults)
    PlotsBase.Fonts.resetfontsizes()
    reset_axis_defaults_byletter!()
end

# -----------------------------------------------------------------------------

# if arg is a valid color value, then set plotattributes[csym] and return true
function handle_colors!(plotattributes::AKW, arg, csym::Symbol)
    try
        plotattributes[csym] = if arg ≡ :auto
            :auto
        else
            plot_color(arg)
        end
        return true
    catch
    end
    false
end

function process_line_attr(plotattributes::AKW, arg)
    # seriestype
    if all_lineLtypes(arg)
        plotattributes[:seriestype] = arg

        # linestyle
    elseif all_styles(arg)
        plotattributes[:linestyle] = arg

    elseif typeof(arg) <: PlotsBase.Stroke
        arg.width ≡ nothing || (plotattributes[:linewidth] = arg.width)
        arg.color ≡ nothing ||
            (plotattributes[:linecolor] = arg.color ≡ :auto ? :auto : plot_color(arg.color))
        arg.alpha ≡ nothing || (plotattributes[:linealpha] = arg.alpha)
        arg.style ≡ nothing || (plotattributes[:linestyle] = arg.style)

    elseif typeof(arg) <: PlotsBase.Brush
        arg.size ≡ nothing || (plotattributes[:fillrange] = arg.size)
        arg.color ≡ nothing ||
            (plotattributes[:fillcolor] = arg.color ≡ :auto ? :auto : plot_color(arg.color))
        arg.alpha ≡ nothing || (plotattributes[:fillalpha] = arg.alpha)
        arg.style ≡ nothing || (plotattributes[:fillstyle] = arg.style)

    elseif typeof(arg) <: PlotsBase.Arrow || arg in (:arrow, :arrows)
        plotattributes[:arrow] = arg

        # linealpha
    elseif all_alphas(arg)
        plotattributes[:linealpha] = arg

        # linewidth
    elseif all_reals(arg)
        plotattributes[:linewidth] = arg

        # color
    elseif !handle_colors!(plotattributes, arg, :linecolor)
        @warn "Skipped line arg $arg."
    end
end

function process_marker_attr(plotattributes::AKW, arg)
    # markershape
    if all_shapes(arg) && !haskey(plotattributes, :markershape)
        plotattributes[:markershape] = arg

        # stroke style
    elseif all_styles(arg)
        plotattributes[:markerstrokestyle] = arg

    elseif typeof(arg) <: PlotsBase.Stroke
        arg.width ≡ nothing || (plotattributes[:markerstrokewidth] = arg.width)
        arg.color ≡ nothing || (
            plotattributes[:markerstrokecolor] =
                arg.color ≡ :auto ? :auto : plot_color(arg.color)
        )
        arg.alpha ≡ nothing || (plotattributes[:markerstrokealpha] = arg.alpha)
        arg.style ≡ nothing || (plotattributes[:markerstrokestyle] = arg.style)

    elseif typeof(arg) <: PlotsBase.Brush
        arg.size ≡ nothing || (plotattributes[:markersize] = arg.size)
        arg.color ≡ nothing || (
            plotattributes[:markercolor] =
                arg.color ≡ :auto ? :auto : plot_color(arg.color)
        )
        arg.alpha ≡ nothing || (plotattributes[:markeralpha] = arg.alpha)

        # linealpha
    elseif all_alphas(arg)
        plotattributes[:markeralpha] = arg

        # bool
    elseif typeof(arg) <: Bool
        plotattributes[:markershape] = arg ? :circle : :none

        # markersize
    elseif all_reals(arg)
        plotattributes[:markersize] = arg

        # markercolor
    elseif !handle_colors!(plotattributes, arg, :markercolor)
        @warn "Skipped marker arg $arg."
    end
end

function process_fill_attr(plotattributes::AKW, arg)
    # fr = get(plotattributes, :fillrange, 0)
    if typeof(arg) <: PlotsBase.Brush
        arg.size ≡ nothing || (plotattributes[:fillrange] = arg.size)
        arg.color ≡ nothing ||
            (plotattributes[:fillcolor] = arg.color ≡ :auto ? :auto : plot_color(arg.color))
        arg.alpha ≡ nothing || (plotattributes[:fillalpha] = arg.alpha)
        arg.style ≡ nothing || (plotattributes[:fillstyle] = arg.style)

    elseif typeof(arg) <: Bool
        plotattributes[:fillrange] = arg ? 0 : nothing

        # fillrange function
    elseif all_functionss(arg)
        plotattributes[:fillrange] = arg

        # fillalpha
    elseif all_alphas(arg)
        plotattributes[:fillalpha] = arg

        # fillrange provided as vector or number
    elseif typeof(arg) <: Union{AbstractArray{<:Real},Real}
        plotattributes[:fillrange] = arg

    elseif !handle_colors!(plotattributes, arg, :fillcolor)
        plotattributes[:fillrange] = arg
    end
    # plotattributes[:fillrange] = fr
    nothing
end

function process_grid_attr!(plotattributes::AKW, arg, letter)
    if arg in _all_grid_attrs || isa(arg, Bool)
        plotattributes[get_attr_symbol(letter, :grid)] = hasgrid(arg, letter)

    elseif all_styles(arg)
        plotattributes[get_attr_symbol(letter, :gridstyle)] = arg

    elseif typeof(arg) <: PlotsBase.Stroke
        arg.width ≡ nothing ||
            (plotattributes[get_attr_symbol(letter, :gridlinewidth)] = arg.width)
        arg.color ≡ nothing || (
            plotattributes[get_attr_symbol(letter, :foreground_color_grid)] =
                arg.color in (:auto, :match) ? :match : plot_color(arg.color)
        )
        arg.alpha ≡ nothing ||
            (plotattributes[get_attr_symbol(letter, :gridalpha)] = arg.alpha)
        arg.style ≡ nothing ||
            (plotattributes[get_attr_symbol(letter, :gridstyle)] = arg.style)

        # linealpha
    elseif all_alphas(arg)
        plotattributes[get_attr_symbol(letter, :gridalpha)] = arg

        # linewidth
    elseif all_reals(arg)
        plotattributes[get_attr_symbol(letter, :gridlinewidth)] = arg

        # color
    elseif !handle_colors!(
        plotattributes,
        arg,
        get_attr_symbol(letter, :foreground_color_grid),
    )
        @warn "Skipped grid arg $arg."
    end
end

function process_minor_grid_attr!(plotattributes::AKW, arg, letter)
    if arg in _all_grid_attrs || isa(arg, Bool)
        plotattributes[get_attr_symbol(letter, :minorgrid)] = hasgrid(arg, letter)

    elseif all_styles(arg)
        plotattributes[get_attr_symbol(letter, :minorgridstyle)] = arg
        plotattributes[get_attr_symbol(letter, :minorgrid)] = true

    elseif typeof(arg) <: PlotsBase.Stroke
        arg.width ≡ nothing ||
            (plotattributes[get_attr_symbol(letter, :minorgridlinewidth)] = arg.width)
        arg.color ≡ nothing || (
            plotattributes[get_attr_symbol(letter, :foreground_color_minor_grid)] =
                arg.color in (:auto, :match) ? :match : plot_color(arg.color)
        )
        arg.alpha ≡ nothing ||
            (plotattributes[get_attr_symbol(letter, :minorgridalpha)] = arg.alpha)
        arg.style ≡ nothing ||
            (plotattributes[get_attr_symbol(letter, :minorgridstyle)] = arg.style)
        plotattributes[get_attr_symbol(letter, :minorgrid)] = true

        # linealpha
    elseif all_alphas(arg)
        plotattributes[get_attr_symbol(letter, :minorgridalpha)] = arg
        plotattributes[get_attr_symbol(letter, :minorgrid)] = true

        # linewidth
    elseif all_reals(arg)
        plotattributes[get_attr_symbol(letter, :minorgridlinewidth)] = arg
        plotattributes[get_attr_symbol(letter, :minorgrid)] = true

        # color
    elseif handle_colors!(
        plotattributes,
        arg,
        get_attr_symbol(letter, :foreground_color_minor_grid),
    )
        plotattributes[get_attr_symbol(letter, :minorgrid)] = true
    else
        @warn "Skipped grid arg $arg."
    end
end

@attributes function process_font_attr!(plotattributes::AKW, fontname::Symbol, arg)
    T = typeof(arg)
    if fontname in (:legend_font,)
        # TODO: this is necessary while old and new font names coexist and should be standard after the transition
        fontname = Symbol(fontname, :_)
    end
    if T <: PlotsBase.Font
        Symbol(fontname, :family) --> arg.family

        # TODO: this is necessary in the transition from old fontsize to new font_pointsize and should be removed when it is completed
        if in(Symbol(fontname, :size), _all_attrs)
            Symbol(fontname, :size) --> arg.pointsize
        else
            Symbol(fontname, :pointsize) --> arg.pointsize
        end
        Symbol(fontname, :halign) --> arg.halign
        Symbol(fontname, :valign) --> arg.valign
        Symbol(fontname, :rotation) --> arg.rotation
        Symbol(fontname, :color) --> arg.color
    elseif arg ≡ :center
        Symbol(fontname, :halign) --> :hcenter
        Symbol(fontname, :valign) --> :vcenter
    elseif arg ∈ _haligns
        Symbol(fontname, :halign) --> arg
    elseif arg ∈ _valigns
        Symbol(fontname, :valign) --> arg
    elseif T <: Colorant
        Symbol(fontname, :color) --> arg
    elseif T <: Symbol || T <: AbstractString
        try
            Symbol(fontname, :color) --> parse(Colorant, string(arg))
        catch
            Symbol(fontname, :family) --> string(arg)
        end
    elseif typeof(arg) <: Integer
        if in(Symbol(fontname, :size), _all_attrs)
            Symbol(fontname, :size) --> arg
        else
            Symbol(fontname, :pointsize) --> arg
        end
    elseif typeof(arg) <: Real
        Symbol(fontname, :rotation) --> convert(Float64, arg)
    else
        @warn "Skipped font arg: $arg ($(typeof(arg)))"
    end
end

_replace_markershape(shape::Symbol) = get(_marker_aliases, shape, shape)
_replace_markershape(shapes::AVec) = map(_replace_markershape, shapes)
_replace_markershape(shape) = shape

function _add_markershape(plotattributes::AKW)
    # add the markershape if it needs to be added... hack to allow "m=10" to add a shape,
    # and still allow overriding in _apply_recipe
    ms = pop!(plotattributes, :markershape_to_add, :none)
    if !haskey(plotattributes, :markershape) && ms ≢ :none
        plotattributes[:markershape] = ms
    end
end

function convert_legend_value(val::Symbol)
    if val in (:both, :all, :yes)
        :best
    elseif val in (:no, :none)
        :none
    elseif val in (
        :right,
        :left,
        :top,
        :bottom,
        :inside,
        :best,
        :legend,
        :topright,
        :topleft,
        :bottomleft,
        :bottomright,
        :outertopright,
        :outertopleft,
        :outertop,
        :outerright,
        :outerleft,
        :outerbottomright,
        :outerbottomleft,
        :outerbottom,
        :inline,
    )
        val
    elseif val ≡ :horizontal
        -1
    else
        error("Invalid symbol for legend: $val")
    end
end
convert_legend_value(val::Real) = val
convert_legend_value(val::Bool) = val ? :best : :none
convert_legend_value(val::Nothing) = :none
convert_legend_value(v::Union{Tuple,NamedTuple}) = convert_legend_value.(v)
convert_legend_value(v::Tuple{<:Real,<:Real}) = v
convert_legend_value(v::Tuple{<:Real,Symbol}) = v
convert_legend_value(v::AbstractArray) = map(convert_legend_value, v)

# -----------------------------------------------------------------------------

"""Throw an error if the `levels` keyword argument is not of the correct type
or `levels` is less than 1"""
function check_contour_levels(levels)
    if !(levels isa Union{Integer,AVec})
        "the levels keyword argument must be an integer or AbstractVector" |>
        ArgumentError |>
        throw
    elseif levels isa Integer && levels <= 0
        "must pass a positive number of contours to the levels keyword argument" |>
        ArgumentError |>
        throw
    end
end

# -----------------------------------------------------------------------------

# when a value can be `:match`, this is the key that should be used instead for value retrieval
const _match_map = Dict(
    :background_color_outside => :background_color,
    :legend_background_color  => :background_color_subplot,
    :background_color_inside  => :background_color_subplot,
    :legend_foreground_color  => :foreground_color_subplot,
    :foreground_color_title   => :foreground_color_subplot,
    :left_margin              => :margin,
    :top_margin               => :margin,
    :right_margin             => :margin,
    :bottom_margin            => :margin,
    :titlefontfamily          => :fontfamily_subplot,
    :titlefontcolor           => :foreground_color_subplot,
    :legend_font_family       => :fontfamily_subplot,
    :legend_font_color        => :foreground_color_subplot,
    :legend_title_font_family => :fontfamily_subplot,
    :legend_title_font_color  => :foreground_color_subplot,
    :colorbar_fontfamily      => :fontfamily_subplot,
    :colorbar_titlefontfamily => :fontfamily_subplot,
    :colorbar_titlefontcolor  => :foreground_color_subplot,
    :colorbar_tickfontfamily  => :fontfamily_subplot,
    :colorbar_tickfontcolor   => :foreground_color_subplot,
    :plot_titlefontfamily     => :fontfamily,
    :plot_titlefontcolor      => :foreground_color,
    :tickfontcolor            => :foreground_color_text,
    :guidefontcolor           => :foreground_color_guide,
    :annotationfontfamily     => :fontfamily_subplot,
    :annotationcolor          => :foreground_color_subplot,
)

# these can match values from the parent container (axis --> subplot --> plot)
const _match_map2 = Dict(
    :background_color_subplot => :background_color,
    :foreground_color_subplot => :foreground_color,
    :foreground_color_axis => :foreground_color_subplot,
    :foreground_color_border => :foreground_color_subplot,
    :foreground_color_grid => :foreground_color_subplot,
    :foreground_color_minor_grid => :foreground_color_subplot,
    :foreground_color_guide => :foreground_color_subplot,
    :foreground_color_text => :foreground_color_subplot,
    :fontfamily_subplot => :fontfamily,
    :tickfontfamily => :fontfamily_subplot,
    :guidefontfamily => :fontfamily_subplot,
)

# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------

has_black_border_for_default(st) = error(
    "The seriestype attribute only accepts Symbols, you passed the $(typeof(st)) $st.",
)
has_black_border_for_default(st::Function) =
    error("The seriestype attribute only accepts Symbols, you passed the function $st.")
has_black_border_for_default(st::Symbol) =
    like_histogram(st) || st in (:hexbin, :bar, :shape)

ensure_gradient!(plotattributes::AKW, csym::Symbol, asym::Symbol) =
    if plotattributes[csym] isa ColorPalette
        α = nothing
        plotattributes[asym] isa AbstractVector || (α = plotattributes[asym])
        plotattributes[csym] = cgrad(plotattributes[csym], categorical = true, alpha = α)
    elseif !(plotattributes[csym] isa ColorGradient)
        plotattributes[csym] =
            typeof(plotattributes[asym]) <: AbstractVector ? cgrad() :
            cgrad(alpha = plotattributes[asym])
    end

# get a good default linewidth... 0 for surface and heatmaps
_replace_linewidth(plotattributes::AKW) =
    if plotattributes[:linewidth] ≡ :auto
        plotattributes[:linewidth] =
            (get(plotattributes, :seriestype, :path) ∉ (:surface, :heatmap, :image)) *
            DEFAULT_LINEWIDTH[]
    end

label_to_string(label::Bool, series_plotindex) =
    label ? label_to_string(:auto, series_plotindex) : ""
label_to_string(label::Nothing, series_plotindex) = ""
label_to_string(label::Missing, series_plotindex) = ""
label_to_string(label::Symbol, series_plotindex) =
    if label ≡ :auto
        string("y", series_plotindex)
    elseif label ≡ :none
        ""
    else
        throw(ArgumentError("unsupported symbol $(label) passed to `label`"))
    end
label_to_string(label, series_plotindex) = string(label)  # Fallback to string promotion

_series_index(plotattributes, sp) =
    if haskey(plotattributes, :series_index)
        plotattributes[:series_index]::Int
    elseif get(plotattributes, :primary, true)
        plotattributes[:series_index] = sp.primary_series_count += 1
    else
        plotattributes[:series_index] = sp.primary_series_count
    end

#--------------------------------------------------
## inspired by Base.@kwdef
"""
    add_attributes(level, expr, match_table)

Takes a `struct` definition and recurses into its fields to create keywords by chaining the field names with the structs' name with underscore.
Also creates pluralized and non-underscore aliases for these keywords.
- `level` indicates which group of `plot`, `subplot`, `series`, etc. the keywords belong to.
- `expr` is the struct definition with default values like `Base.@kwdef`
- `match_table` is an expression of the form `:match = (symbols)`, with symbols whose default value should be `:match`
"""
macro add_attributes(level, expr, match_table)
    expr = macroexpand(__module__, expr) # to expand @static
    expr isa Expr && expr.head ≡ :struct || error("Invalid usage of @add_attributes")
    if (T = expr.args[2]) isa Expr && T.head ≡ :<:
        T = T.args[1]
    end

    key_dict = KW()
    _splitdef!(expr.args[3], key_dict)

    insert_block = Expr(:block)
    for (key, value) ∈ key_dict
        # e.g. _series_defaults[key] = value
        exp_key = Symbol(lowercase(string(T)), "_", key)
        pl_key = makeplural(exp_key)
        if QuoteNode(exp_key) in match_table.args[2].args
            value = QuoteNode(:match)
        end
        field = QuoteNode(Symbol("_", level, "_defaults"))
        push!(
            insert_block.args,
            Expr(
                :(=),
                Expr(:ref, Expr(:call, getfield, PlotsBase, field), QuoteNode(exp_key)),
                value,
            ),
            :($add_aliases($(QuoteNode(exp_key)), $(QuoteNode(pl_key)))),
            :($add_aliases(
                $(QuoteNode(exp_key)),
                $(QuoteNode(make_non_underscore(exp_key))),
            )),
            :($add_aliases(
                $(QuoteNode(exp_key)),
                $(QuoteNode(make_non_underscore(pl_key))),
            )),
        )
    end
    quote
        $expr
        $insert_block
    end |> esc
end

function _splitdef!(blk, key_dict)
    for i ∈ eachindex(blk.args)
        if (ei = blk.args[i]) isa Symbol
            #  var
            continue
        elseif ei isa Expr
            if ei.head ≡ :(=)
                lhs = ei.args[1]
                if lhs isa Symbol
                    #  var = defexpr
                    var = lhs
                elseif lhs isa Expr && lhs.head ≡ :(::) && lhs.args[1] isa Symbol
                    #  var::T = defexpr
                    var = lhs.args[1]
                    type = lhs.args[2]
                    if @isdefined type
                        for field ∈ fieldnames(getproperty(PlotsBase, type))
                            key_dict[Symbol(var, "_", field)] =
                                :(getfield($(ei.args[2]), $(QuoteNode(field))))
                        end
                    end
                else
                    # something else, e.g. inline inner constructor
                    #   F(...) = ...
                    continue
                end
                defexpr = ei.args[2]  # defexpr
                key_dict[var] = defexpr
                blk.args[i] = lhs
            elseif ei.head ≡ :(::) && ei.args[1] isa Symbol
                # var::Typ
                var = ei.args[1]
                key_dict[var] = defexpr
            elseif ei.head ≡ :block
                # can arise with use of @static inside type decl
                _kwdef!(ei, value_attrs, key_attrs)
            end
        end
    end
    blk
end
