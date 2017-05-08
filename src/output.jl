

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
  writemime(io, MIME("image/eps"), plt)
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

function Base.tempname()
    tempfile_limit = UInt32(30)
    global tempname_counter = if isdefined(Plots, :tempname_counter)
        tempname_counter + UInt32(1)
    else
        UInt32(1)
    end
    return tempname(tempname_counter % tempfile_limit)
end
# ---------------------------------------------------------

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
Base.display(::Base.REPL.REPLDisplay, ::MIME"text/plain", plt::Plot) = gui(plt)


_do_plot_show(plt, showval::Bool) = showval && gui(plt)
function _do_plot_show(plt, showval::Symbol)
    showval == :gui && gui(plt)
    showval in (:inline,:ijulia) && inline(plt)
end

# ---------------------------------------------------------

const _mimeformats = Dict(
    "application/eps"         => "eps",
    "image/eps"               => "eps",
    "application/pdf"         => "pdf",
    "image/png"               => "png",
    "application/postscript"  => "ps",
    "image/svg+xml"           => "svg",
    "text/plain"              => "txt",
    "application/x-tex"       => "tex",
)

const _best_html_output_type = KW(
    :pyplot => :png,
    :unicodeplots => :txt,
    :glvisualize => :png
)

# a backup for html... passes to svg or png depending on the html_output_format arg
function Base.show(io::IO, ::MIME"text/html", plt::Plot)
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
        error("only png or svg allowed. got: $output_type")
    end
end

function _show{B}(io::IO, m, plt::Plot{B})
    # Base.show_backtrace(STDOUT, backtrace())
    warn("_show is not defined for this backend. m=", string(m))
end
function _display(plt::Plot)
    warn("_display is not defined for this backend.")
end

# for writing to io streams... first prepare, then callback
for mime in keys(_mimeformats)
    @eval function Base.show{B}(io::IO, m::MIME{Symbol($mime)}, plt::Plot{B})
        prepare_output(plt)
        _show(io, m, plt)
    end
end

closeall() = closeall(backend())


# ---------------------------------------------------------
# A backup, if no PNG generation is defined, is to try to make a PDF and use FileIO to convert

if is_installed("FileIO")
    @eval import FileIO
    function _show(io::IO, ::MIME"image/png", plt::Plot)
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

# ---------------------------------------------------------
# IJulia
# ---------------------------------------------------------

const _ijulia_output = String["text/html"]

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
                Dict{String, String}(_ijulia_output[1] => sprint(show, _ijulia_output[1], plt))
            end

            # default text/plain passes to html... handles Interact issues
            function Base.show(io::IO, m::MIME"text/plain", plt::Plot)
                show(io, MIME("text/html"), plt)
            end
        end
        set_ijulia_output("text/html")
    end
end

# ---------------------------------------------------------
# Atom PlotPane
# ---------------------------------------------------------

function setup_atom()
    if isatom()
        @eval import Atom, Media
        Media.media(Plot, Media.Plot)

        # default text/plain so it doesn't complain
        function Base.show{B}(io::IO, ::MIME"text/plain", plt::Plot{B})
            print(io, "Plot{$B}()")
        end

        function Media.render(e::Atom.Editor, plt::Plot)
            Media.render(e, nothing)
        end

        if get(ENV, "PLOTS_USE_ATOM_PLOTPANE", true) in (true, 1, "1", "true", "yes")
            # this is like "display"... sends an html div with the plot to the PlotPane
            function Media.render(pane::Atom.PlotPane, plt::Plot)
                # temporarily overwrite size to be Atom.plotsize
                sz = plt[:size]
                plt[:size] = Juno.plotsize()
                Media.render(pane, Atom.div(".fill", Atom.HTML(stringmime(MIME("text/html"), plt))))
                plt[:size] = sz
            end
            # special handling for PlotlyJS
            function Media.render(pane::Atom.PlotPane, plt::Plot{PlotlyJSBackend})
                display(Plots.PlotsDisplay(), plt)
            end
        else
            #
            function Media.render(pane::Atom.PlotPane, plt::Plot)
                display(Plots.PlotsDisplay(), plt)
                s = "PlotPane turned off.  Unset ENV[\"PLOTS_USE_ATOM_PLOTPANE\"] and restart Julia to enable it."
                Media.render(pane, Atom.div(Atom.HTML(s)))
            end
        end

        # special handling for plotly... use PlotsDisplay
        function Media.render(pane::Atom.PlotPane, plt::Plot{PlotlyBackend})
            display(Plots.PlotsDisplay(), plt)
            s = "PlotPane turned off.  The plotly and plotlyjs backends cannot render in the PlotPane due to javascript issues."
            Media.render(pane, Atom.div(Atom.HTML(s)))
        end
    end
end
