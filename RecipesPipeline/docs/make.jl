using Documenter
using RecipesPipeline

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
        "Reference" => "reference.md"
    ],
    modules = [RecipesPipeline]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#
