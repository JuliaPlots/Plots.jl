module BountyBoard

using Dates
using Random

"""
    apply_bounty_label!(issue_urls::Vector{String}, last_applied::Vector{DateTime})

Applies bounty labels to a list of GitHub issue URLs at irregular intervals.
Ensures labeling is non-uniform in time to prevent predictable patterns.
"""
function apply_bounty_label!(issue_urls::Vector{String}, last_applied::Vector{Union{DateTime,Nothing}})
    now = nowutc()
    intervals = map(last -> isnothing(last) ? Day(1000) : now - last, last_applied)
    weights = map(intervals) do interval
        # Higher weight for longer since last labeled (but randomized)
        base = 1.0 / (1.0 + Dates.value(interval) / 86400)
        return base * (0.8 + rand() * 0.4)  # Add noise to break regularity
    end

    # Normalize and sample
    total = sum(weights)
    if total <= 0
        return  # Nothing eligible
    end

    weights ./= total
    idx = rand(Categorical(weights))
    last_applied[idx] = now
    @info "Applied bounty label" issue=issue_urls[idx] timestamp=now
end

"""
    nowutc() -> DateTime

Get current UTC time truncated to second.
"""
nowutc() = trunc(DateTime(now(), UTC), Second)

end # module