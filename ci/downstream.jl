using Pkg

const LibGit2 = Pkg.GitTools.LibGit2
const TOML = Pkg.TOML

failsafe_clone_checkout(path, url) = begin
    local repo
    for i in 1:6
        try
            repo = Pkg.GitTools.ensure_clone(stdout, path, url)
            break
        catch err
            @warn err
            sleep(20i)
        end
    end

    @assert isfile(joinpath(path, "Project.toml")) "spurious network error: clone failed, bailing out"

    name, _ = splitext(basename(url))
    registries = joinpath(first(DEPOT_PATH), "registries")
    general = joinpath(registries, "General")
    versions = joinpath(general, name[1:1], name, "Versions.toml")
    if !isfile(versions)
        mkpath(general)
        run(setenv(`tar xf $general.tar.gz`; dir = general))
    end
    @assert isfile(versions)

    version_dict = TOML.parse(read(versions, String))
    stable = VersionNumber.(keys(version_dict)) |> maximum
    tag = LibGit2.GitObject(repo, "v$stable")
    hash = string(LibGit2.target(tag))
    LibGit2.checkout!(repo, hash)
    nothing
end

pkg_version(name) =
    string(Pkg.Types.read_package(normpath(@__DIR__, "..", name, "Project.toml")).version)

fake_supported_version!(path) = begin
    toml = joinpath(path, "Project.toml")
    # fake supported versions for testing (for `Pkg.develop`)
    parsed_toml = TOML.parse(read(toml, String))
    parsed_toml["compat"]["RecipesBase"] = pkg_version("RecipesBase")
    parsed_toml["compat"]["RecipesPipeline"] = pkg_version("RecipesPipeline")
    parsed_toml["compat"]["PlotsBase"] = pkg_version("PlotsBase")
    parsed_toml["compat"]["Plots"] = pkg_version("Plots")
    open(toml, "w") do io
        TOML.print(io, parsed_toml)
    end
    print(read(toml, String))
    nothing
end

test_stable(pkg::String) = begin
    Pkg.activate(; temp = true)
    mktempdir() do tmpd
        for dn in ("RecipesBase", "RecipesPipeline", "PlotsBase", "")
            Pkg.develop(; path = joinpath(@__DIR__, "..", dn))
        end

        pkg_dir = joinpath(tmpd, "$pkg.jl")
        failsafe_clone_checkout(pkg_dir, "https://github.com/JuliaPlots/$pkg.jl")
        fake_supported_version!(pkg_dir)

        Pkg.develop(; path = pkg_dir)
        Pkg.test(pkg)
    end
    nothing
end

test_stable("StatsPlots")
test_stable("GraphRecipes")
