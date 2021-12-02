include("snoop_bot_config.jl")

snoop_bench(
    botconfig,
    joinpath(@__DIR__, "precompile_script.jl"),
)
