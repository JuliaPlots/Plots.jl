# https://github.com/mbaz/Gaston.

# --------------------------------------------
# These functions are called by Plots
# --------------------------------------------

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
    for series ∈ plt.series_list
        gaston_add_series(plt, series)
    end
    
    for sp ∈ plt.subplots
        sp === nothing && continue
        for ann in sp[:annotations]
            x, y, val = locate_annotation(sp, ann...)
            sp.o.axesconf *= "\nset label '$(val.str)' at $x,$y $(gaston_font(val.font))"
        end
    end
    nothing
end

function _update_min_padding!(sp::Subplot{GastonBackend})
    # FIXME: make this more flexible
    sp.minpad = (20mm, 5mm, 2mm, 10mm)
end

function _update_plot_object(plt::Plot{GastonBackend})
    # respect the layout ratio
    xy_wh = gaston_multiplot_pos_size(plt.layout, (0, 0, 1, 1), 0)
    gaston_multiplot_pos_size!(0, xy_wh)
end

for (mime, term) ∈ (
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
        term = String($term); tmpfile = "$(Gaston.tempname()).$term"
        Gaston.save(term=term, output=tmpfile, handle=plt.o.handle, saveopts=gaston_saveopts(plt))
        while !isfile(tmpfile) end  # avoid race condition with read in next line
        write(io, read(tmpfile))
        rm(tmpfile, force=true)
        nothing
    end
end

_display(plt::Plot{GastonBackend}) = display(plt.o)

# --------------------------------------------
# These functions are gaston specific
# --------------------------------------------

function gaston_saveopts(plt::Plot{GastonBackend})
    xsize, ysize = plt.attr[:size]
    saveopts = "size $xsize,$ysize background $(gaston_color(plt.attr[:background_color]))"

    # Scale all plot elements to match Plots.jl DPI standard
    scaling = plt.attr[:dpi] / Plots.DPI
    saveopts *= "fontscale $scaling lw $scaling dl $scaling ps $scaling"
    
    return saveopts
end

function gaston_get_subplots(n, plt_subplots, layout)
    nr, nc = size(layout)
    sps = Array{Any}(nothing, nr, nc)
    for r ∈ 1:nr, c ∈ 1:nc  # NOTE: col major
        l = layout[r, c]
        if l isa GridLayout
            n, sub = gaston_get_subplots(n, plt_subplots, l)
            sps[r, c] = size(sub) == (1, 1) ? only(sub) : sub
        else
            sps[r, c] = get(l.attr, :blank, false) ? nothing : plt_subplots[n += 1]
        end
    end
    return n, sps
end

function gaston_init_subplots(plt, sps)
    sz = nr, nc = size(sps)
    for c ∈ 1:nc, r ∈ 1:nr  # NOTE: row major
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

function gaston_init_subplot(plt::Plot{GastonBackend}, sp::Union{Nothing,Subplot{GastonBackend}})
    if sp === nothing
        push!(plt.o.subplots, sp)
    else
        dims = RecipesPipeline.is3d(sp) || sp.attr[:projection] == "3d" || needs_any_3d_axes(sp) ? 3 : 2
        any_label = false
        if dims == 2
            for series ∈ plt.series_list
                if series[:seriestype] ∈ (:heatmap, :contour)
                    dims = 3  # we need heatmap/contour to use splot, not plot
                end
                any_label |= should_add_to_legend(series)
            end
        end
        sp.o = Gaston.Plot(
            dims=dims,
            axesconf=gaston_parse_axes_args(plt, sp, dims, any_label),  # Gnuplot string
            curves=[]
        )
        push!(plt.o.subplots, sp.o)
    end
    nothing
end

function gaston_multiplot_pos_size(layout, parent_xy_wh)
    nr, nc = size(layout)
    xy_wh_sp = Array{Any}(nothing, nr, nc)
    for r ∈ 1:nr, c ∈ 1:nc  # NOTE: col major
        l = layout[r, c]
        if !isa(l, EmptyLayout)
            # previous position (origin)
            prev_r = r > 1 ? xy_wh_sp[r - 1, c] : nothing
            prev_c = c > 1 ? xy_wh_sp[r, c - 1] : nothing
            prev_r isa Array && (prev_r = prev_r[end, end])
            prev_c isa Array && (prev_c = prev_c[end, end])
            x = prev_c !== nothing ? prev_c[1] + prev_c[3] : parent_xy_wh[1]
            y = prev_r !== nothing ? prev_r[2] + prev_r[4] : parent_xy_wh[2]
            # width and height (pct) are multiplicative (parent)
            w = layout.widths[c].value * parent_xy_wh[3]
            h = layout.heights[r].value * parent_xy_wh[4]
            if l isa GridLayout
                sub = gaston_multiplot_pos_size(l, (x, y, w, h))
                xy_wh_sp[r, c] = size(sub) == (1, 1) ? only(sub) : sub
            else
                xy_wh_sp[r, c] = x, y, w, h, l
            end
        end
    end
    return xy_wh_sp
end

function gaston_multiplot_pos_size!(n::Int, dat)
    nr, nc = size(dat)
    for c ∈ 1:nc, r ∈ 1:nr  # NOTE: row major
        xy_wh_sp = dat[r, c]
        if xy_wh_sp isa Array
            n = gaston_multiplot_pos_size!(n, xy_wh_sp)
        elseif xy_wh_sp isa Tuple
            x, y, w, h, sp = xy_wh_sp
            sp === nothing && continue
            sp.o === nothing && continue
            sp.o.axesconf = "set origin $x,$y\nset size $w,$h\n" * sp.o.axesconf
        end
    end
    return n
end

function gaston_add_series(plt::Plot{GastonBackend}, series::Series)
    sp = series[:subplot]; gsp = sp.o
    x, y, z = series[:x], series[:y], series[:z]
    st = series[:seriestype]

    curves = []
    if gsp.dims == 2 && z === nothing
        for seg ∈ series_segments(series, st; check=true)
            i, rng = seg.attr_index, seg.range
            for sc ∈ gaston_seriesconf!(sp, series, i)
                push!(curves, Gaston.Curve(x[rng], y[rng], nothing, nothing, sc))
            end
        end
    else
        seriesconf = gaston_seriesconf!(sp, series, 1)
        if z isa Surface
            z = z.surf
            if st == :image
                z = Float32.(Gray.(z))
                nr, nc = size(z)
                lx = length(x)
                if lx == 2 && lx != nr
                    x = collect(range(x[1], x[2], length=nr))
                end
                ly = length(y)
                if ly == 2 && ly != nc
                    y = collect(range(y[1], y[2], length=nc))
                end
            end
        end
        for sc ∈ gaston_seriesconf!(sp, series, 1)
            push!(curves, Gaston.Curve(x, y, z, nothing, sc))
        end
    end

    for c ∈ curves
        append = length(gsp.curves) > 0; push!(gsp.curves, c)
        Gaston.write_data(c, gsp.dims, gsp.datafile, append=append)
    end
    nothing
end

function gaston_hvline!(sp, series, curveconf, pt, dt, lw, lc, command)
    if pt == :hline
        lo, hi = axis_limits(sp, :x)
        for y ∈ series[:y]
            sp.o.axesconf *= "\nset arrow from $lo,$y to $hi,$y nohead lc $lc lw $lw dt $dt"
        end
    elseif pt == :vline
        lo, hi = axis_limits(sp, :y)
        for x ∈ series[:x]
            sp.o.axesconf *= "\nset arrow from $x,$lo to $x,$hi nohead lc $lc lw $lw dt $dt"
        end
    else
        push!(curveconf, command)
    end
    nothing
end

function gaston_seriesconf!(sp::Subplot{GastonBackend}, series::Series, i::Int)
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
    gsp = sp.o; st = series[:seriestype]; extra = []
    curveconf = String[should_add_to_legend(series) ? "title '$(series[:label])'" : "notitle"]

    clims = get_clims(sp, series)
    if st ∈ (:scatter, :scatter3d)
        lc, dt, lw = gaston_lc_ls_lw(series, clims, i)
        pt, ps, mc = gaston_mk_ms_mc(series, clims, i)
        gaston_hvline!(sp, series, curveconf, pt, dt, lw, mc, "w points pt $pt ps $ps lc $mc")
    elseif st ∈ (:path, :straightline, :path3d)
        lc, dt, lw = gaston_lc_ls_lw(series, clims, i)
        if series[:markershape] == :none  # simplepath
            push!(curveconf, "w lines lc $lc dt $dt lw $lw")
        else
            pt, ps, mc = gaston_mk_ms_mc(series, clims, i)
            gaston_hvline!(sp, series, curveconf, pt, dt, lw, mc, "w lp lc $mc dt $dt lw $lw pt $pt ps $ps")
        end
    elseif st == :shape
        fc = gaston_color(get_fillcolor(series, i), get_fillalpha(series, i))
        lc, _ = gaston_lc_ls_lw(series, clims, i)
        push!(curveconf, "w filledcurves fc $fc fs solid border lc $lc")
    elseif st ∈ (:steppre, :stepmid, :steppost)
        step = if st == :steppre
            "fsteps"
        elseif st == :stepmid
            "histeps"
        elseif st == :steppost
            "steps"
        end
        push!(curveconf, "w $step")
        lc, dt, lw = gaston_lc_ls_lw(series, clims, i)
        push!(extra, "w points lc $lc dt $dt lw $lw notitle")
    elseif st == :image
        palette = gaston_palette(series[:seriescolor])
        gsp.axesconf *= "\nset palette model RGB defined $palette"
        push!(curveconf, "w image pixels")
    elseif st ∈ (:contour, :contour3d)
        push!(curveconf, "w lines")
        st == :contour && (gsp.axesconf *= "\nset view map\nunset surface")  # 2D
        gsp.axesconf *= "\nunset key"  # FIXME: too many legend (key) entries
        levels = join(map(string, collect(contour_levels(series, clims))), ", ")
        gsp.axesconf *= "\nset contour base\nset cntrparam levels discrete $levels"
    elseif st ∈ (:surface, :heatmap)
        push!(curveconf, "w pm3d")
        palette = gaston_palette(series[:seriescolor])
        gsp.axesconf *= "\nset palette model RGB defined $palette"
        st == :heatmap && (gsp.axesconf *= "\nset view map")
    elseif st == :wireframe
        lc, dt, lw = gaston_lc_ls_lw(series, clims, i)
        push!(curveconf, "w lines lc $lc dt $dt lw $lw")
    else
        @warn "Gaston: $st is not implemented yet"
    end

    return [join(curveconf, " "), extra...]
end

function gaston_parse_axes_args(
    plt::Plot{GastonBackend}, sp::Subplot{GastonBackend}, dims::Int, any_label::Bool
)
    axesconf = String["reset"]
    # Standard 2d axis
    if !ispolar(sp) && !RecipesPipeline.is3d(sp)
        # TODO: configure grid, axis spines, thickness
    end

    for letter ∈ (:x, :y, :z)
        (letter == :z && dims == 2) && continue
        axis = sp.attr[Symbol(letter, :axis)]
        # label names
        push!(axesconf, "set $(letter)label '$(axis[:guide])' $(gaston_font(guidefont(axis)))")
        mirror = axis[:mirror] ? "mirror" : "nomirror"

        # handle ticks
        push!(axesconf, "set $(letter)tics $(mirror) $(axis[:tick_direction]) $(gaston_font(tickfont(axis)))")

        if axis[:scale] == :identity
            logscale, base = "nologscale", ""
        elseif axis[:scale] == :log10
            logscale, base = "logscale", "10"
        elseif axis[:scale] == :log2
            logscale, base = "logscale", "2"
        elseif axis[:scale] == :ln
            logscale, base = "logscale", "e"
        end
        push!(axesconf, "set $logscale $letter $base")

        # major tick locations
        if axis[:ticks] != :native
            if axis[:flip]
                hi, lo = axis_limits(sp, letter)
            else
                lo, hi = axis_limits(sp, letter)
            end
            push!(axesconf, "set $(letter)range [$lo:$hi]")

            ticks = get_ticks(sp, axis)
            gaston_set_ticks!(axesconf, ticks, letter, "", "")

            if axis[:minorticks] != :native
                minor_ticks = get_minor_ticks(sp, axis, ticks)
                gaston_set_ticks!(axesconf, minor_ticks, letter, "m", "add")
            end
        end
        
        if axis[:grid]
            push!(axesconf, "set grid $(letter)tics")
            axis[:minorgrid] && push!(axesconf, "set grid m$(letter)tics")
        end

        ratio = get_aspect_ratio(sp)
        if ratio != :none
            ratio == :equal && (ratio = -1)
            push!(axesconf, "set size ratio $ratio")
        end
    end
    gaston_set_legend!(axesconf, sp, any_label)

    if hascolorbar(sp)
        push!(axesconf, "set cbtics $(gaston_font(colorbartitlefont(sp)))")
    end

    if sp[:title] !== nothing
        push!(axesconf, "set title '$(sp[:title])' $(gaston_font(titlefont(sp)))")
    end

    return join(axesconf, "\n")
end

function gaston_set_ticks!(axesconf, ticks, letter, maj_min, add)
    ticks == :auto && return
    if ticks ∈ (:none, nothing, false)
        push!(axesconf, "unset $(maj_min)$(letter)tics")
        return
    end

    ttype = ticksType(ticks)
    gaston_ticks = String[]
    if ttype == :ticks
        tick_locs = @view ticks[:]
        for i ∈ eachindex(tick_locs)
            tick = if maj_min == "m"
                "'' $(tick_locs[i]) 1"  # see gnuplot manual 'Mxtics'
            else
                "$(tick_locs[i])"
            end
            push!(gaston_ticks, tick)
        end
    elseif ttype == :ticks_and_labels
        tick_locs = @view ticks[1][:]
        tick_labels = @view ticks[2][:]
        for i ∈ eachindex(tick_locs)
            lab = gaston_enclose_tick_string(tick_labels[i])
            push!(gaston_ticks, "'$lab' $(tick_locs[i])")
        end
    else
        gaston_ticks = nothing
        @error "Gaston: invalid input for $(maj_min)$(letter)ticks: $ticks"
    end
    if gaston_ticks !== nothing
        push!(axesconf, "set $(letter)tics $add (" * join(gaston_ticks, ", ") * ")")
    end
    nothing
end

function gaston_set_legend!(axesconf, sp, any_label)
    leg = sp[:legend]
    if sp[:legend] ∉ (:none, :inline) && any_label
        leg == :best && (leg = :topright)

        push!(axesconf, "set key " * (occursin("outer", string(leg)) ? "outside" : "inside"))
        for position ∈ ("top", "bottom", "left", "right")
            occursin(position, string(leg)) && push!(axesconf, "set key $position")
        end
        push!(axesconf, "set key $(gaston_font(legendfont(sp), rot=false, align=false))")
        if sp[:legendtitle] !== nothing
            push!(axesconf, "set key title '$(sp[:legendtitle])'")
        end
        push!(axesconf, "set key box lw 1 opaque")
        push!(axesconf, "set border back")
    else
        push!(axesconf, "set key off")
    end
    nothing
end

# --------------------------------------------
# Helpers
# --------------------------------------------

function gaston_font(f; rot=true, align=true)
    font = "font '$(f.family),$(f.pointsize)' "
    align && (font *= "$(gaston_halign(f.halign)) ")
    rot && (font *= "rotate by $(f.rotation) ")
    font *= "textcolor $(gaston_color(f.color))"
end

gaston_halign(k) = (left=:left, hcenter=:center, right=:right)[k]
gaston_valign(k) = (top=:top, vcenter=:center, bottom=:bottom)[k]

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

function gaston_palette(gradient)
    palette = String[]; n = -1
    for rgba ∈ gradient  # FIXME: naive conversion, inefficient ?
        push!(palette, "$(n += 1) $(rgba.r) $(rgba.g) $(rgba.b)")
    end
    return '(' * join(palette, ", ") * ')'
end

function gaston_marker(marker, alpha)
    # NOTE: :rtriangle, :ltriangle, :hexagon, :heptagon, :octagon seems unsupported by gnuplot
    filled = gaston_alpha(alpha) == 0
    marker == :none && return -1
    marker == :pixel && return 0
    marker ∈ (:+, :cross) && return 1
    marker ∈ (:x, :xcross) && return 2
    marker == :star5 && return 3
    marker == :rect && return filled ? 5 : 4
    marker == :circle && return filled ? 7 : 6
    marker == :utriangle && return filled ? 9 : 8
    marker == :dtriangle && return filled ? 11 : 10
    marker == :diamond && return filled ? 13 : 12
    marker == :pentagon && return filled ? 15 : 14
    marker ∈ (:vline, :hline) && return marker

    @warn "Gaston: unsupported marker $marker"
    return 1
end

function gaston_color(col, alpha=0)
    col = single_color(col)  # in case of gradients
    col = alphacolor(col, gaston_alpha(alpha))  # add a default alpha if non existent
    return "rgb '#$(hex(col, :aarrggbb))'"
end

function gaston_linestyle(style)
    style == :solid && return "1"
    style == :dash && return "2"
    style == :dot && return "3"
    style == :dashdot && return "4"
    style == :dashdotdot && return "5"
end

function gaston_enclose_tick_string(tick_string)
    findfirst("^", tick_string) === nothing && return tick_string
    base, power = split(tick_string, "^")
    return "$base^{$power}"
end
