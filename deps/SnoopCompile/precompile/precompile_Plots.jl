const __bodyfunction__ = Dict{Method,Any}()

# Find keyword "body functions" (the function that contains the body
# as written by the developer, called after all missing keyword-arguments
# have been assigned values), in a manner that doesn't depend on
# gensymmed names.
# `mnokw` is the method that gets called when you invoke it without
# supplying any keywords.
function __lookup_kwbody__(mnokw::Method)
    function getsym(arg)
        isa(arg, Symbol) && return arg
        @assert isa(arg, GlobalRef)
        return arg.name
    end

    f = get(__bodyfunction__, mnokw, nothing)
    if f === nothing
        fmod = mnokw.module
        # The lowered code for `mnokw` should look like
        #   %1 = mkw(kwvalues..., #self#, args...)
        #        return %1
        # where `mkw` is the name of the "active" keyword body-function.
        ast = Base.uncompressed_ast(mnokw)
        if isa(ast, Core.CodeInfo) && length(ast.code) >= 2
            callexpr = ast.code[end-1]
            if isa(callexpr, Expr) && callexpr.head == :call
                fsym = callexpr.args[1]
                if isa(fsym, Symbol)
                    f = getfield(fmod, fsym)
                elseif isa(fsym, GlobalRef)
                    if fsym.mod === Core && fsym.name === :_apply
                        f = getfield(mnokw.module, getsym(callexpr.args[2]))
                    elseif fsym.mod === Core && fsym.name === :_apply_iterate
                        f = getfield(mnokw.module, getsym(callexpr.args[3]))
                    else
                        f = getfield(fsym.mod, fsym.name)
                    end
                else
                    f = missing
                end
            else
                f = missing
            end
        else
            f = missing
        end
        __bodyfunction__[mnokw] = f
    end
    return f
end

function _precompile_()
    ccall(:jl_generating_output, Cint, ()) == 1 || return nothing
    Base.precompile(Tuple{Core.kwftype(typeof(Type)),NamedTuple{(:label, :blank),Tuple{Symbol,Bool}},Type{EmptyLayout}})
    Base.precompile(Tuple{Core.kwftype(typeof(Type)),NamedTuple{(:label, :width, :height),Tuple{Symbol,Symbol,Length{:pct,Float64}}},Type{EmptyLayout}})
    Base.precompile(Tuple{Core.kwftype(typeof(Type)),NamedTuple{(:parent,),Tuple{GridLayout}},Type{Subplot},GRBackend})
    Base.precompile(Tuple{Core.kwftype(typeof(Type)),NamedTuple{(:parent,),Tuple{GridLayout}},Type{Subplot},PlotlyBackend})
    Base.precompile(Tuple{Core.kwftype(typeof(Type)),NamedTuple{(:parent,),Tuple{Subplot{GRBackend}}},Type{Subplot},GRBackend})
    Base.precompile(Tuple{Core.kwftype(typeof(Type)),NamedTuple{(:parent,),Tuple{Subplot{PlotlyBackend}}},Type{Subplot},PlotlyBackend})
    Base.precompile(Tuple{Core.kwftype(typeof(_make_hist)),NamedTuple{(:normed, :weights),Tuple{Bool,Array{Int64,1}}},typeof(_make_hist),Tuple{Array{Float64,1}},Symbol})
    Base.precompile(Tuple{Core.kwftype(typeof(_make_hist)),NamedTuple{(:normed, :weights),Tuple{Bool,Nothing}},typeof(_make_hist),Tuple{Array{Float64,1},Array{Float64,1}},Int64})
    Base.precompile(Tuple{Core.kwftype(typeof(_make_hist)),NamedTuple{(:normed, :weights),Tuple{Bool,Nothing}},typeof(_make_hist),Tuple{Array{Float64,1}},Symbol})
    Base.precompile(Tuple{Core.kwftype(typeof(attr!)),NamedTuple{(:flip,),Tuple{Bool}},typeof(attr!),Axis})
    Base.precompile(Tuple{Core.kwftype(typeof(attr!)),NamedTuple{(:formatter,),Tuple{Symbol}},typeof(attr!),Axis})
    Base.precompile(Tuple{Core.kwftype(typeof(attr!)),NamedTuple{(:formatter,),Tuple{typeof(datetimeformatter)}},typeof(attr!),Axis})
    Base.precompile(Tuple{Core.kwftype(typeof(attr!)),NamedTuple{(:grid, :lims),Tuple{Bool,Tuple{Float64,Float64}}},typeof(attr!),Axis})
    Base.precompile(Tuple{Core.kwftype(typeof(attr!)),NamedTuple{(:grid, :lims, :flip),Tuple{Bool,Tuple{Float64,Float64},Bool}},typeof(attr!),Axis})
    Base.precompile(Tuple{Core.kwftype(typeof(attr!)),NamedTuple{(:gridlinewidth, :grid, :gridalpha, :gridstyle, :foreground_color_grid),Tuple{Int64,Bool,Float64,Symbol,RGBA{Float64}}},typeof(attr!),Axis})
    Base.precompile(Tuple{Core.kwftype(typeof(attr!)),NamedTuple{(:guide,),Tuple{String}},typeof(attr!),Axis})
    Base.precompile(Tuple{Core.kwftype(typeof(attr!)),NamedTuple{(:lims, :flip, :ticks, :guide),Tuple{Tuple{Int64,Int64},Bool,StepRange{Int64,Int64},String}},typeof(attr!),Axis})
    Base.precompile(Tuple{Core.kwftype(typeof(attr!)),NamedTuple{(:lims,),Tuple{Tuple{Float64,Float64}}},typeof(attr!),Axis})
    Base.precompile(Tuple{Core.kwftype(typeof(attr!)),NamedTuple{(:lims,),Tuple{Tuple{Int64,Float64}}},typeof(attr!),Axis})
    Base.precompile(Tuple{Core.kwftype(typeof(attr!)),NamedTuple{(:lims,),Tuple{Tuple{Int64,Int64}}},typeof(attr!),Axis})
    Base.precompile(Tuple{Core.kwftype(typeof(attr!)),NamedTuple{(:rotation,),Tuple{Int64}},typeof(attr!),Axis})
    Base.precompile(Tuple{Core.kwftype(typeof(attr!)),NamedTuple{(:scale, :guide),Tuple{Symbol,String}},typeof(attr!),Axis})
    Base.precompile(Tuple{Core.kwftype(typeof(attr!)),NamedTuple{(:ticks,),Tuple{Nothing}},typeof(attr!),Axis})
    Base.precompile(Tuple{Core.kwftype(typeof(attr!)),NamedTuple{(:ticks,),Tuple{UnitRange{Int64}}},typeof(attr!),Axis})
    Base.precompile(Tuple{Core.kwftype(typeof(default)),NamedTuple{(:titlefont, :legendfontsize, :guidefont, :tickfont, :guide, :framestyle, :yminorgrid),Tuple{Tuple{Int64,String},Int64,Tuple{Int64,Symbol},Tuple{Int64,Symbol},String,Symbol,Bool}},typeof(default)})
    Base.precompile(Tuple{Core.kwftype(typeof(gr_polyline)),NamedTuple{(:arrowside, :arrowstyle),Tuple{Symbol,Symbol}},typeof(gr_polyline),Array{Int64,1},Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(gr_polyline)),NamedTuple{(:arrowside, :arrowstyle),Tuple{Symbol,Symbol}},typeof(gr_polyline),StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(gr_polyline)),NamedTuple{(:arrowside, :arrowstyle),Tuple{Symbol,Symbol}},typeof(gr_polyline),StepRange{Int64,Int64},Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(gr_polyline)),NamedTuple{(:arrowside, :arrowstyle),Tuple{Symbol,Symbol}},typeof(gr_polyline),UnitRange{Int64},Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(gr_polyline)),NamedTuple{(:arrowside, :arrowstyle),Tuple{Symbol,Symbol}},typeof(gr_polyline),UnitRange{Int64},UnitRange{Int64}})
    Base.precompile(Tuple{Core.kwftype(typeof(heatmap)),Any,typeof(heatmap),Any,Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(hline!)),Any,typeof(hline!),Any})
    Base.precompile(Tuple{Core.kwftype(typeof(lens!)),Any,typeof(lens!),Any,Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(plot!)),NamedTuple{(:alpha, :seriestype),Tuple{Float64,Symbol}},typeof(plot!),Array{GeometryBasics.Point{2,Float64},1}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot!)),NamedTuple{(:alpha, :seriestype),Tuple{Float64,Symbol}},typeof(plot!),Plot{GRBackend},Array{GeometryBasics.Point{2,Float64},1}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot!)),NamedTuple{(:annotation,),Tuple{Array{Tuple{Int64,Float64,PlotText},1}}},typeof(plot!)})
    Base.precompile(Tuple{Core.kwftype(typeof(plot!)),NamedTuple{(:line, :seriestype),Tuple{Tuple{Int64,Symbol,Float64,Array{Symbol,2}},Symbol}},typeof(plot!),Array{Float64,2}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot!)),NamedTuple{(:lw, :color),Tuple{Int64,Symbol}},typeof(plot!),Function,Float64,Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(plot!)),NamedTuple{(:lw, :color),Tuple{Int64,Symbol}},typeof(plot!),Plot{GRBackend},Function,Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(plot!)),NamedTuple{(:marker, :series_annotations, :seriestype),Tuple{Tuple{Int64,Float64,Symbol},Array{Any,1},Symbol}},typeof(plot!),Plot{GRBackend},StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(plot!)),NamedTuple{(:marker, :series_annotations, :seriestype),Tuple{Tuple{Int64,Float64,Symbol},Array{Any,1},Symbol}},typeof(plot!),Plot{PlotlyBackend},StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(plot!)),NamedTuple{(:marker, :series_annotations, :seriestype),Tuple{Tuple{Int64,Float64,Symbol},Array{Any,1},Symbol}},typeof(plot!),StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot!)),NamedTuple{(:markersize, :c, :seriestype),Tuple{Int64,Symbol,Symbol}},typeof(plot!),Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot!)),NamedTuple{(:seriestype, :inset),Tuple{Symbol,Tuple{Int64,BoundingBox{Tuple{Length{:w,Float64},Length{:h,Float64}},Tuple{Length{:w,Float64},Length{:h,Float64}}}}}},typeof(plot!),Array{Int64,1},Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot!)),NamedTuple{(:seriestype, :inset),Tuple{Symbol,Tuple{Int64,BoundingBox{Tuple{Length{:w,Float64},Length{:h,Float64}},Tuple{Length{:w,Float64},Length{:h,Float64}}}}}},typeof(plot!),Plot{GRBackend},Array{Int64,1},Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(plot!)),NamedTuple{(:seriestype, :inset),Tuple{Symbol,Tuple{Int64,BoundingBox{Tuple{Length{:w,Float64},Length{:h,Float64}},Tuple{Length{:w,Float64},Length{:h,Float64}}}}}},typeof(plot!),Plot{PlotlyBackend},Array{Int64,1},Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(plot!)),NamedTuple{(:seriestype,),Tuple{Symbol}},typeof(plot!),Array{Int64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot!)),NamedTuple{(:seriestype,),Tuple{Symbol}},typeof(plot!),Plot{PlotlyBackend},Array{Int64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot!)),NamedTuple{(:title,),Tuple{String}},typeof(plot!)})
    Base.precompile(Tuple{Core.kwftype(typeof(plot!)),NamedTuple{(:w,),Tuple{Int64}},typeof(plot!),Plot{GRBackend},Array{Float64,1},Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(plot!)),NamedTuple{(:yaxis,),Tuple{Tuple{String,Symbol}}},typeof(plot!)})
    Base.precompile(Tuple{Core.kwftype(typeof(plot!)),NamedTuple{(:zcolor, :m, :ms, :lab, :seriestype),Tuple{Array{Float64,1},Tuple{Symbol,Float64,Stroke},Array{Float64,1},String,Symbol}},typeof(plot!),Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot!)),NamedTuple{(:zcolor, :m, :ms, :lab, :seriestype),Tuple{Array{Float64,1},Tuple{Symbol,Float64,Stroke},Array{Float64,1},String,Symbol}},typeof(plot!),Plot{GRBackend},Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot!)),NamedTuple{(:zcolor, :m, :ms, :lab, :seriestype),Tuple{Array{Float64,1},Tuple{Symbol,Float64,Stroke},Array{Float64,1},String,Symbol}},typeof(plot!),Plot{PlotlyBackend},Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:annotations, :leg),Tuple{Tuple{Int64,Float64,PlotText},Bool}},typeof(plot),Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:aspect_ratio, :seriestype),Tuple{Int64,Symbol}},typeof(plot),Array{String,1},Array{String,1},Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:bins, :weights, :seriestype),Tuple{Symbol,Array{Int64,1},Symbol}},typeof(plot),Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:color, :line, :marker),Tuple{Array{Symbol,2},Tuple{Symbol,Int64},Tuple{Array{Symbol,2},Int64,Float64,Stroke}}},typeof(plot),Array{Array{T,1} where T,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:connections, :seriestype),Tuple{Tuple{Array{Int64,1},Array{Int64,1},Array{Int64,1}},Symbol}},typeof(plot),Array{Int64,1},Array{Int64,1},Vararg{Array{Int64,1},N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:fill, :seriestype),Tuple{Bool,Symbol}},typeof(plot),StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:framestyle, :title, :color, :layout, :label, :markerstrokewidth, :ticks, :seriestype),Tuple{Array{Symbol,2},Array{String,2},Base.ReshapedArray{Int64,2,UnitRange{Int64},Tuple{}},Int64,String,Int64,UnitRange{Int64},Symbol}},typeof(plot),Array{Array{Float64,1},1},Array{Array{Float64,1},1}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:grid, :title),Tuple{Tuple{Symbol,Symbol,Symbol,Int64,Float64},String}},typeof(plot),Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:lab, :w, :palette, :fill, :α),Tuple{String,Int64,PlotUtils.ContinuousColorGradient,Int64,Float64}},typeof(plot),StepRange{Int64,Int64},Array{Float64,2}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:label, :title, :xlabel, :linewidth, :legend),Tuple{Array{String,2},String,String,Int64,Symbol}},typeof(plot),Array{Function,1},Float64,Vararg{Float64,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:label,),Tuple{Array{String,2}}},typeof(plot),Array{AbstractArray{Float64,1},1}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:layout, :group, :linetype, :linecolor),Tuple{GridLayout,Array{String,1},Array{Symbol,2},Symbol}},typeof(plot),Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:layout, :label, :fillrange, :fillalpha),Tuple{Tuple{Int64,Int64},String,Int64,Float64}},typeof(plot),Plot{GRBackend},Plot{GRBackend},Vararg{Plot{GRBackend},N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:layout, :label, :fillrange, :fillalpha),Tuple{Tuple{Int64,Int64},String,Int64,Float64}},typeof(plot),Plot{PlotlyBackend},Plot{PlotlyBackend},Vararg{Plot{PlotlyBackend},N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:layout, :link),Tuple{Int64,Symbol}},typeof(plot),Plot{GRBackend},Plot{GRBackend}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:layout, :link),Tuple{Int64,Symbol}},typeof(plot),Plot{PlotlyBackend},Plot{PlotlyBackend}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:layout, :palette, :bg_inside),Tuple{Int64,Array{PlotUtils.ContinuousColorGradient,2},Array{Symbol,2}}},typeof(plot),Array{Float64,2}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:layout, :t, :leg, :ticks, :border),Tuple{GridLayout,Array{Symbol,2},Bool,Nothing,Symbol}},typeof(plot),Array{Float64,2}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:layout, :title, :titlelocation, :left_margin, :bottom_margin, :xrotation),Tuple{GridLayout,Array{String,2},Symbol,Array{Length{:mm,Float64},2},Length{:mm,Float64},Int64}},typeof(plot),Array{Float64,2}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:layout, :xlims),Tuple{GridLayout,Tuple{Int64,Float64}}},typeof(plot),Plot{GRBackend},Plot{GRBackend},Vararg{Plot{GRBackend},N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:legend,),Tuple{Bool}},typeof(plot),Plot{GRBackend},Plot{GRBackend},Vararg{Plot{GRBackend},N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:legend,),Tuple{Bool}},typeof(plot),Plot{PlotlyBackend},Plot{PlotlyBackend},Vararg{Plot{PlotlyBackend},N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:legend,),Tuple{Symbol}},typeof(plot),Array{Tuple{Int64,Real},1}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:legend,),Tuple{Symbol}},typeof(plot),Plot{GRBackend},Plot{GRBackend},Vararg{Plot{GRBackend},N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:legend,),Tuple{Symbol}},typeof(plot),Plot{PlotlyBackend},Plot{PlotlyBackend},Vararg{Plot{PlotlyBackend},N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:line, :lab, :ms),Tuple{Tuple{Array{Symbol,2},Int64},Array{String,2},Int64}},typeof(plot),Array{Array{T,1} where T,1},Array{Float64,2}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:line, :label, :legendtitle),Tuple{Tuple{Int64,Array{Symbol,2}},Array{String,2},String}},typeof(plot),Array{Float64,2}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:line, :leg, :fill),Tuple{Int64,Bool,Tuple{Int64,Symbol}}},typeof(plot),Function,Function,Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:line, :marker, :bg, :fg, :xlim, :ylim, :leg),Tuple{Tuple{Int64,Symbol,Symbol},Tuple{Shape,Int64,RGBA{Float64}},Symbol,Symbol,Tuple{Int64,Int64},Tuple{Int64,Int64},Bool}},typeof(plot),StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:line_z, :linewidth, :legend),Tuple{StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Int64,Bool}},typeof(plot),Array{Float64,1},Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:m, :lab, :bg, :xlim, :ylim, :seriestype),Tuple{Tuple{Int64,Symbol},Array{String,2},Symbol,Tuple{Int64,Int64},Tuple{Int64,Int64},Symbol}},typeof(plot),StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Array{Float64,2}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:marker,),Tuple{Bool}},typeof(plot),Array{Union{Missing, Int64},1}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:marker_z, :color, :legend, :seriestype),Tuple{typeof(+),Symbol,Bool,Symbol}},typeof(plot),Array{Float64,1},Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:nbins, :seriestype),Tuple{Int64,Symbol}},typeof(plot),Array{Float64,1},Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:nbins, :show_empty_bins, :normed, :aspect_ratio, :seriestype),Tuple{Tuple{Int64,Int64},Bool,Bool,Int64,Symbol}},typeof(plot),Array{Complex{Float64},1}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:proj, :m),Tuple{Symbol,Int64}},typeof(plot),StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:projection, :seriestype),Tuple{Symbol,Symbol}},typeof(plot),Array{Int64,2}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:quiver, :seriestype),Tuple{Tuple{Array{Float64,1},Array{Float64,1},Array{Float64,1}},Symbol}},typeof(plot),Array{Float64,1},Array{Float64,1},Vararg{Array{Float64,1},N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:reg, :fill),Tuple{Bool,Tuple{Int64,Symbol}}},typeof(plot),Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:ribbon,),Tuple{Tuple{LinRange{Float64},LinRange{Float64}}}},typeof(plot),UnitRange{Int64}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:ribbon,),Tuple{typeof(sqrt)}},typeof(plot),UnitRange{Int64}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:seriestype, :markershape, :markersize, :color),Tuple{Array{Symbol,2},Array{Symbol,1},Int64,Array{Symbol,1}}},typeof(plot),Array{Float64,2}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:seriestype,),Tuple{Symbol}},typeof(plot),Array{DateTime,1},UnitRange{Int64},Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:seriestype,),Tuple{Symbol}},typeof(plot),Array{OHLC,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:st, :xlabel, :ylabel, :zlabel),Tuple{Symbol,String,String,String}},typeof(plot),Array{Float64,1},Array{Float64,1},Vararg{Array{Float64,1},N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:title, :l, :seriestype),Tuple{String,Float64,Symbol}},typeof(plot),Array{String,1},Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:title,),Tuple{Array{String,2}}},typeof(plot),Plot{GRBackend},Plot{GRBackend}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:title,),Tuple{Array{String,2}}},typeof(plot),Plot{PlotlyBackend},Plot{PlotlyBackend}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:title,),Tuple{String}},typeof(plot),Plot{GRBackend}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:title,),Tuple{String}},typeof(plot),Plot{PlotlyBackend}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:w,),Tuple{Int64}},typeof(plot),Array{Float64,2}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:xaxis, :background_color, :leg),Tuple{Tuple{String,Tuple{Int64,Int64},StepRange{Int64,Int64},Symbol},RGB{Float64},Bool}},typeof(plot),Array{Float64,2}})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:yflip, :aspect_ratio),Tuple{Bool,Symbol}},typeof(plot),Array{Float64,1},Array{Int64,1},Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(plot)),NamedTuple{(:zcolor, :m, :leg, :cbar, :w),Tuple{StepRange{Int64,Int64},Tuple{Int64,Float64,Symbol,Stroke},Bool,Bool,Int64}},typeof(plot),Array{Float64,1},Array{Float64,1},Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(portfoliocomposition)),Any,typeof(portfoliocomposition),Any,Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(scatter!)),Any,typeof(scatter!),Any,Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(scatter!)),Any,typeof(scatter!),Any})
    Base.precompile(Tuple{Core.kwftype(typeof(test_examples)),NamedTuple{(:skip, :disp),Tuple{Array{Int64,1},Bool}},typeof(test_examples),Symbol})
    Base.precompile(Tuple{Core.kwftype(typeof(test_examples)),NamedTuple{(:skip,),Tuple{Array{Int64,1}}},typeof(test_examples),Symbol})
    Base.precompile(Tuple{Type{GridLayout},Int64,Vararg{Int64,N} where N})
    Base.precompile(Tuple{Type{Shape},Array{Tuple{Float64,Float64},1}})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol,Any},AbstractArray{OHLC,1}})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol,Any},Array{Complex{Float64},1}})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol,Any},PortfolioComposition})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol,Any},Type{Val{:barhist}},Any,Any,Any})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol,Any},Type{Val{:bar}},Any,Any,Any})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol,Any},Type{Val{:histogram2d}},Any,Any,Any})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol,Any},Type{Val{:hline}},Any,Any,Any})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol,Any},Type{Val{:pie}},Any,Any,Any})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol,Any},Type{Val{:quiver}},Any,Any,Any})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol,Any},Type{Val{:spy}},Any,Any,Any})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol,Any},Type{Val{:sticks}},Any,Any,Any})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol,Any},Type{Val{:xerror}},Any,Any,Any})
    Base.precompile(Tuple{typeof(RecipesPipeline.add_series!),Plot{GRBackend},DefaultsDict})
    Base.precompile(Tuple{typeof(RecipesPipeline.add_series!),Plot{PlotlyBackend},DefaultsDict})
    Base.precompile(Tuple{typeof(RecipesPipeline.plot_setup!),Plot{GRBackend},Dict{Symbol,Any},Array{Dict{Symbol,Any},1}})
    Base.precompile(Tuple{typeof(RecipesPipeline.plot_setup!),Plot{PlotlyBackend},Dict{Symbol,Any},Array{Dict{Symbol,Any},1}})
    Base.precompile(Tuple{typeof(RecipesPipeline.preprocess_attributes!),Plot{GRBackend},DefaultsDict})
    Base.precompile(Tuple{typeof(RecipesPipeline.process_userrecipe!),Plot{GRBackend},Array{Dict{Symbol,Any},1},Dict{Symbol,Any}})
    Base.precompile(Tuple{typeof(RecipesPipeline.process_userrecipe!),Plot{PlotlyBackend},Array{Dict{Symbol,Any},1},Dict{Symbol,Any}})
    Base.precompile(Tuple{typeof(RecipesPipeline.warn_on_recipe_aliases!),Plot{GRBackend},DefaultsDict,Symbol,Any})
    Base.precompile(Tuple{typeof(RecipesPipeline.warn_on_recipe_aliases!),Plot{GRBackend},Dict{Symbol,Any},Symbol,Any})
    Base.precompile(Tuple{typeof(RecipesPipeline.warn_on_recipe_aliases!),Plot{PlotlyBackend},DefaultsDict,Symbol,Any})
    Base.precompile(Tuple{typeof(RecipesPipeline.warn_on_recipe_aliases!),Plot{PlotlyBackend},Dict{Symbol,Any},Symbol,Any})
    Base.precompile(Tuple{typeof(_bin_centers),StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}}})
    Base.precompile(Tuple{typeof(_cbar_unique),Array{Int64,1},String})
    Base.precompile(Tuple{typeof(_cbar_unique),Array{Nothing,1},String})
    Base.precompile(Tuple{typeof(_cbar_unique),Array{PlotUtils.ContinuousColorGradient,1},String})
    Base.precompile(Tuple{typeof(_cbar_unique),Array{StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},1},String})
    Base.precompile(Tuple{typeof(_cbar_unique),Array{Symbol,1},String})
    Base.precompile(Tuple{typeof(_cycle),Array{Float64,1},Array{Int64,1}})
    Base.precompile(Tuple{typeof(_cycle),Array{Float64,1},StepRange{Int64,Int64}})
    Base.precompile(Tuple{typeof(_cycle),Array{Float64,1},UnitRange{Int64}})
    Base.precompile(Tuple{typeof(_cycle),Base.OneTo{Int64},Array{Int64,1}})
    Base.precompile(Tuple{typeof(_cycle),StepRange{Int64,Int64},Array{Int64,1}})
    Base.precompile(Tuple{typeof(_do_plot_show),Plot{GRBackend},Bool})
    Base.precompile(Tuple{typeof(_do_plot_show),Plot{PlotlyBackend},Bool})
    Base.precompile(Tuple{typeof(_heatmap_edges),Array{Float64,1},Bool})
    Base.precompile(Tuple{typeof(_plot!),Plot,Any,Any})
    Base.precompile(Tuple{typeof(_preprocess_barlike),DefaultsDict,Base.OneTo{Int64},Array{Float64,1}})
    Base.precompile(Tuple{typeof(_preprocess_binlike),DefaultsDict,StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Array{Float64,1}})
    Base.precompile(Tuple{typeof(_replace_markershape),Array{Symbol,1}})
    Base.precompile(Tuple{typeof(_update_min_padding!),GridLayout})
    Base.precompile(Tuple{typeof(_update_plot_args),Plot{PlotlyBackend},DefaultsDict})
    Base.precompile(Tuple{typeof(_update_subplot_args),Plot{GRBackend},Subplot{GRBackend},Dict{Symbol,Any},Int64,Bool})
    Base.precompile(Tuple{typeof(_update_subplot_args),Plot{PlotlyBackend},Subplot{PlotlyBackend},Dict{Symbol,Any},Int64,Bool})
    Base.precompile(Tuple{typeof(backend),PlotlyBackend})
    Base.precompile(Tuple{typeof(bbox),Float64,Float64,Float64,Float64})
    Base.precompile(Tuple{typeof(bbox),Length{:mm,Float64},Length{:mm,Float64},Length{:mm,Float64},Length{:mm,Float64}})
    Base.precompile(Tuple{typeof(build_layout),GridLayout,Int64})
    Base.precompile(Tuple{typeof(contour),Any,Vararg{Any,N} where N})
    Base.precompile(Tuple{typeof(convert_to_polar),StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Array{Float64,1},Tuple{Int64,Float64}})
    Base.precompile(Tuple{typeof(create_grid),Expr})
    Base.precompile(Tuple{typeof(error_coords),Array{Float64,1},Array{Float64,1},Array{Float64,1}})
    Base.precompile(Tuple{typeof(error_zipit),Tuple{Array{Float64,1},Array{Float64,1},Array{Float64,1}}})
    Base.precompile(Tuple{typeof(fakedata),Int64,Vararg{Int64,N} where N})
    Base.precompile(Tuple{typeof(font),String,Vararg{Any,N} where N})
    Base.precompile(Tuple{typeof(get_clims),Subplot{GRBackend},Series,Function})
    Base.precompile(Tuple{typeof(get_minor_ticks),Subplot{GRBackend},Axis,Tuple{Array{Float64,1},Array{String,1}}})
    Base.precompile(Tuple{typeof(get_minor_ticks),Subplot{GRBackend},Axis,Tuple{Array{Int64,1},Array{String,1}}})
    Base.precompile(Tuple{typeof(get_series_color),Array{Symbol,1},Subplot{GRBackend},Int64,Symbol})
    Base.precompile(Tuple{typeof(get_series_color),Array{Symbol,1},Subplot{PlotlyBackend},Int64,Symbol})
    Base.precompile(Tuple{typeof(get_xy),Array{OHLC,1}})
    Base.precompile(Tuple{typeof(get_xy),OHLC{Float64},Int64,Float64})
    Base.precompile(Tuple{typeof(gr_add_legend),Subplot{GRBackend},NamedTuple{(:w, :h, :dy, :leftw, :textw, :rightw, :xoffset, :yoffset, :width_factor),NTuple{9,Float64}},Array{Float64,1}})
    Base.precompile(Tuple{typeof(gr_add_legend),Subplot{GRBackend},NamedTuple{(:w, :h, :dy, :leftw, :textw, :rightw, :xoffset, :yoffset, :width_factor),Tuple{Int64,Float64,Float64,Float64,Int64,Float64,Float64,Float64,Float64}},Array{Float64,1}})
    Base.precompile(Tuple{typeof(gr_display),Subplot{GRBackend},Length{:mm,Float64},Length{:mm,Float64},Array{Float64,1}})
    Base.precompile(Tuple{typeof(gr_draw_colorbar),GRColorbar,Subplot{GRBackend},Tuple{Float64,Float64},Array{Float64,1}})
    Base.precompile(Tuple{typeof(gr_draw_contour),Series,StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Array{Float64,2},Tuple{Float64,Float64}})
    Base.precompile(Tuple{typeof(gr_draw_grid),Subplot{GRBackend},Axis,Segments{Tuple{Float64,Float64}}})
    Base.precompile(Tuple{typeof(gr_draw_heatmap),Series,Array{Float64,1},Array{Float64,1},Array{Float64,2},Tuple{Float64,Float64}})
    Base.precompile(Tuple{typeof(gr_draw_heatmap),Series,Base.OneTo{Int64},Base.OneTo{Int64},Array{Float64,2},Tuple{Float64,Float64}})
    Base.precompile(Tuple{typeof(gr_draw_markers),Series,Array{Float64,1},Array{Float64,1},Tuple{Float64,Float64}})
    Base.precompile(Tuple{typeof(gr_draw_markers),Series,Array{Int64,1},Array{Float64,1},Tuple{Float64,Float64}})
    Base.precompile(Tuple{typeof(gr_draw_markers),Series,Base.OneTo{Int64},Array{Float64,1},Tuple{Float64,Float64}})
    Base.precompile(Tuple{typeof(gr_draw_markers),Series,StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Array{Float64,1},Tuple{Float64,Float64}})
    Base.precompile(Tuple{typeof(gr_draw_segments),Series,Array{Float64,1},Array{Float64,1},Int64,Tuple{Float64,Float64}})
    Base.precompile(Tuple{typeof(gr_draw_segments),Series,Base.OneTo{Int64},Array{Float64,1},Int64,Tuple{Float64,Float64}})
    Base.precompile(Tuple{typeof(gr_draw_segments),Series,Base.OneTo{Int64},Array{Float64,1},Nothing,Tuple{Float64,Float64}})
    Base.precompile(Tuple{typeof(gr_draw_segments),Series,StepRange{Int64,Int64},Array{Float64,1},Int64,Tuple{Float64,Float64}})
    Base.precompile(Tuple{typeof(gr_draw_surface),Series,Array{Float64,1},Array{Float64,1},Array{Float64,1},Tuple{Float64,Float64}})
    Base.precompile(Tuple{typeof(gr_draw_surface),Series,Array{Float64,1},Array{Float64,1},Array{Float64,2},Tuple{Float64,Float64}})
    Base.precompile(Tuple{typeof(gr_get_ticks_size),Tuple{Array{Float64,1},Array{Any,1}},Int64})
    Base.precompile(Tuple{typeof(gr_get_ticks_size),Tuple{Array{Float64,1},Array{String,1}},Int64})
    Base.precompile(Tuple{typeof(gr_get_ticks_size),Tuple{Array{Int64,1},Array{String,1}},Int64})
    Base.precompile(Tuple{typeof(gr_label_ticks),Subplot{GRBackend},Symbol,Tuple{Array{Float64,1},Array{String,1}}})
    Base.precompile(Tuple{typeof(gr_label_ticks_3d),Subplot{GRBackend},Symbol,Tuple{Array{Float64,1},Array{String,1}}})
    Base.precompile(Tuple{typeof(gr_polaraxes),Int64,Float64,Subplot{GRBackend}})
    Base.precompile(Tuple{typeof(gr_set_gradient),PlotUtils.ContinuousColorGradient})
    Base.precompile(Tuple{typeof(gr_viewport_from_bbox),Subplot{GRBackend},BoundingBox{Tuple{Length{:mm,Float64},Length{:mm,Float64}},Tuple{Length{:mm,Float64},Length{:mm,Float64}}},Length{:mm,Float64},Length{:mm,Float64},Array{Float64,1}})
    Base.precompile(Tuple{typeof(heatmap_edges),Array{Float64,1},Symbol})
    Base.precompile(Tuple{typeof(heatmap_edges),Base.OneTo{Int64},Symbol})
    Base.precompile(Tuple{typeof(heatmap_edges),StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Symbol})
    Base.precompile(Tuple{typeof(heatmap_edges),UnitRange{Int64},Symbol})
    Base.precompile(Tuple{typeof(ignorenan_minimum),Array{Int64,1}})
    Base.precompile(Tuple{typeof(iter_segments),Array{Float64,1},Array{Float64,1},UnitRange{Int64}})
    Base.precompile(Tuple{typeof(iter_segments),Base.OneTo{Int64},Array{Float64,1}})
    Base.precompile(Tuple{typeof(layout_args),Int64})
    Base.precompile(Tuple{typeof(make_fillrange_side),UnitRange{Int64},Array{Float64,1}})
    Base.precompile(Tuple{typeof(make_fillrange_side),UnitRange{Int64},LinRange{Float64}})
    Base.precompile(Tuple{typeof(optimal_ticks_and_labels),Subplot{GRBackend},Axis,StepRange{Int64,Int64}})
    Base.precompile(Tuple{typeof(optimal_ticks_and_labels),Subplot{GRBackend},Axis,UnitRange{Int64}})
    Base.precompile(Tuple{typeof(plot!),Any})
    Base.precompile(Tuple{typeof(plot),Any,Any})
    Base.precompile(Tuple{typeof(plot),Any})
    Base.precompile(Tuple{typeof(processGridArg!),DefaultsDict,Bool,Symbol})
    Base.precompile(Tuple{typeof(processGridArg!),Dict{Symbol,Any},Symbol,Symbol})
    Base.precompile(Tuple{typeof(processLineArg),Dict{Symbol,Any},Array{Symbol,2}})
    Base.precompile(Tuple{typeof(processLineArg),Dict{Symbol,Any},Symbol})
    Base.precompile(Tuple{typeof(processMarkerArg),Dict{Symbol,Any},Array{Symbol,2}})
    Base.precompile(Tuple{typeof(processMarkerArg),Dict{Symbol,Any},RGBA{Float64}})
    Base.precompile(Tuple{typeof(processMarkerArg),Dict{Symbol,Any},Shape})
    Base.precompile(Tuple{typeof(processMarkerArg),Dict{Symbol,Any},Stroke})
    Base.precompile(Tuple{typeof(processMarkerArg),Dict{Symbol,Any},Symbol})
    Base.precompile(Tuple{typeof(process_annotation),Subplot{GRBackend},Int64,Float64,PlotText})
    Base.precompile(Tuple{typeof(process_annotation),Subplot{PlotlyBackend},Int64,Float64,PlotText})
    Base.precompile(Tuple{typeof(process_axis_arg!),Dict{Symbol,Any},StepRange{Int64,Int64},Symbol})
    Base.precompile(Tuple{typeof(process_axis_arg!),Dict{Symbol,Any},Symbol,Symbol})
    Base.precompile(Tuple{typeof(process_axis_arg!),Dict{Symbol,Any},Tuple{Int64,Int64},Symbol})
    Base.precompile(Tuple{typeof(push!),Plot{GRBackend},Float64,Array{Float64,1}})
    Base.precompile(Tuple{typeof(push!),Segments{Tuple{Float64,Float64,Float64}},Tuple{Float64,Int64,Int64},Tuple{Float64,Float64,Int64}})
    Base.precompile(Tuple{typeof(quiver_using_arrows),DefaultsDict})
    Base.precompile(Tuple{typeof(quiver_using_hack),DefaultsDict})
    Base.precompile(Tuple{typeof(reset_axis_defaults_byletter!)})
    Base.precompile(Tuple{typeof(slice_arg),Array{Length{:mm,Float64},2},Int64})
    Base.precompile(Tuple{typeof(slice_arg),Array{PlotUtils.ContinuousColorGradient,2},Int64})
    Base.precompile(Tuple{typeof(slice_arg),Array{RGBA{Float64},2},Int64})
    Base.precompile(Tuple{typeof(slice_arg),Array{String,2},Int64})
    Base.precompile(Tuple{typeof(slice_arg),Array{Symbol,2},Int64})
    Base.precompile(Tuple{typeof(slice_arg),Base.ReshapedArray{Int64,2,UnitRange{Int64},Tuple{}},Int64})
    Base.precompile(Tuple{typeof(spy),Any})
    Base.precompile(Tuple{typeof(straightline_data),Tuple{Float64,Float64},Tuple{Float64,Float64},Array{Float64,1},Array{Float64,1},Int64})
    Base.precompile(Tuple{typeof(stroke),Int64,Vararg{Any,N} where N})
    Base.precompile(Tuple{typeof(text),String,Int64,Symbol,Vararg{Symbol,N} where N})
    Base.precompile(Tuple{typeof(text),String,Symbol,Int64,Vararg{Any,N} where N})
    Base.precompile(Tuple{typeof(title!),AbstractString})
    Base.precompile(Tuple{typeof(unzip),Array{GeometryBasics.Point{2,Float64},1}})
    Base.precompile(Tuple{typeof(vline!),Any})
    Base.precompile(Tuple{typeof(xgrid!),Plot{GRBackend},Symbol,Vararg{Any,N} where N})
    Base.precompile(Tuple{typeof(yaxis!),Any,Any})
    let fbody = try __lookup_kwbody__(which(plot!, ())) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Any,typeof(plot!),))
        end
    end
    let fbody = try __lookup_kwbody__(which(plot!, (Any,))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Any,typeof(plot!),Any,))
        end
    end
    let fbody = try __lookup_kwbody__(which(plot!, (Any,Vararg{Any,N} where N,))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Any,typeof(plot!),Any,Vararg{Any,N} where N,))
        end
    end
    let fbody = try __lookup_kwbody__(which(plot, (Any,))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Any,typeof(plot),Any,))
        end
    end
    let fbody = try __lookup_kwbody__(which(plot, (Any,Vararg{Any,N} where N,))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Any,typeof(plot),Any,Vararg{Any,N} where N,))
        end
    end
    let fbody = try __lookup_kwbody__(which(plot, (Plot,))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Any,typeof(plot),Plot,))
        end
    end
    let fbody = try __lookup_kwbody__(which(plot, (Plot,Plot,))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Any,typeof(plot),Plot,Plot,))
        end
    end
    let fbody = try __lookup_kwbody__(which(plot, (Plot,Plot,Vararg{Plot,N} where N,))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Any,typeof(plot),Plot,Plot,Vararg{Plot,N} where N,))
        end
    end
    let fbody = try __lookup_kwbody__(which(text, (String,Int64,Vararg{Any,N} where N,))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Base.Iterators.Pairs{Union{},Union{},Tuple{},NamedTuple{(),Tuple{}}},typeof(text),String,Int64,Vararg{Any,N} where N,))
        end
    end
    let fbody = try __lookup_kwbody__(which(text, (String,Symbol,Vararg{Any,N} where N,))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Base.Iterators.Pairs{Union{},Union{},Tuple{},NamedTuple{(),Tuple{}}},typeof(text),String,Symbol,Vararg{Any,N} where N,))
        end
    end
    let fbody = try __lookup_kwbody__(which(title!, (AbstractString,))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Any,typeof(title!),AbstractString,))
        end
    end
    let fbody = try __lookup_kwbody__(which(vline!, (Any,))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Any,typeof(vline!),Any,))
        end
    end
    let fbody = try __lookup_kwbody__(which(yaxis!, (Any,Vararg{Any,N} where N,))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Any,typeof(yaxis!),Any,Vararg{Any,N} where N,))
        end
    end
end
