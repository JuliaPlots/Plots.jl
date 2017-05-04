
immutable Animation
    dir::String
    frames::Vector{String}
end

function Animation()
    tmpdir = convert(String, mktempdir())
    Animation(tmpdir, String[])
end

function frame{P<:AbstractPlot}(anim::Animation, plt::P=current())
    i = length(anim.frames) + 1
    filename = @sprintf("%06d.png", i)
    png(plt, joinpath(anim.dir, filename))
    push!(anim.frames, filename)
end

giffn() = (isijulia() ? "tmp.gif" : tempname()*".gif")
movfn() = (isijulia() ? "tmp.mov" : tempname()*".mov")
mp4fn() = (isijulia() ? "tmp.mp4" : tempname()*".mp4")

type FrameIterator
    itr
    every::Int
    kw
end
FrameIterator(itr; every=1, kw...) = FrameIterator(itr, every, kw)

"""
Animate from an iterator which returns the plot args each iteration.
"""
function animate(fitr::FrameIterator, fn = giffn(); kw...)
    anim = Animation()
    for (i, plotargs) in enumerate(fitr.itr)
        if mod1(i, fitr.every) == 1
            plot(wraptuple(plotargs)...; fitr.kw...)
            frame(anim)
        end
    end
    gif(anim, fn; kw...)
end

# most things will implement this
function animate(obj, fn = giffn(); every=1, fps=20, loop=0, kw...)
    animate(FrameIterator(obj, every, kw), fn; fps=fps, loop=loop)
end

# -----------------------------------------------

"Wraps the location of an animated gif so that it can be displayed"
immutable AnimatedGif
    filename::String
end

file_extension(fn) = Base.Filesystem.splitext(fn)[2][2:end]

gif(anim::Animation, fn = giffn(); kw...) = buildanimation(anim.dir, fn; kw...)
mov(anim::Animation, fn = movfn(); kw...) = buildanimation(anim.dir, fn; kw...)
mp4(anim::Animation, fn = mp4fn(); kw...) = buildanimation(anim.dir, fn; kw...)

const _imagemagick_initialized = Ref(false)

function buildanimation(animdir::AbstractString, fn::AbstractString;
                        fps::Integer = 20, loop::Integer = 0)
    fn = abspath(fn)
    try
        if !_imagemagick_initialized[]
            file = joinpath(Pkg.dir("ImageMagick"), "deps","deps.jl")
            if isfile(file) && !haskey(ENV, "MAGICK_CONFIGURE_PATH")
                include(file)
            end
            _imagemagick_initialized[] = true
        end

        # prefix = get(ENV, "MAGICK_CONFIGURE_PATH", "")
        # high quality
        speed = round(Int, 100 / fps)
        run(`convert -delay $speed -loop $loop $(joinpath(animdir, "*.png")) -alpha off $fn`)

    catch err
        warn("""Tried to create gif using convert (ImageMagick), but got error: $err
            ImageMagick needs to be installed in julia and on your machine:
              1) in julia>> `Pkg.add("ImageMagick")`
              2) on your machine (for Ubuntu): $$ sudo apt install imagemagick
            Will try ffmpeg, but it's lower quality...)""")

        # low quality
        run(`ffmpeg -v 0 -framerate $fps -loop $loop -i $(animdir)/%06d.png -y $fn`)
        # run(`ffmpeg -v warning -i  "fps=$fps,scale=320:-1:flags=lanczos"`)
    end

    info("Saved animation to ", fn)
    AnimatedGif(fn)
end



# write out html to view the gif... note the rand call which is a hack so the image doesn't get cached
function Base.show(io::IO, ::MIME"text/html", agif::AnimatedGif)
    ext = file_extension(agif.filename)
    write(io, if ext == "gif"
        "<img src=\"$(relpath(agif.filename))?$(rand())>\" />"
    elseif ext in ("mov", "mp4")
        "<video controls><source src=\"$(relpath(agif.filename))?$(rand())>\" type=\"video/$ext\"></video>"
    else
        error("Cannot show animation with extension $ext: $agif")
    end)
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
