# miscellaneous tests (not fitting into other test files)

@testset "Infrastructure" begin
    @test_nowarn JSON.Parser.parse(
        String(read(joinpath(dirname(pathof(Plots)), "..", ".zenodo.json"))),
    )
end

@testset "Plotly standalone" begin
    @test_nowarn Plots._init_ijulia_plotting()
    @test Plots.plotly_local_file_path[] === nothing
    temp = Plots.use_local_dependencies[]
    withenv("PLOTS_HOST_DEPENDENCY_LOCAL" => true) do
        Plots.__init__()
        @test Plots.plotly_local_file_path[] isa String
        @test isfile(Plots.plotly_local_file_path[])
        @test Plots.use_local_dependencies[] = true
        @test_nowarn Plots._init_ijulia_plotting()
    end
    Plots.plotly_local_file_path[] = nothing
    Plots.use_local_dependencies[] = temp
end

@testset "NoFail" begin
    with(:unicodeplots) do
        @test backend() == Plots.UnicodePlotsBackend()

        dsp = TextDisplay(IOContext(IOBuffer(), :color => true))

        @testset "plot" begin
            for plt in [
                histogram([1, 0, 0, 0, 0, 0]),
                plot([missing]),
                plot([missing, missing]),
                plot(fill(missing, 10)),
                plot([missing; 1:4]),
                plot([fill(missing, 10); 1:4]),
                plot([1 1; 1 missing]),
                plot(["a" "b"; missing "d"], [1 2; 3 4]),
            ]
                display(dsp, plt)
            end
            @test_nowarn plot(x -> x^2, 0, 2)
        end

        @testset "bar" begin
            p = bar([3, 2, 1], [1, 2, 3])
            @test p isa Plot
            @test display(dsp, p) isa Nothing
        end

        @testset "gui" begin
            open(tempname(), "w") do io
                redirect_stdout(io) do
                    gui(plot())
                end
            end
        end
    end
end

@testset "Themes" begin
    @test showtheme(:dark) isa Plot
end

@testset "plotattr" begin
    tmp = tempname()
    open(tmp, "w") do io
        redirect_stdout(io) do
            plotattr("seriestype")
            plotattr(:Plot)
            plotattr()
        end
    end
    str = join(readlines(tmp), "")
    @test occursin("seriestype", str)
    @test occursin("Plot attributes", str)
end

@testset "legend" begin
    @test isa(
        Plots.legend_pos_from_angle(20, 0.0, 0.5, 1.0, 0.0, 0.5, 1.0),
        NTuple{2,<:AbstractFloat},
    )
    @test Plots.legend_anchor_index(-1) == 1
    @test Plots.legend_anchor_index(+0) == 2
    @test Plots.legend_anchor_index(+1) == 3

    @test Plots.legend_angle(:foo_bar) == (45, :inner)
    @test Plots.legend_angle(20.0) == Plots.legend_angle((20.0, :inner)) == (20.0, :inner)
    @test Plots.legend_angle((20.0, 10.0)) == (20.0, 10.0)
end

@testset "Axis scales" begin
    with(:unicodeplots) do
        pl = plot(1:5, xscale = :log2, yscale = :ln)
        @test pl[1][:xaxis][:scale] === :log2
        @test pl[1][:yaxis][:scale] === :ln
    end
end

@testset "axis letter" begin
    # a custom type for dispacthing the axis-letter-testing recipe
    struct MyType <: Number
        val::Float64
    end
    value(m::MyType) = m.val
    data = MyType.(sort(randn(20)))

    # A recipe that puts the axis letter in the title
    @recipe function f(::Type{T}, m::T) where {T<:AbstractArray{<:MyType}}
        title --> string(plotattributes[:letter])
        value.(m)
    end

    @testset "orientation" begin
        for f in (histogram, barhist, stephist, scatterhist), o in (:vertical, :horizontal)
            @test f(data, orientation = o).subplots[1].attr[:title] ==
                  (o == :vertical ? "x" : "y")
        end
    end

    @testset "$f" for f in (hline, hspan)
        @test f(data).subplots[1].attr[:title] == "y"
    end

    @testset "$f" for f in (vline, vspan)
        @test f(data).subplots[1].attr[:title] == "x"
    end
end

@testset "plot" begin
    pl = plot(1:5)
    pl2 = plot(pl, tex_output_standalone = true)
    @test !pl[:tex_output_standalone]
    @test pl2[:tex_output_standalone]
    plot!(pl, tex_output_standalone = true)
    @test pl[:tex_output_standalone]
end

@testset "get_axis_limits" begin
    x = [0.1, 5]
    p1 = plot(x, [5, 0.1], yscale = :log10)
    p2 = plot!(identity)
    @test all(RecipesPipeline.get_axis_limits(p1, :x) .== x)
    @test all(RecipesPipeline.get_axis_limits(p2, :x) .== x)
end

@testset "Slicing" begin
    @test plot(1:5, fillrange = 0)[1][1][:fillrange] == 0
    data4 = rand(4, 4)
    mat = reshape(1:8, 2, 4)
    for i in axes(data4, 1)
        for attribute in (:fillrange, :ribbon)
            @test plot(data4; NamedTuple{tuple(attribute)}(0)...)[1][i][attribute] == 0
            @test plot(data4; NamedTuple{tuple(attribute)}(Ref([1, 2]))...)[1][i][attribute] ==
                  [1.0, 2.0]
            @test plot(data4; NamedTuple{tuple(attribute)}(Ref([1 2]))...)[1][i][attribute] ==
                  (iseven(i) ? 2 : 1)
            @test plot(data4; NamedTuple{tuple(attribute)}(Ref(mat))...)[1][i][attribute] ==
                  [2(i - 1) + 1, 2i]
        end
        @test plot(data4, ribbon = (mat, mat))[1][i][:ribbon] ==
              ([2(i - 1) + 1, 2i], [2(i - 1) + 1, 2i])
    end
end
