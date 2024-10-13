"""
    `@df d x`

Convert every symbol in the expression `x` with the respective column in `d` if it exists.

If you want to avoid replacing the symbol, escape it with `^`.

`NA` values are replaced with `NaN` for columns of `Float64` and `""` or `Symbol()`
for strings and symbols respectively.

`x` can be either a plot command or a block of plot commands.
"""
macro df(d, x)
    esc(Expr(:call, df_helper(x), d))
end

"""
    `@df x`

Curried version of `@df d x`. Outputs an anonymous function `d -> @df d x`.
"""
macro df(x)
    esc(df_helper(x))
end

function df_helper(x)
    i = gensym()
    Expr(:(->), i, df_helper(i, x))
end

function df_helper(d, x)
    if isa(x, Expr) && x.head === :block # meaning that there were multiple plot commands
        commands = [
            df_helper(d, xx) for xx in x.args if
            !(isa(xx, Expr) && xx.head === :line || isa(xx, LineNumberNode))
        ] # apply the helper recursively
        return Expr(:block, commands...)

    elseif isa(x, Expr) && x.head === :call # each function call is operated on alone
        syms = Any[]
        vars = Symbol[]
        plot_call = parse_table_call!(d, x, syms, vars)
        names = gensym()
        compute_vars = Expr(
            :(=),
            Expr(:tuple, Expr(:tuple, vars...), names),
            Expr(:call, :($(@__MODULE__).extract_columns_and_names), d, syms...),
        )
        argnames = _argnames(names, x)
        if (length(plot_call.args) >= 2) &&
           isa(plot_call.args[2], Expr) &&
           (plot_call.args[2].head === :parameters)
            label_plot_call = Expr(
                :call,
                :($(@__MODULE__).add_label),
                plot_call.args[2],
                argnames,
                plot_call.args[1],
                plot_call.args[3:end]...,
            )
        else
            label_plot_call =
                Expr(:call, :($(@__MODULE__).add_label), argnames, plot_call.args...)
        end
        return Expr(:block, compute_vars, label_plot_call)

    else
        error("Second argument ($x) can only be a block or function call")
    end
end

parse_table_call!(d, x, syms, vars) = x

function parse_table_call!(d, x::QuoteNode, syms, vars)
    new_var = gensym(x.value)
    push!(syms, x)
    push!(vars, new_var)
    return new_var
end

function parse_table_call!(d, x::Expr, syms, vars)
    if x.head === :. && length(x.args) == 2
        isa(x.args[2], QuoteNode) && return x
    elseif x.head === :call
        x.args[1] === :^ && length(x.args) == 2 && return x.args[2]
        if x.args[1] === :cols
            if length(x.args) == 1
                push!(x.args, :($(@__MODULE__).column_names($d)))
                return parse_table_call!(d, x, syms, vars)
            end
            range = x.args[2]
            new_vars = gensym("range")
            push!(syms, range)
            push!(vars, new_vars)
            return new_vars
        end
    elseif x.head === :braces # From Query: use curly brackets to simplify writing named tuples
        new_ex = Expr(:tuple, x.args...)

        for (j, field_in_NT) in enumerate(new_ex.args)
            if isa(field_in_NT, Expr) && field_in_NT.head === :(=)
                new_ex.args[j] = Expr(:(=), field_in_NT.args...)
            elseif field_in_NT isa QuoteNode
                new_ex.args[j] = Expr(:(=), field_in_NT.value, field_in_NT)
            elseif isa(field_in_NT, Expr)
                new_ex.args[j] = Expr(
                    :(=),
                    Symbol(filter(t -> t != ':', string(field_in_NT))),
                    field_in_NT,
                )
            elseif isa(field_in_NT, Symbol)
                new_ex.args[j] = Expr(:(=), field_in_NT, field_in_NT)
            end
        end
        return parse_table_call!(d, new_ex, syms, vars)
    end
    return Expr(x.head, (parse_table_call!(d, arg, syms, vars) for arg in x.args)...)
end

function column_names(t)
    s = Tables.schema(t)
    s === nothing ? propertynames(first(Tables.rows(t))) : s.names
end

not_kw(x) = true
not_kw(x::Expr) = !(x.head in [:kw, :parameters])

function insert_kw!(x::Expr, s::Symbol, v)
    index = isa(x.args[2], Expr) && x.args[2].head === :parameters ? 3 : 2
    x.args = vcat(x.args[1:(index - 1)], Expr(:kw, s, v), x.args[index:end])
end

function _argnames(names, x::Expr)
    Expr(:vect, [_arg2string(names, s) for s in x.args[2:end] if not_kw(s)]...)
end

_arg2string(names, x) = stringify(x)
function _arg2string(names, x::Expr)
    if x.head === :call && x.args[1] == :cols
        return :($(@__MODULE__).compute_name($names, $(x.args[2])))
    elseif x.head === :call && x.args[1] == :hcat
        return hcat(stringify.(x.args[2:end])...)
    elseif x.head === :hcat
        return hcat(stringify.(x.args)...)
    else
        return stringify(x)
    end
end

stringify(x) = filter(t -> t != ':', string(x))

compute_name(names, i::Int) = names[i]
compute_name(names, i::Symbol) = i
compute_name(names, i) = reshape([compute_name(names, ii) for ii in i], 1, :)

"""
    add_label(argnames, f, args...; kwargs...)

This function ensures that labels are passed to the plotting command, if it accepts them.

If `f` does not accept keyword arguments, and `kwargs` is empty, it will only
forward `args...`.

If the user has provided keyword arguments, but `f` does not accept them,
then it will error.
"""
function add_label(argnames, f, args...; kwargs...)
    i = findlast(t -> isa(t, Expr) || isa(t, AbstractArray), argnames)
    try
        if (i === nothing)
            return f(args...; kwargs...)
        else
            return f(label = stringify.(argnames[i]), args...; kwargs...)
        end
    catch e
        if e isa MethodError ||
           (e isa ErrorException && occursin("does not accept keyword arguments", e.msg))
            # check if the user has supplied kwargs, then we need to rethrow the error
            isempty(kwargs) || rethrow(e)
            # transmit only args to `f`
            return f(args...)
        else
            rethrow(e)
        end
    end
end

get_col(s::Int, col_nt, names) = col_nt[names[s]]
get_col(s::Symbol, col_nt, names) = get(col_nt, s, s)
get_col(syms, col_nt, names) = hcat((get_col(s, col_nt, names) for s in syms)...)

# get the appropriate name when passed an Integer
add_sym!(cols, i::Integer, names) = push!(cols, names[i])
# check for errors in Symbols
add_sym!(cols, s::Symbol, names) = s in names ? push!(cols, s) : cols
# recursively extract column names
function add_sym!(cols, s, names)
    for si in s
        add_sym!(cols, si, names)
    end
    cols
end

"""
    extract_columns_and_names(df, syms...)

Extracts columns and their names (if the column number is an integer)
into a slightly complex `Tuple`.

The structure goes as `((columndata...), names)`.  This is unpacked by the [`@df`](@ref) macro into `gensym`'ed variables, which are passed to the plotting function.

!!! note
    If you want to extend the [`@df`](@ref) macro
    to work with your custom type, this is the
    function you should overload!
"""
function extract_columns_and_names(df, syms...)
    Tables.istable(df) || error("Only tables are supported")
    names = column_names(df)

    # extract selected column names
    selected_cols = add_sym!(Symbol[], syms, names)

    cols = Tables.columntable(TableOperations.select(df, unique(selected_cols)...))
    return Tuple(get_col(s, cols, names) for s in syms), names
end
