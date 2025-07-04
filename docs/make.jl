# oneliner fast build PLOTDOCS_SUFFIX='' PLOTDOCS_PACKAGES='UnicodePlots' PLOTDOCS_EXAMPLES='1' julia --project make.jl
import Pkg; Pkg.precompile()

using RecipesBase, RecipesPipeline, PlotsBase, Plots
using DemoCards, Literate, Documenter

import OrderedCollections
import UnicodePlots
import GraphRecipes
import StableRNGs
import PythonPlot
import StatsPlots
import MacroTools
import DataFrames
import PlotThemes
import PGFPlotsX
import PlotlyJS
import Unitful
import Gaston
import Dates
import JSON
import Glob

eval(PlotsBase.WEAKDEPS)

PythonPlot.pygui(false)  # prevent segfault on event loop in ci

const suffix = get(ENV, "PLOTDOCS_SUFFIX", "")
const SRC_DIR = joinpath(@__DIR__, "src")
const BLD_DIR = joinpath(@__DIR__, "build" * suffix)
const WORK_DIR = joinpath(@__DIR__, "work" * suffix)
const GEN_DIR = joinpath(WORK_DIR, "generated")
const BRANCH = ("master", "v2")[2]  # transition to v2

const ATTRIBUTE_SEARCH = Dict{String, Any}()  # search terms

# monkey patch `Documenter` - note that this could break on minor `Documenter` releases
@eval Documenter.Writers.HTMLWriter domify(dctx::DCtx) = begin
    ctx, navnode = dctx.ctx, dctx.navnode
    return map(getpage(ctx, navnode).mdast.children) do node
        rec = SearchRecord(ctx, navnode, node, node.element)
        ############################################################
        # begin addition
        info = "[src=$(rec.src) fragment=$(rec.fragment) title=$(rec.title) page_title=$(rec.page_title)]"
        if (m = match(r"generated/attributes_(\w+)", lowercase(rec.src))) ≢ nothing
            # fix attributes search terms: `Series`, `Plot`, `Subplot` and `Axis` (github.com/JuliaPlots/Plots.jl/issues/2337)
            @info "$info: fix attribute search" maxlog = 10
            for (attr, alias) in $(ATTRIBUTE_SEARCH)[first(m.captures)]
                push!(
                    ctx.search_index,
                    SearchRecord(rec.src, rec.page, rec.fragment, rec.category, rec.title, rec.page_title, attr * ' ' * alias)
                )
            end
        else
            add_to_index = if (m = match(r"gallery/(\w+)/", lowercase(rec.src))) ≢ nothing
                first(m.captures) == "gr"  # only add `GR` gallery pages to `search_index` (github.com/JuliaPlots/Plots.jl/issues/4157)
            else
                true
            end
            if add_to_index
                push!(ctx.search_index, rec)
            else
                @info "$info: skip adding to `search_index`" maxlog = 10
            end
        end
        # end addition
        ############################################################
        domify(dctx, node, node.element)
    end
end

@eval DemoCards get_logopath() = $(joinpath(SRC_DIR, "assets", "axis_logo_600x400.png"))

# ----------------------------------------------------------------------

edit_url(args...) = "https://github.com/JuliaPlots/Plots.jl/blob/$BRANCH/docs/" * if length(args) == 0
    "make.jl"
else
    joinpath(basename(WORK_DIR), args...)
end

autogenerated() = "(Automatically generated: " * Dates.format(Dates.now(), Dates.RFC1123Format) * ')'

author() = "[Plots.jl](https://github.com/JuliaPlots/Plots.jl)"

recursive_rmlines(x) = x
function recursive_rmlines(x::Expr)
    x = MacroTools.rmlines(x)
    x.args .= recursive_rmlines.(x.args)
    return x
end

pretty_print_expr(io::IO, expr::Expr) = if expr.head ≡ :block
    foreach(arg -> println(io, arg), recursive_rmlines(expr).args)
else
    println(io, recursive_rmlines(expr))
end

markdown_code_to_string(arr, prefix = "") =
    surround_backticks(prefix, join(sort(map(string, arr)), "`, `$prefix"))

markdown_symbols_to_string(arr) = isempty(arr) ? "" : markdown_code_to_string(arr, ":")

# ----------------------------------------------------------------------

function generate_cards(
        prefix::AbstractString, backend::Symbol, slice;
        skip = get(PlotsBase._backend_skips, backend, Int[])
    )
    @show backend
    # create folder: for each backend we generate a DemoSection "generated" under "gallery"
    cards_path = let dn = joinpath(prefix, string(backend), "generated" * suffix)
        isdir(dn) && rm(dn; recursive = true)
        mkpath(dn)
    end
    sec_config = Dict{String, Any}("order" => [])

    needs_rng_fix = Dict{Int, Bool}()

    for (i, example) in enumerate(PlotsBase._examples)
        i ∈ skip && continue
        (slice ≢ nothing && i ∉ slice) && continue
        # write out the header, description, code block, and image link
        jlname = "$backend-$(PlotsBase.ref_name(i)).jl"
        jl = PipeBuffer()
        # DemoCards YAML frontmatter
        # https://johnnychen94.github.io/DemoCards.jl/stable/quickstart/usage_example/julia_demos/1.julia_demo/#juliademocard_example
        asset_name = "$(backend)_$(PlotsBase.ref_name(i))"
        asset_path = asset_name * if i ∈ PlotsBase._animation_examples
            ".gif"
        elseif backend ∈ (:gr, :pythonplot, :gaston)
            ".svg"
        else
            ".png"
        end
        if !isempty(example.header)
            push!(sec_config["order"], jlname)
            # start a new demo file
            @debug "generate demo \"$(example.header)\" - writing `$jlname`"

            extra = if backend ≡ :unicodeplots
                "import FileIO, FreeType  #hide"  # weak deps for png export
            else
                ""
            end
            write(
                jl, """
                # ---
                # title: $(example.header)
                # id: $asset_name
                # cover: $asset_path
                # author: "$(author())"
                # description: ""
                # date: $(Dates.now())
                # ---

                using Plots
                const PlotsBase = Plots.PlotsBase  #hide
                $backend()
                $extra

                PlotsBase.reset_defaults()  #hide
                using StableRNGs  #hide
                rng = StableRNG($(PlotsBase.SEED))  #hide
                nothing  #hide
                """
            )
        end
        # DemoCards use Literate.jl syntax with extra leading `#` as markdown lines
        write(jl, "# $(replace(example.desc, "\n" => "\n  # "))\n")
        isnothing(example.imports) || pretty_print_expr(jl, example.imports)
        needs_rng_fix[i] = (exprs_rng = PlotsBase.replace_rand(example.exprs)) != example.exprs
        pretty_print_expr(jl, exprs_rng)

        # NOTE: the supported `Literate.jl` syntax is `#src` and `#hide` NOT `# src` !!
        # from the docs: """
        # #src and #hide are quite similar. The only difference is that #src lines are filtered out before execution (if execute=true) and #hide lines are filtered out after execution.
        # """
        asset_cmd = if i ∈ PlotsBase._animation_examples
            "PlotsBase.gif(anim, \"$asset_path\")\n"  # NOTE: must not be hidden, for appearance in the rendered `html`
        elseif backend ∈ (:gr, :pythonplot, :gaston)
            "PlotsBase.svg(\"$asset_path\")  #src\n"
        elseif backend ≡ :plotlyjs
            """
            PlotsBase.png(\"$asset_path\")  #src
            nothing  #hide
            # ![plot]($asset_path)
            """
        else
            "PlotsBase.png(\"$asset_path\")  #src\n"
        end
        write(jl, """mkpath("assets")  #src\n$asset_cmd\n""")

        @label write_file
        fn, mode = if isempty(example.header)
            "$backend-$(PlotsBase.ref_name(i - 1)).jl", "a"  # continued example
        else
            jlname, "w"
        end
        card = joinpath(cards_path, fn)
        # @info "writing" card
        open(io -> write(io, read(jl, String)), card, mode)
        # DEBUG: sometimes the generated file is still empty when passing to `DemoCards.makedemos`
        sleep(0.01)
    end
    # insert attributes page
    # TODO(johnnychen): make this part of the page template
    attr_name = string(backend, ".jl")
    open(joinpath(cards_path, attr_name), "w") do jl
        pkg = PlotsBase.backend_instance(Symbol(lowercase(string(backend))))
        write(
            jl, """
            # ---
            # title: Supported attribute values
            # id: $(backend)_attributes
            # hidden: true
            # author: "$(author())"
            # date: $(Dates.now())
            # ---

            # - Supported arguments: $(markdown_code_to_string(collect(PlotsBase.supported_attrs(pkg))))
            # - Supported values for linetype: $(markdown_symbols_to_string(PlotsBase.supported_seriestypes(pkg)))
            # - Supported values for linestyle: $(markdown_symbols_to_string(PlotsBase.supported_styles(pkg)))
            # - Supported values for marker: $(markdown_symbols_to_string(PlotsBase.supported_markers(pkg)))
            """
        )
    end
    open(joinpath(cards_path, "config.json"), "w") do config
        sec_config["title"] = ""  # avoid `# Generated` section in gallery
        sec_config["description"] = "[Supported attributes](@ref $(backend)_attributes)"
        push!(sec_config["order"], attr_name)
        write(config, JSON.json(sec_config))
    end
    return needs_rng_fix
end

# tables detailing the features that each backend supports
function make_support_df(allvals, func; default_backends)
    vals = sort(collect(allvals)) # rows
    bs = sort(collect(default_backends))
    df = DataFrames.DataFrame(keys = vals)

    for be in bs # cols
        be_supported_vals = fill("", length(vals))
        for (i, val) in enumerate(vals)
            be_supported_vals[i] = if func == PlotsBase.supported_seriestypes
                stype = PlotsBase.seriestype_supported(PlotsBase.backend_instance(be), val)
                stype ≡ :native ? "✅" : (stype ≡ :no ? "" : "🔼")
            else
                val ∈ func(PlotsBase.backend_instance(be)) ? "✅" : ""
            end
        end
        df[!, be] = be_supported_vals
    end
    return df
end

function generate_supported_markdown(; default_backends)
    supported_args = OrderedCollections.OrderedDict(
        "Keyword Arguments" => (PlotsBase.Commons._all_attrs, PlotsBase.supported_attrs),
        "Markers" => (PlotsBase.Commons._all_markers, PlotsBase.supported_markers),
        "Line Styles" => (PlotsBase.Commons._all_styles, PlotsBase.supported_styles),
        "Scales" => (PlotsBase.Commons._all_scales, PlotsBase.supported_scales)
    )
    return open(joinpath(GEN_DIR, "supported.md"), "w") do md
        write(
            md, """
            ```@meta
            EditURL = "$(edit_url())"
            ```

            ## [Series Types](@id supported)

            Key:

            - ✅ the series type is natively supported by the backend.
            - 🔼 the series type is supported through series recipes.

            ```@raw html
            $(to_html(make_support_df(PlotsBase.all_seriestypes(), PlotsBase.supported_seriestypes; default_backends)))
            ```
            """
        )
        for (header, args) in supported_args
            write(
                md, """

                ## $header

                ```@raw html
                $(to_html(make_support_df(args...; default_backends)))
                ```
                """
            )
        end
        write(md, '\n' * autogenerated())
    end
end

function make_attr_df(ktype::Symbol, defs::KW)
    n = length(defs)
    df = DataFrames.DataFrame(
        Attribute = fill("", n),
        Aliases = fill("", n),
        Default = fill("", n),
        Type = fill("", n),
        Description = fill("", n),
    )
    for (i, (k, def)) in enumerate(defs)
        type, desc = get(PlotsBase._arg_desc, k, (Any, ""))

        aliases = sort(collect(keys(filter(p -> p.second == k, PlotsBase.Commons._keyAliases))))
        df.Attribute[i] = string(k)
        df.Aliases[i] = join(aliases, ", ")
        df.Default[i] = show_default(def)
        df.Type[i] = string(type)
        df.Description[i] = string(desc)
    end
    sort!(df, [:Attribute])
    return df
end

surround_backticks(args...) = '`' * string(args...) * '`'
show_default(x) = surround_backticks(x)
show_default(x::Symbol) = surround_backticks(":$x")

function generate_attr_markdown(c)
    attribute_texts = Dict(
        :Series => "These attributes apply to individual series (lines, scatters, heatmaps, etc)",
        :Plot => "These attributes apply to the full Plot. (A Plot contains a tree-like layout of Subplots)",
        :Subplot => "These attributes apply to settings for individual Subplots.",
        :Axis => """
            These attributes apply by default to all Axes in a Subplot (for example the `subplot[:xaxis]`).
            !!! info
                You can also specific the x, y, or z axis for each of these attributes by prefixing the attribute name with x, y, or z
                (for example `xmirror` only sets the mirror attribute for the x axis).
            """,
    )
    attribute_defaults = Dict(
        :Series => PlotsBase.Commons._series_defaults,
        :Plot => PlotsBase.Commons._plot_defaults,
        :Subplot => PlotsBase.Commons._subplot_defaults,
        :Axis => PlotsBase.Commons._axis_defaults,
    )

    df = make_attr_df(c, attribute_defaults[c])
    cstr = lowercase(string(c))
    ATTRIBUTE_SEARCH[cstr] = collect(zip(df.Attribute, df.Aliases))

    return open(joinpath(GEN_DIR, "attributes_$cstr.md"), "w") do md
        write(
            md, """
            ```@meta
            EditURL = "$(edit_url())"
            ```
            ### $c

            $(attribute_texts[c])

            ```@raw html
            $(to_html(df))
            ```

            $(autogenerated())
            """
        )
    end
end

generate_attr_markdown() =
    foreach(c -> generate_attr_markdown(c), (:Series, :Plot, :Subplot, :Axis))

function generate_graph_attr_markdown()
    df = DataFrames.DataFrame(
        Attribute = [
            "dim",
            "T",
            "curves",
            "curvature_scalar",
            "root",
            "node_weights",
            "names",
            "fontsize",
            "nodeshape",
            "nodesize",
            "nodecolor",
            "x, y, z",
            "method",
            "func",
            "shorten",
            "axis_buffer",
            "layout_kw",
            "edgewidth",
            "edgelabel",
            "edgelabel_offset",
            "self_edge_size",
            "edge_label_box",
        ],
        Aliases = [
            "",
            "",
            "",
            "curvaturescalar, curvature",
            "",
            "nodeweights",
            "",
            "",
            "node_shape",
            "node_size",
            "marker_color",
            "x",
            "",
            "",
            "shorten_edge",
            "axisbuffer",
            "",
            "edge_width, ew",
            "edge_label, el",
            "edgelabeloffset, elo",
            "selfedgesize, ses",
            "edgelabelbox, edgelabel_box, elb",
        ],
        Default = [
            "2",
            "Float64",
            "true",
            "0.05",
            ":top",
            "nothing",
            "[]",
            "7",
            ":hexagon",
            "0.1",
            "1",
            "nothing",
            ":stress",
            "get(_graph_funcs, method, by_axis_local_stress_graph)",
            "0.0",
            "0.2",
            "Dict{Symbol,Any}()",
            "(s, d, w) -> 1",
            "nothing",
            "0.0",
            "0.1",
            "true",
        ],
        Description = [
            "The number of dimensions in the visualization.",
            "The data type for the coordinates of the graph nodes.",
            "Whether or not edges are curved. If `curves == true`, then the edge going from node \$s\$ to node \$d\$ will be defined by a cubic spline passing through three points: (i) node \$s\$, (ii) a point `p` that is distance `curvature_scalar` from the average of node \$s\$ and node \$d\$ and (iii) node \$d\$.",
            "A scalar that defines how much edges curve, see `curves` for more explanation.",
            "For displaying trees, choose from `:top`, `:bottom`, `:left`, `:right`. If you choose `:top`, then the tree will be plotted from the top down.",
            "The weight of the nodes given by a list of numbers. If `node_weights != nothing`, then the size of the nodes will be scaled by the `node_weights` vector.",
            "Names of the nodes given by a list of objects that can be parsed into strings. If the list is smaller than the number of nodes, then GraphRecipes will cycle around the list.",
            "Font size for the node labels and the edge labels.",
            "Shape of the nodes, choose from `:hexagon`, `:circle`, `:ellipse`, `:rect` or `:rectangle`.",
            "The size of nodes in the plot coordinates. Note that if `names` is not empty, then nodes will be scaled to fit the labels inside them.",
            "The color of the nodes. If `nodecolor` is an integer, then it will be taken from the current color palette. Otherwise, the user can pass any color that would be recognised by the Plots `color` attribute.",
            "The coordinates of the nodes.",
            "The method that GraphRecipes uses to produce an optimal layout, choose from `:spectral`, `:sfdp`, `:circular`, `:shell`, `:stress`, `:spring`, `:tree`, `:buchheim`, `:arcdiagram` or `:chorddiagram`. See [NetworkLayout](https://github.com/JuliaGraphs/NetworkLayout.jl) for further details.",
            "A layout algorithm that can be passed in by the user.",
            "An amount to shorten edges by.",
            "Increase the `xlims` and `ylims`/`zlims` of the plot. Can be useful if part of the graph sits outside of the default view.",
            "A list of keywords to be passed to the layout algorithm, see [NetworkLayout](https://github.com/JuliaGraphs/NetworkLayout.jl) for a list of keyword arguments for each algorithm.",
            "The width of the edge going from \$s\$ to node \$d\$ with weight \$w\$.",
            "A dictionary of `(s, d) => label`, where `s` is an integer for the source node, `d` is an integer for the destiny node and `label` is the desired label for the given edge. Alternatively the user can pass a vector or a matrix describing the edge labels. If you use a vector or matrix, then either `missing`, `false`, `nothing`, `NaN` or `\"\"` values will not be displayed. In the case of multigraphs, triples can be used to define edges.",
            "The distance between edge labels and edges.",
            "The size of self edges.",
            "A box around edge labels that avoids intersections between edge labels and the edges that they are labeling.",
        ]
    )
    return open(joinpath(GEN_DIR, "graph_attributes.md"), "w") do md
        write(
            md, """
            ```@meta
            EditURL = "$(edit_url())"
            ```
            # [Graph Attributes](@id graph_attributes)

            Where possible, GraphRecipes will adopt attributes from Plots.jl to format visualizations.
            For example, the `linewidth` attribute from Plots.jl has the same effect in `GraphRecipes`.
            In order to give the user control over the layout of the graph visualization,
            `GraphRecipes` provides a number of keyword arguments (attributes).
            Here we describe those attributes alongside their default values.

            ```@raw html
            $(to_html(df))
            ```
            \n
            ## Aliases
            Certain keyword arguments have aliases, so `GraphRecipes` does "what you mean, not what you say".

            So for example, `nodeshape=:rect` and `node_shape=:rect` are equivalent.
            To see the available aliases, type `GraphRecipes.graph_aliases`.
            If you are unhappy with the provided aliases, then you can add your own:
            ```julia
            using GraphRecipes, Plots

            push!(GraphRecipes.graph_aliases[:nodecolor],:nc)

            # These two calls produce the same plot, modulo some randomness in the layout.
            plot(graphplot([0 1; 0 0]; nodecolor=:red), graphplot([0 1; 0 0]; nc=:red))
            ```

            $(autogenerated())
            """
        )
    end
end

generate_colorschemes_markdown() = open(joinpath(GEN_DIR, "colorschemes.md"), "w") do md
    write(
        md, """
        ```@meta
        EditURL = "$(edit_url())"
        ```
        """
    )
    foreach(line -> write(md, line * '\n'), readlines(joinpath(SRC_DIR, "colorschemes.md")))
    write(
        md, """
        ## misc

        These colorschemes are not defined or provide different colors in ColorSchemes.jl
        They are kept for compatibility with Plots behavior before v1.1.0.
        """
    )
    write(md, "```@raw html\n")
    ks = [:default; sort(collect(keys(PlotUtils.MISC_COLORSCHEMES)))]
    write(md, to_html(make_colorschemes_df(ks); allow_html_in_cells = true))
    write(md, "\n```\n\nThe following colorschemes are defined by ColorSchemes.jl.\n\n")
    for cs in ("cmocean", "scientific", "matplotlib", "colorbrewer", "gnuplot", "colorcet", "seaborn", "general")
        ks = sort([k for (k, v) in PlotUtils.ColorSchemes.colorschemes if occursin(cs, v.category)])
        write(md, "\n## $cs\n\n```@raw html\n")
        write(md, to_html(make_colorschemes_df(ks); allow_html_in_cells = true))
        write(md, "\n```\n")
    end
end

function colors_svg(cs, w, h)
    n = length(cs)
    ws = min(w / n, h)
    # NOTE: html tester, codebeautify.org/htmlviewer or htmledit.squarefree.com
    html = replace(
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN"
         "https://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
        <svg xmlns="https://www.w3.org/2000/svg" version="1.1"
             width="$(n * ws)mm" height="$(h)mm"
             viewBox="0 0 $n 1" preserveAspectRatio="none"
             shape-rendering="crispEdges" stroke="none">
        """, "\n" => " "
    )  # NOTE: no linebreaks (because those break html code)
    for (i, c) in enumerate(cs)
        html *= """<rect width="$(ws)mm" height="$(h)mm" x="$(i - 1)" y="0" fill="#$(hex(convert(RGB, c)))" />"""
    end
    return html *= "</svg>"
end

function make_colorschemes_df(ks)
    n = length(ks)
    df = DataFrames.DataFrame(
        Name = fill("", n),
        Palette = fill("", n),
        Gradient = fill("", n),
    )
    len, w, h = 100, 60, 5
    for (i, k) in enumerate(ks)
        p = palette(k)
        cg = cgrad(k)[range(0, 1, length = len)]
        cp = length(p) ≤ len ? color_list(p) : cg
        df.Name[i] = string(':', k)
        df.Palette[i] = colors_svg(cp, w, h)
        df.Gradient[i] = colors_svg(cg, w, h)
    end
    return df
end

# ----------------------------------------------------------------------

function to_html(df::DataFrames.AbstractDataFrame; table_style = Dict("font-size" => "12px"), kw...)
    io = PipeBuffer()  # NOTE: `DataFrames` exports `PrettyTables`
    show(
        IOContext(io, :limit => false, :compact => false), MIME"text/html"(), df;
        show_row_number = false, summary = false, eltypes = false, table_style,
        kw...
    )
    return read(io, String)
end

function main(args)
    length(args) > 0 && return  # split precompilation and actual docs build

    get!(ENV, "MPLBACKEND", "agg")  # set matplotlib gui backend
    get!(ENV, "GKSwstype", "nul")  # disable default GR ws

    # cleanup
    isdir(WORK_DIR) && rm(WORK_DIR; recursive = true)
    isdir(BLD_DIR) && rm(BLD_DIR; recursive = true)
    mkpath(GEN_DIR)

    # initialize all backends
    gr()
    pythonplot()
    plotlyjs()
    pgfplotsx()
    unicodeplots()
    gaston()

    # NOTE: for a faster representative test build use `PLOTDOCS_PACKAGES='GR' PLOTDOCS_EXAMPLES='1'`
    all_packages = "GR PythonPlot PlotlyJS PGFPlotsX UnicodePlots Gaston"
    packages = get(ENV, "PLOTDOCS_PACKAGES", "ALL")
    packages = let val = packages == "ALL" ? all_packages : packages
        Symbol.(filter(!isempty, strip.(split(val))))
    end
    packages_backends = NamedTuple(p => Symbol(lowercase(string(p))) for p in packages)
    backends = values(packages_backends) |> collect
    debug = length(packages) ≤ 1

    @info "selected packages: $packages"
    @info "selected backends: $backends"

    slice = parse.(Int, split(get(ENV, "PLOTDOCS_EXAMPLES", "")))
    slice = length(slice) == 0 ? nothing : slice
    @info "selected examples: $slice"

    work = basename(WORK_DIR)
    build = basename(BLD_DIR)
    src = basename(SRC_DIR)

    if !debug
        @info "generate markdown"
        generate_attr_markdown()
        generate_supported_markdown(; default_backends = backends)
        generate_graph_attr_markdown()
        generate_colorschemes_markdown()

        for (pkg, dest) in (
                (PlotThemes, "plotthemes.md"),
                (StatsPlots, "statsplots.md"),
            )
            cp(pkgdir(pkg, "README.md"), joinpath(GEN_DIR, dest); force = true)
        end
    end

    @info "gallery"
    gallery = Pair{String, String}[]
    gallery_assets, gallery_callbacks, user_gallery = map(_ -> [], 1:3)
    needs_rng_fix = Dict{Symbol, Any}()

    @time "gallery" for pkg in packages
        be = packages_backends[pkg]
        needs_rng_fix[pkg] = generate_cards(joinpath(@__DIR__, "gallery"), be, slice)
        let (path, cb, asset) = makedemos(
                joinpath(@__DIR__, "gallery", string(be));
                root = @__DIR__, src = joinpath(work, "gallery"), edit_branch = BRANCH
            )
            push!(gallery, string(pkg) => joinpath("gallery", path))
            push!(gallery_callbacks, cb)
            push!(gallery_assets, asset)
        end
    end
    if !debug
        user_gallery, cb, assets = makedemos(
            joinpath("user_gallery");
            root = @__DIR__, src = work, edit_branch = BRANCH
        )
        push!(gallery_callbacks, cb)
        push!(gallery_assets, assets)
        unique!(gallery_assets)
        @show user_gallery gallery_assets
    end

    pages = if debug
        ["Home" => "index.md", "Gallery" => gallery]
    else  # release
        [
            "Home" => "index.md",
            "Getting Started" => [
                "Installation" => "install.md",
                "Basics" => "basics.md",
                "Tutorial" => "tutorial.md",
                "Series Types" => [
                    "Contour Plots" => "series_types/contour.md",
                    "Histograms" => "series_types/histogram.md",
                ],
            ],
            "Manual" => [
                "Input Data" => "input_data.md",
                "Output" => "output.md",
                "Attributes" => "attributes.md",
                "Series Attributes" => "generated/attributes_series.md",
                "Plot Attributes" => "generated/attributes_plot.md",
                "Subplot Attributes" => "generated/attributes_subplot.md",
                "Axis Attributes" => "generated/attributes_axis.md",
                "Layouts" => "layouts.md",
                "Recipes" => [
                    "Overview" => "recipes.md",
                    "RecipesBase" => [
                        "Home" => "RecipesBase/index.md",
                        "Recipes Syntax" => "RecipesBase/syntax.md",
                        "Recipes Types" => "RecipesBase/types.md",
                        "Internals" => "RecipesBase/internals.md",
                        "Public API" => "RecipesBase/api.md",
                    ],
                    "RecipesPipeline" => [
                        "Home" => "RecipesPipeline/index.md",
                        "Public API" => "RecipesPipeline/api.md",
                    ],
                ],
                "Colors" => "colors.md",
                "ColorSchemes" => "generated/colorschemes.md",
                "Animations" => "animations.md",
                "Themes" => "generated/plotthemes.md",
                "Backends" => "backends.md",
                "Supported Attributes" => "generated/supported.md",
            ],
            "Learning" => "learning.md",
            "Contributing" => "contributing.md",
            "Ecosystem" => [
                "StatsPlots" => "generated/statsplots.md",
                "GraphRecipes" => [
                    "Introduction" => "GraphRecipes/introduction.md",
                    "Examples" => "GraphRecipes/examples.md",
                    "Attributes" => "generated/graph_attributes.md",
                ],
                "UnitfulExt" => [
                    "Introduction" => "UnitfulExt/unitfulext.md",
                    "Examples" => [
                        "Simple" => "generated/unitfulext_examples.md",
                        "Plots" => "generated/unitfulext_plots.md",
                    ],
                ],
                "Overview" => "ecosystem.md",
            ],
            "Advanced Topics" => ["Plot objects" => "plot_objects.md", "Plotting pipeline" => "pipeline.md"],
            "Gallery" => gallery,
            "User Gallery" => user_gallery,
            "API" => "api.md",
        ]
    end

    # those will be built pages - to skip some pages, comment them above
    selected_pages = []
    collect_pages!(p::Pair) = if p.second isa AbstractVector
        collect_pages!(p.second)
    else
        push!(selected_pages, basename(p.second))
    end
    collect_pages!(v::AbstractVector) = foreach(collect_pages!, v)

    collect_pages!(pages)
    unique!(selected_pages)
    @show debug selected_pages length(gallery) pages SRC_DIR WORK_DIR BLD_DIR

    n = 0
    @time "copy to src" for (root, dirs, files) in walkdir(SRC_DIR)
        prefix = replace(root, SRC_DIR => WORK_DIR)
        foreach(dir -> mkpath(joinpath(WORK_DIR, dir)), dirs)
        for file in files
            _, ext = splitext(file)
            (ext == ".md" && file ∉ selected_pages) && continue
            src = joinpath(root, file)
            dst = joinpath(prefix, file)
            if debug
                endswith(root, r"RecipesBase|RecipesPipeline|UnitfulExt|GraphRecipes|StatsPlots") && continue
                println('\t', src, " -> ", dst)
            end
            cp(src, dst; force = true)
            n += 1
        end
    end
    @info "copied $n source file(s) to scratch directory `$work`"

    if !debug
        @info "UnitfulExt"
        src_unitfulext = "src/UnitfulExt"
        unitfulext = joinpath(@__DIR__, src_unitfulext)
        notebooks = joinpath(unitfulext, "notebooks")

        execute = true  # set to true for executing notebooks and documenter
        nb = false      # set to true to generate the notebooks
        @time "UnitfulExt" for (root, _, files) in walkdir(unitfulext), file in files
            last(splitext(file)) == ".jl" || continue
            ipath = joinpath(root, file)
            opath = replace(ipath, src_unitfulext => joinpath(work, "generated")) |> splitdir |> first
            Literate.markdown(ipath, opath; documenter = execute)
            nb && Literate.notebook(ipath, notebooks; execute)
        end
    end

    ansicolor = Base.get_bool_env("PLOTDOCS_ANSICOLOR", true)
    @info "makedocs ansicolor=$ansicolor"
    failed = false
    try
        @time "makedocs" makedocs(;
            format = Documenter.HTML(;
                size_threshold = nothing,
                prettyurls = Base.get_bool_env("CI", false),
                assets = ["assets/favicon.ico", gallery_assets...],
                collapselevel = 2,
                ansicolor,
            ),
            root = @__DIR__,
            source = work,
            build,
            # pagesonly = true,  # fails DemoCards, see github.com/JuliaDocs/DemoCards.jl/issues/162
            sitename = "Plots",
            authors = "Thomas Breloff",
            warnonly = true,
            pages,
        )
    catch e
        failed = true
        e isa InterruptException || rethrow()
    end

    @info "gallery callbacks"
    @time "gallery callbacks" foreach(gallery_callbacks) do cb
        cb()  # URL redirection for DemoCards-generated gallery
    end

    failed && return  # don't deploy and post-process on failure

    @info "post-process gallery html files to remove `rng` in user displayed code"
    # non-exhaustive list of examples to be fixed:
    # [1, 4, 5, 7:12, 14:21, 25:27, 29:30, 33:34, 36, 38:39, 41, 43, 45:46, 48, 52, 54, 62]
    @time "post-process `rng`" for pkg in packages
        be = packages_backends[pkg]
        prefix = joinpath(BLD_DIR, "gallery", string(be), "generated" * suffix)
        must_fix = needs_rng_fix[pkg]
        for file in Glob.glob("*/index.html", prefix)
            (m = match(r"-ref(\d+)", file)) ≡ nothing && continue
            idx = parse(Int, first(m.captures))
            get(must_fix, idx, false) || continue
            lines = readlines(file; keep = true)
            open(file, "w") do io
                count, in_code, sub = 0, false, ""
                for line in lines
                    trailing = if (m = match(r"""<code class="language-julia hljs">.*""", line)) ≢ nothing
                        in_code = true
                        m.match
                    else
                        line
                    end
                    if in_code && occursin("rng", line)
                        line = replace(line, r"rng\s*?,\s*" => "")
                        count += 1
                    end
                    occursin("</code>", trailing) && (in_code = false)
                    write(io, line)
                end
                count > 0 && @info "replaced $count `rng` occurrence(s) in $file" maxlog = 10
                @assert count > 0 "idx=$idx - count=$count - file=$file"
            end
        end
    end

    @info "post-process work dir"
    @time "post-process work dir" for file in Glob.glob("*/index.html", BLD_DIR)
        lines = readlines(file; keep = true)
        any(line -> occursin(joinpath("blob", BRANCH, "docs"), line), lines) || continue
        @info "fixing $file" maxlog = 10
        open(file, "w") do io
            old = joinpath("blob", BRANCH, "docs", work)
            new = joinpath("blob", BRANCH, "docs", src)
            foreach(line -> write(io, replace(line, old => new)), lines)
        end
    end

    debug && for (rt, dirs, fns) in walkdir(BLD_DIR)
        if length(dirs) > 0
            println("dirs in $rt:")
            foreach(d -> println('\t', joinpath(rt, d)), dirs)
        end
        if length(fns) > 0
            println("files in $rt:")
            foreach(f -> println('\t', joinpath(rt, f)), fns)
        end
    end

    @info "deploydocs"
    repo = "JuliaPlots/Plots.jl"
    @time "deploydocs" withenv("GITHUB_REPOSITORY" => repo) do
        deploydocs(;
            root = @__DIR__,
            target = build,
            versions = ["stable" => "v^", "v#.#", "dev" => "dev", "latest" => "dev"],
            devbranch = BRANCH,
            deploy_repo = "github.com/JuliaPlots/PlotDocs.jl",  # see https://documenter.juliadocs.org/stable/man/hosting/#Out-of-repo-deployment
            repo_previews = "github.com/JuliaPlots/PlotDocs.jl",
            push_preview = Base.get_bool_env("PLOTDOCS_PUSH_PREVIEW", false),
            forcepush = true,
            repo,
        )
    end
    @info "done !"
    return nothing
end

main(ARGS)
