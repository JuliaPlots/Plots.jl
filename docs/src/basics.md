### Basic Concepts

Use `plot` to create a new plot object, and `plot!` to add to an existing one:

```julia
plot(args...; kw...)                  # creates a new Plot, and set it to be the `current`
plot!(args...; kw...)                 # modifies Plot `current()`
plot!(plt, args...; kw...)            # modifies Plot `plt`
```

The graphic is not shown implicitly, only when "displayed".  This will happen automatically when returned to a REPL prompt or to an IJulia cell.  There are [many other options](@ref output) as well.

Input arguments can take [many forms](@ref input-data).  Some valid examples:

```julia
plot()                                       # empty Plot object
plot(4)                                      # initialize with 4 empty series
plot(rand(10))                               # 1 series... x = 1:10
plot(rand(10,5))                             # 5 series... x = 1:10
plot(rand(10), rand(10))                     # 1 series
plot(rand(10,5), rand(10))                   # 5 series... y is the same for all
plot(sin, rand(10))                          # y = sin.(x)
plot(rand(10), sin)                          # same... y = sin.(x)
plot([sin,cos], 0:0.1:π)                     # 2 series, sin.(x) and cos.(x)
plot([sin,cos], 0, π)                        # sin and cos on the range [0, π]
plot(1:10, Any[rand(10), sin])               # 2 series: rand(10) and map(sin,x)
@df dataset("Ecdat", "Airline") plot(:Cost)  # the :Cost column from a DataFrame... must import StatsPlots
```

[Keyword arguments](@ref attributes) allow for customization of the plot, subplots, axes, and series.  They follow consistent rules as much as possible, and you'll avoid common pitfalls if you read this section carefully:

- Many arguments have aliases which are [replaced during preprocessing](@ref step-1-replace-aliases).  `c` is the same as `color`, `m` is the same as `marker`, etc.  You can choose a verbosity that you are comfortable with.
- There are some [special arguments](@ref step-2-handle-magic-arguments) which magically set many related things at once.
- If the argument is a "matrix-type", then [each column will map to a series](@ref columns-are-series), cycling through columns if there are fewer columns than series.  In this sense, a vector is treated just like an "nx1 matrix".
- Many arguments accept many different types... for example the color (also markercolor, fillcolor, etc) argument will accept strings or symbols with a color name, or any Colors.Colorant, or a ColorScheme, or a symbol representing a ColorGradient, or an AbstractVector of colors/symbols/etc...

---

### Useful Tips

!!! tip
    A common error is to pass a Vector when you intend for each item to apply to only one series. Instead of an n-length Vector, pass a 1xn Matrix.

!!! tip
    You can update certain plot settings after plot creation:
    ```julia
    plot!(title = "New Title", xlabel = "New xlabel", ylabel = "New ylabel")
    plot!(xlims = (0, 5.5), ylims = (-2.2, 6), xticks = 0:0.5:10, yticks = [0,1,5,10])

    # or using magic:
    plot!(xaxis = ("mylabel", :log10, :flip))
    xaxis!("mylabel", :log10, :flip)
    ```

!!! tip
    With [supported backends](@ref supported), you can pass a `Plots.Shape` object for the marker/markershape arguments. `Shape` takes a vector of 2-tuples in the constructor, defining the points of the polygon's shape in a unit-scaled coordinate space.  To make a square, for example, you could do: `Shape([(1,1),(1,-1),(-1,-1),(-1,1)])`

!!! tip
    You can see the default value for a given argument with `default(arg::Symbol)`, and set the default value with `default(arg::Symbol, value)` or `default(; kw...)`. For example set the default window size and whether we should show a legend with `default(size=(600,400), leg=false)`.

!!! tip
    Call `gui()` to display the plot in a window. Interactivity depends on backend. Plotting at the REPL (without semicolon) implicitly calls `gui()`.

---
