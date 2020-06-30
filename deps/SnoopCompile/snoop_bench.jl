using SnoopCompile

snoop_bench(
    BotConfig("Plots", version = ["1.3.1", "1.4.2", "nightly"]),
    joinpath(@__DIR__, "precompile_script.jl"),
)
