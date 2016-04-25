
# https://github.com/stevengj/PyPlot.jl

function _initialize_backend(::PyPlotBackend)
    @eval begin
        import PyPlot
        export PyPlot
        const pycolors = PyPlot.pywrap(PyPlot.pyimport("matplotlib.colors"))
        const pypath = PyPlot.pywrap(PyPlot.pyimport("matplotlib.path"))
        const mplot3d = PyPlot.pywrap(PyPlot.pyimport("mpl_toolkits.mplot3d"))
        const pypatches = PyPlot.pywrap(PyPlot.pyimport("matplotlib.patches"))
        # const pycolorbar = PyPlot.pywrap(PyPlot.pyimport("matplotlib.colorbar"))
    end

    if !isa(Base.Multimedia.displays[end], Base.REPL.REPLDisplay)
        PyPlot.ioff()  # stops wierd behavior of displaying incomplete graphs in IJulia

        # # TODO: how the hell can I use PyQt4??
        # "pyqt4"=>:qt_pyqt4
        # PyPlot.backend[1] = "pyqt4"
        # PyPlot.gui[1] = :qt_pyqt4
        # PyPlot.switch_backend("Qt4Agg")

        # only turn on the gui if we want it
        if PyPlot.gui != :none
            PyPlot.pygui(true)
        end
    end
end

# -------------------------------

# convert colorant to 4-tuple RGBA
getPyPlotColor(c::Colorant, α=nothing) = map(f->float(f(convertColor(c,α))), (red, green, blue, alpha))
getPyPlotColor(cvec::ColorVector, α=nothing) = map(getPyPlotColor, convertColor(cvec, α).v)
getPyPlotColor(scheme::ColorScheme, α=nothing) = getPyPlotColor(convertColor(getColor(scheme), α))
getPyPlotColor(c, α=nothing) = getPyPlotColor(convertColor(c, α))

function getPyPlotColorMap(c::ColorGradient, α=nothing)
    pyvals = [(v, getPyPlotColor(getColorZ(c, v), α)) for v in c.values]
    pycolors.pymember("LinearSegmentedColormap")[:from_list]("tmp", pyvals)
end

# anything else just gets a bluesred gradient
getPyPlotColorMap(c, α=nothing) = getPyPlotColorMap(default_gradient(), α)

# get the style (solid, dashed, etc)
function getPyPlotLineStyle(linetype::Symbol, linestyle::Symbol)
    linetype == :none && return " "
    linestyle == :solid && return "-"
    linestyle == :dash && return "--"
    linestyle == :dot && return ":"
    linestyle == :dashdot && return "-."
    warn("Unknown linestyle $linestyle")
    return "-"
end

function getPyPlotMarker(marker::Shape)
    n = length(marker.vertices)
    mat = zeros(n+1,2)
    for (i,vert) in enumerate(marker.vertices)
        mat[i,1] = vert[1]
        mat[i,2] = vert[2]
    end
    mat[n+1,:] = mat[1,:]
    pypath.pymember("Path")(mat)
end

const _path_MOVETO = UInt8(1)
const _path_LINETO = UInt8(2)
const _path_CLOSEPOLY = UInt8(79)

# see http://matplotlib.org/users/path_tutorial.html
# and http://matplotlib.org/api/path_api.html#matplotlib.path.Path
function buildPyPlotPath(x, y)
    n = length(x)
    mat = zeros(n, 2)
    codes = zeros(UInt8, n)
    lastnan = true
    for i=1:n
        mat[i,1] = x[i]
        mat[i,2] = y[i]
        nan = !isfinite(x[i]) || !isfinite(y[i])
        codes[i] = if nan
            _path_CLOSEPOLY
        else
            lastnan ? _path_MOVETO : _path_LINETO
        end
        lastnan = nan
    end
    pypath.pymember("Path")(mat, codes)
end

# get the marker shape
function getPyPlotMarker(marker::Symbol)
    marker == :none && return " "
    marker == :ellipse && return "o"
    marker == :rect && return "s"
    marker == :diamond && return "D"
    marker == :utriangle && return "^"
    marker == :dtriangle && return "v"
    marker == :cross && return "+"
    marker == :xcross && return "x"
    marker == :star5 && return "*"
    marker == :pentagon && return "p"
    marker == :hexagon && return "h"
    marker == :octagon && return "8"
    haskey(_shapes, marker) && return getPyPlotMarker(_shapes[marker])

    warn("Unknown marker $marker")
    return "o"
end

# getPyPlotMarker(markers::AVec) = map(getPyPlotMarker, markers)
function getPyPlotMarker(markers::AVec)
    warn("Vectors of markers are currently unsupported in PyPlot: $markers")
    getPyPlotMarker(markers[1])
end

# pass through
function getPyPlotMarker(marker::AbstractString)
    @assert length(marker) == 1
    marker
end

function getPyPlotStepStyle(linetype::Symbol)
    linetype == :steppost && return "steps-post"
    linetype == :steppre && return "steps-pre"
    return "default"
end

# ---------------------------------------------------------------------------

type PyPlotAxisWrapper
    ax
    rightax
    fig
    kwargs  # for add_subplot
end

getfig(wrap::PyPlotAxisWrapper) = wrap.fig



# get a reference to the correct axis
function getLeftAxis(wrap::PyPlotAxisWrapper)
    if wrap.ax == nothing
        axes = wrap.fig.o[:axes]
        if isempty(axes)
            return wrap.fig.o[:add_subplot](111; wrap.kwargs...)
        end
        axes[1]
    else
        wrap.ax
    end
end

function getRightAxis(wrap::PyPlotAxisWrapper)
    if wrap.rightax == nothing
        wrap.rightax = getLeftAxis(wrap)[:twinx]()
    end
    wrap.rightax
end

getLeftAxis(plt::Plot{PyPlotBackend}) = getLeftAxis(plt.o)
getRightAxis(plt::Plot{PyPlotBackend}) = getRightAxis(plt.o)
getAxis(plt::Plot{PyPlotBackend}, axis::Symbol) = (axis == :right ? getRightAxis : getLeftAxis)(plt)

# left axis is PyPlot.<func>, right axis is "f.axes[0].twinx().<func>"
function getPyPlotFunction(plt::Plot, axis::Symbol, linetype::Symbol)
    # # need to access mplot3d functions differently
    # if linetype == :surface
    #   return mplot3d.pymember("Axes3D")[:plot_surface]
    # end

    # in the 2-axis case we need to get: <rightaxis>[:<func>]
    ax = getAxis(plt, axis)
    # ax[:set_ylabel](plt.plotargs[:yrightlabel])
    fmap = KW(
        :hist       => :hist,
        :density    => :hist,
        :sticks     => :bar,
        :bar        => :bar,
        :hist2d     => :hexbin,
        :hexbin     => :hexbin,
        :scatter    => :scatter,
        :contour    => :contour,
        :scatter3d  => :scatter,
        :surface    => :plot_surface,
        :wireframe  => :plot_wireframe,
        :heatmap    => :pcolor,
        :shape      => :add_patch,
        # :surface    => pycolors.pymember("LinearSegmentedColormap")[:from_list]
    )
    return ax[get(fmap, linetype, :plot)]
end


function handleSmooth(plt::Plot{PyPlotBackend}, ax, d::KW, smooth::Bool)
    if smooth
        xs, ys = regressionXY(d[:x], d[:y])
        ax[:plot](xs, ys,
                  # linestyle = getPyPlotLineStyle(:path, :dashdot),
                  color = getPyPlotColor(d[:linecolor]),
                  linewidth = 2
                 )
    end
end
handleSmooth(plt::Plot{PyPlotBackend}, ax, d::KW, smooth::Real) = handleSmooth(plt, ax, d, true)

# ---------------------------------------------------------------------------

makePyPlotCurrent(wrap::PyPlotAxisWrapper) = wrap.ax == nothing ? PyPlot.figure(wrap.fig.o[:number]) : nothing
makePyPlotCurrent(plt::Plot{PyPlotBackend}) = plt.o == nothing ? nothing : makePyPlotCurrent(plt.o)


function _before_add_series(plt::Plot{PyPlotBackend})
    makePyPlotCurrent(plt)
end


# ------------------------------------------------------------------

function pyplot_figure(plotargs::KW)
    w,h = map(px2inch, plotargs[:size])
    # bgcolor = getPyPlotColor(plotargs[:background_color])


    # reuse the current figure?
    fig = if plotargs[:overwrite_figure]
        PyPlot.gcf()
    else
        PyPlot.figure()
    end

    # update the specs
    # fig[:set_size_inches](w,h, (isijulia() ? [] : [true])...)
    fig[:set_size_inches](w, h, forward = true)
    # fig[:set_facecolor](bgcolor)
    fig[:set_facecolor](getPyPlotColor(plotargs[:background_color_outside]))
    fig[:set_dpi](DPI)
    fig[:set_tight_layout](true)

    # clear the figure
    PyPlot.clf()

    # resize the window
    PyPlot.plt[:get_current_fig_manager]()[:resize](plotargs[:size]...)
    fig
end

function pyplot_3d_setup!(wrap, d)
    # 3D?
    # if haskey(d, :linetype) && first(d[:linetype]) in _3dTypes # && isa(plt.o, PyPlotFigWrapper)
    if trueOrAllTrue(lt -> lt in _3dTypes, get(d, :linetype, :none))
        push!(wrap.kwargs, (:projection, "3d"))
    end
end

# ---------------------------------------------------------------------------

function _create_plot(pkg::PyPlotBackend, d::KW)
    # create the figure
    # standalone plots will create a figure, but not if part of a subplot (do it later)
    if haskey(d, :subplot)
        wrap = nothing
    else
        wrap = PyPlotAxisWrapper(nothing, nothing, pyplot_figure(d), [])
        # wrap = PyPlotAxisWrapper(nothing, nothing, PyPlot.figure(; figsize = (w,h), facecolor = bgcolor, dpi = DPI, tight_layout = true), [])

        # if haskey(d, :linetype) && first(d[:linetype]) in _3dTypes # && isa(plt.o, PyPlotFigWrapper)
        #   push!(wrap.kwargs, (:projection, "3d"))
        # end
        pyplot_3d_setup!(wrap, d)

        if get(d, :polar, false)
            push!(wrap.kwargs, (:polar, true))
        end
    end

    plt = Plot(wrap, pkg, 0, d, KW[])
    plt
end

# ---------------------------------------------------------------------------

function fix_xy_lengths!(plt::Plot{PyPlotBackend}, d::KW)
    x, y = d[:x], d[:y]
    nx, ny = length(x), length(y)
    if !isa(get(d, :z, nothing), Surface) && nx != ny
        if nx < ny
            d[:x] = Float64[x[mod1(i,nx)] for i=1:ny]
        else
            d[:y] = Float64[y[mod1(i,ny)] for i=1:nx]
        end
    end
end

# # figure out the extra kw from zcolor in scatter and scatter3d
# function get_extra_kw(plt::Plot{PyPlotBackend}, d::KW)
#     extra_kw = KW()
#     if d[:linetype] in (:scatter, :scatter3d)
#         c = getPyPlotColor(d[:markercolor])
#         if d[:marker_z] == nothing
#             c = getPyPlotColor(c, d[:markeralpha])
#
#             # total hack due to PyPlot bug (see issue #145).
#             # hack: duplicate the color vector when the total rgba fields is the same as the series length
#             if (typeof(c) <: AbstractArray && length(c)*4 == length(x)) || (typeof(c) <: Tuple && length(x) == 4)
#                 c = vcat(c, c)
#             end
#             extra_kw[:c] = c
#         else
#             if !isa(c, ColorGradient)
#                 c = default_gradient()
#             end
#             extra_kw[:c] = convert(Vector{Float64}, d[:marker_z])
#             extra_kw[:cmap] = getPyPlotColorMap(c, d[:markeralpha])
#         end
#     end
#     extra_kw
# end
#
# function get_cmap(plt::Plot{PyPlotBackend}, d::KW)
#
# end

# total hack due to PyPlot bug (see issue #145).
# hack: duplicate the color vector when the total rgba fields is the same as the series length
function color_fix(c, x)
    if (typeof(c) <: AbstractArray && length(c)*4 == length(x)) ||
                    (typeof(c) <: Tuple && length(x) == 4)
        vcat(c, c)
    else
        c
    end
end

pylinecolor(d::KW)          = getPyPlotColor(d[:linecolor], d[:linealpha])
pymarkercolor(d::KW)        = getPyPlotColor(d[:markercolor], d[:markeralpha])
pymarkerstrokecolor(d::KW)  = getPyPlotColor(d[:markerstrokecolor], d[:markerstrokealpha])
pyfillcolor(d::KW)          = getPyPlotColor(d[:fillcolor], d[:fillalpha])

pylinecolormap(d::KW)       = getPyPlotColorMap(d[:linecolor], d[:linealpha])
pymarkercolormap(d::KW)     = getPyPlotColorMap(d[:markercolor], d[:markeralpha])
pyfillcolormap(d::KW)       = getPyPlotColorMap(d[:fillcolor], d[:fillalpha])

function _add_series(pkg::PyPlotBackend, plt::Plot, d::KW)
    lt = d[:linetype]
    if !(lt in supportedTypes(pkg))
        error("linetype $(lt) is unsupported in PyPlot.  Choose from: $(supportedTypes(pkg))")
    end

    # 3D plots have a different underlying Axes object in PyPlot
    if lt in _3dTypes && isempty(plt.o.kwargs)
        push!(plt.o.kwargs, (:projection, "3d"))
    end

    # PyPlot doesn't handle mismatched x/y
    fix_xy_lengths!(plt, d)

    ax = getAxis(plt, d[:axis])
    x, y, z = d[:x], d[:y], d[:z]

    # handle zcolor and get c/cmap
    extrakw = KW()

    # holds references to any python object representing the matplotlib series
    handles = []
    needs_colorbar = false

    # path/line/scatter should all do UP TO 2 series... a line, and a scatter
    if lt in (:path, :line, :scatter, :path3d, :scatter3d, :steppre, :steppost)
        xyargs = (lt in _3dTypes ? (x,y,z) : (x,y))

        # line plot (path, line, steppre, steppost, path3d)
        if d[:linewidth] > 0
            handle = ax[:plot](xyargs...;
                label = d[:label],
                zorder = plt.n,
                color = pylinecolor(d),
                linewidth = d[:linewidth],
                linestyle = getPyPlotLineStyle(lt, d[:linestyle]),
                drawstyle = getPyPlotStepStyle(lt)
            )[1]
            push!(handles, handle)
        end

        # scatter plot (scatter, scatter3d, and line plots that have markers)
        if d[:markershape] != :none
            if d[:marker_z] == nothing
                extrakw[:c] = color_fix(pymarkercolor(d), x)
            else
                extrakw[:c] = convert(Vector{Float64}, d[:marker_z])
                extrakw[:cmap] = pymarkercolormap(d)
                needs_colorbar = true
            end
            handle = ax[:scatter](xyargs...;
                label = d[:label],
                zorder = plt.n + 0.5,
                marker = getPyPlotMarker(d[:markershape]),
                s = d[:markersize] .^ 2,
                edgecolors = pymarkerstrokecolor(d),
                linewidths = d[:markerstrokewidth],
                extrakw...
            )
            push!(handles, handle)
        end
    end

    if lt in (:bar, :sticks)
        extrakw[isvertical(d) ? :width : :height] = (lt == :sticks ? 0.1 : 0.9)
        handle = ax[isvertical(d) ? :bar : :barh](x, y;
            label = d[:label],
            zorder = plt.n,
            color = pyfillcolor(d),
            edgecolor = pylinecolor(d),
            linewidth = d[:linewidth],
            align = "center",
            extrakw...
        )[1]
        push!(handles, handle)
    end

    if lt == :hist
        handle = ax[:hist](y;
            label = d[:label],
            zorder = plt.n,
            color = pyfillcolor(d),
            edgecolor = pylinecolor(d),
            linewidth = d[:linewidth],
            bins = d[:bins],
            normed = d[:normalize],
            weights = d[:weights],
            orientation = (isvertical(d) ? "vertical" : "horizontal"),
            histtype = (d[:bar_position] == :stack ? "barstacked" : "bar")
        )[1]
        push!(handles, handle)
    end

    if lt == :hist2d
        handle = ax[:hist2d](x, y;
            label = d[:label],
            zorder = plt.n,
            bins = d[:bins],
            normed = d[:normalize],
            weights = d[:weights],
            cmap = pyfillcolormap(d)  # applies to the pcolorfast object
        )[4]
        push!(handles, handle)
    end

    if lt == :hexbin
        handle = ax[:hexbin](x, y;
            label = d[:label],
            zorder = plt.n,
            gridsize = d[:bins],
            linewidths = d[:linewidth],
            edgecolors = pylinecolor(d),
            cmap = pyfillcolormap(d)  # applies to the pcolorfast object
        )
        push!(handles, handle)
        needs_colorbar = true
    end

    if lt in (:hline,:vline)
        for yi in d[:y]
            func = ax[lt == :hline ? :axhline : :axvline]
            handle = func(yi;
                linewidth=d[:linewidth],
                color=pylinecolor(d),
                linestyle=getPyPlotLineStyle(lt, d[:linestyle])
            )
            push!(handles, handle)
        end
    end

    if lt == :contour
        z = z.surf'
        needs_colorbar = true

        # pass in an integer value as an arg, but a levels list as a keyword arg
        levels = d[:levels]
        args = if isscalar(levels)
            (levels)
        elseif isvector(levels)
            extrakw[:levels] = levels
            ()
        else
            error("Only numbers and vectors are supported with levels keyword")
        end

        # contour lines
        handle = ax[:contour](x, y, z, args...;
            label = d[:label],
            zorder = plt.n,
            linewidths = d[:linewidth],
            linestyles = getPyPlotLineStyle(lt, d[:linestyle]),
            cmap = pylinecolormap(d),
            extrakw...
        )
        push!(handles, handle)

        # contour fills
        handle = ax[:contourf](x, y, z, args...;
            label = d[:label],
            zorder = plt.n + 0.5,
            cmap = pyfillcolormap(d),
            extrakw...
        )
        push!(handles, handle)
    end

    if lt in (:surface, :wireframe)
        x, y, z = map(Array, (x,y,z))
        if !ismatrix(x) || !ismatrix(y)
            x = repmat(x', length(y), 1)
            y = repmat(y, 1, length(d[:x]))
            z = z'
        end
        if lt == :surface
            extrakw[:cmap] = pyfillcolormap(d)
            needs_colorbar = true
        end
        handle = ax[lt == :surface ? :plot_surface : :plot_wireframe](x, y, z;
            label = d[:label],
            zorder = plt.n,
            rstride = 1,
            cstride = 1,
            linewidth = d[:linewidth],
            edgecolor = pylinecolor(d),
            extrakw...
        )
        push!(handles, handle)
    end

    if lt == :heatmap
        x, y, z = heatmap_edges(x), heatmap_edges(y), z.surf'
        handle = ax[:pcolormesh](x, y, z;
            label = d[:label],
            zorder = plt.n,
            cmap = pyfillcolormap(d),
            edgecolors = (d[:linewidth] > 0 ? pylinecolor(d) : "face")
        )
        push!(handles, handle)
    end

    if lt == :shape
        path = buildPyPlotPath(x, y)
        patches = pypatches.pymember("PathPatch")(path;
            label = d[:label],
            zorder = plt.n,
            edgecolor = pymarkerstrokecolor(d),
            facecolor = pymarkercolor(d),
            linewidth = d[:markerstrokewidth],
            fill = true
        )
        handle = ax[:add_patch](patches)
        push!(handles, handle)
    end

    d[:serieshandle] = handles

    # smoothing
    handleSmooth(plt, ax, d, d[:smooth])

    # add the colorbar legend
    if needs_colorbar && plt.plotargs[:colorbar] != :none
        PyPlot.colorbar(handles[end], ax=ax)
    end

    # this sets the bg color inside the grid
    # ax[:set_axis_bgcolor](getPyPlotColor(plt.plotargs[:background_color]))
    ax[:set_axis_bgcolor](getPyPlotColor(plt.plotargs[:background_color_inside]))

    # handle area filling
    fillrange = d[:fillrange]
    if fillrange != nothing && lt != :contour
        if typeof(fillrange) <: @compat(Union{Real, AVec})
            ax[:fill_between](d[:x], fillrange, d[:y], facecolor = pyfillcolor(d), zorder = plt.n)
        else
            ax[:fill_between](d[:x], fillrange..., facecolor = pyfillcolor(d), zorder = plt.n)
        end
    end

    push!(plt.seriesargs, d)
    plt
end

# function _add_series2(pkg::PyPlotBackend, plt::Plot, d::KW)
#     # 3D plots have a different underlying Axes object in PyPlot
#     lt = d[:linetype]
#     if lt in _3dTypes && isempty(plt.o.kwargs)
#         push!(plt.o.kwargs, (:projection, "3d"))
#     end
#
#     # handle mismatched x/y sizes, as PyPlot doesn't like that
#     x, y = d[:x], d[:y]
#     nx, ny = length(x), length(y)
#     if !isa(get(d, :z, nothing), Surface) && nx != ny
#         if nx < ny
#             d[:x] = Float64[x[mod1(i,nx)] for i=1:ny]
#         else
#             d[:y] = Float64[y[mod1(i,ny)] for i=1:nx]
#         end
#     end
#
#     ax = getAxis(plt, d[:axis])
#     if !(lt in supportedTypes(pkg))
#         error("linetype $(lt) is unsupported in PyPlot.  Choose from: $(supportedTypes(pkg))")
#     end
#
#     linecolor = getPyPlotColor(d[:linecolor], d[:linealpha])
#     markercolor = getPyPlotColor(d[:markercolor], d[:markeralpha])
#     fillcolor = getPyPlotColor(d[:fillcolor], d[:fillalpha])
#     strokecolor = getPyPlotColor(d[:markerstrokecolor], d[:markerstrokealpha])
#     linecmap = getPyPlotColorMap(d[:linecolor], d[:linealpha])
#     fillcmap = getPyPlotColorMap(d[:fillcolor], d[:fillalpha])
#     linestyle = getPyPlotLineStyle(lt, d[:linestyle])
#
#     if lt == :sticks
#         d,_ = sticksHack(;d...)
#
#     elseif lt in (:scatter, :scatter3d)
#         if d[:markershape] == :none
#             d[:markershape] = :ellipse
#         end
#
#     elseif lt in (:hline,:vline)
#         for yi in d[:y]
#             func = ax[lt == :hline ? :axhline : :axvline]
#             func(yi, linewidth=d[:linewidth], color=linecolor, linestyle=linestyle)
#         end
#
#     end
#
#     extra_kwargs = KW()
#     plotfunc = getPyPlotFunction(plt, d[:axis], lt)
#
#     # we have different args depending on plot type
#     if lt in (:hist, :density, :sticks, :bar)
#
#         # NOTE: this is unsupported because it does the wrong thing... it shifts the whole axis
#         # extra_kwargs[:bottom] = d[:fill]
#
#         if like_histogram(lt)
#             extra_kwargs[:bins] = d[:bins]
#             extra_kwargs[:normed] = lt == :density
#             extra_kwargs[:orientation] = isvertical(d) ? "vertical" : "horizontal"
#             extra_kwargs[:histtype] = d[:bar_position] == :stack ? "barstacked" : "bar"
#         else
#             extra_kwargs[:linewidth] = (lt == :sticks ? 0.1 : 0.9)
#         end
#
#     elseif lt in (:hist2d, :hexbin)
#         extra_kwargs[:gridsize] = d[:bins]
#         extra_kwargs[:cmap] = linecmap
#
#     elseif lt == :contour
#         extra_kwargs[:cmap] = linecmap
#         extra_kwargs[:linewidths] = d[:linewidth]
#         extra_kwargs[:linestyles] = linestyle
#         # TODO: will need to call contourf to fill in the contours
#
#     elseif lt in (:surface, :wireframe)
#         if lt == :surface
#             extra_kwargs[:cmap] = fillcmap
#         end
#         extra_kwargs[:rstride] = 1
#         extra_kwargs[:cstride] = 1
#         extra_kwargs[:linewidth] = d[:linewidth]
#         extra_kwargs[:edgecolor] = linecolor
#
#     elseif lt == :heatmap
#         extra_kwargs[:cmap] = fillcmap
#
#     elseif lt == :shape
#         extra_kwargs[:edgecolor] = strokecolor
#         extra_kwargs[:facecolor] = markercolor
#         extra_kwargs[:linewidth] = d[:markerstrokewidth]
#         extra_kwargs[:fill] = true
#
#     else
#
#         extra_kwargs[:linestyle] = linestyle
#         extra_kwargs[:marker] = getPyPlotMarker(d[:markershape])
#
#         if lt in (:scatter, :scatter3d)
#             extra_kwargs[:s] = d[:markersize].^2
#             c = d[:markercolor]
#             if d[:marker_z] != nothing
#                 if !isa(c, ColorGradient)
#                     c = default_gradient()
#                 end
#                 extra_kwargs[:c] = convert(Vector{Float64}, d[:marker_z])
#                 extra_kwargs[:cmap] = getPyPlotColorMap(c, d[:markeralpha])
#             else
#                 ppc = getPyPlotColor(c, d[:markeralpha])
#
#                 # total hack due to PyPlot bug (see issue #145).
#                 # hack: duplicate the color vector when the total rgba fields is the same as the series length
#                 if (typeof(ppc) <: AbstractArray && length(ppc)*4 == length(x)) || (typeof(ppc) <: Tuple && length(x) == 4)
#                     ppc = vcat(ppc, ppc)
#                 end
#                 extra_kwargs[:c] = ppc
#
#             end
#             extra_kwargs[:edgecolors] = strokecolor
#             extra_kwargs[:linewidths] = d[:markerstrokewidth]
#         else
#             extra_kwargs[:markersize] = d[:markersize]
#             extra_kwargs[:markerfacecolor] = markercolor
#             extra_kwargs[:markeredgecolor] = strokecolor
#             extra_kwargs[:markeredgewidth] = d[:markerstrokewidth]
#             extra_kwargs[:drawstyle] = getPyPlotStepStyle(lt)
#         end
#     end
#
#     # set these for all types
#     if !(lt in (:contour,:surface,:wireframe,:heatmap))
#         if !(lt in (:scatter, :scatter3d, :shape))
#             extra_kwargs[:color] = linecolor
#             extra_kwargs[:linewidth] = d[:linewidth]
#         end
#         extra_kwargs[:label] = d[:label]
#         extra_kwargs[:zorder] = plt.n
#     end
#
#     # do the plot
#     d[:serieshandle] = if like_histogram(lt)
#         extra_kwargs[:color] = fillcolor
#         extra_kwargs[:edgecolor] = linecolor
#         plotfunc(d[:y]; extra_kwargs...)[1]
#
#     elseif lt == :contour
#         x, y = d[:x], d[:y]
#         surf = d[:z].surf'
#         levels = d[:levels]
#         if isscalar(levels)
#             extra_args = (levels)
#         elseif isvector(levels)
#             extra_args = ()
#             extra_kwargs[:levels] = levels
#         else
#             error("Only numbers and vectors are supported with levels keyword")
#         end
#         handle = plotfunc(x, y, surf, extra_args...; extra_kwargs...)
#         if d[:fillrange] != nothing
#             extra_kwargs[:cmap] = fillcmap
#             delete!(extra_kwargs, :linewidths)
#             handle = ax[:contourf](x, y, surf, extra_args...; extra_kwargs...)
#         end
#         handle
#
#     elseif lt in (:surface,:wireframe)
#         x, y, z = Array(d[:x]), Array(d[:y]), Array(d[:z])
#         if !ismatrix(x) || !ismatrix(y)
#             x = repmat(x', length(y), 1)
#             y = repmat(y, 1, length(d[:x]))
#             z = z'
#         end
#         plotfunc(x, y, z; extra_kwargs...)
#
#     elseif lt in _3dTypes
#         plotfunc(d[:x], d[:y], d[:z]; extra_kwargs...)[1]
#
#     elseif lt in (:scatter, :hist2d, :hexbin)
#         plotfunc(d[:x], d[:y]; extra_kwargs...)
#
#     elseif lt == :heatmap
#         x, y, z = d[:x], d[:y], d[:z].surf'
#         plotfunc(heatmap_edges(x), heatmap_edges(y), z; extra_kwargs...)
#
#     elseif lt == :shape
#         path = buildPyPlotPath(d[:x], d[:y])
#         patches = pypatches.pymember("PathPatch")(path; extra_kwargs...)
#         plotfunc(patches)
#
#     else # plot
#         plotfunc(d[:x], d[:y]; extra_kwargs...)[1]
#     end
#
#     # smoothing
#     handleSmooth(plt, ax, d, d[:smooth])
#
#     # add the colorbar legend
#     if plt.plotargs[:colorbar] != :none && haskey(extra_kwargs, :cmap)
#         PyPlot.colorbar(d[:serieshandle], ax=ax)
#     end
#
#     # this sets the bg color inside the grid
#     ax[:set_axis_bgcolor](getPyPlotColor(plt.plotargs[:background_color]))
#
#     fillrange = d[:fillrange]
#     if fillrange != nothing && lt != :contour
#         if typeof(fillrange) <: @compat(Union{Real, AVec})
#             ax[:fill_between](d[:x], fillrange, d[:y], facecolor = fillcolor, zorder = plt.n)
#         else
#             ax[:fill_between](d[:x], fillrange..., facecolor = fillcolor, zorder = plt.n)
#         end
#     end
#
#     push!(plt.seriesargs, d)
#     plt
# end

# -----------------------------------------------------------------


# given a dimension (:x, :y, or :z), loop over the seriesargs KWs to find the min/max of the underlying data
function minmaxseries(ds, dimension, axis)
    lo, hi = Inf, -Inf
    for d in ds
        d[:axis] == axis || continue
        v = d[dimension]
        if length(v) > 0
            vlo, vhi = extrema(v)
            lo = min(lo, vlo)
            hi = max(hi, vhi)
        end
    end
    if lo == hi
        hi = if lo == 0
            1e-6
        else
            hi + min(abs(1e-2hi), 1e-6)
        end
    end
    lo, hi
end

# TODO: this needs to handle one-sided fixed limits
function set_lims!(plt::Plot{PyPlotBackend}, axis::Symbol)
    ax = getAxis(plt, axis)
    if plt.plotargs[:xlims] == :auto
        ax[:set_xlim](minmaxseries(plt.seriesargs, :x, axis)...)
    end
    if plt.plotargs[:ylims] == :auto
        ax[:set_ylim](minmaxseries(plt.seriesargs, :y, axis)...)
    end
    if plt.plotargs[:zlims] == :auto && haskey(ax, :set_zlim)
        ax[:set_zlim](minmaxseries(plt.seriesargs, :z, axis)...)
    end
end

# --------------------------------------------------------------------------

# TODO: d[:serieshandle] should really be a list of handles... then we should set
# the x/y data for each handle (for example, plot and scatter)

function setxy!{X,Y}(plt::Plot{PyPlotBackend}, xy::Tuple{X,Y}, i::Integer)
    d = plt.seriesargs[i]
    d[:x], d[:y] = xy
    for handle in d[:serieshandle]
        try
            handle[:set_data](xy...)
        catch
            handle[:set_offsets](hcat(xy...))
        end
    end
    set_lims!(plt, d[:axis])
    plt
end


function setxyz!{X,Y,Z}(plt::Plot{PyPlotBackend}, xyz::Tuple{X,Y,Z}, i::Integer)
    d = plt.seriesargs[i]
    d[:x], d[:y], d[:z] = xyz
    for handle in d[:serieshandle]
        handle[:set_data](d[:x], d[:y])
        handle[:set_3d_properties](d[:z])
    end
    # series = d[:serieshandle]
    # series[:set_data](d[:x], d[:y])
    # series[:set_3d_properties](d[:z])
    set_lims!(plt, d[:axis])
    plt
end

# --------------------------------------------------------------------------

function addPyPlotLims(ax, lims, letter)
    lims == :auto && return
    ltype = limsType(lims)
    if ltype == :limits
        setf = ax[symbol("set_", letter, "lim")]
        l1, l2 = lims
        if isfinite(l1)
            letter == "x" ? setf(left = l1) : setf(bottom = l1)
        end
        if isfinite(l2)
            letter == "x" ? setf(right = l2) : setf(top = l2)
        end
    else
        error("Invalid input for $letter: ", lims)
    end
end

function addPyPlotTicks(ax, ticks, letter)
    ticks == :auto && return
    if ticks == :none || ticks == nothing
        ticks = zeros(0)
    end

    ttype = ticksType(ticks)
    tickfunc = symbol("set_", letter, "ticks")
    labfunc = symbol("set_", letter, "ticklabels")
    if ttype == :ticks
        ax[tickfunc](ticks)
    elseif ttype == :ticks_and_labels
        ax[tickfunc](ticks[1])
        ax[labfunc](ticks[2])
    else
        error("Invalid input for $(isx ? "xticks" : "yticks"): ", ticks)
    end
end

function applyPyPlotScale(ax, scaleType::Symbol, letter)
    func = ax[symbol("set_", letter, "scale")]
    scaleType == :identity && return func("linear")
    scaleType == :ln && return func("log", basex = e, basey = e)
    scaleType == :log2 && return func("log", basex = 2, basey = 2)
    scaleType == :log10 && return func("log", basex = 10, basey = 10)
    warn("Unhandled scaleType: ", scaleType)
end


function updateAxisColors(ax, d::KW)
    guidecolor = getPyPlotColor(d[:guidefont].color)
    for (loc, spine) in ax[:spines]
        spine[:set_color](getPyPlotColor(d[:foreground_color_border]))
    end
    for letter in ("x", "y", "z")
        axis = axis_symbol(letter, "axis")
        if haskey(ax, axis)
            ax[:tick_params](axis=letter, which="both",
                             colors=getPyPlotColor(d[:foreground_color_axis]),
                             labelcolor=getPyPlotColor(d[:foreground_color_text]))
            ax[axis][:label][:set_color](guidecolor)
        end
    end
    ax[:title][:set_color](guidecolor)
end

function usingRightAxis(plt::Plot{PyPlotBackend})
    any(args -> args[:axis] in (:right,:auto), plt.seriesargs)
end


# --------------------------------------------------------------------------


function _update_plot(plt::Plot{PyPlotBackend}, d::KW)
    figorax = plt.o
    ax = getLeftAxis(figorax)
    ticksz = get(d, :tickfont, plt.plotargs[:tickfont]).pointsize
    guidesz = get(d, :guidefont, plt.plotargs[:guidefont]).pointsize

    # title
    haskey(d, :title) && ax[:set_title](d[:title])
    ax[:title][:set_fontsize](guidesz)

    # handle right y axis
    axes = [getLeftAxis(figorax)]
    if usingRightAxis(plt)
        push!(axes, getRightAxis(figorax))
        if get(d, :yrightlabel, "") != ""
            rightax = getRightAxis(figorax)
            rightax[:set_ylabel](d[:yrightlabel])
        end
    end

    # handle each axis in turn
    for letter in ("x", "y", "z")
        axis, scale, lims, ticks, flip, lab = axis_symbols(letter, "axis", "scale", "lims", "ticks", "flip", "label")
        haskey(ax, axis) || continue
        haskey(d, scale) && applyPyPlotScale(ax, d[scale], letter)
        haskey(d, lims)  && addPyPlotLims(ax, d[lims], letter)
        haskey(d, ticks) && addPyPlotTicks(ax, d[ticks], letter)
        haskey(d, lab)   && ax[symbol("set_", letter, "label")](d[lab])
        if get(d, flip, false)
            ax[symbol("invert_", letter, "axis")]()
        end
        for tmpax in axes
            tmpax[axis][:label][:set_fontsize](guidesz)
            for lab in tmpax[symbol("get_", letter, "ticklabels")]()
                lab[:set_fontsize](ticksz)
            end
            if get(d, :grid, false)
                # fgcolor = getPyPlotColor(plt.plotargs[:foreground_color])
                fgcolor = getPyPlotColor(plt.plotargs[:foreground_color_grid])
                tmpax[axis][:grid](true, color = fgcolor)
                tmpax[:set_axisbelow](true)
            end
        end
    end
end


# -----------------------------------------------------------------

function createPyPlotAnnotationObject(plt::Plot{PyPlotBackend}, x, y, val::@compat(AbstractString))
    ax = getLeftAxis(plt)
    ax[:annotate](val, xy = (x,y))
end


function createPyPlotAnnotationObject(plt::Plot{PyPlotBackend}, x, y, val::PlotText)
    ax = getLeftAxis(plt)
    ax[:annotate](val.str,
        xy = (x,y),
        family = val.font.family,
        color = getPyPlotColor(val.font.color),
        horizontalalignment = val.font.halign == :hcenter ? "center" : string(val.font.halign),
        verticalalignment = val.font.valign == :vcenter ? "center" : string(val.font.valign),
        rotation = val.font.rotation * 180 / π,
        size = val.font.pointsize
    )
end

function _add_annotations{X,Y,V}(plt::Plot{PyPlotBackend}, anns::AVec{@compat(Tuple{X,Y,V})})
    for ann in anns
        createPyPlotAnnotationObject(plt, ann...)
    end
end

# -----------------------------------------------------------------

function _create_subplot(subplt::Subplot{PyPlotBackend}, isbefore::Bool)
    l = subplt.layout
    plotargs = getplotargs(subplt, 1)
    fig = pyplot_figure(plotargs)

    nr = nrows(l)
    for (i,(r,c)) in enumerate(l)
        # add the plot to the figure
        nc = ncols(l, r)
        fakeidx = (r-1) * nc + c
        ax = fig[:add_subplot](nr, nc, fakeidx)

        subplt.plts[i].o = PyPlotAxisWrapper(ax, nothing, fig, [])
        pyplot_3d_setup!(subplt.plts[i].o, plotargs)
    end

    subplt.o = PyPlotAxisWrapper(nothing, nothing, fig, [])
    pyplot_3d_setup!(subplt.o, plotargs)
    true
end

# this will be called internally, when creating a subplot from existing plots
# NOTE: if I ever need to "Rebuild a "ubplot from individual Plot's"... this is what I should use!
function subplot(plts::AVec{Plot{PyPlotBackend}}, layout::SubplotLayout, d::KW)
    validateSubplotSupported()

    p = length(layout)
    n = sum([plt.n for plt in plts])

    pkg = PyPlotBackend()
    newplts = Plot{PyPlotBackend}[begin
        plt.plotargs[:subplot] = true
        _create_plot(pkg, plt.plotargs)
    end for plt in plts]

    subplt = Subplot(nothing, newplts, PyPlotBackend(), p, n, layout, d, true, false, false, (r,c) -> (nothing,nothing))

    _preprocess_subplot(subplt, d)
    _create_subplot(subplt, true)

    for (i,plt) in enumerate(plts)
        for seriesargs in plt.seriesargs
            _add_series_subplot(newplts[i], seriesargs)
        end
    end

    _postprocess_subplot(subplt, d)

    subplt
end


function _remove_axis(plt::Plot{PyPlotBackend}, isx::Bool)
    if isx
        plot!(plt, xticks=zeros(0), xlabel="")
    else
        plot!(plt, yticks=zeros(0), ylabel="")
    end
end

function _expand_limits(lims, plt::Plot{PyPlotBackend}, isx::Bool)
    pltlims = plt.o.ax[isx ? :get_xbound : :get_ybound]()
    _expand_limits(lims, pltlims)
end

# -----------------------------------------------------------------

const _pyplot_legend_pos = KW(
    :right => "right",
    :left => "center left",
    :top => "upper center",
    :bottom => "lower center"
  )

# function addPyPlotLegend(plt::Plot)
function addPyPlotLegend(plt::Plot, ax)
    leg = plt.plotargs[:legend]
    if leg != :none
        # gotta do this to ensure both axes are included
        args = filter(x -> !(x[:linetype] in (:hist,:density,:hexbin,:hist2d,:hline,:vline,:contour,:surface,:wireframe,:heatmap,:path3d,:scatter3d)), plt.seriesargs)
        args = filter(x -> x[:label] != "", args)
        if length(args) > 0
            leg = ax[:legend]([d[:serieshandle][1] for d in args],
                [d[:label] for d in args],
                loc = get(_pyplot_legend_pos, leg, "best"),
                scatterpoints = 1,
                fontsize = plt.plotargs[:legendfont].pointsize
                # framealpha = 0.6
            )
            leg[:set_zorder](1000)

            # set some legend properties
            frame = leg[:get_frame]()
            frame[:set_facecolor](getPyPlotColor(plt.plotargs[:background_color_legend]))
            frame[:set_edgecolor](getPyPlotColor(plt.plotargs[:foreground_color_legend]))
        end
    end
end

# -----------------------------------------------------------------

function finalizePlot(plt::Plot{PyPlotBackend})
    ax = getLeftAxis(plt)
    addPyPlotLegend(plt, ax)
    updateAxisColors(ax, plt.plotargs)
    PyPlot.draw()
end

function finalizePlot(subplt::Subplot{PyPlotBackend})
    fig = subplt.o.fig
    for (i,plt) in enumerate(subplt.plts)
        ax = getLeftAxis(plt)
        addPyPlotLegend(plt, ax)
        updateAxisColors(ax, plt.plotargs)
    end
    # fig[:tight_layout]()
    PyPlot.draw()
end


# -----------------------------------------------------------------

# NOTE: to bring up a GUI window in IJulia, need some extra steps
function Base.display(::PlotsDisplay, plt::AbstractPlot{PyPlotBackend})
    finalizePlot(plt)
    if isa(Base.Multimedia.displays[end], Base.REPL.REPLDisplay)
        display(getfig(plt.o))
    else
        # # PyPlot.ion()
        # PyPlot.figure(getfig(plt.o).o[:number])
        # PyPlot.draw_if_interactive()
        # # PyPlot.ioff()
    end
    # PyPlot.plt[:show](block=false)
    getfig(plt.o)[:show]()
end


const _pyplot_mimeformats = Dict(
    "application/eps"         => "eps",
    "image/eps"               => "eps",
    "application/pdf"         => "pdf",
    "image/png"               => "png",
    "application/postscript"  => "ps",
    "image/svg+xml"           => "svg"
)


for (mime, fmt) in _pyplot_mimeformats
    @eval function Base.writemime(io::IO, ::MIME{symbol($mime)}, plt::AbstractPlot{PyPlotBackend})
        finalizePlot(plt)
        fig = getfig(plt.o)
        fig.o["canvas"][:print_figure](
            io,
            format=$fmt,
            # bbox_inches = "tight",
            # figsize = map(px2inch, plt.plotargs[:size]),
            facecolor = fig.o["get_facecolor"](),
            edgecolor = "none",
            dpi = DPI
        )
    end
end
