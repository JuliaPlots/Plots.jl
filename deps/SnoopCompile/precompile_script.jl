using Plots

Plots.test_examples(:gr, skip = Plots._backend_skips[:gr])
Plots.test_examples(:plotly, skip = Plots._backend_skips[:plotly])
