
# note: I found this list of hex values in a comment by Tatarize here: http://stackoverflow.com/a/12224359
const _masterColorList = [
  0xFFFFFF,
  0x000000,
  0x0000FF,
  0x00FF00,
  0xFF0000,
  0x01FFFE,
  0xFFA6FE,
  0xFFDB66,
  0x006401,
  0x010067,
  0x95003A,
  0x007DB5,
  0xFF00F6,
  0xFFEEE8,
  0x774D00,
  0x90FB92,
  0x0076FF,
  0xD5FF00,
  0xFF937E,
  0x6A826C,
  0xFF029D,
  0xFE8900,
  0x7A4782,
  0x7E2DD2,
  0x85A900,
  0xFF0056,
  0xA42400,
  0x00AE7E,
  0x683D3B,
  0xBDC6FF,
  0x263400,
  0xBDD393,
  0x00B917,
  0x9E008E,
  0x001544,
  0xC28C9F,
  0xFF74A3,
  0x01D0FF,
  0x004754,
  0xE56FFE,
  0x788231,
  0x0E4CA1,
  0x91D0CB,
  0xBE9970,
  0x968AE8,
  0xBB8800,
  0x43002C,
  0xDEFF74,
  0x00FFC6,
  0xFFE502,
  0x620E00,
  0x008F9C,
  0x98FF52,
  0x7544B1,
  0xB500FF,
  0x00FF78,
  0xFF6E41,
  0x005F39,
  0x6B6882,
  0x5FAD4E,
  0xA75740,
  0xA5FFD2,
  0xFFB167,
  0x009BFF,
  0xE85EBE,
]


function darken(c, v=0.1)
    rgba = RGBA(c)
    r = max(0, min(rgba.r - v, 1))
    g = max(0, min(rgba.g - v, 1))
    b = max(0, min(rgba.b - v, 1))
    RGBA(r,g,b,rgba.alpha)
end
function lighten(c, v=0.3)
    darken(c, -v)
end

# --------------------------------------------------------------


convertColor(c::@compat(Union{AbstractString, Symbol})) = parse(Colorant, string(c))
convertColor(c::Colorant) = c
convertColor(cvec::AbstractVector) = map(convertColor, cvec)

# --------------------------------------------------------------

abstract ColorScheme

getColor(scheme::ColorScheme) = getColor(scheme, 1)
getColorVector(scheme::ColorScheme) = [getColor(scheme)]

colorscheme(scheme::ColorScheme) = scheme
colorscheme(s::Symbol) = haskey(_gradients, s) ? ColorGradient(s) : ColorWrapper(convertColor(s))
colorscheme{T<:Real}(s::Symbol, vals::AVec{T}) = ColorGradient(s, vals)
colorscheme(cs::AVec, vs::AVec) = ColorGradient(cs, vs)
colorscheme{T<:Colorant}(cs::AVec{T}) = ColorGradient(cs)
colorscheme(f::Function) = ColorFunction(f)
colorscheme(v::AVec) = ColorVector(v)
colorscheme(m::AMat) = size(m,1) == 1 ? map(colorscheme, m) : [colorscheme(m[:,i]) for i in 1:size(m,2)]'
colorscheme(c::Colorant) = ColorWrapper(c)

const _rainbowColors = [colorant"blue", colorant"purple", colorant"green", colorant"orange", colorant"red"]

@compat const _gradients = Dict(
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
  )

# --------------------------------------------------------------

"Continuous gradient between values.  Wraps a list of bounding colors and the values they represent."
immutable ColorGradient <: ColorScheme
  colors::Vector{Colorant}
  values::Vector{Float64}

  function ColorGradient{T<:Colorant,S<:Real}(cs::AVec{T}, vals::AVec{S} = 0:1)
    length(cs) == length(vals) && return new(cs, collect(vals))
    
    # otherwise interpolate evenly between the minval and maxval
    minval, maxval = minimum(vals), maximum(vals)
    vs = Float64[interpolate(minval, maxval, w) for w in linspace(0, 1, length(cs))]
    new(cs, vs)
  end
end

# create a gradient from a symbol (blues, reds, etc) and vector of boundary values
function ColorGradient{T<:Real}(s::Symbol, vals::AVec{T} = 0:1)
  haskey(_gradients, s) || error("Invalid gradient symbol.  Choose from: ", sort(collect(keys(_gradients))))

  # if we passed in the right number of values, create the gradient directly
  cs = _gradients[s]
  ColorGradient(cs, vals)
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

# function interpolate_lab(c1::Colorant, c2::Colorant, w::Real)
#   lab1 = Lab(c1)
#   lab2 = Lab(c2)
#   l = interpolate(lab1.l, lab2.l, w)
#   a = interpolate(lab1.a, lab2.a, w)
#   b = interpolate(lab1.b, lab2.b, w)
#   RGB(Lab(l, a, b))
# end

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
  ColorVector(v::AVec) = new(convertColor(v))
end

getColor(scheme::ColorVector, idx::Int) = convertColor(scheme.v[mod1(idx, length(scheme.v))])
getColorVector(scheme::ColorVector) = scheme.v


# --------------------------------------------------------------

"Wraps a single color"
immutable ColorWrapper{C<:Colorant} <: ColorScheme
  c::C
end

ColorWrapper(s::Symbol) = ColorWrapper(parse(Colorant, s))

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

const _allColors = map(convertHexToRGB, _masterColorList)
const _darkColors = filter(isdark, _allColors)
const _lightColors = filter(islight, _allColors)
const _sortedColorsForDarkBackground = vcat(_lightColors, reverse(_darkColors[2:end]))
const _sortedColorsForLightBackground = vcat(_darkColors, reverse(_lightColors[2:end]))

const _defaultNumColors = 20

function getPaletteUsingDistinguishableColors(bgcolor::Colorant, numcolors::Int = _defaultNumColors)
  palette = distinguishable_colors(numcolors, bgcolor)[2:end]

  # try to adjust lightness away from background color
  bg_lab = Lab(bgcolor)
  palette = RGB{Float64}[begin
    lab = Lab(rgb)
    Lab(
        adjustAway(lab.l, bg_lab.l, 25, 75),
        lab.a,
        lab.b
      )
  end for rgb in palette]
end

function getPaletteUsingFixedColorList(bgcolor::Colorant, numcolors::Int = _defaultNumColors)
  palette = isdark(bgcolor) ? _sortedColorsForDarkBackground : _sortedColorsForLightBackground
  palette[1:min(numcolors,length(palette))]
end

function getPaletteUsingColorDiffFromBackground(bgcolor::Colorant, numcolors::Int = _defaultNumColors)
  colordiffs = [colordiff(c, bgcolor) for c in _allColors]
  mindiff = colordiffs[reverse(sortperm(colordiffs))[numcolors]]
  filter(c -> colordiff(c, bgcolor) >= mindiff, _allColors)
end

function getPaletteUsingGradientSymbol(palette, bgcolor::Colorant, numcolors::Int = _defaultNumColors) #; gradientsym::Symbol = :auto)
  # @show gradientsym
  if palette == :auto
    grad = ColorGradient(_gradients[isdark(bgcolor) ? :lightrainbow : :darkrainbow])
  # elseif typeof(palette) <: AVec || typeof(palette) <: ColorGradient
  #   grad = ColorGradient(palette)
  else
    grad = ColorGradient(palette)
  end
  zrng = get_zvalues(numcolors)
  RGBA[getColorZ(grad, z) for z in zrng]
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

# TODO: try to use the algorithms from https://github.com/timothyrenner/ColorBrewer.jl
# TODO: allow the setting of the algorithm, either by passing a symbol (:colordiff, :fixed, etc) or a function? 

# function getBackgroundRGBColor(c, d::Dict)
function handlePlotColors(::PlottingPackage, d::Dict)
  if :background_color in supportedArgs()
    bgcolor = convertColor(d[:background_color])
  else
    bgcolor = _plotDefaults[:background_color]
    if d[:background_color] != _plotDefaults[:background_color]
      warn("Cannot set background_color with backend $(backend())")
    end
  end

  # d[:color_palette] = getPaletteUsingDistinguishableColors(bgcolor)
  # d[:color_palette] = getPaletteUsingFixedColorList(bgcolor)
  # d[:color_palette] = getPaletteUsingColorDiffFromBackground(bgcolor)
  d[:color_palette] = getPaletteUsingGradientSymbol(get(d, :color_palette, :auto), bgcolor)

  # set the foreground color (text, ticks, gridlines) to be white or black depending
  # on how dark the background is.  
  fgcolor = get(d, :foreground_color, :auto)
  if fgcolor == :auto
    fgcolor = isdark(bgcolor) ? colorant"white" : colorant"black"
  else
    fgcolor = convertColor(fgcolor)
  end
  # if !haskey(d, :foreground_color) || d[:foreground_color] == :auto
  #   d[:foreground_color] = isdark(bgcolor) ? colorant"white" : colorant"black"
  # else
  #   d[:foreground_color] = convertColor(d[:foreground_color])
  # end

  # bgcolor
  d[:background_color] = colorscheme(bgcolor)
  d[:foreground_color] = colorscheme(fgcolor)
end

# converts a symbol or string into a colorant (Colors.RGB), and assigns a color automatically
function getSeriesRGBColor(c, d::Dict, n::Int)

  if c == :auto
    c = autopick(d[:color_palette], n)
  end

  # c should now be a subtype of ColorScheme
  colorscheme(c)
end
