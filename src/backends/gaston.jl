# https://github.com/mbaz/Gaston.

should_warn_on_unsupported(::GastonBackend) = false

# Create the window/figure for this backend.
function _create_backend_figure(plt::Plot{GastonBackend})
    state_handle = Gaston.nexthandle() # for now all the figures will be kept
    plt.o = Gaston.newfigure(state_handle)
end

function _before_layout_calcs(plt::Plot{GastonBackend})
    # Initialize all the subplots first
    plt.o.subplots = Gaston.SubPlot[]

    n1 = n2 = 0
    if length(plt.inset_subplots) > 0
        n1, sps = gaston_get_subplots(0, plt.inset_subplots, plt.layout)
        gaston_init_subplots(plt, sps)
    end

    if length(plt.subplots) > 0
        n2, sps = gaston_get_subplots(0, plt.subplots, plt.layout)
    end

    if (n = n1 + n2) != length(plt.subplots)
        @error "Gaston: $n != $(length(plt.subplots))"
    end

    plt.o.layout = gaston_init_subplots(plt, sps)

    # Then add the series (curves in gaston)
    for series in plt.series_list
        gaston_add_series(plt, series)
    end

    for sp in plt.subplots
        sp === nothing && continue
        for ann in sp[:annotations]
            x, y, val = locate_annotation(sp, ann...)
            sp.o.axesconf *= "\nset label '$(val.str)' at $x,$y $(gaston_font(val.font))"
        end
    end
    nothing
end

_update_min_padding!(sp::Subplot{GastonBackend}) = sp.minpad = 0mm, 0mm, 0mm, 0mm

function _update_plot_object(plt::Plot{GastonBackend})
    # respect the layout ratio
    dat = gaston_multiplot_pos_size(plt.layout, (0, 0, 1, 1))
    gaston_multiplot_pos_size!(dat)
    nothing
end

for (mime, term) in (
    "application/eps"        => "epscairo",
    "image/eps"              => "epslatex",
    "application/pdf"        => "pdfcairo",
    "application/postscript" => "postscript",
    "image/png"              => "png",
    "image/svg+xml"          => "svg",
    "text/latex"             => "tikz",
    "application/x-tex"      => "epslatex",
    "text/plain"             => "dumb",
)
    @eval function _show(io::IO, ::MIME{Symbol($mime)}, plt::Plot{GastonBackend})
        term = String($term)
        tmpfile = "$(Gaston.tempname()).$term"

        Gaston.save(
            term = term,
            output = tmpfile,
            handle = plt.o.handle,
            saveopts = gaston_saveopts(plt),
        )
        while !isfile(tmpfile)
        end  # avoid race condition with read in next line
        write(io, read(tmpfile))
        rm(tmpfile, force = true)
        nothing
    end
end

_display(plt::Plot{GastonBackend}) = display(plt.o)

# --------------------------------------------
# These functions are gaston specific
# --------------------------------------------

function gaston_saveopts(plt::Plot{GastonBackend})
    saveopts = String["size $(join(plt.attr[:size], ","))"]

    # Scale all plot elements to match Plots.jl DPI standard
    scaling = plt.attr[:dpi] / Plots.DPI

    push!(
        saveopts,
        gaston_font(
            plottitlefont(plt),
            rot = false,
            align = false,
            color = false,
            scale = 1,
        ),
        "background $(gaston_color(plt.attr[:background_color]))",
        # "title '$(plt.attr[:window_title])'",
        "fontscale $scaling lw $scaling dl $scaling",  # ps $scaling
    )

    return join(saveopts, " ")
end

function gaston_get_subplots(n, plt_subplots, layout)
    nr, nc = size(layout)
    sps = Array{Any}(nothing, nr, nc)
    for r in 1:nr, c in 1:nc  # NOTE: col major
        l = layout[r, c]
        sps[r, c] = if l isa GridLayout
            n, sub = gaston_get_subplots(n, plt_subplots, l)
            size(sub) == (1, 1) ? only(sub) : sub
        else
            get(l.attr, :blank, false) ? nothing : plt_subplots[n += 1]
        end
    end
    return n, sps
end

function gaston_init_subplots(plt, sps)
    sz = nr, nc = size(sps)
    for c in 1:nc, r in 1:nr  # NOTE: row major
        sp = sps[r, c]
        if sp isa Subplot || sp === nothing
            gaston_init_subplot(plt, sp)
        else
            gaston_init_subplots(plt, sp)
            sz = max.(sz, size(sp))
        end
    end
    return sz
end

function gaston_init_subplot(
    plt::Plot{GastonBackend},
    sp::Union{Nothing,Subplot{GastonBackend}},
)
    if sp === nothing
        push!(plt.o.subplots, sp)
    else
        dims =
            RecipesPipeline.is3d(sp) ||
            sp.attr[:projection] == "3d" ||
            needs_any_3d_axes(sp) ? 3 : 2
        any_label = false
        for series in series_list(sp)
            if dims == 2 && series[:seriestype] ∈ (:heatmap, :contour)
                dims = 3  # we need heatmap/contour to use splot, not plot
            end
            any_label |= should_add_to_legend(series)
        end
        axesconf = gaston_parse_axes_args(plt, sp, dims, any_label)
        sp.o = Gaston.Plot(dims = dims, curves = [], axesconf = axesconf)
        push!(plt.o.subplots, sp.o)
    end
    nothing
end

function gaston_multiplot_pos_size(layout, parent_xy_wh)
    nr, nc = size(layout)
    dat = Array{Any}(nothing, nr, nc)
    for r in 1:nr, c in 1:nc
        l = layout[r, c]
        # width and height (pct) are multiplicative (parent)
        w = layout.widths[c].value * parent_xy_wh[3]
        h = layout.heights[r].value * parent_xy_wh[4]
        if isa(l, EmptyLayout)
            dat[r, c] = (c - 1) * w, (r - 1) * h, w, h, nothing
        else
            # previous position (origin)
            prev_r = r > 1 ? dat[r - 1, c] : nothing
            prev_c = c > 1 ? dat[r, c - 1] : nothing
            prev_r isa Array && (prev_r = prev_r[end, end])
            prev_c isa Array && (prev_c = prev_c[end, end])
            x = prev_c !== nothing ? prev_c[1] + prev_c[3] : parent_xy_wh[1]
            y = prev_r !== nothing ? prev_r[2] + prev_r[4] : parent_xy_wh[2]
            dat[r, c] = if l isa GridLayout
                sub = gaston_multiplot_pos_size(l, (x, y, w, h))
                size(sub) == (1, 1) ? only(sub) : sub
            else
                x, y, w, h, l
            end
        end
    end
    return dat
end

function gaston_multiplot_pos_size!(dat)
    nr, nc = size(dat)
    for r in 1:nr, c in 1:nc
        xy_wh_sp = dat[r, c]
        if xy_wh_sp isa Array
            gaston_multiplot_pos_size!(xy_wh_sp)
        elseif xy_wh_sp isa Tuple
            x, y, w, h, sp = xy_wh_sp
            sp === nothing && continue
            sp.o === nothing && continue
            # gnuplot screen coordinates: bottom left at 0,0 and top right at 1,1
            sp.o.axesconf = "set origin $x, $(1 - y - h)\nset size $w, $h\n" * sp.o.axesconf
        end
    end
    nothing
end

function gaston_add_series(plt::Plot{GastonBackend}, series::Series)
    sp = series[:subplot]
    gsp = sp.o
    x, y, z = series[:x], series[:y], series[:z]
    st = series[:seriestype]
    curves = []
    if gsp.dims == 2 && z === nothing
        for (n, seg) in enumerate(series_segments(series, st; check = true))
            i, rng = seg.attr_index, seg.range
            fr = _cycle(series[:fillrange], 1:length(x[rng]))
            for sc in gaston_seriesconf!(sp, series, i, n == 1)
                push!(curves, Gaston.Curve(x[rng], y[rng], nothing, fr, sc))
            end
        end
    else
        if z isa Surface
            z = z.surf
            if st === :image
                z = reverse(Float32.(Gray.(z)), dims = 1)  # flip y axis
                nr, nc = size(z)
                if (ly = length(y)) == 2 && ly != nr
                    y = collect(range(y[1], y[2], length = nr))
                end
                if (lx = length(x)) == 2 && lx != nc
                    x = collect(range(x[1], x[2], length = nc))
                end
            end
            length(x) == size(z, 2) + 1 && (x = (x[1:(end - 1)] + x[2:end]) / 2)
            length(y) == size(z, 1) + 1 && (y = (y[1:(end - 1)] + y[2:end]) / 2)
        end
        if st === :mesh3d
            x, y, z = mesh3d_triangles(x, y, z, series[:connections])
        end
        for sc in gaston_seriesconf!(sp, series, 1, true)
            push!(curves, Gaston.Curve(x, y, z, nothing, sc))
        end
    end

    for c in curves
        append = length(gsp.curves) > 0
        push!(gsp.curves, c)
        Gaston.write_data(c, gsp.dims, gsp.datafile, append = append)
    end
    nothing
end

function gaston_seriesconf!(
    sp::Subplot{GastonBackend},
    series::Series,
    i::Int,
    add_to_legend::Bool,
)
    #=
    gnuplot abbreviations (see gnuplot/src/set.c)
    ---------------------------------------------
    dl: dashlength
    dt: dashtype
    fc: fillcolor
    fs: fillstyle
    lc: linecolor
    lp: linespoints
    ls: linestyle
    lt: linetype
    lw: linewidth
    pi: pointinterval
    pn: pointnumber
    ps: pointscale
    pt: pointtype
    tc: textcolor
    w: with
    =#
    gsp = sp.o
    st = series[:seriestype]
    extra = []
    add_to_legend &= should_add_to_legend(series)
    curveconf = String[add_to_legend ? "title '$(series[:label])'" : "notitle"]

    clims = get_clims(sp, series)
    if st ∈ (:scatter, :scatter3d)
        lc, dt, lw = gaston_lc_ls_lw(series, clims, i)
        pt, ps, mc = gaston_mk_ms_mc(series, clims, i)
        push!(curveconf, "w points pt $pt ps $ps lc $mc")
    elseif st ∈ (:path, :straightline, :path3d)
        fr = series[:fillrange]
        fc = gaston_color(get_fillcolor(series, i), get_fillalpha(series, i))
        fs = get_fillstyle(series, i)  # FIXME: add fillstyle support ?
        lc, dt, lw = gaston_lc_ls_lw(series, clims, i)
        if fr !== nothing # filled curves, but not filled curves with markers
            push!(
                curveconf,
                "w filledcurves fc $fc fs solid border lc $lc lw $lw dt $dt,'' w lines lc $lc lw $lw dt $dt",
            )
        elseif series[:markershape] === :none  # simplepath
            push!(curveconf, "w lines lc $lc dt $dt lw $lw")
        else
            pt, ps, mc = gaston_mk_ms_mc(series, clims, i)
            push!(curveconf, "w lp lc $mc dt $dt lw $lw pt $pt ps $ps")
        end
    elseif st === :shape
        fc = gaston_color(get_fillcolor(series, i), get_fillalpha(series, i))
        lc, _ = gaston_lc_ls_lw(series, clims, i)
        push!(curveconf, "w filledcurves fc $fc fs solid border lc $lc")
    elseif st ∈ (:steppre, :stepmid, :steppost)
        step = if st === :steppre
            "fsteps"
        elseif st === :stepmid
            "histeps"
        elseif st === :steppost
            "steps"
        end
        push!(curveconf, "w $step")
        lc, dt, lw = gaston_lc_ls_lw(series, clims, i)
        push!(extra, "w points lc $lc dt $dt lw $lw notitle")
    elseif st === :image
        palette = gaston_palette(series[:seriescolor])
        gsp.axesconf *= "\nset palette model RGB defined $palette"
        push!(curveconf, "w image pixels")
    elseif st ∈ (:contour, :contour3d)
        push!(curveconf, "w lines")
        st === :contour && (gsp.axesconf *= "\nset view map\nunset surface")  # 2D
        levels = join(map(string, collect(contour_levels(series, clims))), ", ")
        gsp.axesconf *= "\nset contour base\nset cntrparam levels discrete $levels"
    elseif st ∈ (:surface, :heatmap)
        push!(curveconf, "w pm3d")
        palette = gaston_palette(series[:seriescolor])
        gsp.axesconf *= "\nset palette model RGB defined $palette"
        st === :heatmap && (gsp.axesconf *= "\nset view map")
    elseif st ∈ (:wireframe, :mesh3d)
        lc, dt, lw = gaston_lc_ls_lw(series, clims, i)
        push!(curveconf, "w lines lc $lc dt $dt lw $lw")
    elseif st === :quiver
        push!(curveconf, "w vectors filled")
    else
        @warn "Gaston: $st is not implemented yet"
    end

    return [join(curveconf, " "), extra...]
end

function gaston_parse_axes_args(
    plt::Plot{GastonBackend},
    sp::Subplot{GastonBackend},
    dims::Int,
    any_label::Bool,
)
    # axesconf = String["set margins 2, 2, 2, 2"]  # left, right, bottom, top
    axesconf = String[]

    polar = ispolar(sp) && dims == 2  # cannot splot in polar coordinates

    for letter in (:x, :y, :z)
        (letter === :z && dims == 2) && continue
        axis = sp.attr[get_attr_symbol(letter, :axis)]
        # label names
        push!(
            axesconf,
            "set $(letter)label '$(axis[:guide])' $(gaston_font(guidefont(axis)))",
        )
        mirror = axis[:mirror] ? "mirror" : "nomirror"

        logscale, base = if axis[:scale] === :identity
            "nologscale", ""
        elseif axis[:scale] === :log10
            "logscale", "10"
        elseif axis[:scale] === :log2
            "logscale", "2"
        elseif axis[:scale] === :ln
            "logscale", "e"
        end
        push!(axesconf, "set $logscale $letter $base")

        # handle ticks
        if polar
            push!(axesconf, "set size square\nunset $(letter)tics")
        else
            push!(
                axesconf,
                "set $(letter)tics $(mirror) $(axis[:tick_direction]) $(gaston_font(tickfont(axis)))",
            )

            # major tick locations
            if axis[:ticks] !== :native
                if axis[:flip]
                    hi, lo = axis_limits(sp, letter)
                else
                    lo, hi = axis_limits(sp, letter)
                end
                push!(axesconf, "set $(letter)range [$lo:$hi]")

                ticks = get_ticks(sp, axis)
                gaston_set_ticks!(axesconf, ticks, letter, "", "")

                if axis[:minorticks] !== :native
                    minor_ticks = get_minor_ticks(sp, axis, ticks)
                    gaston_set_ticks!(axesconf, minor_ticks, letter, "m", "add")
                end
            end
        end

        if axis[:grid]
            push!(axesconf, "set grid " * (polar ? "polar" : "$(letter)tics"))
            axis[:minorgrid] &&
                push!(axesconf, "set grid " * (polar ? "polar" : "m$(letter)tics"))
        end

        if (ratio = get_aspect_ratio(sp)) !== :none
            ratio === :equal && (ratio = -1)
            push!(axesconf, "set size ratio $ratio")
        end
    end
    gaston_set_legend!(axesconf, sp, any_label)

    hascolorbar(sp) && push!(axesconf, "set cbtics $(gaston_font(colorbartitlefont(sp)))")

    if sp[:title] !== nothing
        push!(axesconf, "set title '$(sp[:title])' $(gaston_font(titlefont(sp)))")
    end

    if polar
        push!(axesconf, "unset border\nset polar\nset border polar")
        tmin, tmax = axis_limits(sp, :x, false, false)
        rmin, rmax = axis_limits(sp, :y, false, false)
        rticks = get_ticks(sp, :y)
        if (ttype = ticksType(rticks)) === :ticks
            gaston_ticks = string.(rticks)
        elseif ttype === :ticks_and_labels
            gaston_ticks = String["'$l' $t" for (t, l) in zip(rticks...)]
        end
        push!(
            axesconf,
            "set rtics ( $(join(gaston_ticks, ", ")) ) $(gaston_font(tickfont(sp.attr[:yaxis])))",
            "set trange [$(min(0, tmin)):$(max(2π, tmax))]",
            "set rrange [$rmin:$rmax]",
            "set ttics 0,30 format \"%g\".GPVAL_DEGREE_SIGN $(gaston_font(tickfont(sp.attr[:xaxis])))",
            "set mttics 3",
        )
    end

    return join(axesconf, "\n")
end

function gaston_set_ticks!(axesconf, ticks, letter, maj_min, add)
    ticks === :auto && return
    if ticks ∈ (:none, nothing, false)
        push!(axesconf, "unset $(maj_min)$(letter)tics")
        return
    end

    gaston_ticks = String[]
    if (ttype = ticksType(ticks)) === :ticks
        tick_locs = @view ticks[:]
        for i in eachindex(tick_locs)
            tick = if maj_min == "m"
                "'' $(tick_locs[i]) 1"  # see gnuplot manual 'Mxtics'
            else
                "$(tick_locs[i])"
            end
            push!(gaston_ticks, tick)
        end
    elseif ttype === :ticks_and_labels
        tick_locs = @view ticks[1][:]
        tick_labels = @view ticks[2][:]
        for i in eachindex(tick_locs)
            lab = gaston_enclose_tick_string(tick_labels[i])
            push!(gaston_ticks, "'$lab' $(tick_locs[i])")
        end
    else
        gaston_ticks = nothing
        @error "Gaston: invalid input for $(maj_min)$(letter)ticks: $ticks ($ttype)"
    end
    if gaston_ticks !== nothing
        push!(axesconf, "set $(letter)tics $add (" * join(gaston_ticks, ", ") * ")")
    end
    nothing
end

function gaston_set_legend!(axesconf, sp, any_label)
    leg = sp[:legend_position]
    if sp[:legend_position] ∉ (:none, :inline) && any_label
        leg === :best && (leg = :topright)

        push!(
            axesconf,
            "set key " * (occursin("outer", string(leg)) ? "outside" : "inside"),
        )
        for position in ("top", "bottom", "left", "right")
            occursin(position, string(leg)) && push!(axesconf, "set key $position")
        end
        push!(axesconf, "set key $(gaston_font(legendfont(sp), rot=false, align=false))")
        if sp[:legend_title] !== nothing
            # NOTE: cannot use legendtitlefont(sp) as it will override legendfont
            push!(axesconf, "set key title '$(sp[:legend_title])'")
        end
        push!(axesconf, "set key box lw 1 opaque", "set border back")
    else
        push!(axesconf, "set key off")
    end
    nothing
end

# --------------------------------------------
# Helpers
# --------------------------------------------

gaston_halign(k) = (left = :left, hcenter = :center, right = :right)[k]
gaston_valign(k) = (top = :top, vcenter = :center, bottom = :bottom)[k]

gaston_alpha(alpha) = alpha === nothing ? 0 : alpha

gaston_lc_ls_lw(series::Series, clims, i::Int) = (
    gaston_color(get_linecolor(series, clims, i), get_linealpha(series, i)),
    gaston_linestyle(get_linestyle(series, i)),
    get_linewidth(series, i),
)

gaston_mk_ms_mc(series::Series, clims, i::Int) = (
    gaston_marker(_cycle(series[:markershape], i), get_markeralpha(series, i)),
    _cycle(series[:markersize], i) * 1.3 / 5,
    gaston_color(get_markercolor(series, clims, i), get_markeralpha(series, i)),
)

function gaston_font(f; rot = true, align = true, color = true, scale = 1)
    font = String["font '$(f.family),$(round(Int, scale * f.pointsize))'"]
    align && push!(font, "$(gaston_halign(f.halign))")
    rot && push!(font, "rotate by $(f.rotation)")
    color && push!(font, "textcolor $(gaston_color(f.color))")
    return join(font, " ")
end

function gaston_palette(gradient)
    palette = String[]
    n = -1
    for rgba in gradient  # FIXME: naive conversion, inefficient ?
        push!(palette, "$(n += 1) $(rgba.r) $(rgba.g) $(rgba.b)")
    end
    return '(' * join(palette, ", ") * ')'
end

function gaston_marker(marker, alpha)
    # NOTE: :rtriangle, :ltriangle, :hexagon, :heptagon, :octagon seems unsupported by gnuplot
    filled = gaston_alpha(alpha) == 0
    marker === :none && return -1
    marker === :pixel && return 0
    marker ∈ (:+, :cross) && return 1
    marker ∈ (:x, :xcross) && return 2
    marker === :star5 && return 3
    marker === :rect && return filled ? 5 : 4
    marker === :circle && return filled ? 7 : 6
    marker === :utriangle && return filled ? 9 : 8
    marker === :dtriangle && return filled ? 11 : 10
    marker === :diamond && return filled ? 13 : 12
    marker === :pentagon && return filled ? 15 : 14

    @warn "Gaston: unsupported marker $marker"
    return 1
end

function gaston_color(col, alpha = 0)
    col = single_color(col)  # in case of gradients
    col = alphacolor(col, gaston_alpha(alpha))  # add a default alpha if non existent
    return "rgb '#$(hex(col, :aarrggbb))'"
end

function gaston_linestyle(style)
    style === :solid && return "1"
    style === :dash && return "2"
    style === :dot && return "3"
    style === :dashdot && return "4"
    style === :dashdotdot && return "5"
end

function gaston_enclose_tick_string(tick_string)
    findfirst("^", tick_string) === nothing && return tick_string
    base, power = split(tick_string, "^")
    return "$base^{$power}"
end
