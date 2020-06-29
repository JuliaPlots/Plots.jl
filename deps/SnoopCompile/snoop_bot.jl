using SnoopCompile

snoop_bot(
    BotConfig(
        "Plots",
        else_os = "linux",
        version = ["1.3", "1", "nightly"],
        else_version = v"1",
    ),
    joinpath(@__DIR__, "precompile_script.jl"),
)
