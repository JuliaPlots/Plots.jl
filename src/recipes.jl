
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

# -------------------------------------------------


"Correlation scatter matrix"
function corrplot{T<:Real,S<:Real}(mat::AMat{T}, corrmat::AMat{S} = cor(mat);
                                   colors = :redsblues,
                                   labels = nothing, kw...)
  m = size(mat,2)
  centers = Float64[mean(extrema(mat[:,i])) for i in 1:m]

  # might be a mistake? 
  @assert m <= 20
  @assert size(corrmat) == (m,m)

  # create a subplot grid, and a gradient from -1 to 1
  p = subplot(rand(0,m^2); n=m^2, leg=false, kw...)
  cgrad = ColorGradient(colors, [-1,1])

  # make all the plots
  for i in 1:m
    for j in 1:m
      idx = p.layout[i,j]
      plt = p.plts[idx]
      if i==j
        # histogram on diagonal
        histogram!(plt, mat[:,i], c=:black, leg=false)
        i > 1 && plot!(plt, yticks = :none)
      elseif i < j
        # plot!(plt, mat[:,j], mat[:,i], l=:hexbin, leg=false)
        # plot!(plt, [0], [0], ann=(0, 0, "Corr:\n$(corrmat[i,j])"), leg=false)
        mi, mj = centers[i], centers[j]
        plot!(plt, [mj], [mi],
                   ann = (mj, mi, text(@sprintf("Corr:\n%0.3f", corrmat[i,j]), 15)),
                   yticks=:none, grid=false)
      else
        # scatter plots off-diagonal, color determined by correlation
        c = RGBA(RGB(getColorZ(cgrad, corrmat[i,j])), 0.3)
        scatter!(plt, mat[:,j], mat[:,i], w=1, ms=3, c=c, leg=false)
      end

      if labels != nothing && length(labels) >= m
        i == m && xlabel!(plt, string(labels[j]))
        j == 1 && ylabel!(plt, string(labels[i]))
      end

      # # replace the plt
      # p.plts[idx] = plt
    end
  end

  # link the axes
  subplot!(p, link = (r,c) -> (true, r!=c))
end


"Sparsity plot... heatmap of non-zero values of a matrix"
function spy{T<:Real}(y::AMat{T}; kw...)
  I,J,V = findnz(y)
  heatmap(J, I; leg=false, yflip=true, kw...)
end

