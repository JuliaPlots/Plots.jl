
# https://github.com/stevengj/PyPlot.jl


supported_args(::PyPlotBackend) = merge_with_base_supported([
    :annotations,
    :background_color_legend, :background_color_inside, :background_color_outside,
    :foreground_color_grid, :foreground_color_legend, :foreground_color_title,
    :foreground_color_axis, :foreground_color_border, :foreground_color_guide, :foreground_color_text,
    :label,
    :linecolor, :linestyle, :linewidth, :linealpha,
    :markershape, :markercolor, :markersize, :markeralpha,
    :markerstrokewidth, :markerstrokecolor, :markerstrokealpha,
    :fillrange, :fillcolor, :fillalpha,
    :bins, :bar_width, :bar_edges, :bar_position,
    :title, :title_location, :titlefont,
    :window_title,
    :guide, :lims, :ticks, :scale, :flip, :rotation,
    :tickfont, :guidefont, :legendfont,
    :grid, :legend, :colorbar,
    :marker_z,
    :line_z,
    :levels,
    :ribbon, :quiver, :arrow,
    :orientation,
    :overwrite_figure,
    :polar,
    :normalize, :weights,
    :contours, :aspect_ratio,
    :match_dimensions,
    :clims,
    :inset_subplots,
    :dpi,
  ])
supported_types(::PyPlotBackend) = [
        :path, :steppre, :steppost, :shape,
        :scatter, :hexbin, #:histogram2d, :histogram,
        # :bar,
        :heatmap, :pie, :image,
        :contour, :contour3d, :path3d, :scatter3d, :surface, :wireframe
    ]
supported_styles(::PyPlotBackend) = [:auto, :solid, :dash, :dot, :dashdot]
supported_markers(::PyPlotBackend) = vcat(_allMarkers, Shape)
supported_scales(::PyPlotBackend) = [:identity, :ln, :log2, :log10]
is_subplot_supported(::PyPlotBackend) = true


# --------------------------------------------------------------------------------------


function _initialize_backend(::PyPlotBackend)
    @eval begin
        # problem: https://github.com/tbreloff/Plots.jl/issues/308
        # solution: hack from @stevengj: https://github.com/stevengj/PyPlot.jl/pull/223#issuecomment-229747768
        otherdisplays = splice!(Base.Multimedia.displays, 2:length(Base.Multimedia.displays))
        import PyPlot
        import LaTeXStrings: latexstring
        append!(Base.Multimedia.displays, otherdisplays)

        export PyPlot
        const pycolors = PyPlot.pywrap(PyPlot.pyimport("matplotlib.colors"))
        const pypath = PyPlot.pywrap(PyPlot.pyimport("matplotlib.path"))
        const mplot3d = PyPlot.pywrap(PyPlot.pyimport("mpl_toolkits.mplot3d"))
        const pypatches = PyPlot.pywrap(PyPlot.pyimport("matplotlib.patches"))
        const pyfont = PyPlot.pywrap(PyPlot.pyimport("matplotlib.font_manager"))
        const pyticker = PyPlot.pywrap(PyPlot.pyimport("matplotlib.ticker"))
        const pycmap = PyPlot.pywrap(PyPlot.pyimport("matplotlib.cm"))
        const pynp = PyPlot.pywrap(PyPlot.pyimport("numpy"))
        pynp.seterr(invalid="ignore")
        const pytransforms = PyPlot.pywrap(PyPlot.pyimport("matplotlib.transforms"))
        const pycollections = PyPlot.pywrap(PyPlot.pyimport("matplotlib.collections"))
        const pyart3d = PyPlot.pywrap(PyPlot.pyimport("mpl_toolkits.mplot3d.art3d"))
    end

    # we don't want every command to update the figure
    PyPlot.ioff()
end

# --------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------

# # convert colorant to 4-tuple RGBA
# py_color(c::Colorant, α=nothing) = map(f->float(f(convertColor(c,α))), (red, green, blue, alpha))
# py_color(cvec::ColorVector, α=nothing) = map(py_color, convertColor(cvec, α).v)
# py_color(grad::ColorGradient, α=nothing) = map(c -> py_color(c, α), grad.colors)
# py_color(scheme::ColorScheme, α=nothing) = py_color(convertColor(getColor(scheme), α))
# py_color(vec::AVec, α=nothing) = map(c->py_color(c,α), vec)
# py_color(c, α=nothing) = py_color(convertColor(c, α))

# function py_colormap(c::ColorGradient, α=nothing)
#     pyvals = [(v, py_color(getColorZ(c, v), α)) for v in c.values]
#     pycolors.pymember("LinearSegmentedColormap")[:from_list]("tmp", pyvals)
# end

# # convert vectors and ColorVectors to standard ColorGradients
# # TODO: move this logic to colors.jl and keep a barebones wrapper for pyplot
# py_colormap(cv::ColorVector, α=nothing) = py_colormap(ColorGradient(cv.v), α)
# py_colormap(v::AVec, α=nothing) = py_colormap(ColorGradient(v), α)

# # anything else just gets a bluesred gradient
# py_colormap(c, α=nothing) = py_colormap(default_gradient(), α)

py_color(c::Colorant) = (red(c), green(c), blue(c), alpha(c))
py_color(cs::AVec) = map(py_color, cs)
py_color(grad::ColorGradient) = py_color(grad.colors)

function py_colormap(grad::ColorGradient)
    pyvals = [(z, py_color(grad[z])) for z in grad.values]
    pycolors.LinearSegmentedColormap[:from_list]("tmp", pyvals)
end
py_colormap(c) = py_colormap(cgrad())


function py_shading(c, z, α=nothing)
    cmap = py_colormap(c, α)
    ls = pycolors.pymember("LightSource")(270,45)
    ls[:shade](z, cmap, vert_exag=0.1, blend_mode="soft")
end

# get the style (solid, dashed, etc)
function py_linestyle(seriestype::Symbol, linestyle::Symbol)
    seriestype == :none && return " "
    linestyle == :solid && return "-"
    linestyle == :dash && return "--"
    linestyle == :dot && return ":"
    linestyle == :dashdot && return "-."
    warn("Unknown linestyle $linestyle")
    return "-"
end

function py_marker(marker::Shape)
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

# # see http://matplotlib.org/users/path_tutorial.html
# # and http://matplotlib.org/api/path_api.html#matplotlib.path.Path
# function py_path(x, y)
#     n = length(x)
#     mat = zeros(n+1, 2)
#     codes = zeros(UInt8, n+1)
#     lastnan = true
#     for i=1:n
#         mat[i,1] = x[i]
#         mat[i,2] = y[i]
#         nan = !ok(x[i], y[i])
#         codes[i] = if nan && i>1
#             _path_CLOSEPOLY
#         else
#             lastnan ? _path_MOVETO : _path_LINETO
#         end
#         lastnan = nan
#     end
#     codes[n+1] = _path_CLOSEPOLY
#     pypath.pymember("Path")(mat, codes)
# end

# get the marker shape
function py_marker(marker::Symbol)
    marker == :none && return " "
    marker == :circle && return "o"
    marker == :rect && return "s"
    marker == :diamond && return "D"
    marker == :utriangle && return "^"
    marker == :dtriangle && return "v"
    marker == :+ && return "+"
    marker == :x && return "x"
    marker == :star5 && return "*"
    marker == :pentagon && return "p"
    marker == :hexagon && return "h"
    marker == :octagon && return "8"
    haskey(_shapes, marker) && return py_marker(_shapes[marker])

    warn("Unknown marker $marker")
    return "o"
end

# py_marker(markers::AVec) = map(py_marker, markers)
function py_marker(markers::AVec)
    warn("Vectors of markers are currently unsupported in PyPlot: $markers")
    py_marker(markers[1])
end

# pass through
function py_marker(marker::AbstractString)
    @assert length(marker) == 1
    marker
end

function py_stepstyle(seriestype::Symbol)
    seriestype == :steppost && return "steps-post"
    seriestype == :steppre && return "steps-pre"
    return "default"
end

# # untested... return a FontProperties object from a Plots.Font
# function py_font(font::Font)
#     pyfont.pymember("FontProperties")(
#         family = font.family,
#         size = font.size
#     )
# end

function get_locator_and_formatter(vals::AVec)
    pyticker.pymember("FixedLocator")(1:length(vals)), pyticker.pymember("FixedFormatter")(vals)
end

function add_pyfixedformatter(cbar, vals::AVec)
    cbar[:locator], cbar[:formatter] = get_locator_and_formatter(vals)
    cbar[:update_ticks]()
end


function labelfunc(scale::Symbol, backend::PyPlotBackend)
    if scale == :log10
        x -> latexstring("10^{$x}")
    elseif scale == :log2
        x -> latexstring("2^{$x}")
    elseif scale == :ln
        x -> latexstring("e^{$x}")
    else
        string
    end
end

# ---------------------------------------------------------------------------

function fix_xy_lengths!(plt::Plot{PyPlotBackend}, series::Series)
    x, y = series[:x], series[:y]
    nx, ny = length(x), length(y)
    if !isa(get(series.d, :z, nothing), Surface) && nx != ny
        if nx < ny
            series[:x] = Float64[x[mod1(i,nx)] for i=1:ny]
        else
            series[:y] = Float64[y[mod1(i,ny)] for i=1:nx]
        end
    end
end

# total hack due to PyPlot bug (see issue #145).
# hack: duplicate the color vector when the total rgba fields is the same as the series length
function py_color_fix(c, x)
    if (typeof(c) <: AbstractArray && length(c)*4 == length(x)) ||
                    (typeof(c) <: Tuple && length(x) == 4)
        vcat(c, c)
    else
        c
    end
end

py_linecolor(series::Series)          = py_color(series[:linecolor])
py_markercolor(series::Series)        = py_color(series[:markercolor])
py_markerstrokecolor(series::Series)  = py_color(series[:markerstrokecolor])
py_fillcolor(series::Series)          = py_color(series[:fillcolor])

py_linecolormap(series::Series)       = py_colormap(series[:linecolor])
py_markercolormap(series::Series)     = py_colormap(series[:markercolor])
py_fillcolormap(series::Series)       = py_colormap(series[:fillcolor])

# ---------------------------------------------------------------------------

# TODO: these can probably be removed eventually... right now they're just keeping things working before cleanup

# getAxis(sp::Subplot) = sp.o

# function getAxis(plt::Plot{PyPlotBackend}, series::Series)
#     sp = get_subplot(plt, get(series.d, :subplot, 1))
#     getAxis(sp)
# end

# getfig(o) = o

# ---------------------------------------------------------------------------
# Figure utils -- F*** matplotlib for making me work so hard to figure this crap out

# the drawing surface
py_canvas(fig) = fig[:canvas]

# the object controlling draw commands
py_renderer(fig) = py_canvas(fig)[:get_renderer]()

# draw commands... paint the screen (probably updating internals too)
py_drawfig(fig) = fig[:draw](py_renderer(fig))
# py_drawax(ax) = ax[:draw](py_renderer(ax[:get_figure]()))

# get a vector [left, right, bottom, top] in PyPlot coords (origin is bottom-left!)
py_extents(obj) = obj[:get_window_extent]()[:get_points]()


# compute a bounding box (with origin top-left), however pyplot gives coords with origin bottom-left
function py_bbox(obj)
    fl, fr, fb, ft = py_extents(obj[:get_figure]())
    l, r, b, t = py_extents(obj)
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

function py_dpi_scale(plt::Plot{PyPlotBackend}, ptsz)
    ptsz * DPI / plt[:dpi]
end

# ---------------------------------------------------------------------------

# Create the window/figure for this backend.
function _create_backend_figure(plt::Plot{PyPlotBackend})
    w,h = map(px2inch, plt[:size])

    # # reuse the current figure?
    fig = if plt[:overwrite_figure]
        PyPlot.gcf()
    else
        fig = PyPlot.figure()
        # finalizer(fig, close)
        fig
    end

    # clear the figure
    # PyPlot.clf()
    fig
end

# Set up the subplot within the backend object.
# function _initialize_subplot(plt::Plot{PyPlotBackend}, sp::Subplot{PyPlotBackend})

function py_init_subplot(plt::Plot{PyPlotBackend}, sp::Subplot{PyPlotBackend})
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
# function _series_added(plt::Plot{PyPlotBackend}, series::Series)

function py_add_series(plt::Plot{PyPlotBackend}, series::Series)
    # d = series.d
    st = series[:seriestype]
    sp = series[:subplot]
    ax = sp.o

    if !(st in supported_types(plt.backend))
        error("seriestype $(st) is unsupported in PyPlot.  Choose from: $(supported_types(plt.backend))")
    end

    # PyPlot doesn't handle mismatched x/y
    fix_xy_lengths!(plt, series)

    # ax = getAxis(plt, series)
    x, y, z = series[:x], series[:y], series[:z]
    xyargs = (st in _3dTypes ? (x,y,z) : (x,y))

    # handle zcolor and get c/cmap
    extrakw = KW()

    # holds references to any python object representing the matplotlib series
    handles = []
    needs_colorbar = false
    discrete_colorbar_values = nothing


    # pass in an integer value as an arg, but a levels list as a keyword arg
    levels = series[:levels]
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
    if st in (:path, :path3d, :steppre, :steppost)
        if series[:linewidth] > 0
            if series[:line_z] == nothing
                handle = ax[:plot](xyargs...;
                    label = series[:label],
                    zorder = series[:series_plotindex],
                    color = py_linecolor(series),
                    linewidth = py_dpi_scale(plt, series[:linewidth]),
                    linestyle = py_linestyle(st, series[:linestyle]),
                    solid_capstyle = "round",
                    drawstyle = py_stepstyle(st)
                )[1]
                push!(handles, handle)

            else
                # multicolored line segments
                n = length(x) - 1
                # segments = Array(Any,n)
                segments = []
                kw = KW(
                    :label => series[:label],
                    :zorder => plt.n,
                    :cmap => py_linecolormap(series),
                    :linewidth => py_dpi_scale(plt, series[:linewidth]),
                    :linestyle => py_linestyle(st, series[:linestyle])
                )
                clims = sp[:clims]
                if is_2tuple(clims)
                    extrakw = KW()
                    isfinite(clims[1]) && (extrakw[:vmin] = clims[1])
                    isfinite(clims[2]) && (extrakw[:vmax] = clims[2])
                    kw[:norm] = pycolors.Normalize(; extrakw...)
                end
                lz = collect(series[:line_z])
                handle = if is3d(st)
                    for rng in iter_segments(x, y, z)
                        length(rng) < 2 && continue
                        push!(segments, [(cycle(x,i),cycle(y,i),cycle(z,i)) for i in rng])
                    end
                    # for i=1:n
                    #     segments[i] = [(cycle(x,i), cycle(y,i), cycle(z,i)), (cycle(x,i+1), cycle(y,i+1), cycle(z,i+1))]
                    # end
                    lc = pyart3d.Line3DCollection(segments; kw...)
                    lc[:set_array](lz)
                    ax[:add_collection3d](lc, zs=z) #, zdir='y')
                    lc
                else
                    for rng in iter_segments(x, y)
                        length(rng) < 2 && continue
                        push!(segments, [(cycle(x,i),cycle(y,i)) for i in rng])
                    end
                    # for i=1:n
                    #     segments[i] = [(cycle(x,i), cycle(y,i)), (cycle(x,i+1), cycle(y,i+1))]
                    # end
                    lc = pycollections.LineCollection(segments; kw...)
                    lc[:set_array](lz)
                    ax[:add_collection](lc)
                    lc
                end
                push!(handles, handle)
                needs_colorbar = true
            end

            a = series[:arrow]
            if a != nothing && !is3d(st)  # TODO: handle 3d later
                if typeof(a) != Arrow
                    warn("Unexpected type for arrow: $(typeof(a))")
                else
                    arrowprops = KW(
                        :arrowstyle => "simple,head_length=$(a.headlength),head_width=$(a.headwidth)",
                        :shrinkA => 0,
                        :shrinkB => 0,
                        :edgecolor => py_linecolor(series),
                        :facecolor => py_linecolor(series),
                        :linewidth => py_dpi_scale(plt, series[:linewidth]),
                        :linestyle => py_linestyle(st, series[:linestyle]),
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

    # add markers?
    if series[:markershape] != :none && st in (:path, :scatter, :path3d,
                                          :scatter3d, :steppre, :steppost,
                                          :bar)
        extrakw = KW()
        if series[:marker_z] == nothing
            extrakw[:c] = py_color_fix(py_markercolor(series), x)
        else
            extrakw[:c] = convert(Vector{Float64}, series[:marker_z])
            extrakw[:cmap] = py_markercolormap(series)
            clims = sp[:clims]
            if is_2tuple(clims)
                isfinite(clims[1]) && (extrakw[:vmin] = clims[1])
                isfinite(clims[2]) && (extrakw[:vmax] = clims[2])
            end
            needs_colorbar = true
        end
        xyargs = if st == :bar && !isvertical(series)
            (y, x)
        else
            xyargs
        end
        handle = ax[:scatter](xyargs...;
            label = series[:label],
            zorder = series[:series_plotindex] + 0.5,
            marker = py_marker(series[:markershape]),
            s = py_dpi_scale(plt, series[:markersize] .^ 2),
            edgecolors = py_markerstrokecolor(series),
            linewidths = py_dpi_scale(plt, series[:markerstrokewidth]),
            extrakw...
        )
        push!(handles, handle)
    end

    if st == :hexbin
        clims = sp[:clims]
        if is_2tuple(clims)
            isfinite(clims[1]) && (extrakw[:vmin] = clims[1])
            isfinite(clims[2]) && (extrakw[:vmax] = clims[2])
        end
        handle = ax[:hexbin](x, y;
            label = series[:label],
            zorder = series[:series_plotindex],
            gridsize = series[:bins],
            linewidths = py_dpi_scale(plt, series[:linewidth]),
            edgecolors = py_linecolor(series),
            cmap = py_fillcolormap(series),  # applies to the pcolorfast object
            extrakw...
        )
        push!(handles, handle)
        needs_colorbar = true
    end

    if st in (:contour, :contour3d)
        z = transpose_z(series, z.surf)
        needs_colorbar = true

        clims = sp[:clims]
        if is_2tuple(clims)
            isfinite(clims[1]) && (extrakw[:vmin] = clims[1])
            isfinite(clims[2]) && (extrakw[:vmax] = clims[2])
        end

        if st == :contour3d
            extrakw[:extend3d] = true
        end

        # contour lines
        handle = ax[:contour](x, y, z, levelargs...;
            label = series[:label],
            zorder = series[:series_plotindex],
            linewidths = py_dpi_scale(plt, series[:linewidth]),
            linestyles = py_linestyle(st, series[:linestyle]),
            cmap = py_linecolormap(series),
            extrakw...
        )
        push!(handles, handle)

        # contour fills
        if series[:fillrange] != nothing
            handle = ax[:contourf](x, y, z, levelargs...;
                label = series[:label],
                zorder = series[:series_plotindex] + 0.5,
                cmap = py_fillcolormap(series),
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
                y = repmat(y, 1, length(series[:x]))
            end
            # z = z'
            z = transpose_z(series, z)
            if st == :surface
                if series[:marker_z] != nothing
                    extrakw[:facecolors] = py_shading(series[:fillcolor], series[:marker_z], series[:fillalpha])
                    extrakw[:shade] = false
                    clims = sp[:clims]
                    if is_2tuple(clims)
                        isfinite(clims[1]) && (extrakw[:vmin] = clims[1])
                        isfinite(clims[2]) && (extrakw[:vmax] = clims[2])
                    end
                else
                    extrakw[:cmap] = py_fillcolormap(series)
                    needs_colorbar = true
                end
            end
            handle = ax[st == :surface ? :plot_surface : :plot_wireframe](x, y, z;
                label = series[:label],
                zorder = series[:series_plotindex],
                rstride = 1,
                cstride = 1,
                linewidth = py_dpi_scale(plt, series[:linewidth]),
                edgecolor = py_linecolor(series),
                extrakw...
            )
            push!(handles, handle)

            # contours on the axis planes
            if series[:contours]
                for (zdir,mat) in (("x",x), ("y",y), ("z",z))
                    offset = (zdir == "y" ? maximum : minimum)(mat)
                    handle = ax[:contourf](x, y, z, levelargs...;
                        zdir = zdir,
                        cmap = py_fillcolormap(series),
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
            clims = sp[:clims]
            if is_2tuple(clims)
                isfinite(clims[1]) && (extrakw[:vmin] = clims[1])
                isfinite(clims[2]) && (extrakw[:vmax] = clims[2])
            end
            handle = ax[:plot_trisurf](x, y, z;
                label = series[:label],
                zorder = series[:series_plotindex],
                cmap = py_fillcolormap(series),
                linewidth = py_dpi_scale(plt, series[:linewidth]),
                edgecolor = py_linecolor(series),
                extrakw...
            )
            push!(handles, handle)
            needs_colorbar = true
        else
            error("Unsupported z type $(typeof(z)) for seriestype=$st")
        end
    end

    if st == :image
        # @show typeof(z)
        img = Array(transpose_z(series, z.surf))
        z = if eltype(img) <: Colors.AbstractGray
            float(img)
        elseif eltype(img) <: Colorant
            map(c -> Float64[red(c),green(c),blue(c)], img)
        else
            z  # hopefully it's in a data format that will "just work" with imshow
        end
        handle = ax[:imshow](z;
            zorder = series[:series_plotindex],
            cmap = py_colormap([:black, :white]),
            vmin = 0.0,
            vmax = 1.0
        )
        push!(handles, handle)

        # expand extrema... handle is AxesImage object
        xmin, xmax, ymax, ymin = handle[:get_extent]()
        expand_extrema!(sp, xmin, xmax, ymin, ymax)
        # sp[:yaxis].series[:flip] = true
    end

    if st == :heatmap
        x, y, z = heatmap_edges(x), heatmap_edges(y), transpose_z(series, z.surf)

        expand_extrema!(sp[:xaxis], x)
        expand_extrema!(sp[:yaxis], y)
        dvals = sp[:zaxis][:discrete_values]
        if !isempty(dvals)
            discrete_colorbar_values = dvals
        end

        clims = sp[:clims]
        if is_2tuple(clims)
            isfinite(clims[1]) && (extrakw[:vmin] = clims[1])
            isfinite(clims[2]) && (extrakw[:vmax] = clims[2])
        end
        
        handle = ax[:pcolormesh](x, y, z;
            label = series[:label],
            zorder = series[:series_plotindex],
            cmap = py_fillcolormap(series),
            # edgecolors = (series[:linewidth] > 0 ? py_linecolor(series) : "face"),
            extrakw...
        )
        push!(handles, handle)
        needs_colorbar = true
    end

    if st == :shape
        handle = []
        for (i,rng) in enumerate(iter_segments(x, y))
            if length(rng) > 1
                path = pypath.pymember("Path")(hcat(x[rng], y[rng]))
                patches = pypatches.pymember("PathPatch")(
                    path;
                    label = series[:label],
                    zorder = series[:series_plotindex],
                    edgecolor = py_color(cycle(series[:linecolor], i)),
                    facecolor = py_color(cycle(series[:fillcolor], i)),
                    linewidth = py_dpi_scale(plt, series[:linewidth]),
                    fill = true
                )
                push!(handle, ax[:add_patch](patches))
            end
        end
        # path = py_path(x, y)
        # patches = pypatches.pymember("PathPatch")(path;
        #     label = series[:label],
        #     zorder = series[:series_plotindex],
        #     edgecolor = py_linecolor(series),
        #     facecolor = py_fillcolor(series),
        #     linewidth = py_dpi_scale(plt, series[:linewidth]),
        #     fill = true
        # )
        # handle = ax[:add_patch](patches)
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

    series[:serieshandle] = handles

    # # smoothing
    # handleSmooth(plt, ax, series, series[:smooth])

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
    fillrange = series[:fillrange]
    if fillrange != nothing && st != :contour
        f, dim1, dim2 = if isvertical(series)
            :fill_between, x, y
        else
            :fill_betweenx, y, x
        end
        n = length(dim1)
        args = if typeof(fillrange) <: Union{Real, AVec}
            dim1, expand_data(fillrange, n), dim2
        elseif is_2tuple(fillrange)
            dim1, expand_data(fillrange[1], n), expand_data(fillrange[2], n)
        end

        handle = ax[f](args...;
            zorder = series[:series_plotindex],
            facecolor = py_fillcolor(series),
            linewidths = 0
        )
        push!(handles, handle)
    end
end

# --------------------------------------------------------------------------

function py_set_lims(ax, axis::Axis)
    letter = axis[:letter]
    lfrom, lto = axis_limits(axis)
    ax[Symbol("set_", letter, "lim")](lfrom, lto)
end

function py_set_ticks(ax, ticks, letter)
    ticks == :auto && return
    axis = ax[Symbol(letter,"axis")]
    if ticks == :none || ticks == nothing || ticks == false
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

function py_compute_axis_minval(axis::Axis)
    # compute the smallest absolute value for the log scale's linear threshold
    minval = 1.0
    sp = axis.sp
    for series in series_list(axis.sp)
        v = series.d[axis[:letter]]
        if !isempty(v)
            minval = min(minval, minimum(abs(v)))
        end
    end

    # now if the axis limits go to a smaller abs value, use that instead
    vmin, vmax = axis_limits(axis)
    minval = min(minval, abs(vmin), abs(vmax))

    minval
end

function py_set_scale(ax, axis::Axis)
    scale = axis[:scale]
    letter = axis[:letter]
    scale in supported_scales() || return warn("Unhandled scale value in pyplot: $scale")
    func = ax[Symbol("set_", letter, "scale")]
    kw = KW()
    arg = if scale == :identity
        "linear"
    else
        kw[Symbol(:base,letter)] = if scale == :ln
            e
        elseif scale == :log2
            2
        elseif scale == :log10
            10
        end
        kw[Symbol(:linthresh,letter)] = max(1e-16, py_compute_axis_minval(axis))
        "symlog"
    end
    func(arg; kw...)
end


function py_set_axis_colors(ax, a::Axis)
    for (loc, spine) in ax[:spines]
        spine[:set_color](py_color(a[:foreground_color_border]))
    end
    axissym = Symbol(a[:letter], :axis)
    if haskey(ax, axissym)
        ax[:tick_params](axis=string(a[:letter]), which="both",
                         colors=py_color(a[:foreground_color_axis]),
                         labelcolor=py_color(a[:foreground_color_text]))
        ax[axissym][:label][:set_color](py_color(a[:foreground_color_guide]))
    end
end


# --------------------------------------------------------------------------


function _before_layout_calcs(plt::Plot{PyPlotBackend})
    # update the fig
    w, h = plt[:size]
    fig = plt.o
    fig[:clear]()
    dpi = plt[:dpi]
    fig[:set_size_inches](w/dpi, h/dpi, forward = true)
    fig[:set_facecolor](py_color(plt[:background_color_outside]))
    fig[:set_dpi](dpi)
    
    # resize the window
    PyPlot.plt[:get_current_fig_manager]()[:resize](w, h)

    # initialize subplots
    for sp in plt.subplots
        py_init_subplot(plt, sp)
    end

    # add the series
    for series in plt.series_list
        py_add_series(plt, series)
    end

    # update subplots
    for sp in plt.subplots
        ax = sp.o
        if ax == nothing
            continue
        end

        # add the annotations
        for ann in sp[:annotations]
            py_add_annotations(sp, ann...)
        end

        # title
        if sp[:title] != ""
            loc = lowercase(string(sp[:title_location]))
            func = if loc == "left"
                :_left_title
            elseif loc == "right"
                :_right_title
            else
                :title
            end
            ax[func][:set_text](sp[:title])
            ax[func][:set_fontsize](py_dpi_scale(plt, sp[:titlefont].pointsize))
            ax[func][:set_color](py_color(sp[:foreground_color_title]))
            # ax[:set_title](sp[:title], loc = loc)
        end

        # axis attributes
        for letter in (:x, :y, :z)
            axissym = Symbol(letter, :axis)
            axis = sp[axissym]
            haskey(ax, axissym) || continue
            py_set_scale(ax, axis)
            py_set_lims(ax, axis)
            py_set_ticks(ax, get_ticks(axis), letter)
            ax[Symbol("set_", letter, "label")](axis[:guide])
            if get(axis.d, :flip, false)
                ax[Symbol("invert_", letter, "axis")]()
            end
            ax[axissym][:label][:set_fontsize](py_dpi_scale(plt, axis[:guidefont].pointsize))
            for lab in ax[Symbol("get_", letter, "ticklabels")]()
                lab[:set_fontsize](py_dpi_scale(plt, axis[:tickfont].pointsize))
                lab[:set_rotation](axis[:rotation])
            end
            if sp[:grid]
                fgcolor = py_color(sp[:foreground_color_grid])
                ax[axissym][:grid](true, color = fgcolor)
                ax[:set_axisbelow](true)
            end
            py_set_axis_colors(ax, axis)
        end

        # aspect ratio
        aratio = sp[:aspect_ratio]
        if aratio != :none
            ax[:set_aspect](isa(aratio, Symbol) ? string(aratio) : aratio, anchor = "C")
        end

        # legend
        py_add_legend(plt, sp, ax)

        # this sets the bg color inside the grid
        ax[:set_axis_bgcolor](py_color(sp[:background_color_inside]))
    end
    py_drawfig(fig)
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
    leftpad   = 0mm
    toppad    = 0mm
    rightpad  = 0mm
    bottompad = 0mm
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

    # add in the user-specified margin
    leftpad   += sp[:left_margin]
    toppad    += sp[:top_margin]
    rightpad  += sp[:right_margin]
    bottompad += sp[:bottom_margin]

    sp.minpad = (leftpad, toppad, rightpad, bottompad)
end


# -----------------------------------------------------------------

function py_add_annotations(sp::Subplot{PyPlotBackend}, x, y, val)
    ax = sp.o
    ax[:annotate](val, xy = (x,y), zorder = 999)
end


function py_add_annotations(sp::Subplot{PyPlotBackend}, x, y, val::PlotText)
    ax = sp.o
    ax[:annotate](val.str,
        xy = (x,y),
        family = val.font.family,
        color = py_color(val.font.color),
        horizontalalignment = val.font.halign == :hcenter ? "center" : string(val.font.halign),
        verticalalignment = val.font.valign == :vcenter ? "center" : string(val.font.valign),
        rotation = val.font.rotation * 180 / π,
        size = py_dpi_scale(sp.plt, val.font.pointsize),
        zorder = 999
    )
end

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

function py_add_legend(plt::Plot, sp::Subplot, ax)
    leg = sp[:legend]
    if leg != :none
        # gotta do this to ensure both axes are included
        labels = []
        handles = []
        for series in series_list(sp)
            if should_add_to_legend(series)
                # add a line/marker and a label
                push!(handles, if series[:seriestype] == :shape
                    PyPlot.plt[:Line2D]((0,1),(0,0),
                        color = py_color(cycle(series[:fillcolor],1)),
                        linewidth = py_dpi_scale(plt, 4)
                    )
                else
                    series[:serieshandle][1]
                end)
                push!(labels, series[:label])
            end
        end

        # if anything was added, call ax.legend and set the colors
        if !isempty(handles)
            leg = ax[:legend](handles,
                labels,
                loc = get(_pyplot_legend_pos, leg, "best"),
                scatterpoints = 1,
                fontsize = py_dpi_scale(plt, sp[:legendfont].pointsize)
                # framealpha = 0.6
            )
            leg[:set_zorder](1000)

            fgcolor = py_color(sp[:foreground_color_legend])
            for txt in leg[:get_texts]()
                PyPlot.plt[:setp](txt, color = fgcolor)
            end

            # set some legend properties
            frame = leg[:get_frame]()
            frame[:set_facecolor](py_color(sp[:background_color_legend]))
            frame[:set_edgecolor](fgcolor)
        end
    end
end

# -----------------------------------------------------------------


# Use the bounding boxes (and methods left/top/right/bottom/width/height) `sp.bbox` and `sp.plotarea` to
# position the subplot in the backend.
function _update_plot_object(plt::Plot{PyPlotBackend})
    for sp in plt.subplots
        ax = sp.o
        ax == nothing && return
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
    plt.o[:show]()
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
    @eval function _show(io::IO, ::MIME{Symbol($mime)}, plt::Plot{PyPlotBackend})
        fig = plt.o
        fig[:canvas][:print_figure](
            io,
            format=$fmt,
            # bbox_inches = "tight",
            # figsize = map(px2inch, plt[:size]),
            facecolor = fig[:get_facecolor](),
            edgecolor = "none",
            dpi = plt[:dpi]
        )
    end
end
