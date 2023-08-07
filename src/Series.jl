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
