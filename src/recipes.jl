
abstract PlotRecipe

getRecipeXY(recipe::PlotRecipe) = Float64[], Float64[]
getRecipeArgs(recipe::PlotRecipe) = ()

plot(recipe::PlotRecipe, args...; kw...) = plot(getRecipeXY(recipe)..., args...; getRecipeArgs(recipe)..., kw...)
plot!(recipe::PlotRecipe, args...; kw...) = plot!(getRecipeXY(recipe)..., args...; getRecipeArgs(recipe)..., kw...)
plot!(plt::Plot, recipe::PlotRecipe, args...; kw...) = plot!(getRecipeXY(recipe)..., args...; getRecipeArgs(recipe)..., kw...)


# -------------------------------------------------

function rotate(x::Real, y::Real, θ::Real; center = (0,0))
    cx = x - center[1]
    cy = y - center[2]
    xrot = cx * cos(θ) - cy * sin(θ)
    yrot = cy * cos(θ) + cx * sin(θ)
    xrot + center[1], yrot + center[2]
end

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
    # # coord before rotation
    xpre = w * cos(θ)
    ypre = h * sin(θ)

    # rotate and translate
    r = rotate(xpre, ypre, rotθ)
    x + r[1], y + r[2]
end

function getRecipeXY(ep::EllipseRecipe)
    x, y = unzip([rotatedEllipse(ep.w, ep.h, ep.x, ep.y, u, ep.θ) for u in linspace(0,2π,100)])
    top = rotate(0, ep.h, ep.θ)
    right = rotate(ep.w, 0, ep.θ)
    linex = Float64[top[1], 0, right[1]] + ep.x
    liney = Float64[top[2], 0, right[2]] + ep.y
    Any[x, linex], Any[y, liney]
end

function getRecipeArgs(ep::EllipseRecipe)
    [(:line, (3, [:dot :solid], [:red :blue], :path))]
end

