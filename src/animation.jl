using FFMPEG

"""
    Animation(dir = mktempdir()))

Represents an animation object

Frames can be added to the animation object manually by calling [`frame`](@ref).
See also [`@animate`](@ref), [`@gif`](@ref).
"""
struct Animation
    dir::String
    frames::Vector{String}
end

Animation(dir = convert(String, mktempdir())) = Animation(dir, String[])

"""
    frame(animation[, plot])

Add a plot (the current plot if not specified) to an existing animation
"""
function frame(anim::Animation, plt::P = current()) where {P<:AbstractPlot}
    i = length(anim.frames) + 1
    filename = @sprintf "%06d.png" i
    png(plt, joinpath(anim.dir, filename))
    push!(anim.frames, filename)
end

giffn() = isijulia() ? "tmp.gif" : tempname() * ".gif"
movfn() = isijulia() ? "tmp.mov" : tempname() * ".mov"
mp4fn() = isijulia() ? "tmp.mp4" : tempname() * ".mp4"
webmfn() = isijulia() ? "tmp.webm" : tempname() * ".webm"
apngfn() = isijulia() ? "tmp.png" : tempname() * ".png"

mutable struct FrameIterator
    itr
    every::Int
    kw
end
FrameIterator(itr; every = 1, kw...) = FrameIterator(itr, every, kw)

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
animate(
    obj,
    fn = giffn();
    every = 1,
    fps = 20,
    loop = 0,
    variable_palette = false,
    verbose = false,
    show_msg = false,
    kw...,
) = animate(
    FrameIterator(obj, every, kw),
    fn;
    fps,
    loop,
    variable_palette,
    verbose,
    show_msg,
)

# -----------------------------------------------

"Wraps the location of an animated gif so that it can be displayed"
struct AnimatedGif
    filename::String
end

file_extension(fn) = Base.Filesystem.splitext(fn)[2][2:end]

"""
    gif(animation[, filename]; fps=20, loop=0, variable_palette=false, verbose=false, show_msg=true)
Creates an animated .gif-file from an `Animation` object.
"""
gif(anim::Animation, fn = giffn(); kw...) = buildanimation(anim, fn; kw...)
"""
    mov(animation[, filename]; fps=20, loop=0, verbose=false, show_msg=true)
Creates an .mov-file from an `Animation` object.
"""
mov(anim::Animation, fn = movfn(); kw...) = buildanimation(anim, fn, false; kw...)
"""
    mp4(animation[, filename]; fps=20, loop=0, verbose=false, show_msg=true)
Creates an .mp4-file from an `Animation` object.
"""
mp4(anim::Animation, fn = mp4fn(); kw...) = buildanimation(anim, fn, false; kw...)
"""
    webm(animation[, filename]; fps=20, loop=0, verbose=false, show_msg=true)
Creates an .webm-file from an `Animation` object.
"""
webm(anim::Animation, fn = webmfn(); kw...) = buildanimation(anim, fn, false; kw...)
"""
    apng(animation[, filename]; fps=20, loop=0, verbose=false, show_msg=true)
Creates an animated .apng-file from an `Animation` object.
"""
apng(anim::Animation, fn = apngfn(); kw...) = buildanimation(anim, fn, false; kw...)

ffmpeg_framerate(fps) = "$fps"
ffmpeg_framerate(fps::Rational) = "$(fps.num)/$(fps.den)"

function buildanimation(
    anim::Animation,
    fn::AbstractString,
    is_animated_gif::Bool = true;
    fps::Real = 20,
    loop::Integer = 0,
    variable_palette::Bool = false,
    verbose = false,
    show_msg::Bool = true,
)
    length(anim.frames) == 0 && throw(ArgumentError("Cannot build empty animations"))

    fn = abspath(expanduser(fn))
    animdir = anim.dir
    framerate = ffmpeg_framerate(fps)
    verbose_level = (verbose isa Int ? verbose : verbose ? 32 : 16) # "error"

    if is_animated_gif
        if variable_palette
            # generate a colorpalette for each frame for highest quality, but larger filesize
            palette = "palettegen=stats_mode=single[pal],[0:v][pal]paletteuse=new=1"
            `-v $verbose_level -framerate $framerate -i $animdir/%06d.png -lavfi "$palette" -loop $loop -y $fn` |>
            ffmpeg_exe
        else
            # generate a colorpalette first so ffmpeg does not have to guess it
            `-v $verbose_level -i $animdir/%06d.png -vf "palettegen=stats_mode=full" -y "$animdir/palette.bmp"` |>
            ffmpeg_exe
            # then apply the palette to get better results
            `-v $verbose_level -framerate $framerate -i $animdir/%06d.png -i "$animdir/palette.bmp" -lavfi "paletteuse=dither=sierra2_4a" -loop $loop -y $fn` |>
            ffmpeg_exe
        end
    elseif file_extension(fn) in ("png", "apng")
        # FFMPEG specific command for APNG (Animated PNG) animations
        `-v $verbose_level -framerate $framerate -i $animdir/%06d.png -plays $loop -f apng  -y $fn` |>
        ffmpeg_exe
    else
        `-v $verbose_level -framerate $framerate -i $animdir/%06d.png -vf format=yuv420p -loop $loop -y $fn` |>
        ffmpeg_exe
    end

    show_msg && @info "Saved animation to $fn"
    AnimatedGif(fn)
end

# write out html to view the gif
function Base.show(io::IO, ::MIME"text/html", agif::AnimatedGif)
    html = if (ext = file_extension(agif.filename)) == "gif"
        "<img src=\"data:image/gif;base64,$(base64encode(read(agif.filename)))\" />"
    elseif ext == "apng"
        "<img src=\"data:image/png;base64,$(base64encode(read(agif.filename)))\" />"
    elseif ext in ("mov", "mp4", "webm")
        mimetype = ext == "mov" ? "video/quicktime" : "video/$ext"
        "<video controls><source src=\"data:$mimetype;base64,$(base64encode(read(agif.filename)))\" type = \"$mimetype\"></video>"
    else
        error("Cannot show animation with extension $ext: $agif")
    end

    write(io, html)
    nothing
end

# Only gifs can be shown via image/gif
Base.showable(::MIME"image/gif", agif::AnimatedGif) = file_extension(agif.filename) == "gif"
Base.showable(::MIME"image/png", agif::AnimatedGif) =
    let ext = file_extension(agif.filename)
        ext == "apng" || ext == "png"
    end

Base.show(io::IO, ::MIME"image/gif", agif::AnimatedGif) =
    open(fio -> write(io, fio), agif.filename)

Base.show(io::IO, ::MIME"image/png", agif::AnimatedGif) =
    open(fio -> write(io, fio), agif.filename)

# -----------------------------------------------

function _animate(forloop::Expr, args...; type::Symbol = :none)
    forloop.head ∈ (:for, :while) ||
        error("@animate macro expects a for- or while-block: $(forloop.head)")

    # add the call to frame to the end of each iteration
    animsym = gensym("anim")
    countersym = gensym("counter")
    freqassert = :()
    block = forloop.args[2]

    animationsKwargs = Any[]
    filterexpr = true

    n = length(args)
    i = 1
    # create filter and read parameters
    while i <= n
        arg = args[i]
        if arg in (:when, :every)
            # specification of frame filter
            @assert i < n
            filterexpr == true ||
                error("Can only specify one filterexpression (one of 'when' or 'every')")

            filterexpr = #      when          every
                arg == :when ? args[i + 1] : :(mod1($countersym, $(args[i + 1])) == 1)

            i += 1
        elseif arg isa Expr && arg.head == Symbol("=")
            #specification of type <kwarg> = <spec>
            lhs, rhs = arg.args
            push!(animationsKwargs, :($lhs = $rhs))
        else
            error("Parameter specification not understood: $(arg)")
        end
        i += 1
    end

    push!(block.args, :(
        if $filterexpr
            Plots.frame($animsym)
        end
    ))
    push!(block.args, :($countersym += 1))

    # add a final call to `gif(anim)`?
    retval = if type === :gif
        :(Plots.gif($animsym; $(animationsKwargs...)))
    elseif type === :apng
        :(Plots.apng($animsym; $(animationsKwargs...)))
    else
        animsym
    end

    # full expression:
    quote
        $freqassert                     # if filtering, check frequency is an Integer > 0
        $animsym = Plots.Animation()    # init animation object
        let $countersym = 1             # init iteration counter
            $forloop                    # for loop, saving a frame after each iteration
        end
        $retval                         # return the animation object, or the gif
    end |> esc
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
This macro supports additional parameters, that may be added after the main loop body.
- Add `fps=n` with positive Integer n, to specify the desired frames per second.
- Add `every n` with positive Integer n, to take only one frame every nth iteration.
- Add `when <cond>` where `<cond>` is an Expression resulting in a Boolean, to take a 
    frame only when `<cond>` returns `true`. Is incompatible with `every`.
"""
macro gif(forloop::Expr, args...)
    _animate(forloop, args...; type = :gif)
end

"""
Builds an `Animation` using one frame per loop iteration, then create an animated PNG (APNG).

Example:

```
  p = plot(1)
  @apng for x=0:0.1:5
    push!(p, 1, sin(x))
  end
```
This macro supports additional parameters, that may be added after the main loop body.
- Add `fps=n` with positive Integer n, to specify the desired frames per second.
- Add `every n` with positive Integer n, to take only one frame every nth iteration.
- Add `when <cond>` where `<cond>` is an Expression resulting in a Boolean, to take a 
    frame only when `<cond>` returns `true`. Is incompatible with `every`.
"""
macro apng(forloop::Expr, args...)
    _animate(forloop, args...; type = :apng)
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
This macro supports additional parameters, that may be added after the main loop body.
- Add `every n` with positive Integer n, to take only one frame every nth iteration.
- Add `when <cond>` where `<cond>` is an Expression resulting in a Boolean, to take a 
    frame only when `<cond>` returns `true`. Is incompatible with `every`.
"""
macro animate(forloop::Expr, args...)
    _animate(forloop, args...)
end
