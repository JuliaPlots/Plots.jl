using CompileBot

snoop_bench(
    BotConfig(
        "Plots",
        yml_path= "SnoopCompile.yml",
    ),
    joinpath(@__DIR__, "precompile_script.jl"),
)
