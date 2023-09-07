module Ticks

export get_ticks, _has_ticks, _transform_ticks, get_minor_ticks
using Plots.Commons
using Plots.Dates


const DEFAULT_MINOR_INTERVALS = Ref(5)  # 5 intervals -> 4 ticks

# get_ticks from axis symbol :x, :y, or :z


get_ticks(ticks::NTuple{2,Any}, args...) = ticks
get_ticks(::Nothing, cvals::T, args...) where {T} = T[], String[]
get_ticks(ticks::Bool, args...) =
    ticks ? get_ticks(:auto, args...) : get_ticks(nothing, args...)
get_ticks(::T, args...) where {T} =
    throw(ArgumentError("Unknown ticks type in get_ticks: $T"))

# do not specify array item type to also catch e.g. "xlabel=[]" and "xlabel=([],[])"
_has_ticks(v::AVec) = !isempty(v)
_has_ticks(t::Tuple{AVec,AVec}) = !isempty(t[1])
_has_ticks(s::Symbol) = s !== :none
_has_ticks(b::Bool) = b
_has_ticks(::Nothing) = false
_has_ticks(::Any) = true

_transform_ticks(ticks, axis) = ticks
_transform_ticks(ticks::AbstractArray{T}, axis) where {T<:Dates.TimeType} =
    Dates.value.(ticks)
_transform_ticks(ticks::NTuple{2,Any}, axis) = (_transform_ticks(ticks[1], axis), ticks[2])


function num_minor_intervals(axis)
    # FIXME: `minorticks` should be fixed in `2.0` to be the number of ticks, not intervals
    # see github.com/JuliaPlots/Plots.jl/pull/4528
    n_intervals = axis[:minorticks]
    if !(n_intervals isa Bool) && n_intervals isa Integer && n_intervals ≥ 0
        max(1, n_intervals)  # 0 intervals makes no sense
    else   # `:auto` or `true`
        if (base = get(_logScaleBases, axis[:scale], nothing)) == 10
            Int(base - 1)
        else
            DEFAULT_MINOR_INTERVALS[]
        end
    end::Int
end

no_minor_intervals(axis) =
    if (n_intervals = axis[:minorticks]) === false
        true  # must be tested with `===` since Bool <: Integer
    elseif n_intervals ∈ (:none, nothing)
        true
    elseif (n_intervals === :auto && !axis[:minorgrid])
        true
    else
        false
    end

function get_minor_ticks(sp, axis, ticks_and_labels)
    no_minor_intervals(axis) && return
    ticks = first(ticks_and_labels)
    length(ticks) < 2 && return

    amin, amax = axis_limits(sp, axis[:letter])
    scale = axis[:scale]
    base = get(_logScaleBases, scale, nothing)

    # add one phantom tick either side of the ticks to ensure minor ticks extend to the axis limits
    if (log_scaled = scale ∈ _logScales)
        sub = round(Int, log(base, ticks[2] / ticks[1]))
        ticks = [ticks[1] / base; ticks; ticks[end] * base]
    else
        sub = 1  # unused
        ratio = length(ticks) > 2 ? (ticks[3] - ticks[2]) / (ticks[2] - ticks[1]) : 1
        first_step = ticks[2] - ticks[1]
        last_step = ticks[end] - ticks[end - 1]
        ticks = [ticks[1] - first_step / ratio; ticks; ticks[end] + last_step * ratio]
    end

    n_minor_intervals = num_minor_intervals(axis)
    minorticks = sizehint!(eltype(ticks)[], n_minor_intervals * sub * length(ticks))
    for i in 2:length(ticks)
        lo = ticks[i - 1]
        hi = ticks[i]
        (isfinite(lo) && isfinite(hi) && hi > lo) || continue
        if log_scaled
            for e in 1:sub
                lo_ = lo * base^(e - 1)
                hi_ = lo_ * base
                step = (hi_ - lo_) / n_minor_intervals
                rng = (lo_ + (e > 1 ? 0 : step)):step:(hi_ - (e < sub ? 0 : step / 2))
                append!(minorticks, collect(rng))
            end
        else
            step = (hi - lo) / n_minor_intervals
            append!(minorticks, collect((lo + step):step:(hi - step / 2)))
        end
    end
    minorticks[amin .≤ minorticks .≤ amax]
end

end # Ticks
