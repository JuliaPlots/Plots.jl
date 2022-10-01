function _extract_group_attributes_old_slow_known_good_implementation(v, args...; legend_entry = string)
    group_labels = collect(unique(sort(v)))
    n = length(group_labels)
    #if n > 100
    #    @warn("You created n=$n groups... Is that intended?")
    #end
    group_indices = Vector{Int}[filter(i -> v[i] == glab, eachindex(v)) for glab in group_labels]
    RecipesPipeline.GroupBy(map(legend_entry, group_labels), group_indices)
end

sc = [ "C","C","C","A", "A", "A","B","B","D"]
mc = rand([ "xx"*"$(i%6)" for i in 1:6],300)
mp = rand([ "xx"*"$(i%73)" for i in 1:73],1000)
lp = [ "xx"*"$(i%599)" for i in 1:2000]

@testset "Group" begin
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
        t1 = @benchmark res1 = _extract_group_attributes_old_slow_known_good_implementation(mp)
        t2 = @benchmark res2 = RecipesPipeline._extract_group_attributes(mp)
        @test !BenchmarkTools.isregression(judge(median(t2),median(t1)))
    end
    @testset "Performance (large ish)" begin 
        t1 = @benchmark res1 = _extract_group_attributes_old_slow_known_good_implementation(lp)
        t2 = @benchmark res2 = RecipesPipeline._extract_group_attributes(lp)
        @test BenchmarkTools.isimprovement(judge(median(t2),median(t1))) 
    end
end

