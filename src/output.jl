defaultOutputFormat(plt::Plot) = "png"

function png(plt::Plot, fn)
    fn = addExtension(fn, "png")
    open(io -> show(io, MIME("image/png"), plt), fn, "w")
    return fn
end
png(fn) = png(current(), fn)

png(plt::Plot, io::IO) = show(io, MIME("image/png"), plt)
png(io::IO) = png(current(), io)

function svg(plt::Plot, fn)
    fn = addExtension(fn, "svg")
    open(io -> show(io, MIME("image/svg+xml"), plt), fn, "w")
    return fn
end

svg(fn) = svg(current(), fn)

svg(plt::Plot, io::IO) = show(io, MIME("image/svg+xml"), plt)
svg(io::IO) = svg(current(), io)

function pdf(plt::Plot, fn)
    fn = addExtension(fn, "pdf")
    open(io -> show(io, MIME("application/pdf"), plt), fn, "w")
    return fn
end
pdf(fn) = pdf(current(), fn)

pdf(plt::Plot, io::IO) = show(io, MIME("application/pdf"), plt)
pdf(io::IO) = pdf(current(), io)

function ps(plt::Plot, fn)
    fn = addExtension(fn, "ps")
    open(io -> show(io, MIME("application/postscript"), plt), fn, "w")
    return fn
end
ps(fn) = ps(current(), fn)

ps(plt::Plot, io::IO) = show(io, MIME("application/postscript"), plt)
ps(io::IO) = ps(current(), io)

function eps(plt::Plot, fn)
    fn = addExtension(fn, "eps")
    open(io -> show(io, MIME("image/eps"), plt), fn, "w")
    return fn
end
eps(fn) = eps(current(), fn)

eps(plt::Plot, io::IO) = show(io, MIME("image/eps"), plt)
eps(io::IO) = eps(current(), io)

function tex(plt::Plot, fn)
    fn = addExtension(fn, "tex")
    open(io -> show(io, MIME("application/x-tex"), plt), fn, "w")
    return fn
end
tex(fn) = tex(current(), fn)

tex(plt::Plot, io::IO) = show(io, MIME("application/x-tex"), plt)
tex(io::IO) = tex(current(), io)

function json(plt::Plot, fn)
    fn = addExtension(fn, "json")
    open(io -> show(io, MIME("application/vnd.plotly.v1+json"), plt), fn, "w")
    return fn
end
json(fn) = json(current(), fn)

json(plt::Plot, io::IO) = show(io, MIME("application/vnd.plotly.v1+json"), plt)
json(io::IO) = json(current(), io)

function html(plt::Plot, fn)
    fn = addExtension(fn, "html")
    open(io -> show(io, MIME("text/html"), plt), fn, "w")
    return fn
end
html(fn) = html(current(), fn)

html(plt::Plot, io::IO) = show(io, MIME("text/html"), plt)
html(io::IO) = html(current(), io)

function txt(plt::Plot, fn; color::Bool = true)
    fn = addExtension(fn, "txt")
    open(io -> show(IOContext(io, :color => color), MIME("text/plain"), plt), fn, "w")
    return fn
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
    return get(_extension_map, oldext, oldext) == ext ? fp : joinpath(dn, string(fn, ".", ext))
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

function inline end  # for IJulia

function Base.display(::PlotsDisplay, plt::Plot)
    prepare_output(plt)
    return _display(plt)
end

_do_plot_show(plt, showval::Bool) = showval && gui(plt)
function _do_plot_show(plt, showval::Symbol)
    showval === :gui && gui(plt)
    return showval in (:inline, :ijulia) && inline(plt)
end

# ---------------------------------------------------------

const _best_html_output_type = KW(
    :unicodeplots => :png,
    :pgfplotsx => :png,
    :inspectdr => :png,
    :plotlyjs => :html,
    :plotly => :html,
    :pyplot => :png,
    :gaston => :png,
    :gr => :png,
)

# a backup for html... passes to svg or png depending on the html_output_format arg
function _show(io::IO, ::MIME"text/html", plt::Plot)
    output_type = Symbol(plt.attr[:html_output_format])
    if output_type === :auto
        output_type = get(_best_html_output_type, backend_name(plt.backend), :svg)
    end
    return if output_type === :png
        # @info "writing png to html output"
        print(
            io,
            "<img src=\"data:image/png;base64,",
            base64encode(show, MIME("image/png"), plt),
            "\" />",
        )
    elseif output_type === :svg
        # @info "writing svg to html output"
        show(io, MIME("image/svg+xml"), plt)
    elseif output_type === :txt
        show(io, MIME("text/plain"), plt)
    else
        error("only png or svg allowed. got: $(repr(output_type))")
    end
end

# delegate showable to _show instead
Base.showable(m::M, ::P) where {M <: MIME, P <: Plot} = showable(m, P)
Base.showable(::M, ::Type{P}) where {M <: MIME, P <: Plot} = hasmethod(_show, Tuple{IO, M, P})

_display(plt::Plot) = @warn "_display is not defined for this backend."

Base.show(io::IO, m::MIME"text/plain", plt::Plot) = show(io, plt)
# for writing to io streams... first prepare, then callback
for mime in (
        "application/vnd.plotly.v1+json",
        "application/postscript",
        "application/x-tex",
        "application/pdf",
        "application/eps",
        "image/svg+xml",
        "text/latex",
        "image/png",
        "image/eps",
        "text/html",
    )
    @eval function Base.show(io::IO, m::MIME{Symbol($mime)}, plt::Plot)
        if haskey(io, :juno_plotsize)
            showjuno(io, m, plt)
        else
            prepare_output(plt)
            Base.invokelatest(_show, io, m, plt)
        end
        return nothing
    end
end

"Close all open gui windows of the current backend"
closeall() = closeall(backend())

# COV_EXCL_START

Base.showable(::MIME"text/html", plt::Plot{UnicodePlotsBackend}) = false  # Pluto

Base.show(io::IO, m::MIME"application/prs.juno.plotpane+html", plt::Plot) =
    showjuno(io, MIME("text/html"), plt)

# Atom PlotPane
function showjuno(io::IO, m, plt)
    dpi = plt[:dpi]

    plt[:dpi] = get(io, :juno_dpi_ratio, 1) * Plots.DPI

    prepare_output(plt)
    return try
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
# COV_EXCL_STOP
