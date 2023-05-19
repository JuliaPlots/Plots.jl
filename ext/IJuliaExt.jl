module IJuliaExt

import Plots: @ext_imp_use, Plots, Plot
using Base64

# Change back when loading as extension again:
#@ext_imp_use :import IJulia
import ..IJulia

using Plots: _init_ijulia_plotting, _ijulia_display_dict

if IJulia.inited
    _init_ijulia_plotting()
    IJulia.display_dict(plt::Plot) = _ijulia_display_dict(plt)
end

# IJulia only... inline display
function Plots.inline(plt::Plot = Plots.current())
    IJulia.clear_output(true)
    display(IJulia.InlineDisplay(), plt)
end

end  # module
