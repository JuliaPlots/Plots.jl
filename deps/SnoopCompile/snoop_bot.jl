using SnoopCompile

snoop_bot(
    BotConfig(
        "Plots",
        os = ["linux", "windows", "macos"],
        else_os = "linux",
        version = ["1.3", "1.4", "nightly"],
        else_version = "1.4",
    ),
    joinpath(@__DIR__, "precompile_script.jl"),
)
