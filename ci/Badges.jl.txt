module Badges

include("widths.jl")

export Badge
const gFontFamily = "font-family='Verdana,Geneva,DejaVu Sans,sans-serif'"

function roundUpToOdd(x)
    x = round(Int, x)
    iseven(x) ? x+1 : x
end

function preferredWidthOf(str)
    return roundUpToOdd(div(widthOf(str), 10))
end

function computeWidths( label, message )
    return (
        preferredWidthOf(label),
        preferredWidthOf(message)
    )
end

function renderLogo(
    logo,
    badgeHeight,
    horizPadding,
    logoWidth = 14,
    logoPadding = 0
    )
    if isempty(logo)
      return (
        false,
        0,
        "",
      )
    end
    logoHeight = 14
    y = (badgeHeight - logoHeight) ÷ 2
    x = horizPadding
    return (
      true,
      logoWidth + logoPadding,
      "<image x='$x' y='$y' width='$logoWidth' height='14' xlink:href='$(escapeXml(logo))'/>"
    )
end

function renderText(
    content,
    leftMargin,
    horizPadding = 0,
    verticalMargin = 0,
    shadow = true )
    if (isempty(content))
      return (renderedText="", width=0 )
    end

    textLength =  preferredWidthOf(content)
    escapedContent = escapeXml(content)

    shadowMargin = 150 + verticalMargin
    textMargin = 140 + verticalMargin

    outTextLength = 10 * textLength
    x = round(Int, 10 * (leftMargin + textLength / 2 + horizPadding))

    renderedText = ""
    if (shadow)
      renderedText = "<text x='$x' y='$shadowMargin' fill='#010101' fill-opacity='.3' transform='scale(.1)' textLength='$outTextLength'>$escapedContent</text>"
    end
    renderedText = renderedText * "<text x='$x' y='$textMargin' transform='scale(.1)' textLength='$outTextLength'>$escapedContent</text>"
    return (
      renderedText,
      textLength,
    )
end

function renderLinks(
    leftLink,
    rightLink,
    leftWidth,
    rightWidth,
    height
  )

    leftLink = escapeXml(leftLink)
    rightLink = escapeXml(rightLink)
    hasLeftLink = !isempty(leftLink)
    hasRightLink = !isempty(rightLink)
    leftLinkWidth = hasRightLink ? leftWidth : leftWidth + rightWidth

    function render( link, width )
      return "<a target='_blank' xlink:href='$link'><rect width='$width' height='$height' fill='rgba(0,0,0,0)'/></a>"
    end

    return (
      (hasRightLink ? render( rightLink, leftWidth + rightWidth) : "") *
      (hasLeftLink ? render( leftLink, leftLinkWidth) : "")
    )
end

function renderBadge(main, leftLink, rightLink, leftWidth, rightWidth, height )
    width = leftWidth + rightWidth
    return "<svg xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' width='$width' height='$height'>
      $main
      $(renderLinks(leftLink, rightLink, leftWidth, rightWidth, height ))
      </svg>"
end


"""
```
render(b::Badge)::String
```

Fully render a badge to SVG. Returns a String.
"""
function render(this)
    return stripXmlWhitespace(renderBadge(
      "<linearGradient id='s' x2='0' y2='100%'>
        <stop offset='0' stop-color='#bbb' stop-opacity='.1'/>
        <stop offset='1' stop-opacity='.1'/>
      </linearGradient>
      <clipPath id='r'>
        <rect width='$(this.width)' height='$(this.height)' rx='3' fill='#fff'/>
      </clipPath>
      <g clip-path='url(#r)'>
        <rect width='$(this.leftWidth)' height='$(this.height)' fill='$(this.labelColor)'/>
        <rect x='$(this.leftWidth)' width='$(this.rightWidth)' height='$(this.height)' fill='$(this.color)'/>
        <rect width='$(this.width)' height='$(this.height)' fill='url(#s)'/>
      </g>
      <g fill='#fff' text-anchor='middle' $(this.fontFamily) text-rendering='geometricPrecision' font-size='110'>
        $(this.renderedLogo)
        $(this.renderedLabel)
        $(this.renderedMessage)
      </g>",
      this.leftLink,
      this.rightLink,
      this.leftWidth,
      this.rightWidth,
      this.height,
    ))
end

"""
```
Badge(;
    label="",
    message,
    leftLink="",
    rightLink="",
    logo="",
    logoWidth=0,
    logoPadding=0,
    horizontalPadding = 5,
    color = "#4c1",
    labelColor = "#555",
    fontFamily = "font-family='Verdana,Geneva,DejaVu Sans,sans-serif'",
    height = 20,
    verticalMargin=0,
    shadow=true)::Badge
```

Create a Badge. Returns a Badges.Badge object, that contains metadata
and pre-rendered segments.
"""
function Badge(;
    label = "",
    message,
    leftLink = "",
    rightLink = "",
    logo = "",
    logoWidth = 0,
    logoPadding = 0,
    horizontalPadding = 5,
    color = "#4c1",
    labelColor = "#555",
    fontFamily = gFontFamily,
    height = 20,
    verticalMargin = 0,
    shadow = true)

    hasLogo, totalLogoWidth, renderedLogo  = renderLogo(
        logo,
        height,
        horizontalPadding,
        logoWidth,
        logoPadding,
    )

    hasLabel = !isempty(label)
    labelColor = hasLabel || hasLogo ? labelColor : color
    labelColor = escapeXml(labelColor)
    color = escapeXml(color)
    labelMargin = totalLogoWidth + 1

    renderedLabel, labelWidth = renderText(
        label,
        labelMargin,
        horizontalPadding,
        verticalMargin,
        shadow
    )

    leftWidth = hasLabel ? labelWidth + 2 * horizontalPadding + totalLogoWidth : 0

    messageMargin = leftWidth - (!isempty(message) ? 1 : 0)

    if (!hasLabel)
        if (hasLogo)
        messageMargin = messageMargin + totalLogoWidth + horizontalPadding
        else
        messageMargin = messageMargin + 1
        end
    end

    renderedMessage, messageWidth  = renderText(
        message,
        messageMargin,
        horizontalPadding,
        verticalMargin,
        shadow
    )

    rightWidth = messageWidth + 2 * horizontalPadding

    if (hasLogo && !hasLabel)
        rightWidth += totalLogoWidth + horizontalPadding - 1
    end
    width = leftWidth + rightWidth


    return (
        leftLink = leftLink,
        rightLink = rightLink,
        leftWidth = leftWidth,
        rightWidth = rightWidth,
        width = width,
        labelColor = labelColor,
        color = color,
        renderedLogo = renderedLogo,
        renderedLabel = renderedLabel,
        renderedMessage = renderedMessage,
        height = height,
        fontFamily = fontFamily
        )

end


function stripXmlWhitespace(xml)
    xml = replace(xml, r">\s+" => '>')
    xml = replace(xml, r"<\s+" => '<')
    return strip(xml)
end


function escapeXml(s)
    s |>
    x -> replace(x, '&' => "&amp;")   |>
    x -> replace(x, '<' => "&gt;")    |>
    x -> replace(x, '>' => "&lt;")    |>
    x -> replace(x, '\"' => "&quot;") |>
    x -> replace(x, '\'' => "&apos;")
end


"""
    `widthOfCharCode(charCode; approx=true)`

Width of one character in Verdana 110 pts.
If `approx` is true, any unknwon character will be measured as 'm'. Otherwise 0.0
"""
function widthOfCharCode(charCode; approx=true)
    if isControlChar(charCode); return 0.0; end
    res = findfirst(WIDTHS) do x
        charCode >= x[1][1] && charCode <= x[1][2]
    end
    if isnothing(res)
        if approx; return EM; else return 0.0; end
    else
        return WIDTHS[res][2]
    end
end

"""
Width of a String, displayed in Verdana 110 pts
"""
widthOf(text::AbstractString; approx=true) = reduce(+, [widthOfCharCode(Int(x), approx=approx) for x in text])

isControlChar(charCode) = charCode <=31 || charCode == 127

# Verdana font metrics precalculated from the npm package anafanafo
# =================================================================

const EM = widthOfCharCode(Int('m'))::Float64

end
