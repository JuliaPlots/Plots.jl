"""
    theme(s::Symbol)

Specify the colour theme for plots.
"""
function theme(s::Symbol; kw...)
    # Reset to defaults to overwrite active theme
    reset_defaults()
    thm = PlotThemes._themes[s]

    # Set the theme's gradient as default
    if haskey(thm.defaults, :gradient)
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
    default(; thm.defaults..., kw...)
    return
end

@deprecate set_theme(s) theme(s)
