

# TODO: there should be a distinction between an object that will manage a full plot, vs a component of a plot.
# the PlotRecipe as currently implemented is more of a "custom component"
# a recipe should fully describe the plotting command(s) and call them, likewise for updating.
#   actually... maybe those should explicitly derive from AbstractPlot???

abstract PlotRecipe

getRecipeXY(recipe::PlotRecipe) = Float64[], Float64[]
getRecipeArgs(recipe::PlotRecipe) = ()

plot(recipe::PlotRecipe, args...; kw...) = plot(getRecipeXY(recipe)..., args...; getRecipeArgs(recipe)..., kw...)
plot!(recipe::PlotRecipe, args...; kw...) = plot!(getRecipeXY(recipe)..., args...; getRecipeArgs(recipe)..., kw...)
plot!(plt::Plot, recipe::PlotRecipe, args...; kw...) = plot!(getRecipeXY(recipe)..., args...; getRecipeArgs(recipe)..., kw...)

num_series(x::AMat) = size(x,2)
num_series(x) = 1

# _apply_recipe(d::KW, kw::KW) = ()

# if it's not a recipe, just do nothing and return the args
function RecipesBase.apply_recipe(d::KW, args...; issubplot=false)
    if issubplot && !isempty(args) && !haskey(d, :n) && !haskey(d, :layout)
        # put in a sensible default
        d[:n] = maximum(map(num_series, args))
    end
    args
end


if is_installed("DataFrames")
    @eval begin
        import DataFrames
        DFS = Union{Symbol, AbstractArray{Symbol}}

        function handle_dfs(df::DataFrames.AbstractDataFrame, d::KW, letter, dfs::DFS)
            if isa(dfs, Symbol)
                get!(d, symbol(letter * "guide"), string(dfs))
                collect(df[dfs])
            else
                get!(d, :label, reshape(dfs, 1, length(dfs)))
                Any[collect(df[s]) for s in dfs]
            end
        end

        function extractGroupArgs(group::Symbol, df::DataFrames.AbstractDataFrame, args...)
            extractGroupArgs(collect(df[group]))
        end


        function handle_group(df::DataFrames.AbstractDataFrame, d::KW)
            if haskey(d, :group)
                g = d[:group]
                if isa(g, Symbol)
                    d[:group] = collect(df[g])
                end
            end
        end

        @recipe function f(df::DataFrames.AbstractDataFrame, sy::DFS)
            handle_group(df, d)
            handle_dfs(df, d, "y", sy)
        end

        @recipe function f(df::DataFrames.AbstractDataFrame, sx::DFS, sy::DFS)
            handle_group(df, d)
            x = handle_dfs(df, d, "x", sx)
            y = handle_dfs(df, d, "y", sy)
            x, y
        end

        @recipe function f(df::DataFrames.AbstractDataFrame, sx::DFS, sy::DFS, sz::DFS)
            handle_group(df, d)
            x = handle_dfs(df, d, "x", sx)
            y = handle_dfs(df, d, "y", sy)
            z = handle_dfs(df, d, "z", sz)
            x, y, z
        end
    end
end

# macro kw(k, v)
#     esc(:(get!(d, $k, $v)))
# end
#
# function _is_arrow_tuple(expr::Expr)
#     expr.head == :tuple &&
#         isa(expr.args[1], Expr) &&
#         expr.args[1].head == :(-->)
# end
#
# function _equals_symbol(arg::Symbol, sym::Symbol)
#     arg == sym
# end
# function _equals_symbol(arg::Expr, sym::Symbol)
#     arg.head == :quote && arg.args[1] == sym
# end
#
# # TODO: when this is moved out of Plots, also move the replacement of key aliases to just after the _apply_recipe calls
# function replace_recipe_arrows!(expr::Expr)
#     for (i,e) in enumerate(expr.args)
#         if isa(e,Expr)
#
#             # process trailing flags, like:
#             #   a --> b, :quiet, :force
#             quiet, require, force = false, false, false
#             if _is_arrow_tuple(e)
#                 for flag in e.args
#                     if _equals_symbol(flag, :quiet)
#                         quiet = true
#                     elseif _equals_symbol(flag, :require)
#                         require = true
#                     elseif _equals_symbol(flag, :force)
#                         force = true
#                     end
#                 end
#                 e = e.args[1]
#             end
#
#             # we are going to recursively swap out `a --> b, flags...` commands
#             if e.head == :(-->)
#                 k, v = e.args
#                 keyexpr = :(get(Plots._keyAliases, $k, $k))
#
#                 set_expr = if force
#                     # forced override user settings
#                     :(d[$keyexpr] = $v)
#                 else
#                     # if the user has set this keyword, use theirs
#                     :(get!(d, $keyexpr, $v))
#                 end
#
#                 expr.args[i] = if quiet
#                     # quietly ignore keywords which are not supported
#                     :($keyexpr in supportedArgs() ? $set_expr : nothing)
#                 elseif require
#                     # error when not supported by the backend
#                     :($keyexpr in supportedArgs() ? $set_expr : error("In recipe: required keyword ", $k, " is not supported by backend $(backend_name())"))
#                 else
#                     set_expr
#                 end
#
#                 # @show quiet, force, expr.args[i]
#
#             elseif e.head != :call
#                 # we want to recursively replace the arrows, but not inside function calls
#                 # as this might include things like Dict(1=>2)
#                 replace_recipe_arrows!(e)
#             end
#         end
#     end
# end
#
#
# macro recipe(funcexpr::Expr)
#     lhs, body = funcexpr.args
#
#     if !(funcexpr.head in (:(=), :function))
#         error("Must wrap a valid function call!")
#     end
#     if !(isa(lhs, Expr) && lhs.head == :call)
#         error("Expected `lhs = ...` with lhs as a call Expr... got: $lhs")
#     end
#
#     # for parametric definitions, take the "curly" expression and add the func
#     front = lhs.args[1]
#     func = :(Plots._apply_recipe)
#     if isa(front, Expr) && front.head == :curly
#         front.args[1] = func
#         func = front
#     end
#
#     # get the arg list, stripping out any keyword parameters into a
#     # bunch of get!(kw, key, value) lines
#     args = lhs.args[2:end]
#     kw_body = Expr(:block)
#     if isa(args[1], Expr) && args[1].head == :parameters
#         for kwpair in args[1].args
#             k, v = kwpair.args
#             push!(kw_body.args, :(get!(kw, $(QuoteNode(k)), $v)))
#         end
#         args = args[2:end]
#     end
#
#     # replace all the key => value lines with argument setting logic
#     replace_recipe_arrows!(body)
#
#     # now build a function definition for _apply_recipe, wrapping the return value in a tuple if needed
#     esc(quote
#         function $func(d::KW, kw::KW, $(args...); issubplot=false)
#             $kw_body
#             ret = $body
#             if typeof(ret) <: Tuple
#                 ret
#             else
#                 (ret,)
#             end
#         end
#     end)
# end
#


# ---------------------------------------------------------------------------

# """
# `apply_series_recipe` should take a processed series KW dict and break it up
# into component parts.  For example, a box plot is made up of `shape` for the
# boxes, `path` for the lines, and `scatter` for the outliers.
#
# Returns a Vector{KW}.
# """
# apply_series_recipe(d::KW, st) = KW[d]


# for seriestype `line`, need to sort by x values
@recipe function f(::Type{Val{:line}}, x, y, z)
    indices = sortperm(x)
    d[:x] = x[indices]
    d[:y] = y[indices]
    if typeof(z) <: AVec
        d[:z] = z[indices]
    end
    d[:seriestype] = :path
    ()
end

@recipe function f(::Type{Val{:sticks}}, x, y, z)
    nx = length(x)
    n = 3nx
    newx, newy = zeros(n), zeros(n)
    for i=1:nx
        rng = 3i-2:3i
        newx[rng] = x[i]
        newy[rng] = [0., y[i], 0.]
    end
    d[:x], d[:y] = newx, newy
    d[:seriestype] = :path
    ()
end

# # create a path from steps
# @recipe function f(::Type{Val{:steppre}}, x, y, z)
#
# end


# midpoints = d[:x]
# heights = d[:y]
# fillrange = d[:fillrange] == nothing ? 0.0 : d[:fillrange]
#
# # estimate the edges
# dists = diff(midpoints) * 0.5
# edges = zeros(length(midpoints)+1)
# for i in 1:length(edges)
#   if i == 1
#     edge = midpoints[1] - dists[1]
#   elseif i == length(edges)
#     edge = midpoints[i-1] + dists[i-2]
#   else
#     edge = midpoints[i-1] + dists[i-1]
#   end
#   edges[i] = edge
# end
#
# x = Float64[]
# y = Float64[]
# for i in 1:length(heights)
#   e1, e2 = edges[i:i+1]
#   append!(x, [e1, e1, e2, e2])
#   append!(y, [fillrange, heights[i], heights[i], fillrange])
# end
#
# d[:x] = x
# d[:y] = y
# d[:seriestype] = :path
# d[:fillrange] = fillrange

# create a bar plot as a filled step function
@recipe function f(::Type{Val{:bar}}, x, y, z)
    nx, ny = length(x), length(y)
    edges = if nx == ny
        # x is centers, calc the edges
        # TODO: use bar_width, etc
        midpoints = x
        halfwidths = diff(midpoints) * 0.5
        Float64[if i == 1
            midpoints[1] - halfwidths[1]
        elseif i == ny+1
            midpoints[i-1] + halfwidths[i-2]
        else
            midpoints[i-1] + halfwidths[i-1]
        end for i=1:ny+1]
    elseif nx == ny + 1
        # x is edges
        x
    else
        error("bar recipe: x must be same length as y (centers), or one more than y (edges).\n\t\tlength(x)=$(length(x)), length(y)=$(length(y))")
    end

    # make fillto a vector... default fills to 0
    fillto = d[:fillrange]
    if fillto == nothing
        fillto = zeros(1)
    elseif isa(fillto, Number)
        fillto = Float64[fillto]
    end
    nf = length(fillto)

    npts = 3ny + 1
    heights = y
    x = zeros(npts)
    y = zeros(npts)
    fillrng = zeros(npts)

    # create the path in triplets.  after the first bottom-left coord of the first bar:
    # add the top-left, top-right, and bottom-right coords for each height
    x[1] = edges[1]
    y[1] = fillto[1]
    fillrng[1] = fillto[1]
    for i=1:ny
        idx = 3i
        rng = idx-1:idx+1
        fi = fillto[mod1(i,nf)]
        x[rng] = [edges[i], edges[i+1], edges[i+1]]
        y[rng] = [heights[i], heights[i], fi]
        fillrng[rng] = [fi, fi, fi]
    end

    d[:x] = x
    d[:y] = y
    d[:fillrange] = fillrng
    d[:seriestype] = :path
    ()
end


    #     # x is edges
    #     for i=1:n
    #         gr_fillrect(series, x[i], x[i+1], 0, y[i])
    #     end
    # elseif length(x) == n
    #     # x is centers
    #     leftwidth = length(x) > 1 ? abs(0.5 * (x[2] - x[1])) : 0.5
    #     for i=1:n
    #         rightwidth = (i == n ? leftwidth : abs(0.5 * (x[i+1] - x[i])))
    #         gr_fillrect(series, x[i] - leftwidth, x[i] + rightwidth, 0, y[i])
    #     end
    # else
    #     error("gr_barplot: x must be same length as y (centers), or one more than y (edges).\n\t\tlength(x)=$(length(x)), length(y)=$(length(y))")
    # end

@recipe function f(::Type{Val{:hist}}, x, y, z)
    edges, counts = Base.hist(y, d[:bins])
    d[:x] = edges
    d[:y] = counts
    d[:seriestype] = :bar
    ()
end

# ---------------------------------------------------------------------------
# Box Plot

const _box_halfwidth = 0.4

# function apply_series_recipe(d::KW, ::Type{Val{:box}})
@recipe function f(::Type{Val{:boxplot}}, x, y, z)
    # dumpdict(d, "box before", true)
    # TODO: add scatter series with outliers

    # create a list of shapes, where each shape is a single boxplot
    shapes = Shape[]
    groupby = extractGroupArgs(x)

    for (i, glabel) in enumerate(groupby.groupLabels)

        # filter y values, then compute quantiles
        q1,q2,q3,q4,q5 = quantile(d[:y][groupby.groupIds[i]], linspace(0,1,5))

        # make the shape
        center = i - 0.5
        l, m, r = center - _box_halfwidth, center, center + _box_halfwidth
        xcoords = [
            m, l, r, m, m, NaN,         # lower T
            l, l, r, r, l, NaN,         # lower box
            l, l, r, r, l, NaN,         # upper box
            m, l, r, m, m, NaN,         # upper T
        ]
        ycoords = [
            q1, q1, q1, q1, q2, NaN,    # lower T
            q2, q3, q3, q2, q2, NaN,    # lower box
            q4, q3, q3, q4, q4, NaN,    # upper box
            q5, q5, q5, q5, q4, NaN,    # upper T
        ]
        push!(shapes, Shape(xcoords, ycoords))
    end

    # d[:plotarg_overrides] = KW(:xticks => (1:length(shapes), groupby.groupLabels))

    d[:seriestype] = :shape
    n = length(groupby.groupLabels)
    xticks --> (linspace(0.5,n-0.5,n), groupby.groupLabels)

    # we want to set the fields directly inside series recipes... args are ignored
    d[:x], d[:y] = shape_coords(shapes)
    () # expects a tuple returned

    # KW[d]
end

# ---------------------------------------------------------------------------
# Violin Plot

# if the user has KernelDensity installed, use this for violin plots.
# otherwise, just use a histogram
if is_installed("KernelDensity")
    @eval import KernelDensity
    @eval function violin_coords(y)
        kd = KernelDensity.kde(y, npoints = 30)
        kd.density, kd.x
    end
else
    @eval function violin_coords(y)
        edges, widths = hist(y, 20)
        centers = 0.5 * (edges[1:end-1] + edges[2:end])
        ymin, ymax = extrema(y)
        vcat(0.0, widths, 0.0), vcat(ymin, centers, ymax)
    end
end


# function apply_series_recipe(d::KW, ::Type{Val{:violin}})
@recipe function f(::Type{Val{:violin}}, x, y, z)
    # dumpdict(d, "box before", true)
    # TODO: add scatter series with outliers

    # create a list of shapes, where each shape is a single boxplot
    shapes = Shape[]
    groupby = extractGroupArgs(d[:x])

    for (i, glabel) in enumerate(groupby.groupLabels)

        # get the edges and widths
        y = d[:y][groupby.groupIds[i]]
        widths, centers = violin_coords(y)

        # normalize
        widths = _box_halfwidth * widths / maximum(widths)

        # make the violin
        xcoords = vcat(widths, -reverse(widths)) + (i - 0.5)
        ycoords = vcat(centers, reverse(centers))
        push!(shapes, Shape(xcoords, ycoords))
    end

    # d[:plotarg_overrides] = KW(:xticks => (1:length(shapes), groupby.groupLabels))
    d[:seriestype] = :shape
    n = length(groupby.groupLabels)
    xticks --> (linspace(0.5,n-0.5,n), groupby.groupLabels)

    d[:x], d[:y] = shape_coords(shapes)
    ()

    # KW[d]
end

# ---------------------------------------------------------------------------
# Error Bars

function error_style!(d::KW)
    d[:seriestype] = :path
    d[:linecolor] = d[:markerstrokecolor]
    d[:linewidth] = d[:markerstrokewidth]
    d[:label] = ""
end

# if we're passed a tuple of vectors, convert to a vector of tuples
function error_zipit(ebar)
    if istuple(ebar)
        collect(zip(ebar...))
    else
        ebar
    end
end

function error_coords(xorig, yorig, ebar)
    # init empty x/y, and zip errors if passed Tuple{Vector,Vector}
    x, y = zeros(0), zeros(0)

    # for each point, create a line segment from the bottom to the top of the errorbar
    for i = 1:max(length(xorig), length(yorig))
        xi = get_mod(xorig, i)
        yi = get_mod(yorig, i)
        ebi = get_mod(ebar, i)
        nanappend!(x, [xi, xi])
        e1, e2 = if istuple(ebi)
            first(ebi), last(ebi)
        elseif isscalar(ebi)
            ebi, ebi
        else
            error("unexpected ebi type $(typeof(ebi)) for errorbar: $ebi")
        end
        nanappend!(y, [yi - e1, yi + e2])
    end
    x, y
end

# we will create a series of path segments, where each point represents one
# side of an errorbar
# function apply_series_recipe(d::KW, ::Type{Val{:yerror}})
@recipe function f(::Type{Val{:yerror}}, x, y, z)
    error_style!(d)
    d[:markershape] = :hline
    d[:x], d[:y] = error_coords(d[:x], d[:y], error_zipit(d[:yerror]))
    # KW[d]
    ()
end

# function apply_series_recipe(d::KW, ::Type{Val{:xerror}})
@recipe function f(::Type{Val{:xerror}}, x, y, z)
    error_style!(d)
    d[:markershape] = :vline
    d[:y], d[:x] = error_coords(d[:y], d[:x], error_zipit(d[:xerror]))
    # KW[d]
    ()
end


# ---------------------------------------------------------------------------
# quiver

# function apply_series_recipe(d::KW, ::Type{Val{:quiver}})
function quiver_using_arrows(d::KW)
    d[:label] = ""
    d[:seriestype] = :path
    if !isa(d[:arrow], Arrow)
        d[:arrow] = arrow()
    end

    velocity = error_zipit(d[:quiver])
    xorig, yorig = d[:x], d[:y]

    # for each point, we create an arrow of velocity vi, translated to the x/y coordinates
    x, y = zeros(0), zeros(0)
    for i = 1:max(length(xorig), length(yorig))
        # get the starting position
        xi = get_mod(xorig, i)
        yi = get_mod(yorig, i)

        # get the velocity
        vi = get_mod(velocity, i)
        vx, vy = if istuple(vi)
            first(vi), last(vi)
        elseif isscalar(vi)
            vi, vi
        elseif isa(vi,Function)
            vi(xi, yi)
        else
            error("unexpected vi type $(typeof(vi)) for quiver: $vi")
        end

        # add the points
        nanappend!(x, [xi, xi+vx, NaN])
        nanappend!(y, [yi, yi+vy, NaN])
    end

    d[:x], d[:y] = x, y
    # KW[d]
end

# function apply_series_recipe(d::KW, ::Type{Val{:quiver}})
function quiver_using_hack(d::KW)
    d[:label] = ""
    d[:seriestype] = :shape

    velocity = error_zipit(d[:quiver])
    xorig, yorig = d[:x], d[:y]

    # for each point, we create an arrow of velocity vi, translated to the x/y coordinates
    pts = P2[]
    for i = 1:max(length(xorig), length(yorig))

        # get the starting position
        xi = get_mod(xorig, i)
        yi = get_mod(yorig, i)
        p = P2(xi, yi)

        # get the velocity
        vi = get_mod(velocity, i)
        vx, vy = if istuple(vi)
            first(vi), last(vi)
        elseif isscalar(vi)
            vi, vi
        elseif isa(vi,Function)
            vi(xi, yi)
        else
            error("unexpected vi type $(typeof(vi)) for quiver: $vi")
        end
        v = P2(vx, vy)

        dist = norm(v)
        arrow_h = 0.1dist          # height of arrowhead
        arrow_w = 0.5arrow_h       # halfwidth of arrowhead
        U1 = v ./ dist             # vector of arrowhead height
        U2 = P2(-U1[2], U1[1])     # vector of arrowhead halfwidth
        U1 *= arrow_h
        U2 *= arrow_w

        ppv = p+v
        nanappend!(pts, P2[p, ppv-U1, ppv-U1+U2, ppv, ppv-U1-U2, ppv-U1])
    end

    d[:x], d[:y] = Plots.unzip(pts[2:end])
    # KW[d]
end

# function apply_series_recipe(d::KW, ::Type{Val{:quiver}})
@recipe function f(::Type{Val{:quiver}}, x, y, z)
    if :arrow in supportedArgs()
        quiver_using_arrows(d)
    else
        quiver_using_hack(d)
    end
    ()
end


# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------

function rotate(x::Real, y::Real, θ::Real; center = (0,0))
  cx = x - center[1]
  cy = y - center[2]
  xrot = cx * cos(θ) - cy * sin(θ)
  yrot = cy * cos(θ) + cx * sin(θ)
  xrot + center[1], yrot + center[2]
end

# ---------------------------------------------------------------------------

type EllipseRecipe <: PlotRecipe
  w::Float64
  h::Float64
  x::Float64
  y::Float64
  θ::Float64
end
EllipseRecipe(w,h,x,y) = EllipseRecipe(w,h,x,y,0)

# return x,y coords of a rotated ellipse, centered at the origin
function rotatedEllipse(w, h, x, y, θ, rotθ)
  # # coord before rotation
  xpre = w * cos(θ)
  ypre = h * sin(θ)

  # rotate and translate
  r = rotate(xpre, ypre, rotθ)
  x + r[1], y + r[2]
end

function getRecipeXY(ep::EllipseRecipe)
  x, y = unzip([rotatedEllipse(ep.w, ep.h, ep.x, ep.y, u, ep.θ) for u in linspace(0,2π,100)])
  top = rotate(0, ep.h, ep.θ)
  right = rotate(ep.w, 0, ep.θ)
  linex = Float64[top[1], 0, right[1]] + ep.x
  liney = Float64[top[2], 0, right[2]] + ep.y
  Any[x, linex], Any[y, liney]
end

function getRecipeArgs(ep::EllipseRecipe)
  [(:line, (3, [:dot :solid], [:red :blue], :path))]
end

# -------------------------------------------------

# TODO: this should really be in another package...
type OHLC{T<:Real}
  open::T
  high::T
  low::T
  close::T
end
Base.convert(::Type{OHLC}, tup::Tuple) = OHLC(tup...)
# Base.tuple(ohlc::OHLC) = (ohlc.open, ohlc.high, ohlc.low, ohlc.close)

# get one OHLC path
function get_xy(o::OHLC, x, xdiff)
    xl, xm, xr = x-xdiff, x, x+xdiff
    ox = [xl, xm, NaN,
          xm, xm, NaN,
          xm, xr]
    oy = [o.open, o.open, NaN,
          o.low, o.high, NaN,
          o.close, o.close]
    ox, oy
end

# get the joined vector
function get_xy(v::AVec{OHLC}, x = 1:length(v))
    xdiff = 0.3mean(abs(diff(x)))
    x_out, y_out = zeros(0), zeros(0)
    for (i,ohlc) in enumerate(v)
        ox,oy = get_xy(ohlc, x[i], xdiff)
        nanappend!(x_out, ox)
        nanappend!(y_out, oy)
    end
    x_out, y_out
end

# these are for passing in a vector of OHLC objects
# TODO: when I allow `@recipe f(::Type{T}, v::T) = ...` definitions to replace convertToAnyVector,
#       then I should replace these with one definition to convert to a vector of 4-tuples

# to squash ambiguity warnings...
@recipe f(x::AVec{Function}, v::AVec{OHLC}) = error()
@recipe f{R1<:Number,R2<:Number,R3<:Number,R4<:Number}(x::AVec{Function}, v::AVec{Tuple{R1,R2,R3,R4}}) = error()

# this must be OHLC?
@recipe f{R1<:Number,R2<:Number,R3<:Number,R4<:Number}(x::AVec, ohlc::AVec{Tuple{R1,R2,R3,R4}}) = x, OHLC[OHLC(t...) for t in ohlc]

@recipe function f(x::AVec, v::AVec{OHLC})
    d[:seriestype] = :path
    get_xy(v, x)
end

@recipe function f(v::AVec{OHLC})
    d[:seriestype] = :path
    get_xy(v)
end

# the series recipe, when passed vectors of 4-tuples

# -------------------------------------------------


"Sparsity plot... heatmap of non-zero values of a matrix"
function spy{T<:Real}(z::AMat{T}; kw...)
    mat = map(zi->float(zi!=0), z)'
    xn, yn = size(mat)
    heatmap(mat; leg=false, yflip=true, aspect_ratio=:equal,
        xlim=(0.5, xn+0.5), ylim=(0.5, yn+0.5),
        kw...)
end

"Adds a+bx... straight line over the current plot"
function abline!(plt::Plot, a, b; kw...)
    plot!(plt, [extrema(plt)...], x -> b + a*x; kw...)
end

abline!(args...; kw...) = abline!(current(), args...; kw...)

# =================================================
# Arc and chord diagrams

"Takes an adjacency matrix and returns source, destiny and weight lists"
function mat2list{T}(mat::AbstractArray{T,2})
    nrow, ncol = size(mat) # rows are sources and columns are destinies

    nosymmetric = !issym(mat) # plots only triu for symmetric matrices
    nosparse = !issparse(mat) # doesn't plot zeros from a sparse matrix

    L = length(mat)

    source  = Array(Int, L)
    destiny = Array(Int, L)
    weight  = Array(T, L)

    idx = 1
    for i in 1:nrow, j in 1:ncol
        value = mat[i, j]
        if !isnan(value) && ( nosparse || value != zero(T) ) # TODO: deal with Nullable

            if i < j
                source[idx]  = i
                destiny[idx] = j
                weight[idx]  = value
                idx += 1
            elseif nosymmetric && (i > j)
                source[idx]  = i
                destiny[idx] = j
                weight[idx]  = value
                idx += 1
            end

        end
    end

    resize!(source, idx-1), resize!(destiny, idx-1), resize!(weight, idx-1)
end

# ---------------------------------------------------------------------------
# Arc Diagram

curvecolor(value, min, max, grad) = getColorZ(grad, (value-min)/(max-min))

"Plots a clockwise arc, from source to destiny, colored by weight"
function arc!(source, destiny, weight, min, max, grad)
    radius = (destiny - source) / 2
    arc = Plots.partialcircle(0, π, 30, radius)
    x, y = Plots.unzip(arc)
    plot!(x .+ radius .+ source,  y, line = (curvecolor(weight, min, max, grad), 0.5, 2), legend=false)
end

"""
`arcdiagram(source, destiny, weight[, grad])`

Plots an arc diagram, form `source` to `destiny` (clockwise), using `weight` to determine the colors.
"""
function arcdiagram(source, destiny, weight; kargs...)

    args = KW(kargs)
    grad = pop!(args, :grad,   ColorGradient([colorant"darkred", colorant"darkblue"]))

    if length(source) == length(destiny) == length(weight)

        vertices = unique(vcat(source, destiny))
        sort!(vertices)

        xmin, xmax = extrema(vertices)
        plot(xlim=(xmin - 0.5, xmax + 0.5), legend=false)

        wmin,wmax = extrema(weight)

        for (i, j, value) in zip(source,destiny,weight)
            arc!(i, j, value, wmin, wmax, grad)
        end

        scatter!(vertices, zeros(length(vertices)); legend=false, args...)

    else

        throw(ArgumentError("source, destiny and weight should have the same length"))

    end
end

"""
`arcdiagram(mat[, grad])`

Plots an arc diagram from an adjacency matrix, form rows to columns (clockwise),
using the values on the matrix as weights to determine the colors.
Doesn't show edges with value zero if the input is sparse.
For simmetric matrices, only the upper triangular values are used.
"""
arcdiagram{T}(mat::AbstractArray{T,2}; kargs...) = arcdiagram(mat2list(mat)...; kargs...)

# ---------------------------------------------------------------------------
# Chord diagram

arcshape(θ1, θ2) = Shape(vcat(Plots.partialcircle(θ1, θ2, 15, 1.1),
                            reverse(Plots.partialcircle(θ1, θ2, 15, 0.9))))

colorlist(grad, ::Void) = :darkgray

function colorlist(grad, z)
    zmin, zmax = extrema(z)
    RGBA{Float64}[getColorZ(grad, (zi-zmin)/(zmax-zmin)) for zi in z]'
end

"""
`chorddiagram(source, destiny, weight[, grad, zcolor, group])`

Plots a chord diagram, form `source` to `destiny`,
using `weight` to determine the edge colors using `grad`.
`zcolor` or `group` can be used to determine the node colors.
"""
function chorddiagram(source, destiny, weight; kargs...)

    args  = KW(kargs)
    grad  = pop!(args, :grad,   ColorGradient([colorant"darkred", colorant"darkblue"]))
    zcolor= pop!(args, :zcolor, nothing)
    group = pop!(args, :group,  nothing)

    if zcolor !== nothing && group !== nothing
        throw(ErrorException("group and zcolor can not be used together."))
    end

    if length(source) == length(destiny) == length(weight)

        plt = plot(xlim=(-2,2), ylim=(-2,2), legend=false, grid=false,
        xticks=nothing, yticks=nothing,
        xlim=(-1.2,1.2), ylim=(-1.2,1.2))

        nodemin, nodemax = extrema(vcat(source, destiny))

        weightmin, weightmax = extrema(weight)

        A  = 1.5π # Filled space
        B  = 0.5π # White space (empirical)

        Δα = A / nodemax
        Δβ = B / nodemax

        δ = Δα  + Δβ

        for i in 1:length(source)
            curve = BezierCurve(P2[ (cos((source[i ]-1)*δ + 0.5Δα), sin((source[i ]-1)*δ + 0.5Δα)), (0,0),
                                    (cos((destiny[i]-1)*δ + 0.5Δα), sin((destiny[i]-1)*δ + 0.5Δα)) ])
            plot!(curve_points(curve), line = (Plots.curvecolor(weight[i], weightmin, weightmax, grad), 1, 1))
        end

        if group === nothing
            c =  colorlist(grad, zcolor)
        elseif length(group) == nodemax

            idx = collect(0:(nodemax-1))

            for g in group
                plot!([arcshape(n*δ, n*δ + Δα) for n in idx[group .== g]]; args...)
            end

            return plt

        else
            throw(ErrorException("group should the ", nodemax, " elements."))
        end

        plot!([arcshape(n*δ, n*δ + Δα) for n in 0:(nodemax-1)]; mc=c, args...)

        return plt

    else
        throw(ArgumentError("source, destiny and weight should have the same length"))
    end
end

"""
`chorddiagram(mat[, grad, zcolor, group])`

Plots a chord diagram from an adjacency matrix,
using the values on the matrix as weights to determine edge colors.
Doesn't show edges with value zero if the input is sparse.
For simmetric matrices, only the upper triangular values are used.
`zcolor` or `group` can be used to determine the node colors.
"""
chorddiagram(mat::AbstractMatrix; kargs...) = chorddiagram(mat2list(mat)...; kargs...)
