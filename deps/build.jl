
using BinaryProvider # requires BinaryProvider 0.3.0 or later

# If the environmental variable is set, obey that.
# Otherwise, use BinaryProvider `ffmpeg` if we cannot find
# a system version.
if get(ENV, "PLOTS_INSTALL_FFMPEG", "auto") == "true"
    use_bp = true
elseif get(ENV, "PLOTS_INSTALL_FFMPEG", "auto") == "false"
    use_bp = false
elseif get(ENV, "PLOTS_INSTALL_FFMPEG", "auto") == "auto"
    if Sys.which("ffmpeg") === nothing
        use_bp = true
    else
        use_bp = false
    end
end


if use_bp
    @info("Using BinaryProvider `ffmpeg`")

    # Parse some basic command-line arguments
    const verbose = "--verbose" in ARGS
    const prefix = Prefix(get([a for a in ARGS if a != "--verbose"], 1, joinpath(@__DIR__, "usr")))

    products = Product[
        ExecutableProduct(prefix, "ffmpeg", :ffmpeg),
    ]

    dependencies = [
        "https://github.com/JuliaPackaging/Yggdrasil/releases/download/Bzip2-v1.0.6-2/build_Bzip2.v1.0.6.jl",

        "https://github.com/ianshmean/ZlibBuilder/releases/download/v1.2.11/build_Zlib.v1.2.11.jl",
        "https://github.com/SimonDanisch/FDKBuilder/releases/download/0.1.6/build_libfdk.v0.1.6.jl",
        "https://github.com/SimonDanisch/FribidiBuilder/releases/download/0.14.0/build_fribidi.v0.14.0.jl",
        "https://github.com/JuliaGraphics/FreeTypeBuilder/releases/download/v2.9.1-4/build_FreeType2.v2.10.0.jl",
        "https://github.com/JuliaIO/LibassBuilder/releases/download/v0.14.0-2/build_libass.v0.14.0.jl",
        
        "https://github.com/JuliaIO/LAMEBuilder/releases/download/v3.100.0-2/build_liblame.v3.100.0.jl",
        
        "https://github.com/JuliaIO/OggBuilder/releases/download/v1.3.3-7/build_Ogg.v1.3.3.jl",
        "https://github.com/JuliaIO/LibVorbisBuilder/releases/download/v1.3.6-2/build_libvorbis.v1.3.6.jl",
                            
        "https://github.com/JuliaIO/LibVPXBuilder/releases/download/v1.8.0/build_LibVPX.v1.8.0.jl",
        "https://github.com/JuliaIO/x264Builder/releases/download/v2019.5.25-static/build_x264Builder.v2019.5.25.jl",
        "https://github.com/JuliaIO/x265Builder/releases/download/v3.0.0-static/build_x265Builder.v3.0.0.jl",
        
        "https://github.com/JuliaIO/FFMPEGBuilder/releases/download/v4.1.0/build_FFMPEG.v4.1.0.jl"
    ]

    for dependency in dependencies
        file = joinpath(@__DIR__, basename(dependency))
        isfile(file) || download(dependency, file)
        # it's a bit faster to run the build in an anonymous module instead of
        # starting a new julia process

        # Build the dependencies
        Mod = @eval module Anon end
        Mod.include(file)
    end

    write_deps_file(joinpath(@__DIR__, "binary_provider_deps.jl"), products)

else
    @info("Using system `ffmpeg`. If you run into `ffmpeg`-related trouble, trying running `ENV[\"PLOTS_INSTALL_FFMPEG\"]=\"true\"; using Pkg; Pkg.build(\"Plots\")` to use `BinaryProvider`-provided `ffmpeg` instead.")

    
    if isfile("binary_provider_deps.jl")
        rm("binary_provider_deps.jl")
    end
end

#TODO: download https://cdn.plot.ly/plotly-latest.min.js to deps/ if it doesn't exist
file_path = ""
if get(ENV, "PLOTS_HOST_DEPENDENCY_LOCAL", "false") == "true"
    global file_path
    local_fn = joinpath(dirname(@__FILE__), "plotly-latest.min.js")
    if !isfile(local_fn)
        @info("Cannot find deps/plotly-latest.min.js... downloading latest version.")
        download("https://cdn.plot.ly/plotly-latest.min.js", local_fn)
        isfile(local_fn) && (file_path = local_fn)
    else
        file_path = local_fn
    end
end

open("deps.jl", "w") do io
    println(io, "const plotly_local_file_path = $(repr(file_path))")
end
