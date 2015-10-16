
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

  Shape,
  PlotText,
  text,
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
  spy,
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


title!(s::@compat(AbstractString); kw...)                 = plot!(; title = s, kw...)
xlabel!(s::@compat(AbstractString); kw...)                = plot!(; xlabel = s, kw...)
ylabel!(s::@compat(AbstractString); kw...)                = plot!(; ylabel = s, kw...)
xlims!{T<:Real,S<:Real}(lims::@compat(Tuple{T,S}); kw...) = plot!(; xlims = lims, kw...)
ylims!{T<:Real,S<:Real}(lims::@compat(Tuple{T,S}); kw...) = plot!(; ylims = lims, kw...)
xlims!(xmin::Real, xmax::Real; kw...)                     = plot!(; xlims = (xmin,xmax), kw...)
ylims!(ymin::Real, ymax::Real; kw...)                     = plot!(; ylims = (ymin,ymax), kw...)
xticks!{T<:Real}(v::AVec{T}; kw...)                       = plot!(; xticks = v, kw...)
yticks!{T<:Real}(v::AVec{T}; kw...)                       = plot!(; yticks = v, kw...)
xticks!{T<:Real,S<:@compat(AbstractString)}(
              ticks::AVec{T}, labels::AVec{S}; kw...)     = plot!(; xticks = (ticks,labels), kw...)
yticks!{T<:Real,S<:@compat(AbstractString)}(
              ticks::AVec{T}, labels::AVec{S}; kw...)     = plot!(; yticks = (ticks,labels), kw...)
annotate!(anns...; kw...)                                 = plot!(; annotation = anns, kw...)
annotate!{T<:Tuple}(anns::AVec{T}; kw...)                 = plot!(; annotation = anns, kw...)
xflip!(flip::Bool = true; kw...)                          = plot!(; xflip = flip, kw...)
yflip!(flip::Bool = true; kw...)                          = plot!(; yflip = flip, kw...)
xaxis!(args...; kw...)                                    = plot!(; xaxis = args, kw...)
yaxis!(args...; kw...)                                    = plot!(; yaxis = args, kw...)

title!(plt::Plot, s::@compat(AbstractString); kw...)                  = plot!(plt; title = s, kw...)
xlabel!(plt::Plot, s::@compat(AbstractString); kw...)                 = plot!(plt; xlabel = s, kw...)
ylabel!(plt::Plot, s::@compat(AbstractString); kw...)                 = plot!(plt; ylabel = s, kw...)
xlims!{T<:Real,S<:Real}(plt::Plot, lims::@compat(Tuple{T,S}); kw...)  = plot!(plt; xlims = lims, kw...)
ylims!{T<:Real,S<:Real}(plt::Plot, lims::@compat(Tuple{T,S}); kw...)  = plot!(plt; ylims = lims, kw...)
xlims!(plt::Plot, xmin::Real, xmax::Real; kw...)                      = plot!(plt; xlims = (xmin,xmax), kw...)
ylims!(plt::Plot, ymin::Real, ymax::Real; kw...)                      = plot!(plt; ylims = (ymin,ymax), kw...)
xticks!{T<:Real}(plt::Plot, ticks::AVec{T}; kw...)                    = plot!(plt; xticks = ticks, kw...)
yticks!{T<:Real}(plt::Plot, ticks::AVec{T}; kw...)                    = plot!(plt; yticks = ticks, kw...)
xticks!{T<:Real,S<:@compat(AbstractString)}(plt::Plot,
                          ticks::AVec{T}, labels::AVec{S}; kw...)     = plot!(plt; xticks = (ticks,labels), kw...)
yticks!{T<:Real,S<:@compat(AbstractString)}(plt::Plot,
                          ticks::AVec{T}, labels::AVec{S}; kw...)     = plot!(plt; yticks = (ticks,labels), kw...)
annotate!(plt::Plot, anns...; kw...)                                  = plot!(plt; annotation = anns, kw...)
annotate!{T<:Tuple}(plt::Plot, anns::AVec{T}; kw...)                  = plot!(plt; annotation = anns, kw...)
xflip!(plt::Plot, flip::Bool = true; kw...)                           = plot!(plt; xflip = flip, kw...)
yflip!(plt::Plot, flip::Bool = true; kw...)                           = plot!(plt; yflip = flip, kw...)
xaxis!(plt::Plot, args...; kw...)                                     = plot!(plt; xaxis = args, kw...)
yaxis!(plt::Plot, args...; kw...)                                     = plot!(plt; yaxis = args, kw...)


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
  # println("[Plots.jl] Default backend: ", CURRENT_BACKEND.sym)

  # # auto init dataframes if the import statement doesn't error out
  # try
  #   @eval import DataFrames
  #   dataframes()
  # end
end

# ---------------------------------------------------------

end # module
