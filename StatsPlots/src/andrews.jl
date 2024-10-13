@userplot AndrewsPlot

"""
    andrewsplot(args...; kw...)
Shows each row of an array (or table) as a line. The `x` argument specifies a
grouping variable. This is a way to visualize structure in high-dimensional data.
https://en.wikipedia.org/wiki/Andrews_plot
#Examples
```julia
using RDatasets, StatsPlots
iris = dataset("datasets", "iris")
@df iris andrewsplot(:Species, cols(1:4))
```
"""
andrewsplot

@recipe function f(h::AndrewsPlot)
    if length(h.args) == 2  # specify x if not given
        x, y = h.args
    else
        y = h.args[1]
        x = ones(size(y, 1))
    end

    seriestype := :andrews

    # series in a user recipe will have different colors
    for g in unique(x)
        @series begin
            label := "$g"
            range(-π, stop = π, length = 200), Surface(y[g .== x, :]) #surface needed, or the array will be split into columns
        end
    end
    nothing
end

# the series recipe
@recipe function f(::Type{Val{:andrews}}, x, y, z)
    y = y.surf
    rows, cols = size(y)
    seriestype := :path

    # these series are the lines, will keep the same colors
    for j = 1:rows
        @series begin
            primary := false
            ys = zeros(length(x))
            terms =
                [isodd(i) ? cos((i ÷ 2) .* ti) : sin((i ÷ 2) .* ti) for i = 2:cols, ti in x]
            for ti in eachindex(x)
                ys[ti] = y[j, 1] / sqrt(2) + sum(y[j, i] .* terms[i - 1, ti] for i = 2:cols)
            end

            x := x
            y := ys
            ()
        end
    end

    x := []
    y := []
    ()
end
