using Preferences
using Plots
using Test

# get `Preferences` set backend, if any
const PREVIOUS_DEFAULT_BACKEND = load_preference(Plots, "default_backend")

include("preferences.jl")

if PREVIOUS_DEFAULT_BACKEND === nothing
    delete_preferences!(Plots, "default_backend")  # restore the absence of a preference
else
    Plots.set_default_backend!(PREVIOUS_DEFAULT_BACKEND)  # reset to previous state
end
