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
        Plots._plots_plotly_defaults()
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
            @test_throws ErrorException plotattr(:WrongAttrType)
            @test_throws ErrorException plotattr("WrongAttribute")
            plotattr("seriestype")
            plotattr(:Plot)
            # plotattr()  # interactive (JLFzf)
        end
    end
    str = join(readlines(tmp), "")
    @test occursin("seriestype", str)
    @test occursin("Plot attributes", str)
    @test Plots.printnothing(nothing) == "nothing"
    @test Plots.attrtypes() == "Series, Subplot, Plot, Axis"
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

@testset "axis scales" begin
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
                  (o === :vertical ? "x" : "y")
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
            get_attr(pl) = pl[1][i][attribute]
            @test plot(data4; NamedTuple{tuple(attribute)}(0)...) |> get_attr == 0
            @test plot(data4; NamedTuple{tuple(attribute)}(Ref([1, 2]))...) |> get_attr ==
                  [1.0, 2.0]
            @test plot(data4; NamedTuple{tuple(attribute)}(Ref([1 2]))...) |> get_attr ==
                  (iseven(i) ? 2 : 1)
            @test plot(data4; NamedTuple{tuple(attribute)}(Ref(mat))...) |> get_attr ==
                  [2(i - 1) + 1, 2i]
        end
        @test plot(data4, ribbon = (mat, mat))[1][i][:ribbon] ==
              ([2(i - 1) + 1, 2i], [2(i - 1) + 1, 2i])
    end
end

@testset "Extract subplot" begin  # JuliaPlots/Plots.jl/issues/4045
    x1, y1 = -1:5, 4:10
    x2, y2 = rand(10), rand(10)
    p1, p2 = plot(x1, y1), plot(x2, y2)
    pl = plot(p1, p2)  # full plot, with 2 subplots

    pl1 = plot(pl.subplots[1])
    series = first(first(pl1.subplots).series_list)
    @test series[:x] == x1
    @test series[:y] == y1

    pl2 = plot(pl.subplots[2])
    series = first(first(pl2.subplots).series_list)
    @test series[:x] == x2
    @test series[:y] == y2
end

@testset "Measures" begin
    @test 1Plots.mm * 0.1Plots.pct == 0.1Plots.mm
    @test 0.1Plots.pct * 1Plots.mm == 0.1Plots.mm
    @test 1Plots.mm / 0.1Plots.pct == 10Plots.mm
    @test 0.1Plots.pct / 1Plots.mm == 10Plots.mm
end

@testset "docstring" begin
    @test occursin("label", Plots._generate_doclist(Plots._all_series_args))
end

@testset "text" begin
    with(:gr) do
        io = PipeBuffer()
        x = y = range(-3, 3, length = 10)
        extra_kwargs = Dict(
            :series => Dict(:display_option => Plots.GR.OPTION_SHADED_MESH),
            :subplot => Dict(:legend_hfactor => 2),
            :plot => Dict(:foo => nothing),
        )
        show(io, surface(x, y, (x, y) -> exp(-x^2 - y^2); extra_kwargs))
        str = read(io, String)
        @test occursin("extra kwargs", str)
        @test occursin("Series{1}", str)
        @test occursin("SubplotPlot{1}", str)
        @test occursin("Plot:", str)
    end
end

@testset "wrap" begin
    # not sure what is intended here ...
    @test scatter(1:2, color = wrap([:red, :blue])) isa Plot
end

@testset "recipes" begin
    with(:gr) do
        @test Plots.seriestype_supported(:path) === :native

        @test plot([1, 2, 5], seriestype = :linearfit) isa Plot
        @test plot([1, 2, 5], seriestype = :scatterpath) isa Plot
        @test plot(1:2, 1:2, 1:2, seriestype = :scatter3d) isa Plot

        let pl = plot(1:2, widen = false)
            Plots.abline!([0, 3], [5, 0])
            @test xlims(pl) == (1, 2)
            @test ylims(pl) == (1, 2)
        end

        @test Plots.findnz([0 1; 2 0]) == ([2, 1], [1, 2], [2, 1])
    end
end

@testset "mesh3d" begin
    with(:gr) do
        x = [0, 1, 2, 0]
        y = [0, 0, 1, 2]
        z = [0, 2, 0, 1]
        i = [0, 0, 0, 1]
        j = [1, 2, 3, 2]
        k = [2, 3, 1, 3]
        # JuliaPlots/Plots.jl/pull/3868#issuecomment-939446686
        mesh3d(
            x,
            y,
            z;
            connections = (i, j, k),
            fillcolor = [:blue, :red, :green, :yellow],
            fillalpha = 0.5,
        )

        # JuliaPlots/Plots.jl/pull/3835#issue-1002117649
        p0 = [0.0, 0.0, 0.0]
        p1 = [1.0, 0.0, 0.0]
        p2 = [0.0, 1.0, 0.0]
        p3 = [1.0, 1.0, 0.0]
        p4 = [0.5, 0.5, 1.0]
        pts = [p0, p1, p2, p3, p4]
        x, y, z = broadcast(i -> getindex.(pts, i), (1, 2, 3))
        # [x[i],y[i],z[i]] is the i-th vertix of the mesh
        mesh3d(
            x,
            y,
            z;
            connections = [
                [1, 2, 4, 3], # Quadrangle 
                [1, 2, 5], # Triangle
                [2, 4, 5], # Triangle
                [4, 3, 5], # Triangle
                [3, 1, 5],  # Triangle
            ],
            linecolor = :black,
            fillcolor = :blue,
            fillalpha = 0.2,
        )
        @test true
    end
end

@testset "fillstyle" begin
    with(:gr) do
        @test histogram(rand(10); fillstyle = :/) isa Plot
    end
end

@testset "group" begin
    # from JuliaPlots/Plots.jl/issues/3630#issuecomment-876001540
    a = repeat(1:3, inner = 4)
    b = repeat(["low", "high"], inner = 2, outer = 3)
    c = repeat(1:2, outer = 6)
    d = [1, 1, 1, 2, 2, 2, 2, 4, 3, 3, 3, 6]
    @test plot(b, d, group = (c, a), layout = (1, 3)) isa Plot
end

@testset "inline" begin
    with(:gr) do
        pl = plot(1:2, display_type = :inline)
        show(devnull, pl)
    end
end
