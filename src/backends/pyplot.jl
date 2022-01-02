
# https://github.com/stevengj/PyPlot.jl

is_marker_supported(::PyPlotBackend, shape::Shape) = true

# --------------------------------------------------------------------------------------

# problem: https://github.com/tbreloff/Plots.jl/issues/308
# solution: hack from @stevengj: https://github.com/stevengj/PyPlot.jl/pull/223#issuecomment-229747768
otherdisplays = splice!(Base.Multimedia.displays, 2:length(Base.Multimedia.displays))
append!(Base.Multimedia.displays, otherdisplays)
pycolors = PyPlot.pyimport("matplotlib.colors")
pypath = PyPlot.pyimport("matplotlib.path")
mplot3d = PyPlot.pyimport("mpl_toolkits.mplot3d")
axes_grid1 = PyPlot.pyimport("mpl_toolkits.axes_grid1")
pypatches = PyPlot.pyimport("matplotlib.patches")
pyfont = PyPlot.pyimport("matplotlib.font_manager")
pyticker = PyPlot.pyimport("matplotlib.ticker")
pycmap = PyPlot.pyimport("matplotlib.cm")
pynp = PyPlot.pyimport("numpy")
pynp."seterr"(invalid = "ignore")
pytransforms = PyPlot.pyimport("matplotlib.transforms")
pycollections = PyPlot.pyimport("matplotlib.collections")
pyart3d = PyPlot.art3D
pyrcparams = PyPlot.PyDict(PyPlot.matplotlib."rcParams")

# "support" matplotlib v3.4
if PyPlot.version < v"3.4"
    @warn("""You are using Matplotlib $(PyPlot.version), which is no longer
    officialy supported by the Plots community. To ensure smooth Plots.jl
    integration update your Matplotlib library to a version >= 3.4.0

    If you have used Conda.jl to install PyPlot (default installation),
    upgrade your matplotlib via Conda.jl and rebuild the PyPlot.

    If you are not sure, here are the default instructions:

    In Julia REPL:
    ```
    import Pkg;
    Pkg.add("Conda")
    import Conda
    Conda.update()
    Pkg.build("PyPlot")
    ```

    """)
end

set_facecolor_sym = if PyPlot.version < v"2"
    :set_axis_bgcolor
else
    :set_facecolor
end

# PyCall API changes in v1.90.0
if !isdefined(PyPlot.PyCall, :_setproperty!)
    @warn "Plots no longer supports PyCall < 1.90.0 and PyPlot < 2.8.0. Either update PyCall and PyPlot or pin Plots to a version <= 0.23.2."
end

# # convert colorant to 4-tuple RGBA
# py_color(c::Colorant, α=nothing) = map(f->float(f(convertColor(c,α))), (red, green, blue, alpha))
# py_color(cvec::ColorVector, α=nothing) = map(py_color, convertColor(cvec, α).v)
# py_color(grad::ColorGradient, α=nothing) = map(c -> py_color(c, α), grad.colors)
# py_color(scheme::ColorScheme, α=nothing) = py_color(convertColor(getColor(scheme), α))
# py_color(vec::AVec, α=nothing) = map(c->py_color(c,α), vec)
# py_color(c, α=nothing) = py_color(convertColor(c, α))

# function py_colormap(c::ColorGradient, α=nothing)
#     pyvals = [(v, py_color(getColorZ(c, v), α)) for v in c.values]
#     pycolors["LinearSegmentedColormap"][:from_list]("tmp", pyvals)
# end

# # convert vectors and ColorVectors to standard ColorGradients
# # TODO: move this logic to colors.jl and keep a barebones wrapper for pyplot
# py_colormap(cv::ColorVector, α=nothing) = py_colormap(ColorGradient(cv.v), α)
# py_colormap(v::AVec, α=nothing) = py_colormap(ColorGradient(v), α)

# # anything else just gets a bluesred gradient
# py_colormap(c, α=nothing) = py_colormap(default_gradient(), α)

for k in (:linthresh, :base, :label)
    # add PyPlot specific symbols to cache
    _attrsymbolcache[k] = Dict{Symbol,Symbol}()
    for letter in (:x, :y, :z, Symbol(""), :top, :bottom, :left, :right)
        _attrsymbolcache[k][letter] = Symbol(k, letter)
    end
end

py_handle_surface(v) = v
py_handle_surface(z::Surface) = z.surf

py_color(s) = py_color(parse(Colorant, string(s)))
py_color(c::Colorant) = (red(c), green(c), blue(c), alpha(c))
py_color(cs::AVec) = map(py_color, cs)
py_color(grad::PlotUtils.AbstractColorList) = py_color(color_list(grad))
py_color(c::Colorant, α) = py_color(plot_color(c, α))

function py_colormap(cg::ColorGradient)
    pyvals = collect(zip(cg.values, py_color(PlotUtils.color_list(cg))))
    cm = pycolors."LinearSegmentedColormap"."from_list"("tmp", pyvals)
    cm."set_bad"(color = (0, 0, 0, 0.0), alpha = 0.0)
    cm
end
function py_colormap(cg::PlotUtils.CategoricalColorGradient)
    r = range(0, stop = 1, length = 256)
    pyvals = collect(zip(r, py_color(cg[r])))
    cm = pycolors."LinearSegmentedColormap"."from_list"("tmp", pyvals)
    cm."set_bad"(color = (0, 0, 0, 0.0), alpha = 0.0)
    cm
end
py_colormap(c) = py_colormap(_as_gradient(c))

function py_shading(c, z)
    cmap = py_colormap(c)
    ls = pycolors."LightSource"(270, 45)
    ls."shade"(z, cmap, vert_exag = 0.1, blend_mode = "soft")
end

# get the style (solid, dashed, etc)
function py_linestyle(seriestype::Symbol, linestyle::Symbol)
    seriestype == :none && return " "
    linestyle == :solid && return "-"
    linestyle == :dash && return "--"
    linestyle == :dot && return ":"
    linestyle == :dashdot && return "-."
    @warn("Unknown linestyle $linestyle")
    return "-"
end

function py_marker(marker::Shape)
    x, y = coords(marker)
    n = length(x)
    mat = zeros(n + 1, 2)
    for i in 1:n
        mat[i, 1] = x[i]
        mat[i, 2] = y[i]
    end
    mat[n + 1, :] = mat[1, :]
    pypath."Path"(mat)
end

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
    marker == :pixel && return ","
    marker == :hline && return "_"
    marker == :vline && return "|"
    haskey(_shapes, marker) && return py_marker(_shapes[marker])

    @warn("Unknown marker $marker")
    return "o"
end

# py_marker(markers::AVec) = map(py_marker, markers)
function py_marker(markers::AVec)
    @warn("Vectors of markers are currently unsupported in PyPlot: $markers")
    py_marker(markers[1])
end

# pass through
function py_marker(marker::AbstractString)
    @assert length(marker) == 1
    marker
end

function py_stepstyle(seriestype::Symbol)
    seriestype == :steppost && return "steps-post"
    seriestype == :stepmid && return "steps-mid"
    seriestype == :steppre && return "steps-pre"
    return "default"
end

function py_fillstepstyle(seriestype::Symbol)
    seriestype == :steppost && return "post"
    seriestype == :stepmid && return "mid"
    seriestype == :steppre && return "pre"
    return nothing
end

py_fillstyle(::Nothing) = nothing
py_fillstyle(fillstyle::Symbol) = string(fillstyle)

function py_get_matching_math_font(parent_fontfamily)
    # matplotlib supported math fonts according to
    # https://matplotlib.org/stable/tutorials/text/mathtext.html
    py_math_supported_fonts = Dict{String,String}(
        "sans-serif" => "dejavusans",
        "serif" => "dejavuserif",
        "cm" => "cm",
        "stix" => "stix",
        "stixsans" => "stixsans",
    )
    # Fallback to "dejavusans" or "dejavuserif" in case the parentfont is different
    # from supported by matplotlib fonts
    matching_font(font) = occursin("serif", lowercase(font)) ? "dejavuserif" : "dejavusans"
    return get(py_math_supported_fonts, parent_fontfamily, matching_font(parent_fontfamily))
end

# # untested... return a FontProperties object from a Plots.Font
# function py_font(font::Font)
#     pyfont["FontProperties"](
#         family = font.family,
#         size = font.size
#     )
# end

function get_locator_and_formatter(vals::AVec)
    pyticker."FixedLocator"(eachindex(vals)), pyticker."FixedFormatter"(vals)
end

function add_pyfixedformatter(cbar, vals::AVec)
    cbar[:locator], cbar[:formatter] = get_locator_and_formatter(vals)
    cbar[:update_ticks]()
end

function labelfunc(scale::Symbol, backend::PyPlotBackend)
    PyPlot.LaTeXStrings.latexstring ∘ labelfunc_tex(scale)
end

function py_mask_nans(z)
    # pynp["ma"][:masked_invalid](z)))
    PyPlot.PyCall.pycall(pynp."ma"."masked_invalid", Any, z)
    # pynp["ma"][:masked_where](pynp["isnan"](z),z)
end

# ---------------------------------------------------------------------------

function fix_xy_lengths!(plt::Plot{PyPlotBackend}, series::Series)
    if series[:x] !== nothing
        x, y = series[:x], series[:y]
        nx, ny = length(x), length(y)
        if !isa(get(series.plotattributes, :z, nothing), Surface) && nx != ny
            if nx < ny
                series[:x] = Float64[x[mod1(i, nx)] for i in 1:ny]
            else
                series[:y] = Float64[y[mod1(i, ny)] for i in 1:nx]
            end
        end
    end
end

function py_linecolormap(series::Series)
    py_colormap(cgrad(series[:linecolor], alpha = get_linealpha(series)))
end
function py_markercolormap(series::Series)
    py_colormap(cgrad(series[:markercolor], alpha = get_markeralpha(series)))
end
function py_fillcolormap(series::Series)
    py_colormap(cgrad(series[:fillcolor], alpha = get_fillalpha(series)))
end

# ---------------------------------------------------------------------------

# TODO: these can probably be removed eventually... right now they're just keeping things working before cleanup

# getAxis(sp::Subplot) = sp.o

# function getAxis(plt::Plot{PyPlotBackend}, series::Series)
#     sp = get_subplot(plt, get(series.plotattributes, :subplot, 1))
#     getAxis(sp)
# end

# getfig(o) = o

# ---------------------------------------------------------------------------
# Figure utils -- F*** matplotlib for making me work so hard to figure this crap out

# the drawing surface
py_canvas(fig) = fig."canvas"

# the object controlling draw commands
py_renderer(fig) = py_canvas(fig)."get_renderer"()

# draw commands... paint the screen (probably updating internals too)
py_drawfig(fig) = fig."draw"(py_renderer(fig))
# py_drawax(ax) = ax[:draw](py_renderer(ax[:get_figure]()))

# get a vector [left, right, bottom, top] in PyPlot coords (origin is bottom-left!)
py_extents(obj) = obj."get_window_extent"()."get_points"()

# compute a bounding box (with origin top-left), however pyplot gives coords with origin bottom-left
function py_bbox(obj)
    fl, fr, fb, ft = py_extents(obj."get_figure"())
    l, r, b, t = py_extents(obj)
    BoundingBox(l * px, (ft - t) * px, (r - l) * px, (t - b) * px)
end

py_bbox(::Nothing) = BoundingBox(0mm, 0mm)

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
    labels = getproperty(ax, Symbol("get_" * letter * "ticklabels"))()
    py_bbox(labels)
end

# bounding box: axis guide
function py_bbox_axislabel(ax, letter)
    pyaxis_label = getproperty(ax, Symbol("get_" * letter * "axis"))().label
    py_bbox(pyaxis_label)
end

# bounding box: union of axis ticks and guide
function py_bbox_axis(ax, letter)
    ticks = py_bbox_ticks(ax, letter)
    labels = py_bbox_axislabel(ax, letter)
    ticks + labels
end

# bounding box: axis title
function py_bbox_title(ax)
    bb = defaultbox
    for s in (:title, :_left_title, :_right_title)
        bb = bb + py_bbox(getproperty(ax, s))
    end
    bb
end

# bounding box: legend
py_bbox_legend(ax) = py_bbox(ax."get_legend"())

function py_thickness_scale(plt::Plot{PyPlotBackend}, ptsz)
    ptsz * plt[:thickness_scaling]
end

# ---------------------------------------------------------------------------

# Create the window/figure for this backend.
function _create_backend_figure(plt::Plot{PyPlotBackend})
    w, h = map(px2inch, Tuple(s * plt[:dpi] / Plots.DPI for s in plt[:size]))

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
    proj = (proj in (nothing, :none) ? nothing : string(proj))

    # add a new axis, and force it to create a new one by setting a distinct label
    ax = fig."add_axes"([0, 0, 1, 1], label = string(gensym()), projection = proj)
    sp.o = ax
end

# ---------------------------------------------------------------------------

# function _series_added(pkg::PyPlotBackend, plt::Plot, plotattributes::KW)
# TODO: change this to accept Subplot??
# function _series_added(plt::Plot{PyPlotBackend}, series::Series)

function py_add_series(plt::Plot{PyPlotBackend}, series::Series)
    # plotattributes = series.plotattributes
    st = series[:seriestype]
    sp = series[:subplot]
    ax = sp.o

    # PyPlot doesn't handle mismatched x/y
    fix_xy_lengths!(plt, series)

    # ax = getAxis(plt, series)
    x, y, z = (py_handle_surface(series[letter]) for letter in (:x, :y, :z))
    if st == :straightline
        x, y = straightline_data(series)
    elseif st == :shape
        x, y = shape_data(series)
    end

    if ispolar(series)
        # make negative radii positive and flip the angle
        # (PyPlot ignores negative radii)
        for i in eachindex(y)
            if y[i] < 0
                y[i] = -y[i]
                x[i] -= π
            end
        end
    end

    xyargs = (st in _3dTypes ? (x, y, z) : (x, y))

    # handle zcolor and get c/cmap
    needs_colorbar = hascolorbar(sp)
    vmin, vmax = clims = get_clims(sp, series)

    # Dict to store extra kwargs
    if st == :wireframe || st == :hexbin
        # vmin, vmax cause an error for wireframe plot
        # We are not supporting clims for hexbin as calculation of bins is not trivial
        extrakw = KW()
    else
        extrakw = KW(:vmin => vmin, :vmax => vmax)
    end

    # holds references to any python object representing the matplotlib series
    handles = []
    discrete_colorbar_values = nothing

    # pass in an integer value as an arg, but a levels list as a keyword arg
    levels = series[:levels]
    levelargs = if isscalar(levels)
        (levels)
    elseif isvector(levels)
        extrakw[:levels] = levels
        ()
    end

    # add custom frame shapes to markershape?
    series_annotations_shapes!(series, :xy)

    # for each plotting command, optionally build and add a series handle to the list

    # line plot
    if st in (:path, :path3d, :steppre, :stepmid, :steppost, :straightline)
        if maximum(series[:linewidth]) > 0
            # TODO: check LineCollection alternative for speed
            # if length(segments) > 1 && (any(typeof(series[attr]) <: AbstractVector for attr in (:fillcolor, :fillalpha)) || series[:fill_z] !== nothing) && !(typeof(series[:linestyle]) <: AbstractVector)
            #     # multicolored line segments
            #     n = length(segments)
            #     # segments = Array(Any,n)
            #     segments = []
            #     kw = KW(
            #         :label => series[:label],
            #         :zorder => plt.n,
            #         :cmap => py_linecolormap(series),
            #         :linewidths => py_thickness_scale(plt, get_linewidth.(series, 1:n)),
            #         :linestyle => py_linestyle(st, get_linestyle.(series)),
            #         :norm => pycolors["Normalize"](; extrakw...)
            #     )
            #     lz = _cycle(series[:line_z], 1:n)
            #     handle = if RecipesPipeline.is3d(st)
            #         line_segments = [[(x[j], y[j], z[j]) for j in rng] for rng in segments]
            #         lc = pyart3d["Line3DCollection"](line_segments; kw...)
            #         lc[:set_array](lz)
            #         ax[:add_collection3d](lc, zs=z) #, zdir='y')
            #         lc
            #     else
            #         line_segments = [[(x[j], y[j]) for j in rng] for rng in segments]
            #         lc = pycollections["LineCollection"](line_segments; kw...)
            #         lc[:set_array](lz)
            #         ax[:add_collection](lc)
            #         lc
            #     end
            #     push!(handles, handle)
            # else
            for (k, segment) in enumerate(series_segments(series, st; check = true))
                i, rng = segment.attr_index, segment.range
                handle = ax."plot"(
                    (arg[rng] for arg in xyargs)...;
                    label = k == 1 ? series[:label] : "",
                    zorder = series[:series_plotindex],
                    color = py_color(
                        single_color(get_linecolor(series, clims, i)),
                        get_linealpha(series, i),
                    ),
                    linewidth = py_thickness_scale(plt, get_linewidth(series, i)),
                    linestyle = py_linestyle(st, get_linestyle(series, i)),
                    solid_capstyle = "butt",
                    dash_capstyle = "butt",
                    drawstyle = py_stepstyle(st),
                )[1]
                push!(handles, handle)
            end
            # end

            a = series[:arrow]
            if a !== nothing && !RecipesPipeline.is3d(st)  # TODO: handle 3d later
                if typeof(a) != Arrow
                    @warn("Unexpected type for arrow: $(typeof(a))")
                else
                    arrowprops = KW(
                        :arrowstyle => "simple,head_length=$(a.headlength),head_width=$(a.headwidth)",
                        :shrinkA => 0,
                        :shrinkB => 0,
                        :edgecolor => py_color(get_linecolor(series)),
                        :facecolor => py_color(get_linecolor(series)),
                        :linewidth => py_thickness_scale(plt, get_linewidth(series)),
                        :linestyle => py_linestyle(st, get_linestyle(series)),
                    )
                    add_arrows(x, y) do xyprev, xy
                        ax."annotate"(
                            "",
                            xytext = (
                                0.001xyprev[1] + 0.999xy[1],
                                0.001xyprev[2] + 0.999xy[2],
                            ),
                            xy = xy,
                            arrowprops = arrowprops,
                            zorder = 999,
                        )
                    end
                end
            end
        end
    end

    # add markers?
    if series[:markershape] != :none &&
       st in (:path, :scatter, :path3d, :scatter3d, :steppre, :stepmid, :steppost, :bar)
        for segment in series_segments(series, :scatter)
            i, rng = segment.attr_index, segment.range
            xyargs = if st == :bar && !isvertical(series)
                if RecipesPipeline.is3d(sp)
                    y[rng], x[rng], z[rng]
                else
                    y[rng], x[rng]
                end
            else
                if RecipesPipeline.is3d(sp)
                    x[rng], y[rng], z[rng]
                else
                    x[rng], y[rng]
                end
            end

            handle = ax."scatter"(
                xyargs...;
                label = series[:label],
                zorder = series[:series_plotindex] + 0.5,
                marker = py_marker(_cycle(series[:markershape], i)),
                s = py_thickness_scale(plt, _cycle(series[:markersize], i)) .^ 2,
                facecolors = py_color(
                    get_markercolor(series, i),
                    get_markeralpha(series, i),
                ),
                edgecolors = py_color(
                    get_markerstrokecolor(series, i),
                    get_markerstrokealpha(series, i),
                ),
                linewidths = py_thickness_scale(plt, get_markerstrokewidth(series, i)),
                extrakw...,
            )
            push!(handles, handle)
        end
    end

    if st == :hexbin
        extrakw[:mincnt] = get(series[:extra_kwargs], :mincnt, nothing)
        extrakw[:edgecolors] =
            get(series[:extra_kwargs], :edgecolors, py_color(get_linecolor(series)))
        handle = ax."hexbin"(
            x,
            y;
            label = series[:label],
            C = series[:weights],
            gridsize = series[:bins] == :auto ? 100 : series[:bins],  # 100 is the default value
            linewidths = py_thickness_scale(plt, series[:linewidth]),
            alpha = series[:fillalpha],
            cmap = py_fillcolormap(series),  # applies to the pcolorfast object
            zorder = series[:series_plotindex],
            extrakw...,
        )
        push!(handles, handle)
    end

    if st in (:contour, :contour3d)
        if st == :contour3d
            extrakw[:extend3d] = true
            if !ismatrix(x) || !ismatrix(y)
                x, y = repeat(x', length(y), 1), repeat(y, 1, length(x))
            end
        end

        if typeof(series[:linecolor]) <: AbstractArray
            extrakw[:colors] = py_color.(series[:linecolor])
        else
            extrakw[:cmap] = py_linecolormap(series)
        end

        # contour lines
        handle = ax."contour"(
            x,
            y,
            z,
            levelargs...;
            label = series[:label],
            zorder = series[:series_plotindex],
            linewidths = py_thickness_scale(plt, series[:linewidth]),
            linestyles = py_linestyle(st, series[:linestyle]),
            extrakw...,
        )
        if series[:contour_labels] == true
            ax."clabel"(handle, handle.levels)
        end
        push!(handles, handle)

        # contour fills
        if series[:fillrange] !== nothing
            handle = ax."contourf"(
                x,
                y,
                z,
                levelargs...;
                label = series[:label],
                zorder = series[:series_plotindex] + 0.5,
                alpha = series[:fillalpha],
                extrakw...,
            )
            push!(handles, handle)
        end
    end

    if st in (:surface, :wireframe)
        if z isa AbstractMatrix
            if !ismatrix(x) || !ismatrix(y)
                x, y = repeat(x', length(y), 1), repeat(y, 1, length(x))
            end
            if st == :surface
                if series[:fill_z] !== nothing
                    # the surface colors are different than z-value
                    extrakw[:facecolors] =
                        py_shading(series[:fillcolor], py_handle_surface(series[:fill_z]))
                    extrakw[:shade] = false
                else
                    extrakw[:cmap] = py_fillcolormap(series)
                end
            end
            handle = getproperty(ax, st == :surface ? :plot_surface : :plot_wireframe)(
                x,
                y,
                z;
                label = series[:label],
                zorder = series[:series_plotindex],
                rstride = series[:stride][1],
                cstride = series[:stride][2],
                linewidth = py_thickness_scale(plt, series[:linewidth]),
                edgecolor = py_color(get_linecolor(series)),
                extrakw...,
            )
            push!(handles, handle)

            # contours on the axis planes
            if series[:contours]
                for (zdir, mat) in (("x", x), ("y", y), ("z", z))
                    offset = (zdir == "y" ? ignorenan_maximum : ignorenan_minimum)(mat)
                    handle = ax."contourf"(
                        x,
                        y,
                        z,
                        levelargs...;
                        zdir = zdir,
                        cmap = py_fillcolormap(series),
                        offset = (zdir == "y" ? ignorenan_maximum : ignorenan_minimum)(mat),  # where to draw the contour plane
                    )
                    push!(handles, handle)
                end
            end

        elseif typeof(z) <: AbstractVector
            # tri-surface plot (http://matplotlib.org/mpl_toolkits/mplot3d/tutorial.html#tri-surface-plots)
            handle = ax."plot_trisurf"(
                x,
                y,
                z;
                label = series[:label],
                zorder = series[:series_plotindex],
                cmap = py_fillcolormap(series),
                linewidth = py_thickness_scale(plt, series[:linewidth]),
                edgecolor = py_color(get_linecolor(series)),
                extrakw...,
            )
            push!(handles, handle)
        else
            error("Unsupported z type $(typeof(z)) for seriestype=$st")
        end
    end

    if st == :mesh3d
        polygons = if series[:connections] isa AbstractVector{<:AbstractVector{Int}}
            # Combination of any polygon types
            broadcast(inds -> broadcast(i -> [x[i], y[i], z[i]], inds), series[:connections])
        elseif series[:connections] isa AbstractVector{NTuple{N,Int}} where {N}
            # Only N-gons - connections have to be 1-based (indexing)
            broadcast(inds -> broadcast(i -> [x[i], y[i], z[i]], inds), series[:connections])
        elseif series[:connections] isa NTuple{3,<:AbstractVector{Int}}
            # Only triangles - connections have to be 0-based (indexing)
            ci, cj, ck = series[:connections]
            if !(length(ci) == length(cj) == length(ck))
                throw(
                    ArgumentError(
                        "Argument connections must consist of equally sized arrays.",
                    ),
                )
            end
            broadcast(
                j -> broadcast(i -> [x[i], y[i], z[i]], [ci[j] + 1, cj[j] + 1, ck[j] + 1]),
                eachindex(ci),
            )
        else
            throw(
                ArgumentError(
                    "Unsupported `:connections` type $(typeof(series[:connections])) for seriestype=$st",
                ),
            )
        end
        col = mplot3d.art3d.Poly3DCollection(
            polygons,
            linewidths = py_thickness_scale(plt, series[:linewidth]),
            edgecolor = py_color(get_linecolor(series)),
            facecolor = py_color(series[:fillcolor]),
            alpha = get_fillalpha(series),
            zorder = series[:series_plotindex],
        )
        handle = ax."add_collection3d"(col)
        # Fix for handle: https://stackoverflow.com/questions/54994600/pyplot-legend-poly3dcollection-object-has-no-attribute-edgecolors2d
        # It seems there aren't two different alpha values for edge and face
        handle._facecolors2d = py_color(series[:fillcolor])
        handle._edgecolors2d = py_color(get_linecolor(series))
        push!(handles, handle)
    end

    if st == :image
        xmin, xmax = ignorenan_extrema(series[:x])
        ymin, ymax = ignorenan_extrema(series[:y])
        dx = (xmax - xmin) / (length(series[:x]) - 1) / 2
        dy = (ymax - ymin) / (length(series[:y]) - 1) / 2
        z = if eltype(z) <: Colors.AbstractGray
            float(z)
        elseif eltype(z) <: Colorant
            map(c -> Float64[red(c), green(c), blue(c), alpha(c)], z)
        else
            z  # hopefully it's in a data format that will "just work" with imshow
        end
        handle = ax."imshow"(
            z;
            zorder = series[:series_plotindex],
            cmap = py_colormap(cgrad(plot_color([:black, :white]))),
            vmin = 0.0,
            vmax = 1.0,
            extent = (xmin - dx, xmax + dx, ymax + dy, ymin - dy),
        )
        push!(handles, handle)

        # expand extrema... handle is AxesImage object
        xmin, xmax, ymax, ymin = handle."get_extent"()
        expand_extrema!(sp, xmin, xmax, ymin, ymax)
        # sp[:yaxis].series[:flip] = true
    end

    if st == :heatmap
        x, y = heatmap_edges(x, sp[:xaxis][:scale], y, sp[:yaxis][:scale], size(z))

        expand_extrema!(sp[:xaxis], x)
        expand_extrema!(sp[:yaxis], y)
        dvals = sp[:zaxis][:discrete_values]
        if !isempty(dvals)
            discrete_colorbar_values = dvals
        end

        handle = ax."pcolormesh"(
            x,
            y,
            py_mask_nans(z);
            label = series[:label],
            zorder = series[:series_plotindex],
            cmap = py_fillcolormap(series),
            alpha = series[:fillalpha],
            # edgecolors = (series[:linewidth] > 0 ? py_linecolor(series) : "face"),
            extrakw...,
        )
        push!(handles, handle)
    end

    if st == :shape
        handle = []
        for segment in series_segments(series)
            i, rng = segment.attr_index, segment.range
            if length(rng) > 1
                lc = get_linecolor(series, clims, i)
                la = get_linealpha(series, i)
                ls = get_linestyle(series, i)
                fc = get_fillcolor(series, clims, i)
                fa = get_fillalpha(series, i)
                fs = get_fillstyle(series, i)
                has_fs = !isnothing(fs)

                path = pypath."Path"(hcat(x[rng], y[rng]))

                # shape outline (and potentially solid fill)
                patches = pypatches."PathPatch"(
                    path;
                    label = series[:label],
                    zorder = series[:series_plotindex],
                    edgecolor = py_color(lc, la),
                    facecolor = py_color(fc, has_fs ? 0 : fa),
                    linewidth = py_thickness_scale(plt, get_linewidth(series, i)),
                    linestyle = py_linestyle(st, ls),
                    fill = !has_fs,
                )
                push!(handle, ax."add_patch"(patches))

                # shape hatched fill
                # hatch color/alpha are controlled by edge (not face) color/alpha
                if has_fs
                    patches = pypatches."PathPatch"(
                        path;
                        label = "",
                        zorder = series[:series_plotindex],
                        edgecolor = py_color(fc, fa),
                        facecolor = py_color(fc, 0), # don't fill with solid background
                        hatch = py_fillstyle(fs),
                        linewidth = 0, # don't replot shape outline (doesn't affect hatch linewidth)
                        linestyle = py_linestyle(st, ls),
                        fill = false,
                    )
                    push!(handle, ax."add_patch"(patches))
                end
            end
        end
        push!(handles, handle)
    end

    series[:serieshandle] = handles

    # # smoothing
    # handleSmooth(plt, ax, series, series[:smooth])

    # handle area filling
    fillrange = series[:fillrange]
    if fillrange !== nothing && st != :contour
        for segment in series_segments(series)
            i, rng = segment.attr_index, segment.range
            f, dim1, dim2 = if isvertical(series)
                :fill_between, x[rng], y[rng]
            else
                :fill_betweenx, y[rng], x[rng]
            end
            n = length(dim1)
            args = if typeof(fillrange) <: Union{Real,AVec}
                dim1, _cycle(fillrange, rng), dim2
            elseif is_2tuple(fillrange)
                dim1, _cycle(fillrange[1], rng), _cycle(fillrange[2], rng)
            end

            la = get_linealpha(series, i)
            fc = get_fillcolor(series, clims, i)
            fa = get_fillalpha(series, i)
            fs = get_fillstyle(series, i)
            has_fs = !isnothing(fs)

            handle = getproperty(ax, f)(
                args...,
                trues(n),
                false,
                py_fillstepstyle(st);
                zorder = series[:series_plotindex],
                # hatch color/alpha are controlled by edge (not face) color/alpha
                # if has_fs, set edge color/alpha <- fill color/alpha and face alpha <- 0
                edgecolor = py_color(fc, has_fs ? fa : la),
                facecolor = py_color(fc, has_fs ? 0 : fa),
                hatch = py_fillstyle(fs),
                linewidths = 0,
            )
            push!(handles, handle)
        end
    end

    # this is all we need to add the series_annotations text
    anns = series[:series_annotations]
    for (xi, yi, str, fnt) in EachAnn(anns, x, y)
        py_add_annotations(sp, xi, yi, PlotText(str, fnt))
    end
end

# --------------------------------------------------------------------------

function py_set_lims(ax, sp::Subplot, axis::Axis)
    letter = axis[:letter]
    lfrom, lto = axis_limits(sp, letter)
    getproperty(ax, Symbol("set_", letter, "lim"))(lfrom, lto)
end

function py_set_ticks(sp, ax, ticks, letter)
    ticks == :auto && return
    axis = getproperty(ax, get_attr_symbol(letter, :axis))
    if ticks == :none || ticks === nothing || ticks == false
        kw = KW()
        for dir in (:top, :bottom, :left, :right)
            kw[dir] = kw[get_attr_symbol(:label, dir)] = false
        end
        axis."set_tick_params"(; which = "both", kw...)
        return
    end

    ttype = ticksType(ticks)
    if ttype == :ticks
        axis."set_ticks"(ticks)
    elseif ttype == :ticks_and_labels
        axis."set_ticks"(ticks[1])
        axis."set_ticklabels"(ticks[2])
    else
        error("Invalid input for $(letter)ticks: $ticks")
    end
end

function py_compute_axis_minval(sp::Subplot, axis::Axis)
    # compute the smallest absolute value for the log scale's linear threshold
    minval = 1.0
    sps = axis.sps
    for sp in sps
        for series in series_list(sp)
            v = series.plotattributes[axis[:letter]]
            if !isempty(v)
                minval = NaNMath.min(minval, ignorenan_minimum(abs.(v)))
            end
        end
    end

    # now if the axis limits go to a smaller abs value, use that instead
    vmin, vmax = axis_limits(sp, axis[:letter])
    minval = NaNMath.min(minval, abs(vmin), abs(vmax))

    minval
end

function py_set_scale(ax, sp::Subplot, scale::Symbol, letter::Symbol)
    scale in supported_scales() || return @warn("Unhandled scale value in pyplot: $scale")
    func = getproperty(ax, Symbol("set_", letter, "scale"))
    if PyPlot.version ≥ v"3.3" # https://matplotlib.org/3.3.0/api/api_changes.html
        pyletter = Symbol("")
    else
        pyletter = letter
    end
    kw = KW()
    arg = if scale == :identity
        "linear"
    else
        kw[get_attr_symbol(:base, pyletter)] = if scale == :ln
            ℯ
        elseif scale == :log2
            2
        elseif scale == :log10
            10
        end
        axis = sp[get_attr_symbol(letter, :axis)]
        kw[get_attr_symbol(:linthresh, pyletter)] =
            NaNMath.max(1e-16, py_compute_axis_minval(sp, axis))
        "symlog"
    end
    func(arg; kw...)
end

function py_set_scale(ax, sp::Subplot, axis::Axis)
    scale = axis[:scale]
    letter = axis[:letter]
    py_set_scale(ax, sp, scale, letter)
end

function py_set_spine_color(spines, color)
    for loc in spines
        getproperty(spines, loc)."set_color"(color)
    end
end

function py_set_spine_color(spines::Dict, color)
    for (loc, spine) in spines
        spine."set_color"(color)
    end
end

function py_set_axis_colors(sp, ax, a::Axis)
    py_set_spine_color(ax.spines, py_color(a[:foreground_color_border]))
    axissym = get_attr_symbol(a[:letter], :axis)
    if PyPlot.PyCall.hasproperty(ax, axissym)
        tickcolor =
            sp[:framestyle] in (:zerolines, :grid) ?
            py_color(plot_color(a[:foreground_color_grid], a[:gridalpha])) :
            py_color(a[:foreground_color_axis])
        ax."tick_params"(
            axis = string(a[:letter]),
            which = "both",
            colors = tickcolor,
            labelcolor = py_color(a[:tickfontcolor]),
        )
        getproperty(ax, axissym).label.set_color(py_color(a[:guidefontcolor]))
    end
end

# --------------------------------------------------------------------------

function _before_layout_calcs(plt::Plot{PyPlotBackend})
    # update the fig
    w, h = plt[:size]
    fig = plt.o
    fig."clear"()
    dpi = plt[:dpi]
    fig."set_size_inches"(w / DPI, h / DPI, forward = true)
    getproperty(fig, set_facecolor_sym)(py_color(plt[:background_color_outside]))
    fig."set_dpi"(plt[:dpi])

    # resize the window
    PyPlot.plt."get_current_fig_manager"().resize(w, h)

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
        if ax === nothing
            continue
        end

        # add the annotations
        for ann in sp[:annotations]
            py_add_annotations(sp, locate_annotation(sp, ann...)...)
        end

        # title
        if sp[:title] != ""
            loc = lowercase(string(sp[:titlelocation]))
            func = if loc == "left"
                :_left_title
            elseif loc == "right"
                :_right_title
            else
                :title
            end
            getproperty(ax, func)."set_text"(sp[:title])
            getproperty(ax, func)."set_fontsize"(
                py_thickness_scale(plt, sp[:titlefontsize]),
            )
            getproperty(ax, func)."set_family"(sp[:titlefontfamily])
            getproperty(ax, func)."set_math_fontfamily"(
                py_get_matching_math_font(sp[:titlefontfamily]),
            )
            getproperty(ax, func)."set_color"(py_color(sp[:titlefontcolor]))
            # ax[:set_title](sp[:title], loc = loc)
        end

        # add the colorbar legend
        if hascolorbar(sp)
            # add keyword args for a discrete colorbar
            slist = series_list(sp)
            colorbar_series = slist[findfirst(hascolorbar.(slist))]
            handle = colorbar_series[:serieshandle][end]
            kw = KW()
            if !isempty(sp[:zaxis][:discrete_values]) &&
               colorbar_series[:seriestype] == :heatmap
                locator, formatter = get_locator_and_formatter(sp[:zaxis][:discrete_values])
                # kw[:values] = eachindex(sp[:zaxis][:discrete_values])
                kw[:values] = sp[:zaxis][:continuous_values]
                kw[:ticks] = locator
                kw[:format] = formatter
                kw[:boundaries] = vcat(0, kw[:values] + 0.5)
            elseif any(
                colorbar_series[attr] !== nothing for attr in (:line_z, :fill_z, :marker_z)
            )
                cmin, cmax = get_clims(sp)
                norm = pycolors."Normalize"(vmin = cmin, vmax = cmax)
                f = if colorbar_series[:line_z] !== nothing
                    py_linecolormap
                elseif colorbar_series[:fill_z] !== nothing
                    py_fillcolormap
                else
                    py_markercolormap
                end
                cmap = pycmap."ScalarMappable"(norm = norm, cmap = f(colorbar_series))
                cmap."set_array"([])
                handle = cmap
            end
            kw[:spacing] = "proportional"

            if RecipesPipeline.is3d(sp) || ispolar(sp)
                cbax = fig."add_axes"(
                    [0.9, 0.1, 0.03, 0.8],
                    label = string("cbar", sp[:subplot_index]),
                )
                cb = fig."colorbar"(handle; cax = cbax, kw...)
            else
                # divider approach works only with 2d plots
                divider = axes_grid1.make_axes_locatable(ax)
                # width = axes_grid1.axes_size.AxesY(ax, aspect=1.0 / 3.5)
                # pad = axes_grid1.axes_size.Fraction(0.5, width)  # Colorbar is spaced 0.5 of its size away from the ax
                # cbax = divider.append_axes("right", size=width, pad=pad)   # This approach does not work well in subplots
                colorbar_position = "right"
                colorbar_pad = "2.5%"
                colorbar_orientation = "vertical"

                if sp[:colorbar] == :left
                    colorbar_position = string(sp[:colorbar])
                    colorbar_pad = "5%"
                elseif sp[:colorbar] == :top
                    colorbar_position = string(sp[:colorbar])
                    colorbar_pad = "2.5%"
                    colorbar_orientation = "horizontal"
                elseif sp[:colorbar] == :bottom
                    colorbar_position = string(sp[:colorbar])
                    colorbar_pad = "5%"
                    colorbar_orientation = "horizontal"
                end

                cbax = divider.append_axes(
                    colorbar_position,
                    size = "5%",
                    pad = colorbar_pad,
                    label = string("cbar", sp[:subplot_index]),
                )  # Reasonable value works most of the usecases
                cb = fig."colorbar"(
                    handle;
                    cax = cbax,
                    orientation = colorbar_orientation,
                    kw...,
                )

                if sp[:colorbar] == :left
                    cbax.yaxis.set_ticks_position("left")
                elseif sp[:colorbar] == :top
                    cbax.xaxis.set_ticks_position("top")
                elseif sp[:colorbar] == :bottom
                    cbax.xaxis.set_ticks_position("bottom")
                end
            end

            cb."set_label"(
                sp[:colorbar_title],
                size = py_thickness_scale(plt, sp[:colorbar_titlefontsize]),
                family = sp[:colorbar_titlefontfamily],
                math_fontfamily = py_get_matching_math_font(sp[:colorbar_titlefontfamily]),
                color = py_color(sp[:colorbar_titlefontcolor]),
            )

            # cb."formatter".set_useOffset(false)   # This for some reason does not work, must be a pyplot bug, instead this is a workaround:
            cb."formatter".set_powerlimits((-Inf, Inf))
            cb."update_ticks"()

            ticks = get_colorbar_ticks(sp)
            if sp[:colorbar] in (:top, :bottom)
                axis = sp[:xaxis]  # colorbar inherits from x axis
                cbar_axis = cb."ax"."xaxis"
                ticks_letter = :x
            else
                axis = sp[:yaxis]  # colorbar inherits from y axis
                cbar_axis = cb."ax"."yaxis"
                ticks_letter = :y
            end
            py_set_scale(cb.ax, sp, sp[:colorbar_scale], ticks_letter)
            sp[:colorbar_ticks] == :native ? nothing :
            py_set_ticks(sp, cb.ax, ticks, ticks_letter)

            for lab in cbar_axis."get_ticklabels"()
                lab."set_fontsize"(py_thickness_scale(plt, sp[:colorbar_tickfontsize]))
                lab."set_family"(sp[:colorbar_tickfontfamily])
                lab."set_math_fontfamily"(
                    py_get_matching_math_font(sp[:colorbar_tickfontfamily]),
                )
                lab."set_color"(py_color(sp[:colorbar_tickfontcolor]))
            end

            # Adjust thickness of the cbar ticks
            intensity = 0.5
            cbar_axis."set_tick_params"(
                direction = axis[:tick_direction] == :out ? "out" : "in",
                width = py_thickness_scale(plt, intensity),
                length = axis[:tick_direction] == :none ? 0 :
                         5 * py_thickness_scale(plt, intensity),
            )

            cb.outline."set_linewidth"(py_thickness_scale(plt, 1))

            sp.attr[:cbar_handle] = cb
            sp.attr[:cbar_ax] = cbax
        end

        # framestyle
        if !ispolar(sp) && !RecipesPipeline.is3d(sp)
            for pos in ("left", "right", "top", "bottom")
                # Scale all axes by default first
                getproperty(ax.spines, pos)."set_linewidth"(py_thickness_scale(plt, 1))
            end

            # Then set visible some of them
            if sp[:framestyle] == :semi
                intensity = 0.5

                spine = sp[:yaxis][:mirror] ? "left" : "right"
                getproperty(ax.spines, spine)."set_alpha"(intensity)
                getproperty(ax.spines, spine)."set_linewidth"(
                    py_thickness_scale(plt, intensity),
                )

                spine = sp[:xaxis][:mirror] ? "bottom" : "top"
                getproperty(ax.spines, spine)."set_linewidth"(
                    py_thickness_scale(plt, intensity),
                )
                getproperty(ax.spines, spine)."set_alpha"(intensity)
            elseif sp[:framestyle] == :box
                ax.tick_params(top = true)   # Add ticks too
                ax.tick_params(right = true) # Add ticks too
            elseif sp[:framestyle] in (:axes, :origin)
                sp[:xaxis][:mirror] ? ax.spines."bottom"."set_visible"(false) :
                ax.spines."top"."set_visible"(false)
                sp[:yaxis][:mirror] ? ax.spines."left"."set_visible"(false) :
                ax.spines."right"."set_visible"(false)
                if sp[:framestyle] == :origin
                    ax.spines."bottom"."set_position"("zero")
                    ax.spines."left"."set_position"("zero")
                end
            elseif sp[:framestyle] in (:grid, :none, :zerolines)
                if PyPlot.version >= v"3.4.1" # that is one where it worked, the API change may have some other value
                    for spine in ax.spines
                        getproperty(ax.spines, string(spine))."set_visible"(false)
                    end
                else
                    for (loc, spine) in ax.spines
                        spine."set_visible"(false)
                    end
                end
                if sp[:framestyle] == :zerolines
                    ax."axhline"(
                        y = 0,
                        color = py_color(sp[:xaxis][:foreground_color_axis]),
                        lw = py_thickness_scale(plt, 0.75),
                    )
                    ax."axvline"(
                        x = 0,
                        color = py_color(sp[:yaxis][:foreground_color_axis]),
                        lw = py_thickness_scale(plt, 0.75),
                    )
                end
            end

            if sp[:xaxis][:mirror]
                ax.xaxis."set_label_position"("top")     # the guides
                sp[:framestyle] == :box ? nothing : ax.xaxis."tick_top"()
            end

            if sp[:yaxis][:mirror]
                ax.yaxis."set_label_position"("right")     # the guides
                sp[:framestyle] == :box ? nothing : ax.yaxis."tick_right"()
            end
        end

        # axis attributes
        for letter in (:x, :y, :z)
            axissym = get_attr_symbol(letter, :axis)
            PyPlot.PyCall.hasproperty(ax, axissym) || continue
            axis = sp[axissym]
            pyaxis = getproperty(ax, axissym)

            if axis[:guide_position] != :auto && letter != :z
                pyaxis."set_label_position"(axis[:guide_position])
            end

            py_set_scale(ax, sp, axis)
            py_set_lims(ax, sp, axis)
            if ispolar(sp) && letter == :y
                ax."set_rlabel_position"(90)
            end
            ticks = sp[:framestyle] == :none ? nothing : get_ticks(sp, axis)
            # don't show the 0 tick label for the origin framestyle
            if sp[:framestyle] == :origin && length(ticks) > 1
                ticks[2][ticks[1] .== 0] .= ""
            end

            # Set ticks
            fontProperties = PyPlot.PyCall.PyDict(
                Dict(
                    "family" => axis[:tickfontfamily],
                    "math_fontfamily" =>
                        py_get_matching_math_font(axis[:tickfontfamily]),
                    "size" => py_thickness_scale(plt, axis[:tickfontsize]),
                    "rotation" => axis[:tickfontrotation],
                ),
            )

            positions = getproperty(ax, Symbol("get_", letter, "ticks"))()
            pyaxis.set_major_locator(pyticker.FixedLocator(positions))
            if RecipesPipeline.is3d(sp)
                getproperty(ax, Symbol("set_", letter, "ticklabels"))(
                    positions;
                    (Symbol(k) => v for (k, v) in fontProperties)...,
                )
            else
                getproperty(ax, Symbol("set_", letter, "ticklabels"))(
                    positions,
                    fontdict = fontProperties,
                )
            end

            py_set_ticks(sp, ax, ticks, letter)

            if axis[:ticks] == :native # It is easier to reset than to account for this
                py_set_lims(ax, sp, axis)
                pyaxis.set_major_locator(pyticker.AutoLocator())
                pyaxis.set_major_formatter(pyticker.ScalarFormatter())
            end

            # Tick marks
            intensity = 0.5  # This value corresponds to scaling of other grid elements
            pyaxis."set_tick_params"(
                direction = axis[:tick_direction] == :out ? "out" : "in",
                width = py_thickness_scale(plt, intensity),
                length = axis[:tick_direction] == :none ? 0 :
                         5 * py_thickness_scale(plt, intensity),
            )

            getproperty(ax, Symbol("set_", letter, "label"))(axis[:guide])
            if get(axis.plotattributes, :flip, false)
                getproperty(ax, Symbol("invert_", letter, "axis"))()
            end
            pyaxis."label"."set_fontsize"(py_thickness_scale(plt, axis[:guidefontsize]))
            pyaxis."label"."set_family"(axis[:guidefontfamily])
            pyaxis."label"."set_math_fontfamily"(
                py_get_matching_math_font(axis[:guidefontfamily]),
            )

            if (RecipesPipeline.is3d(sp))
                pyaxis."set_rotate_label"(false)
            end

            if (letter == :y && !RecipesPipeline.is3d(sp))
                pyaxis."label"."set_rotation"(axis[:guidefontrotation] + 90)
            else
                pyaxis."label"."set_rotation"(axis[:guidefontrotation])
            end

            if axis[:grid] && !(ticks in (:none, nothing, false))
                fgcolor = py_color(axis[:foreground_color_grid])
                pyaxis."grid"(
                    true,
                    color = fgcolor,
                    linestyle = py_linestyle(:line, axis[:gridstyle]),
                    linewidth = py_thickness_scale(plt, axis[:gridlinewidth]),
                    alpha = axis[:gridalpha],
                )
                ax."set_axisbelow"(true)
            else
                pyaxis."grid"(false)
            end
            #

            if axis[:minorticks] > 1
                pyaxis."set_minor_locator"(
                    PyPlot.matplotlib.ticker.AutoMinorLocator(axis[:minorticks]),
                )
                pyaxis."set_tick_params"(
                    which = "minor",
                    direction = axis[:tick_direction] == :out ? "out" : "in",
                    length = axis[:tick_direction] == :none ? 0 :
                             py_thickness_scale(plt, intensity),
                )
            end

            if axis[:minorgrid]
                if !(axis[:minorticks] > 1)  # Check if ticks were already configured
                    ax."minorticks_on"()
                end
                pyaxis."set_tick_params"(
                    which = "minor",
                    direction = axis[:tick_direction] == :out ? "out" : "in",
                    length = axis[:tick_direction] == :none ? 0 :
                             py_thickness_scale(plt, intensity),
                )

                pyaxis."grid"(
                    true,
                    which = "minor",
                    color = fgcolor,
                    linestyle = py_linestyle(:line, axis[:minorgridstyle]),
                    linewidth = py_thickness_scale(plt, axis[:minorgridlinewidth]),
                    alpha = axis[:minorgridalpha],
                )
            end

            py_set_axis_colors(sp, ax, axis)
        end

        # showaxis
        if !sp[:xaxis][:showaxis]
            kw = KW()
            if ispolar(sp)
                ax.spines."polar".set_visible(false)
            end
            for dir in (:top, :bottom)
                if !ispolar(sp)
                    getproperty(ax.spines, string(dir)).set_visible(false)
                end
                kw[dir] = kw[get_attr_symbol(:label, dir)] = false
            end
            ax."xaxis"."set_tick_params"(; which = "both", kw...)
        end
        if !sp[:yaxis][:showaxis]
            kw = KW()
            for dir in (:left, :right)
                if !ispolar(sp)
                    getproperty(ax.spines, string(dir)).set_visible(false)
                end
                kw[dir] = kw[get_attr_symbol(:label, dir)] = false
            end
            ax."yaxis"."set_tick_params"(; which = "both", kw...)
        end

        # aspect ratio
        aratio = get_aspect_ratio(sp)
        if aratio != :none
            ax."set_aspect"(isa(aratio, Symbol) ? string(aratio) : aratio, anchor = "C")
        end

        #camera/view angle
        if RecipesPipeline.is3d(sp)
            #convert azimuthal to match GR behaviour
            #view_init(elevation, azimuthal) so reverse :camera args
            ax."view_init"((sp[:camera] .- (90, 0))[end:-1:1]...)
        end

        # legend
        py_add_legend(plt, sp, ax)

        # this sets the bg color inside the grid
        getproperty(ax, set_facecolor_sym)(py_color(sp[:background_color_inside]))

        # link axes
        x_ax_link, y_ax_link = sp[:xaxis].sps[1].o, sp[:yaxis].sps[1].o
        ax != x_ax_link && ax."get_shared_x_axes"()."join"(ax, sp[:xaxis].sps[1].o)
        ax != y_ax_link && ax."get_shared_y_axes"()."join"(ax, sp[:yaxis].sps[1].o)
    end
    py_drawfig(fig)
end

# Set the (left, top, right, bottom) minimum padding around the plot area
# to fit ticks, tick labels, guides, colorbars, etc.
function _update_min_padding!(sp::Subplot{PyPlotBackend})
    ax = sp.o
    ax === nothing && return sp.minpad
    plotbb = py_bbox(ax)

    # TODO: this should initialize to the margin from sp.attr
    # figure out how much the axis components and title "stick out" from the plot area
    # leftpad = toppad = rightpad = bottompad = 1mm
    leftpad   = 0mm
    toppad    = 0mm
    rightpad  = 0mm
    bottompad = 0mm

    for bb in (
        py_bbox_axis(ax, "x"),
        py_bbox_axis(ax, "y"),
        py_bbox_title(ax),
        py_bbox_legend(ax),
    )
        if ispositive(width(bb)) && ispositive(height(bb))
            leftpad   = max(leftpad, left(plotbb) - left(bb))
            toppad    = max(toppad, top(plotbb) - top(bb))
            rightpad  = max(rightpad, right(bb) - right(plotbb))
            bottompad = max(bottompad, bottom(bb) - bottom(plotbb))
        end
    end

    if haskey(sp.attr, :cbar_ax) # Treat colorbar the same way
        ax = sp.attr[:cbar_handle]."ax"
        for bb in (py_bbox_axis(ax, "x"), py_bbox_axis(ax, "y"), py_bbox_title(ax))
            if ispositive(width(bb)) && ispositive(height(bb))
                leftpad   = max(leftpad, left(plotbb) - left(bb))
                toppad    = max(toppad, top(plotbb) - top(bb))
                rightpad  = max(rightpad, right(bb) - right(plotbb))
                bottompad = max(bottompad, bottom(bb) - bottom(plotbb))
            end
        end
    end

    # optionally add the width of colorbar labels and colorbar to rightpad
    if RecipesPipeline.is3d(sp) && haskey(sp.attr, :cbar_ax)
        bb = py_bbox(sp.attr[:cbar_handle]."ax"."get_yticklabels"())
        sp.attr[:cbar_width] = width(bb) + (sp[:colorbar_title] == "" ? 0px : 30px)
    end

    # add in the user-specified margin
    leftpad   += sp[:left_margin]
    toppad    += sp[:top_margin]
    rightpad  += sp[:right_margin]
    bottompad += sp[:bottom_margin]

    dpi_factor = Plots.DPI / sp.plt[:dpi]

    sp.minpad = Tuple(dpi_factor .* [leftpad, toppad, rightpad, bottompad])
end

# -----------------------------------------------------------------

function py_add_annotations(sp::Subplot{PyPlotBackend}, x, y, val)
    ax = sp.o
    ax."annotate"(val, xy = (x, y), zorder = 999, annotation_clip = false)
end

function py_add_annotations(sp::Subplot{PyPlotBackend}, x, y, val::PlotText)
    ax = sp.o
    ax."annotate"(
        val.str,
        xy = (x, y),
        family = val.font.family,
        color = py_color(val.font.color),
        horizontalalignment = val.font.halign == :hcenter ? "center" :
                              string(val.font.halign),
        verticalalignment = val.font.valign == :vcenter ? "center" :
                            string(val.font.valign),
        rotation = val.font.rotation,
        size = py_thickness_scale(sp.plt, val.font.pointsize),
        zorder = 999,
        annotation_clip = false,
    )
end

# -----------------------------------------------------------------

py_legend_pos(pos::Tuple{S,T}) where {S<:Real,T<:Real} = "lower left"

function py_legend_pos(pos::Tuple{<:Real,Symbol})
    (s, c) = sincosd(pos[1])
    if pos[2] === :outer
        s = -s
        c = -c
    end
    yanchors = ["lower", "center", "upper"]
    xanchors = ["left", "center", "right"]
    return join([yanchors[legend_anchor_index(s)], xanchors[legend_anchor_index(c)]], ' ')
end

function py_legend_bbox(pos::Tuple{T,Symbol}) where {T<:Real}
    if pos[2] === :outer
        return legend_pos_from_angle(pos[1], -0.15, 0.5, 1.0, -0.15, 0.5, 1.0)
    end
    legend_pos_from_angle(pos[1], 0.0, 0.5, 1.0, 0.0, 0.5, 1.0)
end

py_legend_bbox(pos) = pos

function py_add_legend(plt::Plot, sp::Subplot, ax)
    leg = sp[:legend_position]
    if leg != :none
        # gotta do this to ensure both axes are included
        labels = []
        handles = []
        for series in series_list(sp)
            if should_add_to_legend(series)
                clims = get_clims(sp, series)
                # add a line/marker and a label
                if series[:seriestype] == :shape || series[:fillrange] !== nothing
                    lc = get_linecolor(series, clims)
                    la = get_linealpha(series)
                    ls = get_linestyle(series)
                    fc = get_fillcolor(series, clims)
                    fa = get_fillalpha(series)
                    fs = get_fillstyle(series)
                    has_fs = !isnothing(fs)

                    # line (and potentially solid fill)
                    line_handle = pypatches."Patch"(
                        edgecolor = py_color(single_color(lc), la),
                        facecolor = py_color(single_color(fc), has_fs ? 0 : fa),
                        linewidth = py_thickness_scale(
                            plt,
                            clamp(get_linewidth(series), 0, 5),
                        ),
                        linestyle = py_linestyle(series[:seriestype], ls),
                        capstyle = "butt",
                    )

                    # hatched fill
                    # hatch color/alpha are controlled by edge (not face) color/alpha
                    if has_fs
                        fill_handle = pypatches."Patch"(
                            edgecolor = py_color(single_color(fc), fa),
                            facecolor = py_color(single_color(fc), 0), # don't fill with solid background
                            hatch = py_fillstyle(fs),
                            linewidth = 0, # don't replot shape outline (doesn't affect hatch linewidth)
                            linestyle = py_linestyle(series[:seriestype], ls),
                            capstyle = "butt",
                        )

                        # plot two handles on top of each other by passing in a tuple
                        # https://matplotlib.org/stable/tutorials/intermediate/legend_guide.html
                        push!(handles, (line_handle, fill_handle))
                    else
                        # plot line handle (which includes solid fill) only
                        push!(handles, line_handle)
                    end
                elseif series[:seriestype] in
                       (:path, :straightline, :scatter, :steppre, :stepmid, :steppost)
                    hasline = get_linewidth(series) > 0
                    handle = PyPlot.plt."Line2D"(
                        (0, 1),
                        (0, 0),
                        color = py_color(
                            single_color(get_linecolor(series, clims)),
                            get_linealpha(series),
                        ),
                        linewidth = py_thickness_scale(
                            plt,
                            hasline * sp[:legend_font_pointsize] / 8,
                        ),
                        linestyle = py_linestyle(:path, get_linestyle(series)),
                        solid_capstyle = "butt",
                        solid_joinstyle = "miter",
                        dash_capstyle = "butt",
                        dash_joinstyle = "miter",
                        marker = py_marker(_cycle(series[:markershape], 1)),
                        markersize = py_thickness_scale(
                            plt,
                            0.8 * sp[:legend_font_pointsize],
                        ),
                        markeredgecolor = py_color(
                            single_color(get_markerstrokecolor(series)),
                            get_markerstrokealpha(series),
                        ),
                        markerfacecolor = py_color(
                            single_color(get_markercolor(series, clims)),
                            get_markeralpha(series),
                        ),
                        markeredgewidth = py_thickness_scale(
                            plt,
                            0.8 *
                            get_markerstrokewidth(series) *
                            sp[:legend_font_pointsize] / first(series[:markersize]),
                        ),   # retain the markersize/markerstroke ratio from the markers on the plot
                    )
                    push!(handles, handle)
                else
                    push!(handles, series[:serieshandle][1])
                end
                push!(labels, series[:label])
            end
        end

        # if anything was added, call ax.legend and set the colors
        if !isempty(handles)
            leg = legend_angle(leg)
            leg = ax."legend"(
                handles,
                labels,
                loc = py_legend_pos(leg),
                bbox_to_anchor = py_legend_bbox(leg),
                scatterpoints = 1,
                fontsize = py_thickness_scale(plt, sp[:legend_font_pointsize]),
                facecolor = py_color(sp[:legend_background_color]),
                edgecolor = py_color(sp[:legend_foreground_color]),
                framealpha = alpha(plot_color(sp[:legend_background_color])),
                fancybox = false,  # makes the legend box square
                borderpad = 0.8,      # to match GR legendbox
            )
            frame = leg."get_frame"()
            frame."set_linewidth"(py_thickness_scale(plt, 1))
            leg."set_zorder"(1000)
            if sp[:legend_title] !== nothing
                leg."set_title"(sp[:legend_title])
                PyPlot.plt."setp"(
                    leg."get_title"(),
                    color = py_color(sp[:legend_title_font_color]),
                    family = sp[:legend_title_font_family],
                    fontsize = py_thickness_scale(plt, sp[:legend_title_font_pointsize]),
                )
            end

            for txt in leg."get_texts"()
                PyPlot.plt."setp"(
                    txt,
                    color = py_color(sp[:legend_font_color]),
                    family = sp[:legend_font_family],
                    fontsize = py_thickness_scale(plt, sp[:legend_font_pointsize]),
                )
            end
        end
    end
end

# -----------------------------------------------------------------

# Use the bounding boxes (and methods left/top/right/bottom/width/height) `sp.bbox` and `sp.plotarea` to
# position the subplot in the backend.
function _update_plot_object(plt::Plot{PyPlotBackend})
    for sp in plt.subplots
        ax = sp.o
        ax === nothing && return
        figw, figh = sp.plt[:size]
        figw, figh = figw * px, figh * px
        pcts = bbox_to_pcts(sp.plotarea, figw, figh)
        ax."set_position"(pcts)

        if haskey(sp.attr, :cbar_ax) && RecipesPipeline.is3d(sp)   # 2D plots are completely handled by axis dividers
            cbw = sp.attr[:cbar_width]
            # this is the bounding box of just the colors of the colorbar (not labels)
            cb_bbox = BoundingBox(
                right(sp.bbox) - cbw - 2mm,
                top(sp.bbox) + 2mm,
                _cbar_width - 1mm,
                height(sp.bbox) - 4mm,
            )
            pcts = get(
                sp[:extra_kwargs],
                "3d_colorbar_axis",
                bbox_to_pcts(cb_bbox, figw, figh),
            )

            sp.attr[:cbar_ax]."set_position"(pcts)
        end
    end
    PyPlot.draw()
end

# -----------------------------------------------------------------
# display/output

_display(plt::Plot{PyPlotBackend}) = plt.o."show"()

for (mime, fmt) in (
    "application/eps"        => "eps",
    "image/eps"              => "eps",
    "application/pdf"        => "pdf",
    "image/png"              => "png",
    "application/postscript" => "ps",
    "image/svg+xml"          => "svg",
    "application/x-tex"      => "pgf",
)
    @eval function _show(io::IO, ::MIME{Symbol($mime)}, plt::Plot{PyPlotBackend})
        fig = plt.o
        fig."canvas"."print_figure"(
            io,
            format = $fmt,
            # bbox_inches = "tight",
            # figsize = map(px2inch, plt[:size]),
            facecolor = fig."get_facecolor"(),
            edgecolor = "none",
            dpi = plt[:dpi],
        )
    end
end

closeall(::PyPlotBackend) = PyPlot.plt."close"("all")
