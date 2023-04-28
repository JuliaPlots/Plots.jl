module RecipesBase

using PrecompileTools

export @recipe,
    @series,
    @userplot,
    @shorthands,
    @layout,
    RecipeData,
    AbstractBackend,
    AbstractPlot,
    AbstractLayout

# Common abstract types for the Plots ecosystem
abstract type AbstractBackend end
abstract type AbstractPlot{T<:AbstractBackend} end
abstract type AbstractLayout end

const KW = Dict{Symbol,Any}
const AKW = AbstractDict{Symbol,Any}

# a placeholder to establish the name so that other packages (Plots.jl for example)
# can add their own definition of RecipesBase.plot since RecipesBase is the common
# dependency of the Plots ecosystem
function plot end
function plot! end

# a placeholder to establish the name so that other packages (Plots.jl for example)
# can add their own definition of RecipesBase.animate since RecipesBase is the common
# dependency of the Plots ecosystem. Plots.jl will handle the basic cases, while
# other packages can now extend for their types
function animate end

# a placeholder to establish the name so that other packages (Plots.jl for example)
# can add their own definition of RecipesBase.is_key_supported(k::Symbol)
function is_key_supported end

function grid end

# a placeholder to establish the name so that other packages (Plots.jl for example)
# can add their own definition of RecipesBase.group_as_matrix(t)
group_as_matrix(t) = false

# This holds the recipe definitions to be dispatched on
# the function takes in an attribute dict `d` and a list of args.
# This default definition specifies the "no-arg" case.
apply_recipe(plotattributes::AbstractDict{Symbol,Any}) = ()

# Is a key explicitly provided by the user?
# Should be overridden for subtypes representing plot attributes.
is_explicit(d::AbstractDict{Symbol,Any}, k) = haskey(d, k)
function is_default end

# --------------------------------------------------------------------------

# this holds the data and attributes of one series, and is returned from apply_recipe
struct RecipeData
    plotattributes::AbstractDict{Symbol,Any}
    args::Tuple
end

# --------------------------------------------------------------------------

@inline to_symbol(s::Symbol) = s
@inline to_symbol(qn::QuoteNode) = qn.value

@inline wrap_tuple(tup::Tuple) = tup
@inline wrap_tuple(v) = (v,)

# check for flags as part of the `-->` expression
_is_arrow_tuple(expr::Expr) =
    expr.head ≡ :tuple &&
    !isempty(expr.args) &&
    isa(expr.args[1], Expr) &&
    expr.args[1].head === :(-->)

_equals_symbol(x::Symbol, sym::Symbol) = x === sym
_equals_symbol(x::QuoteNode, sym::Symbol) = x.value === sym
_equals_symbol(x, sym::Symbol) = false

# build an apply_recipe function header from the recipe function header
function get_function_def(func_signature::Expr, args::Vector)
    front = func_signature.args[1]
    if func_signature.head ≡ :where
        Expr(:where, get_function_def(front, args), esc.(func_signature.args[2:end])...)
    elseif func_signature.head ≡ :call
        func = Expr(
            :call,
            :($RecipesBase.apply_recipe),
            esc.([:(plotattributes::AbstractDict{Symbol,Any}); args])...,
        )
        if isa(front, Expr) && front.head ≡ :curly
            Expr(:where, func, esc.(front.args[2:end])...)
        else
            func
        end
    else
        error(
            "Expected `func_signature = ...` with func_signature as a call or where Expr... got: $func_signature",
        )
    end
end

function create_kw_body(func_signature::Expr)
    # get the arg list, stripping out any keyword parameters into a
    # bunch of get!(kw, key, value) lines
    func_signature.head ≡ :where && return create_kw_body(func_signature.args[1])
    args = func_signature.args[2:end]
    kw_body, cleanup_body = map(_ -> Expr(:block), 1:2)
    arg1 = args[1]
    if isa(arg1, Expr) && arg1.head ≡ :parameters
        for kwpair in arg1.args
            k, v = kwpair.args
            if isa(k, Expr) && k.head === :(::)
                k = k.args[1]
                @warn """
                Type annotations on keyword arguments not currently supported in recipes.
                Type information has been discarded
                """
            end
            push!(kw_body.args, :($k = get!(plotattributes, $(QuoteNode(k)), $v)))
            push!(
                cleanup_body.args,
                :(
                    $RecipesBase.is_key_supported($(QuoteNode(k))) ||
                    delete!(plotattributes, $(QuoteNode(k)))
                ),
            )
        end
        args = args[2:end]
    end
    args, kw_body, cleanup_body
end

# process the body of the recipe recursively.
# when we see the series macro, we split that block off:
# let
#   d2 = copy(d)
#   <process_recipe_body on d2>
#   RecipeData(d2, block_return)
# end
# and we push this block onto the series_blocks list.
# then at the end we push the main body onto the series list
function process_recipe_body!(expr::Expr)
    for (i, e) in enumerate(expr.args)
        if isa(e, Expr)
            # process trailing flags, like:
            #   a --> b, :quiet, :force
            quiet, require, force = false, false, false
            if _is_arrow_tuple(e)
                for flag in e.args
                    if _equals_symbol(flag, :quiet)
                        quiet = true
                    elseif _equals_symbol(flag, :require)
                        require = true
                    elseif _equals_symbol(flag, :force)
                        force = true
                    end
                end
                e = e.args[1]
            end

            # the unused operator `:=` will mean force: `x := 5` is equivalent to `x --> 5, force`
            # note: this means "x is defined as 5"
            if e.head === :(:=)
                force = true
                e.head = :(-->)
            end

            # we are going to recursively swap out `a --> b, flags...` commands
            # note: this means "x may become 5"
            if e.head === :(-->)
                k, v = e.args
                if isa(k, Symbol)
                    k = QuoteNode(k)
                end

                set_expr = if force
                    # forced override user settings
                    :(plotattributes[$k] = $v)
                else
                    # if the user has set this keyword, use theirs
                    :($RecipesBase.is_explicit(plotattributes, $k) || (plotattributes[$k] = $v))
                end

                expr.args[i] = if quiet
                    # quietly ignore keywords which are not supported
                    :($RecipesBase.is_key_supported($k) ? $set_expr : nothing)
                elseif require
                    # error when not supported by the backend
                    :(
                        $RecipesBase.is_key_supported($k) ? $set_expr :
                        error(
                            "In recipe: required keyword ",
                            $k,
                            " is not supported by backend $(backend_name())",
                        )
                    )
                else
                    set_expr
                end

            elseif e.head ≡ :return
                # To allow `return` in recipes just extract the returned arguments.
                expr.args[i] = first(e.args)

            elseif e.head ≢ :call
                # we want to recursively replace the arrows, but not inside function calls
                # as this might include things like Dict(1=>2)
                process_recipe_body!(e)
            end
        end
    end
end

# --------------------------------------------------------------------------

"""
This handy macro will process a function definition, replace `-->` commands, and
then add a new version of `RecipesBase.apply_recipe` for dispatching on the arguments.

This functionality is primarily geared to turning user types and settings into the
data and attributes that describe a Plots.jl visualization.

Set attributes using the `-->` command, and return a comma separated list of arguments that
should replace the current arguments.

An example:

```julia
using RecipesBase

# Our custom type that we want to display
struct T end

@recipe function plot(t::T, n::Integer = 1; customcolor = :green)
    markershape --> :auto, :require
    markercolor --> customcolor, :force
    xrotation --> 5
    zrotation --> 6, :quiet
    rand(10,n)
end

# ---------------------

# Plots will be the ultimate consumer of our recipe in this example
using Plots; gr()

# This call will implicitly call `RecipesBase.apply_recipe` as part of the Plots
# processing pipeline (see the Pipeline section of the Plots documentation).
# It will plot 5 line plots, all with black circles for markers.
# The markershape argument must be supported, and the zrotation argument's warning
# will be suppressed.  The user can override all arguments except markercolor.
plot(T(), 5; customcolor = :black, shape=:c)
```

In this example, we see lots of the machinery in action.  We create a new type `T` which
we will use for dispatch, and an optional argument `n`, which will be used to determine the
number of series to display.  User-defined keyword arguments are passed through, and the
`-->` command can be trailed by flags:

- quiet:   Suppress unsupported keyword warnings
- require: Error if keyword is unsupported
- force:   Don't allow user override for this keyword
"""
macro recipe(funcexpr::Expr)
    func_signature, func_body = funcexpr.args

    funcexpr.head in (:(=), :function) || error("Must wrap a valid function call!")
    if !(isa(func_signature, Expr) && func_signature.head in (:call, :where))
        error(
            "Expected `func_signature = ...` with func_signature as a call or where Expr...got: $func_signature",
        )
    end
    if length(func_signature.args) < 2
        error("Missing function arguments... need something to dispatch on!")
    end

    args, kw_body, cleanup_body = create_kw_body(func_signature)
    func = get_function_def(func_signature, args)

    @debug "$(__source__.file):$(__source__.line)" func args kw_body cleanup_body

    # this is where the recipe func_body is processed
    # replace all the key => value lines with argument setting logic
    # and break up by series.
    process_recipe_body!(func_body)

    # now build a function definition for apply_recipe, wrapping the return value in a tuple if needed.
    # we are creating a vector of RecipeData objects, one per series.
    return Expr(
        :function,
        func,
        quote
            @nospecialize
            $kw_body
            $cleanup_body
            series_list = $RecipesBase.RecipeData[]
            func_return = $func_body
            func_return === nothing || push!(
                series_list,
                $RecipesBase.RecipeData(
                    plotattributes,
                    $RecipesBase.wrap_tuple(func_return),
                ),
            )
            series_list
        end |> esc,
    )
end

# --------------------------------------------------------------------------

"""
Meant to be used inside a recipe to add additional RecipeData objects to the list:

```julia
@recipe function f(::T)
    # everything get this setting
    linecolor --> :red

    @series begin
        # this setting is only for this series
        fillcolor := :green

        # return the args, just like in recipes
        rand(10)
    end

    # this is the main series... though it can be skipped by returning nothing.
    # note: a @series block returns nothing
    rand(100)
end
```
"""
macro series(expr::Expr)
    quote
        let plotattributes = copy(plotattributes)
            args = $expr
            push!(
                series_list,
                $RecipesBase.RecipeData(plotattributes, $RecipesBase.wrap_tuple(args)),
            )
            nothing
        end
    end |> esc
end

# --------------------------------------------------------------------------

"""
You can easily define your own plotting recipes with convenience methods:
```julia
@userplot GroupHist

@recipe function f(gh::GroupHist)
    # set some attributes, add some series, using gh.args as input
end
# now you can plot like:
grouphist(rand(1_000, 4))
```
"""
macro userplot(expr)
    _userplot(expr)
end

function _userplot(expr::Expr)
    expr.head ≡ :struct ||
        error("Must call userplot on a [mutable] struct expression. Got: $expr")

    typename = gettypename(expr.args[2])
    funcname = Symbol(lowercase(string(typename)))
    funcname2 = Symbol(funcname, "!")

    # return a code block with the type definition and convenience plotting methods
    quote
        $expr
        export $funcname, $funcname2
        Core.@__doc__ $funcname(args...; kw...) =
            $RecipesBase.plot($typename(args); kw...)
        Core.@__doc__ $funcname2(args...; kw...) =
            $RecipesBase.plot!($typename(args); kw...)
        Core.@__doc__ $funcname2(plt::$RecipesBase.AbstractPlot, args...; kw...) =
            $RecipesBase.plot!(plt, $typename(args); kw...)
    end |> esc
end

_userplot(sym::Symbol) = _userplot(:(mutable struct $sym
    args
end))

gettypename(sym::Symbol) = sym

function gettypename(expr::Expr)
    expr.head ≡ :curly || @error "Unexpected struct name: $expr"
    expr.args[1]
end

#----------------------------------------------------------------------------

"""
    @shorthands(funcname::Symbol)

Defines and exports shorthand plotting method definitions (`\$funcname` and `\$funcname!`).
Pass the series type (as a symbol) to the macro.

## Examples

```julia
# define some series type
@recipe function f(::Type{Val{:myseriestype}}, x, y)
    # some implementation here
end
# docstrings are forwarded
\"\"\"
    myseriestype(x, y)
Plot my series type!
\"\"\"
@shorthands myseriestype
```
"""
macro shorthands(funcname::Symbol)
    funcname2 = Symbol(funcname, "!")
    quote
        export $funcname, $funcname2
        Core.@__doc__ $funcname(args...; kw...) =
            $RecipesBase.plot(args...; kw..., seriestype = $(Meta.quot(funcname)))
        Core.@__doc__ $funcname2(args...; kw...) =
            $RecipesBase.plot!(args...; kw..., seriestype = $(Meta.quot(funcname)))
    end |> esc
end

#----------------------------------------------------------------------------

# allow usage of type recipes without depending on StatsPlots

"""
`recipetype(s, args...)`

Use this function to refer to type recipes by their symbol, without taking a dependency.

# Example

```julia
import RecipesBase: recipetype
recipetype(:groupedbar, 1:10, rand(10, 2))
```

instead of

```julia
import StatsPlots: GroupedBar
GroupedBar((1:10, rand(10, 2)))
```
"""
recipetype(s, args...) = recipetype(Val(s), args...)

recipetype(s::Val{T}, args...) where {T} =
    error("No type recipe defined for type $T. You may need to load StatsPlots")

# ----------------------------------------------------------------------
# @layout macro

function add_layout_pct!(kw::AKW, v::Expr, idx::Integer, nidx::Integer)
    # dump(v)
    # something like {0.2w}?
    if v.head ≡ :call && v.args[1] ≡ :*
        num = v.args[2]
        if length(v.args) == 3 && isa(num, Number)
            if (units = v.args[3]) ∈ (:h, :w)
                return kw[units] = num
            end
        end
    end
    error("Couldn't match layout curly (idx=$idx): $v")
end

isrow(v) = isa(v, Expr) && v.head in (:hcat, :row)
iscol(v) = isa(v, Expr) && v.head ≡ :vcat
rowsize(v) = isrow(v) ? length(v.args) : 1

create_grid(expr::Expr) =
    if iscol(expr)
        create_grid_vcat(expr)
    elseif isrow(expr)
        sub(x) = :(cell[1, $(first(x))] = $(create_grid(last(x))))
        quote
            let cell = Matrix(undef, 1, $(length(expr.args)))
                $(map(sub, enumerate(expr.args))...)
                cell
            end
        end
    elseif expr.head ≡ :curly
        create_grid_curly(expr)
    else
        esc(expr)  # if it's something else, just return that (might be an existing layout?)
    end

function create_grid_vcat(expr::Expr)
    rowsizes = map(rowsize, expr.args)
    rmin, rmax = extrema(rowsizes)
    if rmin > 0 && rmin == rmax
        # we have a grid... build the whole thing
        # note: rmin is the number of columns
        nr = length(expr.args)
        nc = rmin
        body = Expr(:block)
        for r in 1:nr
            if (arg = expr.args[r]) |> isrow
                for (c, item) in enumerate(arg.args)
                    push!(body.args, :(cell[$r, $c] = $(create_grid(item))))
                end
            else
                push!(body.args, :(cell[$r, 1] = $(create_grid(arg))))
            end
        end
        quote
            let cell = Matrix(undef, $nr, $nc)
                $body
                cell
            end
        end
    else
        # otherwise just build one row at a time
        sub(x) = :(cell[$(first(x)), 1] = $(create_grid(last(x))))
        quote
            let cell = Matrix(undef, $(length(expr.args)), 1)
                $(map(sub, enumerate(expr.args))...)
                cell
            end
        end
    end
end

function create_grid_curly(expr::Expr)
    kw = KW()
    for (i, arg) in enumerate(expr.args[2:end])
        add_layout_pct!(kw, arg, i, length(expr.args) - 1)
    end
    s = expr.args[1]
    if isa(s, Expr) && s.head ≡ :call && s.args[1] ≡ :grid
        create_grid(
            quote
                grid(
                    $(s.args[2:end]...),
                    width = $(get(kw, :w, QuoteNode(:auto))),
                    height = $(get(kw, :h, QuoteNode(:auto))),
                )
            end,
        )
    elseif isa(s, Symbol)
        quote
            (
                label = $(QuoteNode(s)),
                width = $(get(kw, :w, QuoteNode(:auto))),
                height = $(get(kw, :h, QuoteNode(:auto))),
            )
        end
    else
        error("Unknown use of curly brackets: $expr")
    end
end

create_grid(s::Symbol) = :((label = $(QuoteNode(s)), blank = $(s ≡ :_)))

"""
    @layout mat

Generate the subplots layout from a matrix of symbols (where subplots can span multiple rows or columns).
Precise sizing can be achieved with curly brackets, otherwise the free space is equally split between the plot areas of subplots.
You can use the `_` character (underscore) to ignore plots in the layout (blank plots).

# Examples

```julia-repl
julia> @layout [a b; c]
2×1 Matrix{Any}:
 Any[(label = :a, blank = false) (label = :b, blank = false)]
 (label = :c, blank = false)

julia> @layout [a{0.3w}; b{0.2h}]
2×1 Matrix{Any}:
 (label = :a, width = 0.3, height = :auto)
 (label = :b, width = :auto, height = 0.2)

julia> @layout [_ ° _; ° ° °; ° ° °]
3×3 Matrix{Any}:
 (label = :_, blank = true)   …  (label = :_, blank = true)
 (label = :°, blank = false)     (label = :°, blank = false)
 (label = :°, blank = false)     (label = :°, blank = false)

```
"""
macro layout(mat::Expr)
    create_grid(mat)
end

# COV_EXCL_START
@setup_workload begin
    struct __RecipesBasePrecompileType end
    @compile_workload begin
        @layout [a b; c]
        @layout [a{0.3w}; b{0.2h}]
        @layout [_ ° _; ° ° °; ° ° °]
        # @userplot __RecipesBasePrecompileType  # fails (export statements)
        @recipe f(::__RecipesBasePrecompileType) = begin
            @series begin
                markershape --> :auto, :require
                markercolor --> customcolor, :force
                xrotation --> 5
                zrotation --> 6, :quiet
                fillcolor := :green
                ones(1)
            end
            zeros(1)
        end
    end
end
# COV_EXCL_STOP
end
