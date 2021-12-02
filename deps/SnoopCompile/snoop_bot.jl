include("snoop_bot_config.jl")

snoop_bot(
    botconfig,
    joinpath(@__DIR__, "precompile_script.jl"),
)
