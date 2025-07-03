using RecipesPipeline
using BenchmarkTools
using StableRNGs
using Test

import RecipesPipeline: _prepare_series_data
import RecipesBase

@testset "DefaultsDict" begin
    dd = DefaultsDict(Dict(:foo => 1, :bar => missing), Dict(:foo => nothing, :baz => 'x'))

    @test all(explicitkeys(dd) .== [:bar, :foo])
    @test all(defaultkeys(dd) .== [:baz, :foo])

    @test copy(dd) isa DefaultsDict
    @test RecipesBase.is_explicit(dd, :foo)
    @test RecipesBase.is_default(dd, :baz)
    @test dd[:foo] == 1
    @test dd[:bar] ≡ missing
    @test dd[:baz] == 'x'

    get!(dd, :qux, 100)
    @test dd[:qux] == 100

    delete!(dd, :qux)
    @test !haskey(dd, :qux)
end

@testset "coverage" begin
    @test RecipesPipeline.userrecipe_signature_string((missing, 1)) ==
        "(::Missing, ::Int64)"
    @test RecipesPipeline.typerecipe_signature_string(1) == "(::Type{Int64}, ::Int64)"
    @test RecipesPipeline.plotrecipe_signature_string(:wireframe) ==
        "(::Type{Val{:wireframe}}, ::AbstractPlot)"
    @test RecipesPipeline.seriesrecipe_signature_string(:wireframe) ==
        "(::Type{Val{:wireframe}}, x, y, z)"

    plt = nothing
    plotattributes = Dict(:x => 1, :y => "", :z => nothing, :seriestype => :path)
    kw_list = [:foo, :bar]
    kw = (; foo = 1, bar = nothing)
    @test RecipesPipeline.preprocess_attributes!(plt, plotattributes) isa Nothing
    @test !RecipesPipeline.is_subplot_attribute(plt, :foo)
    @test !is_axis_attribute(plt, :foo)

    @test process_userrecipe!(plt, [:foo], :bar) == [:foo, :bar]
    @test type_alias(plt, :wireframe) ≡ :wireframe

    @test plot_setup!(plt, plotattributes, kw_list) isa Nothing
    @test slice_series_attributes!(plt, kw_list, kw) isa Nothing
    @test process_sliced_series_attributes!(plt, kw_list) isa Nothing

    @test RecipesPipeline.series_defaults(plt) == Dict{Symbol, Any}()
    @test !RecipesPipeline.is_seriestype_supported(plt, :wireframe)
    @test RecipesPipeline.add_series!(plt, kw) isa Nothing

    surface = Surface(zeros(Float32, 1, 2))
    @test copy(surface) isa Surface
    @test eltype(surface) == Float32

    volume = Volume(zeros(Float32, 1, 2, 3))
    @test copy(volume) isa Volume
    @test Array(volume) |> size == (1, 2, 3)
    @test eltype(volume) == Float32

    @test RecipesPipeline._compute_x(nothing, nothing, zeros(2, 3, 4)) == 1:2
    @test RecipesPipeline._compute_x(x -> 2x, 1:3, missing) == [2, 4, 6]

    @test RecipesPipeline._compute_y(nothing, nothing, zeros(2, 3, 4)) == 1:3

    @test RecipesPipeline._compute_z(1:2, 3:4, [5 7; 8 0]) isa Surface

    @test RecipesPipeline._nobigs(zeros(BigFloat, 2)) |> eltype == Float64
    @test RecipesPipeline._nobigs(zeros(BigInt, 2)) |> eltype == Int64

    @test dateformatter(1) == "0001-01-01"
    @test dateformatter(1.0) == "0001-01-01T00:00:00"
    @test datetimeformatter(1) == "0000-12-31T00:00:00.001"
    @test timeformatter(1) == "00:00:00.000000001"
    @test RecipesPipeline.epochdays2epochms(1) == 86_400_000

    @test RecipesBase.is_key_supported("key")
end

@testset "_prepare_series_data" begin
    @test_throws ErrorException _prepare_series_data(:test)
    @test _prepare_series_data(nothing) ≡ nothing
    @test _prepare_series_data((1.0, 2.0)) ≡ (1.0, 2.0)
    @test _prepare_series_data(identity) ≡ identity
    @test _prepare_series_data(1:5:10) ≡ 1:5:10
    a = ones(Union{Missing, Float64}, 100, 100)
    sd = _prepare_series_data(a)
    @test sd == a
    @test eltype(sd) == Float64
    a .= missing
    sd = _prepare_series_data(a)
    @test eltype(sd) == Float64
    @test all(isnan, sd)
    a = fill(missing, 100, 100)
    sd = _prepare_series_data(a)
    @test eltype(sd) == Float64
    @test all(isnan, sd)
    sd = _prepare_series_data(skipmissing(1:5))
    @test length(sd) == 5
    # TODO String, Volume etc
end

@testset "unzip" begin
    x, y, z = unzip([(1.0, 2.0, 3.0), (1.0, 2.0, 3.0)])
    @test all(x .== 1.0) && all(y .== 2.0) && all(z .== 3.0)
    x, y, z = unzip(Tuple{Float64, Float64, Float64}[])
    @test isempty(x) && isempty(y) && isempty(z)
end

@testset "group" begin
    include("test_group.jl")
end
