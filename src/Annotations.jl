# internal module
module Annotations

using ..Plots.Commons
using ..Plots.Fonts: Font, PlotText, text
using ..Plots.Shapes: Shape
using ..Plots: Series, Subplot, TimeType, Length

export EachAnn, series_annotations, series_annotations_shapes!, process_annotation, locate_annotation, annotations, assign_annotation_coord!

mutable struct SeriesAnnotations
    strs::AVec  # the labels/names
    font::Font
    baseshape::Union{Shape,AVec{Shape},Nothing}
    scalefactor::Tuple
end

_text_label(lab::Tuple, font) = text(lab[1], font, lab[2:end]...)
_text_label(lab::PlotText, font) = lab
_text_label(lab, font) = text(lab, font)

series_annotations(scalar) = series_annotations([scalar])
series_annotations(anns::SeriesAnnotations) = anns
series_annotations(::Nothing) = nothing

function series_annotations(anns::AMat{SeriesAnnotations})
    @assert size(anns, 1) == 1 "matrix of SeriesAnnotations must be a row vector"
    anns
end

function series_annotations(anns::AMat, outer_args...)
    # Types that represent annotations for an entire series
    whole_series = Union{AVec,Tuple{AVec,Vararg{Any}}}

    # whole_series types can only be in a row vector
    if size(anns, 1) > 1
        for ann in Iterators.filter(ann -> ann isa whole_series, anns)
            "Given series annotation must be the only element in its column:\n$ann" |>
            ArgumentError |>
            throw
        end
    end

    ann_vec = map(eachcol(anns)) do col
        ann = first(col) isa whole_series ? first(col) : col

        # Override arguments from outer tuple with args from inner tuple
        strs, inner_args = Iterators.peel(wraptuple(ann))
        series_annotations(strs, outer_args..., inner_args...)
    end

    permutedims(ann_vec)
end

function series_annotations(strs::AVec, args...)
    fnt = font()
    shp = nothing
    scalefactor = 1, 1
    for arg in args
        if isa(arg, Shape) || (isa(arg, AVec) && eltype(arg) == Shape)
            shp = arg
        elseif isa(arg, Font)
            fnt = arg
        elseif isa(arg, Symbol) && haskey(_shapes, arg)
            shp = _shapes[arg]
        elseif isa(arg, Number)
            scalefactor = arg, arg
        elseif is_2tuple(arg)
            scalefactor = arg
        elseif isa(arg, AVec)
            strs = collect(zip(strs, arg))
        else
            @warn "Unused SeriesAnnotations arg: $arg ($(typeof(arg)))"
        end
    end
    SeriesAnnotations(map(s -> _text_label(s, fnt), strs), fnt, shp, scalefactor)
end

function series_annotations_shapes!(series::Series, scaletype::Symbol = :pixels)
    anns = series[:series_annotations]

    if anns !== nothing && anns.baseshape !== nothing
        # we use baseshape to overwrite the markershape attribute
        # with a list of custom shapes for each
        msw, msh = anns.scalefactor
        msize = Float64[]
        shapes = Vector{Shape}(undef, length(anns.strs))
        for i in eachindex(anns.strs)
            str = _cycle(anns.strs, i)

            # get the width and height of the string (in mm)
            sw, sh = text_size(str, anns.font.pointsize)

            # how much to scale the base shape?
            # note: it's a rough assumption that the shape fills the unit box [-1, -1, 1, 1],
            #       so we scale the length-2 shape by 1/2 the total length
            scalar = backend() == PyPlotBackend() ? 1.7 : 1.0
            xscale = 0.5to_pixels(sw) * scalar
            yscale = 0.5to_pixels(sh) * scalar

            # we save the size of the larger direction to the markersize list,
            # and then re-scale a copy of baseshape to match the w/h ratio
            maxscale = max(xscale, yscale)
            push!(msize, maxscale)
            baseshape = _cycle(anns.baseshape, i)
            shapes[i] =
                scale(baseshape, msw * xscale / maxscale, msh * yscale / maxscale, (0, 0))
        end
        series[:markershape] = shapes
        series[:markersize] = msize
    end
    nothing
end

mutable struct EachAnn
    anns
    x
    y
end

function Base.iterate(ea::EachAnn, i = 1)
    (ea.anns === nothing || isempty(ea.anns.strs) || i > length(ea.y)) && return

    tmp = _cycle(ea.anns.strs, i)
    str, fnt = if isa(tmp, PlotText)
        tmp.str, tmp.font
    else
        tmp, ea.anns.font
    end
    (_cycle(ea.x, i), _cycle(ea.y, i), str, fnt), i + 1
end

# -----------------------------------------------------------------------
annotations(anns::AMat) = map(annotations, anns)
annotations(sa::SeriesAnnotations) = sa
annotations(anns::AVec) = anns
annotations(anns) = Any[anns]
annotations(::Nothing) = []

_annotationfont(sp::Subplot) = font(;
    family = sp[:annotationfontfamily],
    pointsize = sp[:annotationfontsize],
    halign = sp[:annotationhalign],
    valign = sp[:annotationvalign],
    rotation = sp[:annotationrotation],
    color = sp[:annotationcolor],
)

_annotation(sp::Subplot, font, lab, pos...; alphabet = "abcdefghijklmnopqrstuvwxyz") = (
    pos...,
    lab === :auto ? text("($(alphabet[sp[:subplot_index]]))", font) :
    _text_label(lab, font),
)

assign_annotation_coord!(axis, x) = discrete_value!(axis, x)[1]
assign_annotation_coord!(axis, x::TimeType) = assign_annotation_coord!(axis, Dates.value(x))

_annotation_coords(pos::Symbol) = get(_positionAliases, pos, pos)
_annotation_coords(pos) = pos

function _process_annotation_2d(sp::Subplot, x, y, lab, font = _annotationfont(sp))
    x = assign_annotation_coord!(sp[:xaxis], x)
    y = assign_annotation_coord!(sp[:yaxis], y)
    _annotation(sp, font, lab, x, y)
end

_process_annotation_2d(
    sp::Subplot,
    pos::Union{Tuple,Symbol},
    lab,
    font = _annotationfont(sp),
) = _annotation(sp, font, lab, _annotation_coords(pos))

function _process_annotation_3d(sp::Subplot, x, y, z, lab, font = _annotationfont(sp))
    x = assign_annotation_coord!(sp[:xaxis], x)
    y = assign_annotation_coord!(sp[:yaxis], y)
    z = assign_annotation_coord!(sp[:zaxis], z)
    _annotation(sp, font, lab, x, y, z)
end

_process_annotation_3d(
    sp::Subplot,
    pos::Union{Tuple,Symbol},
    lab,
    font = _annotationfont(sp),
) = _annotation(sp, font, lab, _annotation_coords(pos))

function _process_annotation(sp::Subplot, ann, annotation_processor::Function)
    ann = makevec.(ann)
    [annotation_processor(sp, _cycle.(ann, i)...) for i in 1:maximum(length.(ann))]
end

# Expand arrays of coordinates, positions and labels into individual annotations
# and make sure labels are of type PlotText
process_annotation(sp::Subplot, ann) =
    _process_annotation(sp, ann, is3d(sp) ? _process_annotation_3d : _process_annotation_2d)

function _relative_position(xmin, xmax, pos::Length{:pct}, scale::Symbol)
    # !TODO Add more scales in the future (asinh, sqrt) ?
    if scale === :log || scale === :ln
        exp(log(xmin) + pos.value * log(xmax / xmin))
    elseif scale === :log10
        exp10(log10(xmin) + pos.value * log10(xmax / xmin))
    elseif scale === :log2
        exp2(log2(xmin) + pos.value * log2(xmax / xmin))
    else  # :identity (linear scale)
        xmin + pos.value * (xmax - xmin)
    end
end

# annotation coordinates in pct
const position_multiplier = Dict(
    :N            => (0.5, 0.9),
    :NE           => (0.9, 0.9),
    :E            => (0.9, 0.5),
    :SE           => (0.9, 0.1),
    :S            => (0.5, 0.1),
    :SW           => (0.1, 0.1),
    :W            => (0.1, 0.5),
    :NW           => (0.1, 0.9),
    :topleft      => (0.1, 0.9),
    :topcenter    => (0.5, 0.9),
    :topright     => (0.9, 0.9),
    :bottomleft   => (0.1, 0.1),
    :bottomcenter => (0.5, 0.1),
    :bottomright  => (0.9, 0.1),
)

# Give each annotation coordinates based on specified position
locate_annotation(sp::Subplot, rel::Tuple, label::PlotText) = (
    map(1:length(rel), (:x, :y, :z)) do i, letter
        _relative_position(
            axis_limits(sp, letter)...,
            rel[i] * pct,
            sp[get_attr_symbol(letter, :axis)][:scale],
        )
    end...,
    label,
)

locate_annotation(sp::Subplot, x, y, label::PlotText) = (x, y, label)
locate_annotation(sp::Subplot, x, y, z, label::PlotText) = (x, y, z, label)
locate_annotation(sp::Subplot, pos::Symbol, label::PlotText) =
    locate_annotation(sp, position_multiplier[pos], label)

end # Annotations
