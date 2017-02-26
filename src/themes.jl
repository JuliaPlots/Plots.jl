
function theme(s::Symbol; kw...)
    # reset?
    if s == :none || s == :default
        PlotUtils.set_clibrary(:matplotlib)
        PlotUtils.cgraddefaults(:inferno)
        default(;
            bg        = :white,
            bglegend  = :match,
            bginside  = :match,
            bgoutside = :match,
            fg        = :auto,
            fglegend  = :match,
            fggrid    = :match,
            fgaxis    = :match,
            fgtext    = :match,
            fgborder  = :match,
            fgguide   = :match,
            palette   = :auto
        )
        return
    end

    # update the default gradient and other defaults
    thm = PlotThemes._themes[s]
    if thm.gradient != nothing
        PlotUtils.set_clibrary(:plotthemes)
        PlotUtils.cgraddefaults(default = PlotThemes.gradient_name(s))
    end
    default(;
        bg       = thm.bg_secondary,
        bginside = thm.bg_primary,
        fg       = thm.lines,
        fgtext   = thm.text,
        fgguide  = thm.text,
        fglegend = thm.text,
        palette  = thm.palette,
        kw...
    )
end

@deprecate set_theme(s) theme(s)
