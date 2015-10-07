
# Compose pseudo-forms for simple symbols, all parameterized by center and size

# using Compose: x_measure, y_measure


function createGadflyAnnotation(d::Dict, initargs::Dict)
  sz = [d[:markersize] * Gadfly.px]

  x, y = d[:x], d[:y]
  marker = d[:markershape]

  if d[:linetype] == :ohlc
    shape = ohlcshape(x, y, d[:markersize])
    d[:y] = Float64[z.open for z in y]
    d[:linetype] = :none
    return Gadfly.Guide.annotation(Gadfly.compose(Gadfly.context(), shape, Gadfly.fill(nothing), Gadfly.stroke(getColor(d[:color]))))  

  elseif marker == :rect
    shape = square(x, y, sz)

  elseif marker == :diamond
    shape = diamond(x, y, sz)

  elseif marker == :utriangle
    shape = utriangle(x, y, sz)

  elseif marker == :dtriangle
    shape = utriangle(x, y, sz, -1)

  elseif marker == :cross
    shape = cross(x, y, sz)

  elseif marker == :xcross
    shape = xcross(x, y, sz)

  elseif marker == :star1
    shape = star1(x, y, sz)

  elseif marker == :star2
    shape = star2(x, y, sz)

  elseif marker == :hexagon
    shape = hexagon(x, y, sz)

  elseif marker == :octagon
    shape = octagon(x, y, sz)

  else
    # make circles
    sz = 0.8 * d[:markersize] * Gadfly.px
    xs = collect(float(d[:x]))
    ys = collect(float(d[:y]))
    shape = Gadfly.circle(xs,ys,[sz])
  end

  Gadfly.Guide.annotation(Gadfly.compose(Gadfly.context(), shape, Gadfly.fill(getColorVector(d[:markercolor])), Gadfly.stroke(getColor(initargs[:foreground_color]))))  
end


function square(xs::AbstractArray, ys::AbstractArray, rs::AbstractArray)
  n = max(length(xs), length(ys), length(rs))
  rect_xs = Vector{Compose.Measure}(n)
  rect_ys = Vector{Compose.Measure}(n)
  rect_ws = Vector{Compose.Measure}(n)
  s = 1/sqrt(2)
  for i in 1:n
    x = Compose.x_measure(xs[mod1(i, length(xs))])
    y = Compose.y_measure(ys[mod1(i, length(ys))])
    r = rs[mod1(i, length(rs))]

    rect_xs[i] = x - s*r
    rect_ys[i] = y + s*r
    rect_ws[i] = 2*s*r
  end

  return Gadfly.rectangle(rect_xs, rect_ys, rect_ws, rect_ws)
end


function diamond(xs::AbstractArray, ys::AbstractArray, rs::AbstractArray)
  n = max(length(xs), length(ys), length(rs))
  polys = Vector{Vector{Tuple{Compose.Measure, Compose.Measure}}}(n)
  for i in 1:n
    x = Compose.x_measure(xs[mod1(i, length(xs))])
    y = Compose.y_measure(ys[mod1(i, length(ys))])
    r = rs[mod1(i, length(rs))]
    polys[i] = Tuple{Compose.Measure, Compose.Measure}[(x, y - r), (x + r, y), (x, y + r), (x - r, y)]
  end

  return Gadfly.polygon(polys)
end



function cross(xs::AbstractArray, ys::AbstractArray, rs::AbstractArray)
  n = max(length(xs), length(ys), length(rs))
  polys = Vector{Vector{Tuple{Compose.Measure, Compose.Measure}}}(n)
  for i in 1:n
    x = Compose.x_measure(xs[mod1(i, length(xs))])
    y = Compose.y_measure(ys[mod1(i, length(ys))])
    r = rs[mod1(i, length(rs))]
    u = 0.4r

    # make a "plus sign"
    polys[i] = Tuple{Compose.Measure, Compose.Measure}[
      (x-r, y-u), (x-r, y+u), # L edge
      (x-u, y+u),             # BL inside
      (x-u, y+r), (x+u, y+r), # B edge
      (x+u, y+u),             # BR inside
      (x+r, y+u), (x+r, y-u), # R edge
      (x+u, y-u),             # TR inside
      (x+u, y-r), (x-u, y-r), # T edge
      (x-u, y-u)              # TL inside
    ]
  end

  return Gadfly.polygon(polys)
end

function xcross(xs::AbstractArray, ys::AbstractArray, rs::AbstractArray)
  n = max(length(xs), length(ys), length(rs))
  polys = Vector{Vector{Tuple{Compose.Measure, Compose.Measure}}}(n)
  s = 1/sqrt(5)
  for i in 1:n
    x = Compose.x_measure(xs[mod1(i, length(xs))])
    y = Compose.y_measure(ys[mod1(i, length(ys))])
    r = rs[mod1(i, length(rs))]
    u = s*r
    polys[i] = Tuple{Compose.Measure, Compose.Measure}[
      (x, y - u), (x + u, y - 2u), (x + 2u, y - u),
      (x + u, y), (x + 2u, y + u), (x + u, y + 2u),
      (x, y + u), (x - u, y + 2u), (x - 2u, y + u),
      (x - u, y), (x - 2u, y - u), (x - u, y - 2u)
    ]
  end

  return Gadfly.polygon(polys)
end


function utriangle(xs::AbstractArray, ys::AbstractArray, rs::AbstractArray, scalar = 1)
  n = max(length(xs), length(ys), length(rs))
  polys = Vector{Vector{Tuple{Compose.Measure, Compose.Measure}}}(n)
  s = 0.8
  for i in 1:n
    x = Compose.x_measure(xs[mod1(i, length(xs))])
    y = Compose.y_measure(ys[mod1(i, length(ys))])
    r = rs[mod1(i, length(rs))]
    u = 0.8 * scalar * r
    polys[i] = Tuple{Compose.Measure, Compose.Measure}[
      (x - r, y + u),
      (x + r, y + u),
      (x, y - u)
    ]
  end

  return Gadfly.polygon(polys)
end



function star1(xs::AbstractArray, ys::AbstractArray, rs::AbstractArray, scalar = 1)
  n = max(length(xs), length(ys), length(rs))
  polys = Vector{Vector{Tuple{Compose.Measure, Compose.Measure}}}(n)
  
  # some magic scalars
  sx1, sx2, sx3 = 0.7, 0.4, 0.2
  sy1, sy2, sy3 = 1.2, 0.45, 0.1

  for i in 1:n
    x = Compose.x_measure(xs[mod1(i, length(xs))])
    y = Compose.y_measure(ys[mod1(i, length(ys))])
    r = rs[mod1(i, length(rs))]
    polys[i] = Tuple{Compose.Measure, Compose.Measure}[
      (x-sx1*r, y+    r),  # BL
      (x,       y+sy2*r),
      (x+sx1*r, y+    r),  # BR
      (x+sx2*r, y+sy3*r),
      (x+    r, y-sy2*r),  # R
      (x+sx3*r, y-sy2*r),
      (x,       y-sy1*r),  # T
      (x-sx3*r, y-sy2*r),
      (x-    r, y-sy2*r),  # L
      (x-sx2*r, y+sy3*r)
    ]
  end

  return Gadfly.polygon(polys)
end



function star2(xs::AbstractArray, ys::AbstractArray, rs::AbstractArray, scalar = 1)
  n = max(length(xs), length(ys), length(rs))
  polys = Vector{Vector{Tuple{Compose.Measure, Compose.Measure}}}(n)
  for i in 1:n
    x = Compose.x_measure(xs[mod1(i, length(xs))])
    y = Compose.y_measure(ys[mod1(i, length(ys))])
    r = rs[mod1(i, length(rs))]
    u = 0.4r
    polys[i] = Tuple{Compose.Measure, Compose.Measure}[
      (x-u, y),   (x-r, y-r), # TL
      (x,   y-u), (x+r, y-r), # TR
      (x+u, y),   (x+r, y+r), # BR
      (x,   y+u), (x-r, y+r)  # BL
    ]
  end

  return Gadfly.polygon(polys)
end



function hexagon(xs::AbstractArray, ys::AbstractArray, rs::AbstractArray)
  n = max(length(xs), length(ys), length(rs))

  polys = Vector{Vector{Tuple{Compose.Measure, Compose.Measure}}}(n)
  for i in 1:n
    x = Compose.x_measure(xs[mod1(i, length(xs))])
    y = Compose.y_measure(ys[mod1(i, length(ys))])
    r = rs[mod1(i, length(rs))]
    u = 0.6r

    polys[i] = Tuple{Compose.Measure, Compose.Measure}[
      (x-r, y-u), (x-r, y+u), # L edge
      (x, y+r),               # B
      (x+r, y+u), (x+r, y-u), # R edge
      (x, y-r)                # T
    ]
  end

  return Gadfly.polygon(polys)
end


function octagon(xs::AbstractArray, ys::AbstractArray, rs::AbstractArray)
  n = max(length(xs), length(ys), length(rs))

  polys = Vector{Vector{Tuple{Compose.Measure, Compose.Measure}}}(n)
  for i in 1:n
    x = Compose.x_measure(xs[mod1(i, length(xs))])
    y = Compose.y_measure(ys[mod1(i, length(ys))])
    r = rs[mod1(i, length(rs))]
    u = 0.4r

    polys[i] = Tuple{Compose.Measure, Compose.Measure}[
      (x-r, y-u), (x-r, y+u), # L edge
      (x-u, y+r), (x+u, y+r), # B edge
      (x+r, y+u), (x+r, y-u), # R edge
      (x+u, y-r), (x-u, y-r), # T edge
    ]
  end

  return Gadfly.polygon(polys)
end


# ---------------------------

function ohlcshape(xs::AVec, ys::AVec{OHLC}, tickwidth::Real)
  @assert length(xs) == length(ys)
  n = length(xs)
  u = tickwidth * Compose.px
  polys = Vector{Vector{Tuple{Compose.Measure, Compose.Measure}}}(n)
  for i in 1:n
    x = Compose.x_measure(xs[i])
    o = Compose.y_measure(ys[i].open)
    h = Compose.y_measure(ys[i].high)
    l = Compose.y_measure(ys[i].low)
    c = Compose.y_measure(ys[i].close)
    # o,h,l,c = map(Compose.y_measure, ys[i])
    polys[i] = Tuple{Compose.Measure, Compose.Measure}[
      (x, o), (x - u, o), (x, o),   # open tick
      (x, l), (x, h), (x, c),       # high/low bar
      (x + u, c), (x, c)            # close tick
    ]
  end
  return Gadfly.polygon(polys)
end



