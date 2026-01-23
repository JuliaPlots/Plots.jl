@nospecialize

"""
    scatter(x,y)
    scatter!(x,y)

Make a scatter plot of `y` vs `x`.

# Keyword arguments
- $(_document_argument(:markersize))
- $(_document_argument(:markercolor))
- $(_document_argument(:markershape))
- $(_document_argument(:markeralpha))

# Examples
```julia-repl
julia> scatter([1,2,3],[4,5,6],markersize=[3,4,5],markercolor=[:red,:green,:blue])
julia> scatter([(1,4),(2,5),(3,6)])
```
"""
@shorthands scatter

"""
    bar(x,y)
    bar!(x,y)

Make a bar plot of `y` vs `x`.

# Keyword arguments
- $(_document_argument(:bar_position))
- $(_document_argument(:bar_width))
- $(_document_argument(:bar_edges))
- $(_document_argument(:fillrange))
- $(_document_argument(:permute))

# Examples
```julia-repl
julia> bar([1,2,3],[4,5,6],fillcolor=[:red,:green,:blue],fillalpha=[0.2,0.4,0.6])
julia> bar([(1,4),(2,5),(3,6)])
```
"""
@shorthands bar

@shorthands barh

"""
    histogram(x)
    histogram!(x)

Plot a histogram.

# Arguments
- `x`: AbstractVector of values to be binned
- $(_document_argument(:bins))
- `weights`: Vector of weights for the values in `x`, for weighted bin counts
- $(_document_argument(:normalize))
- $(_document_argument(:bar_position))
- $(_document_argument(:bar_width))
- $(_document_argument(:bar_edges))
- $(_document_argument(:permute))

# Example
```julia-repl
julia> histogram([1,2,1,1,4,3,8],bins=0:8)
julia> histogram([1,2,1,1,4,3,8],bins=0:8,weights=weights([4,7,3,9,12,2,6]))
```
"""
@shorthands histogram

"""
    barhist(x)
    barhist!(x)

Make a histogram bar plot. See `histogram`.
"""
@shorthands barhist

"""
    stephist(x)
    stephist!(x)

Make a histogram step plot (bin counts are represented using horizontal lines
instead of bars). See `histogram`.
"""
@shorthands stephist

"""
    scatterhist(x)
    scatterhist!(x)

Make a histogram scatter plot (bin counts are represented using points
instead of bars). See `histogram`.
"""
@shorthands scatterhist

"""
    histogram2d(x,y)
    histogram2d!(x,y)

Plot a two-dimensional histogram.

# Arguments
- `bins`: Number of bins (if an `Integer`) or bin edges (if an `AbtractVector`)
- `weights`: Vector of weights for the values in `x`. Each entry of x contributes
             its weight to the height of its bin.

# Example
```julia-repl
julia> histogram2d(randn(10_000),randn(10_000))
```
"""
@shorthands histogram2d

"""
    density(x)
    density!(x)

Make a line plot of a kernel density estimate of x. The smoothness of the density plot is defined from `bandwidth` (real positive number).

# Arguments
- `x`: AbstractVector of samples for probability density estimation

# Keyword arguments
- `trim`::Bool: enables cutting off the distribution tails.
- `bandwidth`::Number: a low bandwidth induces under-smoothing, whilst a high bandwidth induces over-smoothing.

# Examples
```julia-repl
julia> density(randn(100), bandwidth = -0.01, trim = false)
output : ERROR: Bandwidth must be positive

julia> density(randn(100), bandwidth = 0.1, trim = false)  # a curve with extremity and under-smoothing
julia> density(randn(100), bandwidth = 10, trim = true)  # a curve without extremity and over-smoothing
```

# Example
```julia-repl
julia> using StatsPlots
julia> density(randn(100_000))
```
"""
@shorthands density

"""
    heatmap(x,y,z)
    heatmap!(x,y,z)

Plot a heatmap of the rectangular array `z`.

# Keyword arguments
- $(_document_argument(:aspect_ratio))

# Example
```julia-repl
julia> heatmap(randn(10,10))
```
"""
@shorthands heatmap
@shorthands plots_heatmap

"""
    hexbin(x,y)
    hexbin!(x,y)

Make a hexagonal binning plot (a histogram of the observations `(x[i],y[i])`
with hexagonal bins).

# Example
```julia-repl
julia> hexbin(randn(10_000), randn(10_000))
```
"""
@shorthands hexbin

"""
    sticks(x,y)
    sticks!(x,y)

Draw a stick plot of `y` vs `x`.

# Arguments
- $(_document_argument(:fillrange))
- $(_document_argument(:markershape))

# Example
```julia-repl
julia> sticks(1:10)
```
"""
@shorthands sticks

"""
    hline(y)
    hline!(y)

Draw horizontal lines at positions specified by the values in
the AbstractVector `y`.

# Example
```julia-repl
julia> hline([-1,0,2])
```
"""
@shorthands hline

"""
    vline(x)
    vline!(x)

Draw vertical lines at positions specified by the values in
the AbstractVector `x`.

# Example
```julia-repl
julia> vline([-1,0,2])
```
"""
@shorthands vline

"""
    hspan(y)

Draw a rectangle between the horizontal line at position `y[1]`
and the horizontal line at position `y[2]`. If `length(y) ≥ 4`,
then further rectangles are drawn between `y[3]` and `y[4]`,
`y[5]` and `y[6]`, and so on. If `length(y)` is odd, then the
last entry of `y` is ignored.

# Example
```julia-repl
julia> hspan(1:6)
```
"""
@shorthands hspan

"""
    vspan(x)

Draw a rectangle between the vertical line at position `x[1]`
and the vertical line at position `x[2]`. If `length(x) ≥ 4`,
then further rectangles are drawn between `x[3]` and `x[4]`,
`x[5]` and `x[6]`, and so on. If `length(x)` is odd, then the
last entry of `x` is ignored.

# Example
```julia-repl
julia> vspan(1:6)
```
"""
@shorthands vspan

"""
    ohlc(x,y::Vector{OHLC})
    ohlc!(x,y::Vector{OHLC})

Make open-high-low-close plot. Each entry of y is represented by a vertical
segment extending from the low value to the high value, with short horizontal
segments on the left and right indicating the open and close values, respectively.

# Example
```julia-repl
julia> meanprices = cumsum(randn(100))
julia> y = OHLC[(p+rand(),p+1,p-1,p+rand()) for p in meanprices]
julia> ohlc(y)
```
"""
@shorthands ohlc

"""
    contour(x,y,z)
    contour!(x,y,z)

Draw contour lines of the surface `z`.

# Arguments
- `levels`: Contour levels (if `AbstractVector`) or number of levels (if `Integer`)
- `fill`: Bool. Fill area between contours or draw contours only (false by default)

# Example
```julia-repl
julia> x = y = range(-20, stop = 20, length = 100)
julia> contour(x, y, (x, y) -> x^2 + y^2)
```
"""
@shorthands contour

"An alias for `contour` with fill = true."
@shorthands contourf

@shorthands contour3d

"""
    surface(x,y,z)
    surface!(x,y,z)

Draw a 3D surface plot.

# Example
```julia-repl
julia> using LinearAlgebra
julia> x = y = range(-3, stop = 3, length = 100)
julia> surface(x, y, (x, y) -> sinc(norm([x, y])))
```
"""
@shorthands surface

"""
    wireframe(x,y,z)
    wireframe!(x,y,z)

Draw a 3D wireframe plot.

# Example
```julia-repl
julia> wireframe(1:10,1:10,randn(10,10))
```
"""
@shorthands wireframe

"""
    path3d(x,y,z)
    path3d!(x,y,z)

Plot a 3D path from `(x[1],y[1],z[1])` to `(x[2],y[2],z[2])`,
..., to `(x[end],y[end],z[end])`.

# Example
```julia-repl
julia> path3d([0,1,2,3],[0,1,4,9],[0,1,8,27])
```
"""
@shorthands path3d

"""
    scatter3d(x,y,z)
    scatter3d!(x,y,z)

Make a 3D scatter plot.

# Example
```julia-repl
julia> scatter3d([0,1,2,3],[0,1,4,9],[0,1,8,27])
```
"""
@shorthands scatter3d

"""
    mesh3d(x,y,z)
    mesh3d(x,y,z; connections)

Plot a 3d mesh. On Plotly the triangles can be specified using the connections argument.

# Example
```Julia
x=[0, 1, 2, 0]
y=[0, 0, 1, 2]
z=[0, 2, 0, 1]

i=[0, 0, 0, 1]
j=[1, 2, 3, 2]
k=[2, 3, 1, 3]

plot(x,y,z,seriestype=:mesh3d;connections=(i,j,k))
```
"""
@shorthands mesh3d

"""
    boxplot(x, y)
    boxplot!(x, y)

Make a box and whisker plot.

# Keyword arguments
- `notch`: Bool. Notch the box plot? (false)
- `whisker_range`: Real. Whiskers extend `whisker_range`*IQR below the first quartile
           and above the third quartile. Values outside this range are shown as outliers (1.5)
- `outliers`: Bool. Show outliers? (true)
- `whisker_width`: Real or Symbol. Length of whiskers; the options are `:match` to match the box width, `:half`, or a number to indicate the total length. (:half)

# Example
```julia-repl
julia> using StatsPlots
julia> boxplot(repeat([1,2,3],outer=100),randn(300))
```
"""
@shorthands boxplot

"""
    violin(x,y,z)
    violin!(x,y,z)

Make a violin plot.

# Example
```julia-repl
julia> violin(repeat([1,2,3],outer=100),randn(300))
```
"""
@shorthands violin

"""
    quiver(x,y,quiver=(u,v))
    quiver!(x,y,quiver=(u,v))

Make a quiver (vector field) plot. The `i`th vector extends
from `(x[i],y[i])` to `(x[i] + u[i], y[i] + v[i])`.

# Keyword arguments
- $(_document_argument(:arrow))

# Example
```julia-repl
julia> quiver([1,2,3],[3,2,1],quiver=([1,1,1],[1,2,3]))
```
"""
@shorthands quiver

"""
    curves(x,y)
    curves!(x,y)

Draw a Bezier curve from `(x[1],y[1])` to `(x[end],y[end])`
with control points `(x[2],y[2]), ..., (x[end-1],y[end]-1)`.

# Keyword arguments
- $(_document_argument(:fillrange))

# Example
```julia-repl
julia> curves([1,2,3,4],[1,1,2,4])
```
"""
@shorthands curves

"""
    pie(x, y)

Plot a pie diagram.

# Example
```julia-repl
x = ["Nerds","Hackers","Scientists"]
y = [0.4,0.35,0.25]
pie(x, y, title="The Julia Community")
```
"""
@shorthands pie

"Plot with seriestype :path3d"
plot3d(args...; kw...) = plot(args...; kw..., seriestype = :path3d)
plot3d!(args...; kw...) = plot!(args...; kw..., seriestype = :path3d)

"Add title to an existing plot"
title!(plt::PlotOrSubplot, s::AbstractString; kw...) = plot!(plt; title = s, kw...)
title!(s::AbstractString; kw...) = plot!(; title = s, kw...)

for letter in ("x", "y", "z")
    @eval begin
        """Add $($(letter))label to an existing plot"""
        $(Symbol(letter, :label!))(s::AbstractString; kw...) =
            plot!(; $(Symbol(letter, :label)) = s, kw...)
        $(Symbol(letter, :label!))(plt::PlotOrSubplot, s::AbstractString; kw...) =
            plot!(plt; $(Symbol(letter, :label)) = s, kw...)
        export $(Symbol(letter, :label!))

        "Set $($letter)lims for an existing plot"
        $(Symbol(letter, :lims!))(lims::Tuple; kw...) =
            plot!(; $(Symbol(letter, :lims)) = lims, kw...)
        $(Symbol(letter, :lims!))(xmin::Real, xmax::Real; kw...) =
            plot!(; $(Symbol(letter, :lims)) = (xmin, xmax), kw...)
        $(Symbol(letter, :lims!))(plt::PlotOrSubplot, lims::Tuple{<:Real, <:Real}; kw...) =
            plot!(plt; $(Symbol(letter, :lims)) = lims, kw...)
        $(Symbol(letter, :lims!))(plt::PlotOrSubplot, xmin::Real, xmax::Real; kw...) =
            plot!(plt; $(Symbol(letter, :lims)) = (xmin, xmax), kw...)
        export $(Symbol(letter, :lims!))

        "Set $($letter)ticks for an existing plot"
        $(Symbol(letter, :ticks!))(v::TicksArgs; kw...) =
            plot!(; $(Symbol(letter, :ticks)) = v, kw...)
        $(Symbol(letter, :ticks!))(
            ticks::AVec{T},
            labels::AVec{S};
            kw...,
        ) where {T <: Real, S <: AbstractString} =
            plot!(; $(Symbol(letter, :ticks)) = (ticks, labels), kw...)
        $(Symbol(letter, :ticks!))(plt::PlotOrSubplot, v::TicksArgs; kw...) =
            plot!(plt; $(Symbol(letter, :ticks)) = v, kw...)
        $(Symbol(letter, :ticks!))(
            plt::PlotOrSubplot,
            ticks::AVec{T},
            labels::AVec{S};
            kw...,
        ) where {T <: Real, S <: AbstractString} =
            plot!(plt; $(Symbol(letter, :ticks)) = (ticks, labels), kw...)
        export $(Symbol(letter, :ticks!))

        "Flip the current plots' $($letter) axis"
        $(Symbol(letter, :flip!))(flip::Bool = true; kw...) =
            plot!(; $(Symbol(letter, :flip)) = flip, kw...)
        $(Symbol(letter, :flip!))(plt::PlotOrSubplot, flip::Bool = true; kw...) =
            plot!(plt; $(Symbol(letter, :flip)) = flip, kw...)
        export $(Symbol(letter, :flip!))

        "Specify $($letter) axis attributes for an existing plot"
        $(Symbol(letter, :axis!))(args...; kw...) =
            plot!(; $(Symbol(letter, :axis)) = args, kw...)
        $(Symbol(letter, :axis!))(plt::PlotOrSubplot, args...; kw...) =
            plot!(plt; $(Symbol(letter, :axis)) = args, kw...)
        export $(Symbol(letter, :axis!))

        "Specify $($letter) grid attributes for an existing plot"
        $(Symbol(letter, :grid!))(args...; kw...) =
            plot!(; $(Symbol(letter, :grid)) = args, kw...)
        $(Symbol(letter, :grid!))(plt::PlotOrSubplot, args...; kw...) =
            plot!(plt; $(Symbol(letter, :grid)) = args, kw...)
        export $(Symbol(letter, :grid!))

        """
            $($letter)error(x, y [, z]; $($letter)error = vals)
            $($letter)error!(x, y [, z]; $($letter)error = vals)

        Create or add a series of $($letter)errorbars at the positions defined by `x`, `y` and `z` with the lenghts defined in `vals`.

        Markerstrokecolor will color the whole errorbars if not specified otherwise.
        """
        @shorthands $(Symbol(letter, :error))
    end
end

"""
    annotate!(anns)
    annotate!(anns::Tuple...)
    annotate!(x, y, txt)

Add annotations to an existing plot.
Annotations are specified either as a vector of tuples, each of the form `(x,y,txt)`,
or as three vectors, `x, y, txt`.
Each `txt` can be a `String`, `PlotText` PlotText (created with `text(args...)`),
or a tuple of arguments to `text` (e.g., `("Label", 8, :red, :top)`).

# Example
```julia-repl
julia> plot(1:10)
julia> annotate!([(7,3,"(7,3)"),(3,7,text("hey", 14, :left, :top, :green))])
julia> annotate!([(4, 4, ("More text", 8, 45.0, :bottom, :red))])
julia> annotate!([2,5], [6,3], ["text at (2,6)", "text at (5,3)"])
```
"""
annotate!(anns...; kw...) = plot!(; annotation = anns, kw...)
annotate!(anns::Tuple...; kw...) = plot!(; annotation = collect(anns), kw...)
annotate!(anns::AVec{<:Tuple}; kw...) = plot!(; annotation = anns, kw...)
annotate!(plt::PlotOrSubplot, anns...; kw...) = plot!(plt; annotations = anns, kw...)
annotate!(plt::PlotOrSubplot, anns::Tuple...; kw...) = plot!(plt; annotations = collect(anns), kw...)
annotate!(plt::PlotOrSubplot, anns::AVec{<:Tuple}; kw...) = plot!(plt; annotations = anns, kw...)

@doc """
   abline!([plot,] a, b; kwargs...)

Adds ax+b... straight line over the current plot, without changing the axis limits
""" abline!

@doc """
    areaplot([x,] y)
    areaplot!([x,] y)

Draw a stacked area plot of the matrix y.
# Examples
```julia-repl
julia> areaplot(1:3, [1 2 3; 7 8 9; 4 5 6], seriescolor = [:red :green :blue], fillalpha = [0.2 0.3 0.4])
```
""" areaplot

@doc """
    lens!([plot,] x, y, inset = (sp_index, bbox(x1, x2, y1, y2)))

Magnify a region of a plot given by `x` and `y`.
`sp_index` is the index of the subplot and `x1`, `x2`, `y1` and `y2` should be between `0` and `1`.
""" lens!
@specialize
