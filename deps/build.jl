
#TODO: download https://cdn.plot.ly/plotly-latest.min.js to deps/ if it doesn't exist

local_fn = joinpath(dirname(@__FILE__), "plotly-latest.min.js")
if !isfile(local_fn)
	@info("Cannot find deps/plotly-latest.min.js... downloading latest version.")
	download("https://cdn.plot.ly/plotly-latest.min.js", local_fn)
end
