module Commons

export AVec, AMat, KW, AKW, TicksArgs
export PLOTS_SEED, PX_PER_INCH, DPI, MM_PER_INCH, MM_PER_PX
export _haligns, _valigns
# Functions
export get_subplot, coords, ispolar, _update_axis, expand_extrema!, series_list

const AVec = AbstractVector
const AMat = AbstractMatrix
const KW = Dict{Symbol,Any}
const AKW = AbstractDict{Symbol,Any}
const TicksArgs =
    Union{AVec{T},Tuple{AVec{T},AVec{S}},Symbol} where {T<:Real,S<:AbstractString}
const PLOTS_SEED  = 1234
const PX_PER_INCH = 100
const DPI         = PX_PER_INCH
const MM_PER_INCH = 25.4
const MM_PER_PX   = MM_PER_INCH / PX_PER_INCH
const _haligns = :hcenter, :left, :right
const _valigns = :vcenter, :top, :bottom

function get_subplot end
function series_list end
function coords end
function ispolar end
function _update_axis end
function expand_extrema! end
end
