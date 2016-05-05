

defaultOutputFormat(plt::AbstractPlot) = "png"

function png(plt::AbstractPlot, fn::@compat(AbstractString))
  fn = addExtension(fn, "png")
  io = open(fn, "w")
  writemime(io, MIME("image/png"), plt)
  close(io)
end
png(fn::@compat(AbstractString)) = png(current(), fn)

function svg(plt::AbstractPlot, fn::@compat(AbstractString))
  fn = addExtension(fn, "svg")
  io = open(fn, "w")
  writemime(io, MIME("image/svg+xml"), plt)
  close(io)
end
svg(fn::@compat(AbstractString)) = svg(current(), fn)


function pdf(plt::AbstractPlot, fn::@compat(AbstractString))
  fn = addExtension(fn, "pdf")
  io = open(fn, "w")
  writemime(io, MIME("application/pdf"), plt)
  close(io)
end
pdf(fn::@compat(AbstractString)) = pdf(current(), fn)


function ps(plt::AbstractPlot, fn::@compat(AbstractString))
  fn = addExtension(fn, "ps")
  io = open(fn, "w")
  writemime(io, MIME("application/postscript"), plt)
  close(io)
end
ps(fn::@compat(AbstractString)) = ps(current(), fn)


function tex(plt::AbstractPlot, fn::@compat(AbstractString))
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

function savefig(plt::AbstractPlot, fn::@compat(AbstractString))

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


# ---------------------------------------------------------

gui(plt::AbstractPlot = current()) = display(PlotsDisplay(), plt)


# override the REPL display to open a gui window
Base.display(::Base.REPL.REPLDisplay, ::MIME"text/plain", plt::AbstractPlot) = gui(plt)

# a backup for html... passes to svg
function Base.writemime(io::IO, ::MIME"text/html", plt::AbstractPlot)
    writemime(io, MIME("image/svg+xml"), plt)
end

# ---------------------------------------------------------
# IJulia
# ---------------------------------------------------------

const _ijulia_output = ASCIIString["text/html"]

function setup_ijulia()
    # override IJulia inline display
    if isijulia()
        @eval begin
            import IJulia
            export set_ijulia_output
            function set_ijulia_output(mimestr::ASCIIString)
                # info("Setting IJulia output format to $mimestr")
                global _ijulia_output
                _ijulia_output[1] = mimestr
            end
            function IJulia.display_dict(plt::AbstractPlot)
                global _ijulia_output
                Dict{ASCIIString, ByteString}(_ijulia_output[1] => sprint(writemime, _ijulia_output[1], plt))
            end
        end

        # IJulia.display_dict(plt::AbstractPlot) = Dict{ASCIIString, ByteString}("text/html" => sprint(writemime, "text/html", plt))
        set_ijulia_output("text/html")
    end
end

# ---------------------------------------------------------
# Atom PlotPane
# ---------------------------------------------------------

function setup_atom()
    # @require Atom begin
    if isatom()
        # @eval import Atom, Media
        @eval import Atom

        # connects the render function
        for T in (GadflyBackend,ImmerseBackend,PyPlotBackend,GRBackend)
            Atom.Media.media(AbstractPlot{T}, Atom.Media.Plot)
        end
        # Atom.Media.media{T <: Union{GadflyBackend,ImmerseBackend,PyPlotBackend,GRBackend}}(Plot{T}, Atom.Media.Plot)

        # Atom.displaysize(::AbstractPlot) = (535, 379)
        # Atom.displaytitle(plt::AbstractPlot) = "Plots.jl (backend: $(backend(plt)))"

        # this is like "display"... sends an html div with the plot to the PlotPane
        function Atom.Media.render(pane::Atom.PlotPane, plt::AbstractPlot)
            Atom.Media.render(pane, Atom.div(Atom.d(), Atom.HTML(stringmime(MIME("text/html"), plt))))
        end


        # function Atom.Media.render(pane::Atom.PlotPane, plt::Plot{PlotlyBackend})
        #     html = Media.render(pane, Atom.div(Atom.d(), Atom.HTML(stringmime(MIME("text/html"), plt))))
        # end
    end
end
