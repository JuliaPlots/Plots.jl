module UnicodePlotsExt

import PlotsBase: PlotsBase, texmath2unicode
import RecipesPipeline
import UnicodePlots

using PlotsBase.Annotations
using PlotsBase.DataSeries
using PlotsBase.Colorbars
using PlotsBase.Subplots
using PlotsBase.Commons
using PlotsBase.Shapes
using PlotsBase.Arrows
using PlotsBase.Colors
using PlotsBase.Plots
using PlotsBase.Fonts
using PlotsBase.Ticks
using PlotsBase.Axes

struct UnicodePlotsBackend <: PlotsBase.AbstractBackend end
PlotsBase.@extension_static UnicodePlotsBackend unicodeplots

const _unicodeplots_attrs = PlotsBase.merge_with_base_supported([
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
const _unicodeplots_seriestypes = [
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
const _unicodeplots_styles = [:auto, :solid]
const _unicodeplots_markers = [
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
const _unicodeplots_scales = [:identity, :ln, :log2, :log10]

# https://github.com/JuliaPlots/UnicodePlots.jl

const _canvas_map = (
    braille = UnicodePlots.BrailleCanvas,
    density = UnicodePlots.DensityCanvas,
    heatmap = UnicodePlots.HeatmapCanvas,
    lookup = UnicodePlots.LookupCanvas,
    ascii = UnicodePlots.AsciiCanvas,
    block = UnicodePlots.BlockCanvas,
    dot = UnicodePlots.DotCanvas,
)

PlotsBase.should_warn_on_unsupported(::UnicodePlotsBackend) = false

function PlotsBase._before_layout_calcs(plt::Plot{UnicodePlotsBackend})
    plt.o = UnicodePlots.Plot[]
    up_width = UnicodePlots.DEFAULT_WIDTH[]
    up_height = UnicodePlots.DEFAULT_HEIGHT[]

    has_layout = prod(size(plt.layout)) > 1
    for sp ∈ plt.subplots
        sp_kw = sp[:extra_kwargs]
        xaxis = sp[:xaxis]
        yaxis = sp[:yaxis]
        xlim = collect(axis_limits(sp, :x))
        ylim = collect(axis_limits(sp, :y))
        zlim = collect(axis_limits(sp, :z))
        F = float(eltype(xlim))

        # We set x/y to have a single point,
        # since we need to create the plot with some data.
        # Since this point is at the bottom left corner of the plot,
        # it should be hidden by consecutive plotting commands.
        x = Vector{F}(xlim)
        y = Vector{F}(ylim)
        z = Vector{F}(zlim)

        plot_3d = RecipesPipeline.is3d(sp)

        # create a plot window with xlim/ylim set,
        # but the X/Y vectors are outside the bounds
        canvas = if (up_c = get(sp_kw, :canvas, :auto)) ≡ :auto
            PlotsBase.isijulia() ? :ascii : :braille
        else
            up_c
        end

        border = if (up_b = get(sp_kw, :border, :auto)) ≡ :auto
            if plot_3d
                :none  # no plots border in 3d (consistency with other backends)
            else
                PlotsBase.isijulia() ? :ascii : :solid
            end
        else
            up_b
        end

        # blank plots will not be shown
        width = has_layout && isempty(series_list(sp)) ? 0 : get(sp_kw, :width, up_width)
        height = get(sp_kw, :height, up_height)

        blend = get(sp_kw, :blend, true)
        grid = xaxis[:grid] && yaxis[:grid]
        quiver = contour = false
        for series ∈ series_list(sp)
            st = series[:seriestype]
            blend &= get(series[:extra_kwargs], :blend, true)
            quiver |= series[:arrow] isa Arrow  # post-pipeline detection (:quiver -> :path)
            contour |= st ≡ :contour
            if st ≡ :histogram2d
                xlim = ylim = (0, 0)
            elseif st ≡ :spy || st ≡ :heatmap
                width = height = nothing
                grid = false
            end
        end
        grid &= !(quiver || contour)
        blend &= !(quiver || contour)

        plot_3d && (xlim = ylim = (0, 0))  # determined using projection
        azimuth, elevation = sp[:camera]
        # use the same convention as `gr`, `PyPlot`, `PlotlyJS`, and wrap in range [-180, 180]
        azimuth = mod(azimuth + 180 - 90, 360) - 180
        # => this defaults to azimuth = -60, elevation = 30
        projection = if plot_3d
            (
                auto = :ortho,  # we choose to unify backends by using `:ortho` proj when `:auto`
                ortho = :ortho,
                orthographic = :ortho,
                persp = :persp,
                perspective = :persp,
            )[sp[:projection_type]]
        else
            nothing
        end

        kw = (
            compact = true,
            title = texmath2unicode(sp[:title]),
            xlabel = texmath2unicode(xaxis[:guide]),
            ylabel = texmath2unicode(yaxis[:guide]),
            labels = !plot_3d,  # guide labels and limits do not make sense in 3d
            xscale = xaxis[:scale],
            yscale = yaxis[:scale],
            xflip = xaxis[:flip],
            yflip = yaxis[:flip],
            xticks = has_ticks(xaxis),
            yticks = has_ticks(yaxis),
            border,
            height,
            width,
            blend,
            grid,
            xlim,
            ylim,
            # 3d
            projection,
            elevation,
            azimuth,
            zoom = get(sp_kw, :zoom, 1),
            up = get(sp_kw, :up, :z),
        )

        o = UnicodePlots.Plot(x, y, plot_3d ? z : nothing, _canvas_map[canvas]; kw...)
        for series ∈ series_list(sp)
            o = addUnicodeSeries!(sp, o, kw, series, sp[:legend_position] ≢ :none, plot_3d)
        end

        for ann ∈ sp[:annotations]
            x, y, val = locate_annotation(sp, ann...)
            o = UnicodePlots.annotate!(
                o,
                x,
                y,
                texmath2unicode(val.str);
                color = up_color(val.font.color),
                halign = val.font.halign,
                valign = val.font.valign,
            )
        end

        push!(plt.o, o)  # save the object
    end
end

up_color(col::UnicodePlots.UserColorType) = col
up_color(col::RGBA) =
    (c = convert(ARGB32, col); map(Int, (red(c).i, green(c).i, blue(c).i)))
up_color(::Any) = :auto

up_cmap(series) = map(
    c -> (red(c), green(c), blue(c)),
    get(get_colorgradient(series), range(0, 1, length = 256)),
)

# add a single series
function addUnicodeSeries!(
    sp::Subplot{UnicodePlotsBackend},
    up::UnicodePlots.Plot,
    kw,
    series,
    addlegend::Bool,
    plot_3d::Bool,
)
    st = series[:seriestype]
    se_kw = series[:extra_kwargs]

    # get the series data and label
    x, y = if st ≡ :straightline
        PlotsBase.straightline_data(series)
    elseif st ≡ :shape
        PlotsBase.shape_data(series)
    else
        series[:x], series[:y]
    end

    (ispolar(sp) || ispolar(series)) && return UnicodePlots.polarplot(x, y)

    # special handling (src/interface)
    fix_ar = get(se_kw, :fix_ar, true)
    if st ≡ :histogram2d
        return UnicodePlots.densityplot(x, y; kw...)
    elseif st ≡ :spy
        return UnicodePlots.spy(Array(series[:z]); fix_ar = fix_ar, kw...)
    elseif st ≡ :image
        return UnicodePlots.imageplot(Array(series[:z]); kw...)
    elseif st in (:contour, :heatmap)  # 2D
        colormap = get(se_kw, :colormap, :none)
        kw = (
            kw...,
            zlabel = sp[:colorbar_title],
            colormap = colormap ≡ :none ? up_cmap(series) : colormap,
            colorbar = hascolorbar(sp),
        )
        z = Array(series[:z])
        if st ≡ :contour
            isfilledcontour(series) &&
                @warn "PlotsBase(UnicodePlots): filled contour is not implemented"
            return UnicodePlots.contourplot(x, y, z; kw..., levels = series[:levels])
        elseif st ≡ :heatmap
            return UnicodePlots.heatmap(z; fix_ar = fix_ar, kw...)
        end
    elseif st in (:surface, :wireframe)  # 3D
        colormap = get(se_kw, :colormap, :none)
        lines = get(se_kw, :lines, st ≡ :wireframe)
        zscale = get(se_kw, :zscale, :aspect)
        kw = (
            kw...,
            zlabel = sp[:colorbar_title],
            color = st ≡ :wireframe ? up_color(get_linecolor(series, 1)) : nothing,
            colormap = colormap ≡ :none ? up_cmap(series) : colormap,
            colorbar = hascolorbar(sp),
            zscale,
            lines,
        )
        z = Array(series[:z])
        return UnicodePlots.surfaceplot(x, y, z isa AMat ? transpose(z) : z; kw...)
    elseif st ≡ :mesh3d
        return UnicodePlots.lineplot!(
            up,
            PlotsBase.mesh3d_triangles(x, y, series[:z], series[:connections])...,
        )
    end

    # now use the ! functions to add to the plot
    if st in (:path, :path3d, :straightline, :shape, :mesh3d)
        func = UnicodePlots.lineplot!
        series_kw = (; head_tail = series[:arrow] isa Arrow ? series[:arrow].side : nothing)
    elseif st in (:scatter, :scatter3d) || series[:markershape] ≢ :none
        func = UnicodePlots.scatterplot!
        series_kw = (; marker = series[:markershape])
    else
        throw(ArgumentError("PlotsBase(UnicodePlots): series type $st not supported"))
    end

    label = addlegend ? series[:label] : ""

    for (n, segment) ∈ enumerate(series_segments(series, st; check = true))
        i, rng = segment.attr_index, segment.range
        lc = get_linecolor(series, i)
        up = func(
            up,
            x[rng],
            y[rng],
            plot_3d ? series[:z][rng] : nothing;
            color = up_color(lc),
            name = n == 1 ? label : "",
            series_kw...,
        )
    end

    for (xi, yi, str, fnt) ∈ EachAnn(series[:series_annotations], x, y)
        up = UnicodePlots.annotate!(
            up,
            xi,
            yi,
            str;
            color = up_color(fnt.color),
            halign = fnt.halign,
            valign = fnt.valign,
        )
    end

    up
end

function unsupported_layout_error()
    """
    PlotsBase(UnicodePlots): complex nested layout is currently unsupported.
    Consider using plain `UnicodePlots` commands and `grid` from Term.jl as an alternative.
    """ |>
    ArgumentError |>
    throw
    nothing
end

# ------------------------------------------------------------------------------------------

function PlotsBase._show(io::IO, ::MIME"image/png", plt::Plot{UnicodePlotsBackend})
    applicable(UnicodePlots.save_image, io) ||
        "PlotsBase(UnicodePlots): saving to `.png` requires `import FreeType, FileIO`" |>
        ArgumentError |>
        throw
    PlotsBase.prepare_output(plt)
    nr, nc = size(plt.layout)
    s1, s2 = map(_ -> zeros(Int, nr, nc), 1:2)
    canvas_type = nothing
    imgs = []
    sps = 0
    for r ∈ 1:nr, c ∈ 1:nc
        if (l = plt.layout[r, c]) isa GridLayout && size(l) != (1, 1)
            unsupported_layout_error()
        else
            img = UnicodePlots.png_image(plt.o[sps += 1]; pixelsize = 32)
            img ≡ nothing && continue
            canvas_type = eltype(img)
            s1[r, c], s2[r, c] = size(img)
            push!(imgs, img)
        end
    end
    if canvas_type ≡ nothing
        @warn "PlotsBase(UnicodePlots) failed to render `png` from plot (font issue)."
    else
        m1 = maximum(s1; dims = 2)
        m2 = maximum(s2; dims = 1)
        img = zeros(canvas_type, sum(m1), sum(m2))
        length(img) == 0 && return  # early return on failing fonts
        sps = 0
        n1 = 1
        for r ∈ 1:nr
            n2 = 1
            for c ∈ 1:nc
                h, w = (sp = imgs[sps += 1]) |> size
                img[n1:(n1 + (h - 1)), n2:(n2 + (w - 1))] = sp
                n2 += m2[c]
            end
            n1 += m1[r]
        end
        UnicodePlots.save_image(io, img)
    end
    nothing
end

Base.show(plt::Plot{UnicodePlotsBackend}) = show(stdout, plt)
Base.show(io::IO, plt::Plot{UnicodePlotsBackend}) =
    PlotsBase._show(io, MIME("text/plain"), plt)

# NOTE: _show(...) must be kept for Base.showable (src/output.jl)
function PlotsBase._show(io::IO, ::MIME"text/plain", plt::Plot{UnicodePlotsBackend})
    PlotsBase.prepare_output(plt)
    nr, nc = size(plt.layout)
    if nr == 1 && nc == 1  # fast path
        n = length(plt.o)
        for (i, p) ∈ enumerate(plt.o)
            show(io, p)
            i < n && println(io)
        end
    else
        have_color = Base.get_have_color()
        lines_colored = Array{Union{Nothing,Vector{String}}}(nothing, nr, nc)
        lines_uncolored = have_color ? similar(lines_colored) : lines_colored
        l_max = zeros(Int, nr)
        w_max = zeros(Int, nc)
        nsp = length(plt.o)
        sps = 0
        for r ∈ 1:nr
            lmax = 0
            for c ∈ 1:nc
                if (l = plt.layout[r, c]) isa GridLayout && size(l) != (1, 1)
                    unsupported_layout_error()
                else
                    if get(l.attr, :blank, false)
                        continue
                    elseif (sps += 1) > nsp
                        continue
                    end
                    colored = string(plt.o[sps]; color = have_color)
                    lines_colored[r, c] = lu = lc = split(colored, '\n')
                    if have_color
                        uncolored = UnicodePlots.no_ansi_escape(colored)
                        lines_uncolored[r, c] = lu = split(uncolored, '\n')
                    end
                    lmax = max(length(lc), lmax)
                    w_max[c] = max(maximum(length.(lu)), w_max[c])
                end
            end
            l_max[r] = lmax
        end
        empty = map(w -> ' '^w, w_max)
        for r ∈ 1:nr
            for n ∈ 1:l_max[r]
                for c ∈ 1:nc
                    pre = c == 1 ? '\0' : ' '
                    if (lc = lines_colored[r, c]) ≡ nothing || length(lc) < n
                        print(io, pre, empty[c])
                    else
                        lu = lines_uncolored[r, c]
                        print(io, pre, lc[n], ' '^(w_max[c] - length(lu[n])))
                    end
                end
                n < l_max[r] && println(io)
            end
            r < nr && println(io)
        end
    end
    nothing
end

# we only support MIME"text/plain", hence display(...) falls back to plain-text on stdout
function PlotsBase._display(plt::Plot{UnicodePlotsBackend})
    show(stdout, plt)
    println(stdout)
end

end  # module
