
# https://github.com/stevengj/PyPlot.jl


supportedArgs(::PyPlotBackend) = [
    :annotations,
    :background_color, :foreground_color, :color_palette,
    :background_color_legend, :background_color_inside, :background_color_outside,
    :foreground_color_legend, :foreground_color_grid, :foreground_color_axis,
        :foreground_color_text, :foreground_color_border,
    :group,
    :label,
    :seriestype,
    :seriescolor, :seriesalpha,
    :linecolor, :linestyle, :linewidth, :linealpha,
    :markershape, :markercolor, :markersize, :markeralpha,
    :markerstrokewidth, :markerstrokecolor, :markerstrokealpha,
    :fillrange, :fillcolor, :fillalpha,
    :bins, :bar_width, :bar_edges,
    :n, :nc, :nr, :layout,
    :smooth,
    :title, :window_title, :show, :size,
    :x, :xguide, :xlims, :xticks, :xscale, :xflip, :xrotation,
    :y, :yguide, :ylims, :yticks, :yscale, :yflip, :yrotation,
    # :axis, :yrightlabel,
    :z, :zguide, :zlims, :zticks, :zscale, :zflip, :zrotation,
    :z,
    :tickfont, :guidefont, :legendfont,
    :grid, :legend, :colorbar,
    :marker_z, :levels,
    :xerror, :yerror,
    :ribbon, :quiver, :arrow,
    :orientation,
    :overwrite_figure,
    :polar,
    :normalize, :weights, :contours, :aspect_ratio,
    :match_dimensions,
    :subplot,
  ]
supportedAxes(::PyPlotBackend) = _allAxes
supportedTypes(::PyPlotBackend) = [
        :none, :line, :path, :steppre, :steppost, :shape,
        :scatter, :histogram2d, :hexbin, :histogram, #:density,
        :bar, :sticks, #:box, :violin, :quiver,
        :hline, :vline, :heatmap, :pie, :image,
        :contour, :contour3d, :path3d, :scatter3d, :surface, :wireframe
    ]
supportedStyles(::PyPlotBackend) = [:auto, :solid, :dash, :dot, :dashdot]
supportedMarkers(::PyPlotBackend) = vcat(_allMarkers, Shape)
supportedScales(::PyPlotBackend) = [:identity, :ln, :log2, :log10]
subplotSupported(::PyPlotBackend) = true
# nativeImagesSupported(::PyPlotBackend) = true


# --------------------------------------------------------------------------------------


function _initialize_backend(::PyPlotBackend)
    @eval begin
        import PyPlot
        export PyPlot
        const pycolors = PyPlot.pywrap(PyPlot.pyimport("matplotlib.colors"))
        const pypath = PyPlot.pywrap(PyPlot.pyimport("matplotlib.path"))
        const mplot3d = PyPlot.pywrap(PyPlot.pyimport("mpl_toolkits.mplot3d"))
        const pypatches = PyPlot.pywrap(PyPlot.pyimport("matplotlib.patches"))
        const pyfont = PyPlot.pywrap(PyPlot.pyimport("matplotlib.font_manager"))
        const pyticker = PyPlot.pywrap(PyPlot.pyimport("matplotlib.ticker"))
        const pycmap = PyPlot.pywrap(PyPlot.pyimport("matplotlib.cm"))
        const pynp = PyPlot.pywrap(PyPlot.pyimport("numpy"))
        const pytransforms = PyPlot.pywrap(PyPlot.pyimport("matplotlib.transforms"))
    end

    PyPlot.ioff()

    # if !isa(Base.Multimedia.displays[end], Base.REPL.REPLDisplay)
    #     PyPlot.ioff()  # stops wierd behavior of displaying incomplete graphs in IJulia

    #     # # TODO: how the hell can I use PyQt4??
    #     # "pyqt4"=>:qt_pyqt4
    #     # PyPlot.backend[1] = "pyqt4"
    #     # PyPlot.gui[1] = :qt_pyqt4
    #     # PyPlot.switch_backend("Qt4Agg")

    #     # only turn on the gui if we want it
    #     if PyPlot.gui != :none
    #         PyPlot.pygui(true)
    #     end
    # end
end

# --------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------

# convert colorant to 4-tuple RGBA
getPyPlotColor(c::Colorant, α=nothing) = map(f->float(f(convertColor(c,α))), (red, green, blue, alpha))
getPyPlotColor(cvec::ColorVector, α=nothing) = map(getPyPlotColor, convertColor(cvec, α).v)
getPyPlotColor(grad::ColorGradient, α=nothing) = map(c -> getPyPlotColor(c, α), grad.colors)
getPyPlotColor(scheme::ColorScheme, α=nothing) = getPyPlotColor(convertColor(getColor(scheme), α))
getPyPlotColor(vec::AVec, α=nothing) = map(c->getPyPlotColor(c,α), vec)
getPyPlotColor(c, α=nothing) = getPyPlotColor(convertColor(c, α))

function getPyPlotColorMap(c::ColorGradient, α=nothing)
    pyvals = [(v, getPyPlotColor(getColorZ(c, v), α)) for v in c.values]
    pycolors.pymember("LinearSegmentedColormap")[:from_list]("tmp", pyvals)
end

# convert vectors and ColorVectors to standard ColorGradients
# TODO: move this logic to colors.jl and keep a barebones wrapper for pyplot
getPyPlotColorMap(cv::ColorVector, α=nothing) = getPyPlotColorMap(ColorGradient(cv.v), α)
getPyPlotColorMap(v::AVec, α=nothing) = getPyPlotColorMap(ColorGradient(v), α)

# anything else just gets a bluesred gradient
getPyPlotColorMap(c, α=nothing) = getPyPlotColorMap(default_gradient(), α)

function getPyPlotCustomShading(c, z, α=nothing)
    cmap = getPyPlotColorMap(c, α)
    # sm = pycmap.pymember("ScalarMappable")(cmap = cmap)
    # sm[:set_array](z)
    # sm
    ls = pycolors.pymember("LightSource")(270,45)
    ls[:shade](z, cmap, vert_exag=0.1, blend_mode="soft")
end

# get the style (solid, dashed, etc)
function getPyPlotLineStyle(seriestype::Symbol, linestyle::Symbol)
    seriestype == :none && return " "
    linestyle == :solid && return "-"
    linestyle == :dash && return "--"
    linestyle == :dot && return ":"
    linestyle == :dashdot && return "-."
    warn("Unknown linestyle $linestyle")
    return "-"
end

function getPyPlotMarker(marker::Shape)
    x, y = shape_coords(marker)
    n = length(x)
    mat = zeros(n+1,2)
    for i=1:n
        mat[i,1] = x[i]
        mat[i,2] = y[i]
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
    mat = zeros(n+1, 2)
    codes = zeros(UInt8, n+1)
    lastnan = true
    for i=1:n
        mat[i,1] = x[i]
        mat[i,2] = y[i]
        nan = !ok(x[i], y[i])
        codes[i] = if nan
            _path_CLOSEPOLY
        else
            lastnan ? _path_MOVETO : _path_LINETO
        end
        lastnan = nan
    end
    codes[n+1] = _path_CLOSEPOLY
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

function getPyPlotStepStyle(seriestype::Symbol)
    seriestype == :steppost && return "steps-post"
    seriestype == :steppre && return "steps-pre"
    return "default"
end

# untested... return a FontProperties object from a Plots.Font
function getPyPlotFont(font::Font)
    pyfont.pymember("FontProperties")(
        family = font.family,
        size = font.size
    )
end

function get_locator_and_formatter(vals::AVec)
    pyticker.pymember("FixedLocator")(1:length(vals)), pyticker.pymember("FixedFormatter")(vals)
end

function add_pyfixedformatter(cbar, vals::AVec)
    cbar[:locator], cbar[:formatter] = get_locator_and_formatter(vals)
    cbar[:update_ticks]()
end

# TODO: smoothing should be moved into the SliceIt method, should not touch backends
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

# ---------------------------------------------------------------------------

# TODO: these can probably be removed eventually... right now they're just keeping things working before cleanup

getAxis(sp::Subplot) = sp.o

function getAxis(plt::Plot{PyPlotBackend}, series::Series)
    sp = get_subplot(plt, get(series.d, :subplot, 1))
    getAxis(sp)
end

getfig(o) = o

# ---------------------------------------------------------------------------
# Figure utils -- F*** matplotlib for making me work so hard to figure this crap out

# the drawing surface
canvas(fig) = fig[:canvas]

# the object controlling draw commands
renderer(fig) = canvas(fig)[:get_renderer]()

# draw commands... paint the screen (probably updating internals too)
drawfig(fig) = fig[:draw](renderer(fig))
drawax(ax) = ax[:draw](renderer(ax[:get_figure]()))

# get a vector [left, right, bottom, top] in PyPlot coords (origin is bottom-left!)
get_extents(obj) = obj[:get_window_extent]()[:get_points]()

# # bounding box of the figure
# function py_bbox_fig(fig)
#     fl, fr, fb, ft = get_extents(fig)
#     BoundingBox(0px, 0px, (fr-fl)*px, (ft-fb)*px)
# end
# py_bbox_fig(plt::Plot) = py_bbox_fig(plt.o)

# compute a bounding box (with origin top-left), however pyplot gives coords with origin bottom-left
function py_bbox(obj)
    fl, fr, fb, ft = get_extents(obj[:get_figure]())
    l, r, b, t = get_extents(obj)
    BoundingBox(l*px, (ft-t)*px, (r-l)*px, (t-b)*px)
end

# get the bounding box of the union of the objects
function py_bbox(v::AVec)
    bbox_union = defaultbox
    for obj in v
        bbox_union = bbox_union + py_bbox(obj)
    end
    bbox_union
end

# bounding box: union of axis tick labels
function py_bbox_ticks(ax, letter)
    labels = ax[Symbol("get_"*letter*"ticklabels")]()
    py_bbox(labels)
end

# bounding box: axis guide
function py_bbox_axislabel(ax, letter)
    pyaxis_label = ax[Symbol("get_"*letter*"axis")]()[:label]
    py_bbox(pyaxis_label)
end

# bounding box: union of axis ticks and guide
function py_bbox_axis(ax, letter)
    ticks = py_bbox_ticks(ax, letter)
    labels = py_bbox_axislabel(ax, letter)
    # letter == "x" && @show ticks labels ticks+labels
    ticks + labels
end

# bounding box: axis title
function py_bbox_title(ax)
    bb = defaultbox
    for s in (:title, :_left_title, :_right_title)
        bb = bb + py_bbox(ax[s])
    end
    bb
end

# ---------------------------------------------------------------------------

# Create the window/figure for this backend.
function _create_backend_figure(plt::Plot{PyPlotBackend})
    w,h = map(px2inch, plt[:size])

    # reuse the current figure?
    fig = if plt[:overwrite_figure]
        PyPlot.gcf()
    else
        PyPlot.figure()
    end

    # # update the specs
    # fig[:set_size_inches](w, h, forward = true)
    # fig[:set_facecolor](getPyPlotColor(plt[:background_color_outside]))
    # fig[:set_dpi](DPI)
    # # fig[:set_tight_layout](true)

    # clear the figure
    PyPlot.clf()

    # # resize the window
    # PyPlot.plt[:get_current_fig_manager]()[:resize](plt[:size]...)
    fig
end

# Set up the subplot within the backend object.
function _initialize_subplot(plt::Plot{PyPlotBackend}, sp::Subplot{PyPlotBackend})
    fig = plt.o
    proj = sp[:projection]
    proj = (proj in (nothing,:none) ? nothing : string(proj))

    # add a new axis, and force it to create a new one by setting a distinct label
    ax = fig[:add_axes](
        [0,0,1,1],
        label = string(gensym()),
        projection = proj
    )
    sp.o = ax
end


# ---------------------------------------------------------------------------


# function _series_added(pkg::PyPlotBackend, plt::Plot, d::KW)
# TODO: change this to accept Subplot??
function _series_added(plt::Plot{PyPlotBackend}, series::Series)
    d = series.d
    st = d[:seriestype]
    sp = d[:subplot]

    if !(st in supportedTypes(plt.backend))
        error("seriestype $(st) is unsupported in PyPlot.  Choose from: $(supportedTypes(plt.backend))")
    end

    # PyPlot doesn't handle mismatched x/y
    fix_xy_lengths!(plt, d)

    ax = getAxis(plt, series)
    x, y, z = d[:x], d[:y], d[:z]
    xyargs = (st in _3dTypes ? (x,y,z) : (x,y))

    # handle zcolor and get c/cmap
    extrakw = KW()

    # holds references to any python object representing the matplotlib series
    handles = []
    needs_colorbar = false
    discrete_colorbar_values = nothing


    # pass in an integer value as an arg, but a levels list as a keyword arg
    levels = d[:levels]
    levelargs = if isscalar(levels)
        (levels)
    elseif isvector(levels)
        extrakw[:levels] = levels
        ()
    else
        error("Only numbers and vectors are supported with levels keyword")
    end

    # for each plotting command, optionally build and add a series handle to the list

    # line plot
    if st in (:path, :line, :path3d, :steppre, :steppost)
        if d[:linewidth] > 0
            handle = ax[:plot](xyargs...;
                label = d[:label],
                zorder = plt.n,
                color = pylinecolor(d),
                linewidth = d[:linewidth],
                linestyle = getPyPlotLineStyle(st, d[:linestyle]),
                solid_capstyle = "round",
                # dash_capstyle = "round",
                drawstyle = getPyPlotStepStyle(st)
            )[1]
            push!(handles, handle)

            a = d[:arrow]
            if a != nothing && !is3d(st)  # TODO: handle 3d later
                if typeof(a) != Arrow
                    warn("Unexpected type for arrow: $(typeof(a))")
                else
                    arrowprops = KW(
                        :arrowstyle => "simple,head_length=$(a.headlength),head_width=$(a.headwidth)",
                        :shrinkA => 0,
                        :shrinkB => 0,
                        :edgecolor => pylinecolor(d),
                        :facecolor => pylinecolor(d),
                        :linewidth => d[:linewidth],
                        :linestyle => getPyPlotLineStyle(st, d[:linestyle]),
                    )
                    add_arrows(x, y) do xyprev, xy
                        ax[:annotate]("",
                            xytext = (0.001xyprev[1] + 0.999xy[1], 0.001xyprev[2] + 0.999xy[2]),
                            xy = xy,
                            arrowprops = arrowprops,
                            zorder = 999
                        )
                    end
                end
            end
        end
    end

    if st == :bar
        bw = d[:bar_width]
        if bw == nothing
            bw = mean(diff(isvertical(d) ? x : y))
        end
        extrakw[isvertical(d) ? :width : :height] = bw
        fr = get(d, :fillrange, nothing)
        if fr != nothing
            extrakw[:bottom] = fr
            d[:fillrange] = nothing
        end
        handle = ax[isvertical(d) ? :bar : :barh](x, y;
            label = d[:label],
            zorder = plt.n,
            color = pyfillcolor(d),
            edgecolor = pylinecolor(d),
            linewidth = d[:linewidth],
            align = d[:bar_edges] ? "edge" : "center",
            extrakw...
        )[1]
        push!(handles, handle)
    end

    if st == :sticks
        extrakw[isvertical(d) ? :width : :height] = 0.0
        handle = ax[isvertical(d) ? :bar : :barh](x, y;
            label = d[:label],
            zorder = plt.n,
            color = pylinecolor(d),
            edgecolor = pylinecolor(d),
            linewidth = d[:linewidth],
            align = "center",
            extrakw...
        )[1]
        push!(handles, handle)
    end

    # add markers?
    if d[:markershape] != :none && st in (:path, :line, :scatter, :path3d,
                                          :scatter3d, :steppre, :steppost,
                                          :bar, :sticks)
        extrakw = KW()
        if d[:marker_z] == nothing
            extrakw[:c] = color_fix(pymarkercolor(d), x)
        else
            extrakw[:c] = convert(Vector{Float64}, d[:marker_z])
            extrakw[:cmap] = pymarkercolormap(d)
            needs_colorbar = true
        end
        xyargs = if st in (:bar, :sticks) && !isvertical(d)
            (y, x)
        else
            xyargs
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

    if st == :histogram
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
        )[3]
        push!(handles, handle)

        # expand the extrema... handle is a list of Rectangle objects
        for rect in handle
            xmin, ymin, xmax, ymax = rect[:get_bbox]()[:extents]
            expand_extrema!(sp, xmin, xmax, ymin, ymax)
            # expand_extrema!(sp[:xaxis], (xmin, xmax))
            # expand_extrema!(sp[:yaxis], (ymin, ymax))
        end
    end

    if st == :histogram2d
        handle = ax[:hist2d](x, y;
            label = d[:label],
            zorder = plt.n,
            bins = d[:bins],
            normed = d[:normalize],
            weights = d[:weights],
            cmap = pyfillcolormap(d)  # applies to the pcolorfast object
        )[4]
        push!(handles, handle)
        needs_colorbar = true

        # expand the extrema... handle is a AxesImage object
        expand_extrema!(sp, handle[:get_extent]()...)
        # xmin, xmax, ymin, ymax = handle[:get_extent]()
        # expand_extrema!(sp[:xaxis], (xmin, xmax))
        # expand_extrema!(sp[:yaxis], (ymin, ymax))
    end

    if st == :hexbin
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

    if st in (:hline,:vline)
        for yi in d[:y]
            func = ax[st == :hline ? :axhline : :axvline]
            handle = func(yi;
                linewidth=d[:linewidth],
                color=pylinecolor(d),
                linestyle=getPyPlotLineStyle(st, d[:linestyle])
            )
            push!(handles, handle)
        end
    end

    if st in (:contour, :contour3d)
        # z = z.surf'
        z = transpose_z(d, z.surf)
        needs_colorbar = true


        if st == :contour3d
            extrakw[:extend3d] = true
        end

        # contour lines
        handle = ax[:contour](x, y, z, levelargs...;
            label = d[:label],
            zorder = plt.n,
            linewidths = d[:linewidth],
            linestyles = getPyPlotLineStyle(st, d[:linestyle]),
            cmap = pylinecolormap(d),
            extrakw...
        )
        push!(handles, handle)

        # contour fills
        if d[:fillrange] != nothing
            handle = ax[:contourf](x, y, z, levelargs...;
                label = d[:label],
                zorder = plt.n + 0.5,
                cmap = pyfillcolormap(d),
                extrakw...
            )
            push!(handles, handle)
        end
    end

    if st in (:surface, :wireframe)
        if typeof(z) <: AbstractMatrix || typeof(z) <: Surface
            x, y, z = map(Array, (x,y,z))
            if !ismatrix(x) || !ismatrix(y)
                x = repmat(x', length(y), 1)
                y = repmat(y, 1, length(d[:x]))
            end
            # z = z'
            z = transpose_z(d, z)
            if st == :surface
                if d[:marker_z] != nothing
                    extrakw[:facecolors] = getPyPlotCustomShading(d[:fillcolor], d[:marker_z], d[:fillalpha])
                    extrakw[:shade] = false
                else
                    extrakw[:cmap] = pyfillcolormap(d)
                    needs_colorbar = true
                end
            end
            handle = ax[st == :surface ? :plot_surface : :plot_wireframe](x, y, z;
                label = d[:label],
                zorder = plt.n,
                rstride = 1,
                cstride = 1,
                linewidth = d[:linewidth],
                edgecolor = pylinecolor(d),
                extrakw...
            )
            push!(handles, handle)

            # contours on the axis planes
            if d[:contours]
                for (zdir,mat) in (("x",x), ("y",y), ("z",z))
                    offset = (zdir == "y" ? maximum : minimum)(mat)
                    handle = ax[:contourf](x, y, z, levelargs...;
                        zdir = zdir,
                        cmap = pyfillcolormap(d),
                        offset = (zdir == "y" ? maximum : minimum)(mat)  # where to draw the contour plane
                    )
                    push!(handles, handle)
                    needs_colorbar = true
                end
            end

            # no colorbar if we are creating a surface LightSource
            if haskey(extrakw, :facecolors)
                needs_colorbar = false
            end

        elseif typeof(z) <: AbstractVector
            # tri-surface plot (http://matplotlib.org/mpl_toolkits/mplot3d/tutorial.html#tri-surface-plots)
            handle = ax[:plot_trisurf](x, y, z;
                label = d[:label],
                zorder = plt.n,
                cmap = pyfillcolormap(d),
                linewidth = d[:linewidth],
                edgecolor = pylinecolor(d)
            )
            push!(handles, handle)
            needs_colorbar = true
        else
            error("Unsupported z type $(typeof(z)) for seriestype=$st")
        end
    end

    if st == :image
        # @show typeof(z)
        img = Array(transpose_z(d, z.surf))
        z = if eltype(img) <: Colors.AbstractGray
            float(img)
        elseif eltype(img) <: Colorant
            map(c -> Float64[red(c),green(c),blue(c)], img)
        else
            z  # hopefully it's in a data format that will "just work" with imshow
        end
        handle = ax[:imshow](z;
            zorder = plt.n,
            cmap = getPyPlotColorMap([:black, :white]),
            vmin = 0.0,
            vmax = 1.0
        )
        push!(handles, handle)

        # expand extrema... handle is AxesImage object
        xmin, xmax, ymax, ymin = handle[:get_extent]()
        expand_extrema!(sp, xmin, xmax, ymin, ymax)
        # sp[:yaxis].d[:flip] = true
    end

    if st == :heatmap
        x, y, z = heatmap_edges(x), heatmap_edges(y), transpose_z(d, z.surf)
        # if !(eltype(z) <: Number)
        #     z, discrete_colorbar_values = indices_and_unique_values(z)
        # end
        dvals = sp[:zaxis][:discrete_values]
        if !isempty(dvals)
            discrete_colorbar_values = dvals
        end
        handle = ax[:pcolormesh](x, y, z;
            label = d[:label],
            zorder = plt.n,
            cmap = pyfillcolormap(d),
            edgecolors = (d[:linewidth] > 0 ? pylinecolor(d) : "face")
        )
        push!(handles, handle)
        needs_colorbar = true

        # TODO: this should probably be handled generically
        # expand extrema... handle is a QuadMesh object
        for path in handle[:properties]()["paths"]
            verts = path[:vertices]
            xmin, ymin = minimum(verts, 1)
            xmax, ymax = maximum(verts, 1)
            expand_extrema!(sp, xmin, xmax, ymin, ymax)
        end

    end

    if st == :shape
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

    if st == :pie
        handle = ax[:pie](y;
            # colors = # a vector of colors?
            labels = pie_labels(sp, series)
        )[1]
        push!(handles, handle)

        # # expand extrema... get list of Wedge objects
        # for wedge in handle
        #     path = wedge[:get_path]()
        #     for 
        lim = 1.1
        expand_extrema!(sp, -lim, lim, -lim, lim)
    end

    d[:serieshandle] = handles

    # smoothing
    handleSmooth(plt, ax, d, d[:smooth])

    # add the colorbar legend
    if needs_colorbar && sp[:colorbar] != :none
        # add keyword args for a discrete colorbar
        handle = handles[end]
        kw = KW()
        if discrete_colorbar_values != nothing
            locator, formatter = get_locator_and_formatter(discrete_colorbar_values)
            # kw[:values] = 1:length(discrete_colorbar_values)
            kw[:values] = sp[:zaxis][:continuous_values]
            kw[:ticks] = locator
            kw[:format] = formatter
            kw[:boundaries] = vcat(0, kw[:values] + 0.5)
        end

        # create and store the colorbar object (handle) and the axis that it is drawn on.
        # note: the colorbar axis is positioned independently from the subplot axis
        fig = plt.o
        cbax = fig[:add_axes]([0.8,0.1,0.03,0.8], label = string(gensym()))
        sp.attr[:cbar_handle] = fig[:colorbar](handle; cax = cbax, kw...)
        sp.attr[:cbar_ax] = cbax
    end

    # handle area filling
    fillrange = d[:fillrange]
    if fillrange != nothing && st != :contour
        f, dim1, dim2 = if isvertical(d)
            :fill_between, x, y
        else
            :fill_betweenx, y, x
        end
        args = if typeof(fillrange) <: Union{Real, AVec}
            dim1, fillrange, dim2
        else
            dim1, fillrange...
        end

        handle = ax[f](args...;
            zorder = plt.n,
            facecolor = pyfillcolor(d),
            linewidths = 0
        )
        push!(handles, handle)
    end
end


# --------------------------------------------------------------------------

function update_limits!(sp::Subplot{PyPlotBackend}, series::Series, letters)
    for letter in letters
        setPyPlotLims(sp.o, sp[Symbol(letter, :axis)])
    end
end

function _series_updated(plt::Plot{PyPlotBackend}, series::Series)
    d = series.d
    for handle in d[:serieshandle]
        if is3d(series)
            handle[:set_data](d[:x], d[:y])
            handle[:set_3d_properties](d[:z])
        else
            try
                handle[:set_data](d[:x], d[:y])
            catch
                handle[:set_offsets](hcat(d[:x], d[:y]))
            end
        end
    end
    update_limits!(d[:subplot], series, is3d(series) ? (:x,:y,:z) : (:x,:y))
end


# --------------------------------------------------------------------------

function setPyPlotLims(ax, axis::Axis)
    letter = axis[:letter]
    lfrom, lto = axis_limits(axis)
    ax[Symbol("set_", letter, "lim")](lfrom, lto)
end

function addPyPlotTicks(ax, ticks, letter)
    ticks == :auto && return
    axis = ax[Symbol(letter,"axis")]
    if ticks == :none || ticks == nothing
        kw = KW()
        for dir in (:top,:bottom,:left,:right)
            kw[dir] = kw[Symbol(:label,dir)] = "off"
        end
        axis[:set_tick_params](;which="both", kw...)
        return
    end

    ttype = ticksType(ticks)
    if ttype == :ticks
        axis[:set_ticks](ticks)
    elseif ttype == :ticks_and_labels
        axis[:set_ticks](ticks[1])
        axis[:set_ticklabels](ticks[2])
    else
        error("Invalid input for $(letter)ticks: $ticks")
    end
end

function applyPyPlotScale(ax, scaleType::Symbol, letter)
    func = ax[Symbol("set_", letter, "scale")]
    scaleType == :identity && return func("linear")
    scaleType == :ln && return func("log", basex = e, basey = e)
    scaleType == :log2 && return func("log", basex = 2, basey = 2)
    scaleType == :log10 && return func("log", basex = 10, basey = 10)
    warn("Unhandled scaleType: ", scaleType)
end


function updateAxisColors(ax, a::Axis)
    for (loc, spine) in ax[:spines]
        spine[:set_color](getPyPlotColor(a[:foreground_color_border]))
    end
    axissym = Symbol(a[:letter], :axis)
    if haskey(ax, axissym)
        ax[:tick_params](axis=string(a[:letter]), which="both",
                         colors=getPyPlotColor(a[:foreground_color_axis]),
                         labelcolor=getPyPlotColor(a[:foreground_color_text]))
        ax[axissym][:label][:set_color](getPyPlotColor(a[:foreground_color_guide]))
    end
end


# --------------------------------------------------------------------------


function _before_layout_calcs(plt::Plot{PyPlotBackend})
    # update the specs
    w, h = plt[:size]
    fig = plt.o
    fig[:set_size_inches](px2inch(w), px2inch(h), forward = true)
    fig[:set_facecolor](getPyPlotColor(plt[:background_color_outside]))
    fig[:set_dpi](DPI)
    
    # resize the window
    PyPlot.plt[:get_current_fig_manager]()[:resize](w, h)

    # update subplots
    for sp in plt.subplots
        ax = getAxis(sp)
        if ax == nothing
            continue
        end

        # add the annotations
        for ann in sp[:annotations]
            createPyPlotAnnotationObject(sp, ann...)
        end

        # title
        if sp[:title] != ""
            loc = lowercase(string(sp[:title_location]))
            field = if loc == "left"
                :_left_title
            elseif loc == "right"
                :_right_title
            else
                :title
            end
            ax[field][:set_text](sp[:title])
            ax[field][:set_fontsize](sp[:titlefont].pointsize)
            ax[field][:set_color](getPyPlotColor(sp[:foreground_color_title]))
            # ax[:set_title](sp[:title], loc = loc)
        end

        # axis attributes
        for letter in (:x, :y, :z)
            axissym = Symbol(letter, :axis)
            axis = sp[axissym]
            haskey(ax, axissym) || continue
            applyPyPlotScale(ax, axis[:scale], letter)
            setPyPlotLims(ax, axis)
            addPyPlotTicks(ax, get_ticks(axis), letter)
            ax[Symbol("set_", letter, "label")](axis[:guide])
            if get(axis.d, :flip, false)
                ax[Symbol("invert_", letter, "axis")]()
            end
            ax[axissym][:label][:set_fontsize](axis[:guidefont].pointsize)
            for lab in ax[Symbol("get_", letter, "ticklabels")]()
                lab[:set_fontsize](axis[:tickfont].pointsize)
                lab[:set_rotation](axis[:rotation])
            end
            if sp[:grid]
                fgcolor = getPyPlotColor(sp[:foreground_color_grid])
                ax[axissym][:grid](true, color = fgcolor)
                ax[:set_axisbelow](true)
            end
            updateAxisColors(ax, axis)
        end

        # aspect ratio
        aratio = sp[:aspect_ratio]
        if aratio != :none
            ax[:set_aspect](isa(aratio, Symbol) ? string(aratio) : aratio, anchor = "C")
        end

        # legend
        addPyPlotLegend(plt, sp, ax)

        # this sets the bg color inside the grid
        ax[:set_axis_bgcolor](getPyPlotColor(sp[:background_color_inside]))
    end
    drawfig(fig)
end


# Set the (left, top, right, bottom) minimum padding around the plot area
# to fit ticks, tick labels, guides, colorbars, etc.
function _update_min_padding!(sp::Subplot{PyPlotBackend})
    ax = sp.o
    ax == nothing && return sp.minpad
    plotbb = py_bbox(ax)

    # TODO: this should initialize to the margin from sp.attr
    # figure out how much the axis components and title "stick out" from the plot area
    # leftpad = toppad = rightpad = bottompad = 1mm
    leftpad   = sp[:left_margin]
    toppad    = sp[:top_margin]
    rightpad  = sp[:right_margin]
    bottompad = sp[:bottom_margin]
    for bb in (py_bbox_axis(ax, "x"), py_bbox_axis(ax, "y"), py_bbox_title(ax))
        if ispositive(width(bb)) && ispositive(height(bb))
            leftpad   = max(leftpad,   left(plotbb) - left(bb))
            toppad    = max(toppad,    top(plotbb)  - top(bb))
            rightpad  = max(rightpad,  right(bb)    - right(plotbb))
            bottompad = max(bottompad, bottom(bb)   - bottom(plotbb))
        end
    end

    # optionally add the width of colorbar labels and colorbar to rightpad
    if haskey(sp.attr, :cbar_ax)
        bb = py_bbox(sp.attr[:cbar_handle][:ax][:get_yticklabels]())
        sp.attr[:cbar_width] = _cbar_width + width(bb) + 1mm
        rightpad = rightpad + sp.attr[:cbar_width]
    end

    sp.minpad = (leftpad, toppad, rightpad, bottompad)
end


# -----------------------------------------------------------------

function createPyPlotAnnotationObject(sp::Subplot{PyPlotBackend}, x, y, val)
    ax = sp.o
    ax[:annotate](val, xy = (x,y), zorder = 999)
end


function createPyPlotAnnotationObject(sp::Subplot{PyPlotBackend}, x, y, val::PlotText)
    ax = sp.o
    ax[:annotate](val.str,
        xy = (x,y),
        family = val.font.family,
        color = getPyPlotColor(val.font.color),
        horizontalalignment = val.font.halign == :hcenter ? "center" : string(val.font.halign),
        verticalalignment = val.font.valign == :vcenter ? "center" : string(val.font.valign),
        rotation = val.font.rotation * 180 / π,
        size = val.font.pointsize,
        zorder = 999
    )
end

# -----------------------------------------------------------------

# function _remove_axis(plt::Plot{PyPlotBackend}, isx::Bool)
#     if isx
#         plot!(plt, xticks=zeros(0), xlabel="")
#     else
#         plot!(plt, yticks=zeros(0), ylabel="")
#     end
# end
#
# function _expand_limits(lims, plt::Plot{PyPlotBackend}, isx::Bool)
#     pltlims = plt.o.ax[isx ? :get_xbound : :get_ybound]()
#     _expand_limits(lims, pltlims)
# end

# -----------------------------------------------------------------

const _pyplot_legend_pos = KW(
    :right => "right",
    :left => "center left",
    :top => "upper center",
    :bottom => "lower center",
    :bottomleft => "lower left",
    :bottomright => "lower right",
    :topright => "upper right",
    :topleft => "upper left"
  )

function addPyPlotLegend(plt::Plot, sp::Subplot, ax)
    leg = sp[:legend]
    if leg != :none
        # gotta do this to ensure both axes are included
        labels = []
        handles = []
        # for series in plt.series_list
        #     if get_subplot(series) === sp &&
        #                 series.d[:label] != "" &&
        #                 !(series.d[:seriestype] in (
        #                     :hexbin,:histogram2d,:hline,:vline,
        #                     :contour,:contour3d,:surface,:wireframe,
        #                     :heatmap,:path3d,:scatter3d, :pie, :image))
        for series in series_list(sp)
            if should_add_to_legend(series)
                # add a line/marker and a label
                push!(handles, if series.d[:seriestype] == :histogram
                    PyPlot.plt[:Line2D]((0,1),(0,0), color=pyfillcolor(series.d), linewidth=4)
                else
                    series.d[:serieshandle][1]
                end)
                push!(labels, series.d[:label])
            end
        end

        # if anything was added, call ax.legend and set the colors
        if !isempty(handles)
            leg = ax[:legend](handles,
                labels,
                loc = get(_pyplot_legend_pos, leg, "best"),
                scatterpoints = 1,
                fontsize = sp[:legendfont].pointsize
                # framealpha = 0.6
            )
            leg[:set_zorder](1000)

            fgcolor = getPyPlotColor(sp[:foreground_color_legend])
            for txt in leg[:get_texts]()
                PyPlot.plt[:setp](txt, color = fgcolor)
            end

            # set some legend properties
            frame = leg[:get_frame]()
            frame[:set_facecolor](getPyPlotColor(sp[:background_color_legend]))
            frame[:set_edgecolor](fgcolor)
        end
    end
end

# -----------------------------------------------------------------

# # add legend, update colors and positions, then draw
# function finalizePlot(plt::Plot{PyPlotBackend})
#     # for sp in plt.subplots
#     #     # ax = getLeftAxis(plt)
#     #     ax = getAxis(sp)
#     #     ax == nothing && continue
#     #     addPyPlotLegend(plt, sp, ax)
#     #     for asym in (:xaxis, :yaxis, :zaxis)
#     #         updateAxisColors(ax, sp.attr[asym])
#     #     end
#     # end
#     drawfig(plt.o)
#     # plt.layout.bbox = py_bbox_fig(plt)
#
#     # TODO: these should be called outside of pyplot... how?
#     update_child_bboxes!(plt.layout)
#     _update_position!(plt.layout)
#
#     PyPlot.draw()
# end

# function _before_layout_calcs(plt::Plot{PyPlotBackend})
#     drawfig(plt.o)
# end

# Use the bounding boxes (and methods left/top/right/bottom/width/height) `sp.bbox` and `sp.plotarea` to
# position the subplot in the backend.
function _update_plot_object(plt::Plot{PyPlotBackend})
    for sp in plt.subplots
        ax = sp.o
        ax == nothing && return
        # figw, figh = size(py_bbox_fig(sp.plt))
        figw, figh = sp.plt[:size]
        figw, figh = figw*px, figh*px
        pcts = bbox_to_pcts(sp.plotarea, figw, figh)
        ax[:set_position](pcts)

        # set the cbar position if there is one
        if haskey(sp.attr, :cbar_ax)
            cbw = sp.attr[:cbar_width]
            # this is the bounding box of just the colors of the colorbar (not labels)
            cb_bbox = BoundingBox(right(sp.bbox)-cbw+1mm, top(sp.bbox)+2mm, _cbar_width-1mm, height(sp.bbox)-4mm)
            pcts = bbox_to_pcts(cb_bbox, figw, figh)
            sp.attr[:cbar_ax][:set_position](pcts)
        end
    end
    PyPlot.draw()
end

# -----------------------------------------------------------------
# display/output

function _display(plt::Plot{PyPlotBackend})
    # if isa(Base.Multimedia.displays[end], Base.REPL.REPLDisplay)
    #     display(plt.o)
    # end
    # PyPlot.ion()
    PyPlot.pygui(false)
    plt.o[:show]()
    PyPlot.pygui(true)
    # PyPlot.ioff()
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
    @eval function _writemime(io::IO, ::MIME{Symbol($mime)}, plt::Plot{PyPlotBackend})
        fig = plt.o
        fig.o["canvas"][:print_figure](
            io,
            format=$fmt,
            # bbox_inches = "tight",
            # figsize = map(px2inch, plt[:size]),
            facecolor = fig.o["get_facecolor"](),
            edgecolor = "none",
            dpi = DPI
        )
    end
end
