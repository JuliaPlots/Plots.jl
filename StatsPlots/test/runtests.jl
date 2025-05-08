using MultivariateStats
using Distributions
using StableRNGs
using Clustering
using PlotsBase
using StatsBase
using RDatasets
using Interact
using NaNMath
using Test

using StatsPlots
import GR
gr()

const iris = dataset("datasets", "iris")
const singers = dataset("lattice", "singer")

const Widgets = Base.get_extension(StatsPlots, :InteractExt).Widgets
@test Widgets isa Module

@testset "grouped histogram" begin
    gpl = groupedhist(
        rand(StableRNG(1337), 1000),
        yscale = :log10,
        ylims = (1e-2, 1e4),
        bar_position = :stack,
    )
    @test NaNMath.minimum(gpl[1][1][:y]) ≤ 1e-2
    @test NaNMath.minimum(gpl[1][1][:y]) > 0
    gpl = groupedhist(
        rand(StableRNG(1337), 1000),
        yscale = :log10,
        ylims = (1e-2, 1e4),
        bar_position = :dodge,
    )
    @test NaNMath.minimum(gpl[1][1][:y]) ≤ 1e-2
    @test NaNMath.minimum(gpl[1][1][:y]) > 0

    data = [1, 1, 1, 1, 2, 1]
    mask = (collect(1:6) .< 5)
    gpl1 = groupedhist(data[mask], group = mask[mask], color = 1)
    gpl2 = groupedhist(data[.!mask], group = mask[.!mask], color = 2)
    gpl12 = groupedhist(data, group = mask, nbins = 5, bar_position = :stack)
    @test NaNMath.maximum(gpl12[1][end][:y]) == NaNMath.maximum(gpl1[1][1][:y])
    data = [10 12; 1 1; 0.25 0.25]
    gplr = groupedbar(data)
    @test NaNMath.maximum(gplr[1][1][:y]) == 10
    @test NaNMath.maximum(gplr[1][end][:y]) == 12
    gplr = groupedbar(data, bar_position = :stack)
    @test NaNMath.maximum(gplr[1][1][:y]) == 22
    @test NaNMath.maximum(gplr[1][end][:y]) == 12
end # testset

@testset "dendrogram" begin
    # Example from https://en.wikipedia.org/wiki/Complete-linkage_clustering
    wiki_example = [
        0 17 21 31 23
        17 0 30 34 21
        21 30 0 28 39
        31 34 28 0 43
        23 21 39 43 0
    ]
    clustering = hclust(wiki_example, linkage = :complete)

    xs, ys = StatsPlots.treepositions(clustering, true, :vertical)

    @test xs == [
        2.0 1.0 4.0 1.75
        2.0 1.0 4.0 1.75
        3.0 2.5 5.0 4.5
        3.0 2.5 5.0 4.5
    ]

    @test ys == [
        0.0 0.0 0.0 23.0
        17.0 23.0 28.0 43.0
        17.0 23.0 28.0 43.0
        0.0 17.0 0.0 28.0
    ]

    D = rand(StableRNG(1337), 10, 10)
    D += D'
    pl = hclust(D, linkage = :single)
    @test show(devnull, pl) isa Nothing
end

@testset "histogram" begin
    data = randn(StableRNG(1337), 1_000)
    @test 0.2 < StatsPlots.wand_bins(data) < 0.4
end

@testset "distributions" begin
    @testset "univariate" begin
        pbern = plot(Bernoulli(0.25))
        @test pbern[1][1][:x][1:2] == zeros(2)
        @test pbern[1][1][:x][4:5] == ones(2)
        @test pbern[1][1][:y][[1, 4]] == zeros(2)
        @test pbern[1][1][:y][[2, 5]] == [0.75, 0.25]

        pdirac = plot(Dirac(0.25))
        @test pdirac[1][1][:x][1:2] == [0.25, 0.25]
        @test pdirac[1][1][:y][1:2] == [0, 1]

        ppois_unbounded = plot(Poisson(1))
        @test ppois_unbounded[1][1][:x] isa AbstractVector
        @test ppois_unbounded[1][1][:x][1:2] == zeros(2)
        @test ppois_unbounded[1][1][:x][4:5] == ones(2)
        @test ppois_unbounded[1][1][:y][[1, 4]] == zeros(2)
        @test ppois_unbounded[1][1][:y][[2, 5]] ==
              pdf.(Poisson(1), ppois_unbounded[1][1][:x][[1, 4]])

        pnonint = plot(Bernoulli(0.75) - 1 // 2)
        @test pnonint[1][1][:x][1:2] == [-1 // 2, -1 // 2]
        @test pnonint[1][1][:x][4:5] == [1 // 2, 1 // 2]
        @test pnonint[1][1][:y][[1, 4]] == zeros(2)
        @test pnonint[1][1][:y][[2, 5]] == [0.25, 0.75]

        pmix = plot(
            MixtureModel([Bernoulli(0.75), Bernoulli(0.5)], [0.5, 0.5]);
            components = false,
        )
        @test pmix[1][1][:x][1:2] == zeros(2)
        @test pmix[1][1][:x][4:5] == ones(2)
        @test pmix[1][1][:y][[1, 4]] == zeros(2)
        @test pmix[1][1][:y][[2, 5]] == [0.375, 0.625]

        dzip = MixtureModel([Dirac(0), Poisson(1)], [0.1, 0.9])
        pzip = plot(dzip; components = false)
        @test pzip[1][1][:x] isa AbstractVector
        @test pzip[1][1][:y][2:3:end] == pdf.(dzip, Int.(pzip[1][1][:x][1:3:end]))
    end

    dist = Gamma(2)
    scatter(dist, leg = false)
    bar!(dist, func = cdf, alpha = 0.3)
end

@testset "ordinations" begin
    @testset "MDS" begin
        X = randn(StableRNG(1337), 4, 100)
        M = fit(MultivariateStats.MDS, X; maxoutdim = 3, distances = false)
        Y = MultivariateStats.predict(M)'

        mds_plt = plot(M)
        @test mds_plt[1][1][:x] == Y[:, 1]
        @test mds_plt[1][1][:y] == Y[:, 2]
        @test mds_plt[1][:xaxis][:guide] == "MDS1"
        @test mds_plt[1][:yaxis][:guide] == "MDS2"

        mds_plt2 = plot(M; mds_axes = (3, 1, 2))
        @test mds_plt2[1][1][:x] == Y[:, 3]
        @test mds_plt2[1][1][:y] == Y[:, 1]
        @test mds_plt2[1][1][:z] == Y[:, 2]
        @test mds_plt2[1][:xaxis][:guide] == "MDS3"
        @test mds_plt2[1][:yaxis][:guide] == "MDS1"
        @test mds_plt2[1][:zaxis][:guide] == "MDS2"
    end
end

@testset "errorline" begin
    @testset "input types" begin
        x = 1:10
        # test for floats
        y = rand(StableRNG(1337), 10, 100) .* collect(1:2:20)
        @test errorline(x, y)[1][1][:x] == x # x-input
        @test all(
            round.(errorline(x, y)[1][1][:y], digits = 3) .==
            round.(mean(y, dims = 2), digits = 3),
        ) # mean of y
        @test all(
            round.(errorline(x, y)[1][1][:ribbon], digits = 3) .==
            round.(std(y, dims = 2), digits = 3),
        ) # std of y
        # test for ints
        y = reshape(1:100, 10, 10)
        @test all(errorline(x, y)[1][1][:y] .== mean(y, dims = 2))
        @test all(
            round.(errorline(x, y)[1][1][:ribbon], digits = 3) .==
            round.(std(y, dims = 2), digits = 3),
        )
        # test colors
        y = rand(StableRNG(1337), 10, 100, 3) .* collect(1:2:20)
        c = palette(:default)
        e = errorline(x, y)
        @test colordiff(c[1], e[1][1][:linecolor]) == 0.0
        @test colordiff(c[2], e[1][2][:linecolor]) == 0.0
        @test colordiff(c[3], e[1][3][:linecolor]) == 0.0
    end

    @testset "example" begin
        rng = StableRNG(1337)
        x = 1:10
        y = fill(NaN, 10, 100, 6)
        for i ∈ axes(y, 3)
            y[:, :, i] =
                collect(1:2:20) .+ 5rand(rng, 10, 100) .* collect(1:2:20) .+ 100rand(rng)
        end

        pl = errorline(x, y[:, :, 1], errorstyle = :ribbon, label = "Ribbon")
        errorline!(
            x,
            y[:, :, 2],
            errorstyle = :stick,
            label = "Stick",
            secondarycolor = :matched,
        )
        errorline!(x, y[:, :, 3], errorstyle = :plume, label = "Plume")
        errorline!(x, y[:, :, 4], errortype = :sem)
        errorline!(x, y[:, :, 5], errortype = :percentile)
        errorline!(x, y[:, :, 6], errortype = :percentile, errorstyle = :stick)
        @test show(devnull, pl) isa Nothing
    end
end

@testset "qqplot" begin
    rng = StableRNG(1337)
    x = rand(rng, Normal(), 100)
    y = rand(rng, Cauchy(), 100)
    pl = plot(
        qqplot(x, y, qqline = :fit),  # qqplot of two samples, show a fitted regression line
        qqplot(Cauchy, y),            # compare with a Cauchy distribution fitted to y; pass an instance (e.g. Normal(0,1)) to compare with a specific distribution
        qqnorm(x, qqline = :R),        # the :R default line passes through the 1st and 3rd quartiles of the distribution
    )
    @test show(devnull, pl) isa Nothing
end

@testset "marginalhist" begin
    rng = StableRNG(1337)
    pl = marginalhist(rand(rng, 100), rand(rng, 100))
    @test show(devnull, pl) isa Nothing
end

@testset "marginalscatter" begin
    rng = StableRNG(1337)
    pl = marginalscatter(rand(rng, 100), rand(rng, 100))
    @test show(devnull, pl) isa Nothing
end

@testset "marginalkde" begin
    rng = StableRNG(1337)
    x = randn(rng, 1024)
    y = randn(rng, 1024)
    pl = marginalkde(x, x + y)
    @test show(devnull, pl) isa Nothing
end

@testset "violin" begin
    y = [i * randn(StableRNG(1337), 100) for i ∈ 1:4]
    violin(y, median = true)
    violin(y, quantiles = [0.1, 0.5, 0.9], linecolor = :white, linewidth = 3)
    violin(y, quantiles = 3, mean = true)
end

@testset "violin df" begin
    pl = violin(
        repeat([0.1, 0.2, 0.3], outer = 100),
        randn(StableRNG(1337), 300),
        side = :right,
    )
    @test show(devnull, pl) isa Nothing

    @df singers violin(
        string.(:VoicePart),
        :Height,
        side = :right,
        linewidth = 0,
        label = "Scala",
    )
    @df singers dotplot!(
        string.(:VoicePart),
        :Height,
        side = :right,
        marker = (:black, stroke(0)),
        label = "",
    )
end

@testset "groupedviolin" begin
    df = DataFrame(
        x = repeat(["A", "B"], inner = 10),
        y = (1:20) .+ randn(20),
        g = repeat(["Group 1", "Group 2"], inner = 5, outer = 2),
    )
    @df df groupedviolin(:x, :y; group = :g)
end

@testset "density" begin
    pl = density(rand(StableRNG(1337), 100_000), label = "density(rand())")
    @test show(devnull, pl) isa Nothing
end

@testset "covellipse" begin
    pl = covellipse([0, 2], [2 1; 1 4]; n_std = 2, showaxes = true, label = "cov1")
    @test show(devnull, pl) isa Nothing
end

@testset "ecdf" begin
    pl = plot(StatsBase.ecdf(randn(StableRNG(1337), 100)), label = "Normal")
    ecdfplot!(rand(Cauchy(), 100); label = "Cauchy")
    @test show(devnull, pl) isa Nothing
end

@testset "corrplot / cornerplot" begin
    M = randn(StableRNG(1337), 1_000, 4)
    @. M[:, 2] += 0.8sqrt(abs(M[:, 1])) - 0.5M[:, 3] + 5
    @. M[:, 3] -= 0.7M[:, 1]^2 + 2
    pl = corrplot(M; label = ["x$i" for i ∈ 1:4])
    @test show(devnull, pl) isa Nothing

    pl = cornerplot(M)
    @test show(devnull, pl) isa Nothing
end

@testset "boxplot / dotplot / violin" begin
    @df singers violin(string.(:VoicePart), :Height, show_mean = true, show_median = true)
    @df singers boxplot!(string.(:VoicePart), :Height, fillalpha = 0.75, linewidth = 2)
    @df singers dotplot!(string.(:VoicePart), :Height, marker = (:black, stroke(0)))
    @test true
end

@testset "ea_histogram" begin
    rng = StableRNG(1337)
    a = [randn(rng, 100); randn(rng, 100) .+ 3; randn(rng, 100) ./ 2 .+ 3]
    pl = ea_histogram(a, bins = :scott, fillalpha = 0.4)
    @test show(devnull, pl) isa Nothing
end

@testset "andrewsplot" begin
    @df iris andrewsplot(:Species, cols(1:4), legend = :topleft)
end

@testset "interaction" begin
    dv = dataviewer(iris)
    @test true
end

@testset "boxplot" begin
    # credits to stackoverflow.com/a/71467031
    boxed = [
        [
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            3,
            7,
            26,
            80,
            170,
            322,
            486,
            688,
            817,
            888,
            849,
            783,
            732,
            624,
            500,
            349,
            232,
            130,
            49,
        ],
        [
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            2,
            28,
            83,
            181,
            318,
            491,
            670,
            761,
            849,
            843,
            862,
            799,
            646,
            481,
            361,
            225,
            98,
            50,
        ],
        [
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            2,
            8,
            28,
            80,
            179,
            322,
            493,
            660,
            753,
            803,
            832,
            823,
            783,
            657,
            541,
            367,
            223,
            121,
            62,
        ],
        [
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            1,
            7,
            23,
            84,
            171,
            312,
            463,
            640,
            778,
            834,
            820,
            763,
            752,
            655,
            518,
            374,
            244,
            133,
            52,
        ],
        [
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            1,
            21,
            70,
            169,
            342,
            527,
            725,
            808,
            861,
            857,
            799,
            688,
            622,
            523,
            369,
            232,
            115,
            41,
        ],
        [
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            2,
            9,
            28,
            76,
            150,
            301,
            492,
            660,
            760,
            823,
            862,
            790,
            749,
            646,
            525,
            352,
            223,
            116,
            54,
        ],
        [
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            1,
            6,
            21,
            64,
            165,
            290,
            434,
            585,
            771,
            852,
            847,
            785,
            739,
            630,
            535,
            354,
            230,
            114,
            42,
        ],
        [
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            1,
            2,
            4,
            19,
            76,
            190,
            337,
            506,
            680,
            775,
            851,
            853,
            816,
            705,
            588,
            496,
            388,
            232,
            127,
            54,
        ],
    ]

    boxes = -0.002:0.0001:0.0012

    xx = repeat(boxes, outer = length(boxed))
    yy = collect(Iterators.flatten(boxed))

    xtick = collect(-0.002:0.0005:0.0012)

    pl = boxplot(xx * 20_000, yy, xticks = (xtick * 20_000, xtick))
    @test show(devnull, pl) isa Nothing
end
