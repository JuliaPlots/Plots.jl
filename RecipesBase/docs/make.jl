using Documenter, RecipesBase, Plots

makedocs(
    sitename = "RecipesBase.jl",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true"
    ),
    pages = [
        "Home" => "index.md",
        "Recipe Syntax" => "syntax.md",
        "Recipe Types" => "types.md",
        "Internals" => "internals.md",
        "Library" => "api.md"
    ],
    modules = [RecipesBase]
)

deploydocs(
    repo = "github.com/JuliaPlots/RecipesBase.jl.git",
    push_preview = true,
)
