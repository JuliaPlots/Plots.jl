module Subplots

export Subplot, colorbartitlefont, legendfont, legendtitlefont, titlefont, get_series_color
import Plots.Ticks: get_ticks
using Plots: Plots, Series, Surface, Volume, AbstractBackend, AbstractLayout, BoundingBox, DefaultsDict, _subplot_defaults, convert_legend_value, like_surface, _match_map, _match_map2
using Plots.PlotUtils: get_color_palette
using Plots.Commons
using Plots.Fonts

# a single subplot
mutable struct Subplot{T<:AbstractBackend} <: AbstractLayout
    parent::AbstractLayout
    series_list::Vector{Series}  # arguments for each series
    primary_series_count::Int # Number of primary series in the series list
    minpad::Tuple # leftpad, toppad, rightpad, bottompad
    bbox::BoundingBox  # the canvas area which is available to this subplot
    plotarea::BoundingBox  # the part where the data goes
    attr::DefaultsDict  # args specific to this subplot
    o  # can store backend-specific data... like a pyplot ax
    plt  # the enclosing Plot object (can't give it a type because of no forward declarations)

    Subplot(::T; parent = Plots.RootLayout()) where {T<:AbstractBackend} = new{T}(
        parent,
        Series[],
        0,
        DEFAULT_MINPAD[],
        DEFAULT_BBOX[],
        DEFAULT_BBOX[],
        DefaultsDict(KW(), _subplot_defaults),
        nothing,
        nothing,
    )
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
Base.getindex(sp::Subplot, i::Union{Vector{<:Integer},Integer}) = series_list(sp)[i]
Base.setindex!(sp::Subplot, v, k::Symbol)    = (sp.attr[k] = v)
Base.lastindex(sp::Subplot) = length(series_list(sp))

Base.empty!(sp::Subplot) = empty!(sp.series_list)
Base.get(sp::Subplot, k::Symbol, v)    = get(sp.attr, k, v)

# -----------------------------------------------------------------------

Base.show(io::IO, sp::Subplot) = print(io, "Subplot{$(sp[:subplot_index])}")

"""
    plotarea(subplot)

Return the bounding box of a subplot.
"""
plotarea(sp::Subplot) = sp.plotarea
plotarea!(sp::Subplot, bbox::BoundingBox) = (sp.plotarea = bbox)

Base.size(sp::Subplot) = (1, 1)
Base.length(sp::Subplot) = 1
Base.getindex(sp::Subplot, r::Int, c::Int) = sp

leftpad(sp::Subplot)   = sp.minpad[1]
toppad(sp::Subplot)    = sp.minpad[2]
rightpad(sp::Subplot)  = sp.minpad[3]
bottompad(sp::Subplot) = sp.minpad[4]

function attr!(sp::Subplot; kw...)
    plotattributes = KW(kw)
    Plots.preprocess_attributes!(plotattributes)
    for (k, v) in plotattributes
        if haskey(_subplot_defaults, k)
            sp[k] = v
        else
            @warn "unused key $k in subplot attr"
        end
    end
    sp
end

Plots.series_list(sp::Subplot) = sp.series_list # filter(series -> series.plotattributes[:subplot] === sp, sp.plt.series_list)
Plots.RecipesPipeline.is3d(sp::Subplot) = string(sp.attr[:projection]) == "3d"
Plots.ispolar(sp::Subplot) = string(sp.attr[:projection]) == "polar"

get_ticks(sp::Subplot, s::Symbol) = get_ticks(sp, sp[get_attr_symbol(s, :axis)])

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

colorbartitlefont(sp::Subplot) = font(;
    family = sp[:colorbar_titlefontfamily],
    pointsize = sp[:colorbar_titlefontsize],
    valign = sp[:colorbar_titlefontvalign],
    halign = sp[:colorbar_titlefonthalign],
    rotation = sp[:colorbar_titlefontrotation],
    color = sp[:colorbar_titlefontcolor],
)

titlefont(sp::Subplot) = font(;
    family = sp[:titlefontfamily],
    pointsize = sp[:titlefontsize],
    valign = sp[:titlefontvalign],
    halign = sp[:titlefonthalign],
    rotation = sp[:titlefontrotation],
    color = sp[:titlefontcolor],
)

legendfont(sp::Subplot) = font(;
    family = sp[:legend_font_family],
    pointsize = sp[:legend_font_pointsize],
    valign = sp[:legend_font_valign],
    halign = sp[:legend_font_halign],
    rotation = sp[:legend_font_rotation],
    color = sp[:legend_font_color],
)

legendtitlefont(sp::Subplot) = font(;
    family = sp[:legend_title_font_family],
    pointsize = sp[:legend_title_font_pointsize],
    valign = sp[:legend_title_font_valign],
    halign = sp[:legend_title_font_halign],
    rotation = sp[:legend_title_font_rotation],
    color = sp[:legend_title_font_color],
)

function _update_subplot_periphery(sp::Subplot, anns::AVec)
    # extend annotations, and ensure we always have a (x,y,PlotText) tuple
    newanns = []
    for ann in vcat(anns, sp[:annotations])
        append!(newanns, process_annotation(sp, ann))
    end
    sp.attr[:annotations] = newanns

    # handle legend/colorbar
    sp.attr[:legend_position] = convert_legend_value(sp.attr[:legend_position])
    sp.attr[:colorbar] = convert_legend_value(sp.attr[:colorbar])
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

function Plots.expand_extrema!(sp::Subplot, plotattributes::AKW)

    # first expand for the data
    for letter in (:x, :y, :z)
        data = plotattributes[
            letter
        ]
        if (
            letter !== :z &&
            plotattributes[:seriestype] === :straightline &&
            any(series[:seriestype] !== :straightline for series in series_list(sp)) &&
            length(data) > 1 &&
            data[1] != data[2]
        )
            data = [NaN]
        end
        axis = sp[get_attr_symbol(letter, :axis)]

        if isa(data, Plots.Volume)
            expand_extrema!(sp[:xaxis], data.x_extents)
            expand_extrema!(sp[:yaxis], data.y_extents)
            expand_extrema!(sp[:zaxis], data.z_extents)
        elseif eltype(data) <: Number ||
               (isa(data, Surface) && all(di -> isa(di, Number), data.surf))
            if !(eltype(data) <: Number)
                # huh... must have been a mis-typed surface? lets swap it out
                data = plotattributes[letter] = Surface(Matrix{Float64}(data.surf))
            end
            expand_extrema!(axis, data)
        elseif data !== nothing
            # TODO: need more here... gotta track the discrete reference value
            #       as well as any coord offset (think of boxplot shape coords... they all
            #       correspond to the same x-value)
            plotattributes[letter],
            plotattributes[get_attr_symbol(letter, :(_discrete_indices))] =
                discrete_value!(axis, data)
            expand_extrema!(axis, plotattributes[letter])
        end
    end

    # expand for fillrange
    fr = plotattributes[:fillrange]
    if fr === nothing && plotattributes[:seriestype] === :bar
        fr = 0.0
    end
    if fr !== nothing && !RecipesPipeline.is3d(plotattributes)
        axis = sp.attr[:yaxis]
        if typeof(fr) <: Tuple
            foreach(x -> expand_extrema!(axis, x), fr)
        else
            expand_extrema!(axis, fr)
        end
    end

    # expand for bar_width
    if plotattributes[:seriestype] === :bar
        dsym = :x
        data = plotattributes[dsym]

        if (bw = plotattributes[:bar_width]) === nothing
            pos = filter(>(0), diff(sort(data)))
            plotattributes[:bar_width] = bw = _bar_width * ignorenan_minimum(pos)
        end
        axis = sp.attr[get_attr_symbol(dsym, :axis)]
        expand_extrema!(axis, ignorenan_maximum(data) + 0.5maximum(bw))
        expand_extrema!(axis, ignorenan_minimum(data) - 0.5minimum(bw))
    end

    # expand for heatmaps
    if plotattributes[:seriestype] === :heatmap
        for letter in (:x, :y)
            data = plotattributes[letter]
            axis = sp[get_attr_symbol(letter, :axis)]
            scale = get(plotattributes, get_attr_symbol(letter, :scale), :identity)
            expand_extrema!(axis, heatmap_edges(data, scale))
        end
    end
end

function Plots.expand_extrema!(sp::Subplot, xmin, xmax, ymin, ymax)
    expand_extrema!(sp[:xaxis], (xmin, xmax))
    expand_extrema!(sp[:yaxis], (ymin, ymax))
end
end # Subplots
