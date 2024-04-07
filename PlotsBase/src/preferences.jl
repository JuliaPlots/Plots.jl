# from github.com/JuliaPackaging/Preferences.jl/blob/master/README.md:
# "Preferences that are accessed during compilation are automatically marked as compile-time preferences"
# ==> this must always be done during precompilation, otherwise
# the cache will not invalidate when preferences change
const DEFAULT_BACKEND = lowercase(load_preference(PlotsBase, "default_backend", "gr"))

function default_backend()
    # environment variable preempts the `Preferences` based mechanism
    sym = get(ENV, "PLOTSBASE_DEFAULT_BACKEND", DEFAULT_BACKEND) |> lowercase |> Symbol
    backend(PlotsBase.backend_type(sym))
end

function set_default_backend!(
    backend::Union{Nothing,AbstractString,Symbol} = nothing;
    force = true,
    kw...,
)
    if backend ≡ nothing
        delete_preferences!(PlotsBase, "default_backend"; force, kw...)
    else
        # NOTE: `_check_installed` already throws a warning
        if (value = lowercase(string(backend))) |> PlotsBase._check_installed ≢ nothing
            set_preferences!(PlotsBase, "default_backend" => value; force, kw...)
        end
    end
    nothing
end

function diagnostics(io::IO = stdout)
    origin = if has_preference(PlotsBase, "default_backend")
        "`Preferences`"
    elseif haskey(ENV, "PLOTSBASE_DEFAULT_BACKEND")
        "environment variable"
    else
        "fallback"
    end
    if (be = backend_name()) ≡ :none
        @info "no `PlotsBase` backends currently initialized"
    else
        be_name = string(PlotsBase.backend_package_name(be))
        @info "selected `PlotsBase` backend: $be_name, from $origin"
        Pkg.status(
            ["PlotsBase", "RecipesBase", "RecipesPipeline", be_name];
            mode = Pkg.PKGMODE_MANIFEST,
            io,
        )
    end
    nothing
end
