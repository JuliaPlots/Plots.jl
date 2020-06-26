using Plots

Plots.test_examples(:gr)
Plots.test_examples(:plotly, skip = Plots._backend_skips[:plotly])
