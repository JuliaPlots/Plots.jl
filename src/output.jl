
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

function json(plt::Plot, fn::AbstractString)
    fn = addExtension(fn, "json")
    io = open(fn, "w")
    show(io, MIME("application/vnd.plotly.v1+json"), plt)
    close(io)
end
json(fn::AbstractString) = json(current(), fn)

function html(plt::Plot, fn::AbstractString)
    fn = addExtension(fn, "html")
    io = open(fn, "w")
    show(io, MIME("text/html"), plt)
    close(io)
end
html(fn::AbstractString) = html(current(), fn)

function txt(plt::Plot, fn::AbstractString)
    fn = addExtension(fn, "txt")
    io = open(fn, "w")
    show(io, MIME("text/plain"), plt)
    close(io)
end
txt(fn::AbstractString) = txt(current(), fn)


# ----------------------------------------------------------------

const _savemap = Dict(
    "png" => png,
    "svg" => svg,
    "pdf" => pdf,
    "ps" => ps,
    "eps" => eps,
    "tex" => tex,
    "json" => json,
    "html" => html,
    "tikz" => tex,
    "txt" => txt,
)

const _extension_map = Dict("tikz" => "tex")

function addExtension(fn::AbstractString, ext::AbstractString)
    oldfn, oldext = splitext(fn)
    oldext = chop(oldext, head = 1, tail = 0)
    if get(_extension_map, oldext, oldext) == ext
        return fn
    else
        return string(fn, ".", ext)
    end
end

"""
    savefig([plot,] filename)

Save a Plot (the current plot if `plot` is not passed) to file. The file
type is inferred from the file extension. All backends support png and pdf
file types, some also support svg, ps, eps, html and tex.
"""
function savefig(plt::Plot, fn::AbstractString)
    fn = abspath(expanduser(fn))

    # get the extension
    fn, ext = splitext(fn)
    ext = chop(ext, head = 1, tail = 0)
    if isempty(ext)
        ext = defaultOutputFormat(plt)
    end

    # save it
    if haskey(_savemap, ext)
        func = _savemap[ext]
        return func(plt, fn)
    else
        error("Invalid file extension: ", fn)
    end
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

_do_plot_show(plt, showval::Bool) = showval && gui(plt)
function _do_plot_show(plt, showval::Symbol)
    showval == :gui && gui(plt)
    showval in (:inline, :ijulia) && inline(plt)
end

# ---------------------------------------------------------

const _best_html_output_type =
    KW(:pyplot => :png, :unicodeplots => :txt, :plotlyjs => :html, :plotly => :html)

# a backup for html... passes to svg or png depending on the html_output_format arg
function _show(io::IO, ::MIME"text/html", plt::Plot)
    output_type = Symbol(plt.attr[:html_output_format])
    if output_type == :auto
        output_type = get(_best_html_output_type, backend_name(plt.backend), :svg)
    end
    if output_type == :png
        # @info("writing png to html output")
        print(
            io,
            "<img src=\"data:image/png;base64,",
            base64encode(show, MIME("image/png"), plt),
            "\" />",
        )
    elseif output_type == :svg
        # @info("writing svg to html output")
        show(io, MIME("image/svg+xml"), plt)
    elseif output_type == :txt
        show(io, MIME("text/plain"), plt)
    else
        error("only png or svg allowed. got: $(repr(output_type))")
    end
end

# delegate showable to _show instead
function Base.showable(m::M, plt::P) where {M <: MIME, P <: Plot}
    return hasmethod(_show, Tuple{IO, M, P})
end

function _display(plt::Plot)
    @warn("_display is not defined for this backend.")
end

# for writing to io streams... first prepare, then callback
for mime in (
    "text/plain",
    "text/html",
    "image/png",
    "image/eps",
    "image/svg+xml",
    "application/eps",
    "application/pdf",
    "application/postscript",
    "application/x-tex",
    "application/vnd.plotly.v1+json",
)
    @eval function Base.show(io::IO, m::MIME{Symbol($mime)}, plt::Plot)
        if haskey(io, :juno_plotsize)
            showjuno(io, m, plt)
        else
            prepare_output(plt)
            _show(io, m, plt)
        end
        return nothing
    end
end

Base.show(io::IO, m::MIME"application/prs.juno.plotpane+html", plt::Plot) =
    showjuno(io, MIME("text/html"), plt)

# default text/plain for all backends
_show(io::IO, ::MIME{Symbol("text/plain")}, plt::Plot) = show(io, plt)

"Close all open gui windows of the current backend"
closeall() = closeall(backend())


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
# Atom PlotPane
# ---------------------------------------------------------
function showjuno(io::IO, m, plt)
    sz = collect(plt[:size])
    dpi = plt[:dpi]
    thickness_scaling = plt[:thickness_scaling]

    jsize = get(io, :juno_plotsize, [400, 500])
    jratio = get(io, :juno_dpi_ratio, 1)

    scale = minimum(jsize[i] / sz[i] for i in 1:2)
    plt[:size] = [s * scale for s in sz]
    plt[:dpi] = jratio * Plots.DPI
    plt[:thickness_scaling] *= scale

    prepare_output(plt)
    try
        _showjuno(io, m, plt)
    finally
        plt[:size] = sz
        plt[:dpi] = dpi
        plt[:thickness_scaling] = thickness_scaling
    end
end

function _showjuno(io::IO, m::MIME"image/svg+xml", plt)
    if Symbol(plt.attr[:html_output_format]) ≠ :svg
        throw(MethodError(show, (typeof(m), typeof(plt))))
    else
        _show(io, m, plt)
    end
end

Base.showable(::MIME"application/prs.juno.plotpane+html", plt::Plot) = false

_showjuno(io::IO, m, plt) = _show(io, m, plt)
