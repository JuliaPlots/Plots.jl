
immutable Animation{P<:PlottingObject}
  plt::P
  dir::ASCIIString
  frames::Vector{ASCIIString}
end

function Animation(plt::PlottingObject)
  Animation(plt, mktempdir(), ASCIIString[])
end
Animation() = Animation(current())

function frame(anim::Animation)
  i = length(anim.frames) + 1
  filename = @sprintf("%06d.png", i)
  png(anim.plt, joinpath(anim.dir, filename))
  push!(anim.frames, filename)
end

function gif(anim::Animation, fn::@compat(AbstractString) = tempname() * ".gif"; fps::Integer = 20)
  run(`ffmpeg -framerate $fps -i $(anim.dir)/%06d.png -y $fn`)
  info("Saved animation to ", fn)
end