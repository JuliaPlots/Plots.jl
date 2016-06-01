

const _keyAliases = KW()

function add_aliases(sym::Symbol, aliases::Symbol...)
    for alias in aliases
        if haskey(_keyAliases, alias)
            error("Already an alias $alias => $(_keyAliases[alias])... can't also alias $sym")
        end
        _keyAliases[alias] = sym
    end
end

# ------------------------------------------------------------

const _allAxes = [:auto, :left, :right]
const _axesAliases = KW(
    :a => :auto,
    :l => :left,
    :r => :right
)

const _3dTypes = [
    :path3d, :scatter3d, :surface, :wireframe, :contour3d
]
const _allTypes = vcat([
    :none, :line, :path, :steppre, :steppost, :sticks, :scatter,
    :heatmap, :hexbin, :histogram, :histogram2d, :histogram3d, :density, :bar, :hline, :vline,
    :contour, :pie, :shape, :image
], _3dTypes)

@compat const _typeAliases = KW(
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
    :gradient      => :quiver,
    :img           => :image,
    :imshow        => :image,
    :imagesc       => :image,
    :hist          => :histogram,
    :hist2d        => :histogram2d,
)

like_histogram(seriestype::Symbol) = seriestype in (:histogram, :density)
like_line(seriestype::Symbol)      = seriestype in (:line, :path, :steppre, :steppost)
like_surface(seriestype::Symbol)   = seriestype in (:contour, :contour3d, :heatmap, :surface, :wireframe, :image)

is3d(seriestype::Symbol) = seriestype in _3dTypes
is3d(series::Series) = is3d(series.d)
is3d(d::KW) = trueOrAllTrue(is3d, d[:seriestype])

is3d(sp::Subplot) = string(sp.attr[:projection]) == "3d"
ispolar(sp::Subplot) = string(sp.attr[:projection]) == "polar"
ispolar(series::Series) = ispolar(series.d[:subplot])

# ------------------------------------------------------------

const _allStyles = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]
@compat const _styleAliases = KW(
    :a    => :auto,
    :s    => :solid,
    :d    => :dash,
    :dd   => :dashdot,
    :ddd  => :dashdotdot,
)

const _allMarkers = vcat(:none, :auto, sort(collect(keys(_shapes))))
@compat const _markerAliases = KW(
    :n            => :none,
    :no           => :none,
    :a            => :auto,
    :circle       => :ellipse,
    :c            => :ellipse,
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
    :+            => :cross,
    :plus         => :cross,
    :x            => :xcross,
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

const _allScales = [:identity, :ln, :log2, :log10, :asinh, :sqrt]
@compat const _scaleAliases = KW(
    :none => :identity,
    :log  => :log10,
)

# -----------------------------------------------------------------------------

const _series_defaults = KW(
    :label             => "AUTO",
    :seriescolor       => :auto,
    :seriesalpha       => nothing,
    :seriestype        => :path,
    :linestyle         => :solid,
    :linewidth         => :auto,
    :linecolor         => :match,
    :linealpha         => nothing,
    :fillrange         => nothing,   # ribbons, areas, etc
    :fillcolor         => :match,
    :fillalpha         => nothing,
    :markershape       => :none,
    :markercolor       => :match,
    :markeralpha       => nothing,
    :markersize        => 6,
    :markerstrokestyle => :solid,
    :markerstrokewidth => 1,
    :markerstrokecolor => :match,
    :markerstrokealpha => nothing,
    :bins              => 30,        # number of bins for hists
    :smooth            => false,     # regression line?
    :group             => nothing,   # groupby vector
    :x                 => nothing,
    :y                 => nothing,
    :z                 => nothing,   # depth for contour, surface, etc
    :marker_z          => nothing,   # value for color scale
    :levels            => 15,
    :orientation       => :vertical,
    :bar_position      => :overlay,  # for bar plots and histograms: could also be stack (stack up) or dodge (side by side)
    :bar_width         => 0.8,
    :bar_edges         => false,
    :xerror            => nothing,
    :yerror            => nothing,
    :ribbon            => nothing,
    :quiver            => nothing,
    :arrow             => nothing,   # allows for adding arrows to line/path... call `arrow(args...)`
    :normalize         => false,     # do we want a normalized histogram?
    :weights           => nothing,   # optional weights for histograms (1D and 2D)
    :contours          => false,     # add contours to 3d surface and wireframe plots
    :match_dimensions  => false,     # do rows match x (true) or y (false) for heatmap/image/spy? see issue 196
                                     # this ONLY effects whether or not the z-matrix is transposed for a heatmap display!
    :subplot           => :auto,     # which subplot(s) does this series belong to?
    :series_annotations => [],       # a list of annotations which apply to the coordinates of this series
)


const _plot_defaults = KW(
    :plot_title                  => "",
    :background_color            => colorant"white",   # default for all backgrounds,
    :background_color_outside    => :match,            # background outside grid,
    :foreground_color            => :auto,             # default for all foregrounds, and title color,
    :size                        => (600,400),
    :pos                         => (0,0),
    :window_title                 => "Plots.jl",
    :show                        => false,
    :layout                      => 1,
    :link                        => :none,
    # :linkx                       => false,
    # :linky                       => false,
    # :linkfunc                    => nothing,
    :overwrite_figure            => true,
    :html_output_format          => :auto,
)


const _subplot_defaults = KW(
    :title                    => "",
    :title_location           => :center,           # also :left or :right
    :titlefont                => font(14),
    :background_color_subplot => :match,            # default for other bg colors... match takes plot default
    :background_color_legend  => :match,            # background of legend
    :background_color_inside  => :match,            # background inside grid
    :foreground_color_subplot => :match,            # default for other fg colors... match takes plot default
    :foreground_color_legend  => :match,            # foreground of legend
    :foreground_color_grid    => :match,            # grid color
    :foreground_color_title   => :match,            # title color
    :color_palette            => :auto,
    :legend                   => :best,
    :colorbar                 => :legend,
    :legendfont               => font(8),
    :grid                     => true,
    :annotations              => [],                # annotation tuples... list of (x,y,annotation)
    :projection               => :none,             # can also be :polar or :3d
    :aspect_ratio             => :none,             # choose from :none or :equal
    :margin                   => 2mm,
    :left_margin              => :match,
    :top_margin               => :match,
    :right_margin             => :match,
    :bottom_margin            => :match,
    :subplot_index            => -1,
)

const _axis_defaults = KW(
    :guide     => "",
    :lims      => :auto,
    :ticks     => :auto,
    :scale     => :identity,
    :rotation  => 0,
    :flip      => false,
    :tickfont  => font(8),
    :guidefont => font(11),
    :foreground_color_axis   => :match,            # axis border/tick colors,
    :foreground_color_border => :match,            # plot area border/spines,
    :foreground_color_text   => :match,            # tick text color,
    :foreground_color_guide  => :match,            # guide text color,
    :discrete_values => [],
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
])

# add defaults for the letter versions
const _axis_defaults_byletter = KW()
for letter in (:x,:y,:z)
    for k in (
                :guide,
                :lims,
                :ticks,
                :scale,
                :rotation,
                :flip,
                :tickfont,
                :guidefont,
                :foreground_color_axis,
                :foreground_color_border,
                :foreground_color_text,
                :foreground_color_guide,
                :discrete_values
            )
        _axis_defaults_byletter[Symbol(letter,k)] = nothing

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

const _all_args = sort(collect(union(map(keys, _all_defaults)...)))
supportedArgs(::AbstractBackend) = error("supportedArgs not defined") #_all_args
supportedArgs() = supportedArgs(backend())

RecipesBase.is_key_supported(k::Symbol) = (k in supportedArgs())

# -----------------------------------------------------------------------------

makeplural(s::Symbol) = Symbol(string(s,"s"))

autopick(arr::AVec, idx::Integer) = arr[mod1(idx,length(arr))]
autopick(notarr, idx::Integer) = notarr

autopick_ignore_none_auto(arr::AVec, idx::Integer) = autopick(setdiff(arr, [:none, :auto]), idx)
autopick_ignore_none_auto(notarr, idx::Integer) = notarr

function aliasesAndAutopick(d::KW, sym::Symbol, aliases::KW, options::AVec, plotIndex::Int)
    if d[sym] == :auto
        d[sym] = autopick_ignore_none_auto(options, plotIndex)
    elseif haskey(aliases, d[sym])
        d[sym] = aliases[d[sym]]
    end
end

function aliases(aliasMap::KW, val)
    sortedkeys(filter((k,v)-> v==val, aliasMap))
end

# -----------------------------------------------------------------------------


# colors
add_aliases(:seriescolor, :c, :color, :colour)
add_aliases(:linecolor, :lc, :lcolor, :lcolour, :linecolour)
add_aliases(:markercolor, :mc, :mcolor, :mcolour, :markercolour)
add_aliases(:markerstokecolor, :msc, :mscolor, :mscolour, :markerstokecolour)
add_aliases(:fillcolor, :fc, :fcolor, :fcolour, :fillcolour)

add_aliases(:background_color, :bg, :bgcolor, :bg_color, :background,
                              :background_colour, :bgcolour, :bg_colour)
add_aliases(:background_color_legend, :bg_legend, :bglegend, :bgcolor_legend, :bg_color_legend, :background_legend,
                              :background_colour_legend, :bgcolour_legend, :bg_colour_legend)
add_aliases(:background_color_inside, :bg_inside, :bginside, :bgcolor_inside, :bg_color_inside, :background_inside,
                              :background_colour_inside, :bgcolour_inside, :bg_colour_inside)
add_aliases(:background_color_outside, :bg_outside, :bgoutside, :bgcolor_outside, :bg_color_outside, :background_outside,
                              :background_colour_outside, :bgcolour_outside, :bg_colour_outside)
add_aliases(:foreground_color, :fg, :fgcolor, :fg_color, :foreground,
                            :foreground_colour, :fgcolour, :fg_colour)
add_aliases(:foreground_color_legend, :fg_legend, :fglegend, :fgcolor_legend, :fg_color_legend, :foreground_legend,
                            :foreground_colour_legend, :fgcolour_legend, :fg_colour_legend)
add_aliases(:foreground_color_grid, :fg_grid, :fggrid, :fgcolor_grid, :fg_color_grid, :foreground_grid,
                            :foreground_colour_grid, :fgcolour_grid, :fg_colour_grid, :gridcolor)
add_aliases(:foreground_color_title, :fg_title, :fgtitle, :fgcolor_title, :fg_color_title, :foreground_title,
                            :foreground_colour_title, :fgcolour_title, :fg_colour_title, :titlecolor)
add_aliases(:foreground_color_axis, :fg_axis, :fgaxis, :fgcolor_axis, :fg_color_axis, :foreground_axis,
                            :foreground_colour_axis, :fgcolour_axis, :fg_colour_axis, :axiscolor)
add_aliases(:foreground_color_border, :fg_border, :fgborder, :fgcolor_border, :fg_color_border, :foreground_border,
                            :foreground_colour_border, :fgcolour_border, :fg_colour_border, :bordercolor, :border)
add_aliases(:foreground_color_text, :fg_text, :fgtext, :fgcolor_text, :fg_color_text, :foreground_text,
                            :foreground_colour_text, :fgcolour_text, :fg_colour_text, :textcolor)
add_aliases(:foreground_color_guide, :fg_guide, :fgguide, :fgcolor_guide, :fg_color_guide, :foreground_guide,
                            :foreground_colour_guide, :fgcolour_guide, :fg_colour_guide, :guidecolor)

# alphas
add_aliases(:seriesalpha, :alpha, :α, :opacity)
add_aliases(:linealpha, :la, :lalpha, :lα, :lineopacity, :lopacity)
add_aliases(:makeralpha, :ma, :malpha, :mα, :makeropacity, :mopacity)
add_aliases(:markerstrokealpha, :msa, :msalpha, :msα, :markerstrokeopacity, :msopacity)
add_aliases(:fillalpha, :fa, :falpha, :fα, :fillopacity, :fopacity)

# series attributes
add_aliases(:seriestype, :st, :t, :typ, :linetype, :lt)
add_aliases(:label, :lab)
add_aliases(:line, :l)
add_aliases(:linewidth, :w, :width, :lw)
add_aliases(:linestyle, :style, :s, :ls)
add_aliases(:marker, :m, :mark)
add_aliases(:markershape, :shape)
add_aliases(:markersize, :ms, :msize)
add_aliases(:marker_z, :markerz, :zcolor)
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
add_aliases(:legend, :leg, :key)
add_aliases(:colorbar, :cb, :cbar, :colorkey)
add_aliases(:smooth, :regression, :reg)
add_aliases(:levels, :nlevels, :nlev, :levs)
add_aliases(:size, :windowsize, :wsize)
add_aliases(:window_title, :windowtitle, :wtitle)
add_aliases(:show, :gui, :display)
add_aliases(:color_palette, :palette)
# add_aliases(:linkx, :xlink)
# add_aliases(:linky, :ylink)
add_aliases(:overwrite_figure, :clf, :clearfig, :overwrite, :reuse)
add_aliases(:xerror, :xerr, :xerrorbar)
add_aliases(:yerror, :yerr, :yerrorbar, :err, :errorbar)
add_aliases(:quiver, :velocity, :quiver2d, :gradient)
add_aliases(:normalize, :norm, :normed, :normalized)
add_aliases(:aspect_ratio, :aspectratio, :axis_ratio, :axisratio, :ratio)
add_aliases(:match_dimensions, :transpose, :transpose_z)
add_aliases(:subplot, :sp, :subplt, :splt)
add_aliases(:projection, :proj)
add_aliases(:title_location, :title_loc, :titleloc, :title_position, :title_pos, :titlepos, :titleposition, :title_align, :title_alignment)
add_aliases(:series_annotations, :series_ann, :seriesann, :series_anns, :seriesanns, :series_annotation)
add_aliases(:html_output_format, :format, :fmt, :html_format)


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
    for (k,v) in kw
        default(k, v)
    end
end


# -----------------------------------------------------------------------------

# if arg is a valid color value, then set d[csym] and return true
function handleColors!(d::KW, arg, csym::Symbol)
    try
        if arg == :auto
            d[csym] = :auto
        else
            c = colorscheme(arg)
            d[csym] = c
        end
        return true
    end
    false
end



function processLineArg(d::KW, arg)
    # seriestype
    if allLineTypes(arg)
        d[:seriestype] = arg

    # linestyle
    elseif allStyles(arg)
        d[:linestyle] = arg

    elseif typeof(arg) <: Stroke
        arg.width == nothing || (d[:linewidth] = arg.width)
        arg.color == nothing || (d[:linecolor] = arg.color == :auto ? :auto : colorscheme(arg.color))
        arg.alpha == nothing || (d[:linealpha] = arg.alpha)
        arg.style == nothing || (d[:linestyle] = arg.style)

    elseif typeof(arg) <: Brush
        arg.size  == nothing || (d[:fillrange] = arg.size)
        arg.color == nothing || (d[:fillcolor] = arg.color == :auto ? :auto : colorscheme(arg.color))
        arg.alpha == nothing || (d[:fillalpha] = arg.alpha)

    elseif typeof(arg) <: Arrow || arg in (:arrow, :arrows)
        d[:arrow] = arg

    # linealpha
    elseif allAlphas(arg)
        d[:linealpha] = arg

    # linewidth
    elseif allReals(arg)
        d[:linewidth] = arg

    # color
    elseif !handleColors!(d, arg, :linecolor)
        warn("Skipped line arg $arg.")

    end
end


function processMarkerArg(d::KW, arg)
    # markershape
    if allShapes(arg)
        d[:markershape] = arg

    # stroke style
    elseif allStyles(arg)
        d[:markerstrokestyle] = arg

    elseif typeof(arg) <: Stroke
        arg.width == nothing || (d[:markerstrokewidth] = arg.width)
        arg.color == nothing || (d[:markerstrokecolor] = arg.color == :auto ? :auto : colorscheme(arg.color))
        arg.alpha == nothing || (d[:markerstrokealpha] = arg.alpha)
        arg.style == nothing || (d[:markerstrokestyle] = arg.style)

    elseif typeof(arg) <: Brush
        arg.size  == nothing || (d[:markersize]  = arg.size)
        arg.color == nothing || (d[:markercolor] = arg.color == :auto ? :auto : colorscheme(arg.color))
        arg.alpha == nothing || (d[:markeralpha] = arg.alpha)

    # linealpha
    elseif allAlphas(arg)
        d[:markeralpha] = arg

    # markersize
    elseif allReals(arg)
        d[:markersize] = arg

    # markercolor
    elseif !handleColors!(d, arg, :markercolor)
        warn("Skipped marker arg $arg.")

    end
end


function processFillArg(d::KW, arg)
    if typeof(arg) <: Brush
        arg.size  == nothing || (d[:fillrange] = arg.size)
        arg.color == nothing || (d[:fillcolor] = arg.color == :auto ? :auto : colorscheme(arg.color))
        arg.alpha == nothing || (d[:fillalpha] = arg.alpha)

    # fillrange function
    elseif allFunctions(arg)
        d[:fillrange] = arg

    # fillalpha
    elseif allAlphas(arg)
        d[:fillalpha] = arg

    elseif !handleColors!(d, arg, :fillcolor)

        d[:fillrange] = arg
    end
end

_replace_markershape(shape::Symbol) = get(_markerAliases, shape, shape)
_replace_markershape(shapes::AVec) = map(_replace_markershape, shapes)
_replace_markershape(shape) = shape

function _add_markershape(d::KW)
    # add the markershape if it needs to be added... hack to allow "m=10" to add a shape,
    # and still allow overriding in _apply_recipe
    ms = pop!(d, :markershape_to_add, :none)
    if !haskey(d, :markershape) && ms != :none
        d[:markershape] = ms
    end
end

"Handle all preprocessing of args... break out colors/sizes/etc and replace aliases."
function preprocessArgs!(d::KW)
    replaceAliases!(d, _keyAliases)

    # handle axis args
    for letter in (:x, :y, :z)
        asym = Symbol(letter, :axis)
        args = pop!(d, asym, ())
        if !(typeof(args) <: Axis)
            for arg in wraptuple(args)
                process_axis_arg!(d, arg, letter)
            end
        end
    end

    # handle line args
    for arg in wraptuple(pop!(d, :line, ()))
        processLineArg(d, arg)
    end

    if haskey(d, :seriestype) && haskey(_typeAliases, d[:seriestype])
        d[:seriestype] = _typeAliases[d[:seriestype]]
    end

    # handle marker args... default to ellipse if shape not set
    anymarker = false
    for arg in wraptuple(get(d, :marker, ()))
        processMarkerArg(d, arg)
        anymarker = true
    end
    delete!(d, :marker)
    if haskey(d, :markershape)
        d[:markershape] = _replace_markershape(d[:markershape])
    elseif anymarker
        d[:markershape_to_add] = :ellipse  # add it after _apply_recipe
    end

    # handle fill
    for arg in wraptuple(get(d, :fill, ()))
        processFillArg(d, arg)
    end
    delete!(d, :fill)

  # convert into strokes and brushes

    if haskey(d, :arrow)
        a = d[:arrow]
        d[:arrow] = if a == true
            arrow()
        elseif a == false
            nothing
        elseif !(typeof(a) <: Arrow)
            arrow(wraptuple(a)...)
        else
            a
        end
    end


    if get(d, :arrow, false) == true
        d[:arrow] = arrow()
    end

    # legends
    if haskey(d, :legend)
        d[:legend] = convertLegendValue(d[:legend])
    end
    if haskey(d, :colorbar)
        d[:colorbar] = convertLegendValue(d[:colorbar])
    end

    # # handle subplot links
    # if haskey(d, :link)
    #     l = d[:link]
    #     if isa(l, Bool)
    #         d[:linkx] = l
    #         d[:linky] = l
    #     elseif isa(l, Function)
    #         d[:linkx] = true
    #         d[:linky] = true
    #         d[:linkfunc] = l
    #     else
    #         warn("Unhandled/invalid link $l.  Should be a Bool or a function mapping (row,column) -> (linkx, linky), where linkx/y can be Bool or Void (nothing)")
    #     end
    #     delete!(d, :link)
    # end
end

# -----------------------------------------------------------------------------

"A special type that will break up incoming data into groups, and allow for easier creation of grouped plots"
type GroupBy
    groupLabels::Vector           # length == numGroups
    groupIds::Vector{Vector{Int}} # list of indices for each group
end


# this is when given a vector-type of values to group by
function extractGroupArgs(v::AVec, args...)
    groupLabels = sort(collect(unique(v)))
    n = length(groupLabels)
    if n > 20
        warn("You created n=$n groups... Is that intended?")
    end
    groupIds = Vector{Int}[filter(i -> v[i] == glab, 1:length(v)) for glab in groupLabels]
    GroupBy(map(string, groupLabels), groupIds)
end


# expecting a mapping of "group label" to "group indices"
function extractGroupArgs{T, V<:AVec{Int}}(idxmap::Dict{T,V}, args...)
    groupLabels = sortedkeys(idxmap)
    groupIds = VecI[collect(idxmap[k]) for k in groupLabels]
    GroupBy(groupLabels, groupIds)
end

filter_data(v::AVec, idxfilter::AVec{Int}) = v[idxfilter]
filter_data(v, idxfilter) = v

function filter_data!(d::KW, idxfilter)
    for s in (:x, :y, :z)
        d[s] = filter_data(get(d, s, nothing), idxfilter)
    end
end

function _filter_input_data!(d::KW)
    idxfilter = pop!(d, :idxfilter, nothing)
    if idxfilter != nothing
        filter_data!(d, idxfilter)
    end
end


# -----------------------------------------------------------------------------

function warnOnUnsupportedArgs(pkg::AbstractBackend, d::KW)
    for k in sortedkeys(d)
        k in supportedArgs(pkg) && continue
        k in _suppress_warnings && continue
        if d[k] != default(k)
            warn("Keyword argument $k not supported with $pkg.  Choose from: $(supportedArgs(pkg))")
        end
    end
end

_markershape_supported(pkg::AbstractBackend, shape::Symbol) = shape in supportedMarkers(pkg)
_markershape_supported(pkg::AbstractBackend, shape::Shape) = Shape in supportedMarkers(pkg)
_markershape_supported(pkg::AbstractBackend, shapes::AVec) = all([_markershape_supported(pkg, shape) for shape in shapes])

function warnOnUnsupported(pkg::AbstractBackend, d::KW)
    (d[:seriestype] == :none
        || d[:seriestype] in supportedTypes(pkg)
        || warn("seriestype $(d[:seriestype]) is unsupported with $pkg.  Choose from: $(supportedTypes(pkg))"))
    (d[:linestyle] in supportedStyles(pkg)
        || warn("linestyle $(d[:linestyle]) is unsupported with $pkg.  Choose from: $(supportedStyles(pkg))"))
    (d[:markershape] == :none
        || _markershape_supported(pkg, d[:markershape])
        || warn("markershape $(d[:markershape]) is unsupported with $pkg.  Choose from: $(supportedMarkers(pkg))"))
end

function warnOnUnsupportedScales(pkg::AbstractBackend, d::KW)
  for k in (:xscale, :yscale)
    if haskey(d, k)
      d[k] in supportedScales(pkg) || warn("scale $(d[k]) is unsupported with $pkg.  Choose from: $(supportedScales(pkg))")
    end
  end
end


# -----------------------------------------------------------------------------

function convertLegendValue(val::Symbol)
    if val in (:both, :all, :yes)
        :best
    elseif val in (:no, :none)
        :none
    elseif val in (:right, :left, :top, :bottom, :inside, :best, :legend, :topright, :topleft, :bottomleft, :bottomright)
        val
    else
        error("Invalid symbol for legend: $val")
    end
end
convertLegendValue(val::Bool) = val ? :best : :none

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
function slice_arg!(d_in::KW, d_out::KW, k::Symbol, default_value, idx::Int = 1; new_key::Symbol = k, remove_pair::Bool = true)
    v = get(d_in, k, get(d_out, new_key, default_value))
    d_out[new_key] = if haskey(d_in, k) && typeof(v) <: AMat && !isempty(v)
        slice_arg(v, idx)
    else
        v
    end
    if remove_pair
        delete!(d_in, k)
    end
end

# if the value is `:match` then we take whatever match_color is.
# this is mainly used for cascading defaults for foreground and background colors
function color_or_match!(d::KW, k::Symbol, match_color)
    v = d[k]
    d[k] = if v == :match
        match_color
    elseif v == nothing
        colorscheme(RGBA(0,0,0,0))
    else
        v
    end
end


# update attr from an input dictionary
function _update_plot_args(plt::Plot, d_in::KW)
    pargs = plt.attr
    for (k,v) in _plot_defaults
        slice_arg!(d_in, pargs, k, v)
    end

    # handle colors
    bg = convertColor(pargs[:background_color])
    fg = pargs[:foreground_color]
    if fg == :auto
        fg = isdark(bg) ? colorant"white" : colorant"black"
    end
    pargs[:background_color] = bg
    pargs[:foreground_color] = convertColor(fg)
    color_or_match!(pargs, :background_color_outside, bg)
end


# update a subplots args and axes
function _update_subplot_args(plt::Plot, sp::Subplot, d_in::KW, subplot_index::Integer)
    pargs = plt.attr
    spargs = sp.attr
    # @show subplot_index, sp
    for (k,v) in _subplot_defaults
        slice_arg!(d_in, spargs, k, v, subplot_index)
    end

    # handle legend/colorbar
    spargs[:legend] = convertLegendValue(spargs[:legend])
    spargs[:colorbar] = convertLegendValue(spargs[:colorbar])
    if spargs[:colorbar] == :legend
        spargs[:colorbar] = spargs[:legend]
    end

    # background colors
    bg = color_or_match!(spargs, :background_color_subplot, pargs[:background_color])
    spargs[:color_palette] = get_color_palette(spargs[:color_palette], bg, 30)
    color_or_match!(spargs, :background_color_legend, bg)
    color_or_match!(spargs, :background_color_inside, bg)

    # foreground colors
    fg = color_or_match!(spargs, :foreground_color_subplot, pargs[:foreground_color])
    color_or_match!(spargs, :foreground_color_legend, fg)
    color_or_match!(spargs, :foreground_color_grid, fg)
    color_or_match!(spargs, :foreground_color_title, fg)

    for k in (:left_margin, :top_margin, :right_margin, :bottom_margin)
        if spargs[k] == :match
            spargs[k] = spargs[:margin]
        end
    end

    for letter in (:x, :y, :z)
        # get (maybe initialize) the axis
        axissym = Symbol(letter, :axis)
        axis = if haskey(spargs, axissym)
            spargs[axissym]
        else
            spargs[axissym] = Axis(letter)
        end

        # grab magic args (for example `xaxis = (:flip, :log)`)
        args = wraptuple(get(d_in, axissym, ()))

        # build the KW of arguments from the letter version (i.e. xticks --> ticks)
        kw = KW()
        # DD(d_in, "d_in before")

        for (k,v) in _axis_defaults
            # first get the args without the letter: `tickfont = font(10)`
            # note: we don't pop because we want this to apply to all axes! (delete after all have finished)
            if haskey(d_in, k)
                kw[k] = slice_arg(d_in[k], subplot_index)
            end

            # then get those args that were passed with a leading letter: `xlabel = "X"`
            lk = Symbol(letter, k)
            if haskey(d_in, lk)
                kw[k] = slice_arg(pop!(d_in, lk), subplot_index)
            end
        end

        # update the axis
        update!(axis, args...; kw...)

        # update the axis colors
        color_or_match!(axis.d, :foreground_color_axis, fg)
        color_or_match!(axis.d, :foreground_color_border, fg)
        color_or_match!(axis.d, :foreground_color_guide, fg)
        color_or_match!(axis.d, :foreground_color_text, fg)

        # TODO: need to handle linking here?
    end

    # now we can get rid of the axis keys without a letter
    for k in keys(_axis_defaults)
        delete!(d_in, k)
    end
end


function has_black_border_for_default(st::Symbol)
    like_histogram(st) || st in (:hexbin, :bar)
end
