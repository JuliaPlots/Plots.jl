# [Output](@id output)

**A `Plot` is only displayed when returned** (a semicolon will suppress the return), or if explicitly displayed with `display(plt)`, `gui()`, or by adding `show = true` to your plot command.


!!! tip
    You can have MATLAB-like interactive behavior by setting the default value: `default(show = true)`.

### Standalone window
Calling `gui(plt)` will open a standalone window.  `gui()`, like `plot!(...)`, applies to the "current" `Plot`.  Returning a `Plot` object to the `REPL` is like calling `gui(plt)`.


### Jupyter / IJulia
`Plot`s are shown inline when returned to a cell.  The default output format is `svg` for backends that support it.
This can be changed by the `html_output_format` attribute, with alias `fmt`:

```julia
plot(rand(10); fmt = :png)
```

### savefig / format
`Plots` support 2 different versions per save-command.
Command `savefig` chooses file type automatically based on the file extension.

```julia
savefig(filename_string)  # save the most recent fig as filename_string (such as "output.png")
savefig(plot_ref, filename_string)  # save the fig referenced by plot_ref as filename_string (such as "output.png")
```

In addition, `Plots` exports the convenience function `png(filename::AbstractString)`.
Other functions such as `PlotsBase.pdf` or `PlotsBase.svg` remain unexported, since they might conflict with exports from other packages.
In this case the string fn containing the filename does not need a file extension.

```julia
png(filename_string)  # save the current fig as png with filename filename_string (such as "output.png")
png(plot_ref, filename_string)  # save the fig referenced by plot_ref as png with filename filename_string (such as "output.png")
```

#### File formats supported by most graphical backends
- `png` (default output format for `savefig`, if no file extension is given)
- `svg`
- `pdf`

When not using `savefig`, the default output format depends on the environment (e.g., when using `IJulia`/`Jupyter`).

#### Supported output file formats
Note: not all backends support every output file format !
A simple table showing which format is supported by which backend

| format   | backends                                                              |
| :------- | :-------------------------------------------------------------------- |
| `eps`    | `plotlyjs`, `pythonplot`                                              |
| `html`   | `plotly`, `plotlyjs `                                                 |
| `json`   | `plotly`, `plotlyjs`                                                  |
| `pdf`    | `gr`, `pythonplot`, `plotlyjs`, `pgfplotsx`, `gaston`                 |
| `png`    | `gr`, `pythonplot`, `unicodeplots`, `plotlyjs`, `pgfplotsx`, `gaston` |
| `ps `    | `gr`, `pythonplot`                                                    |
| `svg`    | `gr`, `pythonplot`, `pgfplotsx`, `plotlyjs`, `gaston`                 |
| `tex`    | `pythonplot`, `pgfplotsx`                                             |
| `text`   | `unicodeplots`, `hdf5`                                                |

Supported file formats can be written to an `IO` stream via, for example, `png(myplot, pipebuffer::IO)`, so the image file can be passed via a PipeBuffer to other functions, eg. `Cairo.read_from_png(pipebuffer::IO)`.
