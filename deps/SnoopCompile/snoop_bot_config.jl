using CompileBot

botconfig = BotConfig(
    "Plots",
    version = [v"1.5", v"1.6", v"1.7"],  # NOTE: keep in sync with .github/workflows/SnoopCompile.yml
    # else_version = v"1.7",
)