

xaxis(args...; kw...) = Axis(:x, args...; kw...)
yaxis(args...; kw...) = Axis(:y, args...; kw...)
zaxis(args...; kw...) = Axis(:z, args...; kw...)

# -------------------------------------------------------------------------

function Axis(letter::Symbol, args...; kw...)
    # init with values from _plot_defaults
    d = KW(
        :letter => letter,
        # :extrema => (Inf, -Inf),
        :extrema => Extrema(),
        :discrete_map => Dict(),   # map discrete values to discrete indices
        :continuous_values => zeros(0),
        :use_minor => false,
        :show => true,  # show or hide the axis? (useful for linked subplots)
    )
    merge!(d, _axis_defaults)
    d[:discrete_values] = []

    # update the defaults
    update!(Axis(d), args...; kw...)
end

function process_axis_arg!(d::KW, arg, letter = "")
    T = typeof(arg)
    arg = get(_scaleAliases, arg, arg)

    if typeof(arg) <: Font
        d[Symbol(letter,:tickfont)] = arg
        d[Symbol(letter,:guidefont)] = arg

    elseif arg in _allScales
        d[Symbol(letter,:scale)] = arg

    elseif arg in (:flip, :invert, :inverted)
        d[Symbol(letter,:flip)] = true

    elseif T <: AbstractString
        d[Symbol(letter,:guide)] = arg

    # xlims/ylims
    elseif (T <: Tuple || T <: AVec) && length(arg) == 2
        sym = typeof(arg[1]) <: Number ? :lims : :ticks
        d[Symbol(letter,sym)] = arg

    # xticks/yticks
    elseif T <: AVec
        d[Symbol(letter,:ticks)] = arg

    elseif arg == nothing
        d[Symbol(letter,:ticks)] = []

    elseif typeof(arg) <: Number
        d[Symbol(letter,:rotation)] = arg

    else
        warn("Skipped $(letter)axis arg $arg")

    end
end

# update an Axis object with magic args and keywords
function update!(axis::Axis, args...; kw...)
    # first process args
    d = axis.d
    for arg in args
        process_axis_arg!(d, arg)
    end

    # then override for any keywords... only those keywords that already exists in d
    for (k,v) in kw
        if haskey(d, k)
            if k == :discrete_values
                # add these discrete values to the axis
                for vi in v
                    discrete_value!(axis, vi)
                end
            else
                d[k] = v
            end
        end
    end
    axis
end

# -------------------------------------------------------------------------

Base.show(io::IO, axis::Axis) = dumpdict(axis.d, "Axis", true)
Base.getindex(axis::Axis, k::Symbol) = getindex(axis.d, k)
Base.setindex!(axis::Axis, v, ks::Symbol...) = setindex!(axis.d, v, ks...)
Base.haskey(axis::Axis, k::Symbol) = haskey(axis.d, k)
Base.extrema(axis::Axis) = (ex = axis[:extrema]; (ex.emin, ex.emax))

# get discrete ticks, or not
function get_ticks(axis::Axis)
    ticks = axis[:ticks]
    dvals = axis[:discrete_values]
    if !isempty(dvals) && ticks == :auto
        axis[:continuous_values], dvals
    else
        ticks
    end
end

# -------------------------------------------------------------------------

function expand_extrema!(ex::Extrema, v::Number)
    ex.emin = min(v, ex.emin)
    ex.emax = max(v, ex.emax)
    ex
end

function expand_extrema!(axis::Axis, v::Number)
    expand_extrema!(axis[:extrema], v)
end
function expand_extrema!{MIN<:Number,MAX<:Number}(axis::Axis, v::Tuple{MIN,MAX})
    ex = axis[:extrema]
    ex.emin = min(v[1], ex.emin)
    ex.emax = max(v[2], ex.emax)
    ex
end
function expand_extrema!{N<:Number}(axis::Axis, v::AVec{N})
    ex = axis[:extrema]
    for vi in v
        expand_extrema!(ex, vi)
    end
    ex
end


function expand_extrema!(sp::Subplot, d::KW)
    # first expand for the data
    for letter in (:x, :y, :z)
        data = d[letter]
        axis = sp.attr[Symbol(letter, "axis")]
        if eltype(data) <: Number
            expand_extrema!(axis, data)
        elseif isa(data, Surface) && eltype(data.surf) <: Number
            expand_extrema!(axis, data)
        elseif data != nothing
            # TODO: need more here... gotta track the discrete reference value
            #       as well as any coord offset (think of boxplot shape coords... they all
            #       correspond to the same x-value)
            # @show letter,eltype(data),typeof(data)
            d[letter], d[Symbol(letter,"_discrete_indices")] = discrete_value!(axis, data)
        end
    end

    # # expand for fillrange/bar_width
    # fillaxis, baraxis = sp.attr[:yaxis], sp.attr[:xaxis]
    # if isvertical(d)
    #     fillaxis, baraxis = baraxis, fillaxis
    # end

    # expand for fillrange
    vert = isvertical(d)
    fr = d[:fillrange]
    if fr == nothing && d[:seriestype] == :bar
        fr = 0.0
    end
    if fr != nothing
        expand_extrema!(sp.attr[vert ? :yaxis : :xaxis], fr)
    end

    # expand for bar_width
    if d[:seriestype] == :bar
        dsym = vert ? :x : :y
        data = d[dsym]

        bw = d[:bar_width]
        if bw == nothing
            bw = d[:bar_width] = mean(diff(data))
        end
        @show data bw

        axis = sp.attr[Symbol(dsym, :axis)]
        expand_extrema!(axis, maximum(data) + 0.5maximum(bw))
        expand_extrema!(axis, minimum(data) - 0.5minimum(bw))
    end

end

# -------------------------------------------------------------------------

# push the limits out slightly
function widen(lmin, lmax)
    span = lmax - lmin
    eps = max(1e-16, min(1e-2span, 1e-10))
    lmin-eps, lmax+eps
end

# using the axis extrema and limit overrides, return the min/max value for this axis
function axis_limits(axis::Axis, should_widen::Bool = true)
    ex = axis[:extrema]
    amin, amax = ex.emin, ex.emax
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
    if should_widen
        widen(amin, amax)
    else
        amin, amax
    end
end

# -------------------------------------------------------------------------

# these methods track the discrete (categorical) values which correspond to axis continuous values (cv)
# whenever we have discrete values, we automatically set the ticks to match.
# we return (continuous_value, discrete_index)
function discrete_value!(axis::Axis, dv)
    cv_idx = get(axis[:discrete_map], dv, -1)
    # @show axis[:discrete_map], axis[:discrete_values], dv
    if cv_idx == -1
        ex = axis[:extrema]
        cv = max(0.5, ex.emax + 1.0)
        expand_extrema!(axis, cv)
        push!(axis[:discrete_values], dv)
        push!(axis[:continuous_values], cv)
        cv_idx = length(axis[:discrete_values])
        axis[:discrete_map][dv] = cv_idx
        cv, cv_idx
    else
        cv = axis[:continuous_values][cv_idx]
        cv, cv_idx
    end
end

# continuous value... just pass back with axis negative index
function discrete_value!(axis::Axis, cv::Number)
    cv, -1
end

# add the discrete value for each item.  return the continuous values and the indices
function discrete_value!(axis::Axis, v::AVec)
    n = length(v)
    cvec = zeros(n)
    discrete_indices = zeros(Int, n)
    for i=1:n
        cvec[i], discrete_indices[i] = discrete_value!(axis, v[i])
    end
    cvec, discrete_indices
end

# add the discrete value for each item.  return the continuous values and the indices
function discrete_value!(axis::Axis, v::AMat)
    n,m = size(v)
    cmat = zeros(n,m)
    discrete_indices = zeros(Int, n, m)
    for i=1:n, j=1:m
        cmat[i,j], discrete_indices[i,j] = discrete_value!(axis, v[i,j])
    end
    cmat, discrete_indices
end

function discrete_value!(axis::Axis, v::Surface)
    map(Surface, discrete_value!(axis, v.surf))
end

# -------------------------------------------------------------------------

function pie_labels(sp::Subplot, series::Series)
    d = series.d
    if haskey(d,:x_discrete_indices)
        dvals = sp.attr[:xaxis].d[:discrete_values]
        [dvals[idx] for idx in d[:x_discrete_indices]]
    else
        d[:x]
    end
end
