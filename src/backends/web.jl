
# NOTE:  backend should implement `html_body` and `html_head`

# CREDIT: parts of this implementation were inspired by @joshday's PlotlyLocal.jl


function standalone_html(plt::AbstractPlot; title::AbstractString = get(plt.plotargs, :window_title, "Plots.jl"))
    """
    <!DOCTYPE html>
    <html>
        <head>
            <title>$title</title>
            $(html_head(plt))
        </head>
        <body>
            $(html_body(plt))
        </body>
    </html>
    """
end

function open_browser_window(filename::AbstractString)
    @osx_only   return run(`open $(filename)`)
    @linux_only return run(`xdg-open $(filename)`)
    @windows_only return run(`$(ENV["COMSPEC"]) /c start $(filename)`)
    warn("Unknown OS... cannot open browser window.")
end

function write_temp_html(plt::AbstractPlot)
    html = standalone_html(plt; title = plt.plotargs[:title])
    filename = string(tempname(), ".html")
    output = open(filename, "w")
    write(output, html)
    close(output)
    filename
end

function standalone_html_window(plt::AbstractPlot)
    filename = write_temp_html(plt)
    open_browser_window(filename)
end

# uses wkhtmltopdf/wkhtmltoimage: http://wkhtmltopdf.org/downloads.html
function html_to_png(html_fn, png_fn, w, h)
    run(`wkhtmltoimage --width $w --height $h --disable-smart-width $html_fn $png_fn`)
end

function writemime_png_from_html(io::IO, plt::AbstractPlot)
    # write html to a temporary file
    html_fn = write_temp_html(plt)

    # convert that html file to a temporary png file using wkhtmltoimage
    png_fn = tempname() * ".png"
    w, h = plt.plotargs[:size]
    html_to_png(html_fn, png_fn, w, h)

    # now read that file data into io
    pngdata = readall(png_fn)
    write(io, pngdata)
end
