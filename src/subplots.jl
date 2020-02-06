

function Subplot(::T; parent = RootLayout()) where T<:AbstractBackend
    Subplot{T}(
        parent,
        Series[],
        (20mm, 5mm, 2mm, 10mm),
        defaultbox,
        defaultbox,
        Attr(KW(), _subplot_defaults),
        nothing,
        nothing
    )
end

"""
    plotarea(subplot)

Return the bounding box of a subplot
"""
plotarea(sp::Subplot) = sp.plotarea
plotarea!(sp::Subplot, bbox::BoundingBox) = (sp.plotarea = bbox)


Base.size(sp::Subplot) = (1,1)
Base.length(sp::Subplot) = 1
Base.getindex(sp::Subplot, r::Int, c::Int) = sp

leftpad(sp::Subplot)   = sp.minpad[1]
toppad(sp::Subplot)    = sp.minpad[2]
rightpad(sp::Subplot)  = sp.minpad[3]
bottompad(sp::Subplot) = sp.minpad[4]

get_subplot(plt::Plot, sp::Subplot) = sp
get_subplot(plt::Plot, i::Integer) = plt.subplots[i]
get_subplot(plt::Plot, k) = plt.spmap[k]
get_subplot(series::Series) = series.plotattributes[:subplot]

get_subplot_index(plt::Plot, idx::Integer) = Int(idx)
get_subplot_index(plt::Plot, sp::Subplot) = findfirst(x -> x === sp, plt.subplots)

series_list(sp::Subplot) = sp.series_list # filter(series -> series.plotattributes[:subplot] === sp, sp.plt.series_list)

function should_add_to_legend(series::Series)
    series.plotattributes[:primary] && series.plotattributes[:label] != "" &&
        !(series.plotattributes[:seriestype] in (
            :hexbin,:bins2d,:histogram2d,:hline,:vline,
            :contour,:contourf,:contour3d,:surface,:wireframe,
            :heatmap, :pie, :image
        ))
end

# ----------------------------------------------------------------------
