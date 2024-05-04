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
    Pkg.Types.read_package(normpath(@__DIR__, "..", name, "Project.toml")).version |> string

maybe_pin_version!(dict::AbstractDict, name::AbstractString, ver::AbstractString) =
    haskey(dict, name) && (dict[name] = "=$ver")

"fake supported Plots ecosystem versions for using `Pkg.develop`"
fake_supported_versions!(path) = begin
    toml = joinpath(path, "Project.toml")
    parsed_toml = TOML.parse(read(toml, String))
    compat = parsed_toml["compat"]
    maybe_pin_version!(compat, "RecipesBase", pkg_version("RecipesBase"))
    maybe_pin_version!(compat, "RecipesPipeline", pkg_version("RecipesPipeline"))
    maybe_pin_version!(compat, "PlotsBase", pkg_version("PlotsBase"))
    maybe_pin_version!(compat, "Plots", pkg_version(""))
    open(toml, "w") do io
        TOML.print(io, parsed_toml)
    end
    # print(read(toml, String))  # debug
    nothing
end

test_stable(pkg::AbstractString) = begin
    Pkg.activate(; temp = true)
    mktempdir() do tmpd
        for dn in ("RecipesBase", "RecipesPipeline", "PlotsBase", "")
            Pkg.develop(; path = joinpath(@__DIR__, "..", dn))
        end

        pkg_dir = joinpath(tmpd, "$pkg.jl")
        failsafe_clone_checkout(pkg_dir, "https://github.com/JuliaPlots/$pkg.jl")
        fake_supported_versions!(pkg_dir)

        Pkg.develop(; path = pkg_dir)
        Pkg.test(pkg)
    end
    nothing
end

test_stable.(ARGS)
