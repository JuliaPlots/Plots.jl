

xaxis(args...; kw...) = Axis(:x, args...; kw...)
yaxis(args...; kw...) = Axis(:y, args...; kw...)
zaxis(args...; kw...) = Axis(:z, args...; kw...)


function Axis(letter::Symbol, args...; kw...)
    # init with values from _plot_defaults
    d = KW(
        :letter => letter,
        :extrema => (Inf, -Inf),
        :discrete_map => Dict(),   # map discrete values to continuous plot values
        :discrete_values => Tuple{Float64,Any}[],
        :use_minor => false,
        :show => true,  # show or hide the axis? (useful for linked subplots)
    )
    merge!(d, _axis_defaults)

    # update the defaults
    update!(Axis(d), args...; kw...)
end

# update an Axis object with magic args and keywords
function update!(a::Axis, args...; kw...)
    # first process args
    d = a.d
    for arg in args
        T = typeof(arg)
        arg = get(_scaleAliases, arg, arg)

        if typeof(arg) <: Font
            d[:tickfont] = arg
            d[:guidefont] = arg

        elseif arg in _allScales
            d[:scale] = arg

        elseif arg in (:flip, :invert, :inverted)
            d[:flip] = true

        elseif T <: @compat(AbstractString)
            d[:guide] = arg

        # xlims/ylims
        elseif (T <: Tuple || T <: AVec) && length(arg) == 2
            sym = typeof(arg[1]) <: Number ? :lims : :ticks
            d[sym] = arg

        # xticks/yticks
        elseif T <: AVec
            d[:ticks] = arg

        elseif arg == nothing
            d[:ticks] = []

        elseif typeof(arg) <: Number
            d[:rotation] = arg

        else
            warn("Skipped $(letter)axis arg $arg")

        end
    end

    # then override for any keywords... only those keywords that already exists in d
    for (k,v) in kw
        # sym = symbol(string(k)[2:end])
        if haskey(d, k)
            d[k] = v
        end
    end
    a
end


Base.show(io::IO, a::Axis) = dumpdict(a.d, "Axis", true)
Base.getindex(a::Axis, k::Symbol) = getindex(a.d, k)
Base.setindex!(a::Axis, v, ks::Symbol...) = setindex!(a.d, v, ks...)
Base.haskey(a::Axis, k::Symbol) = haskey(a.d, k)
Base.extrema(a::Axis) = a[:extrema]

# get discrete ticks, or not
function get_ticks(a::Axis)
    ticks = a[:ticks]
    dvals = a[:discrete_values]
    if !isempty(dvals) && ticks == :auto
        vals, labels = unzip(dvals)
    else
        ticks
    end
end

function expand_extrema!(a::Axis, v::Number)
    emin, emax = a[:extrema]
    a[:extrema] = (min(v, emin), max(v, emax))
end
function expand_extrema!{MIN<:Number,MAX<:Number}(a::Axis, v::Tuple{MIN,MAX})
    emin, emax = a[:extrema]
    a[:extrema] = (min(v[1], emin), max(v[2], emax))
end
function expand_extrema!{N<:Number}(a::Axis, v::AVec{N})
    if !isempty(v)
        emin, emax = a[:extrema]
        a[:extrema] = (min(minimum(v), emin), max(maximum(v), emax))
    end
    a[:extrema]
end

# these methods track the discrete values which correspond to axis continuous values (cv)
# whenever we have discrete values, we automatically set the ticks to match.
# we return the plot value
function discrete_value!(a::Axis, v)
    cv = get(a[:discrete_map], v, NaN)
    if isnan(cv)
        emin, emax = a[:extrema]
        cv = max(0.5, emax + 1.0)
        expand_extrema!(a, cv)
        a[:discrete_map][v] = cv
        push!(a[:discrete_values], (cv, v))
    end
    cv
end

# add the discrete value for each item
function discrete_value!(a::Axis, v::AVec)
    Float64[discrete_value!(a, vi) for vi=v]
end
