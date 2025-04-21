module StatsPlots

using Reexport
import RecipesBase: recipetype
using RecipesPipeline
@reexport using PlotsBase
import PlotsBase.Commons: _cycle, mm

using LinearAlgebra: eigen, diagm
using Distributions
using StatsBase

using MultivariateStats: MultivariateStats
using AbstractFFTs: fft, ifft
using Interpolations
using NaNMath

import Clustering: Hclust, nnodes
import KernelDensity

@recipe f(k::KernelDensity.UnivariateKDE) = k.x, k.density
@recipe f(k::KernelDensity.BivariateKDE) = k.x, k.y, permutedims(k.density)

@shorthands cdensity

export dataviewer

isvertical(plotattributes) =
    let val = get(plotattributes, :orientation, missing)
        val ≡ missing || val in (:vertical, :v)
    end

include("corrplot.jl")
include("cornerplot.jl")
include("distributions.jl")
include("boxplot.jl")
include("dotplot.jl")
include("violin.jl")
include("ecdf.jl")
include("hist.jl")
include("marginalhist.jl")
include("marginalscatter.jl")
include("marginalkde.jl")
include("bar.jl")
include("dendrogram.jl")
include("andrews.jl")
include("ordinations.jl")
include("covellipse.jl")
include("errorline.jl")

function dataviewer end  # InteractExt

end # module
