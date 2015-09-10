

function testplot_line1()
  plot(rand(100,3))
end

function testplot_fn1()
  plot(0:0.01:4π, [sin,cos])
end

function testplot_guides1()
  plot(rand(10); title="TITLE", xlabel="XLABEL", ylabel="YLABEL", background_color=:red)
end

function testplot_points1()
  plot(Vector[rand(10), rand(20)]; marker=:ellipse, markersize=8)
end

function testplot_points2()
  plot(Vector[rand(10), rand(20)]; marker=:ellipse, markersize=8, markercolors=[:red,:blue])
end
