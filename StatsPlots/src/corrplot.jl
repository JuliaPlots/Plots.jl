"""
    corrplot

This plot type shows the correlation among input variables.  
A correlation plot may be produced by a matrix.


A correlation matrix can also be created from the columns of a `DataFrame`
using the [`@df`](@ref) macro like so:

```julia
@df iris corrplot([:SepalLength :SepalWidth :PetalLength :PetalWidth])
```

The marker color in scatter plots reveals the degree of correlation. 
Pass the desired colorgradient to `markercolor`.

With the default gradient positive correlations are blue, neutral are yellow 
and negative are red. In the 2d-histograms, the color gradient shows the frequency 
of points in that bin (as usual, controlled by `seriescolor`).
"""
@userplot CorrPlot

recipetype(::Val{:corrplot}, args...) = CorrPlot(args)

"""
    to_corrplot_matrix(mat)

Transforms the input into a correlation plot matrix.  
Meant to be overloaded by other types!
"""
to_corrplot_matrix(x) = x

function update_ticks_guides(d::KW, labs, i, j, n)
    # d[:title]  = (i==1 ? _cycle(labs,j) : "")
    # d[:xticks] = (i==n)
    d[:xguide] = (i == n ? _cycle(labs, j) : "")
    # d[:yticks] = (j==1)
    d[:yguide] = (j == 1 ? _cycle(labs, i) : "")
end

@recipe function f(cp::CorrPlot)
    mat = to_corrplot_matrix(cp.args[1])
    n = size(mat, 2)
    C = cor(mat)
    labs = pop!(plotattributes, :label, [""])

    link := :x  # need custom linking for y
    layout := (n, n)
    legend := false
    foreground_color_border := nothing
    margin := 1mm
    titlefont := font(11)
    fillcolor --> PlotsBase.fg_color(plotattributes)
    linecolor --> PlotsBase.fg_color(plotattributes)
    markeralpha := 0.4
    grad = cgrad(get(plotattributes, :markercolor, :RdYlBu))
    indices = reshape(1:(n ^ 2), n, n)'
    title = get(plotattributes, :title, "")
    title_location = get(plotattributes, :title_location, :center)
    title := ""

    # histograms on the diagonal
    for i ∈ 1:n
        @series begin
            if title != "" && title_location === :left && i == 1
                title := title
            end
            seriestype := :histogram
            subplot := indices[i, i]
            grid := false
            xformatter --> ((i == n) ? :auto : (x -> ""))
            yformatter --> ((i == 1) ? :auto : (y -> ""))
            update_ticks_guides(plotattributes, labs, i, i, n)
            view(mat, :, i)
        end
    end

    # scatters
    for i ∈ 1:n
        ylink := setdiff(vec(indices[i, :]), indices[i, i])
        vi = view(mat, :, i)
        for j ∈ 1:n
            j == i && continue
            vj = view(mat, :, j)
            subplot := indices[i, j]
            update_ticks_guides(plotattributes, labs, i, j, n)
            if i > j
                #below diag... scatter
                @series begin
                    seriestype := :scatter
                    markercolor := grad[0.5 + 0.5C[i, j]]
                    smooth := true
                    markerstrokewidth --> 0
                    xformatter --> ((i == n) ? :auto : (x -> ""))
                    yformatter --> ((j == 1) ? :auto : (y -> ""))
                    vj, vi
                end
            else
                #above diag... hist2d
                @series begin
                    seriestype := get(plotattributes, :seriestype, :histogram2d)
                    if title != "" &&
                       i == 1 &&
                       (
                           (title_location === :center && j == div(n, 2) + 1) ||
                           (title_location === :right && j == n)
                       )
                        if iseven(n)
                            title_location := :left
                        end
                        title := title
                    end
                    xformatter --> ((i == n) ? :auto : (x -> ""))
                    yformatter --> ((j == 1) ? :auto : (y -> ""))
                    vj, vi
                end
            end
        end
    end
end
