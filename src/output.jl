

defaultOutputFormat(plt::PlottingObject) = "png"

function png(plt::PlottingObject, fn::@compat(AbstractString))
  fn = addExtension(fn, "png")
  io = open(fn, "w")
  writemime(io, MIME("image/png"), plt)
  close(io)
end
png(fn::@compat(AbstractString)) = png(current(), fn)

function svg(plt::PlottingObject, fn::@compat(AbstractString))
  fn = addExtension(fn, "svg")
  io = open(fn, "w")
  writemime(io, MIME("image/svg+xml"), plt)
  close(io)
end
svg(fn::@compat(AbstractString)) = svg(current(), fn)


function pdf(plt::PlottingObject, fn::@compat(AbstractString))
  fn = addExtension(fn, "pdf")
  io = open(fn, "w")
  writemime(io, MIME("application/pdf"), plt)
  close(io)
end
pdf(fn::@compat(AbstractString)) = pdf(current(), fn)


function ps(plt::PlottingObject, fn::@compat(AbstractString))
  fn = addExtension(fn, "ps")
  io = open(fn, "w")
  writemime(io, MIME("application/postscript"), plt)
  close(io)
end
ps(fn::@compat(AbstractString)) = ps(current(), fn)


function tex(plt::PlottingObject, fn::@compat(AbstractString))
  fn = addExtension(fn, "tex")
  io = open(fn, "w")
  writemime(io, MIME("application/x-tex"), plt)
  close(io)
end
tex(fn::@compat(AbstractString)) = tex(current(), fn)


# ----------------------------------------------------------------


@compat const _savemap = Dict(
    "png" => png,
    "svg" => svg,
    "pdf" => pdf,
    "ps"  => ps,
    "tex" => tex,
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
