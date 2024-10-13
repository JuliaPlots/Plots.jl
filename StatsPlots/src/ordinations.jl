@recipe function f(mds::MultivariateStats.MDS{<:Real}; mds_axes = (1, 2))
    length(mds_axes) in [2, 3] || throw(ArgumentError("Can only accept 2 or 3 mds axes"))
    xax = mds_axes[1]
    yax = mds_axes[2]
    tfm = collect(MultivariateStats.predict(mds)')

    xlabel --> "MDS$xax"
    ylabel --> "MDS$yax"
    seriestype := :scatter
    aspect_ratio --> 1

    if length(mds_axes) == 3
        zax = mds_axes[3]
        zlabel --> "MDS$zax"
        tfm[:, xax], tfm[:, yax], tfm[:, zax]
    else
        tfm[:, xax], tfm[:, yax]
    end
end

#= This needs to wait on a different PCA API in MultivariateStats.jl
@recipe function f(pca::PCA{<:Real}; pca_axes=(1,2))
end
=#
