using CompileBot

snoop_bot(
    BotConfig(
        "Plots",
        yml_path= "SnoopCompile.yml",
    ),
    joinpath(@__DIR__, "precompile_script.jl"),
)
