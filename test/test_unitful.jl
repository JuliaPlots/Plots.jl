using Plots, Test
using Unitful
using Unitful: m, cm, s, DimensionError
using Latexify, UnitfulLatexify
# Some helper functions to access the subplot labels and the series inside each test plot
xguide(pl, idx = length(pl.subplots)) = Plots.get_guide(pl.subplots[idx].attr[:xaxis])
yguide(pl, idx = length(pl.subplots)) = Plots.get_guide(pl.subplots[idx].attr[:yaxis])
zguide(pl, idx = length(pl.subplots)) = Plots.get_guide(pl.subplots[idx].attr[:zaxis])
ctitle(pl, idx = length(pl.subplots)) = pl.subplots[idx].attr[:colorbar_title]
xseries(pl, idx = length(pl.series_list)) = pl.series_list[idx].plotattributes[:x]
yseries(pl, idx = length(pl.series_list)) = pl.series_list[idx].plotattributes[:y]
zseries(pl, idx = length(pl.series_list)) = pl.series_list[idx].plotattributes[:z]

testfile = tempname() * ".png"

macro isplot(ex) # @isplot macro to streamline tests
    return :(@test $(esc(ex)) isa Plots.Plot)
end

@testset "heatmap" begin
    x = (1:3)m
    @isplot heatmap(x * x', clims = (1, 7)) # unitless
    @isplot heatmap(x * x', clims = (2m^2, 8m^2)) # units
    @isplot heatmap(x * x', clims = (2.0e6u"mm^2", 7.0e-6u"km^2")) # conversion
    @isplot heatmap(1:3, (1:3)m, x * x', clims = (1m^2, 7.0e-6u"km^2")) # mixed
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
        @test yguide(plot(y, ylabel = "hello", unitformat = :nounit)) == "hello"
        pl = plot(y, ylabel = "")
        @test yguide(pl) == ""
        @test yguide(plot!(pl, -y)) == ""
        @test yguide(plot(y, ylabel = "", unitformat = :round)) == "m"
        pl = plot(y; ylabel = "hello")
        plot!(pl, -y)
        @test yguide(pl) == "hello (m)"
        plot!(pl, -y; ylabel = "goodbye")
        @test yguide(pl) == "goodbye (m)"
        pl = plot(y)
        plot!(pl, -y; ylabel = "hello")
        @test yguide(pl) == "hello (m)"
    end

    @testset "yunit" begin
        @test yguide(plot(y, yunit = cm)) == "cm"
        @test yseries(plot(y, yunit = cm)) ≈ ustrip.(cm, y)
        @test plot([copy(y), copy(y)], yunit = cm) |> pl -> yseries(pl, 1) ≈ yseries(pl, 2)
        pl = plot(y)
        @test_logs (:warn, r"Overriding unit") plot!(pl; yunit = cm)
        @test yguide(pl) == "cm"
        plot!(pl; ylabel = "hello")
        @test yguide(pl) == "hello (cm)"
    end

    @testset "ylims" begin # Using all(lims .≈ lims) because of uncontrolled type conversions?
        @test all(ylims(plot(y, ylims = (-1, 3))) .≈ (-1, 3))
        @test all(ylims(plot(y, ylims = (-1m, 3m))) .≈ (-1, 3))
        @test all(ylims(plot(y, ylims = (-100cm, 300cm))) .≈ (-1, 3))
        @test all(ylims(plot(y, ylims = (-100cm, 3m))) .≈ (-1, 3))
        @test all(ylims(plot!(; ylims = (-2cm, 1cm))) .≈ (-0.02, 0.01))
        @test_throws DimensionError begin
            pl = plot(y)
            plot!(pl; ylims = (-1s, 5s))
            savefig(pl, testfile)
        end
    end

    @testset "yticks" begin
        compare_yticks(pl, expected_ticks) = all(first(first(yticks(pl))) .≈ expected_ticks)
        encompassing_ylims = (-1m, 6m)
        @test compare_yticks(plot(y; ylims = encompassing_ylims, yticks = (1:5)m), 1:5)
        @test compare_yticks(
            plot(y; ylims = encompassing_ylims, yticks = [1cm, 3cm]),
            [0.01, 0.03],
        )
        @test compare_yticks(
            plot!(; ylims = encompassing_ylims, yticks = [-1cm, 4cm]),
            [-0.01, 0.04],
        )
        @test_throws DimensionError begin
            pl = plot(y)
            plot!(pl; yticks = (1:5)s)
            savefig(pl, testfile)
        end
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
        @test yguide(plot(args...; kwargs..., unitformat = :nounit)) == "hello"
    end
end

@testset "With functions" begin
    x, y = randn(3), randn(3)
    @testset "plot(f, x) / plot(x, f)" begin
        f(x) = x^2
        @test plot(f, x * m) isa Plots.Plot
        @test plot(x * m, f) isa Plots.Plot
        g(x) = x * m # If the unit comes from the function only then it throws
        @test_throws DimensionError plot(x, g)
        @test_throws DimensionError plot(g, x)
    end
    @testset "plot(x, y, f)" begin
        f(x, y) = x * y
        @test plot(x * m, y * s, f) isa Plots.Plot
        @test plot(x * m, y, f) isa Plots.Plot
        @test plot(x, y * s, f) isa Plots.Plot
        g(x, y) = x * y * m # If the unit comes from the function only then it throws
        @test_throws DimensionError plot(x, y, g)
    end
    @testset "plot(f, u)" begin
        f(x) = x^2
        pl = plot(x * m, f.(x * m))
        @test plot!(pl, f, m) isa Plots.Plot
        @test_throws DimensionError plot!(pl, f, s)
        pl = plot(f, m)
        @test xguide(pl) == string(m)
        @test yguide(pl) == string(m^2)
        g(x) = exp(x / (3m))
        @test plot(g, u"m") isa Plots.Plot
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
            @test plot(x * m) isa Plots.Plot
            @test plot(x * m, ylabel = "x") isa Plots.Plot
            @test plot(x * m, ylims = (-1, 1)) isa Plots.Plot
            @test plot(x * m, ylims = (-1, 1) .* m) isa Plots.Plot
            @test plot(x * m, yunit = u"km") isa Plots.Plot
            @test plot(x * m, xticks = (1:3) * m) isa Plots.Plot
        end

        @testset "Two arrays" begin
            @test plot(x * m, y * s) isa Plots.Plot
            @test plot(x * m, y * s, xlabel = "x") isa Plots.Plot
            @test plot(x * m, y * s, xlims = (-1, 1)) isa Plots.Plot
            @test plot(x * m, y * s, xlims = (-1, 1) .* m) isa Plots.Plot
            @test plot(x * m, y * s, xunit = u"km") isa Plots.Plot
            @test plot(x * m, y * s, ylabel = "y") isa Plots.Plot
            @test plot(x * m, y * s, ylims = (-1, 1)) isa Plots.Plot
            @test plot(x * m, y * s, ylims = (-1, 1) .* s) isa Plots.Plot
            @test plot(x * m, y * s, yunit = u"ks") isa Plots.Plot
            @test plot(x * m, y * s, yticks = (1:3) * s) isa Plots.Plot
            @test scatter(x * m, y * s) isa Plots.Plot
            if dtype ≠ Symbol("Vectors of vectors")
                @test scatter(x * m, y * s, zcolor = z * (m / s)) isa Plots.Plot
            end
        end

        @testset "Three arrays" begin
            @test plot(x * m, y * s, z * (m / s)) isa Plots.Plot
            @test plot(x * m, y * s, z * (m / s), xlabel = "x") isa Plots.Plot
            @test plot(x * m, y * s, z * (m / s), xlims = (-1, 1)) isa Plots.Plot
            @test plot(x * m, y * s, z * (m / s), xlims = (-1, 1) .* m) isa Plots.Plot
            @test plot(x * m, y * s, z * (m / s), xunit = u"km") isa Plots.Plot
            @test plot(x * m, y * s, z * (m / s), ylabel = "y") isa Plots.Plot
            @test plot(x * m, y * s, z * (m / s), ylims = (-1, 1)) isa Plots.Plot
            @test plot(x * m, y * s, z * (m / s), ylims = (-1, 1) .* s) isa Plots.Plot
            @test plot(x * m, y * s, z * (m / s), yunit = u"ks") isa Plots.Plot
            @test plot(x * m, y * s, z * (m / s), zlabel = "z") isa Plots.Plot
            @test plot(x * m, y * s, z * (m / s), zlims = (-1, 1)) isa Plots.Plot
            @test plot(x * m, y * s, z * (m / s), zlims = (-1, 1) .* (m / s)) isa Plots.Plot
            @test plot(x * m, y * s, z * (m / s), zunit = u"km/hr") isa Plots.Plot
            @test plot(x * m, y * s, z * (m / s), zticks = (1:2) * m / s) isa Plots.Plot
            @test scatter(x * m, y * s, z * (m / s)) isa Plots.Plot
        end

        @testset "Unitful/unitless combinations" begin
            mystr(x::Array{<:Quantity}) = "Q"
            mystr(x::Array) = "A"
            @testset "plot($(mystr(xs)), $(mystr(ys)))" for xs in [x, x * m],
                    ys in [y, y * s]

                @test plot(xs, ys) isa Plots.Plot
            end
            @testset "plot($(mystr(xs)), $(mystr(ys)), $(mystr(zs)))" for xs in [x, x * m],
                    ys in [y, y * s],
                    zs in [z, z * (m / s)]

                @test plot(xs, ys, zs) isa Plots.Plot
            end
        end
    end

    @testset "scatter(x::$(us[1]), y::$(us[2]))" for us in collect(
            Iterators.product(fill([1, u"m", u"s"], 2)...),
        )
        x, y = rand(10) * us[1], rand(10) * us[2]
        @test scatter(x, y) isa Plots.Plot
        @test scatter(x, y, markersize = x) isa Plots.Plot

        @test scatter(x, y, marker_z = x) isa Plots.Plot
        if us[1] != us[2] && us[1] != 1 && us[2] != 1 # Non-matching dimensions
            @test_throws DimensionError scatter!(x, y, marker_z = y)
        else # One is dimensionless, or have same dimensions
            @test scatter!(x, y, marker_z = y) isa Plots.Plot #
        end
    end

    @testset "contour(x::$(us[1]), y::$(us[2]))" for us in collect(
            Iterators.product(fill([1, u"m", u"s"], 2)...),
        )
        x, y = (1:0.01:2) * us[1], (1:0.02:2) * us[2]
        z = x' ./ y
        @test contour(x, y, z) isa Plots.Plot
        @test contourf(x, y, z) isa Plots.Plot
    end

    @testset "ProtectedString" begin
        y = rand(10) * u"m"
        @test plot(y, label = P"meters") isa Plots.Plot
    end

    @testset "latexify as unitformat" begin
        y = rand(10) * u"m^-1"
        @test yguide(plot(y, ylabel = "hello", unitformat = latexify)) == "\$hello\\;\\left/\\;\\mathrm{m}^{-1}\\right.\$"

        uf = (l, u) -> l * " (" * latexify(u) * ")"
        @test yguide(plot(y, ylabel = "hello", unitformat = uf)) == "hello (\$\\mathrm{m}^{-1}\$)"
    end

    @testset "colorbar title" begin

        x, y = (1:0.01:2) * m, (1:0.02:2) * s
        z = x' ./ y
        pl = contour(x, y, z)
        @test ctitle(pl) ∈ ["m s^-1", "m s⁻¹"]
        pl = contourf(x, y, z, zunit = u"km/hr")
        @test ctitle(pl) ∈ ["km hr^-1", "km hr⁻¹"]
        pl = heatmap(x, y, z, zunit = u"cm/s", zunitformat = :square, colorbar_title = "v")
        @test ctitle(pl) ∈ ["v [cm s^-1]", "v [cm s⁻¹]"]
    end

    @testset "twinx (#4750)" begin
        y = rand(10) * u"m"
        pl = plot(y; xlabel = "check", ylabel = "hello")
        pl2 = twinx(pl)
        plot!(pl2, 1 ./ y; ylabel = "goodbye", yunit = u"cm^-1")
        @test pl isa Plots.Plot
        @test pl2 isa Plots.Subplot
        @test yguide(pl, 1) == "hello (m)"
        # on MacOS the superscript gets rendered with Unicode, on Ubuntu and Windows no
        @test yguide(pl, 2) ∈ ["goodbye (cm^-1)", "goodbye (cm⁻¹)"]
        @test xguide(pl, 1) == "check"
        @test xguide(pl, 2) == ""
    end

    @testset "bad link" begin
        pl1 = plot(rand(10) * u"m")
        pl2 = plot(rand(10) * u"s")
        # TODO: On Julia 1.8 and above, can replace ErrorException with part of error message.
        @test_throws ErrorException plot(pl1, pl2; link = :y)
    end

end

@testset "Comparing apples and oranges" begin
    x1 = rand(10) * u"m"
    x2 = rand(10) * u"cm"
    x3 = rand(10) * u"s"
    pl = plot(x1)
    pl = plot!(pl, x2)
    @test yguide(pl) == "m"
    @test yseries(pl) ≈ ustrip.(x2) / 100
    @test_throws DimensionError plot!(pl, x3) # can't place seconds on top of meters!
end

@testset "Bare units" begin
    pl = plot(u"m", u"s")
    @test xguide(pl) == "m"
    @test yguide(pl) == "s"
    @test iszero(length(pl.series_list[1].plotattributes[:y]))
    hline!(pl, [1u"hr"])
    @test yguide(pl) == "s"
end

@testset "Inset subplots" begin
    x1 = rand(10) * u"m"
    x2 = rand(10) * u"s"
    pl = plot(x1)
    pl = plot!(x2, inset = bbox(0.5, 0.5, 0.3, 0.3), subplot = 2)
    @test yguide(pl, 1) == "m"
    @test yguide(pl, 2) == "s"
end

@testset "Missing values" begin
    x = 1:5
    y = [1.0 * u"s", 2.0 * u"s", missing, missing, missing]
    pl = plot(x, y)
    @test yguide(pl, 1) == "s"
end

@testset "Errors" begin
    x = rand(10) * u"mm"
    ex = rand(10) * u"μm"
    y = rand(10) * u"s"
    ey = rand(10) * u"ms"
    pl = plot(x, y, xerr = ex, yerr = ey)
    @test pl isa Plots.Plot
    @test xguide(pl) == "mm"
    @test yguide(pl) == "s"
    pl = plot(x, y, xerr = ex, yerr = (ey, ey ./ 2))
    @test pl isa Plots.Plot
    @test xguide(pl) == "mm"
    @test yguide(pl) == "s"
end

@testset "Ribbon" begin
    x = (1:10) * u"mm"
    y = rand(10) * u"s"
    ribbon = rand(10) * u"ms"
    ribbon = 100 * rand(10) * u"ms"
    pl = plot(x, y, ribbon = ribbon)
    @test pl isa Plots.Plot
    @test xguide(pl) == "mm"
    @test yguide(pl) == "s"
    pl = plot(x, y, ribbon = (ribbon, ribbon .* 2))
    @test pl isa Plots.Plot
    @test xguide(pl) == "mm"
    @test yguide(pl) == "s"
end

@testset "Fillrange" begin
    x = (1:10) * u"mm"
    y = rand(10) * u"s"
    fillrange = rand(10) * u"ms"
    pl = plot(x, y, fillrange = fillrange)
    @test pl isa Plots.Plot
    @test xguide(pl) == "mm"
    @test yguide(pl) == "s"
end

@testset "Aspect ratio" begin
    pl = plot((1:10)u"m", (1:10)u"dm"; aspect_ratio = :equal)
    savefig(pl, testfile) # Force a render, to make it evaluate aspect ratio
    @test abs(-(ylims(pl)...)) > 50
    plot!(pl, (3:4)u"m", (4:5)u"m")
    @test first(pl.subplots)[:aspect_ratio] == 1 // 10 # This is what "equal" means when yunit==xunit/10
    pl = plot((1:10)u"m", (1:10)u"dm"; aspect_ratio = 2)
    savefig(pl, testfile)
    @test 25 < abs(-(ylims(pl)...)) < 50
    pl = plot((1:10)u"m", (1:10)u"s"; aspect_ratio = 1u"m/s")
    savefig(pl, testfile)
    @test 7.5 < abs(-(ylims(pl)...)) < 12.5
    @test_throws DimensionError savefig(
        plot((1:10)u"m", (1:10)u"s"; aspect_ratio = :equal),
        testfile,
    )
end

# https://github.com/jw3126/UnitfulRecipes.jl/issues/60
@testset "Start with empty plot" begin
    pl = plot()
    plot!(pl, (1:3)m)
    @test yguide(pl) == "m"
end

# https://github.com/jw3126/UnitfulRecipes.jl/issues/79
@testset "Annotate" begin
    pl = plot([0, 1]u"s", [0, 1]u"m")
    annotate!(pl, [0.25]u"s", [0.5]u"m", text("annotation"))
    savefig(pl, testfile)
    @test length(pl.subplots[1].attr[:annotations]) == 1
end

@testset "AbstractProtectedString" begin
    str = P"mass"
    @test pointer(str) isa Ptr
    @test pointer(str, 1) isa Ptr
    @test isvalid(str, 1)
    @test ncodeunits(str) == 4
    @test codeunit(str) == UInt8
end

@testset "Logunits plots" begin
    u = (1:3)u"B"
    v = (1:3)u"dB"
    x = (1:3)u"dBV"
    y = (1:3)u"V"
    pl = plot(u, x)
    @test pl isa Plots.Plot
    @test xguide(pl) == "B"
    @test yguide(pl) == "dBV"
    @test plot!(pl, v, y) isa Plots.Plot
    pl = plot(v, y)
    @test pl isa Plots.Plot
    @test plot!(pl, u, x) isa Plots.Plot
end

if Sys.islinux() && Sys.which("pdflatex") ≢ nothing
    @testset "pgfplotsx exponents" begin  # github.com/JuliaPlots/Plots.jl/issues/4722
        Plots.with(:pgfplotsx) do
            pl = plot([1u"s", 2u"s"], [1u"m/s^2", 2u"m/s^2"])
            savefig(pl, tempname() * ".pdf")

            x, y = rand(10) * u"km", rand(10) * u"hr"
            pl = plot(x, y, x ./ y)
            savefig(pl, tempname() * ".pdf")
        end
    end
end
