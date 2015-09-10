

function testplot_line1()
  plot(rand(100,3))
end

function testplot_fn1()
  plot(0:0.01:4π, [sin,cos])
end

function testplot_guides1()
  plot(rand(10); title="TITLE", xlabel="XLABEL", ylabel="YLABEL", background_color=:red)
end
