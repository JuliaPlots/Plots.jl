
__precompile__()

module RecipesBase

export
    @recipe
    # apply_recipe,
    # is_key_supported

# a placeholder... this method should never be called... it's just to establish the
# name so that other packages (Plots.jl for example) can add their own definition
# of RecipesBase.is_key_supported(k::Symbol)
is_key_supported() = true

# this holds the recipe definitions to be dispatched on
apply_recipe(d::Dict{Symbol,Any}, kw::Dict{Symbol,Any}) = ()

# --------------------------------------------------------------------------

function _is_arrow_tuple(expr::Expr)
    expr.head == :tuple &&
        isa(expr.args[1], Expr) &&
        expr.args[1].head == :(-->)
end

function _equals_symbol(arg::Symbol, sym::Symbol)
    arg == sym
end
function _equals_symbol(arg::Expr, sym::Symbol)
    arg.head == :quote && arg.args[1] == sym
end

function replace_recipe_arrows!(expr::Expr)
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

            # we are going to recursively swap out `a --> b, flags...` commands
            if e.head == :(-->)
                k, v = e.args

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

                # @show quiet, force, expr.args[i]

            elseif e.head != :call
                # we want to recursively replace the arrows, but not inside function calls
                # as this might include things like Dict(1=>2)
                replace_recipe_arrows!(e)
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
    # Plots will be the ultimate consumer of our recipe in this example
    using Plot
    gr()

    type T end

    @recipe function plot{N<:Integer}(t::T, n::N = 1; customcolor = :green)
        :markershape --> :auto, :require
        :markercolor --> customcolor, :force
        :xrotation --> 5
        :zrotation --> 6, :quiet
        rand(10,n)
    end

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
    lhs, body = funcexpr.args

    if !(funcexpr.head in (:(=), :function))
        error("Must wrap a valid function call!")
    end
    if !(isa(lhs, Expr) && lhs.head == :call)
        error("Expected `lhs = ...` with lhs as a call Expr... got: $lhs")
    end

    # for parametric definitions, take the "curly" expression and add the func
    front = lhs.args[1]
    func = :(RecipesBase.apply_recipe)
    if isa(front, Expr) && front.head == :curly
        front.args[1] = func
        func = front
    end

    # get the arg list, stripping out any keyword parameters into a
    # bunch of get!(kw, key, value) lines
    args = lhs.args[2:end]
    kw_body = Expr(:block)
    if isa(args[1], Expr) && args[1].head == :parameters
        for kwpair in args[1].args
            k, v = kwpair.args
            push!(kw_body.args, :($k = get!(kw, $(QuoteNode(k)), $v)))
        end
        args = args[2:end]
    end

    # replace all the key => value lines with argument setting logic
    replace_recipe_arrows!(body)

    # now build a function definition for apply_recipe, wrapping the return value in a tuple if needed
    esc(quote
        function $func(d::Dict{Symbol,Any}, kw::Dict{Symbol,Any}, $(args...); issubplot=false)
            $kw_body
            ret = $body
            if typeof(ret) <: Tuple
                ret
            else
                (ret,)
            end
        end
    end)
end

# --------------------------------------------------------------------------

end # module
