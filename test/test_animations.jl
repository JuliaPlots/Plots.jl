@testset "Empty anim" begin
    anim = @animate for i in []
    end
    @test_throws ArgumentError gif(anim, show_msg = false)
end

@userplot CirclePlot
@recipe function f(cp::CirclePlot)
    x, y, i = cp.args
    n = length(x)
    inds = circshift(1:n, 1 - i)
    linewidth --> range(0, 10, length = n)
    seriesalpha --> range(0, 1, length = n)
    aspect_ratio --> 1
    label --> false
    x[inds], y[inds]
end

@testset "Circle plot" begin
    n = 10
    t = range(0, 2π, length = n)
    x = sin.(t)
    y = cos.(t)

    anim = @animate for i in 1:n
        circleplot(x, y, i)
    end
    @test filesize(gif(anim, show_msg = false).filename) > 10_000
    @test filesize(mov(anim, show_msg = false).filename) > 10_000
    @test filesize(mp4(anim, show_msg = false).filename) > 10_000
    @test filesize(webm(anim, show_msg = false).filename) > 10_000
    @test filesize(apng(anim, show_msg = false).filename) > 10_000

    @gif for i in 1:n
        circleplot(x, y, i, line_z = 1:n, cbar = false, framestyle = :zerolines)
    end every 5

    @apng for i in 1:n
        circleplot(x, y, i, line_z = 1:n, cbar = false, framestyle = :zerolines)
    end every 5
end

@testset "html" begin
    pl = plot([sin, cos], zeros(0), leg = false, xlims = (0, 2π), ylims = (-1, 1))
    anim = Animation()
    for x in range(0, stop = 2π, length = 10)
        push!(pl, x, Float64[sin(x), cos(x)])
        frame(anim)
    end

    agif = gif(anim, show_msg = false)
    html = tempname() * ".html"
    open(html, "w") do io
        show(io, MIME("text/html"), agif)
    end
    @test filesize(html) > 10_000
    @test showable(MIME("image/gif"), agif)

    agif = mp4(anim, show_msg = false)
    html = tempname() * ".html"
    open(html, "w") do io
        show(io, MIME("text/html"), agif)
    end
    @test filesize(html) > 10_000
end
