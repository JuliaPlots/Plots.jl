#HDF5 Plots: Save/replay plots to/from HDF5
#-------------------------------------------------------------------------------

#==Usage
===============================================================================
Write to .hdf5 file using:
    p = plot(...)
   Plots.hdf5plot_write(p, "plotsave.hdf5")

Read from .hdf5 file using:
    pyplot() #Must first select backend
    pread = Plots.hdf5plot_read("plotsave.hdf5")
    display(pread)
==#


#==TODO
===============================================================================
 1. Support more features
    - SeriesAnnotations & GridLayout known to be missing.
 3. Improve error handling.
    - Will likely crash if file format is off.
 2. Save data in a folder parallel to "plot".
    - Will make it easier for users to locate data.
    - Use HDF5 reference to link data?
 3. Develop an actual versioned file format.
    - Should have some form of backward compatibility.
    - Should be reliable for archival purposes.
==#

@require Revise = "295af30f-e4ad-537b-8983-00126c2a3abe" begin
    Revise.track(Plots, joinpath(Pkg.dir("Plots"), "src", "backends", "hdf5.jl"))
end

import FixedPointNumbers: N0f8 #In core Julia

#Dispatch types:
struct HDF5PlotNative; end #Indentifies a data element that can natively be handled by HDF5
struct HDF5CTuple; end #Identifies a "complex" tuple structure

mutable struct HDF5Plot_PlotRef
	ref::Union{Plot, Nothing}
end


#==Useful constants
===============================================================================#
const _hdf5_plotroot = "plot"
const _hdf5_dataroot = "data" #TODO: Eventually move data to different root (easier to locate)?
const _hdf5plot_datatypeid = "TYPE" #Attribute identifying type
const _hdf5plot_countid = "COUNT" #Attribute for storing count

#Dict has problems using "Types" as keys.  Initialize in "_initialize_backend":
const HDF5PLOT_MAP_STR2TELEM = Dict{String, Type}()
const HDF5PLOT_MAP_TELEM2STR = Dict{Type, String}()

#Don't really like this global variable... Very hacky
const HDF5PLOT_PLOTREF = HDF5Plot_PlotRef(nothing)

#Simple sub-structures that can just be written out using _hdf5plot_gwritefields:
const HDF5PLOT_SIMPLESUBSTRUCT = Union{Font, BoundingBox,
	GridLayout, RootLayout, ColorGradient, SeriesAnnotations, PlotText
}


#==
===============================================================================#

const _hdf5_attr = merge_with_base_supported([
    :annotations,
    :background_color_legend, :background_color_inside, :background_color_outside,
    :foreground_color_grid, :foreground_color_legend, :foreground_color_title,
    :foreground_color_axis, :foreground_color_border, :foreground_color_guide, :foreground_color_text,
    :label,
    :linecolor, :linestyle, :linewidth, :linealpha,
    :markershape, :markercolor, :markersize, :markeralpha,
    :markerstrokewidth, :markerstrokecolor, :markerstrokealpha,
    :fillrange, :fillcolor, :fillalpha,
    :bins, :bar_width, :bar_edges, :bar_position,
    :title, :title_location, :titlefont,
    :window_title,
    :guide, :lims, :ticks, :scale, :flip, :rotation,
    :tickfont, :guidefont, :legendfont,
    :grid, :legend, :colorbar,
    :marker_z, :line_z, :fill_z,
    :levels,
    :ribbon, :quiver, :arrow,
    :orientation,
    :overwrite_figure,
    :polar,
    :normalize, :weights,
    :contours, :aspect_ratio,
    :match_dimensions,
    :clims,
    :inset_subplots,
    :dpi,
    :colorbar_title,
  ])
const _hdf5_seriestype = [
        :path, :steppre, :steppost, :shape, :straightline,
        :scatter, :hexbin, #:histogram2d, :histogram,
        # :bar,
        :heatmap, :pie, :image,
        :contour, :contour3d, :path3d, :scatter3d, :surface, :wireframe
    ]
const _hdf5_style = [:auto, :solid, :dash, :dot, :dashdot]
const _hdf5_marker = vcat(_allMarkers, :pixel)
const _hdf5_scale = [:identity, :ln, :log2, :log10]
is_marker_supported(::HDF5Backend, shape::Shape) = true

function add_backend_string(::HDF5Backend)
    """
    if !Plots.is_installed("HDF5")
        Pkg.add("HDF5")
    end
    """
end


#==Helper functions
===============================================================================#

_hdf5_plotelempath(subpath::String) = "$_hdf5_plotroot/$subpath"
_hdf5_datapath(subpath::String) = "$_hdf5_dataroot/$subpath"
_hdf5_map_str2telem(k::String) = HDF5PLOT_MAP_STR2TELEM[k]
_hdf5_map_str2telem(v::Vector) = HDF5PLOT_MAP_STR2TELEM[v[1]]

function _hdf5_merge!(dest::Dict, src::Dict)
    for (k, v) in src
        if isa(v, Axis)
            _hdf5_merge!(dest[k].d, v.d)
        else
            dest[k] = v
        end
    end
    return
end


#==
===============================================================================#

function _initialize_backend(::HDF5Backend)
    @eval begin
        import HDF5
        export HDF5
        if length(HDF5PLOT_MAP_TELEM2STR) < 1
            #Possible element types of high-level data types:
            telem2str = Dict{String, Type}(
                "NATIVE" => HDF5PlotNative,
                "VOID" => Nothing,
                "BOOL" => Bool,
                "SYMBOL" => Symbol,
                "TUPLE" => Tuple,
                "CTUPLE" => HDF5CTuple, #Tuple of complex structures
                "RGBA" => ARGB{N0f8},
                "EXTREMA" => Extrema,
                "LENGTH" => Length,
                "ARRAY" => Array, #Dict won't allow Array to be key in HDF5PLOT_MAP_TELEM2STR

                #Sub-structure types:
                "FONT" => Font,
                "BOUNDINGBOX" => BoundingBox,
                "GRIDLAYOUT" => GridLayout,
                "ROOTLAYOUT" => RootLayout,
                "SERIESANNOTATIONS" => SeriesAnnotations,
#                "PLOTTEXT" => PlotText,
                "COLORGRADIENT" => ColorGradient,
                "AXIS" => Axis,
                "SURFACE" => Surface,
                "SUBPLOT" => Subplot,
                "NULLABLE" => Nullable,
            )
            merge!(HDF5PLOT_MAP_STR2TELEM, telem2str)
            merge!(HDF5PLOT_MAP_TELEM2STR, Dict{Type, String}(v=>k for (k,v) in HDF5PLOT_MAP_STR2TELEM))
        end
    end
end

# ---------------------------------------------------------------------------

# Create the window/figure for this backend.
function _create_backend_figure(plt::Plot{HDF5Backend})
    #Do nothing
end

# ---------------------------------------------------------------------------

# # this is called early in the pipeline, use it to make the plot current or something
# function _prepare_plot_object(plt::Plot{HDF5Backend})
# end

# ---------------------------------------------------------------------------

# Set up the subplot within the backend object.
function _initialize_subplot(plt::Plot{HDF5Backend}, sp::Subplot{HDF5Backend})
    #Do nothing
end

# ---------------------------------------------------------------------------

# Add one series to the underlying backend object.
# Called once per series
# NOTE: Seems to be called when user calls plot()... even if backend
#       plot, sp.o has not yet been constructed...
function _series_added(plt::Plot{HDF5Backend}, series::Series)
    #Do nothing
end

# ---------------------------------------------------------------------------

# When series data is added/changed, this callback can do dynamic updates to the backend object.
# note: if the backend rebuilds the plot from scratch on display, then you might not do anything here.
function _series_updated(plt::Plot{HDF5Backend}, series::Series)
    #Do nothing
end

# ---------------------------------------------------------------------------

# called just before updating layout bounding boxes... in case you need to prep
# for the calcs
function _before_layout_calcs(plt::Plot{HDF5Backend})
    #Do nothing
end

# ----------------------------------------------------------------

# Set the (left, top, right, bottom) minimum padding around the plot area
# to fit ticks, tick labels, guides, colorbars, etc.
function _update_min_padding!(sp::Subplot{HDF5Backend})
    #Do nothing
end

# ----------------------------------------------------------------

# Override this to update plot items (title, xlabel, etc), and add annotations (d[:annotations])
function _update_plot_object(plt::Plot{HDF5Backend})
    #Do nothing
end

# ----------------------------------------------------------------

# Display/show the plot (open a GUI window, or browser page, for example).
function _display(plt::Plot{HDF5Backend})
    msg = "HDF5 interface does not support `display()` function."
    msg *= "\nUse `Plots.hdf5plot_write(::String)` method to write to .HDF5 \"plot\" file instead."
    warn(msg)
    return
end


#==HDF5 write functions
===============================================================================#

function _hdf5plot_writetype(grp, k::String, tstr::Array{String})
    d = HDF5.d_open(grp, k)
    HDF5.a_write(d, _hdf5plot_datatypeid, tstr)
end
function _hdf5plot_writetype(grp, k::String, T::Type)
    tstr = HDF5PLOT_MAP_TELEM2STR[T]
    d = HDF5.d_open(grp, k)
    HDF5.a_write(d, _hdf5plot_datatypeid, tstr)
end
function _hdf5plot_overwritetype(grp, k::String, T::Type)
    tstr = HDF5PLOT_MAP_TELEM2STR[T]
    d = HDF5.d_open(grp, k)
    HDF5.a_delete(d, _hdf5plot_datatypeid)
    HDF5.a_write(d, _hdf5plot_datatypeid, tstr)
end
function _hdf5plot_writetype(grp, T::Type) #Write directly to group
    tstr = HDF5PLOT_MAP_TELEM2STR[T]
    HDF5.a_write(grp, _hdf5plot_datatypeid, tstr)
end
function _hdf5plot_overwritetype(grp, T::Type) #Write directly to group
    tstr = HDF5PLOT_MAP_TELEM2STR[T]
    HDF5.a_delete(grp, _hdf5plot_datatypeid)
    HDF5.a_write(grp, _hdf5plot_datatypeid, tstr)
end
function _hdf5plot_writetype(grp, ::Type{Array{T}}) where T<:Any
    tstr = HDF5PLOT_MAP_TELEM2STR[Array] #ANY
    HDF5.a_write(grp, _hdf5plot_datatypeid, tstr)
end
function _hdf5plot_writetype(grp, ::Type{T}) where T<:BoundingBox
    tstr = HDF5PLOT_MAP_TELEM2STR[BoundingBox]
    HDF5.a_write(grp, _hdf5plot_datatypeid, tstr)
end
function _hdf5plot_writecount(grp, n::Int) #Write directly to group
    HDF5.a_write(grp, _hdf5plot_countid, n)
end
function _hdf5plot_gwritefields(grp, k::String, v)
    grp = HDF5.g_create(grp, k)
    for _k in fieldnames(v)
        _v = getfield(v, _k)
        kstr = string(_k)
        _hdf5plot_gwrite(grp, kstr, _v)
    end
    _hdf5plot_writetype(grp, typeof(v))
    return
end

# Write data
# ----------------------------------------------------------------

function _hdf5plot_gwrite(grp, k::String, v) #Default
    grp[k] = v
    _hdf5plot_writetype(grp, k, HDF5PlotNative)
end
function _hdf5plot_gwrite(grp, k::String, v::Array{T}) where T<:Number #Default for arrays
    grp[k] = v
    _hdf5plot_writetype(grp, k, HDF5PlotNative)
end
#=
function _hdf5plot_gwrite(grp, k::String, v::Array{Any})
#    @show grp, k
    warn("Cannot write Array: $k=$v")
end
=#
function _hdf5plot_gwrite(grp, k::String, v::Nothing)
    grp[k] = 0
    _hdf5plot_writetype(grp, k, Nothing)
end
function _hdf5plot_gwrite(grp, k::String, v::Bool)
    grp[k] = Int(v)
    _hdf5plot_writetype(grp, k, Bool)
end
function _hdf5plot_gwrite(grp, k::String, v::Symbol)
    grp[k] = string(v)
    _hdf5plot_writetype(grp, k, Symbol)
end
function _hdf5plot_gwrite(grp, k::String, v::Tuple)
    varr = [v...]
    elt = eltype(varr)
#    if isleaftype(elt)

    _hdf5plot_gwrite(grp, k, varr)
    if elt <: Number
        #We just wrote a simple dataset
        _hdf5plot_overwritetype(grp, k, Tuple)
    else #Used a more complex scheme (using subgroups):
        _hdf5plot_overwritetype(grp[k], HDF5CTuple)
    end
    #NOTE: _hdf5plot_overwritetype overwrites "Array" type with "Tuple".
end
function _hdf5plot_gwrite(grp, k::String, d::Dict)
#    warn("Cannot write dict: $k=$d")
end
function _hdf5plot_gwrite(grp, k::String, v::AbstractRange)
    _hdf5plot_gwrite(grp, k, collect(v)) #For now
end
function _hdf5plot_gwrite(grp, k::String, v::ARGB{N0f8})
    grp[k] = [v.r.i, v.g.i, v.b.i, v.alpha.i]
    _hdf5plot_writetype(grp, k, ARGB{N0f8})
end
function _hdf5plot_gwrite(grp, k::String, v::Colorant)
    _hdf5plot_gwrite(grp, k, ARGB{N0f8}(v))
end
#Custom vector (when not using simple numeric type):
function _hdf5plot_gwritearray(grp, k::String, v::Array{T}) where T
    if "annotations" == k;
        return #Hack.  Does not yet support annotations.
    end

    vgrp = HDF5.g_create(grp, k)
    _hdf5plot_writetype(vgrp, Array) #ANY
    sz = size(v)

    for iter in eachindex(v)
        coord = LinearIndices(sz, iter)
        elem = v[iter]
        idxstr = join(coord, "_")
        _hdf5plot_gwrite(vgrp, "v$idxstr", v[iter])
    end

    _hdf5plot_gwrite(vgrp, "dim", [sz...])
    return
end
_hdf5plot_gwrite(grp, k::String, v::Array) =
	_hdf5plot_gwritearray(grp, k, v)
function _hdf5plot_gwrite(grp, k::String, v::Extrema)
    grp[k] = [v.emin, v.emax]
    _hdf5plot_writetype(grp, k, Extrema)
end
function _hdf5plot_gwrite(grp, k::String, v::Length{T}) where T
    grp[k] = v.value
    _hdf5plot_writetype(grp, k, [HDF5PLOT_MAP_TELEM2STR[Length], string(T)])
end

# Write more complex structures:
# ----------------------------------------------------------------

function _hdf5plot_gwrite(grp, k::String, v::Plot)
    #Don't write plot references
end
function _hdf5plot_gwrite(grp, k::String, v::HDF5PLOT_SIMPLESUBSTRUCT)
    _hdf5plot_gwritefields(grp, k, v)
    return
end
function _hdf5plot_gwrite(grp, k::String, v::Axis)
    grp = HDF5.g_create(grp, k)
    for (_k, _v) in v.d
        kstr = string(_k)
        _hdf5plot_gwrite(grp, kstr, _v)
    end
    _hdf5plot_writetype(grp, Axis)
    return
end
function _hdf5plot_gwrite(grp, k::String, v::Surface)
	grp = HDF5.g_create(grp, k)
	_hdf5plot_gwrite(grp, "data2d", v.surf)
	_hdf5plot_writetype(grp, Surface)
end
# #TODO: "Properly" support Nullable using _hdf5plot_writetype?
# function _hdf5plot_gwrite(grp, k::String, v::Nullable)
#     if isnull(v)
#         _hdf5plot_gwrite(grp, k, nothing)
#     else
#         _hdf5plot_gwrite(grp, k, v.value)
#     end
#     return
# end

function _hdf5plot_gwrite(grp, k::String, v::SeriesAnnotations)
    #Currently no support for SeriesAnnotations
    return
end
function _hdf5plot_gwrite(grp, k::String, v::Subplot)
    grp = HDF5.g_create(grp, k)
    _hdf5plot_gwrite(grp, "index", v[:subplot_index])
    _hdf5plot_writetype(grp, Subplot)
    return
end
function _hdf5plot_write(grp, d::Dict)
    for (k, v) in d
        kstr = string(k)
        _hdf5plot_gwrite(grp, kstr, v)
    end
    return
end

# Write main plot structures:
# ----------------------------------------------------------------

function _hdf5plot_write(sp::Subplot{HDF5Backend}, subpath::String, f)
    f = f::HDF5.HDF5File #Assert
    grp = HDF5.g_create(f, _hdf5_plotelempath("$subpath/attr"))
    _hdf5plot_write(grp, sp.attr)
    grp = HDF5.g_create(f, _hdf5_plotelempath("$subpath/series_list"))
    _hdf5plot_writecount(grp, length(sp.series_list))
    for (i, series) in enumerate(sp.series_list)
        grp = HDF5.g_create(f, _hdf5_plotelempath("$subpath/series_list/series$i"))
        _hdf5plot_write(grp, series.d)
    end

    return
end

function _hdf5plot_write(plt::Plot{HDF5Backend}, f)
    f = f::HDF5.HDF5File #Assert

    grp = HDF5.g_create(f, _hdf5_plotelempath("attr"))
    _hdf5plot_write(grp, plt.attr)

    grp = HDF5.g_create(f, _hdf5_plotelempath("subplots"))
    _hdf5plot_writecount(grp, length(plt.subplots))

    for (i, sp) in enumerate(plt.subplots)
        _hdf5plot_write(sp, "subplots/subplot$i", f)
    end

    return
end
function hdf5plot_write(plt::Plot{HDF5Backend}, path::AbstractString)
    HDF5.h5open(path, "w") do file
        _hdf5plot_write(plt, file)
    end
end
hdf5plot_write(path::AbstractString) = hdf5plot_write(current(), path)


#==HDF5 playback (read) functions
===============================================================================#

function _hdf5plot_readcount(grp) #Read directly from group
    return HDF5.a_read(grp, _hdf5plot_countid)
end

_hdf5plot_convert(T::Type{HDF5PlotNative}, v) = v
_hdf5plot_convert(T::Type{Nothing}, v) = nothing
_hdf5plot_convert(T::Type{Bool}, v) = (v!=0)
_hdf5plot_convert(T::Type{Symbol}, v) = Symbol(v)
_hdf5plot_convert(T::Type{Tuple}, v) = tuple(v...) #With Vector{T<:Number}
function _hdf5plot_convert(T::Type{ARGB{N0f8}}, v)
    r, g, b, a = reinterpret(N0f8, v)
    return Colors.ARGB{N0f8}(r, g, b, a)
end
_hdf5plot_convert(T::Type{Extrema}, v) = Extrema(v[1], v[2])

# Read data structures:
# ----------------------------------------------------------------

function _hdf5plot_read(grp, k::String, T::Type, dtid)
    v = HDF5.d_read(grp, k)
    return _hdf5plot_convert(T, v)
end
function _hdf5plot_read(grp, k::String, T::Type{Length}, dtid::Vector)
    v = HDF5.d_read(grp, k)
    TU = Symbol(dtid[2])
    T = typeof(v)
    return Length{TU,T}(v)
end

# Read more complex data structures:
# ----------------------------------------------------------------
function _hdf5plot_read(grp, k::String, T::Type{Font}, dtid)
    grp = HDF5.g_open(grp, k)

    family = _hdf5plot_read(grp, "family")
    pointsize = _hdf5plot_read(grp, "pointsize")
    halign = _hdf5plot_read(grp, "halign")
    valign = _hdf5plot_read(grp, "valign")
    rotation = _hdf5plot_read(grp, "rotation")
    color = _hdf5plot_read(grp, "color")
    return Font(family, pointsize, halign, valign, rotation, color)
end
function _hdf5plot_read(grp, k::String, T::Type{Array}, dtid) #ANY
    grp = HDF5.g_open(grp, k)
    sz = _hdf5plot_read(grp, "dim")
    if [0] == sz; return []; end
    sz = tuple(sz...)
    result = Array{Any}(sz)

    for iter in eachindex(result)
        coord = LinearIndices(sz, iter)
        idxstr = join(coord, "_")
        result[iter] = _hdf5plot_read(grp, "v$idxstr")
    end

    #Hack: Implicitly make Julia detect element type.
    #      (Should probably write it explicitly to file)
    result = [result[iter] for iter in eachindex(result)] #Potentially make more specific
    return reshape(result, sz)
end
function _hdf5plot_read(grp, k::String, T::Type{HDF5CTuple}, dtid)
    v = _hdf5plot_read(grp, k, Array, dtid)
    return tuple(v...)
end
function _hdf5plot_read(grp, k::String, T::Type{ColorGradient}, dtid)
    grp = HDF5.g_open(grp, k)

    colors = _hdf5plot_read(grp, "colors")
    values = _hdf5plot_read(grp, "values")
    return ColorGradient(colors, values)
end
function _hdf5plot_read(grp, k::String, T::Type{BoundingBox}, dtid)
    grp = HDF5.g_open(grp, k)

    x0 = _hdf5plot_read(grp, "x0")
    a = _hdf5plot_read(grp, "a")
    return BoundingBox(x0, a)
end
_hdf5plot_read(grp, k::String, T::Type{RootLayout}, dtid) = RootLayout()
function _hdf5plot_read(grp, k::String, T::Type{GridLayout}, dtid)
    grp = HDF5.g_open(grp, k)

#    parent = _hdf5plot_read(grp, "parent")
parent = RootLayout()
    minpad = _hdf5plot_read(grp, "minpad")
    bbox = _hdf5plot_read(grp, "bbox")
    grid = _hdf5plot_read(grp, "grid")
    widths = _hdf5plot_read(grp, "widths")
    heights = _hdf5plot_read(grp, "heights")
    attr = KW() #TODO support attr: _hdf5plot_read(grp, "attr")

    return GridLayout(parent, minpad, bbox, grid, widths, heights, attr)
end
function _hdf5plot_read(grp, k::String, T::Type{Axis}, dtid)
    grp = HDF5.g_open(grp, k)
    kwlist = KW()
    _hdf5plot_read(grp, kwlist)
    return Axis([], kwlist)
end
function _hdf5plot_read(grp, k::String, T::Type{Surface}, dtid)
    grp = HDF5.g_open(grp, k)
    data2d = _hdf5plot_read(grp, "data2d")
    return Surface(data2d)
end
function _hdf5plot_read(grp, k::String, T::Type{Subplot}, dtid)
    grp = HDF5.g_open(grp, k)
    idx = _hdf5plot_read(grp, "index")
    return HDF5PLOT_PLOTREF.ref.subplots[idx]
end
function _hdf5plot_read(grp, k::String)
    dtid = HDF5.a_read(grp[k], _hdf5plot_datatypeid)
    T = _hdf5_map_str2telem(dtid) #expect exception
    return _hdf5plot_read(grp, k, T, dtid)
end

#Read in values in group to populate d:
function _hdf5plot_read(grp, d::Dict)
    gnames = names(grp)
    for k in gnames
        try
            v = _hdf5plot_read(grp, k)
            d[Symbol(k)] = v
        catch e
            @show e
            @show grp
            warn("Could not read field $k")
        end
    end
    return
end

# Read main plot structures:
# ----------------------------------------------------------------

function _hdf5plot_read(sp::Subplot, subpath::String, f)
    f = f::HDF5.HDF5File #Assert

    grp = HDF5.g_open(f, _hdf5_plotelempath("$subpath/attr"))
    kwlist = KW()
    _hdf5plot_read(grp, kwlist)
    _hdf5_merge!(sp.attr, kwlist)

    grp = HDF5.g_open(f, _hdf5_plotelempath("$subpath/series_list"))
    nseries = _hdf5plot_readcount(grp)

    for i in 1:nseries
        grp = HDF5.g_open(f, _hdf5_plotelempath("$subpath/series_list/series$i"))
        kwlist = KW()
        _hdf5plot_read(grp, kwlist)
        plot!(sp, kwlist[:x], kwlist[:y]) #Add data & create data structures
        _hdf5_merge!(sp.series_list[end].d, kwlist)
    end

    return
end

function _hdf5plot_read(plt::Plot, f)
    f = f::HDF5.HDF5File #Assert
    #Assumpltion: subplots are already allocated (plt.subplots)

    HDF5PLOT_PLOTREF.ref = plt #Used when reading "layout"
    grp = HDF5.g_open(f, _hdf5_plotelempath("attr"))
    _hdf5plot_read(grp, plt.attr)

    for (i, sp) in enumerate(plt.subplots)
        _hdf5plot_read(sp, "subplots/subplot$i", f)
    end

    return
end

function hdf5plot_read(path::AbstractString)
    plt = nothing
    HDF5.h5open(path, "r") do file
        grp = HDF5.g_open(file, _hdf5_plotelempath("subplots"))
        n = _hdf5plot_readcount(grp)
        plt = plot(layout=n) #Get reference to a new plot
        _hdf5plot_read(plt, file)
    end
    return plt
end

#Last line
