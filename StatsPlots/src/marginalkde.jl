@userplot MarginalKDE

@recipe function f(kc::MarginalKDE; levels = 10, clip = ((-3.0, 3.0), (-3.0, 3.0)))
    x, y = kc.args

    x = vec(x)
    y = vec(y)

    m_x = median(x)
    m_y = median(y)

    dx_l = m_x - quantile(x, 0.16)
    dx_h = quantile(x, 0.84) - m_x

    dy_l = m_y - quantile(y, 0.16)
    dy_h = quantile(y, 0.84) - m_y

    xmin = m_x + clip[1][1] * dx_l
    xmax = m_x + clip[1][2] * dx_h

    ymin = m_y + clip[2][1] * dy_l
    ymax = m_y + clip[2][2] * dy_h

    k = KernelDensity.kde((x, y))
    kx = KernelDensity.kde(x)
    ky = KernelDensity.kde(y)

    ps = pdf.(Ref(k), x, y)

    ls = []
    for p in range(1.0 / levels, stop = 1 - 1.0 / levels, length = levels - 1)
        push!(ls, quantile(ps, p))
    end

    legend --> false
    layout := @layout [
        topdensity _
        contour{0.9w,0.9h} rightdensity
    ]

    @series begin
        seriestype := :contour
        levels := ls
        fill := false
        colorbar := false
        subplot := 2
        xlims := (xmin, xmax)
        ylims := (ymin, ymax)

        (collect(k.x), collect(k.y), k.density')
    end

    ticks := nothing
    xguide := ""
    yguide := ""

    @series begin
        seriestype := :density
        subplot := 1
        xlims := (xmin, xmax)
        ylims := (0, 1.1 * maximum(kx.density))

        x
    end

    @series begin
        seriestype := :density
        subplot := 3
        orientation := :h
        xlims := (0, 1.1 * maximum(ky.density))
        ylims := (ymin, ymax)

        y
    end
end
