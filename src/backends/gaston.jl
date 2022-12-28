# https://github.com/mbaz/Gaston.

should_warn_on_unsupported(::GastonBackend) = false

# Create the window/figure for this backend.
function _create_backend_figure(plt::Plot{GastonBackend})
    state_handle = Gaston.nexthandle() # for now all the figures will be kept
    plt.o = Gaston.newfigure(state_handle)
end

function _before_layout_calcs(plt::Plot{GastonBackend})
    # initialize all the subplots first
    plt.o.subplots = Gaston.SubPlot[]

    foreach(sp -> gaston_init_subplot(plt, sp), unique(plt.inset_subplots))

    if length(plt.subplots) > 0
        n, sps = gaston_get_subplots(0, plt.subplots, plt.layout)
    end

    plt.o.layout = gaston_init_subplots(plt, sps)

    # then add the series (curves in gaston)
    foreach(series -> gaston_add_series(plt, series), plt.series_list)

    for sp in plt.subplots
        sp === nothing && continue
        for ann in sp[:annotations]
            x, y, val = locate_annotation(sp, ann...)
            sp.o.axesconf *= "; set label '$(val.str)' at $x,$y $(gaston_font(val.font))"
        end
        if _debug[]
            sp.o.axesconf = replace(sp.o.axesconf, "; " => "\n")
            println(sp.o.axesconf)
            foreach(x -> println("== n°$(x[1]) ==\n", x[2].conf), enumerate(sp.o.curves))
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
        tmpfile = tempname() * ".$term"

        ret = Gaston.save(;
            saveopts = gaston_saveopts(plt),
            handle = plt.o.handle,
            output = tmpfile,
            term,
        )
        if ret === nothing || ret
            while !isfile(tmpfile)
            end  # avoid race condition with read in next line
            write(io, read(tmpfile))
            rm(tmpfile, force = true)
        end
        nothing
    end
end

_display(plt::Plot{GastonBackend}) = display(plt.o)

# --------------------------------------------
# These functions are gaston specific
# --------------------------------------------

function gaston_saveopts(plt::Plot{GastonBackend})
    saveopts = ["size " * join(plt[:size], ',')]

    # scale all plot elements to match Plots.jl DPI standard
    scaling = plt[:dpi] / Plots.DPI

    push!(
        saveopts,
        gaston_font(
            plottitlefont(plt),
            rot = false,
            align = false,
            color = false,
            scale = 1,
        ),
        "background $(gaston_color(plt[:background_color]))",
        # "title '$(plt[:plot_title])'",  # FIXME: save hangs
        "fontscale $scaling lw $scaling dl $scaling",  # ps $scaling
    )

    join(saveopts, " ")
end

function gaston_get_subplots(n, plt_subplots, layout)
    nr, nc = size(layout)
    sps = Array{Any}(nothing, nr, nc)
    for r in 1:nr, c in 1:nc  # NOTE: col major
        sps[r, c] = if (l = layout[r, c]) isa GridLayout
            n, sub = gaston_get_subplots(n, plt_subplots, l)
            size(sub) == (1, 1) ? only(sub) : sub
        else
            if get(l.attr, :blank, false)
                nothing
            else
                n += 1
                l
            end
        end
    end
    n, sps
end

function gaston_init_subplots(plt, sps)
    sz = nr, nc = size(sps)
    for c in 1:nc, r in 1:nr  # NOTE: row major
        if (sp = sps[r, c]) isa Subplot || sp === nothing
            gaston_init_subplot(plt, sp)
        else
            gaston_init_subplots(plt, sp)
            sz = max.(sz, size(sp))
        end
    end
    sz
end

function gaston_init_subplot(
    plt::Plot{GastonBackend},
    sp::Union{Nothing,Subplot{GastonBackend}},
)
    obj = if sp === nothing
        sp
    else
        dims =
            RecipesPipeline.is3d(sp) || sp[:projection] == "3d" || needs_any_3d_axes(sp) ? 3 : 2
        any_label = false
        for series in series_list(sp)
            if dims == 2 && series[:seriestype] ∈ (:heatmap, :contour)
                dims = 3  # we need heatmap/contour to use splot, not plot
            end
            any_label |= should_add_to_legend(series)
        end
        axesconf = gaston_parse_axes_args(plt, sp, dims, any_label)
        sp.o = Gaston.Plot(; dims, curves = [], axesconf)
    end
    push!(plt.o.subplots, obj)
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
    dat
end

function gaston_multiplot_pos_size!(dat)
    nr, nc = size(dat)
    for r in 1:nr, c in 1:nc
        if (xy_wh_sp = dat[r, c]) isa Array
            gaston_multiplot_pos_size!(xy_wh_sp)
        elseif xy_wh_sp isa Tuple
            x, y, w, h, sp = xy_wh_sp
            sp === nothing && continue
            sp.o === nothing && continue
            # gnuplot screen coordinates: bottom left at 0,0 and top right at 1,1
            gx, gy = x, 1 - y - h
            # @show gx, gy w, h
            sp.o.axesconf = "set origin $gx, $gy; set size $w, $h; " * sp.o.axesconf
        end
    end
    nothing
end

function gaston_add_series(plt::Plot{GastonBackend}, series::Series)
    sp = series[:subplot]
    (gsp = sp.o) === nothing && return
    x, y, z = series[:x], series[:y], series[:z]
    st = series[:seriestype]
    curves = Gaston.Curve[]
    if gsp.dims == 2 && z === nothing
        for (n, seg) in enumerate(series_segments(series, st; check = true))
            i, rng = seg.attr_index, seg.range
            fr = _cycle(series[:fillrange], 1:length(x[rng]))
            for sc in gaston_seriesconf!(sp, series, n == 1, i)
                push!(curves, Gaston.Curve(x[rng], y[rng], nothing, fr, sc))
            end
        end
    else
        supp = nothing  # supplementary column
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
        elseif st === :surface
            if ndims(x) == ndims(y) == ndims(z) == 1
                # must reinterpret 1D data for `pm3d` (points are ordered)
                x, y = unique(x), unique(y)
                z = reshape(z, length(y), length(x))
            end
        end
        for sc in gaston_seriesconf!(sp, series, true, 1)
            push!(curves, Gaston.Curve(x, y, z, supp, sc))
        end
    end

    for c in curves
        append = length(gsp.curves) > 0
        push!(gsp.curves, c)
        Gaston.write_data(c, gsp.dims, gsp.datafile; append)
    end
    nothing
end

function gaston_seriesconf!(
    sp::Subplot{GastonBackend},
    series::Series,
    add_to_legend::Bool,
    i::Int,
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
    add_to_legend &= should_add_to_legend(series)
    curveconf = add_to_legend ? "title '$(series[:label])' " : "notitle "
    extra_curves = String[]

    clims = get_clims(sp, series)
    if st ∈ (:scatter, :scatter3d)
        lc, dt, lw = gaston_lc_ls_lw(series, clims, i)
        pt, ps, mc = gaston_mk_ms_mc(series, clims, i)
        curveconf *= "w points pt $pt ps $ps lc $mc"
    elseif st ∈ (:path, :straightline, :path3d)
        fr = series[:fillrange]
        fc = gaston_color(get_fillcolor(series, i), get_fillalpha(series, i))
        fs = gaston_fillstyle(get_fillstyle(series, i))
        lc, dt, lw = gaston_lc_ls_lw(series, clims, i)
        curveconf *= if fr !== nothing  # filled curves, but not filled curves with markers
            "w filledcurves fc $fc fs $fs border lc $lc lw $lw dt $dt,'' w lines lc $lc lw $lw dt $dt"
        elseif series[:markershape] === :none  # simplepath
            "w lines lc $lc dt $dt lw $lw"
        else
            pt, ps, mc = gaston_mk_ms_mc(series, clims, i)
            "w lp lc $mc dt $dt lw $lw pt $pt ps $ps"
        end
    elseif st === :shape
        fc = gaston_color(get_fillcolor(series, i), get_fillalpha(series, i))
        fs = gaston_fillstyle(get_fillstyle(series, i))
        lc, = gaston_lc_ls_lw(series, clims, i)
        curveconf *= "w filledcurves fc $fc fs $fs border lc $lc"
    elseif st ∈ (:steppre, :stepmid, :steppost)
        step = if st === :steppre
            "fsteps"
        elseif st === :stepmid
            "histeps"
        elseif st === :steppost
            "steps"
        end
        curveconf *= "w $step"
        lc, dt, lw = gaston_lc_ls_lw(series, clims, i)
        push!(extra_curves, "w points lc $lc dt $dt lw $lw notitle")
    elseif st === :image
        gsp.axesconf *= gaston_palette_conf(series)
        curveconf *= "w image pixels"
    elseif st ∈ (:contour, :contour3d)
        filled = isfilledcontour(series)
        curveconf *= filled ? "w pm3d" : "w lines"
        if series[:contour_labels] == true
            gsp.axesconf *= "; set cntrlabel interval -1"
            push!(extra_curves, "w labels notitle")
        end
        levels = collect(contour_levels(series, clims))
        if st === :contour  # 2D
            gsp.axesconf *= if filled
                "; set view map; set palette maxcolors $(length(levels))"
            else
                "; set view map; unset surface"
            end
        end
        gsp.axesconf *= "; set contour both; set cntrparam levels discrete $(join(map(string, levels), ", "))"
    elseif st ∈ (:surface, :heatmap)
        curveconf *= "w pm3d"
        gsp.axesconf *= gaston_palette_conf(series)
        st === :heatmap && (gsp.axesconf *= "; set view map")
    elseif st ∈ (:wireframe, :mesh3d)
        lc, dt, lw = gaston_lc_ls_lw(series, clims, i)
        curveconf *= "w lines lc $lc dt $dt lw $lw"
    elseif st === :quiver
        curveconf *= "w vectors filled"
    else
        @warn "Plots(Gaston): $st is not implemented yet"
    end

    [curveconf, extra_curves...]
end

const gp_borders = (
    bottom_left_front  = 1 << 0,
    bottom_left_back   = 1 << 1,
    bottom_right_front = 1 << 2,
    bottom_right_back  = 1 << 3,
    left_vertical      = 1 << 4,
    back_vertical      = 1 << 5,
    right_vertical     = 1 << 6,
    front_vertical     = 1 << 7,
    top_left_back      = 1 << 8,
    top_right_back     = 1 << 9,
    top_left_front     = 1 << 10,
    top_right_front    = 1 << 11,
    polar              = 1 << 11,
)

const gp_fillstyle = Dict(
    :x => 1,
    :\ => 4,
    :/ => 5,
    # :|, :-, :+  # unimplemented
)

gaston_fillstyle(x) =
    if haskey(gp_fillstyle, x)
        "pattern $(gp_fillstyle[x])"
    else
        "solid"
    end

function gaston_parse_axes_args(
    plt::Plot{GastonBackend},
    sp::Subplot{GastonBackend},
    dims::Int,
    any_label::Bool,
)
    # axesconf = ["set margins 2, 2, 2, 2"]  # left, right, bottom, top
    axesconf = String[]

    polar = ispolar(sp) && dims == 2  # cannot splot in polar coordinates

    fs = sp[:framestyle]
    for letter in (:x, :y, :z)
        (letter === :z && dims == 2) && continue
        axis = sp[get_attr_symbol(letter, :axis)]

        # NOTE: there is no `z2tics` concept in gnuplot (only 2D)
        I = if dims == 2 && axis[:mirror]
            push!(axesconf, "unset $(letter)tics")
            "2"
        else
            ""
        end

        # guide labels
        guide_font = guidefont(axis)
        if letter === :y && dims == 2
            # vertical by default (consistency witht other backends)
            guide_font = font(guide_font; rotation = guide_font.rotation + 90)
        end
        push!(
            axesconf,
            "set $(letter)$(I)label '$(axis[:guide])' $(gaston_font(guide_font))",
        )

        logscale, base = if (scale = axis[:scale]) === :identity
            "nologscale", ""
        elseif scale === :log10
            "logscale", "10"
        elseif scale === :log2
            "logscale", "2"
        elseif scale === :ln
            "logscale", "e"
        end
        push!(axesconf, "set $logscale $letter $base")

        # handle ticks
        if axis[:showaxis] && fs !== :none
            if polar
                push!(axesconf, "set size square; unset $(letter)tics")
            else
                push!(
                    axesconf,
                    "set $(letter)$(I)tics $(axis[:tick_direction]) $(gaston_font(tickfont(axis)))",
                )

                # major tick locations
                if axis[:ticks] !== :native
                    if axis[:flip]
                        hi, lo = axis_limits(sp, letter)
                    else
                        lo, hi = axis_limits(sp, letter)
                    end
                    push!(axesconf, "set $(letter)$(I)range [$lo:$hi]")

                    offset = if dims == 2 && letter == :y
                        # ticks appear too close to the border, offset them by 1 character
                        "offset " * string(axis[:mirror] ? 1 : -1)
                    else
                        ""
                    end
                    push!(axesconf, "set $(letter)$(I)tics border nomirror $offset")

                    ticks = get_ticks(sp, axis)
                    gaston_set_ticks!(axesconf, ticks, letter, I, "", "")

                    if axis[:minorticks] !== :native && !no_minor_intervals(axis)
                        minor_ticks = get_minor_ticks(sp, axis, ticks)
                        gaston_set_ticks!(axesconf, minor_ticks, letter, I, "m", "add")
                    end
                end
            end
        end
        if fs in (:zerolines, :origin)
            push!(axesconf, "set $(letter)zeroaxis")
        end
        if !axis[:showaxis] || fs === :none
            push!(axesconf, "set tics scale 0", "set format x \"\"", "set format y \"\"")
        end

        if axis[:grid]
            push!(axesconf, "set grid " * (polar ? "polar" : "$(letter)tics"))
            axis[:minorgrid] &&
                push!(axesconf, "set grid " * (polar ? "polar" : "m$(letter)tics"))
        end

        if (ratio = get_aspect_ratio(sp)) !== :none
            if dims == 2
                ratio === :equal && (ratio = -1)
                push!(axesconf, "set size ratio $ratio")
            else
                # ratio and square have no effect on 3D plots,
                # but do affect 3D projections created using set view map
                if ratio === :equal
                    push!(axesconf, "set view equal xyz")
                end
            end
        elseif dims == 3
            # by default unit x/y aspect ratio in 3d ?
            # push!(axesconf, "set view equal xy")
            # push!(axesconf, "set size square")
        end
    end
    gaston_set_legend!(axesconf, sp, any_label)

    # plots border
    border = if polar
        gp_borders[:polar]
    elseif dims == 2
        bottom = gp_borders[:bottom_left_front]
        left   = gp_borders[:bottom_left_back]
        top    = gp_borders[:bottom_right_front]
        right  = gp_borders[:bottom_right_back]
        if fs === :box
            bottom + left + top + right
        elseif fs === :semi
            bottom + left
        elseif fs === :axes
            (sp[:xaxis][:mirror] ? top : bottom) + (sp[:yaxis][:mirror] ? right : left)
        else
            0
        end
    else  # 3D
        (
            gp_borders[:bottom_left_front] +
            gp_borders[:bottom_left_back] +
            gp_borders[:bottom_right_front] +
            gp_borders[:bottom_right_back] +
            gp_borders[:left_vertical]
        )
    end
    push!(axesconf, border > 0 ? "set border $border back" : "unset border")

    if hascolorbar(sp)
        push!(
            axesconf,
            "set colorbox",
            "set cbtics border offset 1 $(gaston_font(colorbartitlefont(sp)))",
        )
    else
        push!(axesconf, "unset colorbox")
    end

    if sp[:title] != ""
        # NOTE: `set title` is hard centered, cannot use `sp[:titlelocation]`
        # on `set label` takes `right`, `center` or `left` justification
        push!(axesconf, "set title '$(sp[:title])' $(gaston_font(titlefont(sp)))")
    end

    if polar
        push!(axesconf, "set polar")
        tmin, tmax = axis_limits(sp, :x, false, false)
        rmin, rmax = axis_limits(sp, :y, false, false)
        rticks = get_ticks(sp, :y)
        gaston_ticks = if (ttype = ticksType(rticks)) === :ticks
            string.(rticks)
        elseif ttype === :ticks_and_labels
            ["'$l' $t" for (t, l) in zip(rticks...)]
        end
        push!(
            axesconf,
            "set rtics ( $(join(gaston_ticks, ", ")) ) $(gaston_font(tickfont(sp[:yaxis])))",
            "set trange [$(min(0, tmin)):$(max(2π, tmax))]",
            "set rrange [$rmin:$rmax]",
            "set ttics 0,30 format \"%g\".GPVAL_DEGREE_SIGN $(gaston_font(tickfont(sp[:xaxis])))",
            "set mttics 3",
        )
    end

    join(axesconf, "; ")
end

function gaston_fix_ticks_overflow(ticks::AbstractVector)
    if eltype(ticks) <: Integer
        of = if isdefined(Gaston, :GNUPLOT_VERSION)
            # toggle Int32 - Int64 for older gnuplot version
            typemax(Gaston.GNUPLOT_VERSION ≥ v"5.4.0" ? Int64 : Int32)
        else
            typemax(Int32)
        end
        any(t -> abs(t) > of, ticks) && return float.(ticks)
    end
    ticks
end

function gaston_set_ticks!(axesconf, ticks, letter, I, maj_min, add)
    ticks === :auto && return
    if ticks ∈ (:none, nothing, false)
        push!(axesconf, "unset $(maj_min)$(letter)tics")
        return
    end
    gaston_ticks = if (ttype = ticksType(ticks)) === :ticks
        tics = gaston_fix_ticks_overflow(ticks)
        if maj_min == "m"
            map(t -> "'' $t 1", tics)  # see gnuplot manual 'Mxtics'
        else
            map(string, tics)
        end
    elseif ttype === :ticks_and_labels
        tics = gaston_fix_ticks_overflow(first(ticks))
        labs = last(ticks)
        map(i -> "'$(gaston_enclose_tick_string(labs[i]))' $(tics[i])", eachindex(tics))
    else
        @error "Gaston: invalid input for $(maj_min)$(letter)ticks: $ticks ($ttype)"
        nothing
    end
    if gaston_ticks !== nothing
        push!(axesconf, "set $(letter)$(I)tics $add (" * join(gaston_ticks, ", ") * ")")
    end
    nothing
end

function gaston_set_legend!(axesconf, sp, any_label)
    if (lp = sp[:legend_position]) ∉ (:none, :inline) && any_label
        leg_str = string(_guess_best_legend_position(lp, sp))

        pos = occursin("outer", leg_str) ? "outside " : "inside "
        pos *= if occursin("top", leg_str)
            "top "
        elseif occursin("bottom", leg_str)
            "bottom "
        else
            "center "
        end
        pos *= if occursin("left", leg_str)
            "left "
        elseif occursin("right", leg_str)
            "right "
        else
            "center "
        end
        pos *= sp[:legend_column] == 1 ? "vertical" : "horizontal"
        push!(axesconf, "set key $pos box lw 1 opaque noautotitle")
        push!(axesconf, "set key $(gaston_font(legendfont(sp), rot=false, align=false))")
        if sp[:legend_title] !== nothing
            # NOTE: cannot use legendtitlefont(sp) as it will override legendfont
            push!(axesconf, "set key title '$(sp[:legend_title])'")
        end
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

# from the gnuplot docs:
# - an alpha value of 0 represents a fully opaque color; i.e., "#00RRGGBB" is the same as "#RRGGBB".
# - an alpha value of 255 (FF) represents full transparency
gaston_alpha(alpha) = alpha === nothing ? 0 : alpha

gaston_lc_ls_lw(series::Series, clims, i::Int) = (
    gaston_color(get_linecolor(series, clims, i), get_linealpha(series, i)),
    gaston_linestyle(get_linestyle(series, i)),
    get_linewidth(series, i),
)

gaston_mk_ms_mc(series::Series, clims, i::Int) = (
    gaston_marker(_cycle(series[:markershape], i), get_markeralpha(series, i)),
    0.2_cycle(series[:markersize], i),
    gaston_color(get_markercolor(series, clims, i), get_markeralpha(series, i)),
)

function gaston_font(f; rot = true, align = true, color = true, scale = 1)
    font = "font '$(f.family),$(round(Int, scale * f.pointsize))'"
    align && (font *= " $(gaston_halign(f.halign))")
    rot && (font *= " rotate by $(f.rotation)")
    color && (font *= " textcolor $(gaston_color(f.color))")
    font
end

gaston_palette(gradient) =
    let palette = ["$(n - 1) $(c.r) $(c.g) $(c.b)" for (n, c) in enumerate(gradient)]
        '(' * join(palette, ", ") * ')'
    end

gaston_palette_conf(series) =
    "; set palette model RGB defined $(gaston_palette(series[:seriescolor]))"

function gaston_marker(marker, alpha)
    # NOTE: :rtriangle, :ltriangle, :hexagon, :heptagon, :octagon seems unsupported by gnuplot
    filled = gaston_alpha(alpha) != 1
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
    # @debug "Plots(Gaston): unsupported marker $marker"
    1
end

function gaston_color(col, alpha = 0)
    col = single_color(col)  # in case of gradients
    col = alphacolor(col, gaston_alpha(alpha))  # add a default alpha if non existent
    "rgbcolor '#$(hex(col, :aarrggbb))'"
end

function gaston_linestyle(style)
    style === :solid && return 1
    style === :dash && return 2
    style === :dot && return 3
    style === :dashdot && return 4
    style === :dashdotdot && return 5
    1
end

function gaston_enclose_tick_string(tick_string)
    findfirst('^', tick_string) === nothing && return tick_string
    base, power = split(tick_string, '^')
    "$base^{$power}"
end
