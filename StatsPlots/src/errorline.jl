@userplot ErrorLine
"""
# StatsPlots.errorline(x, y, arg):
    Function for parsing inputs to easily make a [`ribbons`] (https://ggplot2.tidyverse.org/reference/geom_ribbon.html),
    stick errorbar (https://www.mathworks.com/help/matlab/ref/errorbar.html), or plume
    (https://stackoverflow.com/questions/65510619/how-to-prepare-my-data-for-plume-plots) plot while allowing 
    for easily controlling error type and NaN handling.

# Inputs: default values are indicated with *s

    x (vector, unit range) - the values along the x-axis for each y-point

    y (matrix [x, repeat, group]) - values along y-axis wrt x. The first dimension must be of equal length to that of x.
        The second dimension is treated as the repeated observations and error is computed along this dimension. If the
        matrix has a 3rd dimension this is treated as a new group.

    error_style (`Symbol` - *:ribbon*, :stick, :plume) - determines whether to use a ribbon style or stick style error
     representation.

    centertype (symbol - *:mean* or :median) - which approach to use to represent the central value of y at each x-value.

    errortype (symbol - *:std*, :sem, :percentile) - which error metric to use to show the distribution of y at each x-value.

    percentiles (Vector{Int64} *[25, 75]*) - if using errortype === :percentile then which percentiles to use as bounds.

    groupcolor (Symbol, RGB, Vector of Symbol or RGB) - Declares the color for each group. If no value is passed then will use
        the default colorscheme. If one value is given then it will use that color for all groups. If multiple colors are
        given then it will use a different color for each group.

    secondarycolor (`Symbol`, `RGB`, `:matched` - *:Gray60*) - When using stick mode this will allow for the setting of the stick color.
        If `:matched` is given then the color of the sticks with match that of the main line.

    secondarylinealpha (float *.1*) - alpha value of plume lines.

    numsecondarylines (int *100*) - number of plume lines to plot behind central line.

    stickwidth (Float64 *.01*) - How much of the x-axis the horizontal aspect of the error stick should take up.

# Example
```julia
x = 1:10
y = fill(NaN, 10, 100, 3)
for i = axes(y,3)
    y[:,:,i] = collect(1:2:20) .+ rand(10,100).*5 .* collect(1:2:20) .+ rand()*100
end

y = reshape(1:100, 10, 10);
errorline(1:10, y)
```
"""
errorline

function compute_error(
    y::AbstractMatrix,
    centertype::Symbol,
    errortype::Symbol,
    percentiles::AbstractVector,
)
    y_central = fill(NaN, size(y, 1))

    # NaNMath doesn't accept Ints so convert to AbstractFloat if necessary
    if eltype(y) <: Integer
        y = float(y)
    end
    # First compute the center
    y_central = if centertype === :mean
        mapslices(NaNMath.mean, y, dims = 2)
    elseif centertype === :median
        mapslices(NaNMath.median, y, dims = 2)
    else
        error("Invalid center type. Valid symbols include :mean or :median")
    end

    # Takes 2d matrix [x,y] and computes the desired error type for each row (value of x)
    if errortype === :std || errortype === :sem
        y_error = mapslices(NaNMath.std, y, dims = 2)
        if errortype == :sem
            y_error = y_error ./ sqrt(size(y, 2))
        end

    elseif errortype === :percentile
        y_lower = fill(NaN, size(y, 1))
        y_upper = fill(NaN, size(y, 1))
        if any(isnan.(y)) # NaNMath does not have a percentile function so have to go via StatsBase
            for i in axes(y, 1)
                yi = y[i, .!isnan.(y[i, :])]
                y_lower[i] = percentile(yi, percentiles[1])
                y_upper[i] = percentile(yi, percentiles[2])
            end
        else
            y_lower = mapslices(Y -> percentile(Y, percentiles[1]), y, dims = 2)
            y_upper = mapslices(Y -> percentile(Y, percentiles[2]), y, dims = 2)
        end

        y_error = (y_central .- y_lower, y_upper .- y_central) # Difference from center value
    else
        error("Invalid error type. Valid symbols include :std, :sem, :percentile")
    end

    return y_central, y_error
end

@recipe function f(
    e::ErrorLine;
    errorstyle = :ribbon,
    centertype = :mean,
    errortype = :std,
    percentiles = [25, 75],
    groupcolor = nothing,
    secondarycolor = nothing,
    stickwidth = 0.01,
    secondarylinealpha = 0.1,
    numsecondarylines = 100,
    secondarylinewidth = 1,
)
    if length(e.args) == 1  # If only one input is given assume it is y-values in the form [x,obs]
        y = e.args[1]
        x = 1:size(y, 1)
    else # Otherwise assume that the first two inputs are x and y
        x = e.args[1]
        y = e.args[2]

        # Check y orientation
        ndims(y) > 3 && error("ndims(y) > 3")

        if !any(size(y) .== length(x))
            error("Size of x and y do not match")
        elseif ndims(y) == 2 && size(y, 1) != length(x) && size(y, 2) == length(x) # Check if y needs to be transposed or transmuted
            y = transpose(y)
        elseif ndims(y) == 3 && size(y, 1) != length(x)
            error(
                "When passing a 3 dimensional matrix as y, the axes must be [x, repeat, group]",
            )
        end
    end

    # Determine if a color palette is being used so it can be passed to secondary lines
    if :color_palette ∉ keys(plotattributes)
        color_palette = :default
    else
        color_palette = plotattributes[:color_palette]
    end

    # Parse different color type
    if groupcolor isa Symbol || groupcolor isa RGB{Float64} || groupcolor isa RGBA{Float64}
        groupcolor = [groupcolor]
    end

    # Check groupcolor format
    if (groupcolor !== nothing && ndims(y) > 2) && length(groupcolor) == 1
        groupcolor = repeat(groupcolor, size(y, 3)) # Use the same color for all groups
    elseif (groupcolor !== nothing && ndims(y) > 2) && length(groupcolor) < size(y, 3)
        error("$(length(groupcolor)) colors given for a matrix with $(size(y,3)) groups")
    elseif groupcolor === nothing
        gsi_counter = 0
        for i = 1:length(plotattributes[:plot_object].series_list)
            if plotattributes[:plot_object].series_list[i].plotattributes[:primary]
                gsi_counter += 1
            end
        end
        # Start at next index and allow wrapping of indices
        gsi_counter += 1
        idx = (gsi_counter:(gsi_counter + size(y, 3))) .% length(palette(color_palette))
        idx[findall(x -> x == 0, idx)] .= length(palette(color_palette))
        groupcolor = palette(color_palette)[idx]
    end

    if errorstyle === :plume && numsecondarylines > size(y, 2) # Override numsecondarylines
        numsecondarylines = size(y, 2)
    end

    for g in axes(y, 3) # Iterate through 3rd dimension
        # Compute center and distribution for each value of x
        y_central, y_error = compute_error(y[:, :, g], centertype, errortype, percentiles)

        if errorstyle === :ribbon
            seriestype := :path
            @series begin
                x := x
                y := y_central
                ribbon := y_error
                fillalpha --> 0.1
                linecolor := groupcolor[g]
                fillcolor := groupcolor[g]
                () # Suppress implicit return
            end

        elseif errorstyle === :stick
            x_offset = diff(extrema(x) |> collect)[1] * stickwidth
            seriestype := :path
            for (i, xi) in enumerate(x)
                # Error sticks
                @series begin
                    primary := false
                    x :=
                        [xi - x_offset, xi + x_offset, xi, xi, xi + x_offset, xi - x_offset]
                    if errortype === :percentile
                        y := [
                            repeat([y_central[i] - y_error[1][i]], 3)
                            repeat([y_central[i] + y_error[2][i]], 3)
                        ]
                    else
                        y := [
                            repeat([y_central[i] - y_error[i]], 3)
                            repeat([y_central[i] + y_error[i]], 3)
                        ]
                    end
                    # Set the stick color
                    if secondarycolor === nothing
                        linecolor := :gray60
                    elseif secondarycolor === :matched
                        linecolor := groupcolor[g]
                    else
                        linecolor := secondarycolor
                    end
                    linewidth := secondarylinewidth
                    () # Suppress implicit return
                end
            end

            # Base line
            seriestype := :line
            @series begin
                primary := true
                x := x
                y := y_central
                linecolor := groupcolor[g]
                ()
            end

        elseif errorstyle === :plume
            num_obs = size(y, 2)
            if num_obs > numsecondarylines
                sub_sample_idx = sample(1:num_obs, numsecondarylines, replace = false)
                y_sub_sample = y[:, sub_sample_idx, g]
            else
                y_sub_sample = y[:, :, g]
            end
            seriestype := :path
            for i = 1:numsecondarylines
                # Background paths
                @series begin
                    primary := false
                    x := x
                    y := y_sub_sample[:, i]
                    # Set the stick color
                    if secondarycolor === nothing || secondarycolor === :matched
                        linecolor := groupcolor[g]
                    else
                        linecolor := secondarycolor
                    end
                    linealpha := secondarylinealpha
                    linewidth := secondarylinewidth
                    () # Suppress implicit return
                end
            end

            # Base line
            seriestype := :line
            @series begin
                primary := true
                x := x
                y := y_central
                linecolor := groupcolor[g]
                linewidth --> 3 # Make it stand out against the plume better
                ()
            end
        else
            error("Invalid error style. Valid symbols include :ribbon, :stick, or :plume.")
        end
    end
end
