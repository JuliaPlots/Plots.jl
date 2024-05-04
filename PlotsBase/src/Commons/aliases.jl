autopick_ignore_none_auto(arr::AVec, idx::Integer) =
    _cycle(setdiff(arr, [:none, :auto]), idx)
autopick_ignore_none_auto(notarr, idx::Integer) = notarr

function aliases_and_autopick(
    plotattributes::AKW,
    sym::Symbol,
    aliases::Dict{Symbol,Symbol},
    options::AVec,
    plotIndex::Int,
)
    if plotattributes[sym] ≡ :auto
        plotattributes[sym] = autopick_ignore_none_auto(options, plotIndex)
    elseif haskey(aliases, plotattributes[sym])
        plotattributes[sym] = aliases[plotattributes[sym]]
    end
end

aliases(val) = aliases(_keyAliases, val)
aliases(aliasMap::Dict{Symbol,Symbol}, val) =
    filter(x -> x.second == val, aliasMap) |> keys |> collect |> sort

# -----------------------------------------------------------------------------
# legend
add_aliases(:legend_position, :legend, :leg, :key, :legends)
add_aliases(
    :legend_background_color,
    :bg_legend,
    :bglegend,
    :bgcolor_legend,
    :bg_color_legend,
    :background_legend,
    :background_colour_legend,
    :bgcolour_legend,
    :bg_colour_legend,
    :background_color_legend,
)
add_aliases(
    :legend_foreground_color,
    :fg_legend,
    :fglegend,
    :fgcolor_legend,
    :fg_color_legend,
    :foreground_legend,
    :foreground_colour_legend,
    :fgcolour_legend,
    :fg_colour_legend,
    :foreground_color_legend,
)
add_aliases(:legend_font_pointsize, :legendfontsize)
add_aliases(
    :legend_title,
    :key_title,
    :keytitle,
    :label_title,
    :labeltitle,
    :leg_title,
    :legtitle,
)
add_aliases(:legend_title_font_pointsize, :legendtitlefontsize)
add_aliases(:plot_title, :suptitle, :subplot_grid_title, :sgtitle, :plot_grid_title)
# margin
add_aliases(:left_margin, :leftmargin)

add_aliases(:top_margin, :topmargin)
add_aliases(:bottom_margin, :bottommargin)
add_aliases(:right_margin, :rightmargin)

# colors
add_aliases(:seriescolor, :c, :color, :colour, :colormap, :cmap)
add_aliases(:linecolor, :lc, :lcolor, :lcolour, :linecolour)
add_aliases(:markercolor, :mc, :mcolor, :mcolour, :markercolour)
add_aliases(:markerstrokecolor, :msc, :mscolor, :mscolour, :markerstrokecolour)
add_aliases(:markerstrokewidth, :msw, :mswidth)
add_aliases(:fillcolor, :fc, :fcolor, :fcolour, :fillcolour)

add_aliases(
    :background_color,
    :bg,
    :bgcolor,
    :bg_color,
    :background,
    :background_colour,
    :bgcolour,
    :bg_colour,
)
add_aliases(
    :background_color_subplot,
    :bg_subplot,
    :bgsubplot,
    :bgcolor_subplot,
    :bg_color_subplot,
    :background_subplot,
    :background_colour_subplot,
    :bgcolour_subplot,
    :bg_colour_subplot,
)
add_aliases(
    :background_color_inside,
    :bg_inside,
    :bginside,
    :bgcolor_inside,
    :bg_color_inside,
    :background_inside,
    :background_colour_inside,
    :bgcolour_inside,
    :bg_colour_inside,
)
add_aliases(
    :background_color_outside,
    :bg_outside,
    :bgoutside,
    :bgcolor_outside,
    :bg_color_outside,
    :background_outside,
    :background_colour_outside,
    :bgcolour_outside,
    :bg_colour_outside,
)
add_aliases(
    :foreground_color,
    :fg,
    :fgcolor,
    :fg_color,
    :foreground,
    :foreground_colour,
    :fgcolour,
    :fg_colour,
)

add_aliases(
    :foreground_color_subplot,
    :fg_subplot,
    :fgsubplot,
    :fgcolor_subplot,
    :fg_color_subplot,
    :foreground_subplot,
    :foreground_colour_subplot,
    :fgcolour_subplot,
    :fg_colour_subplot,
)
add_aliases(
    :foreground_color_grid,
    :fg_grid,
    :fggrid,
    :fgcolor_grid,
    :fg_color_grid,
    :foreground_grid,
    :foreground_colour_grid,
    :fgcolour_grid,
    :fg_colour_grid,
    :gridcolor,
)
add_aliases(
    :foreground_color_minor_grid,
    :fg_minor_grid,
    :fgminorgrid,
    :fgcolor_minorgrid,
    :fg_color_minorgrid,
    :foreground_minorgrid,
    :foreground_colour_minor_grid,
    :fgcolour_minorgrid,
    :fg_colour_minor_grid,
    :minorgridcolor,
)
add_aliases(
    :foreground_color_title,
    :fg_title,
    :fgtitle,
    :fgcolor_title,
    :fg_color_title,
    :foreground_title,
    :foreground_colour_title,
    :fgcolour_title,
    :fg_colour_title,
    :titlecolor,
)
add_aliases(
    :foreground_color_axis,
    :fg_axis,
    :fgaxis,
    :fgcolor_axis,
    :fg_color_axis,
    :foreground_axis,
    :foreground_colour_axis,
    :fgcolour_axis,
    :fg_colour_axis,
    :axiscolor,
)
add_aliases(
    :foreground_color_border,
    :fg_border,
    :fgborder,
    :fgcolor_border,
    :fg_color_border,
    :foreground_border,
    :foreground_colour_border,
    :fgcolour_border,
    :fg_colour_border,
    :bordercolor,
)
add_aliases(
    :foreground_color_text,
    :fg_text,
    :fgtext,
    :fgcolor_text,
    :fg_color_text,
    :foreground_text,
    :foreground_colour_text,
    :fgcolour_text,
    :fg_colour_text,
    :textcolor,
)
add_aliases(
    :foreground_color_guide,
    :fg_guide,
    :fgguide,
    :fgcolor_guide,
    :fg_color_guide,
    :foreground_guide,
    :foreground_colour_guide,
    :fgcolour_guide,
    :fg_colour_guide,
    :guidecolor,
)

# alphas
add_aliases(:seriesalpha, :alpha, :α, :opacity)
add_aliases(:linealpha, :la, :lalpha, :lα, :lineopacity, :lopacity)
add_aliases(:markeralpha, :ma, :malpha, :mα, :markeropacity, :mopacity)
add_aliases(:markerstrokealpha, :msa, :msalpha, :msα, :markerstrokeopacity, :msopacity)
add_aliases(:fillalpha, :fa, :falpha, :fα, :fillopacity, :fopacity)

# axes attributes
add_axes_aliases(:guide, :label, :lab, :l; generic = false)
add_axes_aliases(:lims, :lim, :limit, :limits, :range)
add_axes_aliases(:ticks, :tick)
add_axes_aliases(:rotation, :rot, :r)
add_axes_aliases(:guidefontsize, :labelfontsize)
add_axes_aliases(:gridalpha, :ga, :galpha, :gα, :gridopacity, :gopacity)
add_axes_aliases(
    :gridstyle,
    :grid_style,
    :gridlinestyle,
    :grid_linestyle,
    :grid_ls,
    :gridls,
)
add_axes_aliases(
    :foreground_color_grid,
    :fg_grid,
    :fggrid,
    :fgcolor_grid,
    :fg_color_grid,
    :foreground_grid,
    :foreground_colour_grid,
    :fgcolour_grid,
    :fg_colour_grid,
    :gridcolor,
)
add_axes_aliases(
    :foreground_color_minor_grid,
    :fg_minor_grid,
    :fgminorgrid,
    :fgcolor_minorgrid,
    :fg_color_minorgrid,
    :foreground_minorgrid,
    :foreground_colour_minor_grid,
    :fgcolour_minorgrid,
    :fg_colour_minor_grid,
    :minorgridcolor,
)
add_axes_aliases(
    :gridlinewidth,
    :gridwidth,
    :grid_linewidth,
    :grid_width,
    :gridlw,
    :grid_lw,
)
add_axes_aliases(
    :minorgridstyle,
    :minorgrid_style,
    :minorgridlinestyle,
    :minorgrid_linestyle,
    :minorgrid_ls,
    :minorgridls,
)
add_axes_aliases(
    :minorgridlinewidth,
    :minorgridwidth,
    :minorgrid_linewidth,
    :minorgrid_width,
    :minorgridlw,
    :minorgrid_lw,
)
add_axes_aliases(
    :tick_direction,
    :tickdirection,
    :tick_dir,
    :tickdir,
    :tick_orientation,
    :tickorientation,
    :tick_or,
    :tickor,
)

# series attributes
add_aliases(:seriestype, :st, :t, :typ, :linetype, :lt)
add_aliases(:label, :lab)
add_aliases(:line, :l)
add_aliases(:linewidth, :w, :width, :lw)
add_aliases(:linestyle, :style, :s, :ls)
add_aliases(:marker, :m, :mark)
add_aliases(:markershape, :shape)
add_aliases(:markersize, :ms, :msize)
add_aliases(:marker_z, :markerz, :zcolor, :mz)
add_aliases(:line_z, :linez, :zline, :lz)
add_aliases(:fill, :f, :area)
add_aliases(:fillrange, :fillrng, :frange, :fillto, :fill_between)
add_aliases(:group, :g, :grouping)
add_aliases(:bins, :bin, :nbin, :nbins, :nb)
add_aliases(:ribbon, :rib)
add_aliases(:annotations, :ann, :anns, :annotate, :annotation)
add_aliases(:xguide, :xlabel, :xlab, :xl)
add_aliases(:xlims, :xlim, :xlimit, :xlimits, :xrange)
add_aliases(:xticks, :xtick)
add_aliases(:xrotation, :xrot, :xr)
add_aliases(:yguide, :ylabel, :ylab, :yl)
add_aliases(:ylims, :ylim, :ylimit, :ylimits, :yrange)
add_aliases(:yticks, :ytick)
add_aliases(:yrotation, :yrot, :yr)
add_aliases(:zguide, :zlabel, :zlab, :zl)
add_aliases(:zlims, :zlim, :zlimit, :zlimits)
add_aliases(:zticks, :ztick)
add_aliases(:zrotation, :zrot, :zr)
add_aliases(:guidefontsize, :labelfontsize)
add_aliases(
    :fill_z,
    :fillz,
    :fz,
    :surfacecolor,
    :surfacecolour,
    :sc,
    :surfcolor,
    :surfcolour,
)
add_aliases(:colorbar, :cb, :cbar, :colorkey)
add_aliases(
    :colorbar_title,
    :colorbartitle,
    :cb_title,
    :cbtitle,
    :cbartitle,
    :cbar_title,
    :colorkeytitle,
    :colorkey_title,
)
add_aliases(:clims, :clim, :cbarlims, :cbar_lims, :climits, :color_limits)
add_aliases(:smooth, :regression, :reg)
add_aliases(:levels, :nlevels, :nlev, :levs)
add_aliases(:size, :windowsize, :wsize)
add_aliases(:window_title, :windowtitle, :wtitle)
add_aliases(:show, :gui, :display)
add_aliases(:color_palette, :palette)
add_aliases(:overwrite_figure, :clf, :clearfig, :overwrite, :reuse)
add_aliases(:xerror, :xerr, :xerrorbar)
add_aliases(:yerror, :yerr, :yerrorbar, :err, :errorbar)
add_aliases(:zerror, :zerr, :zerrorbar)
add_aliases(:quiver, :velocity, :quiver2d, :gradient, :vectorfield)
add_aliases(:normalize, :norm, :normed, :normalized)
add_aliases(:show_empty_bins, :showemptybins, :showempty, :show_empty)
add_aliases(:aspect_ratio, :aspectratio, :axis_ratio, :axisratio, :ratio)
add_aliases(:subplot, :sp, :subplt, :splt)
add_aliases(:projection, :proj)
add_aliases(:projection_type, :proj_type)
add_aliases(
    :titlelocation,
    :title_location,
    :title_loc,
    :titleloc,
    :title_position,
    :title_pos,
    :titlepos,
    :titleposition,
    :title_align,
    :title_alignment,
)
add_aliases(
    :series_annotations,
    :series_ann,
    :seriesann,
    :series_anns,
    :seriesanns,
    :series_annotation,
    :text,
    :txt,
    :texts,
    :txts,
)
add_aliases(:html_output_format, :format, :fmt, :html_format)
add_aliases(:orientation, :direction, :dir)
add_aliases(:inset_subplots, :inset, :floating)
add_aliases(:stride, :wirefame_stride, :surface_stride, :surf_str, :str)

add_aliases(
    :framestyle,
    :frame_style,
    :frame,
    :axesstyle,
    :axes_style,
    :boxstyle,
    :box_style,
    :box,
    :borderstyle,
    :border_style,
    :border,
)

add_aliases(:camera, :cam, :viewangle, :view_angle)
add_aliases(:contour_labels, :contourlabels, :clabels, :clabs)
add_aliases(:warn_on_unsupported, :warn)
