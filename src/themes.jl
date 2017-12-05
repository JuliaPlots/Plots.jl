"""
    theme(s::Symbol)

Specify the colour theme for plots.
"""
function theme(s::Symbol; kw...)
    thm = PlotThemes._themes[s]
    defaults = if :defaults in fieldnames(thm)
        thm.defaults
    else # old PlotTheme type
        defs = KW(
            :bg       => thm.bg_secondary,
            :bginside => thm.bg_primary,
            :fg       => thm.lines,
            :fgtext   => thm.text,
            :fgguide  => thm.text,
            :fglegend => thm.text,
            :palette  => thm.palette,
        )
        if thm.gradient != nothing
            push!(defs, :gradient => thm.gradient)
        end
        defs
    end
    _theme(s, defaults; kw...)
end


function _theme(s::Symbol, defaults::KW; kw...)
    # Reset to defaults to overwrite active theme
    reset_defaults()

    # Set the theme's gradient as default
    if haskey(defaults, :gradient)
        PlotUtils.clibrary(:misc)
        PlotUtils.default_cgrad(default = :sequential, sequential = PlotThemes.gradient_name(s))
    else
        PlotUtils.clibrary(:Plots)
        PlotUtils.default_cgrad(default = :sequential, sequential = :inferno)
    end

    # maybe overwrite the theme's gradient
    kw = KW(kw)
    if haskey(kw, :gradient)
        kwgrad = pop!(kw, :gradient)
        for clib in clibraries()
            if kwgrad in cgradients(clib)
                PlotUtils.clibrary(clib)
                PlotUtils.default_cgrad(default = :sequential, sequential = kwgrad)
                break
            end
        end
    end

    # Set the theme's defaults
    default(; defaults..., kw...)
    return
end

@deprecate set_theme(s) theme(s)
