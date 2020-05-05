
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
pypatches = PyPlot.pyimport("matplotlib.patches")
pyfont = PyPlot.pyimport("matplotlib.font_manager")
pyticker = PyPlot.pyimport("matplotlib.ticker")
pycmap = PyPlot.pyimport("matplotlib.cm")
pynp = PyPlot.pyimport("numpy")
pynp."seterr"(invalid="ignore")
pytransforms = PyPlot.pyimport("matplotlib.transforms")
pycollections = PyPlot.pyimport("matplotlib.collections")
pyart3d = PyPlot.art3D

# "support" matplotlib v1.5
set_facecolor_sym = if PyPlot.version < v"2"
    @warn("You are using Matplotlib $(PyPlot.version), which is no longer officialy supported by the Plots community. To ensure smooth Plots.jl integration update your Matplotlib library to a version >= 2.0.0")
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

py_color(s) = py_color(parse(Colorant, string(s)))
py_color(c::Colorant) = (red(c), green(c), blue(c), alpha(c))
py_color(cs::AVec) = map(py_color, cs)
py_color(grad::PlotUtils.AbstractColorList) = py_color(color_list(grad))
py_color(c::Colorant, α) = py_color(plot_color(c, α))

function py_colormap(cg::ColorGradient)
    pyvals = collect(zip(cg.values, py_color(PlotUtils.color_list(cg))))
    cm = pycolors."LinearSegmentedColormap"."from_list"("tmp", pyvals)
    cm."set_bad"(color=(0,0,0,0.0), alpha=0.0)
    cm
end
function py_colormap(cg::PlotUtils.CategoricalColorGradient)
    r = range(0, stop = 1, length = 256)
    pyvals = collect(zip(r, py_color(cg[r])))
    cm = pycolors."LinearSegmentedColormap"."from_list"("tmp", pyvals)
    cm."set_bad"(color=(0,0,0,0.0), alpha=0.0)
    cm
end
py_colormap(c) = py_colormap(_as_gradient(c))


function py_shading(c, z)
    cmap = py_colormap(c)
    ls = pycolors."LightSource"(270,45)
    ls."shade"(z, cmap, vert_exag=0.1, blend_mode="soft")
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
    mat = zeros(n+1,2)
    for i=1:n
        mat[i,1] = x[i]
        mat[i,2] = y[i]
    end
    mat[n+1,:] = mat[1,:]
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
    seriestype == :steppre && return "steps-pre"
    return "default"
end

function py_fillstepstyle(seriestype::Symbol)
    seriestype == :steppost && return "post"
    seriestype == :steppre && return "pre"
    return nothing
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
    if scale == :log10
        x -> PyPlot.LaTeXStrings.latexstring("10^{$x}")
    elseif scale == :log2
        x -> PyPlot.LaTeXStrings.latexstring("2^{$x}")
    elseif scale == :ln
        x -> PyPlot.LaTeXStrings.latexstring("e^{$x}")
    else
        string
    end
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
                series[:x] = Float64[x[mod1(i,nx)] for i=1:ny]
            else
                series[:y] = Float64[y[mod1(i,ny)] for i=1:nx]
            end
        end
    end
end

py_linecolormap(series::Series)       = py_colormap(series[:linecolor])
py_markercolormap(series::Series)     = py_colormap(series[:markercolor])
py_fillcolormap(series::Series)       = py_colormap(series[:fillcolor])

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
    BoundingBox(l*px, (ft-t)*px, (r-l)*px, (t-b)*px)
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
    labels = getproperty(ax, Symbol("get_"*letter*"ticklabels"))()
    py_bbox(labels)
end

# bounding box: axis guide
function py_bbox_axislabel(ax, letter)
    pyaxis_label = getproperty(ax, Symbol("get_"*letter*"axis"))().label
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
    w,h = map(px2inch, Tuple(s * plt[:dpi] / Plots.DPI for s in plt[:size]))

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
    ax = fig."add_axes"(
        [0,0,1,1],
        label = string(gensym()),
        projection = proj
    )
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
    x, y, z = series[:x], series[:y], series[:z]
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

    xyargs = (st in _3dTypes ? (x,y,z) : (x,y))

    # handle zcolor and get c/cmap
    needs_colorbar = hascolorbar(sp)
    vmin, vmax = clims = get_clims(sp, series)

    # Dict to store extra kwargs
    if st == :wireframe
        extrakw = KW()          # vmin, vmax cause an error for wireframe plot
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
    else
        error("Only numbers and vectors are supported with levels keyword")
    end

    # add custom frame shapes to markershape?
    series_annotations_shapes!(series, :xy)

    # for each plotting command, optionally build and add a series handle to the list

    # line plot
    if st in (:path, :path3d, :steppre, :steppost, :straightline)
        if maximum(series[:linewidth]) > 0
            segments = iter_segments(series)
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
                for (i, rng) in enumerate(iter_segments(series))
                    handle = ax."plot"((arg[rng] for arg in xyargs)...;
                        label = i == 1 ? series[:label] : "",
                        zorder = series[:series_plotindex],
                        color = py_color(single_color(get_linecolor(series, clims, i)), get_linealpha(series, i)),
                        linewidth = py_thickness_scale(plt, get_linewidth(series, i)),
                        linestyle = py_linestyle(st, get_linestyle(series, i)),
                        solid_capstyle = "round",
                        drawstyle = py_stepstyle(st)
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
                        ax."annotate"("",
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
        markercolor = if any(typeof(series[arg]) <: AVec for arg in (:markercolor, :markeralpha)) || series[:marker_z] !== nothing
            # py_color(plot_color.(get_markercolor.(series, clims, eachindex(x)), get_markeralpha.(series, eachindex(x))))
            [py_color(plot_color(get_markercolor(series, clims, i), get_markeralpha(series, i))) for i in eachindex(x)]
        else
            py_color(plot_color(series[:markercolor], series[:markeralpha]))
        end
        extrakw[:c] = if markercolor isa Array
            permutedims(hcat([[m...] for m in markercolor]...),[2,1])
        elseif markercolor isa Tuple
            reshape([markercolor...], 1, length(markercolor))
        else
            error("This case is not handled.  Please file an issue.")
        end
        xyargs = if st == :bar && !isvertical(series)
            (y, x)
        else
            xyargs
        end

        if isa(series[:markershape], AbstractVector{Shape})
            # this section will create one scatter per data point to accommodate the
            # vector of shapes
            handle = []
            x,y = xyargs
            shapes = series[:markershape]
            msc = py_color(get_markerstrokecolor(series), get_markerstrokealpha(series))
            lw = py_thickness_scale(plt, series[:markerstrokewidth])
            for i=eachindex(y)
                if series[:marker_z] !== nothing
                    extrakw[:c] = [py_color(get_markercolor(series, i), get_markercoloralpha(series, i))]
                end

                push!(handle, ax."scatter"(_cycle(x,i), _cycle(y,i);
                    label = series[:label],
                    zorder = series[:series_plotindex] + 0.5,
                    marker = py_marker(_cycle(shapes,i)),
                    s =  py_thickness_scale(plt, _cycle(series[:markersize],i)).^ 2,
                    facecolors = py_color(get_markercolor(series, i), get_markercoloralpha(series, i)),
                    edgecolors = msc,
                    linewidths = lw,
                    extrakw...
                ))
            end
            push!(handles, handle)
        elseif isa(series[:markershape], AbstractVector{Symbol})
            handle = []
            x,y = xyargs
            shapes = series[:markershape]

            prev_marker = py_marker(_cycle(shapes,1))

            cur_x_list = []
            cur_y_list = []

            cur_color_list = []
            cur_scale_list = []

            delete!(extrakw, :c)

            for i=eachindex(y)
                cur_marker = py_marker(_cycle(shapes,i))

                if ( cur_marker == prev_marker )
                  push!(cur_x_list, _cycle(x,i))
                  push!(cur_y_list, _cycle(y,i))

                  push!(cur_color_list, _cycle(markercolor, i))
                  push!(cur_scale_list, py_thickness_scale(plt, _cycle(series[:markersize],i)).^ 2)

                  continue
                end

                push!(handle, ax."scatter"(cur_x_list, cur_y_list;
                  label = series[:label],
                  zorder = series[:series_plotindex] + 0.5,
                  marker = prev_marker,
                  s = cur_scale_list,
                  edgecolors = py_color(get_markerstrokecolor(series), get_markerstrokealpha(series)),
                  linewidths = py_thickness_scale(plt, series[:markerstrokewidth]),
                  facecolors = cur_color_list,
                  extrakw...
                ))

                cur_x_list = [_cycle(x,i)]
                cur_y_list = [_cycle(y,i)]

                cur_color_list = [_cycle(markercolor, i)]
                cur_scale_list = [py_thickness_scale(plt, _cycle(series[:markersize],i)) .^ 2]

                prev_marker = cur_marker
            end

            if !isempty(cur_color_list)
              push!(handle, ax."scatter"(cur_x_list, cur_y_list;
                label = series[:label],
                zorder = series[:series_plotindex] + 0.5,
                marker = prev_marker,
                s = cur_scale_list,
                edgecolors = py_color(get_markerstrokecolor(series), get_markerstrokealpha(series)),
                linewidths = py_thickness_scale(plt, series[:markerstrokewidth]),
                facecolors = cur_color_list,
                extrakw...
              ))
            end

            push!(handles, handle)
        else
            # do a normal scatter plot
            handle = ax."scatter"(xyargs...;
                label = series[:label],
                zorder = series[:series_plotindex] + 0.5,
                marker = py_marker(series[:markershape]),
                s = py_thickness_scale(plt, series[:markersize]) .^2,
                edgecolors = py_color(get_markerstrokecolor(series), get_markerstrokealpha(series)),
                linewidths = py_thickness_scale(plt, series[:markerstrokewidth]),
                extrakw...
            )
            push!(handles, handle)
        end
    end

    if st == :hexbin
        handle = ax."hexbin"(x, y;
            label = series[:label],
            zorder = series[:series_plotindex],
            gridsize = series[:bins],
            linewidths = py_thickness_scale(plt, series[:linewidth]),
            edgecolors = py_color(get_linecolor(series)),
            cmap = py_fillcolormap(series),  # applies to the pcolorfast object
            extrakw...
        )
        push!(handles, handle)
    end

    if st in (:contour, :contour3d)
        z = transpose_z(series, z.surf)
	if typeof(x)<:Plots.Surface
            x = Plots.transpose_z(series, x.surf)
        end
        if typeof(y)<:Plots.Surface
            y = Plots.transpose_z(series, y.surf)
        end

        if st == :contour3d
            extrakw[:extend3d] = true
        end

        if typeof(series[:linecolor]) <: AbstractArray
            extrakw[:colors] = py_color.(series[:linecolor])
        else
            extrakw[:cmap] = py_linecolormap(series)
        end

        # contour lines
        handle = ax."contour"(x, y, z, levelargs...;
            label = series[:label],
            zorder = series[:series_plotindex],
            linewidths = py_thickness_scale(plt, series[:linewidth]),
            linestyles = py_linestyle(st, series[:linestyle]),
            extrakw...
        )
        if series[:contour_labels] == true
            ax."clabel"(handle, handle.levels)
        end
        push!(handles, handle)

        # contour fills
        if series[:fillrange] !== nothing
            handle = ax."contourf"(x, y, z, levelargs...;
                label = series[:label],
                zorder = series[:series_plotindex] + 0.5,
                extrakw...
            )
            push!(handles, handle)
        end
    end

    if st in (:surface, :wireframe)
        if typeof(z) <: AbstractMatrix || typeof(z) <: Surface
            x, y, z = map(Array, (x,y,z))
            if !ismatrix(x) || !ismatrix(y)
                x = repeat(x', length(y), 1)
                y = repeat(y, 1, length(series[:x]))
            end
            z = transpose_z(series, z)
            if st == :surface
                if series[:fill_z] !== nothing
                    # the surface colors are different than z-value
                    extrakw[:facecolors] = py_shading(series[:fillcolor], transpose_z(series, series[:fill_z].surf))
                    extrakw[:shade] = false
                else
                    extrakw[:cmap] = py_fillcolormap(series)
                end
            end
            handle = getproperty(ax, st == :surface ? :plot_surface : :plot_wireframe)(x, y, z;
                label = series[:label],
                zorder = series[:series_plotindex],
                rstride = series[:stride][1],
                cstride = series[:stride][2],
                linewidth = py_thickness_scale(plt, series[:linewidth]),
                edgecolor = py_color(get_linecolor(series)),
                extrakw...
            )
            push!(handles, handle)

            # contours on the axis planes
            if series[:contours]
                for (zdir,mat) in (("x",x), ("y",y), ("z",z))
                    offset = (zdir == "y" ? ignorenan_maximum : ignorenan_minimum)(mat)
                    handle = ax."contourf"(x, y, z, levelargs...;
                        zdir = zdir,
                        cmap = py_fillcolormap(series),
                        offset = (zdir == "y" ? ignorenan_maximum : ignorenan_minimum)(mat)  # where to draw the contour plane
                    )
                    push!(handles, handle)
                end
            end


        elseif typeof(z) <: AbstractVector
            # tri-surface plot (http://matplotlib.org/mpl_toolkits/mplot3d/tutorial.html#tri-surface-plots)
            handle = ax."plot_trisurf"(x, y, z;
                label = series[:label],
                zorder = series[:series_plotindex],
                cmap = py_fillcolormap(series),
                linewidth = py_thickness_scale(plt, series[:linewidth]),
                edgecolor = py_color(get_linecolor(series)),
                extrakw...
            )
            push!(handles, handle)
        else
            error("Unsupported z type $(typeof(z)) for seriestype=$st")
        end
    end

    if st == :image
        # @show typeof(z)
        xmin, xmax = ignorenan_extrema(series[:x]); ymin, ymax = ignorenan_extrema(series[:y])
        img = Array(transpose_z(series, z.surf))
        z = if eltype(img) <: Colors.AbstractGray
            float(img)
        elseif eltype(img) <: Colorant
            map(c -> Float64[red(c),green(c),blue(c),alpha(c)], img)
        else
            z  # hopefully it's in a data format that will "just work" with imshow
        end
        handle = ax."imshow"(z;
            zorder = series[:series_plotindex],
            cmap = py_colormap(cgrad(plot_color([:black, :white]))),
            vmin = 0.0,
            vmax = 1.0,
            extent = (xmin-0.5, xmax+0.5, ymax+0.5, ymin-0.5)
        )
        push!(handles, handle)

        # expand extrema... handle is AxesImage object
        xmin, xmax, ymax, ymin = handle."get_extent"()
        expand_extrema!(sp, xmin, xmax, ymin, ymax)
        # sp[:yaxis].series[:flip] = true
    end

    if st == :heatmap
        x, y, z = heatmap_edges(x, sp[:xaxis][:scale]), heatmap_edges(y, sp[:yaxis][:scale]), transpose_z(series, z.surf)

        expand_extrema!(sp[:xaxis], x)
        expand_extrema!(sp[:yaxis], y)
        dvals = sp[:zaxis][:discrete_values]
        if !isempty(dvals)
            discrete_colorbar_values = dvals
        end

        handle = ax."pcolormesh"(x, y, py_mask_nans(z);
            label = series[:label],
            zorder = series[:series_plotindex],
            cmap = py_fillcolormap(series),
            alpha = series[:fillalpha],
            # edgecolors = (series[:linewidth] > 0 ? py_linecolor(series) : "face"),
            extrakw...
        )
        push!(handles, handle)
    end

    if st == :shape
        handle = []
        for (i, rng) in enumerate(iter_segments(series))
            if length(rng) > 1
                path = pypath."Path"(hcat(x[rng], y[rng]))
                patches = pypatches."PathPatch"(
                    path;
                    label = series[:label],
                    zorder = series[:series_plotindex],
                    edgecolor = py_color(get_linecolor(series, clims, i), get_linealpha(series, i)),
                    facecolor = py_color(get_fillcolor(series, clims, i), get_fillalpha(series, i)),
                    linewidth = py_thickness_scale(plt, get_linewidth(series, i)),
                    linestyle = py_linestyle(st, get_linestyle(series, i)),
                    fill = true
                )
                push!(handle, ax."add_patch"(patches))
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
        for (i, rng) in enumerate(iter_segments(series))
            f, dim1, dim2 = if isvertical(series)
                :fill_between, x[rng], y[rng]
            else
                :fill_betweenx, y[rng], x[rng]
            end
            n = length(dim1)
            args = if typeof(fillrange) <: Union{Real, AVec}
                dim1, _cycle(fillrange, rng), dim2
            elseif is_2tuple(fillrange)
                dim1, _cycle(fillrange[1], rng), _cycle(fillrange[2], rng)
            end

            handle = getproperty(ax, f)(args..., trues(n), false, py_fillstepstyle(st);
                zorder = series[:series_plotindex],
                facecolor = py_color(get_fillcolor(series, clims, i), get_fillalpha(series, i)),
                linewidths = 0
            )
            push!(handles, handle)
        end
    end

    # this is all we need to add the series_annotations text
    anns = series[:series_annotations]
    for (xi,yi,str,fnt) in EachAnn(anns, x, y)
        py_add_annotations(sp, xi, yi, PlotText(str, fnt))
    end
end

# --------------------------------------------------------------------------

function py_set_lims(ax, sp::Subplot, axis::Axis)
    letter = axis[:letter]
    lfrom, lto = axis_limits(sp, letter)
    getproperty(ax, Symbol("set_", letter, "lim"))(lfrom, lto)
end

function py_set_ticks(ax, ticks, letter)
    ticks == :auto && return
    axis = getproperty(ax, Symbol(letter,"axis"))
    if ticks == :none || ticks === nothing || ticks == false
        kw = KW()
        for dir in (:top,:bottom,:left,:right)
            kw[dir] = kw[Symbol(:label,dir)] = false
        end
        axis."set_tick_params"(;which="both", kw...)
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

function py_set_scale(ax, sp::Subplot, axis::Axis)
    scale = axis[:scale]
    letter = axis[:letter]
    scale in supported_scales() || return @warn("Unhandled scale value in pyplot: $scale")
    func = getproperty(ax, Symbol("set_", letter, "scale"))
    kw = KW()
    arg = if scale == :identity
        "linear"
    else
        kw[Symbol(:base,letter)] = if scale == :ln
            ℯ
        elseif scale == :log2
            2
        elseif scale == :log10
            10
        end
        kw[Symbol(:linthresh,letter)] = NaNMath.max(1e-16, py_compute_axis_minval(sp, axis))
        "symlog"
    end
    func(arg; kw...)
end


function py_set_axis_colors(sp, ax, a::Axis)
    for (loc, spine) in ax.spines
        spine."set_color"(py_color(a[:foreground_color_border]))
    end
    axissym = Symbol(a[:letter], :axis)
    if PyPlot.PyCall.hasproperty(ax, axissym)
        tickcolor = sp[:framestyle] in (:zerolines, :grid) ? py_color(plot_color(a[:foreground_color_grid], a[:gridalpha])) : py_color(a[:foreground_color_axis])
        ax."tick_params"(axis=string(a[:letter]), which="both",
                         colors=tickcolor,
                         labelcolor=py_color(a[:tickfontcolor]))
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
    fig."set_size_inches"(w/DPI, h/DPI, forward = true)
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
            getproperty(ax, func)."set_fontsize"(py_thickness_scale(plt, sp[:titlefontsize]))
            getproperty(ax, func)."set_family"(sp[:titlefontfamily])
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
            if !isempty(sp[:zaxis][:discrete_values]) && colorbar_series[:seriestype] == :heatmap
                locator, formatter = get_locator_and_formatter(sp[:zaxis][:discrete_values])
                # kw[:values] = eachindex(sp[:zaxis][:discrete_values])
                kw[:values] = sp[:zaxis][:continuous_values]
                kw[:ticks] = locator
                kw[:format] = formatter
                kw[:boundaries] = vcat(0, kw[:values] + 0.5)
            elseif any(colorbar_series[attr] !== nothing for attr in (:line_z, :fill_z, :marker_z))
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

            # create and store the colorbar object (handle) and the axis that it is drawn on.
            # note: the colorbar axis is positioned independently from the subplot axis
            fig = plt.o
            cbax = fig."add_axes"([0.8,0.1,0.03,0.8], label = string(gensym()))
            cb = fig."colorbar"(handle; cax = cbax, kw...)
            cb."set_label"(sp[:colorbar_title],size=py_thickness_scale(plt, sp[:yaxis][:guidefontsize]),family=sp[:yaxis][:guidefontfamily], color = py_color(sp[:yaxis][:guidefontcolor]))
            for lab in cb."ax"."yaxis"."get_ticklabels"()
                  lab."set_fontsize"(py_thickness_scale(plt, sp[:yaxis][:tickfontsize]))
                  lab."set_family"(sp[:yaxis][:tickfontfamily])
                  lab."set_color"(py_color(sp[:yaxis][:tickfontcolor]))
            end
            sp.attr[:cbar_handle] = cb
            sp.attr[:cbar_ax] = cbax
        end

        # framestyle
        if !ispolar(sp) && !RecipesPipeline.is3d(sp)
            ax.spines["left"]."set_linewidth"(py_thickness_scale(plt, 1))
            ax.spines["bottom"]."set_linewidth"(py_thickness_scale(plt, 1))
            if sp[:framestyle] == :semi
                intensity = 0.5
                ax.spines["right"]."set_alpha"(intensity)
                ax.spines["top"]."set_alpha"(intensity)
                ax.spines["right"]."set_linewidth"(py_thickness_scale(plt, intensity))
                ax.spines["top"]."set_linewidth"(py_thickness_scale(plt, intensity))
            elseif sp[:framestyle] in (:axes, :origin)
                ax.spines["right"]."set_visible"(false)
                ax.spines["top"]."set_visible"(false)
                if sp[:framestyle] == :origin
                    ax.spines["bottom"]."set_position"("zero")
                    ax.spines["left"]."set_position"("zero")
                end
            elseif sp[:framestyle] in (:grid, :none, :zerolines)
                for (loc, spine) in ax.spines
                    spine."set_visible"(false)
                end
                if sp[:framestyle] == :zerolines
                    ax."axhline"(y = 0, color = py_color(sp[:xaxis][:foreground_color_axis]), lw = py_thickness_scale(plt, 0.75))
                    ax."axvline"(x = 0, color = py_color(sp[:yaxis][:foreground_color_axis]), lw = py_thickness_scale(plt, 0.75))
                end
            end
        end

        # axis attributes
        for letter in (:x, :y, :z)
            axissym = Symbol(letter, :axis)
            PyPlot.PyCall.hasproperty(ax, axissym) || continue
            axis = sp[axissym]
            pyaxis = getproperty(ax, axissym)
            if axis[:mirror] && letter != :z
                pos = letter == :x ? "top" : "right"
                pyaxis."set_label_position"(pos)     # the guides
                pyaxis."set_ticks_position"("both")  # the hash marks
                getproperty(pyaxis, Symbol(:tick_, pos))()        # the tick labels
            end
            if axis[:guide_position] != :auto && letter != :z
                pyaxis."set_label_position"(axis[:guide_position])
            end
            py_set_scale(ax, sp, axis)
            axis[:ticks] != :native ? py_set_lims(ax, sp, axis) : nothing
            if ispolar(sp) && letter == :y
                ax."set_rlabel_position"(90)
            end
            ticks = sp[:framestyle] == :none ? nothing : get_ticks(sp, axis)
            # don't show the 0 tick label for the origin framestyle
            if sp[:framestyle] == :origin && length(ticks) > 1
                ticks[2][ticks[1] .== 0] .= ""
            end
            axis[:ticks] != :native ? py_set_ticks(ax, ticks, letter) : nothing

            intensity = 0.5  # This value corresponds to scaling of other grid elements
            pyaxis."set_tick_params"(direction = axis[:tick_direction] == :out ? "out" : "in", width=py_thickness_scale(plt, intensity))

            getproperty(ax, Symbol("set_", letter, "label"))(axis[:guide])
            if get(axis.plotattributes, :flip, false)
                getproperty(ax, Symbol("invert_", letter, "axis"))()
            end
            pyaxis."label"."set_fontsize"(py_thickness_scale(plt, axis[:guidefontsize]))
            pyaxis."label"."set_family"(axis[:guidefontfamily])
            
            if (RecipesPipeline.is3d(sp))
                pyaxis."set_rotate_label"(false)
            end

            if (letter == :y && !RecipesPipeline.is3d(sp))
                pyaxis."label"."set_rotation"(axis[:guidefontrotation] + 90)
            else
                pyaxis."label"."set_rotation"(axis[:guidefontrotation])
            end

            for lab in getproperty(ax, Symbol("get_", letter, "ticklabels"))()
                lab."set_fontsize"(py_thickness_scale(plt, axis[:tickfontsize]))
                lab."set_family"(axis[:tickfontfamily])
                lab."set_rotation"(axis[:rotation])
            end
            if axis[:grid] && !(ticks in (:none, nothing, false))
                fgcolor = py_color(axis[:foreground_color_grid])
                pyaxis."grid"(true,
                    color = fgcolor,
                    linestyle = py_linestyle(:line, axis[:gridstyle]),
                    linewidth = py_thickness_scale(plt, axis[:gridlinewidth]),
                    alpha = axis[:gridalpha])
                ax."set_axisbelow"(true)
            else
                pyaxis."grid"(false)
            end
            #

            if axis[:minorticks] > 1
                pyaxis."set_minor_locator"(PyPlot.matplotlib.ticker.AutoMinorLocator(axis[:minorticks]))
                pyaxis."set_tick_params"(
                    which = "minor",
                    direction = axis[:tick_direction] == :out ? "out" : "in",
                    width=py_thickness_scale(plt, intensity))
            end

            if axis[:minorgrid]
                if !(axis[:minorticks] > 1)  # Check if ticks were already configured
                    ax."minorticks_on"()
                end
                pyaxis."set_tick_params"(
                    which = "minor",
                    direction = axis[:tick_direction] == :out ? "out" : "in",
                    width=py_thickness_scale(plt, intensity))

                pyaxis."grid"(true,
                    which = "minor",
                    color = fgcolor,
                    linestyle = py_linestyle(:line, axis[:minorgridstyle]),
                    linewidth = py_thickness_scale(plt, axis[:minorgridlinewidth]),
                    alpha = axis[:minorgridalpha])
            end



            py_set_axis_colors(sp, ax, axis)
        end

        # showaxis
        if !sp[:xaxis][:showaxis]
            kw = KW()
            if ispolar(sp)
                ax.spines["polar"].set_visible(false)
            end
            for dir in (:top, :bottom)
                if !ispolar(sp)
                    ax.spines[string(dir)].set_visible(false)
                end
                kw[dir] = kw[Symbol(:label,dir)] = false
            end
            ax."xaxis"."set_tick_params"(; which="both", kw...)
        end
        if !sp[:yaxis][:showaxis]
            kw = KW()
            for dir in (:left, :right)
                if !ispolar(sp)
                    ax.spines[string(dir)].set_visible(false)
                end
                kw[dir] = kw[Symbol(:label,dir)] = false
            end
            ax."yaxis"."set_tick_params"(; which="both", kw...)
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
            ax."view_init"((sp[:camera].-(90,0))[end:-1:1]...)
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
    for bb in (py_bbox_axis(ax, "x"), py_bbox_axis(ax, "y"), py_bbox_title(ax), py_bbox_legend(ax))
        if ispositive(width(bb)) && ispositive(height(bb))
            leftpad   = max(leftpad,   left(plotbb) - left(bb))
            toppad    = max(toppad,    top(plotbb)  - top(bb))
            rightpad  = max(rightpad,  right(bb)    - right(plotbb))
            bottompad = max(bottompad, bottom(bb)   - bottom(plotbb))
        end
    end

    # optionally add the width of colorbar labels and colorbar to rightpad
    if haskey(sp.attr, :cbar_ax)
        bb = py_bbox(sp.attr[:cbar_handle]."ax"."get_yticklabels"())
        sp.attr[:cbar_width] = _cbar_width + width(bb) + 2.3mm + (sp[:colorbar_title] == "" ? 0px : 30px)
        rightpad = rightpad + sp.attr[:cbar_width]
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
    ax."annotate"(val, xy = (x,y), zorder = 999, annotation_clip = false)
end


function py_add_annotations(sp::Subplot{PyPlotBackend}, x, y, val::PlotText)
    ax = sp.o
    ax."annotate"(val.str,
        xy = (x,y),
        family = val.font.family,
        color = py_color(val.font.color),
        horizontalalignment = val.font.halign == :hcenter ? "center" : string(val.font.halign),
        verticalalignment = val.font.valign == :vcenter ? "center" : string(val.font.valign),
        rotation = val.font.rotation,
        size = py_thickness_scale(sp.plt, val.font.pointsize),
        zorder = 999,
        annotation_clip = false
    )
end

# -----------------------------------------------------------------

py_legend_pos(pos::Symbol) = get(
    (
        right = "right",
        left = "center left",
        top = "upper center",
        bottom = "lower center",
        bottomleft = "lower left",
        bottomright = "lower right",
        topright = "upper right",
        topleft = "upper left",
        outerright = "center left",
        outerleft = "right",
        outertop = "lower center",
        outerbottom = "upper center",
        outerbottomleft = "lower right",
        outerbottomright = "lower left",
        outertopright = "upper left",
        outertopleft = "upper right",
    ),
    pos,
    "best",
)
py_legend_pos(pos) = "lower left"

py_legend_bbox(pos::Symbol) = get(
    (
        outerright = (1.0, 0.5, 0.0, 0.0),
        outerleft = (-0.15, 0.5, 0.0, 0.0),
        outertop = (0.5, 1.0, 0.0, 0.0),
        outerbottom = (0.5, -0.15, 0.0, 0.0),
        outerbottomleft = (-0.15, 0.0, 0.0, 0.0),
        outerbottomright = (1.0, 0.0, 0.0, 0.0),
        outertopright = (1.0, 1.0, 0.0, 0.0),
        outertopleft = (-0.15, 1.0, 0.0, 0.0),
    ),
    pos,
    (0.0, 0.0, 1.0, 1.0),
)
py_legend_bbox(pos) = pos

function py_add_legend(plt::Plot, sp::Subplot, ax)
    leg = sp[:legend]
    if leg != :none
        # gotta do this to ensure both axes are included
        labels = []
        handles = []
        for series in series_list(sp)
            if should_add_to_legend(series)
                clims = get_clims(sp, series)
                # add a line/marker and a label
                push!(handles,
                    if series[:seriestype] == :shape || series[:fillrange] !== nothing
                        pypatches."Patch"(
                            edgecolor = py_color(single_color(get_linecolor(series, clims)), get_linealpha(series)),
                            facecolor = py_color(single_color(get_fillcolor(series, clims)), get_fillalpha(series)),
                            linewidth = py_thickness_scale(plt, clamp(get_linewidth(series), 0, 5)),
                            linestyle = py_linestyle(series[:seriestype], get_linestyle(series))
                        )
                    elseif series[:seriestype] in (:path, :straightline, :scatter, :steppre, :steppost)
                        hasline = get_linewidth(series) > 0
                        PyPlot.plt."Line2D"((0,1),(0,0),
                            color = py_color(single_color(get_linecolor(series, clims)), get_linealpha(series)),
                            linewidth = py_thickness_scale(plt, hasline * sp[:legendfontsize] / 8),
                            linestyle = py_linestyle(:path, get_linestyle(series)),
                            marker = py_marker(_cycle(series[:markershape], 1)),
                            markersize = py_thickness_scale(plt, 0.8 * sp[:legendfontsize]),
                            markeredgecolor = py_color(single_color(get_markerstrokecolor(series)), get_markerstrokealpha(series)),
                            markerfacecolor = py_color(single_color(get_markercolor(series, clims)), get_markeralpha(series)),
                            markeredgewidth = py_thickness_scale(plt, 0.8 * get_markerstrokewidth(series) * sp[:legendfontsize] / first(series[:markersize]))   # retain the markersize/markerstroke ratio from the markers on the plot
                        )
                    else
                        series[:serieshandle][1]
                    end
                )
                push!(labels, series[:label])
            end
        end

        # if anything was added, call ax.legend and set the colors
        if !isempty(handles)
            leg = ax."legend"(handles,
                labels,
                loc = py_legend_pos(leg),
                bbox_to_anchor = py_legend_bbox(leg),
                scatterpoints = 1,
                fontsize = py_thickness_scale(plt, sp[:legendfontsize]),
                facecolor = py_color(sp[:background_color_legend]),
                edgecolor = py_color(sp[:foreground_color_legend]),
                framealpha = alpha(plot_color(sp[:background_color_legend])),
                fancybox = false  # makes the legend box square
            )
            frame = leg."get_frame"()
            frame."set_linewidth"(py_thickness_scale(plt, 1))
            leg."set_zorder"(1000)
            if sp[:legendtitle] !== nothing
                leg."set_title"(sp[:legendtitle])
                PyPlot.plt."setp"(leg."get_title"(), color = py_color(sp[:legendtitlefontcolor]), family = sp[:legendtitlefontfamily], fontsize = py_thickness_scale(plt, sp[:legendtitlefontsize]))
            end

            for txt in leg."get_texts"()
                PyPlot.plt."setp"(txt, color = py_color(sp[:legendfontcolor]), family = sp[:legendfontfamily], fontsize = py_thickness_scale(plt, sp[:legendfontsize]))
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
        figw, figh = figw*px, figh*px
        pcts = bbox_to_pcts(sp.plotarea, figw, figh)
        ax."set_position"(pcts)

        # set the cbar position if there is one
        if haskey(sp.attr, :cbar_ax)
            cbw = sp.attr[:cbar_width]
            # this is the bounding box of just the colors of the colorbar (not labels)
            ex = sp[:zaxis][:extrema]
            has_toplabel = !(1e-7 < max(abs(ex.emax), abs(ex.emin)) < 1e7)
            cb_bbox = BoundingBox(right(sp.bbox)-cbw+1mm, top(sp.bbox) +  (has_toplabel ? 4mm : 2mm), _cbar_width-1mm, height(sp.bbox) - (has_toplabel ? 6mm : 4mm))
            pcts = bbox_to_pcts(cb_bbox, figw, figh)
            sp.attr[:cbar_ax]."set_position"(pcts)
        end
    end
    PyPlot.draw()
end

# -----------------------------------------------------------------
# display/output

_display(plt::Plot{PyPlotBackend}) = plt.o."show"()


for (mime, fmt) in (
    "application/eps"         => "eps",
    "image/eps"               => "eps",
    "application/pdf"         => "pdf",
    "image/png"               => "png",
    "application/postscript"  => "ps",
    "image/svg+xml"           => "svg",
    "application/x-tex"       => "pgf"
)
    @eval function _show(io::IO, ::MIME{Symbol($mime)}, plt::Plot{PyPlotBackend})
        fig = plt.o
        fig."canvas"."print_figure"(
            io,
            format=$fmt,
            # bbox_inches = "tight",
            # figsize = map(px2inch, plt[:size]),
            facecolor = fig."get_facecolor"(),
            edgecolor = "none",
            dpi = plt[:dpi]
        )
    end
end

closeall(::PyPlotBackend) = PyPlot.plt."close"("all")
