using CompileBot

snoop_bench(
    BotConfig(
        "RecipesPipeline",
        yml_path= "SnoopCompile.yml",
        else_os = "linux",
        else_version = "1.5",
    )
)
