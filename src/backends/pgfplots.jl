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
    # :markerstrokewidth,
     :markerstrokecolor,
     :markerstrokestyle,
    # :n,
    # :bins,
    # :nc,
    # :nr,
    # :pos,
    # :smooth,
    # :show,
    # :size,
     :title,
    # :windowtitle,
     :x,
     :xlabel,
     :xlims,
    # :xticks,
     :y,
     :ylabel,
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
    # TODO: other initialization that needs to be eval-ed
  end
  # TODO: other initialization
end
const _pgfplots_linestyles = KW(
    :solid => "solid",
    :dash => "dashed",
    :dot => "dotted",
    :dashdot => "dashdotted",
    :dashdotdot => "dashdotdotted"
)

const _pgfplots_markers = KW(
    :none => "mark = none,",
    :cross => "mark = +,",
    :xcross => "mark = x,",
    :utriangle => "mark = triangle*,",
    :dtriangle => "mark = triangle*,",
    :ellipse => "mark = o*,",
    :rect => "mark = square*,",
    :star5 => "mark = star,",
    :star6 => "mark = asterisk,",
    :diamond => "mark = diamond*,",
    :pentagon => "mark = pentagon*,"
)

const _pgfplots_legend_pos = KW(
    :bottomleft => "south west",
    :bottomright => "south east",
    :topright => "north east",
    :topleft => "north west"
)

function _pgfplots_get_color(kwargs, symb)
    c = typeof(kwargs[symb]) == Symbol ? convertColor(kwargs[symb]) : kwargs[symb].c
    # We need to convert to decimals here because pgfplot will error
    # for colors in engineering notation
    r_str =  @sprintf("%.8f", float(c.r))
    g_str =  @sprintf("%.8f", float(c.g))
    b_str =  @sprintf("%.8f", float(c.b))
    "{rgb,1:red,$(r_str);green,$(g_str);blue,$(b_str)}"
end

function _pgfplots_get_linestyle!(kwargs, plt)
    ls = plt[:linestyle]
    if haskey(_pgfplots_linestyles, ls)
        kwargs[:style] *= _pgfplots_linestyles[ls]*","
    end

    kwargs[:style] *= "line width = $(plt[:linewidth]) pt"*","
end


function _pgfplots_get_marker!(kwargs, plt)
    # Control marker shape
    mark = plt[:markershape]
    kwargs[:style] *= _pgfplots_markers[mark]

    # Control marker size
    kwargs[:style] *= "mark size = $(plt[:markersize]/2),"

    # Control marker colors and alphas
    α = plt[:markeralpha] == nothing ? 1.0 : plt[:markeralpha]
    kwargs[:style] *= "mark options = {color=$(_pgfplots_get_color(plt, :markerstrokecolor)),"
    kwargs[:style] *= mark == :dtriangle ? "rotate=180," : ""
    kwargs[:style] *= "fill=$(_pgfplots_get_color(plt, :markercolor)),"
    kwargs[:style] *= "fill opacity = $α,"
    markstrokestyle = plt[:markerstrokestyle]
    if haskey(_pgfplots_linestyles, markstrokestyle)
        kwargs[:style] *= _pgfplots_linestyles[markstrokestyle]
    end
    kwargs[:style] *= "},"
end

function _pgfplots_get_series_color!(kwargs, plt)
    α = plt[:seriesalpha] == nothing ? 1.0 : plt[:seriesalpha]
    kwargs[:style] *= "color=$(_pgfplots_get_color(plt, :seriescolor)),"
    kwargs[:style] *= "draw opacity = $α,"
end

function _pgfplots_get_line_color!(kwargs, plt)
    α = plt[:linealpha] == nothing ? 1.0 : plt[:linealpha]
    kwargs[:style] *= "color=$(_pgfplots_get_color(plt, :linecolor)),"
    kwargs[:style] *= "draw opacity = $α,"
end

function _pgfplots_get_fill_color!(kwargs, plt)
    α = plt[:fillalpha] == nothing ? 1.0 : plt[:fillalpha]
    kwargs[:style] *= "fill=$(_pgfplots_get_color(plt, :fillcolor)),"
    kwargs[:style] *= "fill opacity = $α,"
end

function _pgfplots_get_label!(kwargs, plt)
    if plt[:label] != nothing && plt[:legend] != :none
        kwargs[:legendentry] = plt[:label]
    end
end


function _pgfplots_get_plot_kwargs(plt)
    kwargs = KW()
    kwargs[:style] = ""
    _pgfplots_get_linestyle!(kwargs, plt)
    _pgfplots_get_marker!(kwargs, plt)
    _pgfplots_get_series_color!(kwargs, plt)
    _pgfplots_get_label!(kwargs, plt)
    kwargs
end

function _pgfplots_axis(plt_series)
    line_type = plt_series[:seriestype]
    plt_kwargs = _pgfplots_get_plot_kwargs(plt_series)
        if line_type == :path
        PGFPlots.Linear(plt_series[:x], plt_series[:y]; plt_kwargs...)
    elseif line_type == :path3d
        PGFPlots.Linear3(plt_series[:x], plt_series[:y], plt_series[:z]; plt_kwargs...)
    elseif line_type == :scatter
        PGFPlots.Scatter(plt_series[:x], plt_series[:y]; plt_kwargs...)
    elseif line_type == :steppre
        plt_kwargs[:style] *= "const plot mark right,"
        PGFPlots.Linear(plt_series[:x], plt_series[:y]; plt_kwargs...)
    elseif line_type == :stepmid
        plt_kwargs[:style] *= "const plot mark mid,"
        PGFPlots.Linear(plt_series[:x], plt_series[:y]; plt_kwargs...)
    elseif line_type == :steppost
        plt_kwargs[:style] *= "const plot,"
        PGFPlots.Linear(plt_series[:x], plt_series[:y]; plt_kwargs...)
    elseif line_type == :hist
        #TODO patch this in PGFPlots.jl instead; the problem is that PGFPlots will
        # save _all_ data points in the figure which can be quite heavy
        plt_hist = hist(plt_series[:y])
        plt_kwargs[:style] *= "ybar interval,"
        _pgfplots_get_line_color!(plt_kwargs, plt_series)
        _pgfplots_get_fill_color!(plt_kwargs, plt_series)
        PGFPlots.Linear(plt_hist[1][1:end-1]+plt_hist[1].step/2, plt_hist[2]; plt_kwargs...)
    elseif line_type == :hist2d
        PGFPlots.Histogram2(plt_series[:x], plt_series[:y])
    elseif line_type == :bar
        plt_kwargs[:style] *= "ybar,"
        _pgfplots_get_line_color!(plt_kwargs, plt_series)
        _pgfplots_get_fill_color!(plt_kwargs, plt_series)
        PGFPlots.Linear(plt_series[:x], plt_series[:y]; plt_kwargs...)
    elseif line_type == :sticks || line_type == :ysticks
        plt_kwargs[:style] *= "ycomb"
        PGFPlots.Linear(plt_series[:x], plt_series[:y]; plt_kwargs...)
    elseif line_type == :xsticks
        plt_kwargs[:style] *= "xcomb"
        PGFPlots.Linear(plt_series[:x], plt_series[:y]; plt_kwargs...)
    elseif line_type == :contour
        PGFPlots.Contour(plt_series[:z].surf, plt_series[:x], plt_series[:y])
    end
end

# ---------------------------------------------------------------------------

# function _create_plot(pkg::PGFPlotsBackend, d::KW)
#   # TODO: create the window/canvas/context that is the plot within the backend (call it `o`)
#   # TODO: initialize the plot... title, xlabel, bgcolor, etc
#   Plot(nothing, pkg, 0, d, KW[])
# end


# function _add_series(::PGFPlotsBackend, plt::Plot, d::KW)
#   # TODO: add one series to the underlying package
#   push!(plt.seriesargs, d)
#   plt
# end

function _add_annotations{X,Y,V}(plt::Plot{PGFPlotsBackend}, anns::AVec{@compat(Tuple{X,Y,V})})
  # set or add to the annotation_list
  if haskey(plt.plotargs, :annotation_list)
    append!(plt.plotargs[:annotation_list], anns)
  else
    plt.plotargs[:annotation_list] = anns
  end
end

# ----------------------------------------------------------------

# function _before_update_plot(plt::Plot{PGFPlotsBackend})
# end

# TODO: override this to update plot items (title, xlabel, etc) after creation
function _update_plot(plt::Plot{PGFPlotsBackend}, d::KW)
end

# function _update_plot_pos_size(plt::AbstractPlot{PGFPlotsBackend}, d::KW)
# end

# ----------------------------------------------------------------

# accessors for x/y data

# function getxy(plt::Plot{PGFPlotsBackend}, i::Int)
#   d = plt.seriesargs[i]
#   d[:x], d[:y]
# end
#
# function setxy!{X,Y}(plt::Plot{PGFPlotsBackend}, xy::Tuple{X,Y}, i::Integer)
#   d = plt.seriesargs[i]
#   d[:x], d[:y] = xy
#   plt
# end

# ----------------------------------------------------------------

# function _create_subplot(subplt::Subplot{PGFPlotsBackend}, isbefore::Bool)
#   # TODO: build the underlying Subplot object.  this is where you might layout the panes within a GUI window, for example
#   true
# end

# function _expand_limits(lims, plt::Plot{PGFPlotsBackend}, isx::Bool)
#   # TODO: call expand limits for each plot data
# end
#
# function _remove_axis(plt::Plot{PGFPlotsBackend}, isx::Bool)
#   # TODO: if plot is inner subplot, might need to remove ticks or axis labels
# end

# ----------------------------------------------------------------

function _pgfplots_get_axis_kwargs(d)
    axisargs = KW()
    for arg in (:xlabel, :ylabel, :zlabel, :title)
        axisargs[arg] = d[arg]
    end
    axisargs[:style] = ""
    axisargs[:style] *= d[:xflip] == true ? "x dir=reverse," : ""
    axisargs[:style] *= d[:yflip] == true ? "y dir=reverse," : ""
    if d[:xscale] in (:log, :log2, :ln, :log10)
        axisargs[:xmode] = "log"
        if d[:xscale] == :log2
            axisargs[:style] *= "log basis x=2,"
        elseif d[:xscale] in (:log, :log10)
            axisargs[:style] *= "log basis x=10,"
        end
    end
    if d[:yscale] in (:log, :log2, :ln, :log10)
        axisargs[:ymode] = "log"
        if d[:yscale] == :log2
            axisargs[:style] *= "log basis y=2,"
        elseif d[:yscale] in (:log, :log10)
            axisargs[:style] *= "log basis x=10,"
        end
    end
    if d[:zscale] in (:log, :log2, :ln, :log10)
        axisargs[:zmode] = "log"
        if d[:zscale] == :log2
            axisargs[:style] *= "log basis z=2,"
        elseif d[:zscale] in (:log, :log10)
            axisargs[:style] *= "log basis x=10,"
        end
    end

    # Control background color
    axisargs[:style] *= "axis background/.style={fill=$(_pgfplots_get_color(d, :background_color))},"
    # Control x/y-limits
    if d[:xlims] !== :auto
        axisargs[:xmin] = d[:xlims][1]
        axisargs[:xmax] = d[:xlims][2]
    end
    if d[:ylims] !== :auto
        axisargs[:ymin] = d[:ylims][1]
        axisargs[:ymax] = d[:ylims][2]
    end
    if d[:grid] == true
        axisargs[:style] *= "grid = major,"
    elseif d[:grid] == false

    end

    if d[:aspect_ratio] == :equal || d[:aspect_ratio] == 1
        axisargs[:axisEqual] = "true"
    end

    if ((d[:legend] != :none) || (d[:legend] != :best)) && (d[:legend] in keys(_pgfplots_legend_pos))
        axisargs[:legendPos] = _pgfplots_legend_pos[d[:legend]]
    end
    axisargs
end

# ----------------------------------------------------------------

#################  This is the important method to implement!!! #################
function _make_pgf_plot(plt::Plot{PGFPlotsBackend})
    os = Any[]
    # We need to send the :legend KW to the axis
    for plt_series in plt.seriesargs
        plt_series[:legend] = plt.plotargs[:legend]
        push!(os, _pgfplots_axis(plt_series))
    end
    axisargs  =_pgfplots_get_axis_kwargs(plt.plotargs)
    plt.o = PGFPlots.Axis([os...]; axisargs...)
end

function Base.writemime(io::IO, mime::MIME"image/svg+xml", plt::AbstractPlot{PGFPlotsBackend})
  plt.o = _make_pgf_plot(plt)
  writemime(io, mime, plt.o)
end

# function Base.writemime(io::IO, ::MIME"text/html", plt::AbstractPlot{PGFPlotsBackend})
# end

function Base.display(::PlotsDisplay, plt::AbstractPlot{PGFPlotsBackend})
  plt.o = _make_pgf_plot(plt)
  display(plt.o)
end

# function Base.display(::PlotsDisplay, plt::Subplot{PGFPlotsBackend})
#   # TODO: display/show the subplot
# end
