using CompileBot

botconfig = BotConfig(
    "Plots",
    version = ["1.6", "1.7", "1.8", "nightly"],  # <<< keep these versions in sync with .github/workflows/SnoopCompile.yml
    # else_version = "nightly",
)
