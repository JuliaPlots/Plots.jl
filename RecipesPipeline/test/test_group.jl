function _extract_group_attributes_old_slow_known_good_implementation(
    v,
    args...;
    legend_entry = string,
)
    group_labels = collect(unique(sort(v)))
    n = length(group_labels)
    group_indices =
        Vector{Int}[filter(i -> v[i] == glab, eachindex(v)) for glab ∈ group_labels]
    RecipesPipeline.GroupBy(map(legend_entry, group_labels), group_indices)
end

sc = ["C", "C", "C", "A", "A", "A", "B", "B", "D"]
mc = rand(StableRNG(1), map(i -> "xx" * "$(i % 6)", 1:6), 300)
mp = rand(StableRNG(1), map(i -> "xx" * "$(i % 73)", 1:73), 1_000)
lp = map(i -> "xx" * "$(i % 599)", 1:2_000)

@testset "All" begin
    @testset "Correctness" begin
        res1 = _extract_group_attributes_old_slow_known_good_implementation(sc)
        res2 = RecipesPipeline._extract_group_attributes(sc)
        @test res1.group_labels == res2.group_labels
        @test res1.group_indices == res2.group_indices
    end
    @testset "Correctness (medium)" begin
        res1 = _extract_group_attributes_old_slow_known_good_implementation(mc)
        res2 = RecipesPipeline._extract_group_attributes(mc)
        @test res1.group_labels == res2.group_labels
        @test res1.group_indices == res2.group_indices
    end
    @testset "Performance (medium)" begin
        t1 = @benchmark res1 =
            _extract_group_attributes_old_slow_known_good_implementation(mp)
        t2 = @benchmark res2 = RecipesPipeline._extract_group_attributes(mp)
        @test !BenchmarkTools.isregression(judge(median(t2), median(t1)))
    end
    @testset "Performance (large ish)" begin
        t1 = @benchmark res1 =
            _extract_group_attributes_old_slow_known_good_implementation(lp)
        t2 = @benchmark res2 = RecipesPipeline._extract_group_attributes(lp)
        @test BenchmarkTools.isimprovement(judge(median(t2), median(t1)))
    end

    @test RecipesPipeline._extract_group_attributes(Tuple(sc)) isa RecipesPipeline.GroupBy
    @test RecipesPipeline._extract_group_attributes((; A = [1], B = [2])) isa
          RecipesPipeline.GroupBy
    @test RecipesPipeline._extract_group_attributes(Dict(:A => [1], :B => [2])) isa
          RecipesPipeline.GroupBy

    @testset "_filter_input_data!" begin
        filtered_keys = [:x, :y, :z, :xerror, :yerror, :zerror]
        orig_akw = Dict{Symbol,Any}(k => rand(10) for k ∈ filtered_keys)
        orig_akw[:idxfilter] = [1, 4, 10]

        akw = deepcopy(orig_akw)
        RecipesPipeline._filter_input_data!(akw)
        for k ∈ filtered_keys
            @test akw[k] == orig_akw[k][orig_akw[:idxfilter]]
        end
    end
end
