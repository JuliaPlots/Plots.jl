"Represents an animation object"
struct Animation
    dir::String
    frames::Vector{String}
end

function Animation()
    tmpdir = convert(String, mktempdir())
    Animation(tmpdir, String[])
end

"""
    frame(animation[, plot])

Add a plot (the current plot if not specified) to an existing animation
"""
function frame(anim::Animation, plt::P=current()) where P<:AbstractPlot
    i = length(anim.frames) + 1
    filename = @sprintf("%06d.png", i)
    png(plt, joinpath(anim.dir, filename))
    push!(anim.frames, filename)
end

giffn() = (isijulia() ? "tmp.gif" : tempname()*".gif")
movfn() = (isijulia() ? "tmp.mov" : tempname()*".mov")
mp4fn() = (isijulia() ? "tmp.mp4" : tempname()*".mp4")
webmfn() = (isijulia() ? "tmp.webm" : tempname()*".webm")

mutable struct FrameIterator
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
struct AnimatedGif
    filename::String
end

file_extension(fn) = Base.Filesystem.splitext(fn)[2][2:end]

gif(anim::Animation, fn = giffn(); kw...) = buildanimation(anim, fn; kw...)
mov(anim::Animation, fn = movfn(); kw...) = buildanimation(anim, fn, false; kw...)
mp4(anim::Animation, fn = mp4fn(); kw...) = buildanimation(anim, fn, false; kw...)
webm(anim::Animation, fn = webmfn(); kw...) = buildanimation(anim, fn, false; kw...)

ffmpeg_framerate(fps) = "$fps"
ffmpeg_framerate(fps::Rational) = "$(fps.num)/$(fps.den)"

function buildanimation(anim::Animation, fn::AbstractString,
                        is_animated_gif::Bool=true;
                        fps::Real = 20, loop::Integer = 0,
                        variable_palette::Bool=false,
                        verbose=false,
                        show_msg::Bool=true)
    if length(anim.frames) == 0
        throw(ArgumentError("Cannot build empty animations"))
    end

    fn = abspath(expanduser(fn))
    animdir = anim.dir
    framerate = ffmpeg_framerate(fps)
    verbose_level = (verbose isa Int ? verbose :
                        verbose ? 32  # "info"
                                : 16) # "error"

    if is_animated_gif
        if variable_palette
            # generate a colorpalette for each frame for highest quality, but larger filesize
            palette="palettegen=stats_mode=single[pal],[0:v][pal]paletteuse=new=1"
            ffmpeg_exe(`-v $verbose_level -framerate $framerate -loop $loop -i $(animdir)/%06d.png -lavfi "$palette" -y $fn`)
        else
            # generate a colorpalette first so ffmpeg does not have to guess it
            ffmpeg_exe(`-v $verbose_level -i $(animdir)/%06d.png -vf "palettegen=stats_mode=diff" -y "$(animdir)/palette.bmp"`)
            # then apply the palette to get better results
            ffmpeg_exe(`-v $verbose_level -framerate $framerate -loop $loop -i $(animdir)/%06d.png -i "$(animdir)/palette.bmp" -lavfi "paletteuse=dither=sierra2_4a" -y $fn`)
        end
    else
        ffmpeg_exe(`-v $verbose_level -framerate $framerate -loop $loop -i $(animdir)/%06d.png -pix_fmt yuv420p -y $fn`)
    end

    show_msg && @info("Saved animation to ", fn)
    AnimatedGif(fn)
end



# write out html to view the gif
function Base.show(io::IO, ::MIME"text/html", agif::AnimatedGif)
    ext = file_extension(agif.filename)
    if ext == "gif"
        html = "<img src=\"data:image/gif;base64," * base64encode(read(agif.filename)) * "\" />"
    elseif ext in ("mov", "mp4","webm")
        mimetype = ext == "mov" ? "video/quicktime" : "video/$ext"
        html = "<video controls><source src=\"data:$mimetype;base64," *
               base64encode(read(agif.filename)) *
               "\" type = \"$mimetype\"></video>"
    else
        error("Cannot show animation with extension $ext: $agif")
    end

    write(io, html)
    return nothing
end


# Only gifs can be shown via image/gif
Base.showable(::MIME"image/gif", agif::AnimatedGif) = file_extension(agif.filename) == "gif"

function Base.show(io::IO, ::MIME"image/gif", agif::AnimatedGif)
    open(fio-> write(io, fio), agif.filename)
end


# -----------------------------------------------

function _animate(forloop::Expr, args...; callgif = false)
  if forloop.head != :for
    error("@animate macro expects a for-block. got: $(forloop.head)")
  end

  # add the call to frame to the end of each iteration
  animsym = gensym("anim")
  countersym = gensym("counter")
  freqassert = :()
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
    freqassert = :(@assert isa($freq, Integer) && $freq > 0)
    :(mod1($countersym, $freq) == 1)

  elseif args[1] == :when
    # filter on custom expression
    @assert n == 2
    args[2]

  else
    error("Unsupported animate filter: $args")
  end

  push!(block.args, :(if $filterexpr; Plots.frame($animsym); end))
  push!(block.args, :(global $countersym += 1))

  # add a final call to `gif(anim)`?
  retval = callgif ? :(Plots.gif($animsym)) : animsym

  # full expression:
  esc(quote
    $freqassert             # if filtering, check frequency is an Integer > 0
    $animsym = Plots.Animation()  # init animation object
    global $countersym = 1         # init iteration counter
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
