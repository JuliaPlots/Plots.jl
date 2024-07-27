# [References](@id api)

## Contents
```@contents
Pages = ["api.md"]
Depth = 4
```

## Index

```@index
Pages = ["api.md"]
```

## Public Interface

### Plot specification
```@docs
plot
bbox
grid
@layout
default
theme
with
```

```@autodocs
Modules = [Plots]
Pages   = ["components.jl"]
Order   = [:function]
```

```@autodocs
Modules = [Plots]
Pages   = ["shorthands.jl"]
```

### Animations
```@docs
animate
frame
gif
mov
mp4
webm
@animate
@gif
```

### Retriever

```@docs
current
Plots.xlims
Plots.ylims
Plots.zlims
backend_object
plotattr
```

### Output
```@docs
display
```

```@autodocs
Modules = [Plots]
Pages   = ["output.jl"]
```
