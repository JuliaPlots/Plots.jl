

# [WEBSITE]

supported_args(::GLVisualizeBackend) = merge_with_base_supported([
    # :annotations,
    # :background_color_legend, :background_color_inside, :background_color_outside,
    # :foreground_color_grid, :foreground_color_legend, :foreground_color_title,
    # :foreground_color_axis, :foreground_color_border, :foreground_color_guide, :foreground_color_text,
    # :label,
    # :linecolor, :linestyle, :linewidth, :linealpha,
    # :markershape, :markercolor, :markersize, :markeralpha,
    # :markerstrokewidth, :markerstrokecolor, :markerstrokealpha,
    # :fillrange, :fillcolor, :fillalpha,
    # :bins, :bar_width, :bar_edges, :bar_position,
    # :title, :title_location, :titlefont,
    # :window_title,
    # :guide, :lims, :ticks, :scale, :flip, :rotation,
    # :tickfont, :guidefont, :legendfont,
    # :grid, :legend, :colorbar,
    # :marker_z, :levels,
    # :ribbon, :quiver, :arrow,
    # :orientation,
    # :overwrite_figure,
    # :polar,
    # :normalize, :weights,
    # :contours, :aspect_ratio,
    # :match_dimensions,
    # :clims,
    # :inset_subplots,
  ])
supported_types(::GLVisualizeBackend) = [:surface]
supported_styles(::GLVisualizeBackend) = [:auto, :solid]
supported_markers(::GLVisualizeBackend) = [:none, :auto, :circle]
supported_scales(::GLVisualizeBackend) = [:identity]
is_subplot_supported(::GLVisualizeBackend) = false

# --------------------------------------------------------------------------------------


function _initialize_backend(::GLVisualizeBackend; kw...)
    @eval begin
        import GLVisualize
        export GLVisualize
    end
end

# ---------------------------------------------------------------------------

immutable GLScreenWrapper
    window
end

function gl_display(plt::Plot{GLVisualizeBackend})
    # init a window
    w=GLVisualize.glscreen()
    @async GLVisualize.renderloop(w)
    GLScreenWrapper(w)

    for sp in plt.subplots
        # TODO: setup subplot

        for series in series_list(sp)
            # TODO: setup series
            d = series.d
            st = d[:seriestype]

            if st == :surface
                x, y, z = map(Float32, series.d[:x]), map(Float32, series.d[:y]), map(Float32, series.d[:z].surf)
                GLVisualize.view(GLVisualize.visualize((x*ones(y)', ones(x)*y', z), :surface), plt.o.window)
            else
                error("Series type $st not supported by GLVisualize")
            end
        end
    end
end


# ----------------------------------------------------------------

# function _writemime(io::IO, ::MIME"image/png", plt::AbstractPlot{GLVisualizeBackend})
#     # TODO: write a png to io
# end

function _display(plt::Plot{GLVisualizeBackend})
    gl_display(plt)
end
