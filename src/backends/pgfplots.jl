# https://github.com/sisl/PGFPlots.jl

# significant contributions by: @pkofod

const _pgfplots_attr = merge_with_base_supported([
    # :annotations,
    # :background_color_legend,
    :background_color_inside,
    # :background_color_outside,
    # :foreground_color_legend, :foreground_color_grid, :foreground_color_axis,
    #     :foreground_color_text, :foreground_color_border,
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
    :guide, :lims, :ticks, :scale, :flip, :rotation,
    :tickfont, :guidefont, :legendfont,
    :grid, :legend,
    # :colorbar,
    # :marker_z, :levels,
    # :ribbon, :quiver, :arrow,
    # :orientation,
    # :overwrite_figure,
    # :polar,
    # :normalize, :weights, :contours,
    :aspect_ratio,
    # :match_dimensions,
  ])
const _pgfplots_seriestype = [:path, :path3d, :scatter, :steppre, :stepmid, :steppost, :histogram2d, :ysticks, :xsticks, :contour]
const _pgfplots_style = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]
const _pgfplots_marker = [:none, :auto, :circle, :rect, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star5, :pentagon] #vcat(_allMarkers, Shape)
const _pgfplots_scale = [:identity, :ln, :log2, :log10]


# --------------------------------------------------------------------------------------


function _initialize_backend(::PGFPlotsBackend; kw...)
    @eval begin
        import PGFPlots
        export PGFPlots
    end
end


# --------------------------------------------------------------------------------------

const _pgfplots_linestyles = KW(
    :solid => "solid",
    :dash => "dashed",
    :dot => "dotted",
    :dashdot => "dashdotted",
    :dashdotdot => "dashdotdotted",
)

const _pgfplots_markers = KW(
    :none => "none",
    :cross => "+",
    :xcross => "x",
    :+ => "+",
    :x => "x",
    :utriangle => "triangle*",
    :dtriangle => "triangle*",
    :circle => "*",
    :rect => "square*",
    :star5 => "star",
    :star6 => "asterisk",
    :diamond => "diamond*",
    :pentagon => "pentagon*",
)

const _pgfplots_legend_pos = KW(
    :bottomleft => "south west",
    :bottomright => "south east",
    :topright => "north east",
    :topleft => "north west",
)


const _pgf_series_extrastyle = KW(
    :steppre => "const plot mark right",
    :stepmid => "const plot mark mid",
    :steppost => "const plot",
    :sticks => "ycomb",
    :ysticks => "ycomb",
    :xsticks => "xcomb",
)

# --------------------------------------------------------------------------------------

# takes in color,alpha, and returns color and alpha appropriate for pgf style
function pgf_color(c)
    cstr = @sprintf("{rgb,1:red,%.8f;green,%.8f;blue,%.8f}", red(c), green(c), blue(c))
    cstr, alpha(c)
end

function pgf_fillstyle(d::KW)
    cstr,a = pgf_color(d[:fillcolor])
    "fill = $cstr, fill opacity=$a"
end

function pgf_linestyle(d::KW)
    cstr,a = pgf_color(d[:linecolor])
    """
    color = $cstr,
    draw opacity=$a,
    line width=$(d[:linewidth]),
    $(get(_pgfplots_linestyles, d[:linestyle], "solid"))"""
end

function pgf_marker(d::KW)
    shape = d[:markershape]
    cstr, a = pgf_color(d[:markercolor])
    cstr_stroke, a_stroke = pgf_color(d[:markerstrokecolor])
    """
    mark = $(get(_pgfplots_markers, shape, "*")),
    mark size = $(0.5 * d[:markersize]),
    mark options = {
        color = $cstr_stroke, draw opacity = $a_stroke,
        fill = $cstr, fill opacity = $a,
        line width = $(d[:markerstrokewidth]),
        rotate = $(shape == :dtriangle ? 180 : 0),
        $(get(_pgfplots_linestyles, d[:markerstrokestyle], "solid"))
    }"""
end

# --------------------------------------------------------------------------------------

function pgf_series(sp::Subplot, series::Series)
    d = series.d
    st = d[:seriestype]
    style = []
    kw = KW()

    push!(style, pgf_linestyle(d))
    push!(style, pgf_marker(d))

    if d[:fillrange] != nothing
        push!(style, pgf_fillstyle(d))
    end

    # add to legend?
    if sp[:legend] != :none && should_add_to_legend(series)
        kw[:legendentry] = d[:label]
    else
        push!(style, "forget plot")
    end

    # function args
    args = if st  == :contour
        d[:z].surf, d[:x], d[:y]
    elseif is3d(st)
        d[:x], d[:y], d[:z]
    else
        d[:x], d[:y]
    end

    # PGFPlots can't handle non-Vector?
    args = map(a -> if typeof(a) <: AbstractVector && typeof(a) != Vector
            collect(a)
        else
            a
        end, args)
    # for (i,a) in enumerate(args)
    #     if typeof(a) <: AbstractVector && typeof(a) != Vector
    #         args[i] = collect(a)
    #     end
    # end

    # include additional style, then add to the kw
    if haskey(_pgf_series_extrastyle, st)
        push!(style, _pgf_series_extrastyle[st])
    end
    kw[:style] = join(style, ',')

    # build/return the series object
    func = if st == :path3d
        PGFPlots.Linear3
    elseif st == :scatter
        PGFPlots.Scatter
    elseif st == :histogram2d
        PGFPlots.Histogram2
    elseif st == :contour
        PGFPlots.Contour
    else
        PGFPlots.Linear
    end
    func(args...; kw...)
end


# ----------------------------------------------------------------

function pgf_axis(sp::Subplot, letter)
    axis = sp[Symbol(letter,:axis)]
    style = []
    kw = KW()

    # axis guide
    kw[Symbol(letter,:label)] = axis[:guide]

    # flip/reverse?
    axis[:flip] && push!(style, "$letter dir=reverse")

    # scale
    scale = axis[:scale]
    if scale in (:log2, :ln, :log10)
        kw[Symbol(letter,:mode)] = "log"
        scale == :ln || push!(style, "log basis $letter=$(scale == :log2 ? 2 : 10)")
    end

    # ticks on or off
    if axis[:ticks] in (nothing, false)
        push!(style, "$(letter)majorticks=false")
    end

    # limits
    # TODO: support zlims
    if letter != :z
        lims = axis_limits(axis)
        kw[Symbol(letter,:min)] = lims[1]
        kw[Symbol(letter,:max)] = lims[2]
    end

    if !(axis[:ticks] in (nothing, false, :none, :auto))
        ticks = get_ticks(axis)
        push!(style, string(letter, "tick = {", join(ticks[1],","), "}"))
        push!(style, string(letter, "ticklabels = {", join(ticks[2],","), "}"))
    end

    # return the style list and KW args
    style, kw
end

# ----------------------------------------------------------------


function _update_plot_object(plt::Plot{PGFPlotsBackend})
    plt.o = PGFPlots.Axis[]
    for sp in plt.subplots
        # first build the PGFPlots.Axis object
        style = ["unbounded coords=jump"]
        kw = KW()

        # add to style/kw for each axis
        for letter in (:x, :y, :z)
            if letter != :z || is3d(sp)
                axisstyle, axiskw = pgf_axis(sp, letter)
                append!(style, axisstyle)
                merge!(kw, axiskw)
                for sty in axisstyle
                    push!(style, sty)
                end
            end
        end

        # bounding box values are in mm
        # note: bb origin is top-left, pgf is bottom-left
        bb = bbox(sp)
        push!(style, """
            xshift = $(left(bb).value)mm,
            yshift = $((height(bb) - (bottom(bb))).value)mm,
            axis background/.style={fill=$(pgf_color(sp[:background_color_inside])[1])}
        """)
        kw[:width] = "$(width(bb).value)mm"
        kw[:height] = "$(height(bb).value)mm"

        if sp[:title] != ""
            kw[:title] = "$(sp[:title])"
        end

        sp[:grid] && push!(style, "grid = major")
        if sp[:aspect_ratio] in (1, :equal)
            kw[:axisEqual] = "true"
        end

        legpos = sp[:legend]
        if haskey(_pgfplots_legend_pos, legpos)
            kw[:legendPos] = _pgfplots_legend_pos[legpos]
        end

        o = PGFPlots.Axis(; style = style, kw...)

        # add the series object to the PGFPlots.Axis
        for series in series_list(sp)
            push!(o, pgf_series(sp, series))
        end

        # add the PGFPlots.Axis to the list
        push!(plt.o, o)
    end
end


function _show(io::IO, mime::MIME"image/svg+xml", plt::Plot{PGFPlotsBackend})
    show(io, mime, plt.o)
end

function _show(io::IO, mime::MIME"application/pdf", plt::Plot{PGFPlotsBackend})
    # prepare the object
    pgfplt = PGFPlots.plot(plt.o)

    # save a pdf
    fn = tempname()*".pdf"
    PGFPlots.save(PGFPlots.PDF(fn), pgfplt)

    # read it into io
    write(io, readall(open(fn)))

    # cleanup
    PGFPlots.cleanup(plt.o)
end

function _display(plt::Plot{PGFPlotsBackend})
    # prepare the object
    pgfplt = PGFPlots.plot(plt.o)

    # save an svg
    fn = string(tempname(), ".svg")
    PGFPlots.save(PGFPlots.SVG(fn), pgfplt)

    # show it
    open_browser_window(fn)

    # cleanup
    PGFPlots.cleanup(plt.o)
end
