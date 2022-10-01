using CompileBot

botconfig = BotConfig(
    "RecipesPipeline",
    version = ["1.6", "1.7"],  # <<< keep versions in sync with .github/workflows/SnoopCompile.yml
    # else_version = "1.8",
)

snoop_bot(botconfig)
