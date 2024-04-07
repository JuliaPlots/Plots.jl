
# ---------------------------------------------------------------
bool_env(x, default::String = "0")::Bool = tryparse(Bool, get(ENV, x, default))

treats_y_as_x(seriestype) =
    seriestype in (:vline, :vspan, :histogram, :barhist, :stephist, :scatterhist)

function replace_image_with_heatmap(z::AbstractMatrix{<:Colorant})
    n, m = size(z)
    colors = palette(vec(z))
    reshape(1:(n * m), n, m), colors
end

# ---------------------------------------------------------------

"Build line segments for plotting"
mutable struct Segments{T}
    pts::Vector{T}
end

# Segments() = Segments{Float64}(zeros(0))

Segments() = Segments(Float64)
Segments(::Type{T}) where {T} = Segments(T[])
Segments(p::Int) = Segments(NTuple{p,Float64}[])

# Segments() = Segments(zeros(0))

to_nan(::Type{Float64}) = NaN
to_nan(::Type{NTuple{2,Float64}}) = (NaN, NaN)
to_nan(::Type{NTuple{3,Float64}}) = (NaN, NaN, NaN)

Commons.coords(segs::Segments{Float64}) = segs.pts
Commons.coords(segs::Segments{NTuple{2,Float64}}) =
    (map(p -> p[1], segs.pts), map(p -> p[2], segs.pts))
Commons.coords(segs::Segments{NTuple{3,Float64}}) =
    (map(p -> p[1], segs.pts), map(p -> p[2], segs.pts), map(p -> p[3], segs.pts))

function Base.push!(segments::Segments{T}, vs...) where {T}
    isempty(segments.pts) || push!(segments.pts, to_nan(T))
    foreach(v -> push!(segments.pts, convert(T, v)), vs)
    segments
end

function Base.push!(segments::Segments{T}, vs::AVec) where {T}
    isempty(segments.pts) || push!(segments.pts, to_nan(T))
    foreach(v -> push!(segments.pts, convert(T, v)), vs)
    segments
end

# Find minimal type that can contain NaN and x
# To allow use of NaN separated segments with categorical x axis

float_extended_type(x::AbstractArray{T}) where {T} = Union{T,Float64}
float_extended_type(x::AbstractArray{Real}) = Float64

function _update_series_attributes!(plotattributes::AKW, plt::Plot, sp::Subplot)
    pkg = plt.backend
    globalIndex = plotattributes[:series_plotindex]
    plotIndex = Commons._series_index(plotattributes, sp)

    Commons.aliases_and_autopick(
        plotattributes,
        :linestyle,
        Commons._styleAliases,
        supported_styles(pkg),
        plotIndex,
    )
    Commons.aliases_and_autopick(
        plotattributes,
        :markershape,
        Commons._marker_aliases,
        supported_markers(pkg),
        plotIndex,
    )

    # update alphas
    for asym in (:linealpha, :markeralpha, :fillalpha)
        if plotattributes[asym] ≡ nothing
            plotattributes[asym] = plotattributes[:seriesalpha]
        end
    end
    if plotattributes[:markerstrokealpha] ≡ nothing
        plotattributes[:markerstrokealpha] = plotattributes[:markeralpha]
    end

    # update series color
    scolor = plotattributes[:seriescolor]
    stype = plotattributes[:seriestype]
    plotattributes[:seriescolor] = scolor = get_series_color(scolor, sp, plotIndex, stype)

    # update other colors (`linecolor`, `markercolor`, `fillcolor`) <- for grep
    for s in (:line, :marker, :fill)
        csym, asym = Symbol(s, :color), Symbol(s, :alpha)
        plotattributes[csym] = if plotattributes[csym] ≡ :auto
            plot_color(if Commons.has_black_border_for_default(stype) && s ≡ :line
                sp[:foreground_color_subplot]
            else
                scolor
            end)
        elseif plotattributes[csym] ≡ :match
            plot_color(scolor)
        else
            get_series_color(plotattributes[csym], sp, plotIndex, stype)
        end
    end

    # update markerstrokecolor
    plotattributes[:markerstrokecolor] = if plotattributes[:markerstrokecolor] ≡ :match
        plot_color(sp[:foreground_color_subplot])
    elseif plotattributes[:markerstrokecolor] ≡ :auto
        get_series_color(plotattributes[:markercolor], sp, plotIndex, stype)
    else
        get_series_color(plotattributes[:markerstrokecolor], sp, plotIndex, stype)
    end

    # if marker_z, fill_z or line_z are set, ensure we have a gradient
    if plotattributes[:marker_z] ≢ nothing
        Commons.ensure_gradient!(plotattributes, :markercolor, :markeralpha)
    end
    if plotattributes[:line_z] ≢ nothing
        Commons.ensure_gradient!(plotattributes, :linecolor, :linealpha)
    end
    if plotattributes[:fill_z] ≢ nothing
        Commons.ensure_gradient!(plotattributes, :fillcolor, :fillalpha)
    end

    # scatter plots don't have a line, but must have a shape
    if plotattributes[:seriestype] in (:scatter, :scatterbins, :scatterhist, :scatter3d)
        plotattributes[:linewidth] = 0
        if plotattributes[:markershape] ≡ :none
            plotattributes[:markershape] = :circle
        end
    end

    # set label
    plotattributes[:label] = Commons.label_to_string.(plotattributes[:label], globalIndex)

    Commons._replace_linewidth(plotattributes)
    plotattributes
end
"""
1-row matrices will give an element
multi-row matrices will give a column
anything else is returned as-is
"""
function slice_arg(v::AMat, idx::Int)
    isempty(v) && return v
    c = mod1(idx, size(v, 2))
    m, n = axes(v)
    size(v, 1) == 1 ? v[first(m), n[c]] : v[:, n[c]]
end
slice_arg(wrapper::InputWrapper, idx) = wrapper.obj
slice_arg(v::NTuple{2,AMat}, idx::Int) = slice_arg(v[1], idx), slice_arg(v[2], idx)
slice_arg(v, idx) = v

"""
given an argument key `k`, extract the argument value for this index,
and set into plotattributes[k]. Matrices are sliced by column.
if nothing is set (or container is empty), return the existing value.
"""
function slice_arg!(
    plotattributes_in,
    plotattributes_out,
    k::Symbol,
    idx::Int,
    remove_pair::Bool,
)
    v = get(plotattributes_in, k, plotattributes_out[k])
    plotattributes_out[k] = if haskey(plotattributes_in, k) && k ∉ Commons._plot_attrs
        slice_arg(v, idx)
    else
        v
    end
    remove_pair && RecipesPipeline.reset_kw!(plotattributes_in, k)
    nothing
end

function _slice_series_attrs!(
    plotattributes::AKW,
    plt::Plot,
    sp::Subplot,
    commandIndex::Int,
)
    for k in keys(_series_defaults)
        haskey(plotattributes, k) &&
            slice_arg!(plotattributes, plotattributes, k, commandIndex, false)
    end
    plotattributes
end
# -----------------------------------------------------------------------------

function __heatmap_edges(v::AVec, isedges::Bool, ispolar::Bool)
    (n = length(v)) == 1 && return v[1] .+ [ispolar ? max(-v[1], -0.5) : -0.5, 0.5]
    isedges && return v
    # `isedges = true` means that v is a vector which already describes edges
    # and does not need to be extended.
    vmin, vmax = ignorenan_extrema(v)
    extra_min = ispolar ? min(v[1], 0.5(v[2] - v[1])) : 0.5(v[2] - v[1])
    extra_max = 0.5(v[n] - v[n - 1])
    vcat(vmin - extra_min, 0.5(v[1:(n - 1)] + v[2:n]), vmax + extra_max)
end

_heatmap_edges(::Val{true}, v::AVec, ::Symbol, isedges::Bool, ispolar::Bool) =
    __heatmap_edges(v, isedges, ispolar)

function _heatmap_edges(::Val{false}, v::AVec, scale::Symbol, isedges::Bool, ispolar::Bool)
    f, invf = scale_inverse_scale_func(scale)
    invf.(__heatmap_edges(f.(v), isedges, ispolar))
end

"create an (n+1) list of the outsides of heatmap rectangles"
heatmap_edges(
    v::AVec,
    scale::Symbol = :identity,
    isedges::Bool = false,
    ispolar::Bool = false,
) = _heatmap_edges(Val(scale ≡ :identity), v, scale, isedges, ispolar)

function heatmap_edges(
    x::AVec,
    xscale::Symbol,
    y::AVec,
    yscale::Symbol,
    z_size::NTuple{2,Int},
    ispolar::Bool = false,
)
    nx, ny = length(x), length(y)
    # ismidpoints = z_size == (ny, nx) # This fails some tests, but would actually be
    # the correct check, since (4, 3) != (3, 4) and a missleading plot is produced.
    ismidpoints = prod(z_size) == (ny * nx)
    isedges = z_size == (ny - 1, nx - 1)
    (ismidpoints || isedges) ||
        """
        Length of x & y does not match the size of z.
        Must be either `size(z) == (length(y), length(x))` (x & y define midpoints)
        or `size(z) == (length(y)+1, length(x)+1))` (x & y define edges).
        """ |>
        ArgumentError |>
        throw
    (
        _heatmap_edges(Val(xscale ≡ :identity), x, xscale, isedges, false),
        _heatmap_edges(Val(yscale ≡ :identity), y, yscale, isedges, ispolar),  # special handle for `r` in polar plots
    )
end

is_uniformly_spaced(v; tol = 1e-6) =
    let dv = diff(v)
        maximum(dv) - minimum(dv) < tol * mean(abs.(dv))
    end

function convert_to_polar(theta, r, r_extrema = ignorenan_extrema(r))
    rmin, rmax = r_extrema
    r = @. (r - rmin) / (rmax - rmin)
    x = @. r * cos(theta)
    y = @. r * sin(theta)
    x, y
end

fakedata(sz::Int...) = fakedata(Random.seed!(PLOTS_SEED), sz...)

function fakedata(rng::AbstractRNG, sz...)
    y = zeros(sz...)
    for r in 2:size(y, 1)
        y[r, :] = 0.95vec(y[r - 1, :]) + randn(rng, size(y, 2))
    end
    y
end

isijulia() = :IJulia in nameof.(collect(values(Base.loaded_modules)))
isatom() = :Atom in nameof.(collect(values(Base.loaded_modules)))

limsType(lims::Tuple{<:Real,<:Real}) = :limits
limsType(lims::Symbol) = lims ≡ :auto ? :auto : :invalid
limsType(lims) = :invalid

isautop(sp::Subplot) = sp[:projection_type] ≡ :auto
isortho(sp::Subplot) = sp[:projection_type] ∈ (:ortho, :orthographic)
ispersp(sp::Subplot) = sp[:projection_type] ∈ (:persp, :perspective)

# recursively merge kw-dicts, e.g. for merging extra_kwargs / extra_plot_kwargs in plotly)
recursive_merge(x::AbstractDict...) = merge(recursive_merge, x...)
# if values are not AbstractDicts, take the last definition (as does merge)
recursive_merge(x...) = x[end]

nanpush!(a::AbstractVector, b) = (push!(a, NaN); push!(a, b); nothing)
nanappend!(a::AbstractVector, b) = (push!(a, NaN); append!(a, b); nothing)

function nansplit(v::AVec)
    vs = Vector{eltype(v)}[]
    while true
        if (idx = findfirst(isnan, v)) ≡ nothing
            # no nans
            push!(vs, v)
            break
        elseif idx > 1
            push!(vs, v[1:(idx - 1)])
        end
        v = v[(idx + 1):end]
    end
    vs
end

function nanvcat(vs::AVec)
    v_out = zeros(0)
    foreach(v -> nanappend!(v_out, v), vs)
    v_out
end

# compute one side of a fill range from a ribbon
function make_fillrange_side(y::AVec, rib)
    frs = zeros(axes(y))
    for (i, yi) in pairs(y)
        frs[i] = yi + _cycle(rib, i)
    end
    frs
end

# turn a ribbon into a fillrange
function make_fillrange_from_ribbon(kw::AKW)
    y, rib = kw[:y], kw[:ribbon]
    rib = wraptuple(rib)
    rib1, rib2 = -first(rib), last(rib)
    # kw[:ribbon] = nothing
    kw[:fillrange] = make_fillrange_side(y, rib1), make_fillrange_side(y, rib2)
    (get(kw, :fillalpha, nothing) ≡ nothing) && (kw[:fillalpha] = 0.5)
end

#turn tuple of fillranges to one path
function concatenate_fillrange(x, y::Tuple)
    rib1, rib2 = collect(first(y)), collect(last(y)) # collect needed until https://github.com/JuliaLang/julia/pull/37629 is merged
    vcat(x, reverse(x)), vcat(rib1, reverse(rib2))  # x, y
end

get_sp_lims(sp::Subplot, letter::Symbol) = axis_limits(sp, letter)

"""
    xlims([plt])

Returns the x axis limits of the current plot or subplot
"""
xlims(sp::Subplot) = get_sp_lims(sp, :x)

"""
    ylims([plt])

Returns the y axis limits of the current plot or subplot
"""
ylims(sp::Subplot) = get_sp_lims(sp, :y)

"""
    zlims([plt])

Returns the z axis limits of the current plot or subplot
"""
zlims(sp::Subplot) = get_sp_lims(sp, :z)

xlims(plt::Plot, sp_idx::Int = 1) = xlims(plt[sp_idx])
ylims(plt::Plot, sp_idx::Int = 1) = ylims(plt[sp_idx])
zlims(plt::Plot, sp_idx::Int = 1) = zlims(plt[sp_idx])
xlims(sp_idx::Int = 1) = xlims(current(), sp_idx)
ylims(sp_idx::Int = 1) = ylims(current(), sp_idx)
zlims(sp_idx::Int = 1) = zlims(current(), sp_idx)

"Handle all preprocessing of args... break out colors/sizes/etc and replace aliases."
function Commons.preprocess_attributes!(plotattributes::AKW)
    Commons.replaceAliases!(plotattributes, Commons._keyAliases)

    # handle axis args common to all axis
    args = wraptuple(RecipesPipeline.pop_kw!(plotattributes, :axis, ()))
    showarg = wraptuple(RecipesPipeline.pop_kw!(plotattributes, :showaxis, ()))
    for arg in wraptuple((args..., showarg...))
        for letter in (:x, :y, :z)
            process_axis_arg!(plotattributes, arg, letter)
        end
    end
    # handle axis args
    for letter in (:x, :y, :z)
        asym = get_attr_symbol(letter, :axis)
        args = RecipesPipeline.pop_kw!(plotattributes, asym, ())
        if !(typeof(args) <: Axis)
            for arg in wraptuple(args)
                process_axis_arg!(plotattributes, arg, letter)
            end
        end
    end

    # vline and others accesses the y argument but actually maps it to the x axis.
    # Hence, we have to take care of formatters
    if treats_y_as_x(get(plotattributes, :seriestype, :path))
        xformatter = get(plotattributes, :xformatter, :auto)
        yformatter = get(plotattributes, :yformatter, :auto)
        yformatter ≢ :auto && (plotattributes[:xformatter] = yformatter)
        xformatter ≡ :auto &&
            haskey(plotattributes, :yformatter) &&
            pop!(plotattributes, :yformatter)
    end

    # handle grid args common to all axes
    processGridArg! = Commons.process_grid_attr!
    args = RecipesPipeline.pop_kw!(plotattributes, :grid, ())
    for arg in wraptuple(args)
        for letter in (:x, :y, :z)
            processGridArg!(plotattributes, arg, letter)
        end
    end
    # handle individual axes grid args
    for letter in (:x, :y, :z)
        gridsym = get_attr_symbol(letter, :grid)
        args = RecipesPipeline.pop_kw!(plotattributes, gridsym, ())
        for arg in wraptuple(args)
            processGridArg!(plotattributes, arg, letter)
        end
    end
    # handle minor grid args common to all axes
    args = RecipesPipeline.pop_kw!(plotattributes, :minorgrid, ())
    for arg in wraptuple(args)
        for letter in (:x, :y, :z)
            Commons.process_minor_grid_attr!(plotattributes, arg, letter)
        end
    end
    # handle individual axes grid args
    for letter in (:x, :y, :z)
        gridsym = get_attr_symbol(letter, :minorgrid)
        args = RecipesPipeline.pop_kw!(plotattributes, gridsym, ())
        for arg in wraptuple(args)
            Commons.process_minor_grid_attr!(plotattributes, arg, letter)
        end
    end
    # handle font args common to all axes
    for fontname in (:tickfont, :guidefont)
        args = RecipesPipeline.pop_kw!(plotattributes, fontname, ())
        for arg in wraptuple(args)
            for letter in (:x, :y, :z)
                Commons.process_font_attr!(
                    plotattributes,
                    get_attr_symbol(letter, fontname),
                    arg,
                )
            end
        end
    end
    # handle individual axes font args
    for letter in (:x, :y, :z)
        for fontname in (:tickfont, :guidefont)
            args = RecipesPipeline.pop_kw!(
                plotattributes,
                get_attr_symbol(letter, fontname),
                (),
            )
            for arg in wraptuple(args)
                Commons.process_font_attr!(
                    plotattributes,
                    get_attr_symbol(letter, fontname),
                    arg,
                )
            end
        end
    end
    # handle axes args
    for k in Commons._axis_attrs
        if haskey(plotattributes, k) && k ≢ :link
            v = plotattributes[k]
            for letter in (:x, :y, :z)
                lk = get_attr_symbol(letter, k)
                if !is_explicit(plotattributes, lk)
                    plotattributes[lk] = v
                end
            end
        end
    end

    # fonts
    for fontname in
        (:titlefont, :legend_title_font, :plot_titlefont, :colorbar_titlefont, :legend_font)
        args = RecipesPipeline.pop_kw!(plotattributes, fontname, ())
        for arg in wraptuple(args)
            Commons.process_font_attr!(plotattributes, fontname, arg)
        end
    end

    # handle line args
    for arg in wraptuple(RecipesPipeline.pop_kw!(plotattributes, :line, ()))
        Commons.process_line_attr(plotattributes, arg)
    end

    if haskey(plotattributes, :seriestype) &&
       haskey(Commons._typeAliases, plotattributes[:seriestype])
        plotattributes[:seriestype] = Commons._typeAliases[plotattributes[:seriestype]]
    end

    # handle marker args... default to ellipse if shape not set
    anymarker = false
    for arg in wraptuple(get(plotattributes, :marker, ()))
        Commons.process_marker_attr(plotattributes, arg)
        anymarker = true
    end
    RecipesPipeline.reset_kw!(plotattributes, :marker)
    if haskey(plotattributes, :markershape)
        plotattributes[:markershape] =
            Commons._replace_markershape(plotattributes[:markershape])
        if plotattributes[:markershape] ≡ :none &&
           get(plotattributes, :seriestype, :path) in
           (:scatter, :scatterbins, :scatterhist, :scatter3d) #the default should be :auto, not :none, so that :none can be set explicitly and would be respected
            plotattributes[:markershape] = :circle
        end
    elseif anymarker
        plotattributes[:markershape_to_add] = :circle  # add it after _apply_recipe
    end

    # handle fill
    for arg in wraptuple(get(plotattributes, :fill, ()))
        Commons.process_fill_attr(plotattributes, arg)
    end
    RecipesPipeline.reset_kw!(plotattributes, :fill)

    # handle series annotations
    if haskey(plotattributes, :series_annotations)
        plotattributes[:series_annotations] =
            series_annotations(wraptuple(plotattributes[:series_annotations])...)
    end

    # convert into strokes and brushes

    if haskey(plotattributes, :arrow)
        a = plotattributes[:arrow]
        plotattributes[:arrow] = if a == true
            arrow()
        elseif a in (false, nothing, :none)
            nothing
        elseif !(typeof(a) <: Arrow || typeof(a) <: AbstractArray{Arrow})
            arrow(wraptuple(a)...)
        else
            a
        end
    end

    # legends - defaults are set in `src/components.jl` (see `@add_attributes`)
    if haskey(plotattributes, :legend_position)
        plotattributes[:legend_position] =
            Commons.convert_legend_value(plotattributes[:legend_position])
    end
    if haskey(plotattributes, :colorbar)
        plotattributes[:colorbar] = Commons.convert_legend_value(plotattributes[:colorbar])
    end

    # framestyle
    if haskey(plotattributes, :framestyle) &&
       haskey(Commons._framestyle_aliases, plotattributes[:framestyle])
        plotattributes[:framestyle] =
            Commons._framestyle_aliases[plotattributes[:framestyle]]
    end

    # contours
    if haskey(plotattributes, :levels)
        Commons.check_contour_levels(plotattributes[:levels])
    end

    # warnings for moved recipes
    st = get(plotattributes, :seriestype, :path)
    if st in (:boxplot, :violin, :density) &&
       !haskey(
        Base.loaded_modules,
        Base.PkgId(Base.UUID("f3b207a7-027a-5e70-b257-86293d7955fd"), "StatsPlots"),
    )
        @warn "seriestype $st has been moved to StatsPlots.  To use: \`Pkg.add(\"StatsPlots\"); using StatsPlots\`"
    end
    nothing
end

"""
Allows temporary setting of backend and defaults for PlotsBase. Settings apply only for the `do` block.  Example:
```
with(:gr, size=(400,400), type=:histogram) do
  plot(rand(10))
  plot(rand(10))
end
```
"""
function with(f::Function, args...; scalefonts = nothing, kw...)
    new_defs = KW(kw)

    if :canvas in args
        new_defs[:xticks] = nothing
        new_defs[:yticks] = nothing
        new_defs[:grid] = false
        new_defs[:legend_position] = false
    end

    # dict to store old and new keyword args for anything that changes
    old_defs = KW()
    for k in keys(new_defs)
        old_defs[k] = default(k)
    end

    # save the backend
    old_backend = backend_name()

    for arg in args
        # change backend ?
        arg isa Symbol && if arg ∈ backends()
            if (pkg = backend_package_name(arg)) ≢ nothing  # :plotly
                @eval Main import $pkg
            end
            Base.invokelatest(backend, arg)
        end

        # TODO: generalize this strategy to allow args as much as possible
        #       as in:  with(:gr, :scatter, :legend, :grid) do; ...; end
        # TODO: can we generalize this enough to also do something similar in the plot commands??

        k = :legend
        if arg in (k, :leg)
            old_defs[k] = default(k)
            new_defs[k] = true
        end

        k = :grid
        if arg == k
            old_defs[k] = default(k)
            new_defs[k] = true
        end
    end

    # now set all those defaults
    default(; new_defs...)
    scalefonts ≡ nothing || scalefontsizes(scalefonts)

    # call the function
    ret = Base.invokelatest(f)

    # put the defaults back
    scalefonts ≡ nothing || resetfontsizes()
    default(; old_defs...)

    # revert the backend
    old_backend != backend_name() && backend(old_backend)

    # return the result of the function
    ret
end

# ---------------------------------------------------------------
const _convert_sci_unicode_dict = Dict(
    '⁰' => "0",
    '¹' => "1",
    '²' => "2",
    '³' => "3",
    '⁴' => "4",
    '⁵' => "5",
    '⁶' => "6",
    '⁷' => "7",
    '⁸' => "8",
    '⁹' => "9",
    '⁻' => "-",
    "×10" => "×10^{",
)

# converts unicode scientific notation, as returned by Showoff,
# to a tex-like format (supported by gr, pyplot, and pgfplots).

function convert_sci_unicode(label::AbstractString)
    for key in keys(_convert_sci_unicode_dict)
        label = replace(label, key => _convert_sci_unicode_dict[key])
    end
    if occursin("×10^{", label)
        label = string(label, "}")
    end
    label
end

function ___straightline_data(xl, yl, x, y, exp_fact)
    x_vals, y_vals = if y[1] == y[2]
        if x[1] == x[2]
            error("Two identical points cannot be used to describe a straight line.")
        else
            [xl[1], xl[2]], [y[1], y[2]]
        end
    elseif x[1] == x[2]
        [x[1], x[2]], [yl[1], yl[2]]
    else
        # get a and b from the line y = a * x + b through the points given by
        # the coordinates x and x
        b = y[1] - (y[1] - y[2]) * x[1] / (x[1] - x[2])
        a = (y[1] - y[2]) / (x[1] - x[2])
        # get the data values
        xdata = [
            clamp(x[1] + (x[1] - x[2]) * (ylim - y[1]) / (y[1] - y[2]), xl...) for
            ylim in yl
        ]

        xdata, a .* xdata .+ b
    end
    # expand the data outside the axis limits, by a certain factor too improve
    # plotly(js) and interactive behaviour
    (
        x_vals .+ (x_vals[2] - x_vals[1]) .* exp_fact,
        y_vals .+ (y_vals[2] - y_vals[1]) .* exp_fact,
    )
end

__straightline_data(xl, yl, x, y, exp_fact) =
    if (n = length(x)) == 2
        ___straightline_data(xl, yl, x, y, exp_fact)
    else
        k, r = divrem(n, 3)
        @assert r == 0 "Misformed data. `straightline_data` either accepts vectors of length 2 or 3k. The provided series has length $n"
        xdata, ydata = fill(NaN, n), fill(NaN, n)
        for i in 1:k
            inds = (3i - 2):(3i - 1)
            xdata[inds], ydata[inds] =
                ___straightline_data(xl, yl, x[inds], y[inds], exp_fact)
        end
        xdata, ydata
    end

_straightline_data(::Val{true}, ::Function, ::Function, ::Function, ::Function, args...) =
    __straightline_data(args...)

function _straightline_data(
    ::Val{false},
    xf::Function,
    xinvf::Function,
    yf::Function,
    yinvf::Function,
    xl,
    yl,
    x,
    y,
    exp_fact,
)
    xdata, ydata = __straightline_data(xf.(xl), yf.(yl), xf.(x), yf.(y), exp_fact)
    xinvf.(xdata), yinvf.(ydata)
end

function straightline_data(series, expansion_factor = 1)
    sp = series[:subplot]
    xl, yl = (xlims(sp), ylims(sp))

    # handle axes scales
    xf, xinvf, xnoop = scale_inverse_scale_func(sp[:xaxis][:scale])
    yf, yinvf, ynoop = scale_inverse_scale_func(sp[:yaxis][:scale])

    _straightline_data(
        Val(xnoop && ynoop),
        xf,
        xinvf,
        yf,
        yinvf,
        xl,
        yl,
        series[:x],
        series[:y],
        [-expansion_factor, +expansion_factor],
    )
end

function _shape_data!(::Val{false}, xf::Function, xinvf::Function, x, xl, exp_fact)
    @inbounds for i in eachindex(x)
        if x[i] == -Inf
            x[i] = xinvf(xf(xl[1]) - exp_fact * (xf(xl[2]) - xf(xl[1])))
        elseif x[i] == +Inf
            x[i] = xinvf(xf(xl[2]) + exp_fact * (xf(xl[2]) - xf(xl[1])))
        end
    end
    x
end

function _shape_data!(::Val{true}, ::Function, ::Function, x, xl, exp_fact)
    @inbounds for i in eachindex(x)
        if x[i] == -Inf
            x[i] = xl[1] - exp_fact * (xl[2] - xl[1])
        elseif x[i] == +Inf
            x[i] = xl[2] + exp_fact * (xl[2] - xl[1])
        end
    end
    x
end

function shape_data(series, expansion_factor = 1)
    sp = series[:subplot]
    xl, yl = (xlims(sp), ylims(sp))

    # handle axes scales
    xf, xinvf, xnoop = scale_inverse_scale_func(sp[:xaxis][:scale])
    yf, yinvf, ynoop = scale_inverse_scale_func(sp[:yaxis][:scale])

    (
        _shape_data!(Val(xnoop), xf, xinvf, copy(series[:x]), xl, expansion_factor),
        _shape_data!(Val(ynoop), yf, yinvf, copy(series[:y]), yl, expansion_factor),
    )
end

function _add_triangle!(I::Int, i::Int, j::Int, k::Int, x, y, z, X, Y, Z)
    m = 4(I - 1) + 1
    n = m + 1
    o = m + 2
    p = m + 3
    X[m] = X[p] = x[i]
    Y[m] = Y[p] = y[i]
    Z[m] = Z[p] = z[i]
    X[n] = x[j]
    Y[n] = y[j]
    Z[n] = z[j]
    X[o] = x[k]
    Y[o] = y[k]
    Z[o] = z[k]
    nothing
end

function mesh3d_triangles(x, y, z, cns::Tuple{Array,Array,Array})
    ci, cj, ck = cns
    length(ci) == length(cj) == length(ck) ||
        throw(ArgumentError("Argument connections must consist of equally sized arrays."))
    X = zeros(eltype(x), 4length(ci))
    Y = zeros(eltype(y), 4length(cj))
    Z = zeros(eltype(z), 4length(ck))
    @inbounds for I in eachindex(ci)  # connections are 0-based
        _add_triangle!(I, ci[I] + 1, cj[I] + 1, ck[I] + 1, x, y, z, X, Y, Z)
    end
    X, Y, Z
end

function mesh3d_triangles(x, y, z, cns::AbstractVector{NTuple{3,Int}})
    X = zeros(eltype(x), 4length(cns))
    Y = zeros(eltype(y), 4length(cns))
    Z = zeros(eltype(z), 4length(cns))
    @inbounds for I in eachindex(cns)  # connections are 1-based
        _add_triangle!(I, cns[I]..., x, y, z, X, Y, Z)
    end
    X, Y, Z
end

texmath2unicode(s::AbstractString, pat = r"\$([^$]+)\$") =
    replace(s, pat => m -> UnicodeFun.to_latex(m[2:(length(m) - 1)]))

_fmt_paragraph(paragraph::AbstractString; kw...) =
    _fmt_paragraph(PipeBuffer(), paragraph, 0; kw...)

function _fmt_paragraph(
    io::IOBuffer,
    remaining_text::AbstractString,
    column_count::Integer;
    fillwidth = 60,
    leadingspaces = 0,
)
    kw = (; fillwidth, leadingspaces)

    if (m = match(r"(.*?) (.*)", remaining_text)) isa Nothing
        if column_count + length(remaining_text) ≤ fillwidth
            print(io, remaining_text)
        else
            print(io, '\n', ' '^leadingspaces, remaining_text)
        end
        read(io, String)
    else
        if column_count + length(m[1]) ≤ fillwidth
            print(io, m[1], ' ')
            _fmt_paragraph(io, m[2], column_count + length(m[1]) + 1; kw...)
        else
            print(io, '\n', ' '^leadingspaces, m[1], ' ')
            _fmt_paragraph(io, m[2], leadingspaces; kw...)
        end
    end
end

_argument_description(s::Symbol) =
    if s ∈ keys(_arg_desc)
        aliases = if (al = PlotsBase.Commons.aliases(s)) |> length > 0
            " Aliases: " * string(Tuple(al)) * '.'
        else
            ""
        end
        "`$s::$(_arg_desc[s][1])`: $(rstrip(replace(_arg_desc[s][2], '\n' => ' '), '.'))." *
        aliases
    else
        ""
    end

_document_argument(s::Symbol) =
    _fmt_paragraph(_argument_description(s), leadingspaces = 6 + length(string(s)))

# The following functions implement the guess of the optimal legend position,
# from the data series.
function d_point(x, y, lim, scale)
    p_scaled = (x / scale[1], y / scale[2])
    d = sum(abs2, lim .- p_scaled)
    isnan(d) && return 0.0
    d
end
# Function barrier because lims are type-unstable
function _guess_best_legend_position(xl, yl, plt, weight = 100)
    scale = (maximum(xl) - minimum(xl), maximum(yl) - minimum(yl))
    u = zeros(4) # faster than tuple
    # Quadrants where the points will be tested
    quadrants = (
        ((0.00, 0.25), (0.00, 0.25)),   # bottomleft
        ((0.75, 1.00), (0.00, 0.25)),   # bottomright
        ((0.00, 0.25), (0.75, 1.00)),   # topleft
        ((0.75, 1.00), (0.75, 1.00)),   # topright
    )
    for series in plt.series_list
        x = series[:x]
        y = series[:y]
        yoffset = firstindex(y) - firstindex(x)
        for (i, lim) in enumerate(Iterators.product(xl, yl))
            lim = lim ./ scale
            for ix in eachindex(x)
                xi, yi = x[ix], _cycle(y, ix + yoffset)
                # ignore y points outside quadrant visible quadrant
                xi < xl[1] + quadrants[i][1][1] * (xl[2] - xl[1]) && continue
                xi > xl[1] + quadrants[i][1][2] * (xl[2] - xl[1]) && continue
                yi < yl[1] + quadrants[i][2][1] * (yl[2] - yl[1]) && continue
                yi > yl[1] + quadrants[i][2][2] * (yl[2] - yl[1]) && continue
                u[i] += inv(1 + weight * d_point(xi, yi, lim, scale))
            end
        end
    end
    # return in the preferred order in case of draws
    ibest = findmin(u)[2]
    u[ibest] ≈ u[4] && return :topright
    u[ibest] ≈ u[3] && return :topleft
    u[ibest] ≈ u[2] && return :bottomright
    return :bottomleft
end

"""
Computes the distances of the plot limits to a sample of points at the extremes of
the ranges, and places the legend at the corner where the maximum distance to the limits is found.
"""
function _guess_best_legend_position(lp::Symbol, plt)
    lp ≡ :best || return lp
    _guess_best_legend_position(xlims(plt), ylims(plt), plt)
end

_generate_doclist(attributes) =
    replace(join(sort(collect(attributes)), "\n- "), "_" => "\\_")

# for UnitfulExt - cannot reside in `UnitfulExt` (macro)
function protectedstring end  # COV_EXCL_LINE

"""
    P_str(s)

(Unitful extension only).
Creates a string that will be Protected from recipe passes.

Example:
```julia
julia> using Unitful
julia> plot([0,1]u"m", [1,2]u"m/s^2", xlabel=P"This label will NOT display units")
julia> plot([0,1]u"m", [1,2]u"m/s^2", xlabel="This label will display units")
```
"""
macro P_str(s)
    return protectedstring(s)
end

# for `PGFPlotsx` together with `UnitfulExt`
function pgfx_sanitize_string end  # COV_EXCL_LINE

function extrema_plus_buffer(v, buffmult = 0.2)
    vmin, vmax = ignorenan_extrema(v)
    vdiff = vmax - vmin
    buffer = vdiff * buffmult
    vmin - buffer, vmax + buffer
end
