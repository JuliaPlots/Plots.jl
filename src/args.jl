

const _keyAliases = Dict{Symbol,Symbol}()

function add_aliases(sym::Symbol, aliases::Symbol...)
    for alias in aliases
        if haskey(_keyAliases, alias)
            error("Already an alias $alias => $(_keyAliases[alias])... can't also alias $sym")
        end
        _keyAliases[alias] = sym
    end
end

function add_non_underscore_aliases!(aliases::Dict{Symbol,Symbol})
    for (k,v) in aliases
        s = string(k)
        if '_' in s
            aliases[Symbol(replace(s, "_" => ""))] = v
        end
    end
end


# ------------------------------------------------------------

const _allAxes = [:auto, :left, :right]
const _axesAliases = Dict{Symbol,Symbol}(
    :a => :auto,
    :l => :left,
    :r => :right
)

const _3dTypes = [
    :path3d, :scatter3d, :surface, :wireframe, :contour3d, :volume
]
const _allTypes = vcat([
    :none, :line, :path, :steppre, :steppost, :sticks, :scatter,
    :heatmap, :hexbin, :barbins, :barhist, :histogram, :scatterbins,
    :scatterhist, :stepbins, :stephist, :bins2d, :histogram2d, :histogram3d,
    :density, :bar, :hline, :vline,
    :contour, :pie, :shape, :image
], _3dTypes)

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
const _line_like = [:line, :path, :steppre, :steppost]
const _surface_like = [:contour, :contourf, :contour3d, :heatmap, :surface, :wireframe, :image]

like_histogram(seriestype::Symbol) = seriestype in _histogram_like
like_line(seriestype::Symbol)      = seriestype in _line_like
like_surface(seriestype::Symbol)   = seriestype in _surface_like

is3d(seriestype::Symbol) = seriestype in _3dTypes
is3d(series::Series) = is3d(series.plotattributes)
is3d(plotattributes::KW) = trueOrAllTrue(is3d, Symbol(plotattributes[:seriestype]))

is3d(sp::Subplot) = string(sp.attr[:projection]) == "3d"
ispolar(sp::Subplot) = string(sp.attr[:projection]) == "polar"
ispolar(series::Series) = ispolar(series.plotattributes[:subplot])

# ------------------------------------------------------------

const _allStyles = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]
const _styleAliases = Dict{Symbol,Symbol}(
    :a    => :auto,
    :s    => :solid,
    :d    => :dash,
    :dd   => :dashdot,
    :ddd  => :dashdotdot,
)

const _allMarkers = vcat(:none, :auto, _shape_keys) #sort(collect(keys(_shapes))))
const _markerAliases = Dict{Symbol,Symbol}(
    :n            => :none,
    :no           => :none,
    :a            => :auto,
    :ellipse      => :circle,
    :c            => :circle,
    :circ         => :circle,
    :square       => :rect,
    :sq           => :rect,
    :r            => :rect,
    :d            => :diamond,
    :^            => :utriangle,
    :ut           => :utriangle,
    :utri         => :utriangle,
    :uptri        => :utriangle,
    :uptriangle   => :utriangle,
    :v            => :dtriangle,
    :V            => :dtriangle,
    :dt           => :dtriangle,
    :dtri         => :dtriangle,
    :downtri      => :dtriangle,
    :downtriangle => :dtriangle,
    :>            => :rtriangle,
    :rt           => :rtriangle,
    :rtri         => :rtriangle,
    :righttri      => :rtriangle,
    :righttriangle => :rtriangle,
    :<            => :ltriangle,
    :lt           => :ltriangle,
    :ltri         => :ltriangle,
    :lighttri      => :ltriangle,
    :lighttriangle => :ltriangle,
    # :+            => :cross,
    :plus         => :cross,
    # :x            => :xcross,
    :X            => :xcross,
    :star         => :star5,
    :s            => :star5,
    :star1        => :star5,
    :s2           => :star8,
    :star2        => :star8,
    :p            => :pentagon,
    :pent         => :pentagon,
    :h            => :hexagon,
    :hex          => :hexagon,
    :hep          => :heptagon,
    :o            => :octagon,
    :oct          => :octagon,
    :spike        => :vline,
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
const _scaleAliases = Dict{Symbol,Symbol}(
    :none => :identity,
    :log  => :log10,
)

const _allGridSyms = [:x, :y, :z,
                    :xy, :xz, :yx, :yz, :zx, :zy,
                    :xyz, :xzy, :yxz, :yzx, :zxy, :zyx,
                    :all, :both, :on, :yes, :show,
                    :none, :off, :no, :hide]
const _allGridArgs = [_allGridSyms; string.(_allGridSyms); nothing]
hasgrid(arg::Nothing, letter) = false
hasgrid(arg::Bool, letter) = arg
function hasgrid(arg::Symbol, letter)
    if arg in _allGridSyms
        arg in (:all, :both, :on) || occursin(string(letter), string(arg))
    else
        @warn("Unknown grid argument $arg; $(Symbol(letter, :grid)) was set to `true` instead.")
        true
    end
end
hasgrid(arg::AbstractString, letter) = hasgrid(Symbol(arg), letter)

const _allShowaxisSyms = [:x, :y, :z,
                    :xy, :xz, :yx, :yz, :zx, :zy,
                    :xyz, :xzy, :yxz, :yzx, :zxy, :zyx,
                    :all, :both, :on, :yes, :show,
                    :off, :no, :hide]
const _allShowaxisArgs = [_allGridSyms; string.(_allGridSyms)]
showaxis(arg::Nothing, letter) = false
showaxis(arg::Bool, letter) = arg
function showaxis(arg::Symbol, letter)
    if arg in _allGridSyms
        arg in (:all, :both, :on, :yes) || occursin(string(letter), string(arg))
    else
        @warn("Unknown showaxis argument $arg; $(Symbol(letter, :showaxis)) was set to `true` instead.")
        true
    end
end
showaxis(arg::AbstractString, letter) = hasgrid(Symbol(arg), letter)

const _allFramestyles = [:box, :semi, :axes, :origin, :zerolines, :grid, :none]
const _framestyleAliases = Dict{Symbol, Symbol}(
    :frame              => :box,
    :border             => :box,
    :on                 => :box,
    :transparent        => :semi,
    :semitransparent    => :semi,
)

const _bar_width = 0.8
# -----------------------------------------------------------------------------

const _series_defaults = KW(
    :label             => "AUTO",
    :seriescolor       => :auto,
    :seriesalpha       => nothing,
    :seriestype        => :path,
    :linestyle         => :solid,
    :linewidth         => :auto,
    :linecolor         => :auto,
    :linealpha         => nothing,
    :fillrange         => nothing,   # ribbons, areas, etc
    :fillcolor         => :match,
    :fillalpha         => nothing,
    :markershape       => :none,
    :markercolor       => :match,
    :markeralpha       => nothing,
    :markersize        => 4,
    :markerstrokestyle => :solid,
    :markerstrokewidth => 1,
    :markerstrokecolor => :match,
    :markerstrokealpha => nothing,
    :bins              => :auto,        # number of bins for hists
    :smooth            => false,     # regression line?
    :group             => nothing,   # groupby vector
    :x                 => nothing,
    :y                 => nothing,
    :z                 => nothing,   # depth for contour, surface, etc
    :marker_z          => nothing,   # value for color scale
    :line_z            => nothing,
    :fill_z            => nothing,
    :levels            => 15,
    :orientation       => :vertical,
    :bar_position      => :overlay,  # for bar plots and histograms: could also be stack (stack up) or dodge (side by side)
    :bar_width         => nothing,
    :bar_edges         => false,
    :xerror            => nothing,
    :yerror            => nothing,
    :ribbon            => nothing,
    :quiver            => nothing,
    :arrow             => nothing,   # allows for adding arrows to line/path... call `arrow(args...)`
    :normalize         => false,     # do we want a normalized histogram?
    :weights           => nothing,   # optional weights for histograms (1D and 2D)
    :contours          => false,     # add contours to 3d surface and wireframe plots
    :contour_labels    => false,
    :match_dimensions  => false,     # do rows match x (true) or y (false) for heatmap/image/spy? see issue 196
                                     # this ONLY effects whether or not the z-matrix is transposed for a heatmap display!
    :subplot           => :auto,     # which subplot(s) does this series belong to?
    :series_annotations => nothing,       # a list of annotations which apply to the coordinates of this series
    :primary            => true,     # when true, this "counts" as a series for color selection, etc.  the main use is to allow
                                     #     one logical series to be broken up (path and markers, for example)
    :hover              => nothing,  # text to display when hovering over the data points
    :stride             => (1,1),    # array stride for wireframe/surface, the first element is the row stride and the second is the column stride.
)


const _plot_defaults = KW(
    :plot_title                  => "",
    :background_color            => colorant"white",   # default for all backgrounds,
    :background_color_outside    => :match,            # background outside grid,
    :foreground_color            => :auto,             # default for all foregrounds, and title color,
    :fontfamily                  => "sans-serif",
    :size                        => (600,400),
    :pos                         => (0,0),
    :window_title                 => "Plots.jl",
    :show                        => false,
    :layout                      => 1,
    :link                        => :none,
    :overwrite_figure            => true,
    :html_output_format          => :auto,
    :inset_subplots              => nothing,   # optionally pass a vector of (parent,bbox) tuples which are
                                               # the parent layout and the relative bounding box of inset subplots
    :dpi                         => DPI,        # dots per inch for images, etc
    :thickness_scaling           => 1,
    :display_type                => :auto,
    :extra_kwargs                => KW(),
)


const _subplot_defaults = KW(
    :title                    => "",
    :title_location           => :center,           # also :left or :right
    :fontfamily_subplot       => :match,
    :titlefontfamily          => :match,
    :titlefontsize            => 14,
    :titlefonthalign          => :hcenter,
    :titlefontvalign          => :vcenter,
    :titlefontrotation        => 0.0,
    :titlefontcolor           => :match,
    :background_color_subplot => :match,            # default for other bg colors... match takes plot default
    :background_color_legend  => :match,            # background of legend
    :background_color_inside  => :match,            # background inside grid
    :foreground_color_subplot => :match,            # default for other fg colors... match takes plot default
    :foreground_color_legend  => :match,            # foreground of legend
    :foreground_color_title   => :match,            # title color
    :color_palette            => :auto,
    :legend                   => :best,
    :legendtitle              => nothing,
    :colorbar                 => :legend,
    :clims                    => :auto,
    :legendfontfamily         => :match,
    :legendfontsize           => 8,
    :legendfonthalign         => :hcenter,
    :legendfontvalign         => :vcenter,
    :legendfontrotation       => 0.0,
    :legendfontcolor          => :match,
    :annotations              => [],                # annotation tuples... list of (x,y,annotation)
    :projection               => :none,             # can also be :polar or :3d
    :aspect_ratio             => :none,             # choose from :none or :equal
    :margin                   => 1mm,
    :left_margin              => :match,
    :top_margin               => :match,
    :right_margin             => :match,
    :bottom_margin            => :match,
    :subplot_index            => -1,
    :colorbar_title           => "",
    :framestyle               => :axes,
    :camera                   => (30,30),
)

const _axis_defaults = KW(
    :guide     => "",
    :guide_position => :auto,
    :lims      => :auto,
    :ticks     => :auto,
    :scale     => :identity,
    :rotation  => 0,
    :flip      => false,
    :link      => [],
    :tickfontfamily         => :match,
    :tickfontsize           => 8,
    :tickfonthalign         => :hcenter,
    :tickfontvalign         => :vcenter,
    :tickfontrotation       => 0.0,
    :tickfontcolor          => :match,
    :guidefontfamily         => :match,
    :guidefontsize           => 11,
    :guidefonthalign         => :hcenter,
    :guidefontvalign         => :vcenter,
    :guidefontrotation       => 0.0,
    :guidefontcolor          => :match,
    :foreground_color_axis   => :match,            # axis border/tick colors,
    :foreground_color_border => :match,            # plot area border/spines,
    :foreground_color_text   => :match,            # tick text color,
    :foreground_color_guide  => :match,            # guide text color,
    :discrete_values => [],
    :formatter => :auto,
    :mirror => false,
    :grid                     => true,
    :foreground_color_grid    => :match,            # grid color
    :gridalpha                => 0.1,
    :gridstyle                => :solid,
    :gridlinewidth            => 0.5,
    :foreground_color_minor_grid => :match,            # grid color
    :minorgridalpha           => 0.05,
    :minorgridstyle           => :solid,
    :minorgridlinewidth       => 0.5,
    :tick_direction           => :in,
    :minorticks               => false,
    :minorgrid                => false,
    :showaxis                 => true,
    :widen                    => true,
)

const _suppress_warnings = Set{Symbol}([
    :x_discrete_indices,
    :y_discrete_indices,
    :z_discrete_indices,
    :subplot,
    :subplot_index,
    :series_plotindex,
    :link,
    :plot_object,
    :primary,
    :smooth,
    :relative_bbox,
])

# add defaults for the letter versions
const _axis_defaults_byletter = KW()
for letter in (:x,:y,:z)
    for k in keys(_axis_defaults)
    # for k in (
    #             :guide,
    #             :lims,
    #             :ticks,
    #             :scale,
    #             :rotation,
    #             :flip,
    #             :link,
    #             :tickfont,
    #             :guidefont,
    #             :foreground_color_axis,
    #             :foreground_color_border,
    #             :foreground_color_text,
    #             :foreground_color_guide,
    #             :discrete_values,
    #             :formatter,
    #         )
        _axis_defaults_byletter[Symbol(letter,k)] = :match

        # allow the underscore version too: xguide or x_guide
        add_aliases(Symbol(letter, k), Symbol(letter, "_", k))
    end
end

const _all_defaults = KW[
    _series_defaults,
    _plot_defaults,
    _subplot_defaults,
    _axis_defaults_byletter
]

const _initial_defaults = deepcopy(_all_defaults)
const _initial_axis_defaults = deepcopy(_axis_defaults)

# to be able to reset font sizes to initial values
const _initial_fontsizes = Dict(:titlefontsize  => _subplot_defaults[:titlefontsize],
                                :legendfontsize => _subplot_defaults[:legendfontsize],
                                :tickfontsize   => _axis_defaults[:tickfontsize],
                                :guidefontsize  => _axis_defaults[:guidefontsize])

const _all_args = sort(collect(union(map(keys, _all_defaults)...)))

RecipesBase.is_key_supported(k::Symbol) = is_attr_supported(k)

# -----------------------------------------------------------------------------

makeplural(s::Symbol) = Symbol(string(s,"s"))

autopick(arr::AVec, idx::Integer) = arr[mod1(idx,length(arr))]
autopick(notarr, idx::Integer) = notarr

autopick_ignore_none_auto(arr::AVec, idx::Integer) = autopick(setdiff(arr, [:none, :auto]), idx)
autopick_ignore_none_auto(notarr, idx::Integer) = notarr

function aliasesAndAutopick(plotattributes::KW, sym::Symbol, aliases::Dict{Symbol,Symbol}, options::AVec, plotIndex::Int)
    if plotattributes[sym] == :auto
        plotattributes[sym] = autopick_ignore_none_auto(options, plotIndex)
    elseif haskey(aliases, plotattributes[sym])
        plotattributes[sym] = aliases[plotattributes[sym]]
    end
end

function aliases(aliasMap::Dict{Symbol,Symbol}, val)
    sortedkeys(filter((k,v)-> v==val, aliasMap))
end

# -----------------------------------------------------------------------------


# colors
add_aliases(:seriescolor, :c, :color, :colour)
add_aliases(:linecolor, :lc, :lcolor, :lcolour, :linecolour)
add_aliases(:markercolor, :mc, :mcolor, :mcolour, :markercolour)
add_aliases(:markerstrokecolor, :msc, :mscolor, :mscolour, :markerstrokecolour)
add_aliases(:markerstrokewidth, :msw, :mswidth)
add_aliases(:fillcolor, :fc, :fcolor, :fcolour, :fillcolour)

add_aliases(:background_color, :bg, :bgcolor, :bg_color, :background,
                              :background_colour, :bgcolour, :bg_colour)
add_aliases(:background_color_legend, :bg_legend, :bglegend, :bgcolor_legend, :bg_color_legend, :background_legend,
                              :background_colour_legend, :bgcolour_legend, :bg_colour_legend)
add_aliases(:background_color_subplot, :bg_subplot, :bgsubplot, :bgcolor_subplot, :bg_color_subplot, :background_subplot,
                              :background_colour_subplot, :bgcolour_subplot, :bg_colour_subplot)
add_aliases(:background_color_inside, :bg_inside, :bginside, :bgcolor_inside, :bg_color_inside, :background_inside,
                              :background_colour_inside, :bgcolour_inside, :bg_colour_inside)
add_aliases(:background_color_outside, :bg_outside, :bgoutside, :bgcolor_outside, :bg_color_outside, :background_outside,
                              :background_colour_outside, :bgcolour_outside, :bg_colour_outside)
add_aliases(:foreground_color, :fg, :fgcolor, :fg_color, :foreground,
                            :foreground_colour, :fgcolour, :fg_colour)
add_aliases(:foreground_color_legend, :fg_legend, :fglegend, :fgcolor_legend, :fg_color_legend, :foreground_legend,
                            :foreground_colour_legend, :fgcolour_legend, :fg_colour_legend)
add_aliases(:foreground_color_subplot, :fg_subplot, :fgsubplot, :fgcolor_subplot, :fg_color_subplot, :foreground_subplot,
                            :foreground_colour_subplot, :fgcolour_subplot, :fg_colour_subplot)
add_aliases(:foreground_color_grid, :fg_grid, :fggrid, :fgcolor_grid, :fg_color_grid, :foreground_grid,
                            :foreground_colour_grid, :fgcolour_grid, :fg_colour_grid, :gridcolor)
add_aliases(:foreground_color_minor_grid, :fg_minor_grid, :fgminorgrid, :fgcolor_minorgrid, :fg_color_minorgrid, :foreground_minorgrid,
                            :foreground_colour_minor_grid, :fgcolour_minorgrid, :fg_colour_minor_grid, :minorgridcolor)
add_aliases(:foreground_color_title, :fg_title, :fgtitle, :fgcolor_title, :fg_color_title, :foreground_title,
                            :foreground_colour_title, :fgcolour_title, :fg_colour_title, :titlecolor)
add_aliases(:foreground_color_axis, :fg_axis, :fgaxis, :fgcolor_axis, :fg_color_axis, :foreground_axis,
                            :foreground_colour_axis, :fgcolour_axis, :fg_colour_axis, :axiscolor)
add_aliases(:foreground_color_border, :fg_border, :fgborder, :fgcolor_border, :fg_color_border, :foreground_border,
                            :foreground_colour_border, :fgcolour_border, :fg_colour_border, :bordercolor)
add_aliases(:foreground_color_text, :fg_text, :fgtext, :fgcolor_text, :fg_color_text, :foreground_text,
                            :foreground_colour_text, :fgcolour_text, :fg_colour_text, :textcolor)
add_aliases(:foreground_color_guide, :fg_guide, :fgguide, :fgcolor_guide, :fg_color_guide, :foreground_guide,
                            :foreground_colour_guide, :fgcolour_guide, :fg_colour_guide, :guidecolor)

# alphas
add_aliases(:seriesalpha, :alpha, :α, :opacity)
add_aliases(:linealpha, :la, :lalpha, :lα, :lineopacity, :lopacity)
add_aliases(:markeralpha, :ma, :malpha, :mα, :markeropacity, :mopacity)
add_aliases(:markerstrokealpha, :msa, :msalpha, :msα, :markerstrokeopacity, :msopacity)
add_aliases(:fillalpha, :fa, :falpha, :fα, :fillopacity, :fopacity)
add_aliases(:gridalpha, :ga, :galpha, :gα, :gridopacity, :gopacity)

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
add_aliases(:xlims, :xlim, :xlimit, :xlimits)
add_aliases(:xticks, :xtick)
add_aliases(:xrotation, :xrot, :xr)
add_aliases(:yguide, :ylabel, :ylab, :yl)
add_aliases(:ylims, :ylim, :ylimit, :ylimits)
add_aliases(:yticks, :ytick)
add_aliases(:yrotation, :yrot, :yr)
add_aliases(:zguide, :zlabel, :zlab, :zl)
add_aliases(:zlims, :zlim, :zlimit, :zlimits)
add_aliases(:zticks, :ztick)
add_aliases(:zrotation, :zrot, :zr)
add_aliases(:fill_z, :fillz, :fz, :surfacecolor, :surfacecolour, :sc, :surfcolor, :surfcolour)
add_aliases(:legend, :leg, :key)
add_aliases(:legendtitle, :legend_title, :labeltitle, :label_title, :leg_title, :key_title)
add_aliases(:colorbar, :cb, :cbar, :colorkey)
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
add_aliases(:quiver, :velocity, :quiver2d, :gradient, :vectorfield)
add_aliases(:normalize, :norm, :normed, :normalized)
add_aliases(:aspect_ratio, :aspectratio, :axis_ratio, :axisratio, :ratio)
add_aliases(:match_dimensions, :transpose, :transpose_z)
add_aliases(:subplot, :sp, :subplt, :splt)
add_aliases(:projection, :proj)
add_aliases(:title_location, :title_loc, :titleloc, :title_position, :title_pos, :titlepos, :titleposition, :title_align, :title_alignment)
add_aliases(:series_annotations, :series_ann, :seriesann, :series_anns, :seriesanns, :series_annotation, :text, :txt, :texts, :txts)
add_aliases(:html_output_format, :format, :fmt, :html_format)
add_aliases(:orientation, :direction, :dir)
add_aliases(:inset_subplots, :inset, :floating)
add_aliases(:stride, :wirefame_stride, :surface_stride, :surf_str, :str)
add_aliases(:gridlinewidth, :gridwidth, :grid_linewidth, :grid_width, :gridlw, :grid_lw)
add_aliases(:gridstyle, :grid_style, :gridlinestyle, :grid_linestyle, :grid_ls, :gridls)
add_aliases(:minorgridlinewidth, :minorgridwidth, :minorgrid_linewidth, :minorgrid_width, :minorgridlw, :minorgrid_lw)
add_aliases(:minorgridstyle, :minorgrid_style, :minorgridlinestyle, :minorgrid_linestyle, :minorgrid_ls, :minorgridls)
add_aliases(:framestyle, :frame_style, :frame, :axesstyle, :axes_style, :boxstyle, :box_style, :box, :borderstyle, :border_style, :border)
add_aliases(:tick_direction, :tickdirection, :tick_dir, :tickdir, :tick_orientation, :tickorientation, :tick_or, :tickor)
add_aliases(:camera, :cam, :viewangle, :view_angle)
add_aliases(:contour_labels, :contourlabels, :clabels, :clabs)

# add all pluralized forms to the _keyAliases dict
for arg in keys(_series_defaults)
    _keyAliases[makeplural(arg)] = arg
end



# -----------------------------------------------------------------------------

# update the defaults globally

"""
`default(key)` returns the current default value for that key
`default(key, value)` sets the current default value for that key
`default(; kw...)` will set the current default value for each key/value pair
`default(plotattributes, key)` returns the key from  plotattributes if it exists, otherwise `default(key)`
"""
function default(k::Symbol)
    k = get(_keyAliases, k, k)
    for defaults in _all_defaults
        if haskey(defaults, k)
            return defaults[k]
        end
    end
    if haskey(_axis_defaults, k)
        return _axis_defaults[k]
    end
    k in _suppress_warnings || error("Unknown key: ", k)
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
    k in _suppress_warnings || error("Unknown key: ", k)
end

function default(; kw...)
    kw = KW(kw)
    preprocessArgs!(kw)
    for (k,v) in kw
        default(k, v)
    end
end

function default(plotattributes::KW, k::Symbol)
    get(plotattributes, k, default(k))
end

function reset_defaults()
    foreach(merge!, _all_defaults, _initial_defaults)
    merge!(_axis_defaults, _initial_axis_defaults)
end

# -----------------------------------------------------------------------------

# if arg is a valid color value, then set plotattributes[csym] and return true
function handleColors!(plotattributes::KW, arg, csym::Symbol)
    try
        if arg == :auto
            plotattributes[csym] = :auto
        else
            # c = colorscheme(arg)
            c = plot_color(arg)
            plotattributes[csym] = c
        end
        return true
    catch
    end
    false
end



function processLineArg(plotattributes::KW, arg)
    # seriestype
    if allLineTypes(arg)
        plotattributes[:seriestype] = arg

    # linestyle
    elseif allStyles(arg)
        plotattributes[:linestyle] = arg

    elseif typeof(arg) <: Stroke
        arg.width == nothing || (plotattributes[:linewidth] = arg.width)
        arg.color == nothing || (plotattributes[:linecolor] = arg.color == :auto ? :auto : plot_color(arg.color))
        arg.alpha == nothing || (plotattributes[:linealpha] = arg.alpha)
        arg.style == nothing || (plotattributes[:linestyle] = arg.style)

    elseif typeof(arg) <: Brush
        arg.size  == nothing || (plotattributes[:fillrange] = arg.size)
        arg.color == nothing || (plotattributes[:fillcolor] = arg.color == :auto ? :auto : plot_color(arg.color))
        arg.alpha == nothing || (plotattributes[:fillalpha] = arg.alpha)

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
        @warn("Skipped line arg $arg.")

    end
end


function processMarkerArg(plotattributes::KW, arg)
    # markershape
    if allShapes(arg)
        plotattributes[:markershape] = arg

    # stroke style
    elseif allStyles(arg)
        plotattributes[:markerstrokestyle] = arg

    elseif typeof(arg) <: Stroke
        arg.width == nothing || (plotattributes[:markerstrokewidth] = arg.width)
        arg.color == nothing || (plotattributes[:markerstrokecolor] = arg.color == :auto ? :auto : plot_color(arg.color))
        arg.alpha == nothing || (plotattributes[:markerstrokealpha] = arg.alpha)
        arg.style == nothing || (plotattributes[:markerstrokestyle] = arg.style)

    elseif typeof(arg) <: Brush
        arg.size  == nothing || (plotattributes[:markersize]  = arg.size)
        arg.color == nothing || (plotattributes[:markercolor] = arg.color == :auto ? :auto : plot_color(arg.color))
        arg.alpha == nothing || (plotattributes[:markeralpha] = arg.alpha)

    # linealpha
    elseif allAlphas(arg)
        plotattributes[:markeralpha] = arg

    # markersize
    elseif allReals(arg)
        plotattributes[:markersize] = arg

    # markercolor
    elseif !handleColors!(plotattributes, arg, :markercolor)
        @warn("Skipped marker arg $arg.")

    end
end


function processFillArg(plotattributes::KW, arg)
    # fr = get(plotattributes, :fillrange, 0)
    if typeof(arg) <: Brush
        arg.size  == nothing || (plotattributes[:fillrange] = arg.size)
        arg.color == nothing || (plotattributes[:fillcolor] = arg.color == :auto ? :auto : plot_color(arg.color))
        arg.alpha == nothing || (plotattributes[:fillalpha] = arg.alpha)

    elseif typeof(arg) <: Bool
        plotattributes[:fillrange] = arg ? 0 : nothing

    # fillrange function
    elseif allFunctions(arg)
        plotattributes[:fillrange] = arg

    # fillalpha
    elseif allAlphas(arg)
        plotattributes[:fillalpha] = arg

    # fillrange provided as vector or number
    elseif typeof(arg) <: Union{AbstractArray{<:Real}, Real}
        plotattributes[:fillrange] = arg

    elseif !handleColors!(plotattributes, arg, :fillcolor)

        plotattributes[:fillrange] = arg
    end
    # plotattributes[:fillrange] = fr
    return
end


function processGridArg!(plotattributes::KW, arg, letter)
    if arg in _allGridArgs || isa(arg, Bool)
        plotattributes[Symbol(letter, :grid)] = hasgrid(arg, letter)

    elseif allStyles(arg)
        plotattributes[Symbol(letter, :gridstyle)] = arg

    elseif typeof(arg) <: Stroke
        arg.width == nothing || (plotattributes[Symbol(letter, :gridlinewidth)] = arg.width)
        arg.color == nothing || (plotattributes[Symbol(letter, :foreground_color_grid)] = arg.color in (:auto, :match) ? :match : plot_color(arg.color))
        arg.alpha == nothing || (plotattributes[Symbol(letter, :gridalpha)] = arg.alpha)
        arg.style == nothing || (plotattributes[Symbol(letter, :gridstyle)] = arg.style)

    # linealpha
    elseif allAlphas(arg)
        plotattributes[Symbol(letter, :gridalpha)] = arg

    # linewidth
    elseif allReals(arg)
        plotattributes[Symbol(letter, :gridlinewidth)] = arg

    # color
    elseif !handleColors!(plotattributes, arg, Symbol(letter, :foreground_color_grid))
        @warn("Skipped grid arg $arg.")

    end
end

function processMinorGridArg!(plotattributes::KW, arg, letter)
    if arg in _allGridArgs || isa(arg, Bool)
        plotattributes[Symbol(letter, :minorgrid)] = hasgrid(arg, letter)

    elseif allStyles(arg)
        plotattributes[Symbol(letter, :minorgridstyle)] = arg
        plotattributes[Symbol(letter, :minorgrid)] = true

    elseif typeof(arg) <: Stroke
        arg.width == nothing || (plotattributes[Symbol(letter, :minorgridlinewidth)] = arg.width)
        arg.color == nothing || (plotattributes[Symbol(letter, :foreground_color_minor_grid)] = arg.color in (:auto, :match) ? :match : plot_color(arg.color))
        arg.alpha == nothing || (plotattributes[Symbol(letter, :minorgridalpha)] = arg.alpha)
        arg.style == nothing || (plotattributes[Symbol(letter, :minorgridstyle)] = arg.style)
        plotattributes[Symbol(letter, :minorgrid)] = true

    # linealpha
    elseif allAlphas(arg)
        plotattributes[Symbol(letter, :minorgridalpha)] = arg
        plotattributes[Symbol(letter, :minorgrid)] = true

    # linewidth
    elseif allReals(arg)
        plotattributes[Symbol(letter, :minorgridlinewidth)] = arg
        plotattributes[Symbol(letter, :minorgrid)] = true

    # color
    elseif handleColors!(plotattributes, arg, Symbol(letter, :foreground_color_minor_grid))
        plotattributes[Symbol(letter, :minorgrid)] = true
    else
        @warn("Skipped grid arg $arg.")
    end
end

function processFontArg!(plotattributes::KW, fontname::Symbol, arg)
    T = typeof(arg)
    if T <: Font
        plotattributes[Symbol(fontname, :family)] = arg.family
        plotattributes[Symbol(fontname, :size)] = arg.pointsize
        plotattributes[Symbol(fontname, :halign)] = arg.halign
        plotattributes[Symbol(fontname, :valign)] = arg.valign
        plotattributes[Symbol(fontname, :rotation)] = arg.rotation
        plotattributes[Symbol(fontname, :color)] = arg.color
    elseif arg == :center
        plotattributes[Symbol(fontname, :halign)] = :hcenter
        plotattributes[Symbol(fontname, :valign)] = :vcenter
    elseif arg in (:hcenter, :left, :right)
        plotattributes[Symbol(fontname, :halign)] = arg
    elseif arg in (:vcenter, :top, :bottom)
        plotattributes[Symbol(fontname, :valign)] = arg
    elseif T <: Colorant
        plotattributes[Symbol(fontname, :color)] = arg
    elseif T <: Symbol || T <: AbstractString
        try
            plotattributes[Symbol(fontname, :color)] = parse(Colorant, string(arg))
        catch
            plotattributes[Symbol(fontname, :family)] = string(arg)
        end
    elseif typeof(arg) <: Integer
        plotattributes[Symbol(fontname, :size)] = arg
    elseif typeof(arg) <: Real
        plotattributes[Symbol(fontname, :rotation)] = convert(Float64, arg)
    else
        @warn("Skipped font arg: $arg ($(typeof(arg)))")
    end
end

_replace_markershape(shape::Symbol) = get(_markerAliases, shape, shape)
_replace_markershape(shapes::AVec) = map(_replace_markershape, shapes)
_replace_markershape(shape) = shape

function _add_markershape(plotattributes::KW)
    # add the markershape if it needs to be added... hack to allow "m=10" to add a shape,
    # and still allow overriding in _apply_recipe
    ms = pop!(plotattributes, :markershape_to_add, :none)
    if !haskey(plotattributes, :markershape) && ms != :none
        plotattributes[:markershape] = ms
    end
end

"Handle all preprocessing of args... break out colors/sizes/etc and replace aliases."
function preprocessArgs!(plotattributes::KW)
    replaceAliases!(plotattributes, _keyAliases)

    # clear all axis stuff
    # if haskey(plotattributes, :axis) && plotattributes[:axis] in (:none, nothing, false)
    #     plotattributes[:ticks] = nothing
    #     plotattributes[:foreground_color_border] = RGBA(0,0,0,0)
    #     plotattributes[:foreground_color_axis] = RGBA(0,0,0,0)
    #     plotattributes[:grid] = false
    #     delete!(plotattributes, :axis)
    # end
    # for letter in (:x, :y, :z)
    #     asym = Symbol(letter, :axis)
    #     if haskey(plotattributes, asym) || plotattributes[asym] in (:none, nothing, false)
    #         plotattributes[Symbol(letter, :ticks)] = nothing
    #         plotattributes[Symbol(letter, :foreground_color_border)] = RGBA(0,0,0,0)
    #     end
    # end

    # handle axis args common to all axis
    args = pop!(plotattributes, :axis, ())
    for arg in wraptuple(args)
        for letter in (:x, :y, :z)
            process_axis_arg!(plotattributes, arg, letter)
        end
    end
    # handle axis args
    for letter in (:x, :y, :z)
        asym = Symbol(letter, :axis)
        args = pop!(plotattributes, asym, ())
        if !(typeof(args) <: Axis)
            for arg in wraptuple(args)
                process_axis_arg!(plotattributes, arg, letter)
            end
        end
    end

    # handle grid args common to all axes
    args = pop!(plotattributes, :grid, ())
    for arg in wraptuple(args)
        for letter in (:x, :y, :z)
            processGridArg!(plotattributes, arg, letter)
        end
    end
    # handle individual axes grid args
    for letter in (:x, :y, :z)
        gridsym = Symbol(letter, :grid)
        args = pop!(plotattributes, gridsym, ())
        for arg in wraptuple(args)
            processGridArg!(plotattributes, arg, letter)
        end
    end
    # handle minor grid args common to all axes
    args = pop!(plotattributes, :minorgrid, ())
    for arg in wraptuple(args)
        for letter in (:x, :y, :z)
            processMinorGridArg!(plotattributes, arg, letter)
        end
    end
    # handle individual axes grid args
    for letter in (:x, :y, :z)
        gridsym = Symbol(letter, :minorgrid)
        args = pop!(plotattributes, gridsym, ())
        for arg in wraptuple(args)
            processMinorGridArg!(plotattributes, arg, letter)
        end
    end
    # fonts
    for fontname in (:titlefont, :legendfont)
        args = pop!(plotattributes, fontname, ())
        for arg in wraptuple(args)
            processFontArg!(plotattributes, fontname, arg)
        end
    end
    # handle font args common to all axes
    for fontname in (:tickfont, :guidefont)
        args = pop!(plotattributes, fontname, ())
        for arg in wraptuple(args)
            for letter in (:x, :y, :z)
                processFontArg!(plotattributes, Symbol(letter, fontname), arg)
            end
        end
    end
    # handle individual axes font args
    for letter in (:x, :y, :z)
        for fontname in (:tickfont, :guidefont)
            args = pop!(plotattributes, Symbol(letter, fontname), ())
            for arg in wraptuple(args)
                processFontArg!(plotattributes, Symbol(letter, fontname), arg)
            end
        end
    end

    # handle line args
    for arg in wraptuple(pop!(plotattributes, :line, ()))
        processLineArg(plotattributes, arg)
    end

    if haskey(plotattributes, :seriestype) && haskey(_typeAliases, plotattributes[:seriestype])
        plotattributes[:seriestype] = _typeAliases[plotattributes[:seriestype]]
    end

    # handle marker args... default to ellipse if shape not set
    anymarker = false
    for arg in wraptuple(get(plotattributes, :marker, ()))
        processMarkerArg(plotattributes, arg)
        anymarker = true
    end
    delete!(plotattributes, :marker)
    if haskey(plotattributes, :markershape)
        plotattributes[:markershape] = _replace_markershape(plotattributes[:markershape])
        if plotattributes[:markershape] == :none && plotattributes[:seriestype] in (:scatter, :scatterbins, :scatterhist, :scatter3d) #the default should be :auto, not :none, so that :none can be set explicitly and would be respected
            plotattributes[:markershape] = :circle
        end
    elseif anymarker
        plotattributes[:markershape_to_add] = :circle  # add it after _apply_recipe
    end

    # handle fill
    for arg in wraptuple(get(plotattributes, :fill, ()))
        processFillArg(plotattributes, arg)
    end
    delete!(plotattributes, :fill)

    # handle series annotations
    if haskey(plotattributes, :series_annotations)
        plotattributes[:series_annotations] = series_annotations(wraptuple(plotattributes[:series_annotations])...)
    end

  # convert into strokes and brushes

    if haskey(plotattributes, :arrow)
        a = plotattributes[:arrow]
        plotattributes[:arrow] = if a == true
            arrow()
        elseif a in (false, nothing, :none)
            nothing
        elseif !(typeof(a) <: Arrow)
            arrow(wraptuple(a)...)
        else
            a
        end
    end


    # if get(plotattributes, :arrow, false) == true
    #     plotattributes[:arrow] = arrow()
    # end

    # legends
    if haskey(plotattributes, :legend)
        plotattributes[:legend] = convertLegendValue(plotattributes[:legend])
    end
    if haskey(plotattributes, :colorbar)
        plotattributes[:colorbar] = convertLegendValue(plotattributes[:colorbar])
    end

    # framestyle
    if haskey(plotattributes, :framestyle) && haskey(_framestyleAliases, plotattributes[:framestyle])
        plotattributes[:framestyle] = _framestyleAliases[plotattributes[:framestyle]]
    end

    # warnings for moved recipes
    st = get(plotattributes, :seriestype, :path)
    if st in (:boxplot, :violin, :density) && !isdefined(Main, :StatPlots)
        @warn("seriestype $st has been moved to StatPlots.  To use: \`Pkg.add(\"StatPlots\"); using StatPlots\`")
    end

    return
end

# -----------------------------------------------------------------------------

"A special type that will break up incoming data into groups, and allow for easier creation of grouped plots"
mutable struct GroupBy
    groupLabels::Vector           # length == numGroups
    groupIds::Vector{Vector{Int}} # list of indices for each group
end


# this is when given a vector-type of values to group by
function extractGroupArgs(v::AVec, args...; legendEntry = string)
    groupLabels = sort(collect(unique(v)))
    n = length(groupLabels)
    if n > 100
        @warn("You created n=$n groups... Is that intended?")
    end
    groupIds = Vector{Int}[filter(i -> v[i] == glab, 1:length(v)) for glab in groupLabels]
    GroupBy(map(legendEntry, groupLabels), groupIds)
end

legendEntryFromTuple(ns::Tuple) = join(ns, ' ')

# this is when given a tuple of vectors of values to group by
function extractGroupArgs(vs::Tuple, args...)
    isempty(vs) && return GroupBy([""], [1:size(args[1],1)])
    v = map(tuple, vs...)
    extractGroupArgs(v, args...; legendEntry = legendEntryFromTuple)
end

# allow passing NamedTuples for a named legend entry
legendEntryFromTuple(ns::NamedTuple) =
    join(["$k = $v" for (k, v) in pairs(ns)], ", ")

function extractGroupArgs(vs::NamedTuple, args...)
    isempty(vs) && return GroupBy([""], [1:size(args[1],1)])
    v = map(NamedTuple{keys(vs)}∘tuple, values(vs)...)
    extractGroupArgs(v, args...; legendEntry = legendEntryFromTuple)
end

# expecting a mapping of "group label" to "group indices"
function extractGroupArgs(idxmap::Dict{T,V}, args...) where {T, V<:AVec{Int}}
    groupLabels = sortedkeys(idxmap)
    groupIds = Vector{Int}[collect(idxmap[k]) for k in groupLabels]
    GroupBy(groupLabels, groupIds)
end

filter_data(v::AVec, idxfilter::AVec{Int}) = v[idxfilter]
filter_data(v, idxfilter) = v

function filter_data!(plotattributes::KW, idxfilter)
    for s in (:x, :y, :z)
        plotattributes[s] = filter_data(get(plotattributes, s, nothing), idxfilter)
    end
end

function _filter_input_data!(plotattributes::KW)
    idxfilter = pop!(plotattributes, :idxfilter, nothing)
    if idxfilter != nothing
        filter_data!(plotattributes, idxfilter)
    end
end


# -----------------------------------------------------------------------------

const _already_warned = Dict{Symbol,Set{Symbol}}()
const _to_warn = Set{Symbol}()

function warnOnUnsupported_args(pkg::AbstractBackend, plotattributes::KW)
    empty!(_to_warn)
    bend = backend_name(pkg)
    already_warned = get!(_already_warned, bend, Set{Symbol}())
    for k in keys(plotattributes)
        is_attr_supported(pkg, k) && continue
        k in _suppress_warnings && continue
        if plotattributes[k] != default(k)
            k in already_warned || push!(_to_warn, k)
        end
    end

    if !isempty(_to_warn)
        for k in sort(collect(_to_warn))
            push!(already_warned, k)
            @warn("Keyword argument $k not supported with $pkg.  Choose from: $(supported_attrs(pkg))")
        end
    end
end

# _markershape_supported(pkg::AbstractBackend, shape::Symbol) = shape in supported_markers(pkg)
# _markershape_supported(pkg::AbstractBackend, shape::Shape) = Shape in supported_markers(pkg)
# _markershape_supported(pkg::AbstractBackend, shapes::AVec) = all([_markershape_supported(pkg, shape) for shape in shapes])

function warnOnUnsupported(pkg::AbstractBackend, plotattributes::KW)
    if !is_seriestype_supported(pkg, plotattributes[:seriestype])
        @warn("seriestype $(plotattributes[:seriestype]) is unsupported with $pkg.  Choose from: $(supported_seriestypes(pkg))")
    end
    if !is_style_supported(pkg, plotattributes[:linestyle])
        @warn("linestyle $(plotattributes[:linestyle]) is unsupported with $pkg.  Choose from: $(supported_styles(pkg))")
    end
    if !is_marker_supported(pkg, plotattributes[:markershape])
        @warn("markershape $(plotattributes[:markershape]) is unsupported with $pkg.  Choose from: $(supported_markers(pkg))")
    end
end

function warnOnUnsupported_scales(pkg::AbstractBackend, plotattributes::KW)
    for k in (:xscale, :yscale, :zscale, :scale)
        if haskey(plotattributes, k)
            v = plotattributes[k]
            if !is_scale_supported(pkg, v)
                @warn("scale $v is unsupported with $pkg.  Choose from: $(supported_scales(pkg))")
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
    elseif val in (:right, :left, :top, :bottom, :inside, :best, :legend, :topright, :topleft, :bottomleft, :bottomright, :outertopright)
        val
    else
        error("Invalid symbol for legend: $val")
    end
end
convertLegendValue(val::Bool) = val ? :best : :none
convertLegendValue(val::Nothing) = :none
convertLegendValue(v::Tuple{S,T}) where {S<:Real, T<:Real} = v
convertLegendValue(v::AbstractArray) = map(convertLegendValue, v)

# -----------------------------------------------------------------------------


# 1-row matrices will give an element
# multi-row matrices will give a column
# InputWrapper just gives the contents
# anything else is returned as-is
function slice_arg(v::AMat, idx::Int)
    c = mod1(idx, size(v,2))
    size(v,1) == 1 ? v[1,c] : v[:,c]
end
slice_arg(wrapper::InputWrapper, idx) = wrapper.obj
slice_arg(v, idx) = v


# given an argument key (k), we want to extract the argument value for this index.
# matrices are sliced by column, otherwise we
# if nothing is set (or container is empty), return the default or the existing value.
function slice_arg!(plotattributes_in::KW,plotattributes_out::KW, k::Symbol, default_value, idx::Int, remove_pair::Bool)
    v = get(plotattributes_in, k, get(plotattributes_out, k, default_value))
   plotattributes_out[k] = if haskey(plotattributes_in, k) && typeof(v) <: AMat && !isempty(v)
        slice_arg(v, idx)
    else
        v
    end
    if remove_pair
        delete!(plotattributes_in, k)
    end
    return
end

# -----------------------------------------------------------------------------

# # if the value is `:match` then we take whatever match_color is.
# # this is mainly used for cascading defaults for foreground and background colors
# function color_or_match!(plotattributes::KW, k::Symbol, match_color)
#     v = plotattributes[k]
#     plotattributes[k] = if v == :match
#         match_color
#     elseif v == nothing
#         plot_color(RGBA(0,0,0,0))
#     else
#         v
#     end
# end

function color_or_nothing!(plotattributes::KW, k::Symbol)
    v = plotattributes[k]
    plotattributes[k] = if v == nothing || v == false
        RGBA{Float64}(0,0,0,0)
    elseif v != :match
        plot_color(v)
    else
        v
    end
    return
end

# -----------------------------------------------------------------------------

# when a value can be `:match`, this is the key that should be used instead for value retrieval
const _match_map = KW(
    :background_color_outside => :background_color,
    :background_color_legend  => :background_color_subplot,
    :background_color_inside  => :background_color_subplot,
    :foreground_color_legend  => :foreground_color_subplot,
    :foreground_color_title   => :foreground_color_subplot,
    :left_margin   => :margin,
    :top_margin    => :margin,
    :right_margin  => :margin,
    :bottom_margin => :margin,
    :titlefontfamily          => :fontfamily_subplot,
    :legendfontfamily         => :fontfamily_subplot,
    :titlefontcolor           => :foreground_color_subplot,
    :legendfontcolor          => :foreground_color_subplot,
    :tickfontcolor            => :foreground_color_text,
    :guidefontcolor           => :foreground_color_guide,
)

# these can match values from the parent container (axis --> subplot --> plot)
const _match_map2 = KW(
    :background_color_subplot => :background_color,
    :foreground_color_subplot => :foreground_color,
    :foreground_color_axis    => :foreground_color_subplot,
    :foreground_color_border  => :foreground_color_subplot,
    :foreground_color_grid    => :foreground_color_subplot,
    :foreground_color_minor_grid=> :foreground_color_subplot,
    :foreground_color_guide   => :foreground_color_subplot,
    :foreground_color_text    => :foreground_color_subplot,
    :fontfamily_subplot       => :fontfamily,
    :tickfontfamily           => :fontfamily_subplot,
    :guidefontfamily          => :fontfamily_subplot,
)

# properly retrieve from plt.attr, passing `:match` to the correct key
function Base.getindex(plt::Plot, k::Symbol)
    v = plt.attr[k]
    if v == :match
        plt[_match_map[k]]
    else
        v
    end
end


# properly retrieve from sp.attr, passing `:match` to the correct key
function Base.getindex(sp::Subplot, k::Symbol)
    v = sp.attr[k]
    if v == :match
        if haskey(_match_map2, k)
            sp.plt[_match_map2[k]]
        else
            sp[_match_map[k]]
        end
    else
        v
    end
end


# properly retrieve from axis.attr, passing `:match` to the correct key
function Base.getindex(axis::Axis, k::Symbol)
    v = axis.plotattributes[k]
    if v == :match
        if haskey(_match_map2, k)
            axis.sps[1][_match_map2[k]]
        else
            axis[_match_map[k]]
        end
    else
        v
    end
end

function Base.getindex(series::Series, k::Symbol)
    series.plotattributes[k]
end

Base.setindex!(plt::Plot, v, k::Symbol)      = (plt.attr[k] = v)
Base.setindex!(sp::Subplot, v, k::Symbol)    = (sp.attr[k] = v)
Base.setindex!(axis::Axis, v, k::Symbol)     = (axis.plotattributes[k] = v)
Base.setindex!(series::Series, v, k::Symbol) = (series.plotattributes[k] = v)

Base.get(plt::Plot, k::Symbol, v)      = get(plt.attr, k, v)
Base.get(sp::Subplot, k::Symbol, v)    = get(sp.attr, k, v)
Base.get(axis::Axis, k::Symbol, v)     = get(axis.plotattributes, k, v)
Base.get(series::Series, k::Symbol, v) = get(series.plotattributes, k, v)


# -----------------------------------------------------------------------------

function fg_color(plotattributes::KW)
    fg = default(plotattributes, :foreground_color)
    if fg == :auto
        bg = plot_color(default(plotattributes, :background_color))
        fg = isdark(bg) ? colorant"white" : colorant"black"
    else
        plot_color(fg)
    end
end

function fg_color_sp(plotattributes::KW)
    fgsp = default(plotattributes, :foreground_color_subplot)
    if fg == :match
        fg_color(plotattributes)
    else
        plot_color(fgsp)
    end
end



# update attr from an input dictionary
function _update_plot_args(plt::Plot, plotattributes_in::KW)
    for (k,v) in _plot_defaults
        slice_arg!(plotattributes_in, plt.attr, k, v, 1, true)
    end

    # handle colors
   plotattributes= plt.attr
    plt[:background_color] = plot_color(plotattributes[:background_color])
    plt[:foreground_color] = fg_color(plotattributes)
    # bg = plot_color(plt.attr[:background_color])
    # fg = plt.attr[:foreground_color]
    # if fg == :auto
    #     fg = isdark(bg) ? colorant"white" : colorant"black"
    # end
    # plt.attr[:background_color] = bg
    # plt.attr[:foreground_color] = plot_color(fg)
    color_or_nothing!(plt.attr, :background_color_outside)
end

# -----------------------------------------------------------------------------

function _update_subplot_periphery(sp::Subplot, anns::AVec)
    # extend annotations, and ensure we always have a (x,y,PlotText) tuple
    newanns = []
    for ann in vcat(anns, sp[:annotations])
        append!(newanns, process_annotation(sp, ann...))
    end
    sp.attr[:annotations] = newanns

    # handle legend/colorbar
    sp.attr[:legend] = convertLegendValue(sp.attr[:legend])
    sp.attr[:colorbar] = convertLegendValue(sp.attr[:colorbar])
    if sp.attr[:colorbar] == :legend
        sp.attr[:colorbar] = sp.attr[:legend]
    end
    return
end

function _update_subplot_colors(sp::Subplot)
    # background colors
    color_or_nothing!(sp.attr, :background_color_subplot)
    bg = plot_color(sp[:background_color_subplot])
    sp.attr[:color_palette] = get_color_palette(sp.attr[:color_palette], bg, 30)
    color_or_nothing!(sp.attr, :background_color_legend)
    color_or_nothing!(sp.attr, :background_color_inside)

    # foreground colors
    color_or_nothing!(sp.attr, :foreground_color_subplot)
    color_or_nothing!(sp.attr, :foreground_color_legend)
    color_or_nothing!(sp.attr, :foreground_color_title)
    return
end

function _update_axis(plt::Plot, sp::Subplot, plotattributes_in::KW, letter::Symbol, subplot_index::Int)
    # get (maybe initialize) the axis
    axis = get_axis(sp, letter)

    _update_axis(axis, plotattributes_in, letter, subplot_index)

    # convert a bool into auto or nothing
    if isa(axis[:ticks], Bool)
        axis[:ticks] = axis[:ticks] ? :auto : nothing
    end

    _update_axis_colors(axis)
    _update_axis_links(plt, axis, letter)
    return
end

function _update_axis(axis::Axis, plotattributes_in::KW, letter::Symbol, subplot_index::Int)
    # grab magic args (for example `xaxis = (:flip, :log)`)
    args = wraptuple(get(plotattributes_in, Symbol(letter, :axis), ()))

    # build the KW of arguments from the letter version (i.e. xticks --> ticks)
    kw = KW()
    for (k,v) in _axis_defaults
        # first get the args without the letter: `tickfont = font(10)`
        # note: we don't pop because we want this to apply to all axes! (delete after all have finished)
        if haskey(plotattributes_in, k)
            kw[k] = slice_arg(plotattributes_in[k], subplot_index)
        end

        # then get those args that were passed with a leading letter: `xlabel = "X"`
        lk = Symbol(letter, k)
        if haskey(plotattributes_in, lk)
            kw[k] = slice_arg(plotattributes_in[lk], subplot_index)
        end
    end

    # update the axis
    attr!(axis, args...; kw...)
    return
end

function _update_axis_colors(axis::Axis)
    # # update the axis colors
    color_or_nothing!(axis.plotattributes, :foreground_color_axis)
    color_or_nothing!(axis.plotattributes, :foreground_color_border)
    color_or_nothing!(axis.plotattributes, :foreground_color_guide)
    color_or_nothing!(axis.plotattributes, :foreground_color_text)
    color_or_nothing!(axis.plotattributes, :foreground_color_grid)
    color_or_nothing!(axis.plotattributes, :foreground_color_minor_grid)
    return
end

function _update_axis_links(plt::Plot, axis::Axis, letter::Symbol)
    # handle linking here.  if we're passed a list of
    # other subplots to link to, link them together
    link = axis[:link]
    if !isempty(link)
        for other_sp in link
            other_sp = get_subplot(plt, other_sp)
            link_axes!(axis, get_axis(other_sp, letter))
        end
        axis.plotattributes[:link] = []
    end
    return
end

# update a subplots args and axes
function _update_subplot_args(plt::Plot, sp::Subplot, plotattributes_in::KW, subplot_index::Int, remove_pair::Bool)
    anns = pop!(sp.attr, :annotations, [])

    # grab those args which apply to this subplot
    for (k,v) in _subplot_defaults
        slice_arg!(plotattributes_in, sp.attr, k, v, subplot_index, remove_pair)
    end

    _update_subplot_periphery(sp, anns)
    _update_subplot_colors(sp)

    for letter in (:x, :y, :z)
        _update_axis(plt, sp, plotattributes_in, letter, subplot_index)
    end
end

# -----------------------------------------------------------------------------

has_black_border_for_default(st) = error("The seriestype attribute only accepts Symbols, you passed the $(typeof(st)) $st.")
has_black_border_for_default(st::Function) = error("The seriestype attribute only accepts Symbols, you passed the function $st.")
function has_black_border_for_default(st::Symbol)
    like_histogram(st) || st in (:hexbin, :bar, :shape)
end


# converts a symbol or string into a colorant (Colors.RGB), and assigns a color automatically
function getSeriesRGBColor(c, sp::Subplot, n::Int)
    if c == :auto
        c = autopick(sp[:color_palette], n)
    elseif isa(c, Int)
        c = autopick(sp[:color_palette], c)
    end
    plot_color(c)
end

function getSeriesRGBColor(c::AbstractArray, sp::Subplot, n::Int)
    map(x->getSeriesRGBColor(x, sp, n), c)
end

function ensure_gradient!(plotattributes::KW, csym::Symbol, asym::Symbol)
    if !isa(plotattributes[csym], ColorGradient)
        plotattributes[csym] = typeof(plotattributes[asym]) <: AbstractVector ? cgrad() : cgrad(alpha = plotattributes[asym])
    end
end

function _replace_linewidth(plotattributes::KW)
    # get a good default linewidth... 0 for surface and heatmaps
    if get(plotattributes, :linewidth, :auto) == :auto
        plotattributes[:linewidth] = (get(plotattributes, :seriestype, :path) in (:surface,:heatmap,:image) ? 0 : 1)
    end
end

function _add_defaults!(plotattributes::KW, plt::Plot, sp::Subplot, commandIndex::Int)
    # add default values to our dictionary, being careful not to delete what we just added!
    for (k,v) in _series_defaults
        slice_arg!(plotattributes, plotattributes, k, v, commandIndex, false)
    end

    return plotattributes
end


function _update_series_attributes!(plotattributes::KW, plt::Plot, sp::Subplot)
    pkg = plt.backend
    globalIndex = plotattributes[:series_plotindex]
    plotIndex = _series_index(plotattributes, sp)

    aliasesAndAutopick(plotattributes, :linestyle, _styleAliases, supported_styles(pkg), plotIndex)
    aliasesAndAutopick(plotattributes, :markershape, _markerAliases, supported_markers(pkg), plotIndex)

    # update alphas
    for asym in (:linealpha, :markeralpha, :fillalpha)
        if plotattributes[asym] == nothing
            plotattributes[asym] = plotattributes[:seriesalpha]
        end
    end
    if plotattributes[:markerstrokealpha] == nothing
        plotattributes[:markerstrokealpha] = plotattributes[:markeralpha]
    end

    # update series color
    plotattributes[:seriescolor] = getSeriesRGBColor(plotattributes[:seriescolor], sp, plotIndex)

    # update other colors
    for s in (:line, :marker, :fill)
        csym, asym = Symbol(s,:color), Symbol(s,:alpha)
        plotattributes[csym] = if plotattributes[csym] == :auto
            plot_color(if has_black_border_for_default(plotattributes[:seriestype]) && s == :line
                sp[:foreground_color_subplot]
            else
                plotattributes[:seriescolor]
            end)
        elseif plotattributes[csym] == :match
            plot_color(plotattributes[:seriescolor])
        else
            getSeriesRGBColor(plotattributes[csym], sp, plotIndex)
        end
    end

    # update markerstrokecolor
    plotattributes[:markerstrokecolor] = if plotattributes[:markerstrokecolor] == :match
        plot_color(sp[:foreground_color_subplot])
    elseif plotattributes[:markerstrokecolor] == :auto
        getSeriesRGBColor(plotattributes[:markercolor], sp, plotIndex)
    else
        getSeriesRGBColor(plotattributes[:markerstrokecolor], sp, plotIndex)
    end

    # if marker_z, fill_z or line_z are set, ensure we have a gradient
    if plotattributes[:marker_z] != nothing
        ensure_gradient!(plotattributes, :markercolor, :markeralpha)
    end
    if plotattributes[:line_z] != nothing
        ensure_gradient!(plotattributes, :linecolor, :linealpha)
    end
    if plotattributes[:fill_z] != nothing
        ensure_gradient!(plotattributes, :fillcolor, :fillalpha)
    end

    # scatter plots don't have a line, but must have a shape
    if plotattributes[:seriestype] in (:scatter, :scatterbins, :scatterhist, :scatter3d)
        plotattributes[:linewidth] = 0
        if plotattributes[:markershape] == :none
            plotattributes[:markershape] = :circle
        end
    end

    # set label
    label = plotattributes[:label]
    label = (label == "AUTO" ? "y$globalIndex" : label)
    plotattributes[:label] = label

    _replace_linewidth(plotattributes)
   plotattributes
end

function _series_index(plotattributes, sp)
    idx = 0
    for series in series_list(sp)
        if series[:primary]
            idx += 1
        end
        if series == plotattributes
            return idx
        end
    end
    if get(plotattributes, :primary, true)
        idx += 1
    end
    return idx
end
