# https://github.com/sisl/PGFPlots.jl

function _initialize_backend(::PGFPlotsBackend; kw...)
  @eval begin
    import PGFPlots
    export PGFPlots
    # TODO: other initialization that needs to be eval-ed
  end
  # TODO: other initialization
end

_pgfplots_get_color(c) = "{rgb,1:red,$(float(c.r));green,$(float(c.g));blue,$(float(c.b))}"

function _pgfplots_get_linestyle!(kwargs, plt)
    linestyle = plt[:linestyle]
    if linestyle == :dash
        kwargs[:style] *= "dashed,"
    elseif linestyle == :dot
        kwargs[:style] *= "dotted,"
    elseif linestyle == :dashdot
        kwargs[:style] *= "dashdotted,"
    elseif linestyle == :dashdotdot
        kwargs[:style] *= "dashdotdotted,"
    end

    kwargs[:style] *= (haskey(plt, :linewidth) && plt[:linewidth] != :auto) ? "line width = $(plt[:linewidth]) pt," : "line width = 1 pt,"
end


function _pgfplots_get_marker!(kwargs, plt)
    # Control marker shape
    mark = plt[:markershape]
    if mark in (:none,:n, :no)
        kwargs[:style] *= "mark = none,"
    elseif mark in (:auto, :a)
        kwargs[:style] *= "mark = *,"
    elseif mark in (:cross, :+, :plus)
        kwargs[:style] *= "mark = +,"
    elseif mark in (:xcross ,:X, :x)
        kwargs[:style] *= "mark = x,"
    elseif mark in (:utriangle, :^, :uptri, :uptriangle, :ut, :utri,
                    :dtriangle, :V, :downtri, :downtriangle, :dt ,:dtri, :v)
        kwargs[:style] *= "mark = triangle*,"
    elseif mark in (:ellipse, :c, :circle)
        kwargs[:style] *= "mark = o*,"
    elseif mark in  (:rect 	,:r, :sq, :square)
        kwargs[:style] *= "mark = square*,"
    elseif mark in (:star5 	,:s, :star, :star1)
        kwargs[:style] *= "mark = star,"
    elseif mark in (:star6,)
        kwargs[:style] *= "mark = asterisk,"
    elseif mark in (:diamond, :d)
        kwargs[:style] *= "mark = diamond*,"
    elseif mark in (:pentagon ,:p, :pent)
        kwargs[:style] *= "mark = pentagon*,"
    end

    # Control marker size
    kwargs[:style] *= "mark size = $(plt[:markersize]/2),"

    # Control marker colors and alphas
    marker_fill = plt[:markercolor].c
    α = plt[:markeralpha] == nothing ? 1.0 : plt[:markeralpha]
    marker_stroke = plt[:markerstrokecolor].c
    kwargs[:style] *= "mark options = {color="*_pgfplots_get_color(marker_stroke)*","
    kwargs[:style] *= mark in (:dtriangle, :V, :downtri, :downtriangle, :dt ,:dtri, :v) ? "rotate=180," : ""
    kwargs[:style] *= "fill="*_pgfplots_get_color(marker_fill)*","
    kwargs[:style] *= "fill opacity = $α,"
    markerstrokestyle = plt[:markerstrokestyle]
    if markerstrokestyle == :solid
        kwargs[:style] *= "solid,"
    elseif markerstrokestyle == :dash
        kwargs[:style] *= "dashed,"
    elseif markerstrokestyle == :dot
        kwargs[:style] *= "dotted,"
    elseif markerstrokestyle == :dashdot
        kwargs[:style] *= "dashdotted,"
    elseif markerstrokestyle == :dashdotdot
        kwargs[:style] *= "dashdotdotted,"
    end
    kwargs[:style] *= "},"
end

function _pgfplots_get_series_color!(kwargs, plt)
    color = plt[:seriescolor].c
    α = plt[:seriesalpha] == nothing ? 1.0 : plt[:seriesalpha]
    kwargs[:style] *= "color="*_pgfplots_get_color(color)*","
    kwargs[:style] *= "draw opacity = $α,"
end

function _pgfplots_get_plot_kwargs(plt)
    kwargs = KW()
    kwargs[:style] = ""
    _pgfplots_get_linestyle!(kwargs, plt)
    _pgfplots_get_marker!(kwargs, plt)
    _pgfplots_get_series_color!(kwargs, plt)
    kwargs
end

function _pgfplots_axis(plt_series)
    line_type = plt_series[:linetype]
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
        plt_kwargs[:style] *= "ybar interval, mark = none"
        PGFPlots.Linear(plt_hist[1][1:end-1]+plt_hist[1].step/2, plt_hist[2]; plt_kwargs...)
    elseif line_type == :hist2d
        PGFPlots.Histogram2(plt_series[:x], plt_series[:y])
    elseif line_type == :bar
        plt_kwargs[:style] *= "ybar, mark = none"
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

function _create_plot(pkg::PGFPlotsBackend, d::KW)
  # TODO: create the window/canvas/context that is the plot within the backend (call it `o`)
  # TODO: initialize the plot... title, xlabel, bgcolor, etc
  Plot(nothing, pkg, 0, d, KW[])
end


function _add_series(::PGFPlotsBackend, plt::Plot, d::KW)
  # TODO: add one series to the underlying package
  push!(plt.seriesargs, d)
  plt
end

function _add_annotations{X,Y,V}(plt::Plot{PGFPlotsBackend}, anns::AVec{@compat(Tuple{X,Y,V})})
  # set or add to the annotation_list
  if haskey(plt.plotargs, :annotation_list)
    append!(plt.plotargs[:annotation_list], anns)
  else
    plt.plotargs[:annotation_list] = anns
  end
end

# ----------------------------------------------------------------

function _before_update_plot(plt::Plot{PGFPlotsBackend})
end

# TODO: override this to update plot items (title, xlabel, etc) after creation
function _update_plot(plt::Plot{PGFPlotsBackend}, d::KW)
end

function _update_plot_pos_size(plt::AbstractPlot{PGFPlotsBackend}, d::KW)
end

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

function _create_subplot(subplt::Subplot{PGFPlotsBackend}, isbefore::Bool)
  # TODO: build the underlying Subplot object.  this is where you might layout the panes within a GUI window, for example
  true
end

function _expand_limits(lims, plt::Plot{PGFPlotsBackend}, isx::Bool)
  # TODO: call expand limits for each plot data
end

function _remove_axis(plt::Plot{PGFPlotsBackend}, isx::Bool)
  # TODO: if plot is inner subplot, might need to remove ticks or axis labels
end

# ----------------------------------------------------------------

function _pgfplots_get_axis_kwargs(d)
    axisargs = KW()
    axisargs[:style] = "{"
    for arg in (:xlabel, :ylabel, :zlabel, :title)
        axisargs[arg] = d[arg]
    end
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
    axisargs[:style] *= "},"

    # Control background color
    bg_color = d[:background_color].c
    axisargs[:style] *= "axis background/.style={fill={rgb,1:red,$(float(bg_color.r));green,$(float(bg_color.g));blue,$(float(bg_color.b))},}"

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
        axisargs[:style] = "grid = major"
    elseif d[:grid] == false

    end
    axisargs
end

# ----------------------------------------------------------------

#################  This is the important method to implement!!! #################
function _make_pgf_plot(plt::Plot{PGFPlotsBackend})
    os = [_pgfplots_axis(plt_series) for plt_series in plt.seriesargs]
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
