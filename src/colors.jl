
abstract ColorScheme

getColor(scheme::ColorScheme) = getColor(scheme, 1)
getColorVector(scheme::ColorScheme) = [getColor(scheme)]

colorscheme(scheme::ColorScheme) = scheme
colorscheme(s::Symbol; kw...) = haskey(_gradients, s) ? ColorGradient(s; kw...) : ColorWrapper(convertColor(s); kw...)
colorscheme{T<:Real}(s::Symbol, vals::AVec{T}; kw...) = ColorGradient(s, vals; kw...)
colorscheme(cs::AVec, vs::AVec; kw...) = ColorGradient(cs, vs; kw...)
colorscheme{T<:Colorant}(cs::AVec{T}; kw...) = ColorGradient(cs; kw...)
colorscheme(f::Function; kw...) = ColorFunction(f; kw...)
colorscheme(v::AVec; kw...) = ColorVector(v; kw...)
colorscheme(m::AMat; kw...) = size(m,1) == 1 ? map(c->colorscheme(c; kw...), m) : [colorscheme(m[:,i]; kw...) for i in 1:size(m,2)]'
colorscheme(c::Colorant; kw...) = ColorWrapper(c; kw...)


# --------------------------------------------------------------


convertColor(c::@compat(Union{AbstractString, Symbol})) = parse(Colorant, string(c))
convertColor(c::Colorant) = c
convertColor(cvec::AbstractVector) = map(convertColor, cvec)
convertColor(c::ColorScheme) = c

function convertColor(c, α::Real)
  c = convertColor(c)
  RGBA(RGB(c), α)
end
convertColor(cs::AVec, α::Real) = map(c -> convertColor(c, α), cs)
convertColor(c, α::@compat(Void)) = convertColor(c)

# backup... try to convert
getColor(c) = convertColor(c)

# --------------------------------------------------------------

function darken(c, v=0.1)
    rgba = convert(RGBA, c)
    r = max(0, min(rgba.r - v, 1))
    g = max(0, min(rgba.g - v, 1))
    b = max(0, min(rgba.b - v, 1))
    RGBA(r,g,b,rgba.alpha)
end
function lighten(c, v=0.3)
    darken(c, -v)
end

# --------------------------------------------------------------

const _rainbowColors = [colorant"blue", colorant"purple", colorant"green", colorant"orange", colorant"red"]
const _testColors = [colorant"darkblue", colorant"blueviolet",  colorant"darkcyan",colorant"green",
                     darken(colorant"yellow",0.3), colorant"orange", darken(colorant"red",0.2)]

const _gradients = KW(
    :blues        => [colorant"lightblue", colorant"darkblue"],
    :reds         => [colorant"lightpink", colorant"darkred"],
    :greens       => [colorant"lightgreen", colorant"darkgreen"],
    :redsblues    => [colorant"darkred", RGB(0.8,0.85,0.8), colorant"darkblue"],
    :bluesreds    => [colorant"darkblue", RGB(0.8,0.85,0.8), colorant"darkred"],
    :heat         => [colorant"lightyellow", colorant"orange", colorant"darkred"],
    :grays        => [RGB(.95,.95,.95),RGB(.05,.05,.05)],
    :rainbow      => _rainbowColors,
    :lightrainbow => map(lighten, _rainbowColors),
    :darkrainbow  => map(darken, _rainbowColors),
    :darktest     => _testColors,
    :lighttest    => map(c -> lighten(c, 0.3), _testColors),
  )

function register_gradient_colors{C<:Colorant}(name::Symbol, colors::AVec{C})
    _gradients[name] = colors
end

include("color_gradients.jl")

default_gradient() = ColorGradient(:inferno)

# --------------------------------------------------------------

"Continuous gradient between values.  Wraps a list of bounding colors and the values they represent."
immutable ColorGradient <: ColorScheme
  colors::Vector
  values::Vector

  function ColorGradient{S<:Real}(cs::AVec, vals::AVec{S} = linspace(0, 1, length(cs)); alpha = nothing)
    if length(cs) == length(vals)
      return new(convertColor(cs,alpha), collect(vals))
    end

    # # otherwise interpolate evenly between the minval and maxval
    # minval, maxval = minimum(vals), maximum(vals)
    # vs = Float64[interpolate(minval, maxval, w) for w in linspace(0, 1, length(cs))]
    # new(convertColor(cs,alpha), vs)

    # interpolate the colors for each value
    vals = merge(linspace(0, 1, length(cs)), vals)
    grad = ColorGradient(cs)
    cs = [getColorZ(grad, z) for z in linspace(0, 1, length(vals))]
    new(convertColor(cs, alpha), vals)
  end
end

# create a gradient from a symbol (blues, reds, etc) and vector of boundary values
function ColorGradient{T<:Real}(s::Symbol, vals::AVec{T} = 0:0; kw...)
  haskey(_gradients, s) || error("Invalid gradient symbol.  Choose from: ", sort(collect(keys(_gradients))))
  cs = _gradients[s]
  if vals == 0:0
    vals = linspace(0, 1, length(cs))
  end
  ColorGradient(cs, vals; kw...)
end

# function ColorGradient{T<:Real}(cs::AVec, vals::AVec{T} = linspace(0, 1, length(cs)); kw...)
#   ColorGradient(map(convertColor, cs), vals; kw...)
# end

function ColorGradient(grad::ColorGradient; alpha = nothing)
  ColorGradient(convertColor(grad.colors, alpha), grad.values)
end

getColor(gradient::ColorGradient, idx::Int) = gradient.colors[mod1(idx, length(gradient.colors))]

function getColorZ(gradient::ColorGradient, z::Real)
  cs = gradient.colors
  vs = gradient.values
  n = length(cs)
  @assert n > 0 && n == length(vs)

  # can we just return the first color?
  if z <= vs[1] || n == 1
    return cs[1]
  end

  # find the bounding colors and interpolate
  for i in 2:n
    if z <= vs[i]
      return interpolate_rgb(cs[i-1], cs[i], (z - vs[i-1]) / (vs[i] - vs[i-1]))
    end
  end

  # if we get here, return the last color
  cs[end]
end

getColorVector(gradient::ColorGradient) = gradient.colors

# for 0.3
Colors.RGBA(c::Colorant) = RGBA(red(c), green(c), blue(c), alpha(c))
Colors.RGB(c::Colorant) = RGB(red(c), green(c), blue(c))

function interpolate_rgb(c1::Colorant, c2::Colorant, w::Real)
  rgb1 = RGBA(c1)
  rgb2 = RGBA(c2)
  r = interpolate(rgb1.r, rgb2.r, w)
  g = interpolate(rgb1.g, rgb2.g, w)
  b = interpolate(rgb1.b, rgb2.b, w)
  a = interpolate(rgb1.alpha, rgb2.alpha, w)
  RGBA(r, g, b, a)
end


function interpolate(v1::Real, v2::Real, w::Real)
  (1-w) * v1 + w * v2
end

# --------------------------------------------------------------

"Wraps a function, taking an index and returning a Colorant"
immutable ColorFunction <: ColorScheme
  f::Function
end

getColor(scheme::ColorFunction, idx::Int) = scheme.f(idx)

# --------------------------------------------------------------

"Wraps a function, taking an z-value and returning a Colorant"
immutable ColorZFunction <: ColorScheme
  f::Function
end

getColorZ(scheme::ColorFunction, z::Real) = scheme.f(z)

# --------------------------------------------------------------

"Wraps a vector of colors... may be vector of Symbol/String/Colorant"
immutable ColorVector <: ColorScheme
  v::Vector{Colorant}
  ColorVector(v::AVec; alpha = nothing) = new(convertColor(v,alpha))
end

getColor(scheme::ColorVector, idx::Int) = convertColor(scheme.v[mod1(idx, length(scheme.v))])
getColorVector(scheme::ColorVector) = scheme.v


# --------------------------------------------------------------

"Wraps a single color"
immutable ColorWrapper <: ColorScheme
  c::RGBA
  ColorWrapper(c::Colorant; alpha = nothing) = new(convertColor(c, alpha))
end

ColorWrapper(s::Symbol; alpha = nothing) = ColorWrapper(convertColor(parse(Colorant, s), alpha))

getColor(scheme::ColorWrapper, idx::Int) = scheme.c
getColorZ(scheme::ColorWrapper, z::Real) = scheme.c

# --------------------------------------------------------------


isbackgrounddark(bgcolor::Color) = Lab(bgcolor).l < 0.5

# move closer to lighter/darker depending on background value
function adjustAway(val, bgval, vmin=0., vmax=100.)
  if bgval < 0.5 * (vmax+vmin)
    tmp = max(val, bgval)
    return 0.5 * (tmp + max(tmp, vmax))
  else
    tmp = min(val, bgval)
    return 0.5 * (tmp + min(tmp, vmin))
  end
end

# borrowed from http://stackoverflow.com/a/1855903:
lightnessLevel(c::Colorant) = 0.299 * red(c) + 0.587 * green(c) + 0.114 * blue(c)

isdark(c::Colorant) = lightnessLevel(c) < 0.5
islight(c::Colorant) = !isdark(c)

function convertHexToRGB(h::Unsigned)
  mask = 0x0000FF
  RGB([(x & mask) / 0xFF for x in  (h >> 16, h >> 8, h)]...)
end

# note: I found this list of hex values in a comment by Tatarize here: http://stackoverflow.com/a/12224359
const _masterColorList = [
    0xFFFFFF, 0x000000, 0x0000FF, 0x00FF00, 0xFF0000, 0x01FFFE, 0xFFA6FE, 0xFFDB66, 0x006401, 0x010067,
    0x95003A, 0x007DB5, 0xFF00F6, 0xFFEEE8, 0x774D00, 0x90FB92, 0x0076FF, 0xD5FF00, 0xFF937E, 0x6A826C,
    0xFF029D, 0xFE8900, 0x7A4782, 0x7E2DD2, 0x85A900, 0xFF0056, 0xA42400, 0x00AE7E, 0x683D3B, 0xBDC6FF,
    0x263400, 0xBDD393, 0x00B917, 0x9E008E, 0x001544, 0xC28C9F, 0xFF74A3, 0x01D0FF, 0x004754, 0xE56FFE,
    0x788231, 0x0E4CA1, 0x91D0CB, 0xBE9970, 0x968AE8, 0xBB8800, 0x43002C, 0xDEFF74, 0x00FFC6, 0xFFE502,
    0x620E00, 0x008F9C, 0x98FF52, 0x7544B1, 0xB500FF, 0x00FF78, 0xFF6E41, 0x005F39, 0x6B6882, 0x5FAD4E,
    0xA75740, 0xA5FFD2, 0xFFB167, 0x009BFF, 0xE85EBE
  ]
const _allColors = map(convertHexToRGB, _masterColorList)
const _darkColors = filter(isdark, _allColors)
const _lightColors = filter(islight, _allColors)
const _sortedColorsForDarkBackground = vcat(_lightColors, reverse(_darkColors[2:end]))
const _sortedColorsForLightBackground = vcat(_darkColors, reverse(_lightColors[2:end]))

const _defaultNumColors = 17

# --------------------------------------------------------------

# Methods to automatically generate gradients for color selection based on
# background color and a short list of seed colors

# here are some magic constants that could be changed if you really want
const _lightness_darkbg = [80.0]
const _lightness_lightbg = [60.0]
const _lch_c_const = [60]

function adjust_lch(color, l, c)
    lch = convert(LCHab, color)
    convert(RGB, LCHab(l, c, lch.h))
end

function lightness_from_background(bgcolor)
  bglight = convert(LCHab, bgcolor).l
  bglight < 50.0 ? _lightness_darkbg[1] : _lightness_lightbg[1]
end

function gradient_from_list(cs)
    zvalues = Plots.get_zvalues(length(cs))
    indices = sortperm(zvalues)
    sorted_colors = map(RGBA, cs[indices])
    sorted_zvalues = zvalues[indices]
    ColorGradient(sorted_colors, sorted_zvalues)
end

function generate_colorgradient(bgcolor = colorant"white";
                               color_bases = color_bases=[colorant"steelblue",colorant"orangered"],
                               lightness = lightness_from_background(bgcolor),
                               chroma = _lch_c_const[1],
                               n = _defaultNumColors)
  seed_colors = vcat(bgcolor, map(c -> adjust_lch(c, lightness, chroma), color_bases))
  colors = distinguishable_colors(n,
      seed_colors,
      lchoices=Float64[lightness],
      cchoices=Float64[chroma],
      hchoices=linspace(0, 340, 20)
    )[2:end]
  gradient_from_list(colors)
end

function get_color_palette(palette, bgcolor::@compat(Union{Colorant,ColorWrapper}), numcolors::Integer)
  grad = if palette == :auto
    generate_colorgradient(bgcolor)
  else
    ColorGradient(palette)
  end
  zrng = get_zvalues(numcolors)
  RGBA[getColorZ(grad, z) for z in zrng]
end

function get_color_palette(palette::Vector{RGBA}, bgcolor::@compat(Union{Colorant,ColorWrapper}), numcolors::Integer)
  palette
end

# ----------------------------------------------------------------------------------


function getpctrange(n::Int)
    n > 0 || error()
    n == 1 && return zeros(1)
    zs = [0.0, 1.0]
    for i in 3:n
        sorted = sort(zs)
        diffs = diff(sorted)
        widestj = 0
        widest = 0.0
        for (j,d) in enumerate(diffs)
            if d > widest
                widest = d
                widestj = j
            end
        end
        push!(zs, sorted[widestj] + 0.5 * diffs[widestj])
    end
    zs
end

function get_zvalues(n::Int)
    offsets = getpctrange(ceil(Int,n/4)+1)/4
    offsets = vcat(offsets[1], offsets[3:end])
    zvalues = Float64[]
    for offset in offsets
        append!(zvalues, offset + [0.0, 0.5, 0.25, 0.75])
    end
    vcat(zvalues[1], 1.0, zvalues[2:n-1])
end

# ----------------------------------------------------------------------------------


make255(x) = round(Int, 255 * x)

function webcolor(c::Color)
  @sprintf("rgb(%d, %d, %d)", [make255(f(c)) for f in [red,green,blue]]...)
end
function webcolor(c::TransparentColor)
  @sprintf("rgba(%d, %d, %d, %1.3f)", [make255(f(c)) for f in [red,green,blue]]..., alpha(c))
end
webcolor(cs::ColorScheme) = webcolor(getColor(cs))
webcolor(c) = webcolor(convertColor(c))
webcolor(c, α) = webcolor(convertColor(getColor(c), α))

# ----------------------------------------------------------------------------------

# TODO: allow the setting of the algorithm, either by passing a symbol (:colordiff, :fixed, etc) or a function?

function handlePlotColors(::AbstractBackend, d::KW)
    if :background_color in supportedArgs()
        bgcolor = convertColor(d[:background_color])
    else
        bgcolor = _plotDefaults[:background_color]
        if d[:background_color] != _plotDefaults[:background_color]
            warn("Cannot set background_color with backend $(backend())")
        end
    end


    d[:color_palette] = get_color_palette(get(d, :color_palette, :auto), bgcolor, 100)


    # set the foreground color (text, ticks, gridlines) to be white or black depending
    # on how dark the background is.
    fgcolor = get(d, :foreground_color, :auto)
    fgcolor = if fgcolor == :auto
        isdark(bgcolor) ? colorant"white" : colorant"black"
    else
        convertColor(fgcolor)
    end

    # bg/fg color
    d[:background_color] = colorscheme(bgcolor)
    d[:foreground_color] = colorscheme(fgcolor)

    # update sub-background colors
    for bgtype in ("legend", "inside", "outside")
        bgsym = symbol("background_color_" * bgtype)
        if d[bgsym] == :match
            d[bgsym] = d[:background_color]
        elseif d[bgsym] == nothing
            d[bgsym] = colorscheme(RGBA(0,0,0,0))
        end
    end

    # update sub-foreground colors
    for fgtype in ("legend", "grid", "axis", "text", "border", "guide")
        fgsym = symbol("foreground_color_" * fgtype)
        if d[fgsym] == :match
            d[fgsym] = d[:foreground_color]
        elseif d[fgsym] == nothing
            d[fgsym] = colorscheme(RGBA(0,0,0,0))
        end
    end


end

# converts a symbol or string into a colorant (Colors.RGB), and assigns a color automatically
function getSeriesRGBColor(c, plotargs::KW, n::Int)

  if c == :auto
    c = autopick(plotargs[:color_palette], n)
  end

  # c should now be a subtype of ColorScheme
  colorscheme(c)
end
