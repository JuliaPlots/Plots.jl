

defaultOutputFormat(plt::Plot) = "png"

function png(plt::Plot, fn::AbstractString)
  fn = addExtension(fn, "png")
  io = open(fn, "w")
  writemime(io, MIME("image/png"), plt)
  close(io)
end
png(fn::AbstractString) = png(current(), fn)

function svg(plt::Plot, fn::AbstractString)
  fn = addExtension(fn, "svg")
  io = open(fn, "w")
  writemime(io, MIME("image/svg+xml"), plt)
  close(io)
end
svg(fn::AbstractString) = svg(current(), fn)


function pdf(plt::Plot, fn::AbstractString)
  fn = addExtension(fn, "pdf")
  io = open(fn, "w")
  writemime(io, MIME("application/pdf"), plt)
  close(io)
end
pdf(fn::AbstractString) = pdf(current(), fn)


function ps(plt::Plot, fn::AbstractString)
  fn = addExtension(fn, "ps")
  io = open(fn, "w")
  writemime(io, MIME("application/postscript"), plt)
  close(io)
end
ps(fn::AbstractString) = ps(current(), fn)


function tex(plt::Plot, fn::AbstractString)
  fn = addExtension(fn, "tex")
  io = open(fn, "w")
  writemime(io, MIME("application/x-tex"), plt)
  close(io)
end
tex(fn::AbstractString) = tex(current(), fn)


# ----------------------------------------------------------------


@compat const _savemap = Dict(
    "png" => png,
    "svg" => svg,
    "pdf" => pdf,
    "ps"  => ps,
    "tex" => tex,
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

gui(plt::Plot = current()) = display(PlotsDisplay(), plt)

function Base.display(::PlotsDisplay, plt::Plot)
    prepare_output(plt)
    _display(plt)
end

# override the REPL display to open a gui window
Base.display(::Base.REPL.REPLDisplay, ::MIME"text/plain", plt::Plot) = gui(plt)

# ---------------------------------------------------------

const _mimeformats = Dict(
    "application/eps"         => "eps",
    "image/eps"               => "eps",
    "application/pdf"         => "pdf",
    "image/png"               => "png",
    "application/postscript"  => "ps",
    "image/svg+xml"           => "svg",
    "text/plain"              => "txt",
)

const _best_html_output_type = KW(
    :pyplot => :png,
    :unicodeplots => :txt,
)

# a backup for html... passes to svg or png depending on the html_output_format arg
function Base.writemime(io::IO, ::MIME"text/html", plt::Plot)
    output_type = Symbol(plt.attr[:html_output_format])
    if output_type == :auto
        output_type = get(_best_html_output_type, backend_name(plt.backend), :svg)
    end
    if output_type == :png
        # info("writing png to html output")
        print(io, "<img src=\"data:image/png;base64,", base64encode(writemime, MIME("image/png"), plt), "\" />")
    elseif output_type == :svg
        # info("writing svg to html output")
        writemime(io, MIME("image/svg+xml"), plt)
    elseif output_type == :txt
        writemime(io, MIME("text/plain"), plt)
    else
        error("only png or svg allowed. got: $output_type")
    end
end

# for writing to io streams... first prepare, then callback
for mime in keys(_mimeformats)
    @eval function _writemime(io::IO, m, plt::Plot)
        warn("_writemime is not defined for this backend. m=", string(m))
    end
    @eval function _display(plt::Plot)
        warn("_display is not defined for this backend.")
    end
    @eval function Base.writemime(io::IO, m::MIME{Symbol($mime)}, plt::Plot)
        prepare_output(plt)
        _writemime(io, m, plt)
    end
end


# ---------------------------------------------------------
# A backup, if no PNG generation is defined, is to try to make a PDF and use FileIO to convert

if is_installed("FileIO")
    @eval begin
        import FileIO
        function _writemime(io::IO, ::MIME"image/png", plt::Plot)
            fn = tempname()

            # first save a pdf file
            pdf(plt, fn)

            # load that pdf into a FileIO Stream
            s = FileIO.load(fn * ".pdf")

            # save a png
            pngfn = fn * ".png"
            FileIO.save(pngfn, s)

            # now write from the file
            write(io, readall(open(pngfn)))
        end
    end
end





# function html_output_format(fmt)
#     if fmt == "png"
#         @eval function Base.writemime(io::IO, ::MIME"text/html", plt::Plot)
#             print(io, "<img src=\"data:image/png;base64,", base64(writemime, MIME("image/png"), plt), "\" />")
#         end
#     elseif fmt == "svg"
#         @eval function Base.writemime(io::IO, ::MIME"text/html", plt::Plot)
#             writemime(io, MIME("image/svg+xml"), plt)
#         end
#     else
#         error("only png or svg allowed. got: $fmt")
#     end
# end
#
# html_output_format("svg")

# ---------------------------------------------------------
# IJulia
# ---------------------------------------------------------

const _ijulia_output = Compat.ASCIIString["text/html"]

function setup_ijulia()
    # override IJulia inline display
    if isijulia()
        @eval begin
            import IJulia
            export set_ijulia_output
            function set_ijulia_output(mimestr::AbstractString)
                # info("Setting IJulia output format to $mimestr")
                global _ijulia_output
                _ijulia_output[1] = mimestr
            end
            function IJulia.display_dict(plt::Plot)
                global _ijulia_output
                Dict{Compat.ASCIIString, ByteString}(_ijulia_output[1] => sprint(writemime, _ijulia_output[1], plt))
            end

            # default text/plain passes to html... handles Interact issues
            function Base.writemime(io::IO, m::MIME"text/plain", plt::Plot)
                writemime(io, MIME("text/html"), plt)
            end
        end
        set_ijulia_output("text/html")
    end
end

# ---------------------------------------------------------
# Atom PlotPane
# ---------------------------------------------------------

function setup_atom()
    # @require Atom begin
    if isatom() && get(ENV, "PLOTS_USE_ATOM_PLOTPANE", false) in (true, 1, "1", "true", "yes")
        # @eval import Atom, Media
        @eval import Atom

        # connects the render function
        for T in (GadflyBackend,ImmerseBackend,PyPlotBackend,GRBackend)
            Atom.Media.media(Plot{T}, Atom.Media.Plot)
        end
        # Atom.Media.media{T <: Union{GadflyBackend,ImmerseBackend,PyPlotBackend,GRBackend}}(Plot{T}, Atom.Media.Plot)

        # Atom.displaysize(::Plot) = (535, 379)
        # Atom.displaytitle(plt::Plot) = "Plots.jl (backend: $(backend(plt)))"

        # this is like "display"... sends an html div with the plot to the PlotPane
        function Atom.Media.render(pane::Atom.PlotPane, plt::Plot)
            Atom.Media.render(pane, Atom.div(Atom.d(), Atom.HTML(stringmime(MIME("text/html"), plt))))
        end


        # function Atom.Media.render(pane::Atom.PlotPane, plt::Plot{PlotlyBackend})
        #     html = Media.render(pane, Atom.div(Atom.d(), Atom.HTML(stringmime(MIME("text/html"), plt))))
        # end
    end
end
