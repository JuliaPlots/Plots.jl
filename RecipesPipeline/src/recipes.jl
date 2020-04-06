# # Default recipes
# Includes stuff from Base/stdlib.
# -------------------------------------------------
# ## Dates & Times

dateformatter(dt) = string(Date(Dates.UTD(dt)))
datetimeformatter(dt) = string(DateTime(Dates.UTM(dt)))
timeformatter(t) = string(Dates.Time(Dates.Nanosecond(t)))

@recipe f(::Type{Date}, dt::Date) = (dt -> Dates.value(dt), dateformatter)
@recipe f(::Type{DateTime}, dt::DateTime) =
    (dt -> Dates.value(dt), datetimeformatter)
@recipe f(::Type{Dates.Time}, t::Dates.Time) = (t -> Dates.value(t), timeformatter)
@recipe f(::Type{P}, t::P) where {P<:Dates.Period} =
    (t -> Dates.value(t), t -> string(P(t)))

# -------------------------------------------------
# ## Characters

@recipe f(::Type{<:AbstractChar}, ::AbstractChar) = (string, string)
