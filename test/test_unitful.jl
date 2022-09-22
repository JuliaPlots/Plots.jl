using Unitful: m, s, cm, DimensionError

testfile = "test.png"

# Some helper functions to access the subplot labels and the series inside each test plot
xguide(plt, idx = length(plt.subplots)) =
    plt.subplots[idx].attr[:xaxis].plotattributes[:guide]
yguide(plt, idx = length(plt.subplots)) =
    plt.subplots[idx].attr[:yaxis].plotattributes[:guide]
zguide(plt, idx = length(plt.subplots)) =
    plt.subplots[idx].attr[:zaxis].plotattributes[:guide]
xseries(plt, idx = length(plt.series_list)) = plt.series_list[idx].plotattributes[:x]
yseries(plt, idx = length(plt.series_list)) = plt.series_list[idx].plotattributes[:y]
zseries(plt, idx = length(plt.series_list)) = plt.series_list[idx].plotattributes[:z]

macro isplot(ex) # @isplot macro to streamline tests
    :(@test $(esc(ex)) isa Plot)
end

@testset "heatmap" begin
    x = (1:3)m
    @isplot heatmap(x * x', clims = (1, 7)) # unitless
    @isplot heatmap(x * x', clims = (2m^2, 8m^2)) # units
    @isplot heatmap(x * x', clims = (2e6u"mm^2", 7e-6u"km^2")) # conversion
    @isplot heatmap(1:3, (1:3)m, x * x', clims = (1m^2, 7e-6u"km^2")) # mixed
end

@testset "plot(y)" begin
    y = rand(3)m

    @testset "no keyword argument" begin
        @test yguide(plot(y)) == "m"
        @test yseries(plot(y)) ≈ ustrip.(y)
    end

    @testset "ylabel" begin
        @test yguide(plot(y, ylabel = "hello")) == "hello (m)"
        @test yguide(plot(y, ylabel = P"hello")) == "hello"
        @test yguide(plot(y, ylabel = "")) == ""
        pl = plot(y; ylabel = "hello")
        plot!(pl, -y)
        @test yguide(pl) == "hello (m)"
    end

    @testset "yunit" begin
        @test yguide(plot(y, yunit = cm)) == "cm"
        @test yseries(plot(y, yunit = cm)) ≈ ustrip.(cm, y)
    end

    @testset "ylims" begin # Using all(lims .≈ lims) because of uncontrolled type conversions?
        @test all(ylims(plot(y, ylims = (-1, 3))) .≈ (-1, 3))
        @test all(ylims(plot(y, ylims = (-1m, 3m))) .≈ (-1, 3))
        @test all(ylims(plot(y, ylims = (-100cm, 300cm))) .≈ (-1, 3))
        @test all(ylims(plot(y, ylims = (-100cm, 3m))) .≈ (-1, 3))
    end

    @testset "keyword combinations" begin
        @test yguide(plot(y, yunit = cm, ylabel = "hello")) == "hello (cm)"
        @test yseries(plot(y, yunit = cm, ylabel = "hello")) ≈ ustrip.(cm, y)
        @test all(ylims(plot(y, yunit = cm, ylims = (-1, 3))) .≈ (-1, 3))
        @test all(ylims(plot(y, yunit = cm, ylims = (-1, 3))) .≈ (-1, 3))
        @test all(ylims(plot(y, yunit = cm, ylims = (-100cm, 300cm))) .≈ (-100, 300))
        @test all(ylims(plot(y, yunit = cm, ylims = (-100cm, 3m))) .≈ (-100, 300))
    end
end

@testset "plot(x,y)" begin
    x, y = randn(3)m, randn(3)s

    @testset "no keyword argument" begin
        @test xguide(plot(x, y)) == "m"
        @test xseries(plot(x, y)) ≈ ustrip.(x)
        @test yguide(plot(x, y)) == "s"
        @test yseries(plot(x, y)) ≈ ustrip.(y)
    end

    @testset "labels" begin
        @test xguide(plot(x, y, xlabel = "hello")) == "hello (m)"
        @test xguide(plot(x, y, xlabel = P"hello")) == "hello"
        @test yguide(plot(x, y, ylabel = "hello")) == "hello (s)"
        @test yguide(plot(x, y, ylabel = P"hello")) == "hello"
        @test xguide(plot(x, y, xlabel = "hello", ylabel = "hello")) == "hello (m)"
        @test xguide(plot(x, y, xlabel = P"hello", ylabel = P"hello")) == "hello"
        @test yguide(plot(x, y, xlabel = "hello", ylabel = "hello")) == "hello (s)"
        @test yguide(plot(x, y, xlabel = P"hello", ylabel = P"hello")) == "hello"
    end

    @testset "unitformat" begin
        args = (x, y)
        kwargs = (:xlabel => "hello", :ylabel => "hello")
        @test yguide(plot(args...; kwargs..., unitformat = nothing)) == "hello s"
        @test yguide(
            plot(
                args...;
                kwargs...,
                unitformat = (l, u) -> string(u, " is the unit of ", l),
            ),
        ) == "s is the unit of hello"
        @test yguide(plot(args...; kwargs..., unitformat = ", dear ")) == "hello, dear s"
        @test yguide(plot(args...; kwargs..., unitformat = (", dear ", " esq."))) ==
              "hello, dear s esq."
        @test yguide(
            plot(args...; kwargs..., unitformat = ("well ", ", dear ", " esq.")),
        ) == "well hello, dear s esq."
        @test yguide(plot(args...; kwargs..., unitformat = '?')) == "hello ? s"
        @test yguide(plot(args...; kwargs..., unitformat = ('<', '>'))) == "hello <s>"
        @test yguide(plot(args...; kwargs..., unitformat = ('A', 'B', 'C'))) == "Ahello BsC"
        @test yguide(plot(args...; kwargs..., unitformat = false)) == "hello s"
        @test yguide(plot(args...; kwargs..., unitformat = true)) == "hello (s)"
        @test yguide(plot(args...; kwargs..., unitformat = :round)) == "hello (s)"
        @test yguide(plot(args...; kwargs..., unitformat = :square)) == "hello [s]"
        @test yguide(plot(args...; kwargs..., unitformat = :curly)) == "hello {s}"
        @test yguide(plot(args...; kwargs..., unitformat = :angle)) == "hello <s>"
        @test yguide(plot(args...; kwargs..., unitformat = :slash)) == "hello / s"
        @test yguide(plot(args...; kwargs..., unitformat = :slashround)) == "hello / (s)"
        @test yguide(plot(args...; kwargs..., unitformat = :slashsquare)) == "hello / [s]"
        @test yguide(plot(args...; kwargs..., unitformat = :slashcurly)) == "hello / {s}"
        @test yguide(plot(args...; kwargs..., unitformat = :slashangle)) == "hello / <s>"
        @test yguide(plot(args...; kwargs..., unitformat = :verbose)) ==
              "hello in units of s"
    end
end

@testset "With functions" begin
    x, y = randn(3), randn(3)
    @testset "plot(f, x) / plot(x, f)" begin
        f(x) = x^2
        @test plot(f, x * m) isa Plot
        @test plot(x * m, f) isa Plot
        g(x) = x * m # If the unit comes from the function only then it throws
        @test_throws DimensionError plot(x, g) isa Plot
        @test_throws DimensionError plot(g, x) isa Plot
    end
    @testset "plot(x, y, f)" begin
        f(x, y) = x * y
        @test plot(x * m, y * s, f) isa Plot
        @test plot(x * m, y, f) isa Plot
        @test plot(x, y * s, f) isa Plot
        g(x, y) = x * y * m # If the unit comes from the function only then it throws
        @test_throws DimensionError plot(x, y, g) isa Plot
    end
    @testset "plot(f, u)" begin
        f(x) = x^2
        pl = plot(x * m, f.(x * m))
        @test plot!(pl, f, m) isa Plot
        @test_throws DimensionError plot!(pl, f, s) isa Plot
        pl = plot(f, m)
        @test xguide(pl) == string(m)
        @test yguide(pl) == string(m^2)
        g(x) = exp(x / (3m))
        @test plot(g, u"m") isa Plot
    end
end

@testset "More plots" begin
    @testset "data as $dtype" for dtype in
                                  [:Vectors, :Matrices, Symbol("Vectors of vectors")]
        if dtype == :Vectors
            x, y, z = randn(10), randn(10), randn(10)
        elseif dtype == :Matrices
            x, y, z = randn(10, 2), randn(10, 2), randn(10, 2)
        else
            x, y, z = [rand(10), rand(20)], [rand(10), rand(20)], [rand(10), rand(20)]
        end

        @testset "One array" begin
            @test plot(x * m) isa Plot
            @test plot(x * m, ylabel = "x") isa Plot
            @test plot(x * m, ylims = (-1, 1)) isa Plot
            @test plot(x * m, ylims = (-1, 1) .* m) isa Plot
            @test plot(x * m, yunit = u"km") isa Plot
            @test plot(x * m, xticks = (1:3) * m) isa Plot
        end

        @testset "Two arrays" begin
            @test plot(x * m, y * s) isa Plot
            @test plot(x * m, y * s, xlabel = "x") isa Plot
            @test plot(x * m, y * s, xlims = (-1, 1)) isa Plot
            @test plot(x * m, y * s, xlims = (-1, 1) .* m) isa Plot
            @test plot(x * m, y * s, xunit = u"km") isa Plot
            @test plot(x * m, y * s, ylabel = "y") isa Plot
            @test plot(x * m, y * s, ylims = (-1, 1)) isa Plot
            @test plot(x * m, y * s, ylims = (-1, 1) .* s) isa Plot
            @test plot(x * m, y * s, yunit = u"ks") isa Plot
            @test plot(x * m, y * s, yticks = (1:3) * s) isa Plot
            @test scatter(x * m, y * s) isa Plot
            if dtype ≠ Symbol("Vectors of vectors")
                @test scatter(x * m, y * s, zcolor = z * (m / s)) isa Plot
            end
        end

        @testset "Three arrays" begin
            @test plot(x * m, y * s, z * (m / s)) isa Plot
            @test plot(x * m, y * s, z * (m / s), xlabel = "x") isa Plot
            @test plot(x * m, y * s, z * (m / s), xlims = (-1, 1)) isa Plot
            @test plot(x * m, y * s, z * (m / s), xlims = (-1, 1) .* m) isa Plot
            @test plot(x * m, y * s, z * (m / s), xunit = u"km") isa Plot
            @test plot(x * m, y * s, z * (m / s), ylabel = "y") isa Plot
            @test plot(x * m, y * s, z * (m / s), ylims = (-1, 1)) isa Plot
            @test plot(x * m, y * s, z * (m / s), ylims = (-1, 1) .* s) isa Plot
            @test plot(x * m, y * s, z * (m / s), yunit = u"ks") isa Plot
            @test plot(x * m, y * s, z * (m / s), zlabel = "z") isa Plot
            @test plot(x * m, y * s, z * (m / s), zlims = (-1, 1)) isa Plot
            @test plot(x * m, y * s, z * (m / s), zlims = (-1, 1) .* (m / s)) isa Plot
            @test plot(x * m, y * s, z * (m / s), zunit = u"km/hr") isa Plot
            @test plot(x * m, y * s, z * (m / s), zticks = (1:2) * m / s) isa Plot
            @test scatter(x * m, y * s, z * (m / s)) isa Plot
        end

        @testset "Unitful/unitless combinations" begin
            mystr(x::Array{<:Quantity}) = "Q"
            mystr(x::Array) = "A"
            @testset "plot($(mystr(xs)), $(mystr(ys)))" for xs in [x, x * m],
                ys in [y, y * s]

                @test plot(xs, ys) isa Plot
            end
            @testset "plot($(mystr(xs)), $(mystr(ys)), $(mystr(zs)))" for xs in [x, x * m],
                ys in [y, y * s],
                zs in [z, z * (m / s)]

                @test plot(xs, ys, zs) isa Plot
            end
        end
    end

    @testset "scatter(x::$(us[1]), y::$(us[2]))" for us in collect(
        Iterators.product(fill([1, u"m", u"s"], 2)...),
    )
        x, y = rand(10) * us[1], rand(10) * us[2]
        @test scatter(x, y) isa Plot
        @test scatter(x, y, markersize = x) isa Plot
        @test scatter(x, y, line_z = x) isa Plot
    end

    @testset "contour(x::$(us[1]), y::$(us[2]))" for us in collect(
        Iterators.product(fill([1, u"m", u"s"], 2)...),
    )
        x, y = (1:0.01:2) * us[1], (1:0.02:2) * us[2]
        z = x' ./ y
        @test contour(x, y, z) isa Plot
        @test contourf(x, y, z) isa Plot
    end

    @testset "ProtectedString" begin
        y = rand(10) * u"m"
        @test plot(y, label = P"meters") isa Plot
    end
end

@testset "Comparing apples and oranges" begin
    x1 = rand(10) * u"m"
    x2 = rand(10) * u"cm"
    x3 = rand(10) * u"s"
    plt = plot(x1)
    plt = plot!(plt, x2)
    @test yguide(plt) == "m"
    @test yseries(plt) ≈ ustrip.(x2) / 100
    @test_throws DimensionError plot!(plt, x3) # can't place seconds on top of meters!
end

@testset "Bare units" begin
    plt = plot(u"m", u"s")
    @test xguide(plt) == "m"
    @test yguide(plt) == "s"
    @test iszero(length(plt.series_list[1].plotattributes[:y]))
    hline!(plt, [1u"hr"])
    @test yguide(plt) == "s"
end

@testset "Inset subplots" begin
    x1 = rand(10) * u"m"
    x2 = rand(10) * u"s"
    plt = plot(x1)
    plt = plot!(x2, inset = bbox(0.5, 0.5, 0.3, 0.3), subplot = 2)
    @test yguide(plt, 1) == "m"
    @test yguide(plt, 2) == "s"
end

@testset "Missing values" begin
    x = 1:5
    y = [1.0 * u"s", 2.0 * u"s", missing, missing, missing]
    @show typeof(y)
    plt = plot(x, y)
    @test yguide(plt, 1) == "s"
end

@testset "Errors" begin
    x = rand(10) * u"mm"
    ex = rand(10) * u"μm"
    y = rand(10) * u"s"
    ey = rand(10) * u"ms"
    plt = plot(x, y, xerr = ex, yerr = ey)
    @test plt isa Plot
    @test xguide(plt) == "mm"
    @test yguide(plt) == "s"
end

@testset "Ribbon" begin
    x = rand(10) * u"mm"
    y = rand(10) * u"s"
    ribbon = rand(10) * u"ms"
    plt = plot(x, y, ribbon = ribbon)
    @test plt isa Plot
    @test xguide(plt) == "mm"
    @test yguide(plt) == "s"
end

@testset "Fillrange" begin
    x = rand(10) * u"mm"
    y = rand(10) * u"s"
    fillrange = rand(10) * u"ms"
    plt = plot(x, y, fillrange = fillrange)
    @test plt isa Plot
    @test xguide(plt) == "mm"
    @test yguide(plt) == "s"
end

@testset "Aspect ratio" begin
    plt = plot((1:10)u"m", (1:10)u"dm"; aspect_ratio = :equal)
    savefig(plt, testfile) # Force a render, to make it evaluate aspect ratio
    @test abs(-(ylims(plt)...)) > 50
    plt = plot((1:10)u"m", (1:10)u"dm"; aspect_ratio = 2)
    savefig(plt, testfile)
    @test 25 < abs(-(ylims(plt)...)) < 50
    plt = plot((1:10)u"m", (1:10)u"s"; aspect_ratio = 1u"m/s")
    savefig(plt, testfile)
    @test 7.5 < abs(-(ylims(plt)...)) < 12.5
    @test_throws DimensionError savefig(
        plot((1:10)u"m", (1:10)u"s"; aspect_ratio = :equal),
        testfile,
    )
end

# https://github.com/jw3126/UnitfulRecipes.jl/issues/60
@testset "Start with empty plot" begin
    plt = plot()
    plot!(plt, (1:3)m)
    @test yguide(plt) == "m"
end
