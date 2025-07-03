"""
    theme(s::Symbol)

Specify the colour theme for plots.
"""
function theme(s::Symbol; kw...)
    defaults = if haskey(PlotThemes._themes, s)
        copy(PlotThemes._themes[s].defaults)
    else
        @warn ":$s is not a known theme, using :default"
        Dict{Symbol, Any}()
    end
    return _theme(s, defaults; kw...)
end

function _theme(s::Symbol, defaults::AKW; kw...)
    # Reset to defaults to overwrite active theme
    reset_defaults()

    # Set the theme's gradient as default
    if haskey(defaults, :colorgradient)
        PlotUtils.default_cgrad(pop!(defaults, :colorgradient))
    else
        PlotUtils.default_cgrad(:default)
    end

    # maybe overwrite the theme's gradient
    kw = KW(kw)
    if haskey(kw, :colorgradient)
        PlotUtils.default_cgrad(pop!(kw, :colorgradient))
    end

    # Set the theme's defaults
    default(; defaults..., kw...)
    return
end

@deprecate set_theme(s) theme(s)

@userplot ShowTheme

_color_functions =
    KW(:protanopic => protanopic, :deuteranopic => deuteranopic, :tritanopic => tritanopic)
_get_showtheme_args(thm::Symbol) = thm, identity
_get_showtheme_args(thm::Symbol, func::Symbol) = thm, get(_color_functions, func, identity)

@recipe function showtheme(st::ShowTheme)
    thm, cfunc = _get_showtheme_args(st.args...)
    defaults = PlotThemes._themes[thm].defaults

    # get the gradient
    gradient_colors = color_list(cgrad(get(defaults, :colorgradient, :default)))
    colorgradient = cgrad(cfunc.(RGB.(gradient_colors)))

    # get the palette
    cp = color_list(palette(get(defaults, :palette, :default)))
    cp = cfunc.(RGB.(cp))

    # apply the theme
    for k in keys(defaults)
        k in (:colorgradient, :palette) && continue
        def = defaults[k]
        arg = get(_keyAliases, k, k)
        plotattributes[arg] = if typeof(def) <: Colorant
            cfunc(RGB(def))
        elseif eltype(def) <: Colorant
            cfunc.(RGB.(def))
        elseif occursin("color", string(arg)) && !startswith(string(arg), "colorbar")
            cfunc.(RGB.(plot_color.(def)))
        else
            def
        end
    end

    Random.seed!(1)

    label := ""
    colorbar := false
    layout := (2, 3)

    for j in 1:4
        @series begin
            subplot := 1
            color_palette := cp
            seriestype := :path
            cumsum(randn(50))
        end

        @series begin
            subplot := 2
            seriestype := :scatter
            color_palette := cp
            marker := (:circle, :diamond, :star5, :square)[j]
            randn(10), randn(10)
        end
    end

    @series begin
        subplot := 3
        seriestype := :histogram
        color_palette := cp
        randn(1_000) .+ (0:2:4)'
    end

    f(r) = sin(r) / r
    _norm(x, y) = norm([x, y])
    x = y = range(-3π, stop = 3π, length = 30)
    z = f.(_norm.(x, y'))
    wi = 2:3:30

    @series begin
        subplot := 4
        seriestype := :heatmap
        seriescolor := colorgradient
        xticks := ((-2π):(2π):(2π), string.(-2:2:2, "π"))
        yticks := ((-2π):(2π):(2π), string.(-2:2:2, "π"))
        x, y, z
    end

    @series begin
        subplot := 5
        seriestype := :surface
        seriescolor := colorgradient
        xticks := ((-2π):(2π):(2π), string.(-2:2:2, "π"))
        yticks := ((-2π):(2π):(2π), string.(-2:2:2, "π"))
        x, y, z
    end

    n = 100
    ts = range(0, stop = 10π, length = n)
    x = (0.1ts) .* cos.(ts)
    y = (0.1ts) .* sin.(ts)
    z = 1:n

    @series begin
        subplot := 6
        seriescolor := colorgradient
        linewidth := 3
        line_z := z
        x, y, z
    end
end
