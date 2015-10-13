
if VERSION >= v"0.4-"
  __precompile__()
end

module Plots

using Compat
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

  spy,

  title!,
  xlabel!,
  ylabel!,
  xlims!,
  ylims!,
  xticks!,
  yticks!,
  annotate!,
  xflip!,
  yflip!,
  xaxis!,
  yaxis!,

  savefig,
  png,
  gui,

  backend,
  backends,
  aliases,
  dataframes,
  OHLC,

  colorscheme,
  ColorScheme,
  ColorGradient,
  ColorVector,
  ColorWrapper,
  ColorFunction,
  ColorZFunction,
  getColor,
  getColorZ,

  debugplots,

  supportedArgs,
  supportedAxes,
  supportedTypes,
  supportedStyles,
  supportedMarkers,
  subplotSupported,

  # recipes
  PlotRecipe,
  EllipseRecipe,
  corrplot

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
include("recipes.jl")


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

"Sparsity plot... heatmap of non-zero values of a matrix"
function spy{T<:Real}(y::AMat{T}; kw...)
  I,J,V = findnz(y)
  heatmap(J, I; leg=false, yflip=true, kw...)
end

title!(s::@compat(AbstractString))                 = plot!(title = s)
xlabel!(s::@compat(AbstractString))                = plot!(xlabel = s)
ylabel!(s::@compat(AbstractString))                = plot!(ylabel = s)
xlims!{T<:Real,S<:Real}(lims::@compat(Tuple{T,S})) = plot!(xlims = lims)
ylims!{T<:Real,S<:Real}(lims::@compat(Tuple{T,S})) = plot!(ylims = lims)
xlims!(xmin::Real, xmax::Real)            = plot!(xlims = (xmin,xmax))
ylims!(ymin::Real, ymax::Real)            = plot!(ylims = (ymin,ymax))
xticks!{T<:Real}(v::AVec{T})              = plot!(xticks = v)
yticks!{T<:Real}(v::AVec{T})              = plot!(yticks = v)
xticks!{T<:Real,S<:@compat(AbstractString)}(ticks::AVec{T}, labels::AVec{S})  = plot!(xticks = (ticks,labels))
yticks!{T<:Real,S<:@compat(AbstractString)}(ticks::AVec{T}, labels::AVec{S})  = plot!(yticks = (ticks,labels))
annotate!(anns)                           = plot!(annotation = anns)
xflip!(flip::Bool = true)                 = plot!(xflip = flip)
yflip!(flip::Bool = true)                 = plot!(yflip = flip)
xaxis!(args...)                           = plot!(xaxis = args)
yaxis!(args...)                           = plot!(yaxis = args)

title!(plt::Plot, s::@compat(AbstractString))                  = plot!(plt; title = s)
xlabel!(plt::Plot, s::@compat(AbstractString))                 = plot!(plt; xlabel = s)
ylabel!(plt::Plot, s::@compat(AbstractString))                 = plot!(plt; ylabel = s)
xlims!{T<:Real,S<:Real}(plt::Plot, lims::@compat(Tuple{T,S}))  = plot!(plt; xlims = lims)
ylims!{T<:Real,S<:Real}(plt::Plot, lims::@compat(Tuple{T,S}))  = plot!(plt; ylims = lims)
xlims!(plt::Plot, xmin::Real, xmax::Real)             = plot!(plt; xlims = (xmin,xmax))
ylims!(plt::Plot, ymin::Real, ymax::Real)             = plot!(plt; ylims = (ymin,ymax))
xticks!{T<:Real}(plt::Plot, ticks::AVec{T})           = plot!(plt; xticks = ticks)
yticks!{T<:Real}(plt::Plot, ticks::AVec{T})           = plot!(plt; yticks = ticks)
xticks!{T<:Real,S<:@compat(AbstractString)}(plt::Plot, ticks::AVec{T}, labels::AVec{S})  = plot!(plt; xticks = (ticks,labels))
yticks!{T<:Real,S<:@compat(AbstractString)}(plt::Plot, ticks::AVec{T}, labels::AVec{S})  = plot!(plt; yticks = (ticks,labels))
annotate!(plt::Plot, anns)                            = plot!(plt; annotation = anns)
xflip!(plt::Plot, flip::Bool = true)                  = plot!(plt; xflip = flip)
yflip!(plt::Plot, flip::Bool = true)                  = plot!(plt; yflip = flip)
xaxis!(plt::Plot, args...)                            = plot!(plt; xaxis = args)
yaxis!(plt::Plot, args...)                            = plot!(plt; yaxis = args)


# ---------------------------------------------------------


defaultOutputFormat(plt::PlottingObject) = "png"

function png(plt::PlottingObject, fn::@compat(AbstractString))
  fn = addExtension(fn, "png")
  io = open(fn, "w")
  writemime(io, MIME("image/png"), plt)
  close(io)
end
png(fn::@compat(AbstractString)) = png(current(), fn)


@compat const _savemap = Dict(
    "png" => png,
  )

function getExtension(fn::@compat(AbstractString))
  pieces = split(fn, ".")
  length(pieces) > 1 || error("Can't extract file extension: ", fn)
  ext = pieces[end]
  haskey(_savemap, ext) || error("Invalid file extension: ", fn)
  ext
end

function addExtension(fn::@compat(AbstractString), ext::@compat(AbstractString))
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

function savefig(plt::PlottingObject, fn::@compat(AbstractString))
  
  # get the extension
  local ext
  try
    ext = getExtension(fn)
  catch
    # if we couldn't extract the extension, add the default
    ext = defaultOutputFormat(plt)
    fn = addExtension(fn, ext)
  end

  # save it
  func = get(_savemap, ext) do
    error("Unsupported extension $ext with filename ", fn)
  end
  func(plt, fn)
end
savefig(fn::@compat(AbstractString)) = savefig(current(), fn)


# savepng(args...; kw...) = savepng(current(), args...; kw...)
# savepng(plt::PlottingObject, fn::@compat(AbstractString); kw...) = (io = open(fn, "w"); writemime(io, MIME("image/png"), plt); close(io))




# ---------------------------------------------------------

gui(plt::PlottingObject = current()) = display(PlotsDisplay(), plt)


# override the REPL display to open a gui window
Base.display(::Base.REPL.REPLDisplay, ::MIME"text/plain", plt::PlottingObject) = gui(plt)

# ---------------------------------------------------------


try
  import DataFrames
  dataframes()
end

# const CURRENT_BACKEND = pickDefaultBackend()

# for be in backends()
#   try
#     backend(be)
#     backend()
#   catch err
#     @show err
#   end
# end


function __init__()
  global const CURRENT_BACKEND = pickDefaultBackend()
  # global CURRENT_BACKEND
  println("[Plots.jl] Default backend: ", CURRENT_BACKEND.sym)

  # # auto init dataframes if the import statement doesn't error out
  # try
  #   @eval import DataFrames
  #   dataframes()
  # end
end

# ---------------------------------------------------------

end # module
