using CompileBot

snoop_bench(
    BotConfig(
        "Plots",
    ),
    joinpath(@__DIR__, "precompile_script.jl"),
)
