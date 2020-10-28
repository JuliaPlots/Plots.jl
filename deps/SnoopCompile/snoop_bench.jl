using CompileBot

snoop_bench(
    BotConfig(
        "Plots",
        yml_path= "SnoopCompile.yml",
        else_os = "linux",
        else_version = "1.5",
    ),
    joinpath(@__DIR__, "precompile_script.jl"),
)
