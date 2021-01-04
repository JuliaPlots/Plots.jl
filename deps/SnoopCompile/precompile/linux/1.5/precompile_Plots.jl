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
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.Type)),NamedTuple{(:label, :blank),Tuple{Symbol,Bool}},Type{Plots.EmptyLayout}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.Type)),NamedTuple{(:label, :width, :height),Tuple{Symbol,Symbol,Measures.Length{:pct,Float64}}},Type{Plots.EmptyLayout}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.Type)),NamedTuple{(:parent,),Tuple{Plots.GridLayout}},Type{Plots.Subplot},Plots.GRBackend})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.Type)),NamedTuple{(:parent,),Tuple{Plots.GridLayout}},Type{Plots.Subplot},Plots.PlotlyBackend})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.Type)),NamedTuple{(:parent,),Tuple{Plots.Subplot{Plots.GRBackend}}},Type{Plots.Subplot},Plots.GRBackend})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.Type)),NamedTuple{(:parent,),Tuple{Plots.Subplot{Plots.PlotlyBackend}}},Type{Plots.Subplot},Plots.PlotlyBackend})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots._make_hist)),NamedTuple{(:normed, :weights),Tuple{Bool,Array{Int64,1}}},typeof(Plots._make_hist),Tuple{Array{Float64,1}},Symbol})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots._make_hist)),NamedTuple{(:normed, :weights),Tuple{Bool,Nothing}},typeof(Plots._make_hist),Tuple{Array{Float64,1},Array{Float64,1}},Int64})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots._make_hist)),NamedTuple{(:normed, :weights),Tuple{Bool,Nothing}},typeof(Plots._make_hist),Tuple{Array{Float64,1}},Symbol})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.attr!)),NamedTuple{(:formatter,),Tuple{Symbol}},typeof(attr!),Plots.Axis})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.attr!)),NamedTuple{(:formatter,),Tuple{typeof(RecipesPipeline.datetimeformatter)}},typeof(attr!),Plots.Axis})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.attr!)),NamedTuple{(:grid, :lims),Tuple{Bool,Tuple{Int64,Int64}}},typeof(attr!),Plots.Axis})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.attr!)),NamedTuple{(:grid, :lims, :flip),Tuple{Bool,Tuple{Int64,Int64},Bool}},typeof(attr!),Plots.Axis})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.attr!)),NamedTuple{(:gridlinewidth, :grid, :gridalpha, :gridstyle, :foreground_color_grid),Tuple{Int64,Bool,Float64,Symbol,RGBA{Float64}}},typeof(attr!),Plots.Axis})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.attr!)),NamedTuple{(:guide,),Tuple{String}},typeof(attr!),Plots.Axis})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.attr!)),NamedTuple{(:lims, :flip, :ticks, :guide),Tuple{Tuple{Int64,Int64},Bool,StepRange{Int64,Int64},String}},typeof(attr!),Plots.Axis})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.attr!)),NamedTuple{(:lims,),Tuple{Tuple{Float64,Float64}}},typeof(attr!),Plots.Axis})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.attr!)),NamedTuple{(:lims,),Tuple{Tuple{Int64,Float64}}},typeof(attr!),Plots.Axis})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.attr!)),NamedTuple{(:rotation,),Tuple{Int64}},typeof(attr!),Plots.Axis})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.attr!)),NamedTuple{(:scale, :guide),Tuple{Symbol,String}},typeof(attr!),Plots.Axis})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.attr!)),NamedTuple{(:ticks,),Tuple{UnitRange{Int64}}},typeof(attr!),Plots.Axis})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.default)),NamedTuple{(:titlefont, :legendfontsize, :guidefont, :tickfont, :guide, :framestyle, :yminorgrid),Tuple{Tuple{Int64,String},Int64,Tuple{Int64,Symbol},Tuple{Int64,Symbol},String,Symbol,Bool}},typeof(default)})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.gr_polyline)),NamedTuple{(:arrowside, :arrowstyle),Tuple{Symbol,Symbol}},typeof(Plots.gr_polyline),Array{Int64,1},Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.gr_polyline)),NamedTuple{(:arrowside, :arrowstyle),Tuple{Symbol,Symbol}},typeof(Plots.gr_polyline),StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.gr_polyline)),NamedTuple{(:arrowside, :arrowstyle),Tuple{Symbol,Symbol}},typeof(Plots.gr_polyline),StepRange{Int64,Int64},Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.gr_polyline)),NamedTuple{(:arrowside, :arrowstyle),Tuple{Symbol,Symbol}},typeof(Plots.gr_polyline),UnitRange{Int64},Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.gr_polyline)),NamedTuple{(:arrowside, :arrowstyle),Tuple{Symbol,Symbol}},typeof(Plots.gr_polyline),UnitRange{Int64},UnitRange{Int64}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.heatmap)),Any,typeof(heatmap),Any,Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.hline!)),Any,typeof(hline!),Any})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.lens!)),Any,typeof(lens!),Any,Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot!)),NamedTuple{(:alpha, :seriestype),Tuple{Float64,Symbol}},typeof(plot!),Array{GeometryBasics.Point{2,Float64},1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot!)),NamedTuple{(:alpha, :seriestype),Tuple{Float64,Symbol}},typeof(plot!),Plots.Plot{Plots.GRBackend},Array{GeometryBasics.Point{2,Float64},1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot!)),NamedTuple{(:annotation,),Tuple{Array{Tuple{Int64,Float64,Plots.PlotText},1}}},typeof(plot!)})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot!)),NamedTuple{(:line, :seriestype),Tuple{Tuple{Int64,Symbol,Float64,Array{Symbol,2}},Symbol}},typeof(plot!),Array{Float64,2}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot!)),NamedTuple{(:line, :seriestype),Tuple{Tuple{Int64,Symbol,Float64,Array{Symbol,2}},Symbol}},typeof(plot!),Plots.Plot{Plots.GRBackend},Array{Float64,2}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot!)),NamedTuple{(:lw, :color),Tuple{Int64,Symbol}},typeof(plot!),Function,Float64,Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot!)),NamedTuple{(:lw, :color),Tuple{Int64,Symbol}},typeof(plot!),Plots.Plot{Plots.GRBackend},Function,Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot!)),NamedTuple{(:marker, :series_annotations, :seriestype),Tuple{Tuple{Int64,Float64,Symbol},Array{Any,1},Symbol}},typeof(plot!),Plots.Plot{Plots.GRBackend},StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot!)),NamedTuple{(:marker, :series_annotations, :seriestype),Tuple{Tuple{Int64,Float64,Symbol},Array{Any,1},Symbol}},typeof(plot!),Plots.Plot{Plots.PlotlyBackend},StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot!)),NamedTuple{(:marker, :series_annotations, :seriestype),Tuple{Tuple{Int64,Float64,Symbol},Array{Any,1},Symbol}},typeof(plot!),StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot!)),NamedTuple{(:markersize, :c, :seriestype),Tuple{Int64,Symbol,Symbol}},typeof(plot!),Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot!)),NamedTuple{(:seriestype, :inset),Tuple{Symbol,Tuple{Int64,Measures.BoundingBox{Tuple{Measures.Length{:w,Float64},Measures.Length{:h,Float64}},Tuple{Measures.Length{:w,Float64},Measures.Length{:h,Float64}}}}}},typeof(plot!),Array{Int64,1},Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot!)),NamedTuple{(:seriestype, :inset),Tuple{Symbol,Tuple{Int64,Measures.BoundingBox{Tuple{Measures.Length{:w,Float64},Measures.Length{:h,Float64}},Tuple{Measures.Length{:w,Float64},Measures.Length{:h,Float64}}}}}},typeof(plot!),Plots.Plot{Plots.GRBackend},Array{Int64,1},Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot!)),NamedTuple{(:seriestype, :inset),Tuple{Symbol,Tuple{Int64,Measures.BoundingBox{Tuple{Measures.Length{:w,Float64},Measures.Length{:h,Float64}},Tuple{Measures.Length{:w,Float64},Measures.Length{:h,Float64}}}}}},typeof(plot!),Plots.Plot{Plots.PlotlyBackend},Array{Int64,1},Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot!)),NamedTuple{(:seriestype,),Tuple{Symbol}},typeof(plot!),Array{Int64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot!)),NamedTuple{(:seriestype,),Tuple{Symbol}},typeof(plot!),Plots.Plot{Plots.GRBackend},Array{Int64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot!)),NamedTuple{(:title,),Tuple{String}},typeof(plot!),Plots.Plot{Plots.PlotlyBackend}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot!)),NamedTuple{(:title,),Tuple{String}},typeof(plot!)})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot!)),NamedTuple{(:w,),Tuple{Int64}},typeof(plot!),Plots.Plot{Plots.GRBackend},Array{Float64,1},Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot!)),NamedTuple{(:yaxis,),Tuple{Tuple{String,Symbol}}},typeof(plot!)})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot!)),NamedTuple{(:zcolor, :m, :ms, :lab, :seriestype),Tuple{Array{Float64,1},Tuple{Symbol,Float64,Plots.Stroke},Array{Float64,1},String,Symbol}},typeof(plot!),Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot!)),NamedTuple{(:zcolor, :m, :ms, :lab, :seriestype),Tuple{Array{Float64,1},Tuple{Symbol,Float64,Plots.Stroke},Array{Float64,1},String,Symbol}},typeof(plot!),Plots.Plot{Plots.GRBackend},Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot!)),NamedTuple{(:zcolor, :m, :ms, :lab, :seriestype),Tuple{Array{Float64,1},Tuple{Symbol,Float64,Plots.Stroke},Array{Float64,1},String,Symbol}},typeof(plot!),Plots.Plot{Plots.PlotlyBackend},Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:annotations, :leg),Tuple{Tuple{Int64,Float64,Plots.PlotText},Bool}},typeof(plot),Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:aspect_ratio, :seriestype),Tuple{Int64,Symbol}},typeof(plot),Array{String,1},Array{String,1},Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:bins, :weights, :seriestype),Tuple{Symbol,Array{Int64,1},Symbol}},typeof(plot),Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:color, :line, :marker),Tuple{Array{Symbol,2},Tuple{Symbol,Int64},Tuple{Array{Symbol,2},Int64,Float64,Plots.Stroke}}},typeof(plot),Array{Array{T,1} where T,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:connections, :seriestype),Tuple{Tuple{Array{Int64,1},Array{Int64,1},Array{Int64,1}},Symbol}},typeof(plot),Array{Int64,1},Array{Int64,1},Vararg{Array{Int64,1},N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:fill, :seriestype),Tuple{Bool,Symbol}},typeof(plot),StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:framestyle, :title, :color, :layout, :label, :markerstrokewidth, :ticks, :seriestype),Tuple{Array{Symbol,2},Array{String,2},Base.ReshapedArray{Int64,2,UnitRange{Int64},Tuple{}},Int64,String,Int64,UnitRange{Int64},Symbol}},typeof(plot),Array{Array{Float64,1},1},Array{Array{Float64,1},1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:grid, :title),Tuple{Tuple{Symbol,Symbol,Symbol,Int64,Float64},String}},typeof(plot),Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:lab, :w, :palette, :fill, :α),Tuple{String,Int64,PlotUtils.ContinuousColorGradient,Int64,Float64}},typeof(plot),StepRange{Int64,Int64},Array{Float64,2}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:label, :title, :xlabel, :linewidth, :legend),Tuple{Array{String,2},String,String,Int64,Symbol}},typeof(plot),Array{Function,1},Float64,Vararg{Float64,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:label,),Tuple{Array{String,2}}},typeof(plot),Array{AbstractArray{Float64,1},1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:layout, :group, :linetype, :linecolor),Tuple{Plots.GridLayout,Array{String,1},Array{Symbol,2},Symbol}},typeof(plot),Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:layout, :label, :fillrange, :fillalpha),Tuple{Tuple{Int64,Int64},String,Int64,Float64}},typeof(plot),Plots.Plot{Plots.GRBackend},Plots.Plot{Plots.GRBackend},Vararg{Plots.Plot{Plots.GRBackend},N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:layout, :label, :fillrange, :fillalpha),Tuple{Tuple{Int64,Int64},String,Int64,Float64}},typeof(plot),Plots.Plot{Plots.PlotlyBackend},Plots.Plot{Plots.PlotlyBackend},Vararg{Plots.Plot{Plots.PlotlyBackend},N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:layout, :link),Tuple{Int64,Symbol}},typeof(plot),Plots.Plot{Plots.GRBackend},Plots.Plot{Plots.GRBackend}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:layout, :link),Tuple{Int64,Symbol}},typeof(plot),Plots.Plot{Plots.PlotlyBackend},Plots.Plot{Plots.PlotlyBackend}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:layout, :palette, :bg_inside),Tuple{Int64,Array{PlotUtils.ContinuousColorGradient,2},Array{Symbol,2}}},typeof(plot),Array{Float64,2}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:layout, :t, :leg, :ticks, :border),Tuple{Plots.GridLayout,Array{Symbol,2},Bool,Nothing,Symbol}},typeof(plot),Array{Float64,2}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:layout, :title, :titlelocation, :left_margin, :bottom_margin, :xrotation),Tuple{Plots.GridLayout,Array{String,2},Symbol,Array{Measures.Length{:mm,Float64},2},Measures.Length{:mm,Float64},Int64}},typeof(plot),Array{Float64,2}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:layout, :xlims),Tuple{Plots.GridLayout,Tuple{Int64,Float64}}},typeof(plot),Plots.Plot{Plots.GRBackend},Plots.Plot{Plots.GRBackend},Vararg{Plots.Plot{Plots.GRBackend},N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:legend,),Tuple{Bool}},typeof(plot),Plots.Plot{Plots.GRBackend},Plots.Plot{Plots.GRBackend},Vararg{Plots.Plot{Plots.GRBackend},N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:legend,),Tuple{Bool}},typeof(plot),Plots.Plot{Plots.PlotlyBackend},Plots.Plot{Plots.PlotlyBackend},Vararg{Plots.Plot{Plots.PlotlyBackend},N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:legend,),Tuple{Symbol}},typeof(plot),Array{Tuple{Int64,Real},1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:legend,),Tuple{Symbol}},typeof(plot),Plots.Plot{Plots.GRBackend},Plots.Plot{Plots.GRBackend},Vararg{Plots.Plot{Plots.GRBackend},N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:legend,),Tuple{Symbol}},typeof(plot),Plots.Plot{Plots.PlotlyBackend},Plots.Plot{Plots.PlotlyBackend},Vararg{Plots.Plot{Plots.PlotlyBackend},N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:line, :lab, :ms),Tuple{Tuple{Array{Symbol,2},Int64},Array{String,2},Int64}},typeof(plot),Array{Array{T,1} where T,1},Array{Float64,2}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:line, :label, :legendtitle),Tuple{Tuple{Int64,Array{Symbol,2}},Array{String,2},String}},typeof(plot),Array{Float64,2}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:line, :leg, :fill),Tuple{Int64,Bool,Tuple{Int64,Symbol}}},typeof(plot),Function,Function,Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:line, :marker, :bg, :fg, :xlim, :ylim, :leg),Tuple{Tuple{Int64,Symbol,Symbol},Tuple{Shape,Int64,RGBA{Float64}},Symbol,Symbol,Tuple{Int64,Int64},Tuple{Int64,Int64},Bool}},typeof(plot),StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:line_z, :linewidth, :legend),Tuple{StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Int64,Bool}},typeof(plot),Array{Float64,1},Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:m, :lab, :bg, :xlim, :ylim, :seriestype),Tuple{Tuple{Int64,Symbol},Array{String,2},Symbol,Tuple{Int64,Int64},Tuple{Int64,Int64},Symbol}},typeof(plot),StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Array{Float64,2}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:marker,),Tuple{Bool}},typeof(plot),Array{Union{Missing, Int64},1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:marker_z, :color, :legend, :seriestype),Tuple{typeof(+),Symbol,Bool,Symbol}},typeof(plot),Array{Float64,1},Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:nbins, :seriestype),Tuple{Int64,Symbol}},typeof(plot),Array{Float64,1},Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:nbins, :show_empty_bins, :normed, :aspect_ratio, :seriestype),Tuple{Tuple{Int64,Int64},Bool,Bool,Int64,Symbol}},typeof(plot),Array{Complex{Float64},1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:proj, :m),Tuple{Symbol,Int64}},typeof(plot),StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:projection, :seriestype),Tuple{Symbol,Symbol}},typeof(plot),Array{Int64,2}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:quiver, :seriestype),Tuple{Tuple{Array{Float64,1},Array{Float64,1},Array{Float64,1}},Symbol}},typeof(plot),Array{Float64,1},Array{Float64,1},Vararg{Array{Float64,1},N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:reg, :fill),Tuple{Bool,Tuple{Int64,Symbol}}},typeof(plot),Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:ribbon,),Tuple{StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}}}},typeof(plot),UnitRange{Int64}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:ribbon,),Tuple{Tuple{LinRange{Float64},LinRange{Float64}}}},typeof(plot),UnitRange{Int64}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:ribbon,),Tuple{typeof(sqrt)}},typeof(plot),UnitRange{Int64}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:seriestype, :markershape, :markersize, :color),Tuple{Array{Symbol,2},Array{Symbol,1},Int64,Array{Symbol,1}}},typeof(plot),Array{Float64,2}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:seriestype,),Tuple{Symbol}},typeof(plot),Array{Dates.DateTime,1},UnitRange{Int64},Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:seriestype,),Tuple{Symbol}},typeof(plot),Array{OHLC,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:st, :xlabel, :ylabel, :zlabel),Tuple{Symbol,String,String,String}},typeof(plot),Array{Float64,1},Array{Float64,1},Vararg{Array{Float64,1},N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:title, :l, :seriestype),Tuple{String,Float64,Symbol}},typeof(plot),Array{String,1},Array{Float64,1}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:title,),Tuple{Array{String,2}}},typeof(plot),Plots.Plot{Plots.GRBackend},Plots.Plot{Plots.GRBackend}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:title,),Tuple{Array{String,2}}},typeof(plot),Plots.Plot{Plots.PlotlyBackend},Plots.Plot{Plots.PlotlyBackend}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:title,),Tuple{String}},typeof(plot),Plots.Plot{Plots.GRBackend}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:title,),Tuple{String}},typeof(plot),Plots.Plot{Plots.PlotlyBackend}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:w,),Tuple{Int64}},typeof(plot),Array{Float64,2}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:xaxis, :background_color, :leg),Tuple{Tuple{String,Tuple{Int64,Int64},StepRange{Int64,Int64},Symbol},RGB{Float64},Bool}},typeof(plot),Array{Float64,2}})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:yflip, :aspect_ratio),Tuple{Bool,Symbol}},typeof(plot),Array{Float64,1},Array{Int64,1},Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.plot)),NamedTuple{(:zcolor, :m, :leg, :cbar, :w),Tuple{StepRange{Int64,Int64},Tuple{Int64,Float64,Symbol,Plots.Stroke},Bool,Bool,Int64}},typeof(plot),Array{Float64,1},Array{Float64,1},Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.portfoliocomposition)),Any,typeof(portfoliocomposition),Any,Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.scatter!)),Any,typeof(scatter!),Any,Vararg{Any,N} where N})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.scatter!)),Any,typeof(scatter!),Any})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.test_examples)),NamedTuple{(:skip, :disp),Tuple{Array{Int64,1},Bool}},typeof(test_examples),Symbol})
    Base.precompile(Tuple{Core.kwftype(typeof(Plots.test_examples)),NamedTuple{(:skip,),Tuple{Array{Int64,1}}},typeof(test_examples),Symbol})
    Base.precompile(Tuple{Type{Plots.GridLayout},Int64,Vararg{Int64,N} where N})
    Base.precompile(Tuple{Type{Shape},Array{Tuple{Float64,Float64},1}})
    Base.precompile(Tuple{typeof(Base.Broadcast.copyto_nonleaf!),Array{PlotUtils.ContinuousColorGradient,1},Base.Broadcast.Broadcasted{Base.Broadcast.DefaultArrayStyle{1},Tuple{Base.OneTo{Int64}},typeof(Plots.get_colorgradient),Tuple{Base.Broadcast.Extruded{Array{Any,1},Tuple{Bool},Tuple{Int64}}}},Base.OneTo{Int64},Int64,Int64})
    Base.precompile(Tuple{typeof(Base.Broadcast.copyto_nonleaf!),Array{StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},1},Base.Broadcast.Broadcasted{Base.Broadcast.DefaultArrayStyle{1},Tuple{Base.OneTo{Int64}},typeof(Plots.contour_levels),Tuple{Base.Broadcast.Extruded{Array{Any,1},Tuple{Bool},Tuple{Int64}},Base.RefValue{Tuple{Float64,Float64}}}},Base.OneTo{Int64},Int64,Int64})
    Base.precompile(Tuple{typeof(Base.Broadcast.materialize),Base.Broadcast.Broadcasted{Base.Broadcast.DefaultArrayStyle{1},Nothing,typeof(Plots.contour_levels),Tuple{Array{Any,1},Base.RefValue{Tuple{Float64,Float64}}}}})
    Base.precompile(Tuple{typeof(Base.Broadcast.materialize),Base.Broadcast.Broadcasted{Base.Broadcast.DefaultArrayStyle{1},Nothing,typeof(Plots.get_linecolor),Tuple{Array{Any,1},Base.RefValue{Tuple{Float64,Float64}}}}})
    Base.precompile(Tuple{typeof(Base.collect_similar),Array{AbstractLayout,2},Base.Generator{Array{AbstractLayout,2},typeof(Plots._update_min_padding!)}})
    Base.precompile(Tuple{typeof(Base.vect),Tuple{Int64,Float64,Plots.PlotText},Vararg{Tuple{Int64,Float64,Plots.PlotText},N} where N})
    Base.precompile(Tuple{typeof(Plots._bin_centers),StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}}})
    Base.precompile(Tuple{typeof(Plots._cbar_unique),Array{Int64,1},String})
    Base.precompile(Tuple{typeof(Plots._cbar_unique),Array{Nothing,1},String})
    Base.precompile(Tuple{typeof(Plots._cbar_unique),Array{PlotUtils.ContinuousColorGradient,1},String})
    Base.precompile(Tuple{typeof(Plots._cbar_unique),Array{StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},1},String})
    Base.precompile(Tuple{typeof(Plots._cbar_unique),Array{Symbol,1},String})
    Base.precompile(Tuple{typeof(Plots._cycle),Array{Float64,1},Array{Int64,1}})
    Base.precompile(Tuple{typeof(Plots._cycle),Array{Float64,1},StepRange{Int64,Int64}})
    Base.precompile(Tuple{typeof(Plots._cycle),Array{Float64,1},UnitRange{Int64}})
    Base.precompile(Tuple{typeof(Plots._cycle),Base.OneTo{Int64},Array{Int64,1}})
    Base.precompile(Tuple{typeof(Plots._cycle),StepRange{Int64,Int64},Array{Int64,1}})
    Base.precompile(Tuple{typeof(Plots._do_plot_show),Plots.Plot{Plots.GRBackend},Bool})
    Base.precompile(Tuple{typeof(Plots._do_plot_show),Plots.Plot{Plots.PlotlyBackend},Bool})
    Base.precompile(Tuple{typeof(Plots._heatmap_edges),Array{Float64,1},Bool})
    Base.precompile(Tuple{typeof(Plots._plot!),Plots.Plot,Any,Any})
    Base.precompile(Tuple{typeof(Plots._preprocess_barlike),RecipesPipeline.DefaultsDict,Base.OneTo{Int64},Array{Float64,1}})
    Base.precompile(Tuple{typeof(Plots._preprocess_binlike),RecipesPipeline.DefaultsDict,StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Array{Float64,1}})
    Base.precompile(Tuple{typeof(Plots._replace_markershape),Array{Symbol,1}})
    Base.precompile(Tuple{typeof(Plots._update_min_padding!),Plots.GridLayout})
    Base.precompile(Tuple{typeof(Plots._update_subplot_args),Plots.Plot{Plots.GRBackend},Plots.Subplot{Plots.GRBackend},Dict{Symbol,Any},Int64,Bool})
    Base.precompile(Tuple{typeof(Plots._update_subplot_args),Plots.Plot{Plots.PlotlyBackend},Plots.Subplot{Plots.PlotlyBackend},Dict{Symbol,Any},Int64,Bool})
    Base.precompile(Tuple{typeof(Plots.build_layout),Plots.GridLayout,Int64})
    Base.precompile(Tuple{typeof(Plots.convert_to_polar),StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Array{Float64,1},Tuple{Int64,Float64}})
    Base.precompile(Tuple{typeof(Plots.create_grid),Expr})
    Base.precompile(Tuple{typeof(Plots.error_coords),Array{Float64,1},Array{Float64,1},Array{Float64,1}})
    Base.precompile(Tuple{typeof(Plots.error_zipit),Tuple{Array{Float64,1},Array{Float64,1},Array{Float64,1}}})
    Base.precompile(Tuple{typeof(Plots.fakedata),Int64,Vararg{Int64,N} where N})
    Base.precompile(Tuple{typeof(Plots.get_clims),Plots.Subplot{Plots.GRBackend},Plots.Series,Function})
    Base.precompile(Tuple{typeof(Plots.get_minor_ticks),Plots.Subplot{Plots.GRBackend},Plots.Axis,Tuple{Array{Float64,1},Array{String,1}}})
    Base.precompile(Tuple{typeof(Plots.get_minor_ticks),Plots.Subplot{Plots.GRBackend},Plots.Axis,Tuple{Array{Int64,1},Array{String,1}}})
    Base.precompile(Tuple{typeof(Plots.get_series_color),Array{Symbol,1},Plots.Subplot{Plots.GRBackend},Int64,Symbol})
    Base.precompile(Tuple{typeof(Plots.get_series_color),Array{Symbol,1},Plots.Subplot{Plots.PlotlyBackend},Int64,Symbol})
    Base.precompile(Tuple{typeof(Plots.get_xy),Array{OHLC,1}})
    Base.precompile(Tuple{typeof(Plots.gr_add_legend),Plots.Subplot{Plots.GRBackend},NamedTuple{(:w, :h, :dy, :leftw, :textw, :rightw, :xoffset, :yoffset, :width_factor),NTuple{9,Float64}},Array{Float64,1}})
    Base.precompile(Tuple{typeof(Plots.gr_add_legend),Plots.Subplot{Plots.GRBackend},NamedTuple{(:w, :h, :dy, :leftw, :textw, :rightw, :xoffset, :yoffset, :width_factor),Tuple{Int64,Float64,Float64,Float64,Int64,Float64,Float64,Float64,Float64}},Array{Float64,1}})
    Base.precompile(Tuple{typeof(Plots.gr_display),Plots.Subplot{Plots.GRBackend},Measures.Length{:mm,Float64},Measures.Length{:mm,Float64},Array{Float64,1}})
    Base.precompile(Tuple{typeof(Plots.gr_draw_colorbar),Plots.GRColorbar,Plots.Subplot{Plots.GRBackend},Tuple{Float64,Float64},Array{Float64,1}})
    Base.precompile(Tuple{typeof(Plots.gr_draw_contour),Plots.Series,StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Array{Float64,2},Tuple{Float64,Float64}})
    Base.precompile(Tuple{typeof(Plots.gr_draw_grid),Plots.Subplot{Plots.GRBackend},Plots.Axis,Segments{Tuple{Float64,Float64}}})
    Base.precompile(Tuple{typeof(Plots.gr_draw_heatmap),Plots.Series,Array{Float64,1},Array{Float64,1},Array{Float64,2},Tuple{Float64,Float64}})
    Base.precompile(Tuple{typeof(Plots.gr_draw_heatmap),Plots.Series,Base.OneTo{Int64},Base.OneTo{Int64},Array{Float64,2},Tuple{Float64,Float64}})
    Base.precompile(Tuple{typeof(Plots.gr_draw_marker),Plots.Series,Int64,Float64,Tuple{Float64,Float64},Int64,Int64,Int64,Symbol})
    Base.precompile(Tuple{typeof(Plots.gr_draw_markers),Plots.Series,Array{Int64,1},Array{Float64,1},Tuple{Float64,Float64}})
    Base.precompile(Tuple{typeof(Plots.gr_draw_markers),Plots.Series,Base.OneTo{Int64},Array{Float64,1},Tuple{Float64,Float64}})
    Base.precompile(Tuple{typeof(Plots.gr_draw_markers),Plots.Series,StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Array{Float64,1},Tuple{Float64,Float64}})
    Base.precompile(Tuple{typeof(Plots.gr_draw_segments),Plots.Series,Array{Float64,1},Array{Float64,1},Int64,Tuple{Float64,Float64}})
    Base.precompile(Tuple{typeof(Plots.gr_draw_segments),Plots.Series,Array{Float64,1},Array{Float64,1},Nothing,Tuple{Float64,Float64}})
    Base.precompile(Tuple{typeof(Plots.gr_draw_segments),Plots.Series,Base.OneTo{Int64},Array{Float64,1},Nothing,Tuple{Float64,Float64}})
    Base.precompile(Tuple{typeof(Plots.gr_draw_segments),Plots.Series,StepRange{Int64,Int64},Array{Float64,1},Int64,Tuple{Float64,Float64}})
    Base.precompile(Tuple{typeof(Plots.gr_get_ticks_size),Tuple{Array{Float64,1},Array{Any,1}},Int64})
    Base.precompile(Tuple{typeof(Plots.gr_get_ticks_size),Tuple{Array{Float64,1},Array{String,1}},Int64})
    Base.precompile(Tuple{typeof(Plots.gr_get_ticks_size),Tuple{Array{Int64,1},Array{String,1}},Int64})
    Base.precompile(Tuple{typeof(Plots.gr_label_ticks),Plots.Subplot{Plots.GRBackend},Symbol,Tuple{Array{Float64,1},Array{String,1}}})
    Base.precompile(Tuple{typeof(Plots.gr_label_ticks_3d),Plots.Subplot{Plots.GRBackend},Symbol,Tuple{Array{Float64,1},Array{String,1}}})
    Base.precompile(Tuple{typeof(Plots.gr_polaraxes),Int64,Float64,Plots.Subplot{Plots.GRBackend}})
    Base.precompile(Tuple{typeof(Plots.gr_set_gradient),PlotUtils.ContinuousColorGradient})
    Base.precompile(Tuple{typeof(Plots.heatmap_edges),Array{Float64,1},Symbol})
    Base.precompile(Tuple{typeof(Plots.heatmap_edges),Base.OneTo{Int64},Symbol})
    Base.precompile(Tuple{typeof(Plots.heatmap_edges),StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Symbol})
    Base.precompile(Tuple{typeof(Plots.heatmap_edges),UnitRange{Int64},Symbol})
    Base.precompile(Tuple{typeof(Plots.ignorenan_minimum),Array{Int64,1}})
    Base.precompile(Tuple{typeof(Plots.layout_args),Int64})
    Base.precompile(Tuple{typeof(Plots.make_fillrange_side),UnitRange{Int64},LinRange{Float64}})
    Base.precompile(Tuple{typeof(Plots.optimal_ticks_and_labels),Plots.Subplot{Plots.GRBackend},Plots.Axis,StepRange{Int64,Int64}})
    Base.precompile(Tuple{typeof(Plots.optimal_ticks_and_labels),Plots.Subplot{Plots.GRBackend},Plots.Axis,UnitRange{Int64}})
    Base.precompile(Tuple{typeof(Plots.processGridArg!),Dict{Symbol,Any},Symbol,Symbol})
    Base.precompile(Tuple{typeof(Plots.processGridArg!),RecipesPipeline.DefaultsDict,Bool,Symbol})
    Base.precompile(Tuple{typeof(Plots.processLineArg),Dict{Symbol,Any},Array{Symbol,2}})
    Base.precompile(Tuple{typeof(Plots.processLineArg),Dict{Symbol,Any},Symbol})
    Base.precompile(Tuple{typeof(Plots.processMarkerArg),Dict{Symbol,Any},Array{Symbol,2}})
    Base.precompile(Tuple{typeof(Plots.processMarkerArg),Dict{Symbol,Any},Plots.Stroke})
    Base.precompile(Tuple{typeof(Plots.processMarkerArg),Dict{Symbol,Any},RGBA{Float64}})
    Base.precompile(Tuple{typeof(Plots.processMarkerArg),Dict{Symbol,Any},Shape})
    Base.precompile(Tuple{typeof(Plots.processMarkerArg),Dict{Symbol,Any},Symbol})
    Base.precompile(Tuple{typeof(Plots.process_annotation),Plots.Subplot{Plots.GRBackend},Int64,Float64,Plots.PlotText})
    Base.precompile(Tuple{typeof(Plots.process_annotation),Plots.Subplot{Plots.PlotlyBackend},Int64,Float64,Plots.PlotText})
    Base.precompile(Tuple{typeof(Plots.process_axis_arg!),Dict{Symbol,Any},StepRange{Int64,Int64},Symbol})
    Base.precompile(Tuple{typeof(Plots.process_axis_arg!),Dict{Symbol,Any},Symbol,Symbol})
    Base.precompile(Tuple{typeof(Plots.process_axis_arg!),Dict{Symbol,Any},Tuple{Int64,Int64},Symbol})
    Base.precompile(Tuple{typeof(Plots.quiver_using_arrows),RecipesPipeline.DefaultsDict})
    Base.precompile(Tuple{typeof(Plots.quiver_using_hack),RecipesPipeline.DefaultsDict})
    Base.precompile(Tuple{typeof(Plots.reset_axis_defaults_byletter!)})
    Base.precompile(Tuple{typeof(Plots.slice_arg),Array{Measures.Length{:mm,Float64},2},Int64})
    Base.precompile(Tuple{typeof(Plots.slice_arg),Array{PlotUtils.ContinuousColorGradient,2},Int64})
    Base.precompile(Tuple{typeof(Plots.slice_arg),Array{RGBA{Float64},2},Int64})
    Base.precompile(Tuple{typeof(Plots.slice_arg),Array{String,2},Int64})
    Base.precompile(Tuple{typeof(Plots.slice_arg),Array{Symbol,2},Int64})
    Base.precompile(Tuple{typeof(Plots.slice_arg),Base.ReshapedArray{Int64,2,UnitRange{Int64},Tuple{}},Int64})
    Base.precompile(Tuple{typeof(Plots.straightline_data),Tuple{Float64,Float64},Tuple{Float64,Float64},Array{Float64,1},Array{Float64,1},Int64})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol,Any},AbstractArray{OHLC,1}})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol,Any},Array{Complex{Float64},1}})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol,Any},Plots.PortfolioComposition})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol,Any},Type{Val{:barhist}},Any,Any,Any})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol,Any},Type{Val{:bar}},Any,Any,Any})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol,Any},Type{Val{:histogram2d}},Any,Any,Any})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol,Any},Type{Val{:hline}},Any,Any,Any})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol,Any},Type{Val{:pie}},Any,Any,Any})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol,Any},Type{Val{:quiver}},Any,Any,Any})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol,Any},Type{Val{:spy}},Any,Any,Any})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol,Any},Type{Val{:sticks}},Any,Any,Any})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol,Any},Type{Val{:xerror}},Any,Any,Any})
    Base.precompile(Tuple{typeof(RecipesPipeline._finish_userrecipe!),Plots.Plot{Plots.GRBackend},Array{Dict{Symbol,Any},1},RecipeData})
    Base.precompile(Tuple{typeof(RecipesPipeline._finish_userrecipe!),Plots.Plot{Plots.PlotlyBackend},Array{Dict{Symbol,Any},1},RecipeData})
    Base.precompile(Tuple{typeof(RecipesPipeline.add_series!),Plots.Plot{Plots.GRBackend},RecipesPipeline.DefaultsDict})
    Base.precompile(Tuple{typeof(RecipesPipeline.add_series!),Plots.Plot{Plots.PlotlyBackend},RecipesPipeline.DefaultsDict})
    Base.precompile(Tuple{typeof(RecipesPipeline.plot_setup!),Plots.Plot{Plots.GRBackend},Dict{Symbol,Any},Array{Dict{Symbol,Any},1}})
    Base.precompile(Tuple{typeof(RecipesPipeline.plot_setup!),Plots.Plot{Plots.PlotlyBackend},Dict{Symbol,Any},Array{Dict{Symbol,Any},1}})
    Base.precompile(Tuple{typeof(RecipesPipeline.preprocess_attributes!),Plots.Plot{Plots.GRBackend},RecipesPipeline.DefaultsDict})
    Base.precompile(Tuple{typeof(RecipesPipeline.process_userrecipe!),Plots.Plot{Plots.GRBackend},Array{Dict{Symbol,Any},1},Dict{Symbol,Any}})
    Base.precompile(Tuple{typeof(RecipesPipeline.process_userrecipe!),Plots.Plot{Plots.PlotlyBackend},Array{Dict{Symbol,Any},1},Dict{Symbol,Any}})
    Base.precompile(Tuple{typeof(RecipesPipeline.unzip),Array{GeometryBasics.Point{2,Float64},1}})
    Base.precompile(Tuple{typeof(RecipesPipeline.warn_on_recipe_aliases!),Plots.Plot{Plots.GRBackend},Array{RecipeData,1},Symbol,String})
    Base.precompile(Tuple{typeof(RecipesPipeline.warn_on_recipe_aliases!),Plots.Plot{Plots.GRBackend},Dict{Symbol,Any},Symbol,String})
    Base.precompile(Tuple{typeof(RecipesPipeline.warn_on_recipe_aliases!),Plots.Plot{Plots.GRBackend},RecipesPipeline.DefaultsDict,Symbol,String})
    Base.precompile(Tuple{typeof(RecipesPipeline.warn_on_recipe_aliases!),Plots.Plot{Plots.PlotlyBackend},Array{RecipeData,1},Symbol,String})
    Base.precompile(Tuple{typeof(RecipesPipeline.warn_on_recipe_aliases!),Plots.Plot{Plots.PlotlyBackend},Dict{Symbol,Any},Symbol,String})
    Base.precompile(Tuple{typeof(RecipesPipeline.warn_on_recipe_aliases!),Plots.Plot{Plots.PlotlyBackend},RecipesPipeline.DefaultsDict,Symbol,String})
    Base.precompile(Tuple{typeof(backend),Plots.PlotlyBackend})
    Base.precompile(Tuple{typeof(bbox),Float64,Float64,Float64,Float64})
    Base.precompile(Tuple{typeof(bbox),Measures.Length{:mm,Float64},Measures.Length{:mm,Float64},Measures.Length{:mm,Float64},Measures.Length{:mm,Float64}})
    Base.precompile(Tuple{typeof(contour),Any,Vararg{Any,N} where N})
    Base.precompile(Tuple{typeof(copy),Base.Broadcast.Broadcasted{Base.Broadcast.DefaultArrayStyle{2},Tuple{Base.OneTo{Int64},Base.OneTo{Int64}},typeof(Plots.gr_color),Tuple{Array{RGBA{Float64},2}}}})
    Base.precompile(Tuple{typeof(copy),Base.Broadcast.Broadcasted{Base.Broadcast.Style{Tuple},Nothing,typeof(string),Tuple{Base.Broadcast.Broadcasted{Base.Broadcast.Style{Tuple},Nothing,typeof(typeof),Tuple{Tuple{Plots.PortfolioComposition}}}}}})
    Base.precompile(Tuple{typeof(copy),Base.Broadcast.Broadcasted{Base.Broadcast.Style{Tuple},Nothing,typeof(string),Tuple{Base.Broadcast.Broadcasted{Base.Broadcast.Style{Tuple},Nothing,typeof(typeof),Tuple{Tuple{Plots.Spy}}}}}})
    Base.precompile(Tuple{typeof(font),String,Vararg{Any,N} where N})
    Base.precompile(Tuple{typeof(iter_segments),Array{Float64,1},Array{Float64,1},UnitRange{Int64}})
    Base.precompile(Tuple{typeof(merge),NamedTuple{(:annotation,),Tuple{Array{Tuple{Int64,Float64,Plots.PlotText},1}}},Base.Iterators.Pairs{Union{},Union{},Tuple{},NamedTuple{(),Tuple{}}}})
    Base.precompile(Tuple{typeof(merge),NamedTuple{(:zcolor, :m, :ms, :lab),Tuple{Array{Float64,1},Tuple{Symbol,Float64,Plots.Stroke},Array{Float64,1},String}},NamedTuple{(:seriestype,),Tuple{Symbol}}})
    Base.precompile(Tuple{typeof(plot!),Any})
    Base.precompile(Tuple{typeof(plot),Any,Any})
    Base.precompile(Tuple{typeof(plot),Any})
    Base.precompile(Tuple{typeof(push!),Plots.Plot{Plots.GRBackend},Float64,Array{Float64,1}})
    Base.precompile(Tuple{typeof(push!),Segments{Tuple{Float64,Float64,Float64}},Tuple{Float64,Int64,Int64},Tuple{Float64,Float64,Int64}})
    Base.precompile(Tuple{typeof(setindex!),Dict{Plots.Subplot,Any},Dict{Symbol,Any},Plots.Subplot{Plots.PlotlyBackend}})
    Base.precompile(Tuple{typeof(setindex!),Dict{Symbol,Any},Tuple{Int64,Float64,Symbol,Plots.Stroke},Symbol})
    Base.precompile(Tuple{typeof(setindex!),Dict{Symbol,Any},Tuple{Symbol,Float64,Plots.Stroke},Symbol})
    Base.precompile(Tuple{typeof(setindex!),Plots.Plot{Plots.GRBackend},RGBA{Float64},Symbol})
    Base.precompile(Tuple{typeof(spy),Any})
    Base.precompile(Tuple{typeof(stroke),Int64,Vararg{Any,N} where N})
    Base.precompile(Tuple{typeof(text),String,Int64,Symbol,Vararg{Symbol,N} where N})
    Base.precompile(Tuple{typeof(text),String,Symbol,Int64,Vararg{Any,N} where N})
    Base.precompile(Tuple{typeof(title!),AbstractString})
    Base.precompile(Tuple{typeof(vcat),Array{Any,1},Array{Tuple{Int64,Float64,Plots.PlotText},1}})
    Base.precompile(Tuple{typeof(vcat),Array{Any,1},Tuple{Int64,Float64,Plots.PlotText}})
    Base.precompile(Tuple{typeof(vline!),Any})
    Base.precompile(Tuple{typeof(xgrid!),Plots.Plot{Plots.GRBackend},Symbol,Vararg{Any,N} where N})
    Base.precompile(Tuple{typeof(yaxis!),Any,Any})
    let fbody = try __lookup_kwbody__(which(Plots.text, (String,Int64,Vararg{Any,N} where N,))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Base.Iterators.Pairs{Union{},Union{},Tuple{},NamedTuple{(),Tuple{}}},typeof(text),String,Int64,Vararg{Any,N} where N,))
        end
    end
    let fbody = try __lookup_kwbody__(which(Plots.text, (String,Symbol,Vararg{Any,N} where N,))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Base.Iterators.Pairs{Union{},Union{},Tuple{},NamedTuple{(),Tuple{}}},typeof(text),String,Symbol,Vararg{Any,N} where N,))
        end
    end
    let fbody = try __lookup_kwbody__(which(Plots.title!, (AbstractString,))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Any,typeof(title!),AbstractString,))
        end
    end
    let fbody = try __lookup_kwbody__(which(Plots.vline!, (Any,))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Any,typeof(vline!),Any,))
        end
    end
    let fbody = try __lookup_kwbody__(which(Plots.yaxis!, (Any,Vararg{Any,N} where N,))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Any,typeof(yaxis!),Any,Vararg{Any,N} where N,))
        end
    end
    let fbody = try __lookup_kwbody__(which(RecipesBase.plot!, ())) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Any,typeof(plot!),))
        end
    end
    let fbody = try __lookup_kwbody__(which(RecipesBase.plot!, (Any,))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Any,typeof(plot!),Any,))
        end
    end
    let fbody = try __lookup_kwbody__(which(RecipesBase.plot!, (Any,Vararg{Any,N} where N,))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Any,typeof(plot!),Any,Vararg{Any,N} where N,))
        end
    end
    let fbody = try __lookup_kwbody__(which(RecipesBase.plot, (Any,))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Any,typeof(plot),Any,))
        end
    end
    let fbody = try __lookup_kwbody__(which(RecipesBase.plot, (Any,Vararg{Any,N} where N,))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Any,typeof(plot),Any,Vararg{Any,N} where N,))
        end
    end
    let fbody = try __lookup_kwbody__(which(RecipesBase.plot, (Plots.Plot,))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Any,typeof(plot),Plots.Plot,))
        end
    end
    let fbody = try __lookup_kwbody__(which(RecipesBase.plot, (Plots.Plot,Plots.Plot,))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Any,typeof(plot),Plots.Plot,Plots.Plot,))
        end
    end
    let fbody = try __lookup_kwbody__(which(RecipesBase.plot, (Plots.Plot,Plots.Plot,Vararg{Plots.Plot,N} where N,))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Any,typeof(plot),Plots.Plot,Plots.Plot,Vararg{Plots.Plot,N} where N,))
        end
    end
end
