
defaultOutputFormat(plt::Plot) = "png"

png(plt::Plot, fn) =
    open(addExtension(fn, "png"), "w") do io
        show(io, MIME("image/png"), plt)
    end
png(fn) = png(current(), fn)

png(plt::Plot, io::IO) = show(io, MIME("image/png"), plt)
png(io::IO) = png(current(), io)

svg(plt::Plot, fn) =
    open(addExtension(fn, "svg"), "w") do io
        show(io, MIME("image/svg+xml"), plt)
    end
svg(fn) = svg(current(), fn)

svg(plt::Plot, io::IO) = show(io, MIME("image/svg+xml"), plt)
svg(io::IO) = svg(current(), io)

pdf(plt::Plot, fn) =
    open(addExtension(fn, "pdf"), "w") do io
        show(io, MIME("application/pdf"), plt)
    end
pdf(fn) = pdf(current(), fn)

pdf(plt::Plot, io::IO) = show(io, MIME("application/pdf"), plt)
pdf(io::IO) = pdf(current(), io)

ps(plt::Plot, fn) =
    open(addExtension(fn, "ps"), "w") do io
        show(io, MIME("application/postscript"), plt)
    end
ps(fn) = ps(current(), fn)

ps(plt::Plot, io::IO) = show(io, MIME("application/postscript"), plt)
ps(io::IO) = ps(current(), io)

eps(plt::Plot, fn) =
    open(addExtension(fn, "eps"), "w") do io
        show(io, MIME("image/eps"), plt)
    end
eps(fn) = eps(current(), fn)

eps(plt::Plot, io::IO) = show(io, MIME("image/eps"), plt)
eps(io::IO) = eps(current(), io)

tex(plt::Plot, fn) =
    open(addExtension(fn, "tex"), "w") do io
        show(io, MIME("application/x-tex"), plt)
    end
tex(fn) = tex(current(), fn)

tex(plt::Plot, io::IO) = show(io, MIME("application/x-tex"), plt)
tex(io::IO) = tex(current(), io)

json(plt::Plot, fn) =
    open(addExtension(fn, "json"), "w") do io
        show(io, MIME("application/vnd.plotly.v1+json"), plt)
    end
json(fn) = json(current(), fn)

json(plt::Plot, io::IO) = show(io, MIME("application/vnd.plotly.v1+json"), plt)
json(io::IO) = json(current(), io)

html(plt::Plot, fn) =
    open(addExtension(fn, "html"), "w") do io
        show(io, MIME("text/html"), plt)
    end
html(fn) = html(current(), fn)

html(plt::Plot, io::IO) = show(io, MIME("text/html"), plt)
html(io::IO) = html(current(), io)

txt(plt::Plot, fn; color::Bool = true) =
    open(addExtension(fn, "txt"), "w") do io
        show(IOContext(io, :color => color), MIME("text/plain"), plt)
    end
txt(fn) = txt(current(), fn)

txt(plt::Plot, io::IO) = show(io, MIME("text/plain"), plt)
txt(io::IO) = txt(current(), io)

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

for out in Symbol.(unique(values(_savemap)))
    @eval @doc """
        $($out)([plot,], filename)
    Save plot as $($out)-file.
    """ $out
end

const _extension_map = Dict("tikz" => "tex")

"""
    addExtension(filepath, extension)

Change filepath extension according to the extension map
"""
function addExtension(fp, ext::AbstractString)
    dn, fn = splitdir(fp)
    _, oldext = splitext(fn)
    oldext = chop(oldext, head = 1, tail = 0)
    get(_extension_map, oldext, oldext) == ext ? fp : joinpath(dn, string(fn, ".", ext))
end

"""
    savefig([plot,] filename)

Save a Plot (the current plot if `plot` is not passed) to file. The file
type is inferred from the file extension. All backends support png and pdf
file types, some also support svg, ps, eps, html and tex.
"""
function savefig(plt::Plot, fn) # fn might be an `AbstractString` or an `AbstractPath` from `FilePaths.jl`
    fn = abspath(expanduser(fn))

    # get the extension
    _, ext = splitext(fn)
    ext = chop(ext, head = 1, tail = 0)
    isempty(ext) && (ext = defaultOutputFormat(plt))

    # save it
    if haskey(_savemap, ext)
        func = _savemap[ext]
        return func(plt, fn)
    else
        error("Invalid file extension: ", fn)
    end
end
savefig(fn) = savefig(current(), fn)

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
    showval === :gui && gui(plt)
    showval in (:inline, :ijulia) && inline(plt)
end

# ---------------------------------------------------------

const _best_html_output_type =
    KW(:pyplot => :png, :unicodeplots => :txt, :plotlyjs => :html, :plotly => :html)

# a backup for html... passes to svg or png depending on the html_output_format arg
function _show(io::IO, ::MIME"text/html", plt::Plot)
    output_type = Symbol(plt.attr[:html_output_format])
    if output_type === :auto
        output_type = get(_best_html_output_type, backend_name(plt.backend), :svg)
    end
    if output_type === :png
        # @info("writing png to html output")
        print(
            io,
            "<img src=\"data:image/png;base64,",
            base64encode(show, MIME("image/png"), plt),
            "\" />",
        )
    elseif output_type === :svg
        # @info("writing svg to html output")
        show(io, MIME("image/svg+xml"), plt)
    elseif output_type === :txt
        show(io, MIME("text/plain"), plt)
    else
        error("only png or svg allowed. got: $(repr(output_type))")
    end
end

# delegate showable to _show instead
Base.showable(m::M, plt::P) where {M<:MIME,P<:Plot} = hasmethod(_show, Tuple{IO,M,P})

_display(plt::Plot) = @warn("_display is not defined for this backend.")

Base.show(io::IO, m::MIME"text/plain", plt::Plot) = show(io, plt)
# for writing to io streams... first prepare, then callback
for mime in (
    "text/html",
    "text/latex",
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

Base.showable(::MIME"text/html", plt::Plot{UnicodePlotsBackend}) = false  # Pluto

Base.show(io::IO, m::MIME"application/prs.juno.plotpane+html", plt::Plot) =
    showjuno(io, MIME("text/html"), plt)

"Close all open gui windows of the current backend"
closeall() = closeall(backend())

# ---------------------------------------------------------
# Atom PlotPane
# ---------------------------------------------------------
function showjuno(io::IO, m, plt)
    dpi = plt[:dpi]

    plt[:dpi] = get(io, :juno_dpi_ratio, 1) * Plots.DPI

    prepare_output(plt)
    try
        _showjuno(io, m, plt)
    finally
        plt[:dpi] = dpi
    end
end

_showjuno(io::IO, m::MIME"image/svg+xml", plt) =
    if Symbol(plt.attr[:html_output_format]) ≠ :svg
        throw(MethodError(show, (typeof(m), typeof(plt))))
    else
        _show(io, m, plt)
    end

Base.showable(::MIME"application/prs.juno.plotpane+html", plt::Plot) = false

_showjuno(io::IO, m, plt) = _show(io, m, plt)
