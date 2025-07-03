# # Default recipes
# Includes stuff from Base/stdlib.
# -------------------------------------------------
# ## Dates & Times

function epochdays2datetime(fractionaldays::Real)::DateTime
    days = floor(fractionaldays)
    dayfraction = fractionaldays - days
    missing_ms = Millisecond(round(Millisecond(Day(1)).value * dayfraction))
    return DateTime(Dates.epochdays2date(days)) + missing_ms
end

epochdays2epochms(x) = Dates.datetime2epochms(epochdays2datetime(x))

dateformatter(dt::Integer) = string(Date(Dates.UTD(dt)))

dateformatter(dt::Real) = string(DateTime(Dates.UTM(epochdays2epochms(dt))))

datetimeformatter(dt) = string(DateTime(Dates.UTM(round(dt))))
timeformatter(t) = string(Dates.Time(Dates.Nanosecond(round(t))))

@recipe f(::Type{Date}, dt::Date) = (dt -> Dates.value(dt), dateformatter)
@recipe f(::Type{DateTime}, dt::DateTime) = (dt -> Dates.value(dt), datetimeformatter)
@recipe f(::Type{Dates.Time}, t::Dates.Time) = (t -> Dates.value(t), timeformatter)
@recipe f(::Type{P}, t::P) where {P <: Dates.Period} =
    (t -> Dates.value(t), t -> string(P(round(t))))

# -------------------------------------------------
# ## Characters

@recipe f(::Type{<:AbstractChar}, ::AbstractChar) = (string, string)
