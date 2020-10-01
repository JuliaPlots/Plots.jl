using CompileBot

snoop_bot(
    BotConfig(
        "Plots",
        yml_path= "SnoopCompile.yml",
        else_os = "linux",
        else_version = "1.4",
    ),
    joinpath(@__DIR__, "precompile_script.jl"),
)
