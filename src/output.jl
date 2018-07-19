

defaultOutputFormat(plt::Plot) = "png"

function png(plt::Plot, fn::AbstractString)
  fn = addExtension(fn, "png")
  io = open(fn, "w")
  show(io, MIME("image/png"), plt)
  close(io)
end
png(fn::AbstractString) = png(current(), fn)

function svg(plt::Plot, fn::AbstractString)
  fn = addExtension(fn, "svg")
  io = open(fn, "w")
  show(io, MIME("image/svg+xml"), plt)
  close(io)
end
svg(fn::AbstractString) = svg(current(), fn)


function pdf(plt::Plot, fn::AbstractString)
  fn = addExtension(fn, "pdf")
  io = open(fn, "w")
  show(io, MIME("application/pdf"), plt)
  close(io)
end
pdf(fn::AbstractString) = pdf(current(), fn)


function ps(plt::Plot, fn::AbstractString)
  fn = addExtension(fn, "ps")
  io = open(fn, "w")
  show(io, MIME("application/postscript"), plt)
  close(io)
end
ps(fn::AbstractString) = ps(current(), fn)

function eps(plt::Plot, fn::AbstractString)
  fn = addExtension(fn, "eps")
  io = open(fn, "w")
  show(io, MIME("image/eps"), plt)
  close(io)
end
eps(fn::AbstractString) = eps(current(), fn)

function tex(plt::Plot, fn::AbstractString)
  fn = addExtension(fn, "tex")
  io = open(fn, "w")
  show(io, MIME("application/x-tex"), plt)
  close(io)
end
tex(fn::AbstractString) = tex(current(), fn)

function html(plt::Plot, fn::AbstractString)
    fn = addExtension(fn, "html")
    io = open(fn, "w")
    _use_remote[] = true
    show(io, MIME("text/html"), plt)
    _use_remote[] = false
    close(io)
end
html(fn::AbstractString) = html(current(), fn)


# ----------------------------------------------------------------


const _savemap = Dict(
    "png" => png,
    "svg" => svg,
    "pdf" => pdf,
    "ps"  => ps,
    "eps" => eps,
    "tex" => tex,
    "html" => html,
  )

function getExtension(fn::AbstractString)
  pieces = split(fn, ".")
  length(pieces) > 1 || error("Can't extract file extension: ", fn)
  ext = pieces[end]
  haskey(_savemap, ext) || error("Invalid file extension: ", fn)
  ext
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

"""
    savefig([plot,] filename)

Save a Plot (the current plot if `plot` is not passed) to file. The file
type is inferred from the file extension. All backends support png and pdf
file types, some also support svg, ps, eps, html and tex.
"""
function savefig(plt::Plot, fn::AbstractString)

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
savefig(fn::AbstractString) = savefig(current(), fn)


# ---------------------------------------------------------
"""
    gui([plot])

Display a plot using the backends' gui window
"""
gui(plt::Plot = current()) = display(PlotsDisplay(), plt)

# IJulia only... inline display
function inline(plt::Plot = current())
    isijulia() || error("inline() is IJulia-only")
    Main.IJulia.clear_output(true)
    display(Main.IJulia.InlineDisplay(), plt)
end

function Base.display(::PlotsDisplay, plt::Plot)
    prepare_output(plt)
    _display(plt)
end

# override the REPL display to open a gui window
using REPL
Base.display(::REPL.REPLDisplay, ::MIME"text/plain", plt::Plot) = gui(plt)


_do_plot_show(plt, showval::Bool) = showval && gui(plt)
function _do_plot_show(plt, showval::Symbol)
    showval == :gui && gui(plt)
    showval in (:inline,:ijulia) && inline(plt)
end

# ---------------------------------------------------------

const _best_html_output_type = KW(
    :pyplot => :png,
    :unicodeplots => :txt,
    :glvisualize => :png,
    :plotlyjs => :html,
    :plotly => :html
)

# a backup for html... passes to svg or png depending on the html_output_format arg
function _show(io::IO, ::MIME"text/html", plt::Plot)
    output_type = Symbol(plt.attr[:html_output_format])
    if output_type == :auto
        output_type = get(_best_html_output_type, backend_name(plt.backend), :svg)
    end
    if output_type == :png
        # info("writing png to html output")
        print(io, "<img src=\"data:image/png;base64,", base64encode(show, MIME("image/png"), plt), "\" />")
    elseif output_type == :svg
        # info("writing svg to html output")
        show(io, MIME("image/svg+xml"), plt)
    elseif output_type == :txt
        show(io, MIME("text/plain"), plt)
    else
        error("only png or svg allowed. got: $(repr(output_type))")
    end
end

# delegate mimewritable (showable on julia 0.7) to _show instead
function Base.mimewritable(m::M, plt::P) where {M<:MIME, P<:Plot}
    return hasmethod(_show, Tuple{IO, M, P})
end

function _display(plt::Plot)
    @warn("_display is not defined for this backend.")
end

# for writing to io streams... first prepare, then callback
for mime in ("text/plain", "text/html", "image/png", "image/eps", "image/svg+xml",
             "application/eps", "application/pdf", "application/postscript",
             "application/x-tex")
    @eval function Base.show(io::IO, m::MIME{Symbol($mime)}, plt::Plot)
        prepare_output(plt)
        _show(io, m, plt)
    end
end

# default text/plain for all backends
_show(io::IO, ::MIME{Symbol("text/plain")}, plt::Plot) = show(io, plt)

"Close all open gui windows of the current backend"
closeall() = closeall(backend())


# ---------------------------------------------------------
# A backup, if no PNG generation is defined, is to try to make a PDF and use FileIO to convert

const PDFBackends = Union{PGFPlotsBackend,PlotlyJSBackend,PyPlotBackend,InspectDRBackend,GRBackend}
if is_installed("FileIO")
    @eval import FileIO
    function _show(io::IO, ::MIME"image/png", plt::Plot{<:PDFBackends})
        fn = tempname()

        # first save a pdf file
        pdf(plt, fn)

        # load that pdf into a FileIO Stream
        s = FileIO.load(fn * ".pdf")

        # save a png
        pngfn = fn * ".png"
        FileIO.save(pngfn, s)

        # now write from the file
        write(io, read(open(pngfn), String))
    end
end

# function html_output_format(fmt)
#     if fmt == "png"
#         @eval function Base.show(io::IO, ::MIME"text/html", plt::Plot)
#             print(io, "<img src=\"data:image/png;base64,", base64(show, MIME("image/png"), plt), "\" />")
#         end
#     elseif fmt == "svg"
#         @eval function Base.show(io::IO, ::MIME"text/html", plt::Plot)
#             show(io, MIME("image/svg+xml"), plt)
#         end
#     else
#         error("only png or svg allowed. got: $fmt")
#     end
# end
#
# html_output_format("svg")
