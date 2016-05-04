
const _invisible = RGBA(0,0,0,0)

const _themes = KW(
    :default => KW(
        :bg         => :white,
        :bglegend   => :match,
        :bginside   => :match,
        :bgoutside  => :match,
        :fg         => :auto,
        :fglegend   => :match,
        :fggrid     => :match,
        :fgaxis     => :match,
        :fgtext     => :match,
        :fgborder   => :match,
        :fgguide    => :match,
    )
)

function add_theme(sym::Symbol, theme::KW)
    _themes[sym] = theme
end

# add a new theme, using an existing theme as the base
function add_theme(sym::Symbol;
                   base      = :default,  # start with this theme
                   bg        = _themes[base][:bg],
                   bglegend  = _themes[base][:bglegend],
                   bginside  = _themes[base][:bginside],
                   bgoutside = _themes[base][:bgoutside],
                   fg        = _themes[base][:fg],
                   fglegend  = _themes[base][:fglegend],
                   fggrid    = _themes[base][:fggrid],
                   fgaxis    = _themes[base][:fgaxis],
                   fgtext    = _themes[base][:fgtext],
                   fgborder  = _themes[base][:fgborder],
                   fgguide   = _themes[base][:fgguide],
                   kw...)
    _themes[sym] = merge(KW(
        :bg => bg,
        :bglegend  => bglegend,
        :bginside  => bginside,
        :bgoutside => bgoutside,
        :fg        => fg,
        :fglegend  => fglegend,
        :fggrid    => fggrid,
        :fgaxis    => fgaxis,
        :fgtext    => fgtext,
        :fgborder  => fgborder,
        :fgguide   => fgguide,
    ), KW(kw))
end

add_theme(:ggplot2,
    bglegend = _invisible,
    bginside = :lightgray,
    fg       = :white,
    fglegend = _invisible,
    fgtext   = :gray,
    fgguide  = :black
)

function set_theme(sym::Symbol)
    default(; _themes[sym]...)
end
