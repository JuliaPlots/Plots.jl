# github.com/stevengj/PythonPlot.jl

is_marker_supported(::PythonPlotBackend, shape::Shape) = true

# problem: github.com/tbreloff/Plots.jl/issues/308
# solution: hack from @stevengj: github.com/JuliaPy/PyPlot.jl/pull/223#issuecomment-229747768
let otherdisplays = splice!(Base.Multimedia.displays, 2:length(Base.Multimedia.displays))
    append!(Base.Multimedia.displays, otherdisplays)
end

if PythonPlot.version < v"3.4"
    @warn """You are using Matplotlib $(PythonPlot.version), which is no longer
    officially supported by the Plots community. To ensure smooth Plots.jl
    integration update your Matplotlib library to a version ≥ 3.4.0
    """
end

for k in (:linthresh, :base, :label)
    # add PythonPlot specific symbols to cache
    _attrsymbolcache[k] = Dict{Symbol,Symbol}()
    for letter in (:x, :y, :z, Symbol(), :top, :bottom, :left, :right)
        _attrsymbolcache[k][letter] = Symbol(k, letter)
    end
end

_py_handle_surface(v) = v
_py_handle_surface(z::Surface) = z.surf

_py_color(s) = _py_color(parse(Colorant, string(s)))
_py_color(c::Colorant) = [red(c), green(c), blue(c), alpha(c)]  # NOTE: returning a tuple fails `PythonPlot`
_py_color(cs::AVec) = map(_py_color, cs)
_py_color(grad::PlotUtils.AbstractColorList) = _py_color(color_list(grad))
_py_color(c::Colorant, α) = _py_color(plot_color(c, α))

function _py_colormap(cg::ColorGradient)
    pyvals = collect(zip(cg.values, _py_color(PlotUtils.color_list(cg))))
    cm = mpl.colors.LinearSegmentedColormap.from_list("tmp", pyvals)
    cm.set_bad(color = (0, 0, 0, 0.0), alpha = 0.0)
    cm
end
function _py_colormap(cg::PlotUtils.CategoricalColorGradient)
    r = range(0, 1; length = 256)
    pyvals = collect(zip(r, _py_color(cg[r])))
    cm = mpl.colors.LinearSegmentedColormap.from_list("tmp", pyvals)
    cm.set_bad(color = (0, 0, 0, 0.0), alpha = 0.0)
    cm
end
_py_colormap(c) = _py_colormap(_as_gradient(c))

_py_shading(c, z) = mpl.colors.LightSource(270, 45).shade(
    z,
    _py_colormap(c),
    vert_exag = 0.1,
    blend_mode = "soft",
)

# get the style (solid, dashed, etc)
function _py_linestyle(seriestype::Symbol, linestyle::Symbol)
    seriestype === :none && return " "
    linestyle === :solid && return "-"
    linestyle === :dash && return "--"
    linestyle === :dot && return ":"
    linestyle === :dashdot && return "-."
    @warn "Unknown linestyle $linestyle"
    "-"
end

function _py_marker(marker::Shape)
    x, y = coords(marker)
    n = length(x)
    mat = zeros(n + 1, 2)
    @inbounds for i in eachindex(x)
        mat[i, 1] = x[i]
        mat[i, 2] = y[i]
    end
    mat[n + 1, :] = @view mat[1, :]
    mpl.path.Path(mat)
end

# get the marker shape
function _py_marker(marker::Symbol)
    marker === :none && return " "
    marker === :circle && return "o"
    marker === :rect && return "s"
    marker === :diamond && return "D"
    marker === :utriangle && return "^"
    marker === :dtriangle && return "v"
    marker === :+ && return "+"
    marker === :x && return "x"
    marker === :star5 && return "*"
    marker === :pentagon && return "p"
    marker === :hexagon && return "h"
    marker === :octagon && return "8"
    marker === :pixel && return ","
    marker === :hline && return "_"
    marker === :vline && return "|"
    haskey(_shapes, marker) && return _py_marker(_shapes[marker])

    @warn "Unknown marker $marker"
    "o"
end

# _py_marker(markers::AVec) = map(_py_marker, markers)
function _py_marker(markers::AVec)
    @warn "Vectors of markers are currently unsupported in PythonPlot: $markers"
    markers |> first |> _py_marker
end

# pass through
function _py_marker(marker::AbstractString)
    @assert length(marker) == 1
    marker
end

function _py_stepstyle(seriestype::Symbol)
    seriestype === :steppost && return "steps-post"
    seriestype === :stepmid && return "steps-mid"
    seriestype === :steppre && return "steps-pre"
    "default"
end

function _py_fillstepstyle(seriestype::Symbol)
    seriestype === :steppost && return "post"
    seriestype === :stepmid && return "mid"
    seriestype === :steppre && return "pre"
    nothing
end

_py_fillstyle(::Nothing) = nothing
_py_fillstyle(fillstyle::Symbol) = string(fillstyle)

function _py_get_matching_math_font(parent_fontfamily)
    # matplotlib supported math fonts according to
    # matplotlib.org/stable/tutorials/text/mathtext.html
    _py_math_supported_fonts = Dict{String,String}(
        "serif"      => "dejavuserif",
        "sans-serif" => "dejavusans",
        "stixsans"   => "stixsans",
        "stix"       => "stix",
        "cm"         => "cm",
    )
    # Fallback to "dejavusans" or "dejavuserif" in case the parentfont is different
    # from supported by matplotlib fonts
    matching_font(font) = occursin("serif", lowercase(font)) ? "dejavuserif" : "dejavusans"
    get(_py_math_supported_fonts, parent_fontfamily, matching_font(parent_fontfamily))
end

get_locator_and_formatter(vals::AVec) =
    mpl.ticker.FixedLocator(eachindex(vals)), mpl.ticker.FixedFormatter(vals)

labelfunc(scale::Symbol, backend::PythonPlotBackend) =
    PythonPlot.LaTeXStrings.latexstring ∘ labelfunc_tex(scale)

_py_mask_nans(z) = PythonPlot.pycall(numpy.ma.masked_invalid, z)

# ---------------------------------------------------------------------------

function fix_xy_lengths!(plt::Plot{PythonPlotBackend}, series::Series)
    if (x = series[:x]) !== nothing
        y = series[:y]
        nx, ny = length(x), length(y)
        if !(get(series.plotattributes, :z, nothing) isa Surface || nx == ny)
            if nx < ny
                series[:x] = map(i -> Float64(x[mod1(i, nx)]), 1:ny)
            else
                series[:y] = map(i -> Float64(y[mod1(i, ny)]), 1:nx)
            end
        end
    end
end

is_valid_cgrad_color(::PlotUtils.ColorSchemes.ColorScheme) = true
is_valid_cgrad_color(::PlotUtils.ColorGradient) = true
is_valid_cgrad_color(::AbstractVector) = true
is_valid_cgrad_color(::Nothing) = false
is_valid_cgrad_color(::Symbol) = true
is_valid_cgrad_color(::Any) = false

_py_linecolormap(series::Series) =
    if (color = get(series, :linecolor, nothing)) |> is_valid_cgrad_color
        _py_colormap(cgrad(color, alpha = get_linealpha(series)))
    else
        nothing
    end
_py_fillcolormap(series::Series) =
    if (color = get(series, :fillcolor, nothing)) |> is_valid_cgrad_color
        _py_colormap(cgrad(color, alpha = get_fillalpha(series)))
    else
        nothing
    end
_py_markercolormap(series::Series) =
    if (color = get(series, :markercolor, nothing)) |> is_valid_cgrad_color
        _py_colormap(cgrad(color, alpha = get_markeralpha(series)))
    else
        nothing
    end

# ---------------------------------------------------------------------------
# Figure utils -- F*** matplotlib for making me work so hard to figure this crap out

# the drawing surface
_py_canvas(fig) = fig.canvas

# the object controlling draw commands
_py_renderer(fig) = _py_canvas(fig).get_renderer()

# draw commands... paint the screen (probably updating internals too)
_py_drawfig(fig) = fig.draw(_py_renderer(fig))

# `get_points` returns a numpy array in the form [x0 y0; x1 y1] coords (origin is bottom-left (0, 0)!)
_py_extents(obj) = PythonPlot.PyArray(obj.get_window_extent().get_points())

# see cjdoris.github.io/PythonCall.jl/stable/conversion-to-julia/#py2jl-conversion
to_vec(x) = PythonPlot.pyconvert(Vector, x)
to_str(x) = PythonPlot.pyconvert(String, x)

# compute a bounding box (with origin top-left), however PythonPlot gives coords with origin bottom-left
function _py_bbox(obj)
    pyisnone(obj) && return _py_bbox(nothing)
    fl, fr, fb, ft = bb = _py_extents(obj.get_figure())
    l, r, b, t = ex = _py_extents(obj)
    # @show obj bb ex
    x0, y0, width, height = l * px, (ft - t) * px, (r - l) * px, (t - b) * px
    # @show width height
    BoundingBox(x0, y0, width, height)
end

_py_bbox(::Nothing) = BoundingBox(0mm, 0mm)

# get the bounding box of the union of the objects
function _py_bbox(v::AVec)
    bbox_union = DEFAULT_BBOX[]
    for obj in v
        bbox_union += _py_bbox(obj)
    end
    bbox_union
end

get_axis(l::Symbol, x::Union{Symbol,AbstractString}) = Symbol(:get_, l, x)
set_axis(l::Symbol, x::Union{Symbol,AbstractString}) = Symbol(:set_, l, x)

# bounding box: union of axis tick labels
_py_bbox_ticks(ax, letter) =
    if to_str(ax.name) == "3d"
        _py_bbox(nothing)  # FIXME: broken in `3d` (huge extents)
    else
        getproperty(ax, get_axis(letter, :ticklabels))() |> to_vec |> _py_bbox
    end

# bounding box: axis guide
_py_bbox_axislabel(ax, letter) =
    getproperty(ax, get_axis(letter, :axis))().label |> _py_bbox

# bounding box: union of axis ticks and guide
function _py_bbox_axis(ax, letter)
    ticks = _py_bbox_ticks(ax, letter)
    labels = _py_bbox_axislabel(ax, letter)
    ticks + labels
end

# bounding box: axis title
function _py_bbox_title(ax)
    bb = DEFAULT_BBOX[]
    for s in (:title, :_left_title, :_right_title)
        bb += _py_bbox(getproperty(ax, s))
    end
    bb
end

# bounding box: legend
_py_bbox_legend(ax) = _py_bbox(ax.get_legend())
_py_thickness_scale(plt::Plot{PythonPlotBackend}, ptsz) = ptsz * plt[:thickness_scaling]

# ---------------------------------------------------------------------------

# Create the window/figure for this backend.
function _create_backend_figure(plt::Plot{PythonPlotBackend})
    w, h = map(s -> px2inch(s * plt[:dpi] / Plots.DPI), plt[:size])
    # reuse the current figure?
    plt[:overwrite_figure] ? PythonPlot.gcf() : PythonPlot.figure()
end

# Set up the subplot within the backend object.
# function _initialize_subplot(plt::Plot{PythonPlotBackend}, sp::Subplot{PythonPlotBackend})

function _py_init_subplot(plt::Plot{PythonPlotBackend}, sp::Subplot{PythonPlotBackend})
    fig = plt.o
    projection = (proj = sp[:projection]) ∈ (nothing, :none) ? nothing : string(proj)
    kw = if projection == "3d"
        # PythonPlot defaults to "persp" projection by default, we choose to unify backends
        # by using a default "ortho" proj when `:auto`
        (;
            proj_type = (
                auto = "ortho",
                ortho = "ortho",
                orthographic = "ortho",
                persp = "persp",
                perspective = "persp",
            )[sp[:projection_type]]
        )
    else
        (;)
    end
    # add a new axis, and force it to create a new one by setting a distinct label
    sp.o = fig.add_subplot(; label = string(gensym()), projection, kw...)
end

# ---------------------------------------------------------------------------
const _py_line_series = :path, :path3d, :steppre, :stepmid, :steppost, :straightline
const _py_marker_series =
    :path, :scatter, :path3d, :scatter3d, :steppre, :stepmid, :steppost, :bar
const _py_legend_series = :path, :straightline, :scatter, :steppre, :stepmid, :steppost

function _py_add_series(plt::Plot{PythonPlotBackend}, series::Series)
    # plotattributes = series.plotattributes
    st = series[:seriestype]
    sp = series[:subplot]
    xaxis, yaxis = sp[:xaxis], sp[:yaxis]
    ax = sp.o

    # PythonPlot doesn't handle mismatched x/y
    fix_xy_lengths!(plt, series)

    # ax = getAxis(plt, series)
    x, y, z = (_py_handle_surface(series[letter]) for letter in (:x, :y, :z))
    if st === :straightline
        x, y = straightline_data(series)
    elseif st === :shape
        x, y = shape_data(series)
    end

    # make negative radii positive and flip the angle (PythonPlot ignores negative radii)
    ispolar(series) && for i in eachindex(y)
        if y[i] < 0
            y[i] = -y[i]
            x[i] -= π
        end
    end

    xyargs = st ∈ _3dTypes ? (x, y, z) : (x, y)

    # handle zcolor and get c/cmap
    needs_colorbar = hascolorbar(sp)
    vmin, vmax = clims = get_clims(sp, series)

    # Dict to store extra kwargs
    extrakw = if st === :wireframe || st === :hexbin
        # vmin, vmax cause an error for wireframe plot
        # We are not supporting clims for hexbin as calculation of bins is not trivial
        KW()
    else
        KW(:vmin => vmin, :vmax => vmax)
    end

    # holds references to any python object representing the matplotlib series
    handles = []
    push_h(x) = push!(handles, x)

    # pass in an integer value as an arg, but a levels list as a keyword arg
    levels = series[:levels]
    levelargs = isscalar(levels) ? levels : ()
    isvector(levels) && (extrakw[:levels] = levels)

    # add custom frame shapes to markershape?
    series_annotations_shapes!(series, :xy)

    # some defaults
    cbar_scale = sp[:colorbar_scale]
    linewidths = linewidth = _py_thickness_scale(plt, get_linewidth(series))
    linestyles = linestyle = _py_linestyle(st, get_linestyle(series))
    edgecolor  = edgecolors = _py_color(get_linecolor(series, 1, cbar_scale))
    facecolor  = facecolors = _py_color(series[:fillcolor])
    zorder     = series[:series_plotindex]
    alpha      = get_fillalpha(series)
    label      = series[:label]

    # add lines ?
    if st ∈ _py_line_series && maximum(series[:linewidth]) > 0
        for (k, segment) in enumerate(series_segments(series, st; check = true))
            i, rng = segment.attr_index, segment.range
            ax.plot(
                map(arg -> arg[rng], xyargs)...;
                label = k == 1 ? label : "",
                color = _py_color(
                    single_color(get_linecolor(series, clims, i, cbar_scale)),
                    get_linealpha(series, i),
                ),
                linewidth = _py_thickness_scale(plt, get_linewidth(series, i)),
                linestyle = _py_linestyle(st, get_linestyle(series, i)),
                solid_capstyle = "butt",
                dash_capstyle = "butt",
                drawstyle = _py_stepstyle(st),
                zorder,
            ) |> push_h
        end

        if (a = series[:arrow]) !== nothing && !RecipesPipeline.is3d(st)  # TODO: handle 3d later
            if typeof(a) != Arrow
                @warn "Unexpected type for arrow: $(typeof(a))"
            else
                arrowprops = Dict(
                    "arrowstyle" => "simple,head_length=$(a.headlength),head_width=$(a.headwidth)",
                    "edgecolor"  => edgecolor,
                    "facecolor"  => edgecolor,
                    "linewidth"  => linewidth,
                    "linestyle"  => linestyle,
                    "shrinkA"    => 0,
                    "shrinkB"    => 0,
                )
                add_arrows(x, y) do xyprev, xy
                    ax.annotate(
                        "";
                        xytext = (0.001xyprev[1] + 0.999xy[1], 0.001xyprev[2] + 0.999xy[2]),
                        zorder = 999,
                        arrowprops,
                        xy,
                    )
                end
            end
        end
    end

    # add markers ?
    if series[:markershape] !== :none && st ∈ _py_marker_series
        for segment in series_segments(series, :scatter)
            i, rng = segment.attr_index, segment.range
            args = if st === :bar && !isvertical(series)
                y[rng], x[rng]
            else
                x[rng], y[rng]
            end
            RecipesPipeline.is3d(sp) && (args = (args..., z[rng]))
            ax.scatter(
                args...;
                zorder = zorder + 0.5,
                marker = _py_marker(_cycle(series[:markershape], i)),
                s = _py_thickness_scale(plt, _cycle(series[:markersize], i)) .^ 2,
                facecolors = _py_color(
                    get_markercolor(series, i, cbar_scale),
                    get_markeralpha(series, i),
                ),
                edgecolors = _py_color(
                    get_markerstrokecolor(series, i),
                    get_markerstrokealpha(series, i),
                ),
                linewidths = _py_thickness_scale(plt, get_markerstrokewidth(series, i)),
                label,
                extrakw...,
            ) |> push_h
        end
    end

    if st === :shape
        for segment in series_segments(series)
            i, rng = segment.attr_index, segment.range
            if length(rng) > 1
                lc = get_linecolor(series, clims, i, cbar_scale)
                fc = get_fillcolor(series, clims, i)
                la = get_linealpha(series, i)
                fa = get_fillalpha(series, i)
                ls = get_linestyle(series, i)
                fs = get_fillstyle(series, i)
                has_fs = !isnothing(fs)

                path = mpl.path.Path(hcat(x[rng], y[rng]))
                # FIXME: path can be un-filled e.g. ex 56,
                # where rectangles are created using 4 paths instead of a single one

                # shape outline (and potentially solid fill)
                mpl.patches.PathPatch(
                    path;
                    edgecolor = _py_color(lc, la),
                    facecolor = _py_color(fc, has_fs ? 0 : fa),
                    linewidth = _py_thickness_scale(plt, get_linewidth(series, i)),
                    linestyle = _py_linestyle(st, ls),
                    fill = !has_fs,
                    zorder,
                    label,
                ) |>
                ax.add_patch |>
                push_h
                # shape hatched fill - hatch color/alpha are controlled by edge (not face) color/alpha
                if has_fs
                    mpl.patches.PathPatch(
                        path;
                        label = "",
                        edgecolor = _py_color(fc, fa),
                        facecolor = _py_color(fc, 0), # don't fill with solid background
                        hatch = _py_fillstyle(fs),
                        linewidth = 0, # don't replot shape outline (doesn't affect hatch linewidth)
                        linestyle = _py_linestyle(st, ls),
                        fill = false,
                        zorder,
                    ) |>
                    ax.add_patch |>
                    push_h
                end
            end
        end
    elseif st === :image
        x, y = series[:x], series[:y]
        xmin, xmax = ignorenan_extrema(x)
        ymin, ymax = ignorenan_extrema(y)
        z = if eltype(z) <: Colors.AbstractGray
            float(z)
        elseif eltype(z) <: Colorant
            rgba = Array{Float64,3}(undef, size(z)..., 4)
            rgba[:, :, 1] = Colors.red.(z)
            rgba[:, :, 2] = Colors.green.(z)
            rgba[:, :, 3] = Colors.blue.(z)
            rgba[:, :, 4] = Colors.alpha.(z)
            rgba
        else
            z  # hopefully it's in a data format that will "just work" with imshow
        end
        aspect = if get_aspect_ratio(sp) === :equal
            "equal"
        else
            "auto"
        end
        ax.imshow(
            z;
            cmap = _py_colormap(cgrad(plot_color([:black, :white]))),
            extent = (xmin, xmax, ymax, ymin),
            vmin = 0.0,
            vmax = 1.0,
            zorder,
            aspect,
        ) |> push_h
    elseif st === :heatmap
        x, y = heatmap_edges(x, xaxis[:scale], y, yaxis[:scale], size(z))
        expand_extrema!(xaxis, x)
        expand_extrema!(yaxis, y)
        ax.pcolormesh(
            x,
            y,
            _py_mask_nans(z);
            # edgecolors = (series[:linewidth] > 0 ? _py_linecolor(series) : "face"),
            cmap = _py_fillcolormap(series),
            zorder,
            alpha,
            label,
            extrakw...,
        ) |> push_h
    elseif st === :mesh3d
        cns = series[:connections]
        polygons = if cns isa AbstractVector{<:AbstractVector{<:Integer}}
            # Combination of any polygon types
            map(inds -> map(i -> [x[i], y[i], z[i]], inds), cns)
        elseif cns isa AbstractVector{NTuple{N,<:Integer}} where {N}
            # Only N-gons - connections have to be 1-based (indexing)
            map(inds -> map(i -> [x[i], y[i], z[i]], inds), cns)
        elseif cns isa NTuple{3,<:AbstractVector{<:Integer}}
            # Only triangles - connections have to be 0-based (indexing)
            X, Y, Z = mesh3d_triangles(x, y, z, cns)
            ntris = length(cns[1])
            polys = sizehint!(Matrix{eltype(x)}[], ntris)
            for n in 1:ntris
                m = 4(n - 1) + 1
                push!(
                    polys,
                    [
                        X[m + 0] Y[m + 0] Z[m + 0]
                        X[m + 1] Y[m + 1] Z[m + 1]
                        X[m + 2] Y[m + 2] Z[m + 2]
                    ],
                )
            end
            polys
        else
            "Unsupported `:connections` type $(typeof(series[:connections])) for seriestype=$st" |>
            ArgumentError |>
            throw
        end
        mpl_toolkits.mplot3d.art3d.Poly3DCollection(
            polygons;
            linewidths,
            edgecolors,
            facecolors,
            zorder,
            alpha,
        ) |>
        ax.add_collection3d |>
        push_h
    elseif st === :hexbin
        sekw = series[:extra_kwargs]
        extrakw[:mincnt] = get(sekw, :mincnt, nothing)
        extrakw[:edgecolors] = get(sekw, :edgecolors, edgecolor)
        ax.hexbin(
            x,
            y;
            C = series[:weights],
            gridsize = series[:bins] === :auto ? 100 : series[:bins],  # 100 is the default value
            cmap = _py_fillcolormap(series),  # applies to the pcolorfast object
            linewidths,
            zorder,
            alpha,
            label,
            extrakw...,
        ) |> push_h
    elseif st ∈ (:contour, :contour3d)
        if st === :contour3d
            extrakw[:extend3d] = true
            if !ismatrix(x) || !ismatrix(y)
                x, y = repeat(x', length(y), 1), repeat(y, 1, length(x))
            end
        end
        if typeof(series[:linecolor]) <: AbstractArray
            extrakw[:colors] = _py_color.(series[:linecolor])
        else
            extrakw[:cmap] = _py_linecolormap(series)
        end
        (
            handle = ax.contour(
                x,
                y,
                z,
                levelargs...;
                linestyles,
                linewidths,
                zorder,
                extrakw...,
            )
        ) |> push_h
        series[:contour_labels] === true && ax.clabel(handle, handle.levels)

        # contour fills
        series[:fillrange] !== nothing &&
            ax.contourf(
                x,
                y,
                z,
                levelargs...;
                zorder = zorder + 0.5,
                label,
                alpha,
                extrakw...,
            ) |> push_h
    elseif st ∈ (:surface, :wireframe)
        if z isa AbstractMatrix
            if !ismatrix(x) || !ismatrix(y)
                x, y = repeat(x', length(y), 1), repeat(y, 1, length(x))
            end
            if st === :surface
                if series[:fill_z] !== nothing
                    # the surface colors are different than z-value
                    extrakw[:facecolors] =
                        _py_shading(series[:fillcolor], _py_handle_surface(series[:fill_z]))
                    extrakw[:shade] = false
                else
                    extrakw[:cmap] = _py_fillcolormap(series)
                end
            end
            rstride, cstride = series[:stride]
            getproperty(ax, Symbol(:plot_, st))(
                x,
                y,
                z;
                edgecolor,
                linewidth,
                rstride,
                cstride,
                zorder,
                label,
                extrakw...,
            ) |> push_h

            # contours on the axis planes
            series[:contours] && for (zdir, mat) in (("x", x), ("y", y), ("z", z))
                offset = zdir == "y" ? ignorenan_maximum(mat) : ignorenan_minimum(mat)
                ax.contourf(
                    x,
                    y,
                    z,
                    levelargs...;
                    cmap = _py_fillcolormap(series),
                    offset,  # where to draw the contour plane
                    zdir,
                ) |> push_h
            end
        elseif typeof(z) <: AbstractVector
            # tri-surface plot (matplotlib.org/mpl_toolkits/mplot3d/tutorial.html#tri-surface-plots)
            ax.plot_trisurf(
                x,
                y,
                z;
                cmap = _py_fillcolormap(series),
                edgecolor,
                linewidth,
                zorder,
                label,
                extrakw...,
            ) |> push_h
        else
            error("Unsupported z type $(typeof(z)) for seriestype=$st")
        end
    end

    series[:serieshandle] = handles

    # # smoothing
    # handleSmooth(plt, ax, series, series[:smooth])

    # handle area filling
    if (fillrange = series[:fillrange]) !== nothing && st !== :contour
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

            getproperty(ax, f)(
                args...,
                trues(n),
                false,
                _py_fillstepstyle(st);
                # hatch color/alpha are controlled by edge (not face) color/alpha
                # if has_fs, set edge color/alpha <- fill color/alpha and face alpha <- 0
                edgecolor = _py_color(fc, has_fs ? fa : la),
                facecolor = _py_color(fc, has_fs ? 0 : fa),
                hatch = _py_fillstyle(fs),
                linewidths = 0,
                zorder,
            ) |> push_h
        end
    end

    # this is all we need to add the series_annotations text
    for (xi, yi, str, fnt) in EachAnn(series[:series_annotations], x, y)
        _py_add_annotations(sp, xi, yi, PlotText(str, fnt))
    end
end

# --------------------------------------------------------------------------

_py_set_lims(ax, sp::Subplot, axis::Axis) =
    let letter = axis[:letter]
        getproperty(ax, set_axis(letter, :lim))(axis_limits(sp, letter)...)
    end

function _py_set_ticks(sp, ax, ticks, letter)
    ticks === :auto && return
    axis = getproperty(ax, get_attr_symbol(letter, :axis))
    if ticks === :none || ticks === nothing || ticks == false
        kw = KW()
        for dir in (:top, :bottom, :left, :right)
            kw[dir] = kw[get_attr_symbol(:label, dir)] = false
        end
        axis.set_tick_params(; which = "both", kw...)
        return
    end

    tick_values, tick_labels = if (ttype = ticksType(ticks)) === :ticks
        ticks, []
    elseif ttype === :ticks_and_labels
        ticks
    else
        error("Invalid input for $(letter)ticks: $ticks")
    end
    length(tick_values) > 0 && axis.set_ticks(tick_values)
    length(tick_labels) > 0 && axis.set_ticklabels(tick_labels)
    nothing
end

function _py_compute_axis_minval(sp::Subplot, axis::Axis)
    # compute the smallest absolute value for the log scale's linear threshold
    minval = 1.0
    for sp in axis.sps, series in series_list(sp)
        (v = series.plotattributes[axis[:letter]]) |> isempty && continue
        minval = NaNMath.min(minval, ignorenan_minimum(abs.(v)))
    end

    # now if the axis limits go to a smaller abs value, use that instead
    vmin, vmax = axis_limits(sp, axis[:letter])
    NaNMath.min(minval, abs(vmin), abs(vmax))
end

function _py_set_scale(ax, sp::Subplot, scale::Symbol, letter::Symbol)
    scale ∈ supported_scales() || return @warn "Unhandled scale value in PythonPlot: $scale"
    scl, kw = if scale === :identity
        "linear", KW()
    else
        "symlog",
        KW(
            get_attr_symbol(:base, Symbol()) => _logScaleBases[scale],
            get_attr_symbol(:linthresh, Symbol()) => NaNMath.max(
                1e-16,
                _py_compute_axis_minval(sp, sp[get_attr_symbol(letter, :axis)]),
            ),
        )
    end
    getproperty(ax, set_axis(letter, :scale))(scl; kw...)
end

_py_set_scale(ax, sp::Subplot, axis::Axis) =
    _py_set_scale(ax, sp, axis[:scale], axis[:letter])

_py_set_spine_color(spines, color) = foreach(loc -> spines[loc].set_color(color), spines)

_py_set_spine_color(spines::Dict, color) =
    foreach(spine -> spine.set_color(color), values(spines))

function _py_set_axis_colors(sp, ax, a::Axis)
    _py_set_spine_color(ax.spines, _py_color(a[:foreground_color_border]))
    axissym = get_attr_symbol(a[:letter], :axis)
    if hasproperty(ax, axissym)
        tickcolor =
            sp[:framestyle] ∈ (:zerolines, :grid) ?
            _py_color(plot_color(a[:foreground_color_grid], a[:gridalpha])) :
            _py_color(a[:foreground_color_axis])
        ax.tick_params(
            axis = string(a[:letter]),
            which = "both",
            colors = tickcolor,
            labelcolor = _py_color(a[:tickfontcolor]),
        )
        getproperty(ax, axissym).label.set_color(_py_color(a[:guidefontcolor]))
    end
end

# --------------------------------------------------------------------------
_py_hide_spines(ax) =
    foreach(spine -> getproperty(ax.spines, string(spine)).set_visible(false), ax.spines)

function _before_layout_calcs(plt::Plot{PythonPlotBackend})
    # update the fig
    w, h = plt[:size]
    fig = plt.o
    fig.clear()
    fig.set_size_inches(w / DPI, h / DPI, forward = true)
    fig.set_facecolor(_py_color(plt[:background_color_outside]))
    fig.set_dpi(plt[:dpi])

    # resize the window
    PythonPlot.get_current_fig_manager().resize(w, h)

    # initialize subplots
    foreach(sp -> _py_init_subplot(plt, sp), plt.subplots)

    # add the series
    foreach(series -> _py_add_series(plt, series), plt.series_list)

    # update subplots
    for sp in plt.subplots
        (ax = sp.o) === nothing && continue
        xaxis, yaxis = sp[:xaxis], sp[:yaxis]

        # add the annotations
        foreach(
            ann -> _py_add_annotations(sp, locate_annotation(sp, ann...)...),
            sp[:annotations],
        )

        # title
        if (title = sp[:title]) != ""  # support symbols
            loc = lowercase(string(sp[:titlelocation]))
            func = getproperty(ax, if loc == "left"
                :_left_title
            elseif loc == "right"
                :_right_title
            else
                :title
            end)
            func.set_text(string(title))
            func.set_fontsize(_py_thickness_scale(plt, sp[:titlefontsize]))
            func.set_family(sp[:titlefontfamily])
            func.set_math_fontfamily(_py_get_matching_math_font(sp[:titlefontfamily]))
            func.set_color(_py_color(sp[:titlefontcolor]))
        end

        # add the colorbar legend
        if hascolorbar(sp)
            cbar_scale = sp[:colorbar_scale]
            # add keyword args for a discrete colorbar
            slist = series_list(sp)
            cbar_series = slist[findfirst(hascolorbar, slist)]
            kw = KW()
            handle =
                if !isempty(sp[:zaxis][:discrete_values]) &&
                   cbar_series[:seriestype] === :heatmap
                    kw[:ticks], kw[:format] =
                        get_locator_and_formatter(sp[:zaxis][:discrete_values])
                    # kw[:values] = eachindex(sp[:zaxis][:discrete_values])
                    kw[:values] = sp[:zaxis][:continuous_values]
                    kw[:boundaries] = vcat(0, kw[:values] + 0.5)
                    cbar_series[:serieshandle][end]
                elseif any(
                    cbar_series[attr] !== nothing for attr in (:line_z, :fill_z, :marker_z)
                )
                    cmin, cmax = get_clims(sp)
                    norm = if cbar_scale === :identity
                        mpl.colors.Normalize(vmin = cmin, vmax = cmax)
                    else
                        mpl.colors.LogNorm(vmin = cmin, vmax = cmax)
                    end
                    cmap = nothing
                    for func in (_py_linecolormap, _py_fillcolormap, _py_markercolormap)
                        (cmap = func(cbar_series)) === nothing || break
                    end
                    c_map = mpl.cm.ScalarMappable(; cmap, norm)
                    c_map.set_array(PythonPlot.pylist([]))
                    c_map
                else
                    cbar_series[:serieshandle][end]
                end
            kw[:spacing] = "proportional"

            cb_sym = sp[:colorbar]
            label = string("cbar", sp[:subplot_index])
            cbar = if RecipesPipeline.is3d(sp) || ispolar(sp)
                cax = fig.add_axes([0.9, 0.1, 0.03, 0.8]; label)
                fig.colorbar(handle; cax, kw...)
            else
                # divider approach works only with 2d plots
                divider = mpl_toolkits.axes_grid1.make_axes_locatable(ax)
                pos, pad, orientation = if cb_sym === :left
                    cb_sym, "5%", "vertical"
                elseif cb_sym === :top
                    cb_sym, "2.5%", "horizontal"
                elseif cb_sym === :bottom
                    cb_sym, "5%", "horizontal"
                else  # :right or :best
                    :right, "2.5%", "vertical"
                end
                # Reasonable value works most of the usecases
                cax = divider.append_axes(string(pos); size = "5%", label, pad)
                if cb_sym === :left
                    cax.yaxis.set_ticks_position("left")
                elseif cb_sym === :right
                    cax.yaxis.set_ticks_position("right")
                elseif cb_sym === :top
                    cax.xaxis.set_ticks_position("top")
                else  # :bottom or :best
                    cax.xaxis.set_ticks_position("bottom")
                end
                fig.colorbar(handle; orientation, cax, kw...)
            end

            cbar.set_label(
                sp[:colorbar_title];
                size = _py_thickness_scale(plt, sp[:colorbar_titlefontsize]),
                family = sp[:colorbar_titlefontfamily],
                math_fontfamily = _py_get_matching_math_font(sp[:colorbar_titlefontfamily]),
                color = _py_color(sp[:colorbar_titlefontcolor]),
            )

            # cbar.formatter.set_useOffset(false)  # this for some reason does not work, must be a pyplot bug, instead this is a workaround:
            cbar_scale === :identity && cbar.formatter.set_powerlimits((-Inf, Inf))
            cbar.update_ticks()

            ticks = get_colorbar_ticks(sp)
            axis, cbar_axis, ticks_letter = if sp[:colorbar] ∈ (:top, :bottom)
                xaxis, cbar.ax.xaxis, :x  # colorbar inherits from x axis
            else
                yaxis, cbar.ax.yaxis, :y  # colorbar inherits from y axis
            end
            _py_set_scale(cbar.ax, sp, sp[:colorbar_scale], ticks_letter)
            sp[:colorbar_ticks] === :native ||
                _py_set_ticks(sp, cbar.ax, ticks, ticks_letter)

            for lab in cbar_axis.get_ticklabels()
                lab.set_fontsize(_py_thickness_scale(plt, sp[:colorbar_tickfontsize]))
                lab.set_family(sp[:colorbar_tickfontfamily])
                lab.set_math_fontfamily(
                    _py_get_matching_math_font(sp[:colorbar_tickfontfamily]),
                )
                lab.set_color(_py_color(sp[:colorbar_tickfontcolor]))
            end

            # Adjust thickness of the cbar ticks
            intensity = 0.5
            cbar_axis.set_tick_params(
                direction = axis[:tick_direction] === :out ? "out" : "in",
                width = _py_thickness_scale(plt, intensity),
                length = axis[:tick_direction] === :none ? 0 :
                         5_py_thickness_scale(plt, intensity),
            )

            cbar.outline.set_linewidth(_py_thickness_scale(plt, 1))

            sp.attr[:cbar_handle] = cbar
            sp.attr[:cbar_ax] = cax
        end

        framestyle = sp[:framestyle]
        if !ispolar(sp) && !RecipesPipeline.is3d(sp)
            for pos in ("left", "right", "top", "bottom")
                # Scale all axes by default first
                getproperty(ax.spines, pos).set_linewidth(_py_thickness_scale(plt, 1))
            end

            # Then set visible some of them
            if framestyle === :semi
                intensity = 0.5

                pyspine = getproperty(ax.spines, yaxis[:mirror] ? "left" : "right")
                pyspine.set_alpha(intensity)
                pyspine.set_linewidth(_py_thickness_scale(plt, intensity))

                pyspine = getproperty(ax.spines, xaxis[:mirror] ? "bottom" : "top")
                pyspine.set_linewidth(_py_thickness_scale(plt, intensity))
                pyspine.set_alpha(intensity)
            elseif framestyle === :box
                ax.tick_params(top = true)   # Add ticks too
                ax.tick_params(right = true) # Add ticks too
            elseif framestyle ∈ (:axes, :origin)
                for loc in
                    (xaxis[:mirror] ? "bottom" : "top", yaxis[:mirror] ? "left" : "right")
                    getproperty(ax.spines, loc).set_visible(false)
                end
                if framestyle === :origin
                    ax.spines.bottom.set_position("zero")
                    ax.spines.left.set_position("zero")
                end
            elseif framestyle ∈ (:grid, :none, :zerolines)
                _py_hide_spines(ax)
                if framestyle === :zerolines
                    ax.axhline(
                        y = 0,
                        color = _py_color(xaxis[:foreground_color_axis]),
                        lw = _py_thickness_scale(plt, 0.75),
                    )
                    ax.axvline(
                        x = 0,
                        color = _py_color(yaxis[:foreground_color_axis]),
                        lw = _py_thickness_scale(plt, 0.75),
                    )
                end
            end

            if xaxis[:mirror]
                ax.xaxis.set_label_position("top")  # the guides
                framestyle === :box || ax.xaxis.tick_top()
            end

            if yaxis[:mirror]
                ax.yaxis.set_label_position("right")  # the guides
                framestyle === :box || ax.yaxis.tick_right()
            end
        end

        # axis attributes
        for letter in (:x, :y, :z)
            axissym = get_attr_symbol(letter, :axis)
            hasproperty(ax, axissym) || continue
            axis = sp[axissym]
            pyaxis = getproperty(ax, axissym)

            if axis[:guide_position] !== :auto && letter !== :z
                pyaxis.set_label_position(string(axis[:guide_position]))
            end

            _py_set_scale(ax, sp, axis)
            _py_set_lims(ax, sp, axis)
            (ispolar(sp) && letter === :y) && ax.set_rlabel_position(90)
            ticks = framestyle === :none ? nothing : get_ticks(sp, axis)

            has_major_ticks = ticks !== :none && ticks !== nothing && ticks !== false
            has_major_ticks &= if (ttype = ticksType(ticks)) === :ticks
                length(ticks) > 0
            elseif ttype === :ticks_and_labels
                tcs, labs = ticks
                if framestyle === :origin
                    # don't show the 0 tick label for the origin framestyle
                    labs[tcs .== 0] .= ""
                end
                length(tcs) > 0
            else
                true
            end

            # Set ticks
            intensity = 0.5  # this value corresponds to scaling of other grid elements
            length_factor = 6  # arbitrary factor (closest to mpl examples)

            if axis[:ticks] === :native # it is easier to reset than to account for this
                _py_set_lims(ax, sp, axis)
                pyaxis.set_major_locator(mpl.ticker.AutoLocator())
                pyaxis.set_major_formatter(mpl.ticker.ScalarFormatter())
            elseif has_major_ticks
                fontProperties = Dict(
                    "math_fontfamily" => _py_get_matching_math_font(axis[:tickfontfamily]),
                    "size"            => _py_thickness_scale(plt, axis[:tickfontsize]),
                    "rotation"        => axis[:tickfontrotation],
                    "family"          => axis[:tickfontfamily],
                )
                positions = getproperty(ax, get_axis(letter, :ticks))()
                pyaxis.set_major_locator(mpl.ticker.FixedLocator(positions))
                kw = if RecipesPipeline.is3d(sp)
                    NamedTuple(Symbol(k) => v for (k, v) in fontProperties)
                else
                    (; fontdict = PythonPlot.PyDict(fontProperties))
                end
                getproperty(ax, set_axis(letter, :ticklabels))(positions; kw...)
                _py_set_ticks(sp, ax, ticks, letter)

                pyaxis.set_tick_params(
                    direction = axis[:tick_direction] === :out ? "out" : "in",
                    width = _py_thickness_scale(plt, intensity),
                    length = axis[:tick_direction] === :none ? 0 :
                             length_factor * _py_thickness_scale(plt, intensity),
                )
            else
                pyaxis.set_major_locator(mpl.ticker.NullLocator())
            end

            getproperty(ax, set_axis(letter, :label))(axis[:guide])
            pyaxis.label.set_fontsize(_py_thickness_scale(plt, axis[:guidefontsize]))
            pyaxis.label.set_family(axis[:guidefontfamily])
            pyaxis.label.set_math_fontfamily(
                _py_get_matching_math_font(axis[:guidefontfamily]),
            )

            RecipesPipeline.is3d(sp) && pyaxis.set_rotate_label(false)
            axis[:flip] && getproperty(ax, Symbol(:invert_, letter, :axis))()

            axis[:guidefontrotation] + if letter === :y && !RecipesPipeline.is3d(sp)
                90
            else
                0
            end |> pyaxis.label.set_rotation

            if axis[:grid] && has_major_ticks
                pyaxis.grid(
                    true,
                    color = _py_color(axis[:foreground_color_grid]),
                    linestyle = _py_linestyle(:line, axis[:gridstyle]),
                    linewidth = _py_thickness_scale(plt, axis[:gridlinewidth]),
                    alpha = axis[:gridalpha],
                )
                ax.set_axisbelow(true)
            else
                pyaxis.grid(false)
            end

            # minorticks
            if !no_minor_intervals(axis) && has_major_ticks
                ax.minorticks_on()
                n_minor_intervals = num_minor_intervals(axis)
                if (scale = axis[:scale]) === :identity
                    mpl.ticker.AutoMinorLocator(n_minor_intervals)
                else
                    mpl.ticker.LogLocator(
                        base = _logScaleBases[scale],
                        subs = 1:n_minor_intervals,
                    )
                end |> pyaxis.set_minor_locator
                pyaxis.set_tick_params(
                    which = "minor",
                    direction = axis[:tick_direction] === :out ? "out" : "in",
                    length = axis[:tick_direction] === :none ? 0 :
                             0.5length_factor * _py_thickness_scale(plt, intensity),
                )
            end

            axis[:minorgrid] && pyaxis.grid(
                true;
                which = "minor",
                color = _py_color(axis[:foreground_color_grid]),
                linestyle = _py_linestyle(:line, axis[:minorgridstyle]),
                linewidth = _py_thickness_scale(plt, axis[:minorgridlinewidth]),
                alpha = axis[:minorgridalpha],
            )

            _py_set_axis_colors(sp, ax, axis)
        end

        # showaxis
        if !xaxis[:showaxis]
            kw = KW()
            ispolar(sp) && ax.spines.polar.set_visible(false)
            for dir in (:top, :bottom)
                ispolar(sp) || getproperty(ax.spines, string(dir)).set_visible(false)
                kw[dir] = kw[get_attr_symbol(:label, dir)] = false
            end
            ax.xaxis.set_tick_params(; which = "both", kw...)
        end
        if !yaxis[:showaxis]
            kw = KW()
            for dir in (:left, :right)
                ispolar(sp) || getproperty(ax.spines, string(dir)).set_visible(false)
                kw[dir] = kw[get_attr_symbol(:label, dir)] = false
            end
            ax.yaxis.set_tick_params(; which = "both", kw...)
        end

        # aspect ratio
        if (ratio = get_aspect_ratio(sp)) !== :none
            if RecipesPipeline.is3d(sp)
                if ratio === :auto
                    nothing
                elseif ratio === :equal
                    ax.set_box_aspect((1, 1, 1))
                else
                    ax.set_box_aspect(ratio)
                end
            else
                ax.set_aspect(ratio isa Symbol ? string(ratio) : ratio, anchor = "C")
            end
        end

        # camera/view angle
        if RecipesPipeline.is3d(sp)
            # convert azimuth to match GR behaviour
            azimuth, elevation = sp[:camera] .- (90, 0)
            ax.view_init(elevation, azimuth)
        end

        # legend
        _py_add_legend(plt, sp, ax)

        # this sets the bg color inside the grid
        ax.set_facecolor(_py_color(sp[:background_color_inside]))

        # link axes
        x_ax_link, y_ax_link = xaxis.sps[1].o, yaxis.sps[1].o
        if Bool(ax != x_ax_link)  # twinx
            ax.sharey(y_ax_link)
        end
        if Bool(ax != y_ax_link)  # twiny
            ax.sharex(x_ax_link)
        end
    end  # for sp in pl.subplots
    _py_drawfig(fig)
end

expand_padding!(padding, bb, plotbb) =
    if ispositive(width(bb)) && ispositive(height(bb))
        padding[1] = max(padding[1], left(plotbb) - left(bb))
        padding[2] = max(padding[2], top(plotbb) - top(bb))
        padding[3] = max(padding[3], right(bb) - right(plotbb))
        padding[4] = max(padding[4], bottom(bb) - bottom(plotbb))
    end

# Set the (left, top, right, bottom) minimum padding around the plot area
# to fit ticks, tick labels, guides, colorbars, etc.
function _update_min_padding!(sp::Subplot{PythonPlotBackend})
    (ax = sp.o) === nothing && return sp.minpad
    plotbb = _py_bbox(ax)

    # TODO: this should initialize to the margin from sp.attr
    # figure out how much the axis components and title "stick out" from the plot area
    padding = [0mm, 0mm, 0mm, 0mm]  # leftpad, toppad, rightpad, bottompad

    for bb in (
        _py_bbox_axis(ax, :x),
        _py_bbox_axis(ax, :y),
        _py_bbox_title(ax),
        _py_bbox_legend(ax),
    )
        expand_padding!(padding, bb, plotbb)
    end
    if haskey(sp.attr, :cbar_ax) # Treat colorbar the same way
        cbar_ax = sp.attr[:cbar_handle].ax
        for bb in (
            _py_bbox_axis(cbar_ax, :x),
            _py_bbox_axis(cbar_ax, :y),
            _py_bbox_title(cbar_ax),
        )
            expand_padding!(padding, bb, plotbb)
        end
    end

    # optionally add the width of colorbar labels and colorbar to rightpad
    if RecipesPipeline.is3d(sp)
        expand_padding!(padding, _py_bbox_axis(ax, :z), plotbb)
        if haskey(sp.attr, :cbar_ax)
            sp.attr[:cbar_bbox] = _py_bbox(sp.attr[:cbar_handle].ax)
        end
    end

    # add ∈ the user-specified margin
    padding .+= [sp[:left_margin], sp[:top_margin], sp[:right_margin], sp[:bottom_margin]]

    sp.minpad = Tuple((Plots.DPI / sp.plt[:dpi]) .* padding)
end

# -----------------------------------------------------------------

_py_add_annotations(sp::Subplot{PythonPlotBackend}, x, y, val) =
    sp.o.annotate(val, xy = (x, y), annotation_clip = false, zorder = 999)

_py_add_annotations(sp::Subplot{PythonPlotBackend}, x, y, val::PlotText) = sp.o.annotate(
    val.str,
    xy = (x, y),
    size = _py_thickness_scale(sp.plt, val.font.pointsize),
    horizontalalignment = val.font.halign === :hcenter ? "center" : string(val.font.halign),
    verticalalignment = val.font.valign === :vcenter ? "center" : string(val.font.valign),
    color = _py_color(val.font.color),
    rotation = val.font.rotation,
    family = val.font.family,
    annotation_clip = false,
    zorder = 999,
)

_py_add_annotations(sp::Subplot{PythonPlotBackend}, x, y, z, val::PlotText) = sp.o.text3D(
    x,
    y,
    z,
    val.str;
    size = _py_thickness_scale(sp.plt, val.font.pointsize),
    horizontalalignment = val.font.halign === :hcenter ? "center" : string(val.font.halign),
    verticalalignment = val.font.valign === :vcenter ? "center" : string(val.font.valign),
    color = _py_color(val.font.color),
    rotation = val.font.rotation,
    family = val.font.family,
    zorder = 999,
)

# -----------------------------------------------------------------

_py_legend_pos(pos::Tuple{S,T}) where {S<:Real,T<:Real} = "lower left"

function _py_legend_pos(pos::Tuple{<:Real,Symbol})
    s, c = sincosd(pos[1]) .* (pos[2] === :outer ? -1 : 1)
    yanchors = "lower", "center", "upper"
    xanchors = "left", "center", "right"
    join([yanchors[legend_anchor_index(s)], xanchors[legend_anchor_index(c)]], ' ')
end

# legend_pos_from_angle(theta, xmin, xcenter, xmax, ymin, ycenter, ymax)
_py_legend_bbox(pos::Tuple{<:Real,Symbol}) =
    legend_pos_from_angle(pos[1], 0.0, 0.5, 1.0, 0.0, 0.5, 1.0)
_py_legend_bbox(pos) = pos

function _py_add_legend(plt::Plot, sp::Subplot, ax)
    (leg = sp[:legend_position]) === :none && return

    # gotta do this to ensure both axes are included
    labels, handles = [], []
    push_h(x) = push!(handles, x)

    nseries = 0
    for series in series_list(sp)
        should_add_to_legend(series) || continue
        clims = get_clims(sp, series)
        nseries += 1
        # add a line/marker and a label
        if series[:seriestype] === :shape || series[:fillrange] !== nothing
            lc = get_linecolor(series, clims)
            fc = get_fillcolor(series, clims)
            la = get_linealpha(series)
            fa = get_fillalpha(series)
            ls = get_linestyle(series)
            fs = get_fillstyle(series)
            has_fs = !isnothing(fs)

            # line (and potentially solid fill)
            mpl.patches.Patch(
                edgecolor = _py_color(single_color(lc), la),
                facecolor = _py_color(single_color(fc), has_fs ? 0 : fa),
                linewidth = _py_thickness_scale(plt, clamp(get_linewidth(series), 0, 5)),
                linestyle = _py_linestyle(series[:seriestype], ls),
                capstyle = "butt",
            ) |> push_h

            # plot two handles on top of each other by passing in a tuple
            # matplotlib.org/stable/tutorials/intermediate/legend_guide.html

            # hatched fill
            # hatch color/alpha are controlled by edge (not face) color/alpha
            has_fs &&
                mpl.patches.Patch(
                    edgecolor = _py_color(single_color(fc), fa),
                    facecolor = _py_color(single_color(fc), 0), # don't fill with solid background
                    hatch = _py_fillstyle(fs),
                    linewidth = 0, # don't replot shape outline (doesn't affect hatch linewidth)
                    linestyle = _py_linestyle(series[:seriestype], ls),
                    capstyle = "butt",
                ) |> push_h
        elseif series[:seriestype] ∈ _py_legend_series
            has_line = get_linewidth(series) > 0
            PythonPlot.pyplot.Line2D(
                (0, 1),
                (0, 0),
                color = _py_color(
                    single_color(get_linecolor(series, clims)),
                    get_linealpha(series),
                ),
                linewidth = _py_thickness_scale(
                    plt,
                    has_line * sp[:legend_font_pointsize] / 8,
                ),
                linestyle = _py_linestyle(:path, get_linestyle(series)),
                solid_capstyle = "butt",
                solid_joinstyle = "miter",
                dash_capstyle = "butt",
                dash_joinstyle = "miter",
                marker = _py_marker(_cycle(series[:markershape], 1)),
                markersize = _py_thickness_scale(plt, 0.8sp[:legend_font_pointsize]),
                markeredgecolor = _py_color(
                    single_color(get_markerstrokecolor(series)),
                    get_markerstrokealpha(series),
                ),
                markerfacecolor = _py_color(
                    single_color(get_markercolor(series, clims, 1, sp[:colorbar_scale])),
                    get_markeralpha(series),
                ),
                markeredgewidth = _py_thickness_scale(
                    plt,
                    0.8get_markerstrokewidth(series) * sp[:legend_font_pointsize] /
                    first(series[:markersize]),
                ),   # retain the markersize/markerstroke ratio from the markers on the plot
            ) |> push_h
        else
            first(series[:serieshandle]) |> push_h
        end
        push!(labels, series[:label])
    end

    # if anything was added, call ax.legend and set the colors
    isempty(handles) && return

    leg = legend_angle(leg)
    ncol = if (lc = sp[:legend_column]) < 0
        nseries
    elseif lc > 1
        lc == nseries ||
            @warn "n° of legend_column=$lc is not compatible with n° of series=$nseries"
        nseries
    else
        1
    end
    leg = ax.legend(
        handles,
        labels;
        loc = _py_legend_pos(leg),
        bbox_to_anchor = _py_legend_bbox(leg),
        scatterpoints = 1,
        fontsize = _py_thickness_scale(plt, sp[:legend_font_pointsize]),
        facecolor = _py_color(sp[:legend_background_color]),
        edgecolor = _py_color(sp[:legend_foreground_color]),
        framealpha = alpha(plot_color(sp[:legend_background_color])),
        fancybox = false,  # makes the legend box square
        # borderpad = 0.8,  # to match GR legendbox
        ncol,
    )
    leg.get_frame().set_linewidth(_py_thickness_scale(plt, 1))
    leg.set_zorder(1_000)
    if sp[:legend_title] !== nothing
        leg.set_title(string(sp[:legend_title]))
        PythonPlot.setp(
            leg.get_title(),
            color = _py_color(sp[:legend_title_font_color]),
            family = sp[:legend_title_font_family],
            fontsize = _py_thickness_scale(plt, sp[:legend_title_font_pointsize]),
        )
    end

    for txt in leg.get_texts()
        PythonPlot.setp(
            txt,
            color = _py_color(sp[:legend_font_color]),
            family = sp[:legend_font_family],
            fontsize = _py_thickness_scale(plt, sp[:legend_font_pointsize]),
        )
    end
    nothing
end

# -----------------------------------------------------------------

# Use the bounding boxes (and methods left/top/right/bottom/width/height) `sp.bbox` and `sp.plotarea` to
# position the subplot in the backend.
function _update_plot_object(plt::Plot{PythonPlotBackend})
    for sp in plt.subplots
        (ax = sp.o) === nothing && return
        figw, figh = sp.plt[:size] .* px

        # ax.set_position signature: `[left, bottom, width, height]`
        bbox_to_pcts(sp.plotarea, figw, figh) |> ax.set_position

        if haskey(sp.attr, :cbar_ax) && RecipesPipeline.is3d(sp)  # 2D plots are completely handled by axis dividers
            bb = sp.attr[:cbar_bbox]
            # this is the bounding box of just the colors of the colorbar (not labels)
            pad = 2mm
            cb_bbox = BoundingBox(
                right(sp.bbox) - 2width(bb) - 2pad,  # x0
                top(sp.bbox) + pad,  # y0
                width(bb),  # width
                height(sp.bbox) - 2pad,  # height
            )
            get(sp[:extra_kwargs], "3d_colorbar_axis", bbox_to_pcts(cb_bbox, figw, figh)) |>
            sp.attr[:cbar_ax].set_position
        end
    end
    PythonPlot.draw()
end

# -----------------------------------------------------------------
# display/output

_display(plt::Plot{PythonPlotBackend}) = plt.o.show()

for (mime, fmt) in (
    "application/eps"        => "eps",
    "image/eps"              => "eps",
    "application/pdf"        => "pdf",
    "image/png"              => "png",
    "application/postscript" => "ps",
    "image/svg+xml"          => "svg",
    "application/x-tex"      => "pgf",
)
    @eval function _show(io::IO, ::MIME{Symbol($mime)}, plt::Plot{PythonPlotBackend})
        fig = plt.o
        fig.canvas.print_figure(
            io,
            format = $fmt,
            # bbox_inches = "tight",
            facecolor = fig.get_facecolor(),
            edgecolor = "none",
            dpi = plt[:dpi],
        )
    end
end

closeall(::PythonPlotBackend) = PythonPlot.close("all")
