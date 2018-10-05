
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
