
abstract PlotRecipe

getRecipeXY(recipe::PlotRecipe) = Float64[], Float64[]
getRecipeArgs(recipe::PlotRecipe) = ()

plot(recipe::PlotRecipe, args...; kw...) = plot(getRecipeXY(recipe)..., args...; getRecipeArgs(recipe)..., kw...)
plot!(recipe::PlotRecipe, args...; kw...) = plot!(getRecipeXY(recipe)..., args...; getRecipeArgs(recipe)..., kw...)
plot!(plt::Plot, recipe::PlotRecipe, args...; kw...) = plot!(getRecipeXY(recipe)..., args...; getRecipeArgs(recipe)..., kw...)


# -------------------------------------------------

type EllipseRecipe <: PlotRecipe
    w::Float64
    h::Float64
    x::Float64
    y::Float64
    θ::Float64
end
EllipseRecipe(w,h,x,y) = EllipseRecipe(w,h,x,y,0)

# return x,y coords of a rotated ellipse, centered at the origin
function rotatedEllipse(w, h, x, y, θ, rotθ)
    # coord before rotation
    xpre = w * cos(θ)
    ypre = h * sin(θ)
    
    # rotate
    xrot = xpre * cos(rotθ) + ypre * sin(rotθ)
    yrot = ypre * cos(rotθ) - xpre * sin(rotθ)

    # translate
    xrot + x, yrot + y
end

function getRecipeXY(ep::EllipseRecipe)
    x, y = unzip([rotatedEllipse(ep.w, ep.h, ep.x, ep.y, u, ep.θ) for u in linspace(0,2π,100)])
    right = rotatedEllipse(ep.w, ep.h, ep.x, ep.y, 0, ep.θ)
    top = rotatedEllipse(ep.w, ep.h, ep.x, ep.y, 0.5π, ep.θ)
    linex = Float64[top[1], ep.x, right[1]]
    liney = Float64[top[2], ep.y, right[2]]
    Any[x, linex], Any[y, liney]
end

function getRecipeArgs(ep::EllipseRecipe)
    d = Dict()
    d[:line] = (3, [:dot :solid], [:red :blue], :path)
    d
end

