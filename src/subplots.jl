

function Subplot{T<:AbstractBackend}(::T; parent = RootLayout())
    Subplot{T}(
        parent,
        (20mm, 5mm, 2mm, 10mm),
        defaultbox,
        defaultbox,
        KW(),
        nothing,
        nothing
    )
end

plotarea(sp::Subplot) = sp.plotarea
plotarea!(sp::Subplot, bbox::BoundingBox) = (sp.plotarea = bbox)


Base.size(sp::Subplot) = (1,1)
Base.length(sp::Subplot) = 1
Base.getindex(sp::Subplot, r::Int, c::Int) = sp

leftpad(sp::Subplot)   = sp.minpad[1]
toppad(sp::Subplot)    = sp.minpad[2]
rightpad(sp::Subplot)  = sp.minpad[3]
bottompad(sp::Subplot) = sp.minpad[4]

get_subplot(plt::Plot, sp::Subplot) = sp
get_subplot(plt::Plot, i::Integer) = plt.subplots[i]
get_subplot(plt::Plot, k) = plt.spmap[k]
get_subplot(series::Series) = series.d[:subplot]

get_subplot_index(plt::Plot, idx::Integer) = idx
get_subplot_index(plt::Plot, sp::Subplot) = findfirst(_ -> _ === sp, plt.subplots)

# ----------------------------------------------------------------------
