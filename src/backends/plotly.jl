
# https://plot.ly/javascript/getting-started

# ---------------------------------------------------------------------------

function _create_plot(pkg::PlotlyPackage; kw...)
  d = Dict(kw)
  # TODO: create the window/canvas/context that is the plot within the backend (call it `o`)
  # TODO: initialize the plot... title, xlabel, bgcolor, etc
  Plot(nothing, pkg, 0, d, Dict[])
end


function _add_series(::PlotlyPackage, plt::Plot; kw...)
  d = Dict(kw)
  # TODO: add one series to the underlying package
  push!(plt.seriesargs, d)
  plt
end

function _add_annotations{X,Y,V}(plt::Plot{PlotlyPackage}, anns::AVec{@compat(Tuple{X,Y,V})})
  for ann in anns
    # TODO: add the annotation to the plot
  end
end

# ----------------------------------------------------------------

function _before_update_plot(plt::Plot{PlotlyPackage})
end

# TODO: override this to update plot items (title, xlabel, etc) after creation
function _update_plot(plt::Plot{PlotlyPackage}, d::Dict)
end

function _update_plot_pos_size(plt::PlottingObject{PlotlyPackage}, d::Dict)
end

# ----------------------------------------------------------------

# accessors for x/y data

function Base.getindex(plt::Plot{PlotlyPackage}, i::Int)
  series = plt.o.lines[i]
  series.x, series.y
end

function Base.setindex!(plt::Plot{PlotlyPackage}, xy::Tuple, i::Integer)
  series = plt.o.lines[i]
  series.x, series.y = xy
  plt
end

# ----------------------------------------------------------------

function _create_subplot(subplt::Subplot{PlotlyPackage})
  # TODO: build the underlying Subplot object.  this is where you might layout the panes within a GUI window, for example
end

function _expand_limits(lims, plt::Plot{PlotlyPackage}, isx::Bool)
  # TODO: call expand limits for each plot data
end

function _remove_axis(plt::Plot{PlotlyPackage}, isx::Bool)
  # TODO: if plot is inner subplot, might need to remove ticks or axis labels
end

# ----------------------------------------------------------------

function Base.writemime(io::IO, ::MIME"image/png", plt::PlottingObject{PlotlyPackage})
  # TODO: write a png to io
end

function open_browser_window(filename::AbstractString)
  @osx_only   return run(`open $(filename)`)
  @linux_only return run(`xdg-open $(filename)`)
  @windows_only return run(`$(ENV["COMSPEC"]) /c start $(filename)`)
  warn("Unknown OS... cannot open browser window.")
end

function build_plotly_json()
end

function Base.display(::PlotsDisplay, plt::Plot{PlotlyPackage})

  filename = string(tempname(), ".html")
  output = open(filename, "w")
  w, h = plt.plotargs[:size]

  write(output,
      """
      <!DOCTYPE html>
      <html>
        <head>
          <title>Plots.jl (Plotly)</title>
          <meta charset="utf-8">
          <script src="$(Pkg.dir("Plots"))/src/backends/plotly-latest.min.js"></script>
        </head>
          <div id="myplot" style="width:$(w)px;height:$(h)px;"></div>
          <script charset="utf-8">
            PLOT = document.getElementById('myplot');
            Plotly.plot(PLOT, [{
                  x: [1, 2, 3, 4, 5],
                  y: [1, 2, 4, 8, 16]
                }], 
              {margin: { t: 0 }});
          """)

  # build_plotly_json(plt)
  # print(output, json)

  write(output,
          """
          </script>
      </html>
      """)
  close(output)

  open_browser_window(filename)
end

function Base.display(::PlotsDisplay, plt::Subplot{PlotlyPackage})
  # TODO: display/show the subplot
end
