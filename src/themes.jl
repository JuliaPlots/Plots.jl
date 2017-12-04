"""
    theme(s::Symbol)

Specify the colour theme for plots.
"""
function theme(s::Symbol; kw...)
    defaults = merge(_initial_defaults..., s.defaults, kw)
    if haskey(s.defaults, :gradient)
        PlotUtils.clibrary(:misc)
        PlotUtils.default_cgrad(default = :sequential, sequential = PlotThemes.gradient_name(s))
    end
    default(; defaults...)
    return
end

# function theme(s::Symbol; kw...)
#     # reset?
#     if s == :none || s == :default
#         PlotUtils.clibrary(:Plots)
#         PlotUtils.default_cgrad(default = :sequential, sequential = :inferno)
#         default(;
#             bg        = :white,
#             bglegend  = :match,
#             bginside  = :match,
#             bgoutside = :match,
#             fg        = :auto,
#             fglegend  = :match,
#             fggrid    = :match,
#             fgaxis    = :match,
#             fgtext    = :match,
#             fgborder  = :match,
#             fgguide   = :match,
#             palette   = :auto
#         )
#         return
#     end
#
#     # update the default gradient and other defaults
#     thm = PlotThemes._themes[s]
#     if thm.gradient != nothing
#         PlotUtils.clibrary(:misc)
#         PlotUtils.default_cgrad(default = :sequential, sequential = PlotThemes.gradient_name(s))
#     end
#     default(;
#         bg       = thm.bg_secondary,
#         bginside = thm.bg_primary,
#         fg       = thm.lines,
#         fgtext   = thm.text,
#         fgguide  = thm.text,
#         fglegend = thm.text,
#         palette  = thm.palette,
#         kw...
#     )
# end

@deprecate set_theme(s) theme(s)
