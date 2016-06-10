
immutable Animation
  dir::Compat.ASCIIString
  frames::Vector{Compat.ASCIIString}
end

function Animation()
  tmpdir = convert(Compat.ASCIIString, mktempdir())
  Animation(tmpdir, Compat.ASCIIString[])
end

function frame{P<:AbstractPlot}(anim::Animation, plt::P=current())
  i = length(anim.frames) + 1
  filename = @sprintf("%06d.png", i)
  png(plt, joinpath(anim.dir, filename))
  push!(anim.frames, filename)
end


# -----------------------------------------------

"Wraps the location of an animated gif so that it can be displayed"
immutable AnimatedGif
  filename::Compat.ASCIIString
end

function gif(anim::Animation, fn = "tmp.gif"; fps::Integer = 20)
  fn = abspath(fn)

  try

    # high quality
    speed = round(Int, 100 / fps)
    file = joinpath(Pkg.dir("ImageMagick"), "deps","deps.jl")
    if isfile(file) && !haskey(ENV, "MAGICK_CONFIGURE_PATH")
        include(file)
    end
    prefix = get(ENV, "MAGICK_CONFIGURE_PATH", "")
    run(`$(joinpath(prefix, "convert")) -delay $speed -loop 0 $(joinpath(anim.dir, "*.png")) -alpha off $fn`)

  catch err
    warn("""Tried to create gif using convert (ImageMagick), but got error: $err
    ImageMagick can be installed by executing `Pkg.add("ImageMagick")`
    Will try ffmpeg, but it's lower quality...)""")

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

function _animate(forloop::Expr, args...; callgif = false)
  if forloop.head != :for
    error("@animate macro expects a for-block. got: $(forloop.head)")
  end

  # add the call to frame to the end of each iteration
  animsym = gensym("anim")
  countersym = gensym("counter")
  block = forloop.args[2]

  # create filter
  n = length(args)
  filterexpr = if n == 0
    # no filter... every iteration gets a frame
    true

  elseif args[1] == :every
    # filter every `freq` frames (starting with the first frame)
    @assert n == 2
    freq = args[2]
    @assert isa(freq, Integer) && freq > 0
    :(mod1($countersym, $freq) == 1)

  elseif args[1] == :when
    # filter on custom expression
    @assert n == 2
    args[2]

  else
    error("Unsupported animate filter: $args")
  end

  push!(block.args, :(if $filterexpr; frame($animsym); end))
  push!(block.args, :($countersym += 1))

  # add a final call to `gif(anim)`?
  retval = callgif ? :(gif($animsym)) : animsym

  # full expression:
  esc(quote
    $animsym = Animation()  # init animation object
    $countersym = 1         # init iteration counter
    $forloop                # for loop, saving a frame after each iteration
    $retval                 # return the animation object, or the gif
  end)
end

"""
Builds an `Animation` using one frame per loop iteration, then create an animated GIF.

Example:

```
  p = plot(1)
  @gif for x=0:0.1:5
    push!(p, 1, sin(x))
  end
```
"""
macro gif(forloop::Expr, args...)
  _animate(forloop, args...; callgif = true)
end

"""
Collect one frame per for-block iteration and return an `Animation` object.

Example:

```
  p = plot(1)
  anim = @animate for x=0:0.1:5
    push!(p, 1, sin(x))
  end
  gif(anim)
```
"""
macro animate(forloop::Expr, args...)
  _animate(forloop, args...)
end
