using SnoopCompile

snoop_bot(
    BotConfig("Plots", version = [v"1.2", v"1", "nightly"]),
    joinpath(@__DIR__, "precompile_script.jl"),
)
