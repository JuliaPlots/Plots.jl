

function Subplot{T<:AbstractBackend}(::T; parent = RootLayout())
    Subplot{T}(parent, defaultbox, defaultbox, KW(), nothing, nothing)
end

plotarea!(sp::Subplot, bbox::BoundingBox) = (sp.plotarea = bbox)


Base.size(sp::Subplot) = (1,1)
Base.length(sp::Subplot) = 1
Base.getindex(sp::Subplot, r::Int, c::Int) = sp


get_subplot(plt::Plot, sp::Subplot) = sp
get_subplot(plt::Plot, i::Integer) = plt.subplots[i]
get_subplot(plt::Plot, k) = plt.spmap[k]
get_subplot(series::Series) = series.d[:subplot]

get_subplot_index(plt::Plot, idx::Integer) = idx
get_subplot_index(plt::Plot, sp::Subplot) = findfirst(_ -> _ === sp, plt.subplots)

# ----------------------------------------------------------------------
