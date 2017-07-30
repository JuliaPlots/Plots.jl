
__precompile__()

module RecipesBase

export
    @recipe,
    @series,
    @userplot,
    @shorthands,
    RecipeData,
    AbstractBackend,
    AbstractPlot,
    AbstractLayout

# Common abstract types for the Plots ecosystem
abstract type AbstractBackend end
abstract type AbstractPlot{T<:AbstractBackend} end
abstract type AbstractLayout end

# a placeholder to establish the name so that other packages (Plots.jl for example)
# can add their own definition of RecipesBase.plot since RecipesBase is the common
# dependency of the Plots ecosystem
function plot end

# a placeholder to establish the name so that other packages (Plots.jl for example)
# can add their own definition of RecipesBase.animate since RecipesBase is the common
# dependency of the Plots ecosystem. Plots.jl will handle the basic cases, while
# other packages can now extend for their types
function animate end

# a placeholder to establish the name so that other packages (Plots.jl for example)
# can add their own definition of RecipesBase.is_key_supported(k::Symbol)
function is_key_supported end

# This holds the recipe definitions to be dispatched on
# the function takes in an attribute dict `d` and a list of args.
# This default definition specifies the "no-arg" case.
apply_recipe(d::Dict{Symbol,Any}) = ()

const _debug_recipes = Bool[false]
function debug(v::Bool = true)
    _debug_recipes[1] = v
end

# --------------------------------------------------------------------------

# this holds the data and attributes of one series, and is returned from apply_recipe
immutable RecipeData
    d::Dict{Symbol,Any}
    args::Tuple
end

# --------------------------------------------------------------------------

@inline to_symbol(s::Symbol) = s
@inline to_symbol(qn::QuoteNode) = qn.value

@inline wrap_tuple(tup::Tuple) = tup
@inline wrap_tuple(v) = (v,)

# check for flags as part of the `-->` expression
function _is_arrow_tuple(expr::Expr)
    expr.head == :tuple && !isempty(expr.args) &&
        isa(expr.args[1], Expr) &&
        expr.args[1].head == :(-->)
end

function _equals_symbol(arg::Symbol, sym::Symbol)
    arg == sym
end
function _equals_symbol(arg::Expr, sym::Symbol)
    arg.head == :quote && arg.args[1] == sym
end

# build an apply_recipe function header from the recipe function header
function get_function_def(func_signature::Expr, args::Vector)
    front = func_signature.args[1]
    if func_signature.head == :where
        Expr(:where, get_function_def(front, args), esc.(func_signature.args[2:end])...)
    elseif func_signature.head == :call
        func = Expr(:call, :(RecipesBase.apply_recipe), esc.([:(d::Dict{Symbol, Any}); args])...)
        if isa(front, Expr) && front.head == :curly
            Expr(:where, func, esc.(front.args[2:end])...)
        else
            func
        end
    else
        error("Expected `func_signature = ...` with func_signature as a call or where Expr... got: $func_signature")
    end
end

function create_kw_body(func_signature::Expr)
    # get the arg list, stripping out any keyword parameters into a
    # bunch of get!(kw, key, value) lines
    func_signature.head == :where && return create_kw_body(func_signature.args[1])
    args = func_signature.args[2:end]
    kw_body = Expr(:block)
    cleanup_body = Expr(:block)
    if isa(args[1], Expr) && args[1].head == :parameters
        for kwpair in args[1].args
            k, v = kwpair.args
            push!(kw_body.args, :($k = get!(d, $(QuoteNode(k)), $v)))
            push!(cleanup_body.args, :(RecipesBase.is_key_supported($(QuoteNode(k))) || delete!(d, $(QuoteNode(k)))))
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
    for (i,e) in enumerate(expr.args)
        if isa(e,Expr)

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
            if e.head == :(:=)
                force = true
                e.head = :(-->)
            end

            # we are going to recursively swap out `a --> b, flags...` commands
            # note: this means "x may become 5"
            if e.head == :(-->)
                k, v = e.args
                if isa(k, Symbol)
                    k = QuoteNode(k)
                end

                set_expr = if force
                    # forced override user settings
                    :(d[$k] = $v)
                else
                    # if the user has set this keyword, use theirs
                    :(get!(d, $k, $v))
                end

                expr.args[i] = if quiet
                    # quietly ignore keywords which are not supported
                    :(RecipesBase.is_key_supported($k) ? $set_expr : nothing)
                elseif require
                    # error when not supported by the backend
                    :(RecipesBase.is_key_supported($k) ? $set_expr : error("In recipe: required keyword ", $k, " is not supported by backend $(backend_name())"))
                else
                    set_expr
                end

            # TODO elseif it's a @series macrocall, add a series block and push to the `series` list

            elseif e.head != :call
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

```
using RecipesBase

# Our custom type that we want to display
type T end

@recipe function plot{N<:Integer}(t::T, n::N = 1; customcolor = :green)
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

    if !(funcexpr.head in (:(=), :function))
        error("Must wrap a valid function call!")
    end
    if length(func_signature.args) < 2
        error("Missing function arguments... need something to dispatch on!")
    end

    args, kw_body, cleanup_body = create_kw_body(func_signature)
    func = get_function_def(func_signature, args)

    # this is where the receipe func_body is processed
    # replace all the key => value lines with argument setting logic
    # and break up by series.
    process_recipe_body!(func_body)

    # now build a function definition for apply_recipe, wrapping the return value in a tuple if needed.
    # we are creating a vector of RecipeData objects, one per series.
    funcdef = Expr(:function, func, esc(quote
        if RecipesBase._debug_recipes[1]
            println("apply_recipe args: ", $args)
        end
        $kw_body
        $cleanup_body
        series_list = RecipesBase.RecipeData[]
        func_return = $func_body
        if func_return != nothing
            push!(series_list, RecipesBase.RecipeData(d, RecipesBase.wrap_tuple(func_return)))
        end
        series_list
    end))
    funcdef
end


# --------------------------------------------------------------------------

"""
Meant to be used inside a recipe to add additional RecipeData objects to the list:

```
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
    esc(quote
        let d = copy(d)
            args = $expr
            push!(series_list, RecipesBase.RecipeData(d, RecipesBase.wrap_tuple(args)))
            nothing
        end
    end)
end

# --------------------------------------------------------------------------

"""
You can easily define your own plotting recipes with convenience methods:
```
@userplot type GroupHist
    args
end
@recipe function f(gh::GroupHist)
    # set some attributes, add some series, using gh.args as input
end
# now you can plot like:
grouphist(rand(1000,4))
```
"""
macro userplot(expr)
    _userplot(expr)
end

function _userplot(expr::Expr)
    if expr.head != :type
        errror("Must call userplot on a type/immutable expression.  Got: $expr")
    end

    typename = expr.args[2]
    funcname = Symbol(lowercase(string(typename)))
    funcname2 = Symbol(funcname, "!")

    # return a code block with the type definition and convenience plotting methods
    esc(quote
        $expr
        export $funcname, $funcname2
        $funcname(args...; kw...) = plot($typename(args); kw...)
        $funcname2(args...; kw...) = plot!($typename(args); kw...)
    end)
end

function _userplot(sym::Symbol)
    _userplot(:(type $sym
            args
    end))
end

#----------------------------------------------------------------------------

# define and export shorthand plotting method definitions
macro shorthands(funcname::Symbol)
    funcname2 = Symbol(funcname, "!")
    esc(quote
        export $funcname, $funcname2
        $funcname(args...; kw...) = plot(args...; kw..., seriestype = $(Meta.quot(funcname)))
        $funcname2(args...; kw...) = plot!(args...; kw..., seriestype = $(Meta.quot(funcname)))
    end)
end

end # module
