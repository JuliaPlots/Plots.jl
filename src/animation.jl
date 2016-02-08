
immutable Animation
  dir::ASCIIString
  frames::Vector{ASCIIString}
end

function Animation()
  tmpdir = convert(ASCIIString, mktempdir())
  Animation(tmpdir, ASCIIString[])
end

function frame{P<:PlottingObject}(anim::Animation, plt::P=current())
  i = length(anim.frames) + 1
  filename = @sprintf("%06d.png", i)
  png(plt, joinpath(anim.dir, filename))
  push!(anim.frames, filename)
end


# -----------------------------------------------

"Wraps the location of an animated gif so that it can be displayed"
immutable AnimatedGif
  filename::ASCIIString
end

function gif(anim::Animation, fn::@compat(AbstractString) = "tmp.gif"; fps::Integer = 20)
  fn = abspath(fn)

  try

    # high quality
    speed = round(Int, 100 / fps)
    run(`convert -delay $speed -loop 0 $(anim.dir)/*.png $fn`)

  catch err
    warn("Tried to create gif using convert (ImageMagick), but got error: $err\nWill try ffmpeg, but it's lower quality...)")

    # low quality
    run(`ffmpeg -v 0 -framerate $fps -i $(anim.dir)/%06d.png -y $fn`)
    # run(`ffmpeg -v warning -i  "fps=$fps,scale=320:-1:flags=lanczos"`)
  end

  info("Saved animation to ", fn)
  AnimatedGif(fn)
end



# write out html to view the gif... note the rand call which is a hack so the image doesn't get cached
function Base.writemime(io::IO, ::MIME"text/html", agif::AnimatedGif)
  write(io, "<img src=\"$(relpath(agif.filename))?$(rand())>\" />")
end


# -----------------------------------------------

"""
Collect one frame per for-block iteration and return an `Animation` object.

Example:

```
  p = plot(1)
  anim = @animate for x=0:0.1:5
    push!(p, 1, sin(x))
  end
```
"""
macro animate(forloop::Expr)
  if forloop.head != :for
    error("@animate macro expects a for-block. got: $(forloop.head)")
  end

  # add the call to frame to the end of each iteration
  animsym = gensym("anim")
  block = forloop.args[2]
  push!(block.args, :(frame($animsym)))

  # full expression:
  esc(quote
    $animsym = Animation()  # init animation object
    $forloop                   # for loop, saving a frame after each iteration
    $animsym                # return the animation object
  end)
end
