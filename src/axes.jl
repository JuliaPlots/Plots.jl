

xaxis(args...; kw...) = Axis(:x, args...; kw...)
yaxis(args...; kw...) = Axis(:y, args...; kw...)
zaxis(args...; kw...) = Axis(:z, args...; kw...)


function Axis(letter::Symbol, args...; kw...)
    # init with values from _plot_defaults
    d = KW(
        :letter => letter,
        :extrema => (Inf, -Inf),
        :discrete_map => Dict(),   # map discrete values to discrete indices
        # :discrete_values => Tuple{Float64,Any}[],
        :discrete_values => [],
        :continuous_values => zeros(0),
        :use_minor => false,
        :show => true,  # show or hide the axis? (useful for linked subplots)
    )
    merge!(d, _axis_defaults)

    # update the defaults
    update!(Axis(d), args...; kw...)
end

function process_axis_arg!(d::KW, arg, letter = "")
    T = typeof(arg)
    arg = get(_scaleAliases, arg, arg)

    if typeof(arg) <: Font
        d[symbol(letter,:tickfont)] = arg
        d[symbol(letter,:guidefont)] = arg

    elseif arg in _allScales
        d[symbol(letter,:scale)] = arg

    elseif arg in (:flip, :invert, :inverted)
        d[symbol(letter,:flip)] = true

    elseif T <: @compat(AbstractString)
        d[symbol(letter,:guide)] = arg

    # xlims/ylims
    elseif (T <: Tuple || T <: AVec) && length(arg) == 2
        sym = typeof(arg[1]) <: Number ? :lims : :ticks
        d[symbol(letter,sym)] = arg

    # xticks/yticks
    elseif T <: AVec
        d[symbol(letter,:ticks)] = arg

    elseif arg == nothing
        d[symbol(letter,:ticks)] = []

    elseif typeof(arg) <: Number
        d[symbol(letter,:rotation)] = arg

    else
        warn("Skipped $(letter)axis arg $arg")

    end
end

# update an Axis object with magic args and keywords
function update!(a::Axis, args...; kw...)
    # first process args
    d = a.d
    for arg in args
        process_axis_arg!(d, arg)
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
        # vals, labels = unzip(dvals)
        a[:continuous_values], dvals
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


# using the axis extrema and limit overrides, return the min/max value for this axis
function axis_limits(axis::Axis, letter)
    amin, amax = axis[:extrema]
    lims = axis[:lims]
    if isa(lims, Tuple) && length(lims) == 2
        if isfinite(lims[1])
            amin = lims[1]
        end
        if isfinite(lims[2])
            amax = lims[2]
        end
    end
    if amax <= amin
        amax = amin + 1.0
    end
    amin, amax
end

# these methods track the discrete values which correspond to axis continuous values (cv)
# whenever we have discrete values, we automatically set the ticks to match.
# we return (continuous_value, discrete_index)
function discrete_value!(a::Axis, dv)
    cv_idx = get(a[:discrete_map], dv, -1)
    if cv_idx == -1
        emin, emax = a[:extrema]
        cv = max(0.5, emax + 1.0)
        expand_extrema!(a, cv)
        push!(a[:discrete_values], dv)
        push!(a[:continuous_values], cv)
        cv_idx = length(a[:discrete_values])
        a[:discrete_map][dv] = cv_idx
        cv, cv_idx
    else
        cv = a[:continuous_values][cv_idx]
        cv, cv_idx
    end
end

# continuous value... just pass back with a negative index
function discrete_value!(a::Axis, cv::Number)
    cv, -1
end

# add the discrete value for each item.  return the continuous values and the indices
function discrete_value!(a::Axis, v::AVec)
    n = length(v)
    cvec = zeros(n)
    discrete_indices = zeros(Int, n)
    for i=1:n
        cvec[i], discrete_indices[i] = discrete_value!(a, v[i])
    end
    cvec, discrete_indices
end

function pie_labels(sp::Subplot, series::Series)
    d = series.d
    if haskey(d,:x_discrete_indices)
        dvals = sp.attr[:xaxis].d[:discrete_values]
        [dvals[idx] for idx in d[:x_discrete_indices]]
    else
        d[:x]
    end
end
