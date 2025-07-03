using GraphRecipes
using Markdown

cd(@__DIR__)

readme = read("../README.md", String) |> Markdown.parse
content = readme.content

code_blocks = []
for paragraph in content
    if paragraph isa Markdown.Code
        push!(code_blocks, paragraph.code)
    end
end

# Parse the code examples on the README into expressions. Ignore the first one, which is
# the installation instructions.
readme_exprs = [Meta.parse("begin $(code_blocks[i]) end") for i in 2:length(code_blocks)]

julia_logo_pun() = eval(readme_exprs[1])
