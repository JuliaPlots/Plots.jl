using CompileBot

botconfig = BotConfig(
    "Plots",
    version = [v"1.6", v"1.7"],  # <<< keep versions in sync with .github/workflows/SnoopCompile.yml
    # else_version = v"1.8",
)
