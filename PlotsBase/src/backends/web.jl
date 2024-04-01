
# NOTE:  backend should implement `html_body` and `html_head`

# CREDIT: parts of this implementation were inspired by @joshday's PlotlyLocal.jl

standalone_html(
    plt::AbstractPlot;
    title::AbstractString = get(plt.attr, :window_title, "Plots.jl"),
) = """
    <!DOCTYPE html>
    <html>
        <head>
            <title>$title</title>
            <meta http-equiv="content-type" content="text/html; charset=UTF-8">
            $(html_head(plt))
        </head>
        <body>
            $(html_body(plt))
        </body>
    </html>
    """

embeddable_html(plt::AbstractPlot) = html_head(plt) * html_body(plt)

function open_browser_window(filename::AbstractString)
    @static if Sys.isapple()
        return run(`open $(filename)`)
    elseif Sys.islinux() || Sys.isbsd()    # Sys.isbsd() addition is as yet untested, but based on suggestion in https://github.com/JuliaPlots/Plots.jl/issues/681
        return run(`xdg-open $(filename)`)
    elseif Sys.iswindows()
        return run(`$(ENV["COMSPEC"]) /c start "" "$(filename)"`)
    else
        @warn "Unknown OS... cannot open browser window."
    end
end

function write_temp_html(plt::AbstractPlot)
    html = standalone_html(plt; title = plt.attr[:window_title])
    filename = string(tempname(), ".html")
    write(filename, html)
    filename
end

function standalone_html_window(plt::AbstractPlot)
    old = _use_local_dependencies[] # save state to restore afterwards
    # if we open a browser ourself, we can host local files, so
    # when we have a local plotly downloaded this is the way to go!
    _use_local_dependencies[] =
        _plotly_local_file_path[] === nothing ? false : isfile(_plotly_local_file_path[])
    filename = write_temp_html(plt)
    open_browser_window(filename)
    # restore for other backends
    _use_local_dependencies[] = old
end

# uses wkhtmltopdf/wkhtmltoimage: http://wkhtmltopdf.org/downloads.html
html_to_png(html_fn, png_fn, w, h) = run(
    `wkhtmltoimage -f png -q --width $w --height $h --disable-smart-width $html_fn $png_fn`,
)

function show_png_from_html(io::IO, plt::AbstractPlot)
    # write html to a temporary file
    html_fn = write_temp_html(plt)

    # convert that html file to a temporary png file using wkhtmltoimage
    png_fn = tempname() * ".png"
    w, h = plt.attr[:size]
    html_to_png(html_fn, png_fn, w, h)

    # now read that file data into io
    pngdata = readall(png_fn)
    write(io, pngdata)
end
