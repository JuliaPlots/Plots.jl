"""
    scatter(x,y)
    scatter!(x,y)

Make a scatter plot of y vs x.

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

Make a bar plot of y vs x.

# Arguments

- $(_document_argument("bar_position"))
- $(_document_argument("bar_width"))
- $(_document_argument("bar_edges"))
- $(_document_argument("orientation"))

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
- $(_document_argument("bins"))
- `weights`: Vector of weights for the values in `x`, for weighted bin counts
- $(_document_argument("normalize"))
- $(_document_argument("bar_position"))
- $(_document_argument("bar_width"))
- $(_document_argument("bar_edges"))
- $(_document_argument("orientation"))

# Example
```julia-repl
julia> histogram([1,2,1,1,4,3,8],bins=0:8)
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
    stephist(x)

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

Make a line plot of a kernel density estimate of x.

# Arguments

- `x`: AbstractVector of samples for probability density estimation

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
with hexagonal bins)

# Example
```julia-repl
julia> hexbin(randn(10_000), randn(10_000))
```
"""
@shorthands hexbin

"""
    sticks(x,y)
    sticks!(x,y)

Draw a stick plot of y vs x.

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
the AbstractVector `y`

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
the AbstractVector `x`

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

Draw contour lines of the `Surface` z.

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
    boxplot(x, y)
    boxplot!(x, y)

Make a box and whisker plot.

# Keyword arguments
- `notch`: Bool. Notch the box plot? (false)
- `range`: Real. Values more than range*IQR below the first quartile
           or above the third quartile are shown as outliers (1.5)
- `outliers`: Bool. Show outliers? (true)
- `whisker_width`: Real or Symbol. Length of whiskers (:match)

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
with control points `(x[2],y[2]), ..., (x[end-1],y[end]-1)`

# Example
```julia-repl
julia> curves([1,2,3,4],[1,1,2,4])
```
"""
@shorthands curves

"Plot a pie diagram"
@shorthands pie

"Plot with seriestype :path3d"
plot3d(args...; kw...)     = plot(args...; kw...,  seriestype = :path3d)
plot3d!(args...; kw...)    = plot!(args...; kw..., seriestype = :path3d)

"Add title to an existing plot"
title!(s::AbstractString; kw...)                 = plot!(; title = s, kw...)

"Add xlabel to an existing plot"
xlabel!(s::AbstractString; kw...)                = plot!(; xlabel = s, kw...)

"Add ylabel to an existing plot"
ylabel!(s::AbstractString; kw...)                = plot!(; ylabel = s, kw...)

"Set xlims for an existing plot"
xlims!(lims::Tuple{T,S}; kw...) where {T<:Real,S<:Real} = plot!(; xlims = lims, kw...)

"Set ylims for an existing plot"
ylims!(lims::Tuple{T,S}; kw...) where {T<:Real,S<:Real} = plot!(; ylims = lims, kw...)

"Set zlims for an existing plot"
zlims!(lims::Tuple{T,S}; kw...) where {T<:Real,S<:Real} = plot!(; zlims = lims, kw...)

xlims!(xmin::Real, xmax::Real; kw...)                     = plot!(; xlims = (xmin,xmax), kw...)
ylims!(ymin::Real, ymax::Real; kw...)                     = plot!(; ylims = (ymin,ymax), kw...)
zlims!(zmin::Real, zmax::Real; kw...)                     = plot!(; zlims = (zmin,zmax), kw...)


"Set xticks for an existing plot"
xticks!(v::TicksArgs; kw...) where {T<:Real}                       = plot!(; xticks = v, kw...)

"Set yticks for an existing plot"
yticks!(v::TicksArgs; kw...) where {T<:Real}                       = plot!(; yticks = v, kw...)

xticks!(
ticks::AVec{T}, labels::AVec{S}; kw...) where {T<:Real,S<:AbstractString}     = plot!(; xticks = (ticks,labels), kw...)
yticks!(
ticks::AVec{T}, labels::AVec{S}; kw...) where {T<:Real,S<:AbstractString}     = plot!(; yticks = (ticks,labels), kw...)

"""
    annotate!(anns...)

Add annotations to an existing plot.

# Arguments

- `anns`: An `AbstractVector` of tuples of the form `(x,y,text)`. The `text` object
          can be a `String` or `PlotText`.

# Example
```julia-repl
julia> plot(1:10)
julia> annotate!([(7,3,"(7,3)"),(3,7,text("hey", 14, :left, :top, :green))])
```
"""
annotate!(anns...; kw...)             = plot!(; annotation = anns, kw...)
annotate!(anns::Tuple...; kw...)      = plot!(; annotation = collect(anns), kw...)
annotate!(anns::AVec{<:Tuple}; kw...) = plot!(; annotation = anns, kw...)

"Flip the current plots' x axis"
xflip!(flip::Bool = true; kw...)                          = plot!(; xflip = flip, kw...)

"Flip the current plots' y axis"
yflip!(flip::Bool = true; kw...)                          = plot!(; yflip = flip, kw...)

"Specify x axis attributes for an existing plot"
xaxis!(args...; kw...)                                    = plot!(; xaxis = args, kw...)

"Specify y axis attributes for an existing plot"
yaxis!(args...; kw...)                                    = plot!(; yaxis = args, kw...)
xgrid!(args...; kw...)                                    = plot!(; xgrid = args, kw...)
ygrid!(args...; kw...)                                    = plot!(; ygrid = args, kw...)
