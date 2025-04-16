struct PlotsDisplay <: AbstractDisplay end

default_output_format(plt::Plot) = "png"

function png(plt::Plot, fn)
    fn = addExtension(fn, "png")
    open(io -> show(io, MIME("image/png"), plt), fn, "w")
    fn
end
png(fn) = png(current(), fn)

png(plt::Plot, io::IO) = show(io, MIME("image/png"), plt)
png(io::IO) = png(current(), io)

function svg(plt::Plot, fn)
    fn = addExtension(fn, "svg")
    open(io -> show(io, MIME("image/svg+xml"), plt), fn, "w")
    fn
end

svg(fn) = svg(current(), fn)

svg(plt::Plot, io::IO) = show(io, MIME("image/svg+xml"), plt)
svg(io::IO) = svg(current(), io)

function pdf(plt::Plot, fn)
    fn = addExtension(fn, "pdf")
    open(io -> show(io, MIME("application/pdf"), plt), fn, "w")
    fn
end
pdf(fn) = pdf(current(), fn)

pdf(plt::Plot, io::IO) = show(io, MIME("application/pdf"), plt)
pdf(io::IO) = pdf(current(), io)

function ps(plt::Plot, fn)
    fn = addExtension(fn, "ps")
    open(io -> show(io, MIME("application/postscript"), plt), fn, "w")
    fn
end
ps(fn) = ps(current(), fn)

ps(plt::Plot, io::IO) = show(io, MIME("application/postscript"), plt)
ps(io::IO) = ps(current(), io)

function eps(plt::Plot, fn)
    fn = addExtension(fn, "eps")
    open(io -> show(io, MIME("image/eps"), plt), fn, "w")
    fn
end
eps(fn) = eps(current(), fn)

eps(plt::Plot, io::IO) = show(io, MIME("image/eps"), plt)
eps(io::IO) = eps(current(), io)

function tex(plt::Plot, fn)
    fn = addExtension(fn, "tex")
    open(io -> show(io, MIME("application/x-tex"), plt), fn, "w")
    fn
end
tex(fn) = tex(current(), fn)

tex(plt::Plot, io::IO) = show(io, MIME("application/x-tex"), plt)
tex(io::IO) = tex(current(), io)

function json(plt::Plot, fn)
    fn = addExtension(fn, "json")
    open(io -> show(io, MIME("application/vnd.plotly.v1+json"), plt), fn, "w")
    fn
end
json(fn) = json(current(), fn)

json(plt::Plot, io::IO) = show(io, MIME("application/vnd.plotly.v1+json"), plt)
json(io::IO) = json(current(), io)

function html(plt::Plot, fn)
    fn = addExtension(fn, "html")
    open(io -> show(io, MIME("text/html"), plt), fn, "w")
    fn
end
html(fn) = html(current(), fn)

html(plt::Plot, io::IO) = show(io, MIME("text/html"), plt)
html(io::IO) = html(current(), io)

function txt(plt::Plot, fn; color::Bool = true)
    fn = addExtension(fn, "txt")
    open(io -> show(IOContext(io, :color => color), MIME("text/plain"), plt), fn, "w")
    fn
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

for out ∈ Symbol.(unique(values(_savemap)))
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
    if isfile(fn) && plt[:safe_saving]
        @warn "Filename $fn already exists, defaulting to prevent overriding. To disable this behavior, provide `:safe_saving=false` kwarg, i.e. `plot(rand(10), safe_saving=false)`"
        return
    end
    # get the extension
    _, ext = splitext(fn)
    ext = chop(ext, head = 1, tail = 0)
    isempty(ext) && (ext = default_output_format(plt))

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

Display a plot using the backends' gui window.
"""
gui(plt::Plot = current()) = display(PlotsDisplay(), plt)

function Base.display(::PlotsDisplay, plt::Plot)
    prepare_output(plt)
    _display(plt)
end

_do_plot_show(plt, showval::Bool) = showval && gui(plt)
function _do_plot_show(plt, showval::Symbol)
    showval ≡ :gui && gui(plt)
    showval in (:inline, :ijulia) && inline(plt)
end

# ---------------------------------------------------------

const _best_html_output_type =
    KW(:pythonplot => :png, :unicodeplots => :txt, :plotlyjs => :html, :plotly => :html)

# a backup for html... passes to svg or png depending on the html_output_format arg
function _show(io::IO, ::MIME"text/html", plt::Plot)
    output_type = Symbol(plt.attr[:html_output_format])
    if output_type ≡ :auto
        output_type = get(_best_html_output_type, backend_name(plt.backend), :svg)
    end
    if output_type ≡ :png
        # @info "writing png to html output"
        print(
            io,
            "<img src=\"data:image/png;base64,",
            Base64.base64encode(show, MIME("image/png"), plt),
            "\" />",
        )
    elseif output_type ≡ :svg
        # @info "writing svg to html output"
        show(io, MIME("image/svg+xml"), plt)
    elseif output_type ≡ :txt
        show(io, MIME("text/plain"), plt)
    else
        error("only png or svg allowed. got: $(repr(output_type))")
    end
end

# delegate showable to _show instead
Base.showable(m::M, ::P) where {M<:MIME,P<:Plot} = showable(m, P)
Base.showable(::M, ::Type{P}) where {M<:MIME,P<:Plot} = hasmethod(_show, Tuple{IO,M,P})

_display(plt::Plot) = @warn "_display is not defined for this backend."

Base.show(io::IO, m::MIME"text/plain", plt::Plot) = show(io, plt)
# for writing to io streams... first prepare, then callback
for mime ∈ (
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
            Base.invokelatest(_show, io, m, plt)
        end
        return nothing
    end
end

"Close all open gui windows of the current backend"
closeall() = closeall(backend())

# COV_EXCL_START

# Base.showable(::MIME"text/html", ::Plot{UnicodePlotsBackend}) = false  # Pluto

Base.show(io::IO, m::MIME"application/prs.juno.plotpane+html", plt::Plot) =
    showjuno(io, MIME("text/html"), plt)

function inline end  # for IJulia

function hdf5plot_write end
function hdf5plot_read end

"""
Add extra jupyter mimetypes to display_dict based on the plot backed.

The default is nothing, except for plotly based backends, where it
adds data for `application/vnd.plotly.v1+json` that is used in
frontends like jupyterlab and nteract.
"""
_ijulia__extra_mime_info!(::Plot, out::Dict) = out

# Atom PlotPane
function showjuno(io::IO, m, plt)
    dpi = plt[:dpi]

    plt[:dpi] = get(io, :juno_dpi_ratio, 1) * PlotsBase.DPI

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

Base.showable(::MIME"application/prs.juno.plotpane+html", ::Plot) = false

_showjuno(io::IO, m, plt) = _show(io, m, plt)

# COV_EXCL_STOP
