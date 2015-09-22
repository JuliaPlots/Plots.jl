
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




convertColor(c::Union{AbstractString, Symbol}) = parse(Colorant, string(c))
convertColor(c::Colorant) = c
convertColor(cvec::AbstractVector) = map(convertColor, cvec)

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

# TODO: try to use the algorithms from https://github.com/timothyrenner/ColorBrewer.jl
# TODO: allow the setting of the algorithm, either by passing a symbol (:colordiff, :fixed, etc) or a function? 

# function getBackgroundRGBColor(c, d::Dict)
function handlePlotColors(::PlottingPackage, d::Dict)
  if :background_color in supportedArgs()
    bgcolor = convertColor(d[:background_color])
  else
    bgcolor = _plotDefaults[:background_color]
    if d[:background_color] != _plotDefaults[:background_color]
      warn("Cannot set background_color with backend $(plotter())")
    end
  end
  d[:background_color] = bgcolor

  # d[:color_palette] = getPaletteUsingDistinguishableColors(bgcolor)
  # d[:color_palette] = getPaletteUsingFixedColorList(bgcolor)
  d[:color_palette] = getPaletteUsingColorDiffFromBackground(bgcolor)

  # set the foreground color (text, ticks, gridlines) to be white or black depending
  # on how dark the background is.  
  if !haskey(d, :foreground_color) || d[:foreground_color] == :auto
    d[:foreground_color] = isdark(bgcolor) ? colorant"white" : colorant"black"
  else
    d[:foreground_color] = convertColor(d[:foreground_color])
  end

  # bgcolor
  d[:background_color] = bgcolor
end

# converts a symbol or string into a colorant (Colors.RGB), and assigns a color automatically
function getSeriesRGBColor(c, d::Dict, n::Int)

  if c == :auto
    c = autopick(d[:color_palette], n)
  else
    c = convertColor(c)
  end

  # # should be a RGB now... either it was passed in, generated automatically, or created from a string
  # @assert isa(c, Colorant)

  # return the RGB
  c
end
