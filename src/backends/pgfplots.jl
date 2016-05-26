# https://github.com/sisl/PGFPlots.jl

supportedArgs(::PGFPlotsBackend) = [
    # :annotation,
    :aspect_ratio,
    # :axis,
     :background_color,
    # :color_palette,
    # :fillrange,
     :fillcolor,
     :fillalpha,
    # :foreground_color,
    # :group,
     :label,
    # :layout,
     :legend,
     :seriescolor, :seriesalpha,
     :linecolor,
     :linestyle,
     :seriestype,
     :linewidth,
     :linealpha,
     :markershape,
     :markercolor,
     :markersize,
     :markeralpha,
     :markerstrokewidth,
     :markerstrokecolor,
     :markerstrokestyle,
    # :n,
    # :bins,
    # :nc,
    # :nr,
    # :pos,
    # :smooth,
    # :show,
     :size,
     :title,
    # :window_title,
     :x,
     :xguide,
     :xlims,
    # :xticks,
     :y,
     :yguide,
     :ylims,
    # :yrightlabel,
    # :yticks,
     :xscale,
     :yscale,
     :xflip,
     :yflip,
     :z,
     :zscale,
    # :tickfont,
    # :guidefont,
    # :legendfont,
     :grid,
    # :surface
    # :levels,
  ]
supportedAxes(::PGFPlotsBackend) = [:auto, :left]
supportedTypes(::PGFPlotsBackend) = [:path, :path3d, :scatter, :line, :steppre, :stepmid, :steppost, :hist, :bar, :hist2d, :sticks, :ysticks, :xsticks, :contour] #  :hexbin, :hline, :vline,]
supportedStyles(::PGFPlotsBackend) = [:auto, :solid, :dash, :dot, :dashdot, :dashdotdot]
supportedMarkers(::PGFPlotsBackend) = [:none, :auto, :ellipse, :rect, :diamond, :utriangle, :dtriangle, :cross, :xcross, :star5, :pentagon] #vcat(_allMarkers, Shape)
supportedScales(::PGFPlotsBackend) = [:identity, :log, :ln, :log2, :log10] # :asinh, :sqrt]
subplotSupported(::PGFPlotsBackend) = false


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
    :utriangle => "triangle*",
    :dtriangle => "triangle*",
    :ellipse => "o*",
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


# # function _pgfplots_get_color(kwargs, symb)
#     # c = typeof(kwargs[symb]) == Symbol ? convertColor(kwargs[symb]) : kwargs[symb].c
# function _pgfplots_get_color(c)
#     getColor(c)
#     # We need to convert to decimals here because pgfplot will error
#     # for colors in engineering notation
#     r_str =  @sprintf("%.8f", float(c.r))
#     g_str =  @sprintf("%.8f", float(c.g))
#     b_str =  @sprintf("%.8f", float(c.b))
#     "{rgb,1:red,$(r_str);green,$(g_str);blue,$(b_str)}"
# end

# # function _pgfplots_get_linestyle!(kwargs, plt)
# function _pgfplots_get_linestyle!(style, kw, d)
#     ls = d[:linestyle]
#     if haskey(_pgfplots_linestyles, ls)
#         push!(style, _pgfplots_linestyles[ls])
#     end
#
#     push!(style, "line width = $(d[:linewidth]) pt")
# end

# takes in color,alpha, and returns color and alpha appropriate for pgf style
function pgf_color(c, a = nothing)
    c = getColor(c)
    cstr = @sprintf("{rgb,1:red,%.8f;green,%.8f;blue,%.8f}", red(c), green(c), blue(c))
    a = float(a == nothing ? alpha(c) : a)
    cstr, a
end

function pgf_fillstyle(d::KW)
    cstr,a = pgf_color(d[:fillcolor], d[:fillalpha])
    "fill = $cstr, fill opacity=$a"
end

function pgf_linestyle(d::KW)
    cstr,a = pgf_color(d[:linecolor], d[:linealpha])
    """
    color = $cstr,
    draw opacity=$a,
    line width=$(d[:linewidth]),
    $(get(_pgfplots_linestyles, d[:linestyle], "solid"))
    """
end

function pgf_marker(d::KW)
    shape = d[:markershape]
    cstr, a = pgf_color(d[:markercolor], d[:markeralpha])
    cstr_stroke, a_stroke = pgf_color(d[:markerstrokecolor], d[:markerstrokealpha])
    """
    mark = $(get(_pgfplots_markers, shape, "o*")),
    mark size = $(0.5 * d[:markersize]),
    mark options = {
        color = $cstr_stroke, draw opacity = $a_stroke,
        fill = $cstr, fill opacity = $a,
        line width = $(d[:markerstrokewidth]),
        rotate = $(shape == :dtriangle ? 180 : 0),
        $(get(_pgfplots_linestyles, d[:markerstrokestyle], "solid"))
    }
    """
end


# # function _pgfplots_get_marker!(kwargs, plt)
# function _pgfplots_get_marker!(style, kw, d)
#     # Control marker shape, size, colors, alphas, and stroke width
#     mark = d[:markershape]
#     α = d[:markeralpha] == nothing ? 1.0 : d[:markeralpha]
#     push!(style, "mark = " * _pgfplots_markers[mark],
#                           "mark size = $(d[:markersize]/2)",
#                           "mark options = {color=$(_pgfplots_get_color(d[:markerstrokecolor]))",
#                           "fill=$(_pgfplots_get_color(d[:markercolor]))",
#                           "fill opacity = $α",
#                           "line width=$(d[:markerstrokewidth])")
#
#     # Rotate the marker if :dtriangle was chosen
#     mark == :dtriangle && push!(style, "rotate=180")
#
#     # Apply marker stroke style if it is a valid PGFPlots stroke style
#     if haskey(_pgfplots_linestyles, d[:markerstrokestyle])
#         push!(style, _pgfplots_linestyles[d[:markerstrokestyle]])
#     end
#
#     # End the open mark options bracker
#     push!(style, "}")
# end



# # function _pgfplots_get_series_color!(kwargs, plt)
# function _pgfplots_get_series_color!(style, kw, d)
#     c = getColor(d[:seriescolor])
#     α = d[:seriesalpha] == nothing ? 1.0 : d[:seriesalpha]
#     push!(style, "color=$(_pgfplots_get_color(d[:seriescolor]))",
#                           "draw opacity = $α")
# end
#
# # function _pgfplots_get_line_color!(kwargs, plt)
# function _pgfplots_get_line_color!(style, kw, d)
#     α = d[:linealpha] == nothing ? 1.0 : d[:linealpha]
#     style *= ", color=$(_pgfplots_get_color(d[:linecolor]))" *
#                       ", draw opacity = $α"
# end
#
# # function _pgfplots_get_fill_color!(kwargs, plt)
# function _pgfplots_get_fill_color!(style, kw, d)
#     α = d[:fillalpha] == nothing ? 1.0 : d[:fillalpha]
#     style *= ", fill=$(_pgfplots_get_color(d[:fillcolor]))" *
#                       ", fill opacity = $α"
# end

# # function _pgfplots_get_label!(kwargs, plt)
# function _pgfplots_get_label!(kw::KW, series::Series)
#     if d[:label] != nothing && d[:legend] != :none
#         kwargs[:legendentry] = d[:label]
#     end
# end

# --------------------------------------------------------------------------------------

# function _pgfplots_get_plot_kwargs(plt)
#     style = []
#     kw = KW()
#     # kw[:style] = []
#     _pgfplots_get_linestyle!(style, kw, plt)
#     _pgfplots_get_marker!(style, kw, plt)
#     _pgfplots_get_series_color!(style, kw, plt)
#     _pgfplots_get_label!(style, kw, plt)
#     kw[:style] = join(style, ',')
#     kw
# end


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
    if sp.attr[:legend] != :none && should_add_to_legend(series)
        kw[:legendentry] = d[:label]
    end

    # function args
    args = if st  == :contour
        d[:z].surf, d[:x], d[:y]
    elseif is3d(st)
        d[:x], d[:y], d[:z]
    else
        d[:x], d[:y]
    end

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
    elseif st == :hist2d
        PGFPlots.Histogram2
    elseif st == :contour
        PGFPlots.Contour
    else
        PGFPlots.Linear
    end
    func(args...; kw...)

    # # now return the series object
    # func, args = if st == :path
    #     PGFPlots.Linear, (d[:x], d[:y])
    # elseif st == :path3d
    #     PGFPlots.Linear3(d[:x], d[:y], d[:z]; kw...)
    # elseif st == :scatter
    #     PGFPlots.Scatter(d[:x], d[:y]; kw...)
    # elseif st == :steppre
    #     kw[:style] *= ", const plot mark right"
    #     PGFPlots.Linear(d[:x], d[:y]; kw...)
    # elseif st == :stepmid
    #     kw[:style] *= ", const plot mark mid"
    #     PGFPlots.Linear(d[:x], d[:y]; kw...)
    # elseif st == :steppost
    #     kw[:style] *= ", const plot"
    #     PGFPlots.Linear(d[:x], d[:y]; kw...)
    # # elseif st == :hist
    # #     #TODO patch this in PGFPlots.jl instead; the problem is that PGFPlots will
    # #     # save _all_ data points in the figure which can be quite heavy
    # #     plt_hist = hist(d[:y])
    # #     kw[:style] *= ", ybar interval"
    # #     _pgfplots_get_line_color!(kw, d)
    # #     _pgfplots_get_fill_color!(kw, d)
    # #     PGFPlots.Linear(plt_hist[1][1:end-1]+plt_hist[1].step/2, plt_hist[2]; kw...)
    # elseif st == :hist2d
    #     PGFPlots.Histogram2(d[:x], d[:y])
    # # elseif st == :bar
    # #     kw[:style] *= ", ybar"
    # #     _pgfplots_get_line_color!(kw, d)
    # #     _pgfplots_get_fill_color!(kw, d)
    # #     PGFPlots.Linear(d[:x], d[:y]; kw...)
    # elseif st == :sticks || st == :ysticks
    #     kw[:style] *= ", ycomb"
    #     PGFPlots.Linear(d[:x], d[:y]; kw...)
    # elseif st == :xsticks
    #     kw[:style] *= ", xcomb"
    #     PGFPlots.Linear(d[:x], d[:y]; kw...)
    # elseif st == :contour
    #     PGFPlots.Contour(d[:z].surf, d[:x], d[:y])
    # end


    # if st == :path
    #     PGFPlots.Linear(d[:x], d[:y]; kw...)
    # elseif st == :path3d
    #     PGFPlots.Linear3(d[:x], d[:y], d[:z]; kw...)
    # elseif st == :scatter
    #     PGFPlots.Scatter(d[:x], d[:y]; kw...)
    # elseif st == :steppre
    #     kw[:style] *= ", const plot mark right"
    #     PGFPlots.Linear(d[:x], d[:y]; kw...)
    # elseif st == :stepmid
    #     kw[:style] *= ", const plot mark mid"
    #     PGFPlots.Linear(d[:x], d[:y]; kw...)
    # elseif st == :steppost
    #     kw[:style] *= ", const plot"
    #     PGFPlots.Linear(d[:x], d[:y]; kw...)
    # elseif st == :hist
    #     #TODO patch this in PGFPlots.jl instead; the problem is that PGFPlots will
    #     # save _all_ data points in the figure which can be quite heavy
    #     plt_hist = hist(d[:y])
    #     kw[:style] *= ", ybar interval"
    #     _pgfplots_get_line_color!(kw, d)
    #     _pgfplots_get_fill_color!(kw, d)
    #     PGFPlots.Linear(plt_hist[1][1:end-1]+plt_hist[1].step/2, plt_hist[2]; kw...)
    # elseif st == :hist2d
    #     PGFPlots.Histogram2(d[:x], d[:y])
    # elseif st == :bar
    #     kw[:style] *= ", ybar"
    #     _pgfplots_get_line_color!(kw, d)
    #     _pgfplots_get_fill_color!(kw, d)
    #     PGFPlots.Linear(d[:x], d[:y]; kw...)
    # elseif st == :sticks || st == :ysticks
    #     kw[:style] *= ", ycomb"
    #     PGFPlots.Linear(d[:x], d[:y]; kw...)
    # elseif st == :xsticks
    #     kw[:style] *= ", xcomb"
    #     PGFPlots.Linear(d[:x], d[:y]; kw...)
    # elseif st == :contour
    #     PGFPlots.Contour(d[:z].surf, d[:x], d[:y])
    # end
end


# ----------------------------------------------------------------

function pgf_axis(sp::Subplot, letter)
    axis = sp.attr[symbol(letter,:axis)]
    style = []
    kw = KW()

    # axis guide
    kw[symbol(letter,:label)] = axis[:guide]

    # flip/reverse?
    axis[:flip] && push!(style, "$letter dir=reverse")

    # scale
    scale = axis[:scale]
    if scale in (:log2, :ln, :log10)
        kw[symbol(letter,:mode)] = "log"
        scale == :ln || push!(style, "log basis $letter=$(scale == :log2 ? 2 : 10)")
    end

    # limits
    lims = axis_limits(axis)
    kw[symbol(letter,:min)] = lims[1]
    kw[symbol(letter,:max)] = lims[2]

    # return the style list and KW args
    style, kw
end

# function _pgfplots_get_axis_kwargs(d)
#     axisargs = KW()
#     for arg in (:xguide, :yguide, :zguide, :title)
#         axisargs[arg] = d[arg]
#     end
#     axisargs[:style] = []
#     d[:xflip] == true && push!(axisargs[:style], "x dir=reverse")
#     d[:yflip] == true && push!(axisargs[:style], "y dir=reverse")
#     if d[:xscale] in (:log, :log2, :ln, :log10)
#         axisargs[:xmode] = "log"
#         if d[:xscale] == :log2
#             push!(axisargs[:style], "log basis x=2")
#         elseif d[:xscale] in (:log, :log10)
#             push!(axisargs[:style], "log basis x=10")
#         end
#     end
#     if d[:yscale] in (:log, :log2, :ln, :log10)
#         axisargs[:ymode] = "log"
#         if d[:yscale] == :log2
#             push!(axisargs[:style], "log basis y=2")
#         elseif d[:yscale] in (:log, :log10)
#             push!(axisargs[:style], "log basis x=10")
#         end
#     end
#     if d[:zscale] in (:log, :log2, :ln, :log10)
#         axisargs[:zmode] = "log"
#         if d[:zscale] == :log2
#             push!(axisargs[:style], "log basis z=2")
#         elseif d[:zscale] in (:log, :log10)
#             push!(axisargs[:style], "log basis x=10")
#         end
#     end
#
#     # Control background color
#     push!(axisargs[:style], "axis background/.style={fill=$(_pgfplots_get_color(d, :background_color))}")
#     # Control x/y-limits
#     if d[:xlims] !== :auto
#         axisargs[:xmin] = d[:xlims][1]
#         axisargs[:xmax] = d[:xlims][2]
#     end
#     if d[:ylims] !== :auto
#         axisargs[:ymin] = d[:ylims][1]
#         axisargs[:ymax] = d[:ylims][2]
#     end
#
#     d[:grid] == true && push!(axisargs[:style], "grid = major")
#
#     if d[:aspect_ratio] == :equal || d[:aspect_ratio] == 1
#         axisargs[:axisEqual] = "true"
#     end
#
#     if ((d[:legend] != :none) || (d[:legend] != :best)) && (d[:legend] in keys(_pgfplots_legend_pos))
#         axisargs[:legendPos] = _pgfplots_legend_pos[d[:legend]]
#     end
#     axisargs[:style] = join(axisargs[:style], ',')
#     axisargs
# end

# ----------------------------------------------------------------

# #################  This is the important method to implement!!! #################
# function _make_pgf_plot(plt::Plot{PGFPlotsBackend})
#     os = Any[]
#     # We need to send the :legend KW to the axis
#     for plt_series in plt.seriesargs
#         plt_series[:legend] = plt.attr[:legend]
#         push!(os, _pgfplots_axis(plt_series))
#     end
#     axisargs  =_pgfplots_get_axis_kwargs(plt.attr)
#     w, h = map(px2mm, plt.attr[:size])
#     plt.o = PGFPlots.Axis([os...]; width = "$w mm", height = "$h mm", axisargs...)
# end

function _make_pgf_plot!(plt::Plot)
    plt.o = PGFPlots.Axis[]
    for sp in plt.subplots
        # first build the PGFPlots.Axis object
        style = []
        kw = KW()

        # add to style/kw for each axis
        for letter in (:x, :y, :z)
            if letter != :z || is3d(sp)
                axisstyle, axiskw = pgf_axis(sp, letter)
                merge!(kw, axiskw)
            end
        end

        # bounding box values are in mm
        # note: bb origin is top-left, pgf is bottom-left
        bb = bbox(sp)
        push!(style, """
            xshift = $(left(bb).value)mm,
            yshift = $((height(bb) - (bottom(bb))).value)mm,
            width = $(width(bb).value)mm,
            height = $(height(bb).value)mm,
            axis background/.style={fill=$(pgf_color(sp.attr[:background_color_inside])[1])}
        """)

        if sp.attr[:title] != ""
            push!(style, "title = $(sp.attr[:title])")
        end

        sp.attr[:grid] && push!(style, "grid = major")
        if sp.attr[:aspect_ratio] in (1, :equal)
            kw[:axisEqual] = "true"
        end

        legpos = sp.attr[:legend]
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


function _writemime(io::IO, mime::MIME"image/svg+xml", plt::Plot{PGFPlotsBackend})
  _make_pgf_plot!(plt)
  writemime(io, mime, plt.o)
end

function _writemime(io::IO, mime::MIME"image/png", plt::Plot{PGFPlotsBackend})
  _make_pgf_plot!(plt)
  writemime(io, mime, plt.o)
end

function _display(plt::Plot{PGFPlotsBackend})
  _make_pgf_plot!(plt)
  display(plt.o)
end
