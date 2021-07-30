# https://github.com/mbaz/Gaston.
const G = Gaston
const GastonSubplot = G.Plot
const GASTON_MARKER_SCALING = 1.3 / 5.0

# --------------------------------------------
# These functions are called by Plots
# --------------------------------------------

# Create the window/figure for this backend.
function _create_backend_figure(plt::Plot{GastonBackend})
    xsize, ysize = plt.attr[:size]
    G.set(termopts="size $xsize,$ysize")

    state_handle = G.nexthandle() # for now all the figures will be kept
    plt.o = G.newfigure(state_handle)
end


function _before_layout_calcs(plt::Plot{GastonBackend})
    # Initialize all the subplots first
    plt.o.subplots = G.SubPlot[]

    n1 = n2 = 0
    if length(plt.inset_subplots) > 0
        n1, sps = gaston_get_subplots(0, plt.inset_subplots, plt.layout)
        gaston_init_subplots(plt, sps)
    end

    if length(plt.subplots) > 0
        n2, sps = gaston_get_subplots(0, plt.subplots, plt.layout)
    end

    n = n1 + n2
    if n != length(plt.subplots)
        @error "Gaston: $n != $(length(plt.subplots))"
    end

    plt.o.layout = gaston_init_subplots(plt, sps)

    # Then add the series (curves in gaston)
    for series in plt.series_list
        gaston_add_series(plt, series)
    end
    nothing
end

function _update_min_padding!(sp::Subplot{GastonBackend})
    # FIXME: make this more flexible
    sp.minpad = (20mm, 5mm, 2mm, 10mm)
end

function _update_plot_object(plt::Plot{GastonBackend})
    # respect the layout ratio
    xy_wh = gaston_multiplot_pos_size(plt.layout, (0, 0, 1, 1))
    gaston_multiplot_pos_size!(0, plt, xy_wh)
end

for (mime, term) in (
    "application/eps"         => "epscairo",   # NEED fixing TODO
    "image/eps"               => "epslatex",   # NEED fixing TODO
    "application/pdf"         => "pdfcairo",   # NEED fixing TODO
    "application/postscript"  => "postscript", # NEED fixing TODO
    "image/svg+xml"           => "svg",
    "text/latex"              => "tikz",       # NEED fixing TODO
    "application/x-tex"       => "epslatex",   # NEED fixing TODO
    "text/plain"              => "dumb",       # NEED fixing TODO
)
    @eval function _show(io::IO, ::MIME{Symbol($mime)}, plt::Plot{GastonBackend})
        tmpfile = G.tempname() * "." * $term
        G.save(
            term=$term,
            output=tmpfile,
            handle=plt.o.handle,
        )
        while !isfile(tmpfile) end  # avoid race condition with read in next line
        write(io, read(tmpfile))
        rm(tmpfile, force=true)
        nothing
    end
end

function _show(io::IO, mime::MIME{Symbol("image/png")}, plt::Plot{GastonBackend})
    scaling = plt.attr[:dpi] / Plots.DPI

    # Scale all plot elements to match Plots.jl DPI standard
    saveopts = "fontscale $scaling lw $scaling dl $scaling ps $scaling"

    tmpfile = G.tempname()
    G.save(
        term="pngcairo",
        output=tmpfile,
        handle=plt.o.handle,
        saveopts=saveopts
    )
    while !isfile(tmpfile) end  # avoid race condition with read in next line
    write(io, read(tmpfile))
    rm(tmpfile, force=true)
    nothing
end

_display(plt::Plot{GastonBackend}) = display(plt.o)

# --------------------------------------------
# These functions are gaston specific
# --------------------------------------------

function gaston_get_subplots(n, plt_subplots, layout)
    nr, nc = size(layout)
    sps = Array{Any}(undef, nr, nc)
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
        sp.o = GastonSubplot(
            dims=RecipesPipeline.is3d(sp) ? 3 : 2,
            axesconf=gaston_parse_axes_args(plt, sp),  # Gnuplot string
            curves=[]
        )
        push!(plt.o.subplots, sp.o)
    end
    nothing
end

function gaston_multiplot_pos_size(layout, parent_xy_wh)
    nr, nc = size(layout)
    xy_wh = Array{Any}(undef, nr, nc)
    for r ∈ 1:nr, c ∈ 1:nc  # NOTE: col major
        l = layout[r, c]
        if !isa(l, EmptyLayout)
            # previous position (origin)
            prev_r = r > 1 ? xy_wh[r - 1, c] : undef
            prev_c = c > 1 ? xy_wh[r, c - 1] : undef
            prev_r isa Array{Any} && (prev_r = prev_r[end, end])
            prev_c isa Array{Any} && (prev_c = prev_c[end, end])
            x = prev_c !== undef ? prev_c[1] + prev_c[3] : parent_xy_wh[1]
            y = prev_r !== undef ? prev_r[2] + prev_r[4] : parent_xy_wh[2]
            # width and height (pct) are multiplicative (parent)
            w = layout.widths[c].value * parent_xy_wh[3]
            h = layout.heights[r].value * parent_xy_wh[4]
            if l isa GridLayout
                xy_wh[r, c] = gaston_multiplot_pos_size(l, (x, y, w, h))
            else
                xy_wh[r, c] = x, y, w, h
            end
        end
    end
    return xy_wh
end

function gaston_multiplot_pos_size!(n::Int, plt, origin_size)
    nr, nc = size(origin_size)
    for c ∈ 1:nc, r ∈ 1:nr  # NOTE: row major
        xy_wh = origin_size[r, c]
        if xy_wh === undef
            continue
        elseif xy_wh isa Tuple
            x, y, w, h = xy_wh
            gsp = plt.o.subplots[n += 1]
            gsp.axesconf = "set origin $x,$y\nset size $w,$h\n" * gsp.axesconf
        else
            n = gaston_multiplot_pos_size!(n, plt, xy_wh)
        end
    end
    return n
end

function gaston_add_series(plt::Plot{GastonBackend}, series::Series)
    # Gaston.Curve = Plots.Series
    sp = series[:subplot]
    g_sp = sp.o  # Gaston subplot object

    if series[:seriestype] ∈ (:heatmap, :contour) && g_sp.dims == 2
        g_sp.dims = 3  # FIXME: this is ugly, we need heatmap/contour to use splot, not plot
    end

    x = series[:x]
    y = series[:y]
    z = g_sp.dims == 2 ? nothing : series[:z]
    if z isa Surface
        z = z.surf
    end

    seriesconf = gaston_seriesconf!(sp, series)  # Gnuplot string
    c = G.Curve(x, y, z, nothing, seriesconf)

    isfirst = length(g_sp.curves) == 0 ? true : false
    push!(g_sp.curves, c)
    G.write_data(c, g_sp.dims, g_sp.datafile, append = isfirst ? false : true)
    nothing
end

function gaston_seriesconf!(sp, series::Series)
    gsp = sp.o
    curveconf = String[]
    st = series[:seriestype]

    clims = get_clims(sp, series)
    label = "title \"$(series[:label])\""
    if st ∈ (:scatter, :scatter3d)
        pt, ps, lc = gaston_mk_ms_mc(series)
        push!(curveconf, "with points pt $pt ps $ps lc $lc")
    elseif st ∈ (:path, :straightline, :path3d)
        lc, dt, lw = gaston_lc_ls_lw(series)
        if series[:markershape] == :none # simplepath
            push!(curveconf, "with lines lc $lc dt $dt lw $lw")
        else
            pt, ps = gaston_mk_ms_mc(series)
            push!(curveconf, "with lp lc $lc dt $dt lw $lw pt $pt ps $ps")
        end
    elseif st == :shape
        fc = gaston_color(series[:fillcolor], series[:fillalpha])
        fs = "solid"
        lc, _ = gaston_lc_ls_lw(series)
        push!(curveconf, "with filledcurves fc $fc fs $fs border lc $lc")
    elseif st == :steppre
        push!(curveconf, "with steps")
    elseif st == :steppost
        push!(curveconf, "with fsteps")  # Not sure if not the other way
    elseif st ∈ (:contour, :contour3d)
        label = "notitle"
        push!(curveconf, "with lines")
        if st == :contour
            gsp.axesconf *= "\nset view map\nunset surface"
        end
        gsp.axesconf *= "\nunset key"
        levels = join(map(string, collect(contour_levels(series, clims))), ", ")
        gsp.axesconf *= "\nset contour base\nset cntrparam levels discrete $levels"
    elseif st ∈ (:surface, :heatmap)
        palette = gaston_palette(series[:seriescolor])
        gsp.axesconf *= "\nset palette model RGB defined $palette"
        if st == :heatmap
            gsp.axesconf *= "\nset view map"
        end
        push!(curveconf, "with pm3d")
    elseif st == :wireframe
        lc, dt, lw = gaston_lc_ls_lw(series)
        push!(curveconf, "with lines lc $lc dt $dt lw $lw")
    else
        @warn "Gaston: $st is not implemented yet"
    end

    push!(curveconf, label)
    return join(curveconf, " ")
end

function gaston_parse_axes_args(plt::Plot{GastonBackend}, sp::Subplot{GastonBackend})
    axesconf = String[]
    # Standard 2d axis
    if !ispolar(sp) && !RecipesPipeline.is3d(sp)
        # TODO: configure grid, axis spines, thickness
    end

    for letter in (:x, :y, :z)
        axis_attr = sp.attr[Symbol(letter, :axis)]
        # label names
        push!(axesconf, "set $(letter)label \"$(axis_attr[:guide])\"")
        push!(axesconf, "set $(letter)label font \"$(axis_attr[:guidefontfamily]), $(axis_attr[:guidefontsize])\"")

        # Handle ticks
        # ticksyle
        push!(axesconf, "set $(letter)tics font \"$(axis_attr[:tickfontfamily]), $(axis_attr[:tickfontsize])\"")
        push!(axesconf, "set $(letter)tics textcolor rgb \"#$(hex(axis_attr[:tickfontcolor], :rrggbb))\"")
        push!(axesconf, "set $(letter)tics  $(axis_attr[:tick_direction])")

        mirror = axis_attr[:mirror] ? "mirror" : "nomirror"
        push!(axesconf, "set $(letter)tics $(mirror)")

        logscale = if axis_attr[:scale] == :identity
            "nologscale"
        elseif axis_attr[:scale] == :log10
            "logscale"
        end
        push!(axesconf, "set $logscale $(letter)")

        # tick locations
        if axis_attr[:ticks] != :native
            # axis limits
            from, to = axis_limits(sp, letter)
            push!(axesconf, "set $(letter)range [$from:$to]")

            ticks = get_ticks(sp, axis_attr)
            gaston_set_ticks!(axesconf, ticks, letter)
        end

        ratio = get_aspect_ratio(sp)
        if ratio != :none
            if ratio == :equal
                ratio = -1
            end
            push!(axesconf, "set size ratio $ratio")
        end
    end
    gaston_set_legend!(axesconf, sp) # Set legend params

    if sp[:title] != nothing
        push!(axesconf, "set title '$(sp[:title])'")
        push!(axesconf, "set title font '$(sp[:titlefontfamily]), $(sp[:titlefontsize])'")
    end

    return join(axesconf, "\n")
end

function gaston_set_ticks!(axesconf, ticks, letter)
    ticks == :auto && return
    if ticks ∈ (:none, nothing, false)
        push!(axesconf, "unset $(letter)tics")
        return
    end

    ttype = ticksType(ticks)
    if ttype == :ticks
        tick_locations = @view ticks[:]
        gaston_tick_string = []
        for i in eachindex(tick_locations)
            lac = tick_locations[i]
            push!(gaston_tick_string, "$loc")
        end
        push!(
            axesconf,
            "set $(letter)tics (" * join(gaston_tick_string, ", ") * ")"
        )
    elseif ttype == :ticks_and_labels
        tick_locations = @view ticks[1][:]
        tick_labels = @view ticks[2][:]
        gaston_tick_string = []
        for i in eachindex(tick_locations)
            loc = tick_locations[i]
            lab = gaston_enclose_tick_string(tick_labels[i])
            push!(gaston_tick_string, "'$lab' $loc")
        end
        push!(
            axesconf,
            "set $(letter)tics (" * join(gaston_tick_string, ", ") * ")"
        )
    else
        error("Invalid input for $(letter)ticks: $ticks")
    end
    nothing
end

function gaston_set_legend!(axesconf, sp)
    leg = sp[:legend]
    if sp[:legend] ∉ (:none, :inline)
        if leg == :best
            leg = :topright
        end

        if occursin("outer", string(leg))
            push!(axesconf, "set key outside")
        else
            push!(axesconf, "set key inside")
        end
        positions = ["top", "bottom", "left", "right"]
        for position in positions
            if occursin(position, string(leg))
                push!(axesconf, "set key $position")
            end
        end
        if sp[:legendtitle] != nothing
            push!(axesconf, "set key title '$(sp[:legendtitle])'")
        end
        push!(axesconf, "set key box linewidth 1")
        push!(axesconf, "set key opaque")

        push!(axesconf, "set border back")
        push!(axesconf, "set key font \"$(sp[:legendfontfamily]), $(sp[:legendfontsize])\"")
    else
        push!(axesconf, "set key off")

    end
    nothing
end

# --------------------------------------------
# Helpers
# --------------------------------------------

gaston_lc_ls_lw(series::Series) = (
    gaston_color(series[:linecolor], series[:linealpha]),
    gaston_linestyle(series[:linestyle]),
    series[:linewidth],
)

gaston_mk_ms_mc(series::Series) = (
    gaston_marker(series[:markershape]),
    series[:markersize] * GASTON_MARKER_SCALING,
    gaston_color(series[:markercolor], series[:markeralpha]),
)

function gaston_palette(gradient)
    palette = String[]
    n = -1
    for rgba ∈ gradient  # FIXME: naive conversion, inefficient ?
        push!(palette, "$(n += 1) $(rgba.r) $(rgba.g) $(rgba.b)")
    end
    return '(' * join(palette, ", ") * ')'
end

function gaston_marker(marker)
    marker == :none && return -1
    marker == :circle && return 7
    marker == :rect && return 5
    marker == :diamond && return 28
    marker == :utriangle && return 9
    marker == :dtriangle && return 11
    marker == :+ && return 1
    marker == :x && return 2
    marker == :star5 && return 3
    marker == :pentagon && return 15
    marker == :pixel && return 0

    @warn "Unsupported marker $marker"
    return 1
end

function gaston_color(color, alpha=0.)
    if isvector(color)
        return gaston_color.(color)
    else
        col = single_color(color)  # in case of gradients
        col = alphacolor(col, alpha == nothing ? 0. : alpha)  # add a default alpha if non existent
        return "rgb \"#$(hex(col, :aarrggbb))\""
    end
end

function gaston_linestyle(style)
    style == :solid && return "1"
    style == :dash && return "2"
    style == :dot && return "3"
    style == :dashdot && return "4"
    style == :dashdotdot && return "5"
end

function gaston_enclose_tick_string(tick_string)
    if findfirst("^", tick_string) == nothing
        return tick_string
    end

    base, power = split(tick_string, "^")
    power = string("{", power, "}")
    return string(base, "^", power)
end
