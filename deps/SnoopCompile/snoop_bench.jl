using SnoopCompile

snoop_bench(
    BotConfig("Plots", version = [v"1.2", v"1"]),
    joinpath(@__DIR__, "precompile_script.jl"),
)
