# # unfished
# add_theme(:ggplot2_base,
#     bglegend = _invisible,
#     fg       = :white,
#     fglegend = _invisible,
#     fgguide  = :black)
#
# add_theme(:ggplot2,
#           base = :ggplot2_base,
#           bginside = :lightgray,
#           fg       = :lightgray,
#           fgtext   = :gray,
#           fglegend = :gray,
#           fgguide  = :black)
#
# add_theme(:ggplot2_grey, base = :ggplot2)
#
# add_theme(:ggplot2_bw,
#           base = :ggplot2_base,
#           bginside = :white,
#           fg       = :black,
#           fgtext   = :lightgray,
#           fglegend = :lightgray,
#           fgguide  = :black)

const _ggplot_colors = Dict(
    :gray92 => RGB(fill(0.92, 3)...),
    :gray20 => RGB(fill(0.2, 3)...),
    :gray30 => RGB(fill(0.3, 3)...)
    )


const _ggplot2 = PlotTheme(Dict([
    ## Background etc
    :bg => :white,
    :bginside => _ggplot_colors[:gray92],
    :bglegend => _ggplot_colors[:gray92],
    :fglegend => :white,
    :fgguide => :black,
    :widen=>true,
    ## Axes / Ticks
    #framestyle => :grid,
    #foreground_color_tick => _ggplot_colors[:gray20], # tick color not yet implemented
    :foreground_color_axis => _ggplot_colors[:gray20], # tick color
    :tick_direction=>:out,
    :foreground_color_border =>:white, # axis color
    :foreground_color_text => _ggplot_colors[:gray30], # tick labels
    :gridlinewidth => 1,
    #tick label size => *0.8,
    ### Grid
    :foreground_color_grid => :white,
    :gridalpha => 1,
    ### Minor Grid
    :minorgrid => true,
    :minorgridalpha => 1,
    :minorgridlinewidth=>0.5, # * 0.5
    :foreground_color_minor_grid=>:white,
    #foreground_color_minortick=>:white, ## not yet implemented
    :minorticks => 2,
    ## Lines and markers
    :markerstrokealpha => 0,
    :markerstrokewidth => 0 ])
    #showaxis=> :false
)
