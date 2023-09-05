module PlotsSeries

export Series, should_add_to_legend
import Plots: Plots, DefaultsDict

mutable struct Series
    plotattributes::DefaultsDict
end

Base.getindex(series::Series, k::Symbol) = series.plotattributes[k]
Base.setindex!(series::Series, v, k::Symbol) = (series.plotattributes[k] = v)
Base.get(series::Series, k::Symbol, v) = get(series.plotattributes, k, v)

# TODO: consider removing
attr(series::Series, k::Symbol) = series.plotattributes[k]
attr!(series::Series, v, k::Symbol) = (series.plotattributes[k] = v)
function attr!(series::Series; kw...)
    plotattributes = KW(kw)
    Plots.preprocess_attributes!(plotattributes)
    for (k, v) in plotattributes
        if haskey(_series_defaults, k)
            series[k] = v
        else
            @warn "unused key $k in series attr"
        end
    end
    _series_updated(series[:subplot].plt, series)
    series
end

should_add_to_legend(series::Series) =
    series.plotattributes[:primary] &&
    series.plotattributes[:label] != "" &&
    series.plotattributes[:seriestype] ∉ (
        :hexbin,
        :bins2d,
        :histogram2d,
        :hline,
        :vline,
        :contour,
        :contourf,
        :contour3d,
        :surface,
        :wireframe,
        :heatmap,
        :image,
    )

Plots.get_subplot(series::Series) = series.plotattributes[:subplot]
Plots.RecipesPipeline.is3d(series::Series) = RecipesPipeline.is3d(series.plotattributes)
Plots.ispolar(series::Series) = ispolar(series.plotattributes[:subplot])
end # PlotsSeries
