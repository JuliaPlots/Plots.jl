# https://github.com/sisl/PGFPlots.jl

# significant contributions by: @pkofod

@require Revise begin
    Revise.track(Plots, joinpath(Pkg.dir("Plots"), "src", "backends", "pgfplots.jl"))
end

const _pgfplots_attr = merge_with_base_supported([
    :annotations,
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
    :colorbar,
    :marker_z, #:levels,
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
  ])
const _pgfplots_seriestype = [:path, :path3d, :scatter, :steppre, :stepmid, :steppost, :histogram2d, :ysticks, :xsticks, :contour, :shape]
const _pgfplots_style = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]
const _pgfplots_marker = [:none, :auto, :circle, :rect, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star5, :pentagon, :hline] #vcat(_allMarkers, Shape)
const _pgfplots_scale = [:identity, :ln, :log2, :log10]


# --------------------------------------------------------------------------------------

function add_backend_string(::PGFPlotsBackend)
    """
    Pkg.add("PGFPlots")
    Pkg.build("PGFPlots")
    """
end

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
    :hline => "-"
)

const _pgfplots_legend_pos = KW(
    :bottomleft => "south west",
    :bottomright => "south east",
    :topright => "north east",
    :topleft => "north west",
    :outertopright => "outer north east",
)


const _pgf_series_extrastyle = KW(
    :steppre => "const plot mark right",
    :stepmid => "const plot mark mid",
    :steppost => "const plot",
    :sticks => "ycomb",
    :ysticks => "ycomb",
    :xsticks => "xcomb",
)

# PGFPlots uses the anchors to define orientations for example to align left
# one needs to use the right edge as anchor
const _pgf_annotation_halign = KW(
    :center => "",
    :left => "right",
    :right => "left"
)

const _pgf_framestyles = [:box, :axes, :origin, :zerolines, :grid, :none]
const _pgf_framestyle_defaults = Dict(:semi => :box)
function pgf_framestyle(style::Symbol)
    if style in _pgf_framestyles
        return style
    else
        default_style = get(_pgf_framestyle_defaults, style, :axes)
        warn("Framestyle :$style is not (yet) supported by the PGFPlots backend. :$default_style was cosen instead.")
        default_style
    end
end

# --------------------------------------------------------------------------------------

# takes in color,alpha, and returns color and alpha appropriate for pgf style
function pgf_color(c::Colorant)
    cstr = @sprintf("{rgb,1:red,%.8f;green,%.8f;blue,%.8f}", red(c), green(c), blue(c))
    cstr, alpha(c)
end

function pgf_color(grad::ColorGradient)
    # Can't handle ColorGradient here, fallback to defaults.
    cstr = @sprintf("{rgb,1:red,%.8f;green,%.8f;blue,%.8f}", 0.0, 0.60560316,0.97868012)
    cstr, 1
end

# Generates a colormap for pgfplots based on a ColorGradient
function pgf_colormap(grad::ColorGradient)
    join(map(grad.colors) do c
        @sprintf("rgb=(%.8f,%.8f,%.8f)", red(c), green(c),blue(c))
    end,", ")
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

function pgf_add_annotation!(o,x,y,val)
    # Construct the style string.
    # Currently supports color and orientation
    cstr,a = pgf_color(val.font.color)
    push!(o, PGFPlots.Plots.Node(val.str, # Annotation Text
                                 x, y,
                                 style="""
                                 $(get(_pgf_annotation_halign,val.font.halign,"")),
                                 color=$cstr, draw opacity=$(convert(Float16,a)),
                                 rotate=$(val.font.rotation)
                                 """))
end

# --------------------------------------------------------------------------------------

function pgf_series(sp::Subplot, series::Series)
    d = series.d
    st = d[:seriestype]
    style = []
    kw = KW()
    push!(style, pgf_linestyle(d))
    push!(style, pgf_marker(d))

    if d[:fillrange] != nothing || st in (:shape,)
        push!(style, pgf_fillstyle(d))
    end

    # add to legend?
    if sp[:legend] != :none && should_add_to_legend(series)
        kw[:legendentry] = d[:label]
        if st == :shape || d[:fillrange] != nothing
            push!(style, "area legend")
        end
    else
        push!(style, "forget plot")
    end

    # function args
    args = if st  == :contour
        d[:z].surf, d[:x], d[:y]
    elseif is3d(st)
        d[:x], d[:y], d[:z]
    elseif d[:marker_z] != nothing
        # If a marker_z is used pass it as third coordinate to a 2D plot.
        # See "Scatter Plots" in PGFPlots documentation
        d[:x], d[:y], d[:marker_z]
    elseif ispolar(sp)
        theta, r = filter_radial_data(d[:x], d[:y], axis_limits(sp[:yaxis]))
        rad2deg.(theta), r
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

    # turn off scaled ticks
    push!(style, "scaled $(letter) ticks = false")

    # set to supported framestyle
    framestyle = pgf_framestyle(sp[:framestyle])

    # axis guide
    kw[Symbol(letter,:label)] = axis[:guide]

    # Add ticklabel rotations
    push!(style, "$(letter)ticklabel style={rotate = $(axis[:rotation])}")

    # flip/reverse?
    axis[:flip] && push!(style, "$letter dir=reverse")

    # scale
    scale = axis[:scale]
    if scale in (:log2, :ln, :log10)
        kw[Symbol(letter,:mode)] = "log"
        scale == :ln || push!(style, "log basis $letter=$(scale == :log2 ? 2 : 10)")
    end

    # ticks on or off
    if axis[:ticks] in (nothing, false, :none) || framestyle == :none
        push!(style, "$(letter)majorticks=false")
    end

    # grid on or off
    if axis[:grid] && framestyle != :none
        push!(style, "$(letter)majorgrids = true")
    else
        push!(style, "$(letter)majorgrids = false")
    end

    # limits
    # TODO: support zlims
    if letter != :z
        lims = ispolar(sp) && letter == :x ? rad2deg.(axis_limits(axis)) : axis_limits(axis)
        kw[Symbol(letter,:min)] = lims[1]
        kw[Symbol(letter,:max)] = lims[2]
    end

    if !(axis[:ticks] in (nothing, false, :none, :native)) && framestyle != :none
        ticks = get_ticks(axis)
        #pgf plot ignores ticks with angle below 90 when xmin = 90 so shift values
        tick_values = ispolar(sp) && letter == :x ? [rad2deg.(ticks[1])[3:end]..., 360, 405] : ticks[1]
        push!(style, string(letter, "tick = {", join(tick_values,","), "}"))
        if axis[:showaxis] && axis[:scale] in (:ln, :log2, :log10) && axis[:ticks] == :auto
            # wrap the power part of label with }
            tick_labels = String[begin
                base, power = split(label, "^")
                power = string("{", power, "}")
                string(base, "^", power)
            end for label in ticks[2]]
            push!(style, string(letter, "ticklabels = {\$", join(tick_labels,"\$,\$"), "\$}"))
        elseif axis[:showaxis]
            tick_labels = ispolar(sp) && letter == :x ? [ticks[2][3:end]..., "0", "45"] : ticks[2]
            tick_labels = axis[:formatter] == :scientific ? string.("\$", convert_sci_unicode.(tick_labels), "\$") : tick_labels
            push!(style, string(letter, "ticklabels = {", join(tick_labels,","), "}"))
        else
            push!(style, string(letter, "ticklabels = {}"))
        end
        push!(style, string(letter, "tick align = ", (axis[:tick_direction] == :out ? "outside" : "inside")))
    end

    # framestyle
    if framestyle in (:axes, :origin)
        axispos = framestyle == :axes ? "left" : "middle"
        # the * after lines disables the arrows at the axes
        push!(style, string("axis lines* = ", axispos))
    end

    if framestyle == :zerolines
        push!(style, string("extra ", letter, " ticks = 0"))
        push!(style, string("extra ", letter, " tick labels = "))
        push!(style, string("extra ", letter, " tick style = {grid = major, major grid style = {color = black, draw opacity=1.0, line width=0.5), solid}}"))
    end

    if !axis[:showaxis]
        push!(style, "separate axis lines")
    end
    if !axis[:showaxis] || framestyle in (:zerolines, :grid, :none)
        push!(style, string(letter, " axis line style = {draw opacity = 0}"))
    end

    # return the style list and KW args
    style, kw
end

# ----------------------------------------------------------------


function _update_plot_object(plt::Plot{PGFPlotsBackend})
    plt.o = PGFPlots.Axis[]
    # Obtain the total height of the plot by extracting the maximal bottom
    # coordinate from the bounding box.
    total_height = bottom(bbox(plt.layout))

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
            end
        end

        # bounding box values are in mm
        # note: bb origin is top-left, pgf is bottom-left
        # A round on 2 decimal places should be enough precision for 300 dpi
        # plots.
        bb = bbox(sp)
        push!(style, """
            xshift = $(left(bb).value)mm,
            yshift = $(round((total_height - (bottom(bb))).value,2))mm,
            axis background/.style={fill=$(pgf_color(sp[:background_color_inside])[1])}
        """)
        kw[:width] = "$(width(bb).value)mm"
        kw[:height] = "$(height(bb).value)mm"

        if sp[:title] != ""
            kw[:title] = "$(sp[:title])"
        end

        if sp[:aspect_ratio] in (1, :equal)
            kw[:axisEqual] = "true"
        end

        legpos = sp[:legend]
        if haskey(_pgfplots_legend_pos, legpos)
            kw[:legendPos] = _pgfplots_legend_pos[legpos]
        end

        if is3d(sp)
            azim, elev = sp[:camera]
            kw[:view] = "{$(azim)}{$(elev)}"
        end

        axisf = PGFPlots.Axis
        if sp[:projection] == :polar
            axisf = PGFPlots.PolarAxis
            #make radial axis vertical
            kw[:xmin] = 90
            kw[:xmax] = 450
        end

        # Search series for any gradient. In case one series uses a gradient set
        # the colorbar and colomap.
        # The reasoning behind doing this on the axis level is that pgfplots
        # colorbar seems to only works on axis level and needs the proper colormap for
        # correctly displaying it.
        # It's also possible to assign the colormap to the series itself but
        # then the colormap needs to be added twice, once for the axis and once for the
        # series.
        # As it is likely that all series within the same axis use the same
        # colormap this should not cause any problem.
        for series in series_list(sp)
            for col in (:markercolor, :fillcolor)
                if typeof(series.d[col]) == ColorGradient
                    push!(style,"colormap={plots}{$(pgf_colormap(series.d[col]))}")

                    if sp[:colorbar] == :none
                        kw[:colorbar] = "false"
                    else
                        kw[:colorbar] = "true"
                    end
                    # goto is needed to break out of col and series for
                    @goto colorbar_end
                end
            end
        end
        @label colorbar_end

        o = axisf(; style = join(style, ","), kw...)

        # add the series object to the PGFPlots.Axis
        for series in series_list(sp)
            push!(o, pgf_series(sp, series))

            # add series annotations
            anns = series[:series_annotations]
            for (xi,yi,str,fnt) in EachAnn(anns, series[:x], series[:y])
                pgf_add_annotation!(o, xi, yi, PlotText(str, fnt))
            end
        end

        # add the annotations
        for ann in sp[:annotations]
            pgf_add_annotation!(o, locate_annotation(sp, ann...)...)
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
    write(io, readstring(open(fn)))

    # cleanup
    PGFPlots.cleanup(plt.o)
end

function _show(io::IO, mime::MIME"application/x-tex", plt::Plot{PGFPlotsBackend})
    fn = tempname()*".tex"
    PGFPlots.save(fn, backend_object(plt), include_preamble=false)
    write(io, readstring(open(fn)))
end

function _display(plt::Plot{PGFPlotsBackend})
    # prepare the object
    PGFPlots.pushPGFPlotsPreamble("\\usepackage{fontspec}")
    pgfplt = PGFPlots.plot(plt.o)

    # save an svg
    fn = string(tempname(), ".svg")
    PGFPlots.save(PGFPlots.SVG(fn), pgfplt)

    # show it
    open_browser_window(fn)

    # cleanup
    PGFPlots.cleanup(plt.o)
end
