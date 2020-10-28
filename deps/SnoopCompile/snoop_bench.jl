using CompileBot

snoop_bench(
    BotConfig(
        "Plots",
        yml_path= "SnoopCompile.yml",
        os = "linux",
        version = "1.5",
    ),
    joinpath(@__DIR__, "precompile_script.jl"),
)
