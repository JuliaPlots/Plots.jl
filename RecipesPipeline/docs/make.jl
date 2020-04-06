using Documenter
using RecipesPipeline
using Literate

# create literate versions of the source files
filepath = joinpath(@__DIR__, "..", "src")
files = joinpath.(filepath, readdir(filepath))

Literate.markdown.(files, joinpath(@__DIR__, "src", "generated"); documenter = false)

makedocs(
    sitename = "RecipesPipeline",
    format = format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true"
    ),
    pages = [
        "index.md",
        "Developer manual" => [
            "Public API" => "api.md",
            "Recipes" => "recipes.md"
            ],
        "Reference" => "reference.md",
        "Source code" => joinpath.(generated,
                [
                "RecipesPipeline.md",
                "api.md",
                "user_recipe.md",
                "plot_recipe.md",
                "type_recipe.md",
                "series_recipe.md",
                "group.md",
                "recipes.md",
                "series.md",
                "group.md",
                "utils.md"
            ]
        ),
    ],
    modules = [RecipesPipeline]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
deploydocs(
    repo = "https://github.com/JuliaPlots/RecipesPipeline.jl",
    push_preview = true
)
