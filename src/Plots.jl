__precompile__()

module Plots

using Reexport
@reexport using Colors

export
  plot,
  plot!,
  # plot_display,
  # plot_display!,
  subplot,
  subplot!,

  current,
  default,
  
  scatter,
  scatter!,
  bar,
  bar!,
  histogram,
  histogram!,
  heatmap,
  heatmap!,
  sticks,
  sticks!,
  hline,
  hline!,
  vline,
  vline!,
  ohlc,
  ohlc!,

  title!,
  xlabel!,
  ylabel!,
  xlims!,
  ylims!,
  xticks!,
  yticks!,
  annotate!,

  savefig,
  png,
  gui,

  backend,
  backends,
  aliases,
  dataframes,
  OHLC,

  supportedArgs,
  supportedAxes,
  supportedTypes,
  supportedStyles,
  supportedMarkers,
  subplotSupported

# ---------------------------------------------------------


const IMG_DIR = Pkg.dir("Plots") * "/img/"


# ---------------------------------------------------------

include("types.jl")
include("utils.jl")
include("colors.jl")
include("plotter.jl")
include("args.jl")
include("plot.jl")
include("subplot.jl")


# ---------------------------------------------------------

scatter(args...; kw...)    = plot(args...; kw...,  linetype = :scatter)
scatter!(args...; kw...)   = plot!(args...; kw..., linetype = :scatter)
bar(args...; kw...)        = plot(args...; kw...,  linetype = :bar)
bar!(args...; kw...)       = plot!(args...; kw..., linetype = :bar)
histogram(args...; kw...)  = plot(args...; kw...,  linetype = :hist)
histogram!(args...; kw...) = plot!(args...; kw..., linetype = :hist)
heatmap(args...; kw...)    = plot(args...; kw...,  linetype = :heatmap)
heatmap!(args...; kw...)   = plot!(args...; kw..., linetype = :heatmap)
sticks(args...; kw...)     = plot(args...; kw...,  linetype = :sticks, marker = :ellipse)
sticks!(args...; kw...)    = plot!(args...; kw..., linetype = :sticks, marker = :ellipse)
hline(args...; kw...)      = plot(args...; kw...,  linetype = :hline)
hline!(args...; kw...)     = plot!(args...; kw..., linetype = :hline)
vline(args...; kw...)      = plot(args...; kw...,  linetype = :vline)
vline!(args...; kw...)     = plot!(args...; kw..., linetype = :vline)
ohlc(args...; kw...)       = plot(args...; kw...,  linetype = :ohlc)
ohlc!(args...; kw...)      = plot!(args...; kw..., linetype = :ohlc)


title!(s::AbstractString)                 = plot!(title = s)
xlabel!(s::AbstractString)                = plot!(xlabel = s)
ylabel!(s::AbstractString)                = plot!(ylabel = s)
xlims!{T<:Real,S<:Real}(lims::Tuple{T,S}) = plot!(xlims = lims)
ylims!{T<:Real,S<:Real}(lims::Tuple{T,S}) = plot!(ylims = lims)
xticks!{T<:Real}(v::AVec{T})              = plot!(xticks = v)
yticks!{T<:Real}(v::AVec{T})              = plot!(yticks = v)
xticks!{T<:Real,S<:AbstractString}(ticks::AVec{T}, labels::AVec{S})  = plot!(xticks = (ticks,labels))
yticks!{T<:Real,S<:AbstractString}(ticks::AVec{T}, labels::AVec{S})  = plot!(yticks = (ticks,labels))
annotate!(anns)                           = plot!(annotation = anns)

title!(plt::Plot, s::AbstractString)                  = plot!(plt; title = s)
xlabel!(plt::Plot, s::AbstractString)                 = plot!(plt; xlabel = s)
ylabel!(plt::Plot, s::AbstractString)                 = plot!(plt; ylabel = s)
xlims!{T<:Real,S<:Real}(plt::Plot, lims::Tuple{T,S})  = plot!(plt; xlims = lims)
ylims!{T<:Real,S<:Real}(plt::Plot, lims::Tuple{T,S})  = plot!(plt; ylims = lims)
xticks!{T<:Real}(plt::Plot, ticks::AVec{T})           = plot!(plt; xticks = ticks)
yticks!{T<:Real}(plt::Plot, ticks::AVec{T})           = plot!(plt; yticks = ticks)
xticks!{T<:Real,S<:AbstractString}(plt::Plot, ticks::AVec{T}, labels::AVec{S})  = plot!(plt; xticks = (ticks,labels))
yticks!{T<:Real,S<:AbstractString}(plt::Plot, ticks::AVec{T}, labels::AVec{S})  = plot!(plt; yticks = (ticks,labels))
annotate!(plt::Plot, anns)                            = plot!(plt; annotation = anns)


# ---------------------------------------------------------

function getExtension(fn::AbstractString)
  pieces = split(fn, ".")
  if length(pieces) < 2
    error("Can't extract file extension: ", fn)
  end
  pieces[end]
end

function addExtension(fn::AbstractString, ext::AbstractString)
  try
    oldext = getExtension(fn)
    if oldext == ext
      return fn
    else
      return "$fn.$ext"
    end
  catch
    return "$fn.$ext"
  end
end


function png(plt::PlottingObject, fn::AbstractString)
  fn = addExtension(fn, "png")
  io = open(fn, "w")
  writemime(io, MIME("image/png"), plt)
  close(io)
end
png(fn::AbstractString) = png(current(), fn)


const _savemap = Dict(
    "png" => png,
  )

function savefig(plt::PlottingObject, fn::AbstractString)
  ext = getExtension(fn)
  func = get(_savemap, ext) do
    error("Unsupported extension $ext with filename ", fn)
  end
  func(plt, fn)
end
savefig(fn::AbstractString) = savefig(current(), fn)


# savepng(args...; kw...) = savepng(current(), args...; kw...)
# savepng(plt::PlottingObject, fn::AbstractString; kw...) = (io = open(fn, "w"); writemime(io, MIME("image/png"), plt); close(io))




# ---------------------------------------------------------

gui(plt::PlottingObject = current()) = display(PlotsDisplay(), plt)


# override the REPL display to open a gui window
Base.display(::Base.REPL.REPLDisplay, ::MIME"text/plain", plt::PlottingObject) = gui(plt)

# ---------------------------------------------------------


function __init__()
  global const CURRENT_BACKEND = pickDefaultBackend()
  println("[Plots.jl] Default backend: ", CURRENT_BACKEND.sym)
end

# ---------------------------------------------------------

end # module
