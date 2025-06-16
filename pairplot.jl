using Plots

df = rand(5, 5) * 10 |> Matrix

function pairplot(df)
    rows, cols = size(df)
    y = ones(3)
    title = Plots.scatter(
        y,
        marker = 0,
        markeralpha = 0,
        annotations = (2, y[2], Plots.text("Pair plot")),
        axis = ([], false),
        leg = false,
        size = (200, 100),
    )
    plots = []
    for row = 1:rows, col = 1:cols
        if row == rows && col == 1
            push!(
                plots,
                scatter(
                    df[!, row],
                    df[!, col],
                    xtickfont = font(4),
                    ytickfont = font(4),
                    legend = false,
                    xlabel = "foo",
                    xguidefontsize = font(4),
                    ylabel = "bar",
                    yguidefontsize = font(4),
                ),
            )

        elseif row == rows
            push!(
                plots,
                scatter(
                    df[!, row],
                    df[!, col],
                    xtickfont = font(4),
                    ytickfont = font(4),
                    legend = false,
                    xlabel = "foo",
                    xguidefontsize = font(4),
                ),
            )
        elseif col == 1
            push!(
                plots,
                scatter(
                    df[!, row],
                    df[!, col],
                    xtickfont = font(4),
                    ytickfont = font(4),
                    legend = false,
                    ylabel = "bar",
                    yguidefontsize = font(4),
                ),
            )
        else
            push!(
                plots,
                scatter(
                    df[!, row],
                    df[!, col],
                    xtickfont = font(4),
                    ytickfont = font(4),
                    legend = false,
                ),
            )
        end
    end
    plot(
        title,
        plot(plots..., layout = (rows, cols)),
        layout = grid(2, 1, heights = [0.05, 0.95]),
    )
end

pairplot(df)

