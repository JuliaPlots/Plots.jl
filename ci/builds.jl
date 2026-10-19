# a cache saved after a failed build keeps the package without the files its build fetches, and
# `Pkg` does not build an installed package again, so build those missing the last file fetched
using Pkg, TOML

last_fetched = (
    WebIO = ("deps", "bundles", "webio.bundle.js"),
    Knockout = ("assets", "knockout_punches.js"),
    InteractBase = ("assets", "katex.min.css"),
    Interact = ("assets", "bulma_confined.min.css"),
)
manifest = TOML.parsefile(joinpath(dirname(Base.active_project()), "Manifest.toml"))["deps"]
unbuilt = String[]
for (name, file) in pairs(last_fetched)
    haskey(manifest, string(name)) || continue
    uuid = Base.UUID(only(manifest[string(name)])["uuid"])
    root = dirname(dirname(Base.locate_package(Base.PkgId(uuid, string(name)))))
    isfile(joinpath(root, file...)) || push!(unbuilt, string(name))
end
isempty(unbuilt) || Pkg.build(unbuilt)
