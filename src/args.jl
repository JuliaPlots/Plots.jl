makeplural(s::Symbol) = last(string(s)) == 's' ? s : Symbol(string(s, "s"))
make_non_underscore(s::Symbol) = Symbol(replace(string(s), "_" => ""))

const _keyAliases = Dict{Symbol,Symbol}()

function add_aliases(sym::Symbol, aliases::Symbol...)
    for alias in aliases
        (haskey(_keyAliases, alias) || alias === sym) && return
        _keyAliases[alias] = sym
    end
    nothing
end

function add_axes_aliases(sym::Symbol, aliases::Symbol...; generic::Bool = true)
    sym in keys(_axis_defaults) || throw(ArgumentError("Invalid `$sym`"))
    generic && add_aliases(sym, aliases...)
    for letter in (:x, :y, :z)
        add_aliases(Symbol(letter, sym), (Symbol(letter, a) for a in aliases)...)
    end
end

function add_non_underscore_aliases!(aliases::Dict{Symbol,Symbol})
    for (k, v) in aliases
        if '_' in string(k)
            aliases[make_non_underscore(k)] = v
        end
    end
end

macro attributes(expr::Expr)
    RecipesBase.process_recipe_body!(expr)
    expr
end

# ------------------------------------------------------------

const _allAxes = [:auto, :left, :right]
const _axesAliases = Dict{Symbol,Symbol}(:a => :auto, :l => :left, :r => :right)

const _3dTypes = [:path3d, :scatter3d, :surface, :wireframe, :contour3d, :volume, :mesh3d]
const _allTypes = vcat(
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

RecipesPipeline.is3d(series::Series) = RecipesPipeline.is3d(series.plotattributes)
RecipesPipeline.is3d(sp::Subplot) = string(sp.attr[:projection]) == "3d"
ispolar(sp::Subplot) = string(sp.attr[:projection]) == "polar"
ispolar(series::Series) = ispolar(series.plotattributes[:subplot])

# ------------------------------------------------------------

const _allStyles = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]
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
    :heptagon,
    :octagon,
    :star4,
    :star6,
    :star7,
    :star8,
    :vline,
    :hline,
    :+,
    :x,
]

const _allMarkers = vcat(:none, :auto, _shape_keys) #sort(collect(keys(_shapes))))
const _markerAliases = Dict{Symbol,Symbol}(
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

const _positionAliases = Dict{Symbol,Symbol}(
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

const _allScales = [:identity, :ln, :log2, :log10, :asinh, :sqrt]
const _logScales = [:ln, :log2, :log10]
const _logScaleBases = Dict(:ln => ℯ, :log2 => 2.0, :log10 => 10.0)
const _scaleAliases = Dict{Symbol,Symbol}(:none => :identity, :log => :log10)

const _allGridSyms = [
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
const _allGridArgs = [_allGridSyms; string.(_allGridSyms); nothing]
hasgrid(arg::Nothing, letter) = false
hasgrid(arg::Bool, letter) = arg
function hasgrid(arg::Symbol, letter)
    if arg in _allGridSyms
        arg in (:all, :both, :on) || occursin(string(letter), string(arg))
    else
        @warn "Unknown grid argument $arg; $(get_attr_symbol(letter, :grid)) was set to `true` instead."
        true
    end
end
hasgrid(arg::AbstractString, letter) = hasgrid(Symbol(arg), letter)

const _allShowaxisSyms = [
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
const _allShowaxisArgs = [_allGridSyms; string.(_allGridSyms)]
showaxis(arg::Nothing, letter) = false
showaxis(arg::Bool, letter) = arg
function showaxis(arg::Symbol, letter)
    if arg in _allGridSyms
        arg in (:all, :both, :on, :yes) || occursin(string(letter), string(arg))
    else
        @warn "Unknown showaxis argument $arg; $(get_attr_symbol(letter, :showaxis)) was set to `true` instead."
        true
    end
end
showaxis(arg::AbstractString, letter) = hasgrid(Symbol(arg), letter)

const _allFramestyles = [:box, :semi, :axes, :origin, :zerolines, :grid, :none]
const _framestyleAliases = Dict{Symbol,Symbol}(
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
    :orientation        => :vertical,
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

is_subplot_attr(k) = k in _all_subplot_args
is_series_attr(k) = k in _all_series_args
is_axis_attr(k) = Symbol(chop(string(k); head = 1, tail = 0)) in _all_axis_args
is_axis_attr_noletter(k) = k in _all_axis_args

RecipesBase.is_key_supported(k::Symbol) = is_attr_supported(k)

# -----------------------------------------------------------------------------
autopick_ignore_none_auto(arr::AVec, idx::Integer) =
    _cycle(setdiff(arr, [:none, :auto]), idx)
autopick_ignore_none_auto(notarr, idx::Integer) = notarr

function aliasesAndAutopick(
    plotattributes::AKW,
    sym::Symbol,
    aliases::Dict{Symbol,Symbol},
    options::AVec,
    plotIndex::Int,
)
    if plotattributes[sym] === :auto
        plotattributes[sym] = autopick_ignore_none_auto(options, plotIndex)
    elseif haskey(aliases, plotattributes[sym])
        plotattributes[sym] = aliases[plotattributes[sym]]
    end
end

aliases(val) = aliases(_keyAliases, val)
aliases(aliasMap::Dict{Symbol,Symbol}, val) =
    filter(x -> x.second == val, aliasMap) |> keys |> collect |> sort

# -----------------------------------------------------------------------------
# legend
add_aliases(:legend_position, :legend, :leg, :key, :legends)
add_aliases(
    :legend_background_color,
    :bg_legend,
    :bglegend,
    :bgcolor_legend,
    :bg_color_legend,
    :background_legend,
    :background_colour_legend,
    :bgcolour_legend,
    :bg_colour_legend,
    :background_color_legend,
)
add_aliases(
    :legend_foreground_color,
    :fg_legend,
    :fglegend,
    :fgcolor_legend,
    :fg_color_legend,
    :foreground_legend,
    :foreground_colour_legend,
    :fgcolour_legend,
    :fg_colour_legend,
    :foreground_color_legend,
)
add_aliases(:legend_font_pointsize, :legendfontsize)
add_aliases(
    :legend_title,
    :key_title,
    :keytitle,
    :label_title,
    :labeltitle,
    :leg_title,
    :legtitle,
)
add_aliases(:legend_title_font_pointsize, :legendtitlefontsize)
add_aliases(:plot_title, :suptitle, :subplot_grid_title, :sgtitle, :plot_grid_title)
# margin
add_aliases(:left_margin, :leftmargin)

add_aliases(:top_margin, :topmargin)
add_aliases(:bottom_margin, :bottommargin)
add_aliases(:right_margin, :rightmargin)

# colors
add_aliases(:seriescolor, :c, :color, :colour, :colormap, :cmap)
add_aliases(:linecolor, :lc, :lcolor, :lcolour, :linecolour)
add_aliases(:markercolor, :mc, :mcolor, :mcolour, :markercolour)
add_aliases(:markerstrokecolor, :msc, :mscolor, :mscolour, :markerstrokecolour)
add_aliases(:markerstrokewidth, :msw, :mswidth)
add_aliases(:fillcolor, :fc, :fcolor, :fcolour, :fillcolour)

add_aliases(
    :background_color,
    :bg,
    :bgcolor,
    :bg_color,
    :background,
    :background_colour,
    :bgcolour,
    :bg_colour,
)
add_aliases(
    :background_color_subplot,
    :bg_subplot,
    :bgsubplot,
    :bgcolor_subplot,
    :bg_color_subplot,
    :background_subplot,
    :background_colour_subplot,
    :bgcolour_subplot,
    :bg_colour_subplot,
)
add_aliases(
    :background_color_inside,
    :bg_inside,
    :bginside,
    :bgcolor_inside,
    :bg_color_inside,
    :background_inside,
    :background_colour_inside,
    :bgcolour_inside,
    :bg_colour_inside,
)
add_aliases(
    :background_color_outside,
    :bg_outside,
    :bgoutside,
    :bgcolor_outside,
    :bg_color_outside,
    :background_outside,
    :background_colour_outside,
    :bgcolour_outside,
    :bg_colour_outside,
)
add_aliases(
    :foreground_color,
    :fg,
    :fgcolor,
    :fg_color,
    :foreground,
    :foreground_colour,
    :fgcolour,
    :fg_colour,
)

add_aliases(
    :foreground_color_subplot,
    :fg_subplot,
    :fgsubplot,
    :fgcolor_subplot,
    :fg_color_subplot,
    :foreground_subplot,
    :foreground_colour_subplot,
    :fgcolour_subplot,
    :fg_colour_subplot,
)
add_aliases(
    :foreground_color_grid,
    :fg_grid,
    :fggrid,
    :fgcolor_grid,
    :fg_color_grid,
    :foreground_grid,
    :foreground_colour_grid,
    :fgcolour_grid,
    :fg_colour_grid,
    :gridcolor,
)
add_aliases(
    :foreground_color_minor_grid,
    :fg_minor_grid,
    :fgminorgrid,
    :fgcolor_minorgrid,
    :fg_color_minorgrid,
    :foreground_minorgrid,
    :foreground_colour_minor_grid,
    :fgcolour_minorgrid,
    :fg_colour_minor_grid,
    :minorgridcolor,
)
add_aliases(
    :foreground_color_title,
    :fg_title,
    :fgtitle,
    :fgcolor_title,
    :fg_color_title,
    :foreground_title,
    :foreground_colour_title,
    :fgcolour_title,
    :fg_colour_title,
    :titlecolor,
)
add_aliases(
    :foreground_color_axis,
    :fg_axis,
    :fgaxis,
    :fgcolor_axis,
    :fg_color_axis,
    :foreground_axis,
    :foreground_colour_axis,
    :fgcolour_axis,
    :fg_colour_axis,
    :axiscolor,
)
add_aliases(
    :foreground_color_border,
    :fg_border,
    :fgborder,
    :fgcolor_border,
    :fg_color_border,
    :foreground_border,
    :foreground_colour_border,
    :fgcolour_border,
    :fg_colour_border,
    :bordercolor,
)
add_aliases(
    :foreground_color_text,
    :fg_text,
    :fgtext,
    :fgcolor_text,
    :fg_color_text,
    :foreground_text,
    :foreground_colour_text,
    :fgcolour_text,
    :fg_colour_text,
    :textcolor,
)
add_aliases(
    :foreground_color_guide,
    :fg_guide,
    :fgguide,
    :fgcolor_guide,
    :fg_color_guide,
    :foreground_guide,
    :foreground_colour_guide,
    :fgcolour_guide,
    :fg_colour_guide,
    :guidecolor,
)

# alphas
add_aliases(:seriesalpha, :alpha, :α, :opacity)
add_aliases(:linealpha, :la, :lalpha, :lα, :lineopacity, :lopacity)
add_aliases(:markeralpha, :ma, :malpha, :mα, :markeropacity, :mopacity)
add_aliases(:markerstrokealpha, :msa, :msalpha, :msα, :markerstrokeopacity, :msopacity)
add_aliases(:fillalpha, :fa, :falpha, :fα, :fillopacity, :fopacity)

# axes attributes
add_axes_aliases(:guide, :label, :lab, :l; generic = false)
add_axes_aliases(:lims, :lim, :limit, :limits, :range)
add_axes_aliases(:ticks, :tick)
add_axes_aliases(:rotation, :rot, :r)
add_axes_aliases(:guidefontsize, :labelfontsize)
add_axes_aliases(:gridalpha, :ga, :galpha, :gα, :gridopacity, :gopacity)
add_axes_aliases(
    :gridstyle,
    :grid_style,
    :gridlinestyle,
    :grid_linestyle,
    :grid_ls,
    :gridls,
)
add_axes_aliases(
    :foreground_color_grid,
    :fg_grid,
    :fggrid,
    :fgcolor_grid,
    :fg_color_grid,
    :foreground_grid,
    :foreground_colour_grid,
    :fgcolour_grid,
    :fg_colour_grid,
    :gridcolor,
)
add_axes_aliases(
    :foreground_color_minor_grid,
    :fg_minor_grid,
    :fgminorgrid,
    :fgcolor_minorgrid,
    :fg_color_minorgrid,
    :foreground_minorgrid,
    :foreground_colour_minor_grid,
    :fgcolour_minorgrid,
    :fg_colour_minor_grid,
    :minorgridcolor,
)
add_axes_aliases(
    :gridlinewidth,
    :gridwidth,
    :grid_linewidth,
    :grid_width,
    :gridlw,
    :grid_lw,
)
add_axes_aliases(
    :minorgridstyle,
    :minorgrid_style,
    :minorgridlinestyle,
    :minorgrid_linestyle,
    :minorgrid_ls,
    :minorgridls,
)
add_axes_aliases(
    :minorgridlinewidth,
    :minorgridwidth,
    :minorgrid_linewidth,
    :minorgrid_width,
    :minorgridlw,
    :minorgrid_lw,
)
add_axes_aliases(
    :tick_direction,
    :tickdirection,
    :tick_dir,
    :tickdir,
    :tick_orientation,
    :tickorientation,
    :tick_or,
    :tickor,
)

# series attributes
add_aliases(:seriestype, :st, :t, :typ, :linetype, :lt)
add_aliases(:label, :lab)
add_aliases(:line, :l)
add_aliases(:linewidth, :w, :width, :lw)
add_aliases(:linestyle, :style, :s, :ls)
add_aliases(:marker, :m, :mark)
add_aliases(:markershape, :shape)
add_aliases(:markersize, :ms, :msize)
add_aliases(:marker_z, :markerz, :zcolor, :mz)
add_aliases(:line_z, :linez, :zline, :lz)
add_aliases(:fill, :f, :area)
add_aliases(:fillrange, :fillrng, :frange, :fillto, :fill_between)
add_aliases(:group, :g, :grouping)
add_aliases(:bins, :bin, :nbin, :nbins, :nb)
add_aliases(:ribbon, :rib)
add_aliases(:annotations, :ann, :anns, :annotate, :annotation)
add_aliases(:xguide, :xlabel, :xlab, :xl)
add_aliases(:xlims, :xlim, :xlimit, :xlimits, :xrange)
add_aliases(:xticks, :xtick)
add_aliases(:xrotation, :xrot, :xr)
add_aliases(:yguide, :ylabel, :ylab, :yl)
add_aliases(:ylims, :ylim, :ylimit, :ylimits, :yrange)
add_aliases(:yticks, :ytick)
add_aliases(:yrotation, :yrot, :yr)
add_aliases(:zguide, :zlabel, :zlab, :zl)
add_aliases(:zlims, :zlim, :zlimit, :zlimits)
add_aliases(:zticks, :ztick)
add_aliases(:zrotation, :zrot, :zr)
add_aliases(:guidefontsize, :labelfontsize)
add_aliases(
    :fill_z,
    :fillz,
    :fz,
    :surfacecolor,
    :surfacecolour,
    :sc,
    :surfcolor,
    :surfcolour,
)
add_aliases(:colorbar, :cb, :cbar, :colorkey)
add_aliases(
    :colorbar_title,
    :colorbartitle,
    :cb_title,
    :cbtitle,
    :cbartitle,
    :cbar_title,
    :colorkeytitle,
    :colorkey_title,
)
add_aliases(:clims, :clim, :cbarlims, :cbar_lims, :climits, :color_limits)
add_aliases(:smooth, :regression, :reg)
add_aliases(:levels, :nlevels, :nlev, :levs)
add_aliases(:size, :windowsize, :wsize)
add_aliases(:window_title, :windowtitle, :wtitle)
add_aliases(:show, :gui, :display)
add_aliases(:color_palette, :palette)
add_aliases(:overwrite_figure, :clf, :clearfig, :overwrite, :reuse)
add_aliases(:xerror, :xerr, :xerrorbar)
add_aliases(:yerror, :yerr, :yerrorbar, :err, :errorbar)
add_aliases(:zerror, :zerr, :zerrorbar)
add_aliases(:quiver, :velocity, :quiver2d, :gradient, :vectorfield)
add_aliases(:normalize, :norm, :normed, :normalized)
add_aliases(:show_empty_bins, :showemptybins, :showempty, :show_empty)
add_aliases(:aspect_ratio, :aspectratio, :axis_ratio, :axisratio, :ratio)
add_aliases(:subplot, :sp, :subplt, :splt)
add_aliases(:projection, :proj)
add_aliases(:projection_type, :proj_type)
add_aliases(
    :titlelocation,
    :title_location,
    :title_loc,
    :titleloc,
    :title_position,
    :title_pos,
    :titlepos,
    :titleposition,
    :title_align,
    :title_alignment,
)
add_aliases(
    :series_annotations,
    :series_ann,
    :seriesann,
    :series_anns,
    :seriesanns,
    :series_annotation,
    :text,
    :txt,
    :texts,
    :txts,
)
add_aliases(:html_output_format, :format, :fmt, :html_format)
add_aliases(:orientation, :direction, :dir)
add_aliases(:inset_subplots, :inset, :floating)
add_aliases(:stride, :wirefame_stride, :surface_stride, :surf_str, :str)

add_aliases(
    :framestyle,
    :frame_style,
    :frame,
    :axesstyle,
    :axes_style,
    :boxstyle,
    :box_style,
    :box,
    :borderstyle,
    :border_style,
    :border,
)

add_aliases(:camera, :cam, :viewangle, :view_angle)
add_aliases(:contour_labels, :contourlabels, :clabels, :clabs)
add_aliases(:warn_on_unsupported, :warn)

# -----------------------------------------------------------------------------

function parse_axis_kw(s::Symbol)
    s = string(s)
    for letter in ('x', 'y', 'z')
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
    for defaults in _all_defaults
        haskey(defaults, k) && return defaults[k]
    end
    haskey(_axis_defaults, k) && return _axis_defaults[k]
    if (axis_k = parse_axis_kw(k)) !== nothing
        letter, key = axis_k
        return _axis_defaults_byletter[letter][key]
    end
    k === :letter && return k # for type recipe processing
    missing
end

function default(k::Symbol, v)
    k = get(_keyAliases, k, k)
    for defaults in _all_defaults
        if haskey(defaults, k)
            defaults[k] = v
            return v
        end
    end
    if haskey(_axis_defaults, k)
        _axis_defaults[k] = v
        return v
    end
    if (axis_k = parse_axis_kw(k)) !== nothing
        letter, key = axis_k
        _axis_defaults_byletter[letter][key] = v
        return v
    end
    k in _suppress_warnings || error("Unknown key: ", k)
end

function default(; reset = true, kw...)
    (reset && isempty(kw)) && reset_defaults()
    kw = KW(kw)
    Plots.preprocess_attributes!(kw)
    for (k, v) in kw
        default(k, v)
    end
end

default(plotattributes::AKW, k::Symbol) = get(plotattributes, k, default(k))

function reset_defaults()
    foreach(merge!, _all_defaults, _initial_defaults)
    merge!(_axis_defaults, _initial_axis_defaults)
    reset_axis_defaults_byletter!()
end

# -----------------------------------------------------------------------------

# if arg is a valid color value, then set plotattributes[csym] and return true
function handleColors!(plotattributes::AKW, arg, csym::Symbol)
    try
        plotattributes[csym] = if arg === :auto
            :auto
        else
            plot_color(arg)
        end
        return true
    catch
    end
    false
end

function processLineArg(plotattributes::AKW, arg)
    # seriestype
    if allLineTypes(arg)
        plotattributes[:seriestype] = arg

        # linestyle
    elseif allStyles(arg)
        plotattributes[:linestyle] = arg

    elseif typeof(arg) <: Stroke
        arg.width === nothing || (plotattributes[:linewidth] = arg.width)
        arg.color === nothing || (
            plotattributes[:linecolor] =
                arg.color === :auto ? :auto : plot_color(arg.color)
        )
        arg.alpha === nothing || (plotattributes[:linealpha] = arg.alpha)
        arg.style === nothing || (plotattributes[:linestyle] = arg.style)

    elseif typeof(arg) <: Brush
        arg.size === nothing || (plotattributes[:fillrange] = arg.size)
        arg.color === nothing || (
            plotattributes[:fillcolor] =
                arg.color === :auto ? :auto : plot_color(arg.color)
        )
        arg.alpha === nothing || (plotattributes[:fillalpha] = arg.alpha)
        arg.style === nothing || (plotattributes[:fillstyle] = arg.style)

    elseif typeof(arg) <: Arrow || arg in (:arrow, :arrows)
        plotattributes[:arrow] = arg

        # linealpha
    elseif allAlphas(arg)
        plotattributes[:linealpha] = arg

        # linewidth
    elseif allReals(arg)
        plotattributes[:linewidth] = arg

        # color
    elseif !handleColors!(plotattributes, arg, :linecolor)
        @warn "Skipped line arg $arg."
    end
end

function processMarkerArg(plotattributes::AKW, arg)
    # markershape
    if allShapes(arg) && !haskey(plotattributes, :markershape)
        plotattributes[:markershape] = arg

        # stroke style
    elseif allStyles(arg)
        plotattributes[:markerstrokestyle] = arg

    elseif typeof(arg) <: Stroke
        arg.width === nothing || (plotattributes[:markerstrokewidth] = arg.width)
        arg.color === nothing || (
            plotattributes[:markerstrokecolor] =
                arg.color === :auto ? :auto : plot_color(arg.color)
        )
        arg.alpha === nothing || (plotattributes[:markerstrokealpha] = arg.alpha)
        arg.style === nothing || (plotattributes[:markerstrokestyle] = arg.style)

    elseif typeof(arg) <: Brush
        arg.size === nothing || (plotattributes[:markersize] = arg.size)
        arg.color === nothing || (
            plotattributes[:markercolor] =
                arg.color === :auto ? :auto : plot_color(arg.color)
        )
        arg.alpha === nothing || (plotattributes[:markeralpha] = arg.alpha)

        # linealpha
    elseif allAlphas(arg)
        plotattributes[:markeralpha] = arg

        # bool
    elseif typeof(arg) <: Bool
        plotattributes[:markershape] = arg ? :circle : :none

        # markersize
    elseif allReals(arg)
        plotattributes[:markersize] = arg

        # markercolor
    elseif !handleColors!(plotattributes, arg, :markercolor)
        @warn "Skipped marker arg $arg."
    end
end

function processFillArg(plotattributes::AKW, arg)
    # fr = get(plotattributes, :fillrange, 0)
    if typeof(arg) <: Brush
        arg.size === nothing || (plotattributes[:fillrange] = arg.size)
        arg.color === nothing || (
            plotattributes[:fillcolor] =
                arg.color === :auto ? :auto : plot_color(arg.color)
        )
        arg.alpha === nothing || (plotattributes[:fillalpha] = arg.alpha)
        arg.style === nothing || (plotattributes[:fillstyle] = arg.style)

    elseif typeof(arg) <: Bool
        plotattributes[:fillrange] = arg ? 0 : nothing

        # fillrange function
    elseif allFunctions(arg)
        plotattributes[:fillrange] = arg

        # fillalpha
    elseif allAlphas(arg)
        plotattributes[:fillalpha] = arg

        # fillrange provided as vector or number
    elseif typeof(arg) <: Union{AbstractArray{<:Real},Real}
        plotattributes[:fillrange] = arg

    elseif !handleColors!(plotattributes, arg, :fillcolor)
        plotattributes[:fillrange] = arg
    end
    # plotattributes[:fillrange] = fr
    nothing
end

function processGridArg!(plotattributes::AKW, arg, letter)
    if arg in _allGridArgs || isa(arg, Bool)
        plotattributes[get_attr_symbol(letter, :grid)] = hasgrid(arg, letter)

    elseif allStyles(arg)
        plotattributes[get_attr_symbol(letter, :gridstyle)] = arg

    elseif typeof(arg) <: Stroke
        arg.width === nothing ||
            (plotattributes[get_attr_symbol(letter, :gridlinewidth)] = arg.width)
        arg.color === nothing || (
            plotattributes[get_attr_symbol(letter, :foreground_color_grid)] =
                arg.color in (:auto, :match) ? :match : plot_color(arg.color)
        )
        arg.alpha === nothing ||
            (plotattributes[get_attr_symbol(letter, :gridalpha)] = arg.alpha)
        arg.style === nothing ||
            (plotattributes[get_attr_symbol(letter, :gridstyle)] = arg.style)

        # linealpha
    elseif allAlphas(arg)
        plotattributes[get_attr_symbol(letter, :gridalpha)] = arg

        # linewidth
    elseif allReals(arg)
        plotattributes[get_attr_symbol(letter, :gridlinewidth)] = arg

        # color
    elseif !handleColors!(
        plotattributes,
        arg,
        get_attr_symbol(letter, :foreground_color_grid),
    )
        @warn "Skipped grid arg $arg."
    end
end

function processMinorGridArg!(plotattributes::AKW, arg, letter)
    if arg in _allGridArgs || isa(arg, Bool)
        plotattributes[get_attr_symbol(letter, :minorgrid)] = hasgrid(arg, letter)

    elseif allStyles(arg)
        plotattributes[get_attr_symbol(letter, :minorgridstyle)] = arg
        plotattributes[get_attr_symbol(letter, :minorgrid)] = true

    elseif typeof(arg) <: Stroke
        arg.width === nothing ||
            (plotattributes[get_attr_symbol(letter, :minorgridlinewidth)] = arg.width)
        arg.color === nothing || (
            plotattributes[get_attr_symbol(letter, :foreground_color_minor_grid)] =
                arg.color in (:auto, :match) ? :match : plot_color(arg.color)
        )
        arg.alpha === nothing ||
            (plotattributes[get_attr_symbol(letter, :minorgridalpha)] = arg.alpha)
        arg.style === nothing ||
            (plotattributes[get_attr_symbol(letter, :minorgridstyle)] = arg.style)
        plotattributes[get_attr_symbol(letter, :minorgrid)] = true

        # linealpha
    elseif allAlphas(arg)
        plotattributes[get_attr_symbol(letter, :minorgridalpha)] = arg
        plotattributes[get_attr_symbol(letter, :minorgrid)] = true

        # linewidth
    elseif allReals(arg)
        plotattributes[get_attr_symbol(letter, :minorgridlinewidth)] = arg
        plotattributes[get_attr_symbol(letter, :minorgrid)] = true

        # color
    elseif handleColors!(
        plotattributes,
        arg,
        get_attr_symbol(letter, :foreground_color_minor_grid),
    )
        plotattributes[get_attr_symbol(letter, :minorgrid)] = true
    else
        @warn "Skipped grid arg $arg."
    end
end

@attributes function processFontArg!(plotattributes::AKW, fontname::Symbol, arg)
    T = typeof(arg)
    if fontname in (:legend_font,)
        # TODO: this is neccessary while old and new font names coexist and should be standard after the transition
        fontname = Symbol(fontname, :_)
    end
    if T <: Font
        Symbol(fontname, :family) --> arg.family

        # TODO: this is neccessary in the transition from old fontsize to new font_pointsize and should be removed when it is completed
        if in(Symbol(fontname, :size), _all_args)
            Symbol(fontname, :size) --> arg.pointsize
        else
            Symbol(fontname, :pointsize) --> arg.pointsize
        end
        Symbol(fontname, :halign) --> arg.halign
        Symbol(fontname, :valign) --> arg.valign
        Symbol(fontname, :rotation) --> arg.rotation
        Symbol(fontname, :color) --> arg.color
    elseif arg === :center
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
        if in(Symbol(fontname, :size), _all_args)
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

_replace_markershape(shape::Symbol) = get(_markerAliases, shape, shape)
_replace_markershape(shapes::AVec) = map(_replace_markershape, shapes)
_replace_markershape(shape) = shape

function _add_markershape(plotattributes::AKW)
    # add the markershape if it needs to be added... hack to allow "m=10" to add a shape,
    # and still allow overriding in _apply_recipe
    ms = pop!(plotattributes, :markershape_to_add, :none)
    if !haskey(plotattributes, :markershape) && ms !== :none
        plotattributes[:markershape] = ms
    end
end

"Handle all preprocessing of args... break out colors/sizes/etc and replace aliases."
function preprocess_attributes!(plotattributes::AKW)
    replaceAliases!(plotattributes, _keyAliases)

    # handle axis args common to all axis
    args = wraptuple(RecipesPipeline.pop_kw!(plotattributes, :axis, ()))
    showarg = wraptuple(RecipesPipeline.pop_kw!(plotattributes, :showaxis, ()))
    for arg in wraptuple((args..., showarg...))
        for letter in (:x, :y, :z)
            process_axis_arg!(plotattributes, arg, letter)
        end
    end
    # handle axis args
    for letter in (:x, :y, :z)
        asym = get_attr_symbol(letter, :axis)
        args = RecipesPipeline.pop_kw!(plotattributes, asym, ())
        if !(typeof(args) <: Axis)
            for arg in wraptuple(args)
                process_axis_arg!(plotattributes, arg, letter)
            end
        end
    end

    # vline and others accesses the y argument but actually maps it to the x axis.
    # Hence, we have to take care of formatters
    if treats_y_as_x(get(plotattributes, :seriestype, :path))
        xformatter = get(plotattributes, :xformatter, :auto)
        yformatter = get(plotattributes, :yformatter, :auto)
        yformatter !== :auto && (plotattributes[:xformatter] = yformatter)
        xformatter === :auto &&
            haskey(plotattributes, :yformatter) &&
            pop!(plotattributes, :yformatter)
    end

    # handle grid args common to all axes
    args = RecipesPipeline.pop_kw!(plotattributes, :grid, ())
    for arg in wraptuple(args)
        for letter in (:x, :y, :z)
            processGridArg!(plotattributes, arg, letter)
        end
    end
    # handle individual axes grid args
    for letter in (:x, :y, :z)
        gridsym = get_attr_symbol(letter, :grid)
        args = RecipesPipeline.pop_kw!(plotattributes, gridsym, ())
        for arg in wraptuple(args)
            processGridArg!(plotattributes, arg, letter)
        end
    end
    # handle minor grid args common to all axes
    args = RecipesPipeline.pop_kw!(plotattributes, :minorgrid, ())
    for arg in wraptuple(args)
        for letter in (:x, :y, :z)
            processMinorGridArg!(plotattributes, arg, letter)
        end
    end
    # handle individual axes grid args
    for letter in (:x, :y, :z)
        gridsym = get_attr_symbol(letter, :minorgrid)
        args = RecipesPipeline.pop_kw!(plotattributes, gridsym, ())
        for arg in wraptuple(args)
            processMinorGridArg!(plotattributes, arg, letter)
        end
    end
    # handle font args common to all axes
    for fontname in (:tickfont, :guidefont)
        args = RecipesPipeline.pop_kw!(plotattributes, fontname, ())
        for arg in wraptuple(args)
            for letter in (:x, :y, :z)
                processFontArg!(plotattributes, get_attr_symbol(letter, fontname), arg)
            end
        end
    end
    # handle individual axes font args
    for letter in (:x, :y, :z)
        for fontname in (:tickfont, :guidefont)
            args = RecipesPipeline.pop_kw!(
                plotattributes,
                get_attr_symbol(letter, fontname),
                (),
            )
            for arg in wraptuple(args)
                processFontArg!(plotattributes, get_attr_symbol(letter, fontname), arg)
            end
        end
    end
    # handle axes args
    for k in _axis_args
        if haskey(plotattributes, k) && k !== :link
            v = plotattributes[k]
            for letter in (:x, :y, :z)
                lk = get_attr_symbol(letter, k)
                if !is_explicit(plotattributes, lk)
                    plotattributes[lk] = v
                end
            end
        end
    end

    # fonts
    for fontname in
        (:titlefont, :legend_title_font, :plot_titlefont, :colorbar_titlefont, :legend_font)
        args = RecipesPipeline.pop_kw!(plotattributes, fontname, ())
        for arg in wraptuple(args)
            processFontArg!(plotattributes, fontname, arg)
        end
    end

    # handle line args
    for arg in wraptuple(RecipesPipeline.pop_kw!(plotattributes, :line, ()))
        processLineArg(plotattributes, arg)
    end

    if haskey(plotattributes, :seriestype) &&
       haskey(_typeAliases, plotattributes[:seriestype])
        plotattributes[:seriestype] = _typeAliases[plotattributes[:seriestype]]
    end

    # handle marker args... default to ellipse if shape not set
    anymarker = false
    for arg in wraptuple(get(plotattributes, :marker, ()))
        processMarkerArg(plotattributes, arg)
        anymarker = true
    end
    RecipesPipeline.reset_kw!(plotattributes, :marker)
    if haskey(plotattributes, :markershape)
        plotattributes[:markershape] = _replace_markershape(plotattributes[:markershape])
        if plotattributes[:markershape] === :none &&
           get(plotattributes, :seriestype, :path) in
           (:scatter, :scatterbins, :scatterhist, :scatter3d) #the default should be :auto, not :none, so that :none can be set explicitly and would be respected
            plotattributes[:markershape] = :circle
        end
    elseif anymarker
        plotattributes[:markershape_to_add] = :circle  # add it after _apply_recipe
    end

    # handle fill
    for arg in wraptuple(get(plotattributes, :fill, ()))
        processFillArg(plotattributes, arg)
    end
    RecipesPipeline.reset_kw!(plotattributes, :fill)

    # handle series annotations
    if haskey(plotattributes, :series_annotations)
        plotattributes[:series_annotations] =
            series_annotations(wraptuple(plotattributes[:series_annotations])...)
    end

    # convert into strokes and brushes

    if haskey(plotattributes, :arrow)
        a = plotattributes[:arrow]
        plotattributes[:arrow] = if a == true
            arrow()
        elseif a in (false, nothing, :none)
            nothing
        elseif !(typeof(a) <: Arrow || typeof(a) <: AbstractArray{Arrow})
            arrow(wraptuple(a)...)
        else
            a
        end
    end

    # legends - defaults are set in `src/components.jl` (see `@add_attributes`)
    if haskey(plotattributes, :legend_position)
        plotattributes[:legend_position] =
            convertLegendValue(plotattributes[:legend_position])
    end
    if haskey(plotattributes, :colorbar)
        plotattributes[:colorbar] = convertLegendValue(plotattributes[:colorbar])
    end

    # framestyle
    if haskey(plotattributes, :framestyle) &&
       haskey(_framestyleAliases, plotattributes[:framestyle])
        plotattributes[:framestyle] = _framestyleAliases[plotattributes[:framestyle]]
    end

    # contours
    if haskey(plotattributes, :levels)
        check_contour_levels(plotattributes[:levels])
    end

    # warnings for moved recipes
    st = get(plotattributes, :seriestype, :path)
    if st in (:boxplot, :violin, :density) &&
       !haskey(
        Base.loaded_modules,
        Base.PkgId(Base.UUID("f3b207a7-027a-5e70-b257-86293d7955fd"), "StatsPlots"),
    )
        @warn "seriestype $st has been moved to StatsPlots.  To use: \`Pkg.add(\"StatsPlots\"); using StatsPlots\`"
    end
    nothing
end
RecipesPipeline.preprocess_attributes!(plt::Plot, plotattributes::AKW) =
    Plots.preprocess_attributes!(plotattributes)

# -----------------------------------------------------------------------------

const _already_warned = Dict{Symbol,Set{Symbol}}()
const _to_warn = Set{Symbol}()

should_warn_on_unsupported(::AbstractBackend) = _plot_defaults[:warn_on_unsupported]

function warn_on_unsupported_args(pkg::AbstractBackend, plotattributes)
    empty!(_to_warn)
    bend = backend_name(pkg)
    already_warned = get!(_already_warned, bend) do
        Set{Symbol}()
    end
    extra_kwargs = Dict{Symbol,Any}()
    for k in explicitkeys(plotattributes)
        (is_attr_supported(pkg, k) && k ∉ keys(_deprecated_attributes)) && continue
        k in _suppress_warnings && continue
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
            if k in keys(_deprecated_attributes)
                @warn """
                Keyword argument `$k` is deprecated.
                Please use `$(_deprecated_attributes[k])` instead.
                """
            else
                @warn "Keyword argument $k not supported with $pkg.  Choose from: $(join(supported_attrs(pkg), ", "))"
            end
        end
    end
    extra_kwargs
end

# _markershape_supported(pkg::AbstractBackend, shape::Symbol) = shape in supported_markers(pkg)
# _markershape_supported(pkg::AbstractBackend, shape::Shape) = Shape in supported_markers(pkg)
# _markershape_supported(pkg::AbstractBackend, shapes::AVec) = all([_markershape_supported(pkg, shape) for shape in shapes])

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

# -----------------------------------------------------------------------------

function convertLegendValue(val::Symbol)
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
    elseif val === :horizontal
        -1
    else
        error("Invalid symbol for legend: $val")
    end
end
convertLegendValue(val::Real) = val
convertLegendValue(val::Bool) = val ? :best : :none
convertLegendValue(val::Nothing) = :none
convertLegendValue(v::Union{Tuple,NamedTuple}) = convertLegendValue.(v)
convertLegendValue(v::Tuple{<:Real,<:Real}) = v
convertLegendValue(v::Tuple{<:Real,Symbol}) = v
convertLegendValue(v::AbstractArray) = map(convertLegendValue, v)

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

# 1-row matrices will give an element
# multi-row matrices will give a column
# InputWrapper just gives the contents
# anything else is returned as-is
function slice_arg(v::AMat, idx::Int)
    isempty(v) && return v
    c = mod1(idx, size(v, 2))
    m, n = axes(v)
    size(v, 1) == 1 ? v[first(m), n[c]] : v[:, n[c]]
end
slice_arg(wrapper::InputWrapper, idx) = wrapper.obj
slice_arg(v::NTuple{2,AMat}, idx::Int) = slice_arg(v[1], idx), slice_arg(v[2], idx)
slice_arg(v, idx) = v

# given an argument key `k`, extract the argument value for this index,
# and set into plotattributes[k]. Matrices are sliced by column.
# if nothing is set (or container is empty), return the existing value.
function slice_arg!(
    plotattributes_in,
    plotattributes_out,
    k::Symbol,
    idx::Int,
    remove_pair::Bool,
)
    v = get(plotattributes_in, k, plotattributes_out[k])
    plotattributes_out[k] = if haskey(plotattributes_in, k) && k ∉ _plot_args
        slice_arg(v, idx)
    else
        v
    end
    remove_pair && RecipesPipeline.reset_kw!(plotattributes_in, k)
    nothing
end

# -----------------------------------------------------------------------------

function color_or_nothing!(plotattributes, k::Symbol)
    plotattributes[k] = (v = plotattributes[k]) === :match ? v : plot_color(v)
    nothing
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

# properly retrieve from plt.attr, passing `:match` to the correct key
Base.getindex(plt::Plot, k::Symbol) =
    if (v = plt.attr[k]) === :match
        plt[_match_map[k]]
    else
        v
    end

# properly retrieve from sp.attr, passing `:match` to the correct key
Base.getindex(sp::Subplot, k::Symbol) =
    if (v = sp.attr[k]) === :match
        if haskey(_match_map2, k)
            sp.plt[_match_map2[k]]
        else
            sp[_match_map[k]]
        end
    else
        v
    end

# properly retrieve from axis.attr, passing `:match` to the correct key
Base.getindex(axis::Axis, k::Symbol) =
    if (v = axis.plotattributes[k]) === :match
        if haskey(_match_map2, k)
            axis.sps[1][_match_map2[k]]
        else
            axis[_match_map[k]]
        end
    else
        v
    end

Base.getindex(series::Series, k::Symbol) = series.plotattributes[k]

Base.setindex!(plt::Plot, v, k::Symbol)      = (plt.attr[k] = v)
Base.setindex!(sp::Subplot, v, k::Symbol)    = (sp.attr[k] = v)
Base.setindex!(axis::Axis, v, k::Symbol)     = (axis.plotattributes[k] = v)
Base.setindex!(series::Series, v, k::Symbol) = (series.plotattributes[k] = v)

Base.get(plt::Plot, k::Symbol, v)      = get(plt.attr, k, v)
Base.get(sp::Subplot, k::Symbol, v)    = get(sp.attr, k, v)
Base.get(axis::Axis, k::Symbol, v)     = get(axis.plotattributes, k, v)
Base.get(series::Series, k::Symbol, v) = get(series.plotattributes, k, v)

# -----------------------------------------------------------------------------

function fg_color(plotattributes::AKW)
    fg = get(plotattributes, :foreground_color, :auto)
    if fg === :auto
        bg = plot_color(get(plotattributes, :background_color, :white))
        fg = alpha(bg) > 0 && isdark(bg) ? colorant"white" : colorant"black"
    else
        plot_color(fg)
    end
end

# update attr from an input dictionary
function _update_plot_args(plt::Plot, plotattributes_in::AKW)
    for (k, v) in _plot_defaults
        slice_arg!(plotattributes_in, plt.attr, k, 1, true)
    end

    # handle colors
    plt[:background_color] = plot_color(plt.attr[:background_color])
    plt[:foreground_color] = fg_color(plt.attr)
    color_or_nothing!(plt.attr, :background_color_outside)
end

# -----------------------------------------------------------------------------

function _update_subplot_periphery(sp::Subplot, anns::AVec)
    # extend annotations, and ensure we always have a (x,y,PlotText) tuple
    newanns = []
    for ann in vcat(anns, sp[:annotations])
        append!(newanns, process_annotation(sp, ann))
    end
    sp.attr[:annotations] = newanns

    # handle legend/colorbar
    sp.attr[:legend_position] = convertLegendValue(sp.attr[:legend_position])
    sp.attr[:colorbar] = convertLegendValue(sp.attr[:colorbar])
    if sp.attr[:colorbar] === :legend
        sp.attr[:colorbar] = sp.attr[:legend_position]
    end
    nothing
end

function _update_subplot_colors(sp::Subplot)
    # background colors
    color_or_nothing!(sp.attr, :background_color_subplot)
    sp.attr[:color_palette] = get_color_palette(sp.attr[:color_palette], 30)
    color_or_nothing!(sp.attr, :legend_background_color)
    color_or_nothing!(sp.attr, :background_color_inside)

    # foreground colors
    color_or_nothing!(sp.attr, :foreground_color_subplot)
    color_or_nothing!(sp.attr, :legend_foreground_color)
    color_or_nothing!(sp.attr, :foreground_color_title)
    nothing
end

_update_margins(sp::Subplot) =
    for sym in (:margin, :left_margin, :top_margin, :right_margin, :bottom_margin)
        if (margin = get(sp.attr, sym, nothing)) isa Tuple
            # transform e.g. (1, :mm) => 1 * Plots.mm
            sp.attr[sym] = margin[1] * getfield(@__MODULE__, margin[2])
        end
    end

function _update_axis(
    plt::Plot,
    sp::Subplot,
    plotattributes_in::AKW,
    letter::Symbol,
    subplot_index::Int,
)
    # get (maybe initialize) the axis
    axis = get_axis(sp, letter)

    _update_axis(axis, plotattributes_in, letter, subplot_index)

    # convert a bool into auto or nothing
    if isa(axis[:ticks], Bool)
        axis[:ticks] = axis[:ticks] ? :auto : nothing
    end

    _update_axis_colors(axis)
    _update_axis_links(plt, axis, letter)
    nothing
end

function _update_axis(
    axis::Axis,
    plotattributes_in::AKW,
    letter::Symbol,
    subplot_index::Int,
)
    # build the KW of arguments from the letter version (i.e. xticks --> ticks)
    kw = KW()
    for k in _all_axis_args
        # first get the args without the letter: `tickfont = font(10)`
        # note: we don't pop because we want this to apply to all axes! (delete after all have finished)
        if haskey(plotattributes_in, k)
            kw[k] = slice_arg(plotattributes_in[k], subplot_index)
        end

        # then get those args that were passed with a leading letter: `xlabel = "X"`
        lk = get_attr_symbol(letter, k)

        if haskey(plotattributes_in, lk)
            kw[k] = slice_arg(plotattributes_in[lk], subplot_index)
        end
    end

    # update the axis
    attr!(axis; kw...)
    nothing
end

function _update_axis_colors(axis::Axis)
    # # update the axis colors
    color_or_nothing!(axis.plotattributes, :foreground_color_axis)
    color_or_nothing!(axis.plotattributes, :foreground_color_border)
    color_or_nothing!(axis.plotattributes, :foreground_color_guide)
    color_or_nothing!(axis.plotattributes, :foreground_color_text)
    color_or_nothing!(axis.plotattributes, :foreground_color_grid)
    color_or_nothing!(axis.plotattributes, :foreground_color_minor_grid)
    nothing
end

function _update_axis_links(plt::Plot, axis::Axis, letter::Symbol)
    # handle linking here.  if we're passed a list of
    # other subplots to link to, link them together
    (link = axis[:link]) |> isempty && return
    for other_sp in link
        link_axes!(axis, get_axis(get_subplot(plt, other_sp), letter))
    end
    axis.plotattributes[:link] = []
    nothing
end

# update a subplots args and axes
function _update_subplot_args(
    plt::Plot,
    sp::Subplot,
    plotattributes_in,
    subplot_index::Int,
    remove_pair::Bool,
)
    anns = RecipesPipeline.pop_kw!(sp.attr, :annotations)

    # grab those args which apply to this subplot
    for k in keys(_subplot_defaults)
        slice_arg!(plotattributes_in, sp.attr, k, subplot_index, remove_pair)
    end

    _update_subplot_colors(sp)
    _update_margins(sp)
    colorbar_update_keys =
        (:clims, :colorbar, :seriestype, :marker_z, :line_z, :fill_z, :colorbar_entry)
    if any(haskey.(Ref(plotattributes_in), colorbar_update_keys))
        _update_subplot_colorbars(sp)
    end

    lims_warned = false
    for letter in (:x, :y, :z)
        _update_axis(plt, sp, plotattributes_in, letter, subplot_index)
        lk = get_attr_symbol(letter, :lims)

        # warn against using `Range` in x,y,z lims
        if !lims_warned &&
           haskey(plotattributes_in, lk) &&
           plotattributes_in[lk] isa AbstractRange
            @warn "lims should be a Tuple, not $(typeof(plotattributes_in[lk]))."
            lims_warned = true
        end
    end

    _update_subplot_periphery(sp, anns)
end

# -----------------------------------------------------------------------------

has_black_border_for_default(st) = error(
    "The seriestype attribute only accepts Symbols, you passed the $(typeof(st)) $st.",
)
has_black_border_for_default(st::Function) =
    error("The seriestype attribute only accepts Symbols, you passed the function $st.")
has_black_border_for_default(st::Symbol) =
    like_histogram(st) || st in (:hexbin, :bar, :shape)

# converts a symbol or string into a Colorant or ColorGradient
# and assigns a color automatically
get_series_color(c, sp::Subplot, n::Int, seriestype) =
    if c === :auto
        like_surface(seriestype) ? cgrad() : _cycle(sp[:color_palette], n)
    elseif isa(c, Int)
        _cycle(sp[:color_palette], c)
    else
        c
    end |> plot_color

get_series_color(c::AbstractArray, sp::Subplot, n::Int, seriestype) =
    map(x -> get_series_color(x, sp, n, seriestype), c)

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

const DEFAULT_LINEWIDTH = Ref(1)

# get a good default linewidth... 0 for surface and heatmaps
_replace_linewidth(plotattributes::AKW) =
    if plotattributes[:linewidth] === :auto
        plotattributes[:linewidth] =
            (get(plotattributes, :seriestype, :path) ∉ (:surface, :heatmap, :image)) *
            DEFAULT_LINEWIDTH[]
    end

function _slice_series_args!(plotattributes::AKW, plt::Plot, sp::Subplot, commandIndex::Int)
    for k in keys(_series_defaults)
        haskey(plotattributes, k) &&
            slice_arg!(plotattributes, plotattributes, k, commandIndex, false)
    end
    plotattributes
end

label_to_string(label::Bool, series_plotindex) =
    label ? label_to_string(:auto, series_plotindex) : ""
label_to_string(label::Nothing, series_plotindex) = ""
label_to_string(label::Missing, series_plotindex) = ""
label_to_string(label::Symbol, series_plotindex) =
    if label === :auto
        string("y", series_plotindex)
    elseif label === :none
        ""
    else
        throw(ArgumentError("unsupported symbol $(label) passed to `label`"))
    end
label_to_string(label, series_plotindex) = string(label)  # Fallback to string promotion

function _update_series_attributes!(plotattributes::AKW, plt::Plot, sp::Subplot)
    pkg = plt.backend
    globalIndex = plotattributes[:series_plotindex]
    plotIndex = _series_index(plotattributes, sp)

    aliasesAndAutopick(
        plotattributes,
        :linestyle,
        _styleAliases,
        supported_styles(pkg),
        plotIndex,
    )
    aliasesAndAutopick(
        plotattributes,
        :markershape,
        _markerAliases,
        supported_markers(pkg),
        plotIndex,
    )

    # update alphas
    for asym in (:linealpha, :markeralpha, :fillalpha)
        if plotattributes[asym] === nothing
            plotattributes[asym] = plotattributes[:seriesalpha]
        end
    end
    if plotattributes[:markerstrokealpha] === nothing
        plotattributes[:markerstrokealpha] = plotattributes[:markeralpha]
    end

    # update series color
    scolor = plotattributes[:seriescolor]
    stype = plotattributes[:seriestype]
    plotattributes[:seriescolor] = scolor = get_series_color(scolor, sp, plotIndex, stype)

    # update other colors (`linecolor`, `markercolor`, `fillcolor`) <- for grep
    for s in (:line, :marker, :fill)
        csym, asym = Symbol(s, :color), Symbol(s, :alpha)
        plotattributes[csym] = if plotattributes[csym] === :auto
            plot_color(if has_black_border_for_default(stype) && s === :line
                sp[:foreground_color_subplot]
            else
                scolor
            end)
        elseif plotattributes[csym] === :match
            plot_color(scolor)
        else
            get_series_color(plotattributes[csym], sp, plotIndex, stype)
        end
    end

    # update markerstrokecolor
    plotattributes[:markerstrokecolor] = if plotattributes[:markerstrokecolor] === :match
        plot_color(sp[:foreground_color_subplot])
    elseif plotattributes[:markerstrokecolor] === :auto
        get_series_color(plotattributes[:markercolor], sp, plotIndex, stype)
    else
        get_series_color(plotattributes[:markerstrokecolor], sp, plotIndex, stype)
    end

    # if marker_z, fill_z or line_z are set, ensure we have a gradient
    if plotattributes[:marker_z] !== nothing
        ensure_gradient!(plotattributes, :markercolor, :markeralpha)
    end
    if plotattributes[:line_z] !== nothing
        ensure_gradient!(plotattributes, :linecolor, :linealpha)
    end
    if plotattributes[:fill_z] !== nothing
        ensure_gradient!(plotattributes, :fillcolor, :fillalpha)
    end

    # scatter plots don't have a line, but must have a shape
    if plotattributes[:seriestype] in (:scatter, :scatterbins, :scatterhist, :scatter3d)
        plotattributes[:linewidth] = 0
        if plotattributes[:markershape] === :none
            plotattributes[:markershape] = :circle
        end
    end

    # set label
    plotattributes[:label] = label_to_string.(plotattributes[:label], globalIndex)

    _replace_linewidth(plotattributes)
    plotattributes
end

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
    expr isa Expr && expr.head === :struct || error("Invalid usage of @add_attributes")
    if (T = expr.args[2]) isa Expr && T.head === :<:
        T = T.args[1]
    end

    key_dict = KW()
    _splitdef!(expr.args[3], key_dict)

    insert_block = Expr(:block)
    for (key, value) in key_dict
        # e.g. _series_defualts[key] = value
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
                Expr(:ref, Expr(:call, getfield, Plots, field), QuoteNode(exp_key)),
                value,
            ),
            :(Plots.add_aliases($(QuoteNode(exp_key)), $(QuoteNode(pl_key)))),
            :(Plots.add_aliases(
                $(QuoteNode(exp_key)),
                $(QuoteNode(Plots.make_non_underscore(exp_key))),
            )),
            :(Plots.add_aliases(
                $(QuoteNode(exp_key)),
                $(QuoteNode(Plots.make_non_underscore(pl_key))),
            )),
        )
    end
    quote
        $expr
        $insert_block
    end |> esc
end

function _splitdef!(blk, key_dict)
    for i in eachindex(blk.args)
        if (ei = blk.args[i]) isa Symbol
            #  var
            continue
        elseif ei isa Expr
            if ei.head === :(=)
                lhs = ei.args[1]
                if lhs isa Symbol
                    #  var = defexpr
                    var = lhs
                elseif lhs isa Expr && lhs.head === :(::) && lhs.args[1] isa Symbol
                    #  var::T = defexpr
                    var = lhs.args[1]
                    type = lhs.args[2]
                    if @isdefined type
                        for field in fieldnames(getproperty(Plots, type))
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
            elseif ei.head === :(::) && ei.args[1] isa Symbol
                # var::Typ
                var = ei.args[1]
                key_dict[var] = defexpr
            elseif ei.head === :block
                # can arise with use of @static inside type decl
                _kwdef!(ei, value_args, key_args)
            end
        end
    end
    blk
end
