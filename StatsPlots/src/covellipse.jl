"""
    covellipse(μ, Σ; showaxes=false, n_std=1, n_ellipse_vertices=100)

Plot a confidence ellipse of the 2×2 covariance matrix `Σ`, centered at `μ`.
The ellipse is the contour line of a Gaussian density function with mean `μ`
and variance `Σ` at `n_std` standard deviations.
If `showaxes` is true, the two axes of the ellipse are also plotted.
"""
@userplot CovEllipse

@recipe function f(c::CovEllipse; showaxes = false, n_std = 1, n_ellipse_vertices = 100)
    μ, S = _covellipse_args(c.args; n_std = n_std)

    θ = range(0, 2π; length = n_ellipse_vertices)
    A = S * [cos.(θ)'; sin.(θ)']

    @series begin
        seriesalpha --> 0.3
        Shape(μ[1] .+ A[1, :], μ[2] .+ A[2, :])
    end
    showaxes && @series begin
        label := false
        linecolor --> "gray"
        ([μ[1] + S[1, 1], μ[1], μ[1] + S[1, 2]], [μ[2] + S[2, 1], μ[2], μ[2] + S[2, 2]])
    end
end

function _covellipse_args(
    (μ, Σ)::Tuple{AbstractVector{<:Real},AbstractMatrix{<:Real}};
    n_std::Real,
)
    size(μ) == (2,) && size(Σ) == (2, 2) ||
        error("covellipse requires mean of length 2 and covariance of size 2×2.")
    λ, U = eigen(Σ)
    μ, n_std * U * diagm(.√λ)
end
_covellipse_args(args; n_std) = error(
    "Wrong inputs for covellipse: $(typeof.(args)). " *
    "Expected real-valued vector μ, real-valued matrix Σ.",
)
