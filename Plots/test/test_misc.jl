# miscellaneous tests (not fitting into other test files)

@testset "Infrastructure" begin
    @test_nowarn JSON.Parser.parse(
        String(read(joinpath(dirname(pathof(Plots)), "..", ".zenodo.json"))),
    )
end

@testset "Plotly standalone" begin
    @test Plots._plotly_local_file_path[] ≡ nothing
    temp = Plots._use_local_dependencies[]
    withenv("PLOTS_HOST_DEPENDENCY_LOCAL" => true) do
        Plots._plots_plotly_defaults()
        @test Plots._plotly_local_file_path[] isa String
        @test isfile(Plots._plotly_local_file_path[])
        @test Plots._use_local_dependencies[] = true
    end
    Plots._plotly_local_file_path[] = nothing
    Plots._use_local_dependencies[] = temp
end

@testset "NoFail" begin
    Plots.with(:unicodeplots) do
        @test backend() == Plots.UnicodePlotsBackend()

        dsp = TextDisplay(IOContext(IOBuffer(), :color => true))

        @testset "plot" begin
            for pl in [
                    histogram([1, 0, 0, 0, 0, 0]),
                    plot([missing]),
                    plot([missing, missing]),
                    plot(fill(missing, 10)),
                    plot([missing; 1:4]),
                    plot([fill(missing, 10); 1:4]),
                    plot([1 1; 1 missing]),
                    plot(["a" "b"; missing "d"], [1 2; 3 4]),
                ]
                display(dsp, pl)
            end
            @test_nowarn plot(x -> x^2, 0, 2)
        end

        @testset "bar" begin
            p = bar([3, 2, 1], [1, 2, 3])
            @test p isa Plots.Plot
            @test display(dsp, p) isa Nothing
        end

        @testset "gui" begin
            open(tempname(), "w") do io
                redirect_stdout(io) do
                    gui(plot())
                end
            end
        end

        @testset "axis scales" begin
            pl = plot(1:5, xscale = :log2, yscale = :ln)
            @test pl[1][:xaxis][:scale] ≡ :log2
            @test pl[1][:yaxis][:scale] ≡ :ln
        end
    end
end

@testset "bool_env" begin
    @test Plots.bool_env("FOO", "true")
    @test Plots.bool_env("FOO", "1")
    @test !Plots.bool_env("FOO", "false")
    @test !Plots.bool_env("FOO", "0")
end

@testset "Themes" begin
    @test showtheme(:dark) isa Plots.Plot
end

@testset "maths" begin
    @test Plots.floor_base(15.0, 10.0) ≈ 10
    @test Plots.ceil_base(15.0, 10.0) ≈ 10^2
    @test Plots.floor_base(4.2, 2.0) ≈ 2^2
    @test Plots.ceil_base(4.2, 2.0) ≈ 2^3
    @test Plots.floor_base(1.5 * ℯ, ℯ) ≈ ℯ
    @test Plots.ceil_base(1.5 * ℯ, ℯ) ≈ ℯ^2
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
    @test Plots.attrtypes() == "Series, Subplot, Plot, Axis"
end

@testset "legend" begin
    @test isa(
        Plots.legend_pos_from_angle(20, 0.0, 0.5, 1.0, 0.0, 0.5, 1.0),
        NTuple{2, <:AbstractFloat},
    )
    @test Plots.legend_anchor_index(-1) == 1
    @test Plots.legend_anchor_index(+0) == 2
    @test Plots.legend_anchor_index(+1) == 3

    @test Plots.legend_angle(:foo_bar) == (45, :inner)
    @test Plots.legend_angle(20.0) == Plots.legend_angle((20.0, :inner)) == (20.0, :inner)
    @test Plots.legend_angle((20.0, 10.0)) == (20.0, 10.0)
end

@testset "axis letter" begin
    # a custom type for dispacthing the axis-letter-testing recipe
    struct MyType <: Number
        val::Float64
    end
    value(m::MyType) = m.val
    data = MyType.(sort(randn(20)))

    # A recipe that puts the axis letter in the title
    @recipe function f(::Type{T}, m::T) where {T <: AbstractArray{<:MyType}}
        title --> string(plotattributes[:letter])
        value.(m)
    end

    @testset "orientation" begin
        for f in (histogram, barhist, stephist, scatterhist), o in (:vertical, :horizontal)
            sp = f(data, orientation = o).subplots[1]
            @test sp.attr[:title] == (o ≡ :vertical ? "x" : "y")
        end
    end

    @testset "$f" for f in (hline, hspan)
        @test f(data).subplots[1].attr[:title] == "y"
    end

    @testset "$f" for f in (vline, vspan)
        @test f(data).subplots[1].attr[:title] == "x"
    end
end

@testset "tex_output_standalone" begin
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
    sp = plot(data4, ribbon = (mat, mat))[1]
    for i in axes(data4, 1)
        for attribute in (:fillrange, :ribbon)
            nt = NamedTuple{tuple(attribute)}
            get_attr(pl) = pl[1][i][attribute]
            @test plot(data4; nt(0)...) |> get_attr == 0
            @test plot(data4; nt(Ref([1, 2]))...) |> get_attr == [1.0, 2.0]
            @test plot(data4; nt(Ref([1 2]))...) |> get_attr == (iseven(i) ? 2 : 1)
            @test plot(data4; nt(Ref(mat))...) |> get_attr == [2(i - 1) + 1, 2i]
        end
        @test sp[i][:ribbon] == ([2(i - 1) + 1, 2i], [2(i - 1) + 1, 2i])
    end
end

@testset "Extract subplot" begin  # github.com/JuliaPlots/Plots.jl/issues/4045
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

@testset "Empty Plot / Subplots" begin
    pl = plot(map(_ -> plot(1:2, [1:2 2:3]), 1:2)...)
    empty!(pl)
    @test length(pl.subplots) == 2
    @test length(first(pl).series_list) == 0
    @test length(last(pl).series_list) == 0

    pl = plot(map(_ -> plot(1:2, [1:2 2:3]), 1:2)...)
    empty!(first(pl))  # clear out only the first subplot
    @test length(pl.subplots) == 2
    @test length(first(pl).series_list) == 0
    @test length(last(pl).series_list) == 2
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

@testset "wrap" begin
    # not sure what is intended here ...
    wrapped = Plots.wrap([:red, :blue])
    @test !isempty(wrapped)
    @test scatter(1:2, color = wrapped) isa Plots.Plot
end

@testset "group" begin
    # from github.com/JuliaPlots/Plots.jl/issues/3630#issuecomment-876001540
    a = repeat(1:3, inner = 4)
    b = repeat(["low", "high"], inner = 2, outer = 3)
    c = repeat(1:2, outer = 6)
    d = [1, 1, 1, 2, 2, 2, 2, 4, 3, 3, 3, 6]
    @test plot(b, d, group = (c, a), layout = (1, 3)) isa Plots.Plot
end

@testset "skipissing" begin
    @test plot(skipmissing(1:5)) isa Plots.Plot
end

Plots.with(:gr) do
    @testset "text" begin
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

    @testset "recipes" begin
        @test Plots.seriestype_supported(:path) ≡ :native

        @test plot([1, 2, 5], seriestype = :linearfit) isa Plots.Plot
        @test plot([1, 2, 5], seriestype = :scatterpath) isa Plots.Plot
        @test plot(1:2, 1:2, 1:2, seriestype = :scatter3d) isa Plots.Plot

        let pl = plot(1:2, -1:1, widen = false)
            Plots.abline!([0, 3], [5, -5])
            @test xlims(pl) == (+1, +2)
            @test ylims(pl) == (-1, +1)
        end

        @test Plots.findnz([0 1; 2 0]) == ([2, 1], [1, 2], [2, 1])
    end

    @testset "mesh3d" begin
        x = [0, 1, 2, 0]
        y = [0, 0, 1, 2]
        z = [0, 2, 0, 1]
        i = [0, 0, 0, 1]
        j = [1, 2, 3, 2]
        k = [2, 3, 1, 3]
        # github.com/JuliaPlots/Plots.jl/pull/3868#issuecomment-939446686
        mesh3d(
            x,
            y,
            z;
            connections = (i, j, k),
            fillcolor = [:blue, :red, :green, :yellow],
            fillalpha = 0.5,
        )

        # github.com/JuliaPlots/Plots.jl/pull/3835#issue-1002117649
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

    @testset "fillstyle" begin
        @test histogram(rand(10); fillstyle = :/) isa Plots.Plot
    end

    @testset "showable" begin
        @test showable(MIME("image/png"), plot(1:2))
    end

    @testset "inline" begin
        show(devnull, plot(1:2, display_type = :inline))
    end

    @testset "legends" begin
        @test plot([0:1 reverse(0:1)]; labels = ["a" "b"], leg = (0.5, 0.5)) isa Plots.Plot
        @test plot([0:1 reverse(0:1)]; labels = ["a" "b"], leg = (0.5, :outer)) isa
            Plots.Plot
        @test plot([0:1 reverse(0:1)]; labels = ["a" "b"], leg = (0.5, :inner)) isa
            Plots.Plot
        @test_logs (:warn, r"n° of legend_column.*") png(
            plot(1:2, legend_columns = 10),
            tempname(),
        )
    end

    @testset "cycling" begin
        # see github.com/JuliaPlots/Plots.jl/issues/4561
        # and github.com/JuliaPlots/Plots.jl/issues/2980
        # cycling arguments is a weird Plots feature - maybe remove in `2.0` ?
        x = 0.0:0.1:1
        y = rand(3)
        show(devnull, scatter(x, y))
        # show(devnull, plot(x, y))  # currently unsupported
    end
end
