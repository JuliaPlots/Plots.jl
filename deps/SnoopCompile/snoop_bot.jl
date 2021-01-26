using CompileBot

snoop_bot(
    BotConfig(
        "Plots",
    ),
    joinpath(@__DIR__, "precompile_script.jl"),
)
