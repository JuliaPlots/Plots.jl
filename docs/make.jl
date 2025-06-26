using FranklinTemplates, Franklin

descr = Dict{String,String}(
    "sandbox"   => """
                   <span class="th-name">sandbox</span>
                   <p>Simplest one-page layout, meant for practicing or testing Franklin syntax.</p>
                   """,
    "sandbox-extended"   => """
                   <span class="th-name">sandbox-extended</span>
                   <p>Simplest one-page layout, meant for practising interaction between Franklin and other packages.</p>
                   """,
    "basic"     => """
                   <span class="th-name">basic</span>
                   <p>Barebone responsive theme with a top navigation bar, no extra javascript and a simple stylesheet.</p>
                   """,
    "jemdoc"    => """
                   <span class="th-name">jemdoc</span>
                   <p>Simple theme with a side navigation bar, no extra javascript and a simple stylesheet. (Adapted from the original Jemdoc theme.)</p>
                   """,
    "just-the-docs" => """
                   <span class="th-name">just-the-docs</span>
                   <p>Simple documentation theme with a side navigation bar, and no extra javascript (Adapted from the Jekyll theme.)</p>
                   """,
    "hyde"      => """
                   <span class="th-name">hyde</span>
                   <p>A neat two-column responsive theme with a side navigation bar, no extra javascript and a simple stylesheet. (Adapted from the Jekyll theme.)</p>
                   """,
    "hypertext" => """
                   <span class="th-name">hypertext</span>
                   <p>Barebone responsive theme with a simple top navigation bar, no extra javascript and a simple stylesheet. (Adapted from the Grav theme.)</p>
                   """,
    "lanyon"    => """
                   <span class="th-name">lanyon</span>
                   <p>A neat single-column theme with a sliding menu-bar, no extra javascript and a simple stylesheet. (Adapted from the Jekyll theme.)</p>
                   """,
    "minimal-mistakes" => """
                   <span class="th-name">minimal-mistakes</span>
                   <p>A responsive two-column theme with a nice landing page, extra javascript for the responsiveness. (Adapted from the Jekyll theme.)</p>
                   """,
    "pure-sm"   => """
                   <span class="th-name">pure-sm</span>
                   <p>Single-column theme with a sliding menu-bar, a simple stylesheet and some javascript for the menu bar. (Adapted from the Pure CSS theme.)</p>
                   """,
    "tufte"     => """
                   <span class="th-name">tufte</span>
                   <p>A neat single-column theme adapted from tufte.css with a focus on clarity and nice typesetting, no extra javascript and a sophisticated stylesheet.</p>
                   """,
    "vela"      => """
                   <span class="th-name">vela</span>
                   <p>A single-column theme with a sliding menu-bar, a simple stylesheet and extra javascript for the menu-bar. (Adapted from the Grav theme.)</p>
                   """,
    "academic"  => """
                   <span class="th-name">academic</span>
                   <p>Simple one-page portfolio with blog posts and papers list, no extra javascript and a simple stylesheet.</p>
                   """,
    "celeste"   => """
                   <span class="th-name">celeste</span>
                   <p>A lightweight theme that features a minimalist, content-first design. (Adapted from the Jekyll theme.)</p>
                   """,
    "bootstrap5"=> """
                    <span class="th-name">bootstrap5</span>
                    <p>A bootstrap theme that uses Bootstrap 5, Bootstrap Icon 1.10, FontAwesome 6. (CDN base)</p>
                """,
    )


build = joinpath(@__DIR__, "build")

isdir(build) || mkdir(build)

function fixdir(τ::String)
    for name in readdir(τ; join=true)
        occursin("__site", name) && continue
        rm(name, recursive=true)
    end
    for name in readdir(joinpath(τ, "__site"); join=true)
        cp(name, replace(name, "__site" => ""))
    end
    rm(joinpath(τ, "__site"), recursive=true)
    # 2. fix links in index.html etc
    html_files = String[]
    for (root, _, files) ∈ walkdir(τ)
        for file ∈ files
            if endswith(file, ".xml")
                fp  = joinpath(root, file)
                rss = read(fp, String)
                rss = replace(rss, r"\/([a-zA-Z0-9\_-]+\.xsl)" => SubstitutionString("/FranklinTemplates.jl/templates/$τ/\\1"))
                write(fp, rss)
            end
            endswith(file, ".html") || continue
            fp   = joinpath(root, file)
            html = read(fp, String)
            html = replace(html, "href=\"/" => "href=\"/templates/$τ/")
            html = replace(html, "src=\"/" => "src=\"/templates/$τ/")
            write(fp, html)
        end
    end
    return
end

# make a template folder with a subfolder for each template
# compile each template with a fullpass of Franklin
begin
    # Clean up the directory to avoid clashes etc.
    if isdir(joinpath(build, "templates"))
        rm(joinpath(build, "templates"), recursive=true)
    end
    # Make the template folder.
    templates = mkpath(joinpath(build, "templates"))
    cd(templates)
    for τ ∈ FranklinTemplates.LIST_OF_TEMPLATES
        println("🍏  template: $τ")
        FranklinTemplates.newsite(τ; template=τ, changedir=true, verbose=false)
        optimize(minify=(τ ∉ ("vela", "sandbox-extended"))) # see issue #7
        cd("..")
        fixdir(τ)
    end
    # copy over the thumb folder
    cp(joinpath(dirname(build), "thumb"), joinpath(build, "thumb"), force=true)
end

# build the index page
begin
    io = IOBuffer()
    write(io, read(joinpath(@__DIR__, "index_head.html"), String))

    # One card per template
    for τ ∈ FranklinTemplates.LIST_OF_TEMPLATES
        c = """
            <a href="/templates/$τ/index.html" target="_blank" rel="noopener noreferrer" title="$τ">
            <div class="card" id="$τ">
              <div class="descr">
              $(descr[τ])
              </div>
            </div>
            </a>
            """
        write(io, c)
    end
    write(io, read(joinpath(@__DIR__, "index_foot.html"), String))
    write(joinpath(build, "index.html"), take!(io))
end

cd(pkgdir(FranklinTemplates))
