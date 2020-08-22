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
 1. Support more features.
    - GridLayout known not to be working.
 2. Improve error handling.
    - Will likely crash if file format is off.
 3. Save data in a folder parallel to "plot".
    - Will make it easier for users to locate data.
    - Use HDF5 reference to link data?
 4. Develop an actual versioned file format.
    - Should have some form of backward compatibility.
    - Should be reliable for archival purposes.
 5. Fix construction of plot object with hdf5plot_read.
    - Layout doesn't seem to get transferred well (ex: `Plots._examples[40]`).
    - Not building object correctly when backends do not natively support
      a certain feature (ex: :steppre)
    - No support for CategoricalArrays.* structures. But they appear to be
      brought into `Plots._examples[25,30]` through DataFrames.jl - so we can't
      really reference them in this code.
==#
"""
    _hdf5_implementation

Create module (namespace) for implementing HDF5 "plots".
(Avoid name collisions, while keeping names short)
"""
module _hdf5_implementation #Tools required to implements HDF5 "plots"

import Dates

#Plots.jl imports HDF5 to main:
import ..HDF5
import ..HDF5: HDF5Group, HDF5Dataset

import ..Colors, ..Colorant
import ..PlotUtils.ColorSchemes.ColorScheme

import ..HDF5Backend
import ..HDF5PLOT_MAP_STR2TELEM, ..HDF5PLOT_MAP_TELEM2STR
import ..HDF5Plot_PlotRef, ..HDF5PLOT_PLOTREF
import ..BoundingBox, ..Extrema, ..Length
import ..RecipesPipeline.datetimeformatter
import ..PlotUtils.ColorPalette, ..PlotUtils.CategoricalColorGradient, ..PlotUtils.ContinuousColorGradient
import ..Surface, ..Shape, ..Arrow
import ..GridLayout, ..RootLayout
import ..Font, ..PlotText, ..SeriesAnnotations
import ..Axis, ..Subplot, ..Plot
import ..AKW, ..KW, ..DefaultsDict
import .._axis_defaults
import ..plot, ..plot!

#Types that already have built-in HDF5 support (just write out natively):
const HDF5_SupportedTypes = Union{Number, String}
#TODO: Types_HDF5Support

#Dispatch types:
struct CplxTuple; end #Identifies a "complex" tuple structure (not merely numbers)
#HDF5 reader will auto-detect type correctly:
struct HDF5_AutoDetect; end #See HDF5_SupportedTypes


#==
===============================================================================#

if length(HDF5PLOT_MAP_TELEM2STR) < 1
    #Possible element types of high-level data types:
    #(Used to add type information as an HDF5 string attribute)
    #(Also used to dispatch appropriate read function through _read_typed())
    _telem2str = Dict{String, Type}(
        "NOTHING" => Nothing,
        "SYMBOL" => Symbol,
        "RGBA" => Colorant, #Write out any Colorant to an #RRGGBBAA string
        "TUPLE" => Tuple,
        "CTUPLE" => CplxTuple, #Tuple of complex structures

        "EXTREMA" => Extrema,
        "LENGTH" => Length,
        "ARRAY" => Array, #Array{Any} (because Array{T<:Union{Number, String}} natively supported by HDF5)

        #Sub-structure types:
        "T_DATETIMEFORMATTER" => typeof(datetimeformatter),

        #Sub-structure types:
        "DEFAULTSDICT" => DefaultsDict,
        "FONT" => Font,
        "BOUNDINGBOX" => BoundingBox,
        "GRIDLAYOUT" => GridLayout,
        "ROOTLAYOUT" => RootLayout,
        "SERIESANNOTATIONS" => SeriesAnnotations,
        "PLOTTEXT" => PlotText,
        "SHAPE" => Shape,
        "ARROW" => Arrow,
        "COLORSCHEME" => ColorScheme,
        "COLORPALETTE" => ColorPalette,
        "CONT_COLORGRADIENT" => ContinuousColorGradient,
        "CAT_COLORGRADIENT" => CategoricalColorGradient,
        "AXIS" => Axis,
        "SURFACE" => Surface,
        "SUBPLOT" => Subplot,
    )
    merge!(HDF5PLOT_MAP_STR2TELEM, _telem2str) #Faster to create than push!()??
    merge!(HDF5PLOT_MAP_TELEM2STR, Dict{Type, String}(v=>k for (k,v) in HDF5PLOT_MAP_STR2TELEM))
end


#==Helper functions
===============================================================================#

h5plotpath(plotname::String) = "plots/$plotname"

#Version info
#NOTE: could cache output, but we seem to not want const declarations in backend files.
function _get_Plots_versionstr()
    #Adds to load up time... Maybe a more efficient way??
    try
        deps = Pkg.dependencies()
        uuid = Base.UUID("91a5bcdd-55d7-5caf-9e0b-520d859cae80") #Plots.jl
        vinfo = deps[uuid].version
        return "Source: Plots.jl v$vinfo"
    catch
        now = string(Dates.now()) #Use time in case it can help recover plot
        return "Source: Plots.jl v? - $now"
    end
end

function _hdf5_merge!(dest::AKW, src::AKW)
    for (k, v) in src
        if isa(v, Axis)
            _hdf5_merge!(dest[k].plotattributes, v.plotattributes)
        else
            dest[k] = v
        end
    end
    return
end

#_type_for_map returns the type to use with HDF5PLOT_MAP_TELEM2STR[], in case it is not concrete:
_type_for_map(::Type{T}) where T = T #Catch-all
_type_for_map(::Type{T}) where T<:BoundingBox = BoundingBox
_type_for_map(::Type{T}) where T<:ColorScheme = ColorScheme
_type_for_map(::Type{T}) where T<:Surface = Surface


#==Read/write things like type name in attributes
===============================================================================#
function _write_datatype_attr(ds::Union{HDF5Group, HDF5Dataset}, ::Type{T}) where T
    typestr = HDF5PLOT_MAP_TELEM2STR[T]
    HDF5.attrs(ds)["TYPE"] = typestr
end
function _read_datatype_attr(ds::Union{HDF5Group, HDF5Dataset})
    if !HDF5.exists(HDF5.attrs(ds), "TYPE")
        return HDF5_AutoDetect
    end

    typestr = HDF5.read(HDF5.attrs(ds)["TYPE"])
    return HDF5PLOT_MAP_STR2TELEM[typestr]
end

#Type parameter attributes:
function _write_typeparam_attr(ds::HDF5Dataset, v::Length{T}) where T
    HDF5.attrs(ds)["TYPEPARAM"] = string(T) #Need to add units for Length
end
_read_typeparam_attr(ds::HDF5Dataset) = HDF5.read(HDF5.attrs(ds)["TYPEPARAM"])

function _write_length_attr(grp::HDF5Group, v::Vector) #of a vector
    HDF5.attrs(grp)["LENGTH"] = length(v)
end
_read_length_attr(::Type{Vector}, grp::HDF5Group) = HDF5.read(HDF5.attrs(grp)["LENGTH"])

function _write_size_attr(grp::HDF5Group, v::Array) #of an array
    HDF5.attrs(grp)["SIZE"] = [size(v)...]
end
_read_size_attr(::Type{Array}, grp::HDF5Group) = tuple(HDF5.read(HDF5.attrs(grp)["SIZE"])...)


#==_write_typed(): Simple (leaf) datatypes. (Labels with type name.)
===============================================================================#
#= No: write out struct instead!
function _write_typed(grp::HDF5Group, name::String, v::T) where T
    tstr = string(T)
    path = HDF5.name(grp) * "/" * name
    @info("Type not supported: $tstr\npath: $path")
    return
end
=#
#Default behaviour: Assumes value is supported by HDF5 format
function _write_typed(grp::HDF5Group, name::String, v::HDF5_SupportedTypes)
    grp[name] = v
    return #No need to _write_datatype_attr
end
function _write_typed(grp::HDF5Group, name::String, v::Nothing)
    grp[name] = "nothing" #Redundancy check/easier to read HDF5 file
    _write_datatype_attr(grp[name], Nothing)
end
function _write_typed(grp::HDF5Group, name::String, v::Symbol)
    grp[name] = String(v)
    _write_datatype_attr(grp[name], Symbol)
end
function _write_typed(grp::HDF5Group, name::String, v::Colorant)
    vstr = "#" * Colors.hex(v, :RRGGBBAA)
    grp[name] = vstr
    _write_datatype_attr(grp[name], Colorant)
end
function _write_typed(grp::HDF5Group, name::String, v::Extrema)
    grp[name] = [v.emin, v.emax] #More compact than writing struct
    _write_datatype_attr(grp[name], Extrema)
end
function _write_typed(grp::HDF5Group, name::String, v::Length)
    grp[name] = v.value
    _write_datatype_attr(grp[name], Length)
    _write_typeparam_attr(grp[name], v)
end
function _write_typed(grp::HDF5Group, name::String, v::typeof(datetimeformatter))
    grp[name] = string(v) #Just write something that helps reader
   _write_datatype_attr(grp[name], typeof(datetimeformatter))
end
function _write_typed(grp::HDF5Group, name::String, v::Array{T}) where T<:Number #Default for arrays
    grp[name] = v
    return #No need to _write_datatype_attr
end
function _write_typed(grp::HDF5Group, name::String, v::AbstractRange)
    _write_typed(grp, name, collect(v)) #For now
end



#== Helper functions for writing complex data structures
===============================================================================#

#Write an array using HDF5 hierarchy (when not using simple numeric eltype):
function _write_harray(grp::HDF5Group, name::String, v::Array)
    sgrp = HDF5.g_create(grp, name)
    sz = size(v)
    lidx = LinearIndices(sz)

    for iter in eachindex(v)
        coord = lidx[iter]
        elem = v[iter]
        idxstr = join(coord, "_")
        _write_typed(sgrp, "v$idxstr", elem)
    end

    _write_size_attr(sgrp, v)
end

#Write Dict without tagging with type:
function _write(grp::HDF5Group, name::String, d::AbstractDict)
    sgrp = HDF5.g_create(grp, name)
    for (k, v) in d
        kstr = string(k)
        _write_typed(sgrp, kstr, v)
    end
    return
end

#Write out arbitrary `struct`s:
function _writestructgeneric(grp::HDF5Group, obj::T) where T
    for fname in fieldnames(T)
       v = getfield(obj, fname)
       _write_typed(grp, String(fname), v)
    end
    return
end


#==_write_typed(): More complex structures. (Labels with type name.)
===============================================================================#

#Catch-all (default behaviour for `struct`s):
function _write_typed(grp::HDF5Group, name::String, v::T) where T
    #NOTE: need "name" parameter so that call signature is same with built-ins
    MT = _type_for_map(T)
    try #Check to see if type is supported
        typestr = HDF5PLOT_MAP_TELEM2STR[MT]
    catch
        @warn("HDF5Plots does not yet support structs of type `$MT`\n\n$grp")
        return
    end

    #If attribute is supported and no writer is defined, then this should work:
    objgrp = HDF5.g_create(grp, name)
    _write_datatype_attr(objgrp, MT)
    _writestructgeneric(objgrp, v)
end

function _write_typed(grp::HDF5Group, name::String, v::Array{T}) where T
    _write_harray(grp, name, v)
    _write_datatype_attr(grp[name], Array) #{Any}
end

function _write_typed(grp::HDF5Group, name::String, v::Tuple, ::Type{ELT}) where ELT<: Number #Basic Tuple
    _write_typed(grp, name, [v...])
    _write_datatype_attr(grp[name], Tuple)
end
function _write_typed(grp::HDF5Group, name::String, v::Tuple, ::Type) #CplxTuple
    _write_harray(grp, name, [v...])
    _write_datatype_attr(grp[name], CplxTuple)
end
_write_typed(grp::HDF5Group, name::String, v::Tuple) = _write_typed(grp, name, v, eltype(v))

function _write_typed(grp::HDF5Group, name::String, v::Dict)
#=
    tstr = string(Dict)
    path = HDF5.name(grp) * "/" * name
    @info("Type not supported: $tstr\npath: $path")
    return
=#
    #No support for structures with Dicts yet
end
function _write_typed(grp::HDF5Group, name::String, d::DefaultsDict) #Typically for plot attributes
    _write(grp, name, d)
    _write_datatype_attr(grp[name], DefaultsDict)
end

function _write_typed(grp::HDF5Group, name::String, v::Axis)
    sgrp = HDF5.g_create(grp, name)
    #Ignore: sps::Vector{Subplot}
    _write_typed(sgrp, "plotattributes", v.plotattributes)
    _write_datatype_attr(sgrp, Axis)
end

function _write_typed(grp::HDF5Group, name::String, v::Subplot)
    #Not for use in main "Plot.subplots[]" hierarchy.  Just establishes reference with subplot_index.
    sgrp = HDF5.g_create(grp, name)
    _write_typed(sgrp, "index", v[:subplot_index])
    _write_datatype_attr(sgrp, Subplot)
    return
end

function _write_typed(grp::HDF5Group, name::String, v::Plot)
    #Don't write plot references
end


#==_write(): Write out more complex structures
NOTE: No need to write out type information (inferred from hierarchy)
===============================================================================#

function _write(grp::HDF5Group, sp::Subplot{HDF5Backend})
    _write_typed(grp, "attr", sp.attr)

    listgrp = HDF5.g_create(grp, "series_list")
    _write_length_attr(listgrp, sp.series_list)
    for (i, series) in enumerate(sp.series_list)
        #Just write .plotattributes part:
        _write(listgrp, "$i", series.plotattributes)
    end

    return
end

function _write(grp::HDF5Group, plt::Plot{HDF5Backend})
    _write_typed(grp, "attr", plt.attr)

    listgrp = HDF5.g_create(grp, "subplots")
    _write_length_attr(listgrp, plt.subplots)
    for (i, sp) in enumerate(plt.subplots)
        sgrp = HDF5.g_create(listgrp, "$i")
        _write(sgrp, sp)
    end

    return
end

function hdf5plot_write(plt::Plot{HDF5Backend}, path::AbstractString; name::String="_unnamed")
    HDF5.h5open(path, "w") do file
        HDF5.d_write(file, "VERSION_INFO", _get_Plots_versionstr())
        grp = HDF5.g_create(file, h5plotpath(name))
        _write(grp, plt)
    end
end


#== _read(): Read data, but not type information.
===============================================================================#

#Types with built-in HDF5 support:
_read(::Type{HDF5_AutoDetect}, ds::HDF5Dataset) = HDF5.read(ds)

function _read(::Type{Nothing}, ds::HDF5Dataset)
    nstr = "nothing"
    v = HDF5.read(ds)
    if nstr != v
        path = HDF5.name(ds)
        throw(Meta.ParseError("_read(::Nothing, ::HDF5Group): Read $v != $nstr:\n$path"))
    end
    return nothing
end
_read(::Type{Symbol}, ds::HDF5Dataset) = Symbol(HDF5.read(ds))
_read(::Type{Colorant}, ds::HDF5Dataset) = parse(Colorant, HDF5.read(ds))
_read(::Type{Tuple}, ds::HDF5Dataset) = tuple(HDF5.read(ds)...)
function _read(::Type{Extrema}, ds::HDF5Dataset)
    v = HDF5.read(ds)
    return Extrema(v[1], v[2])
end
function _read(::Type{Length}, ds::HDF5Dataset)
    TUNIT = Symbol(_read_typeparam_attr(ds))
    v = HDF5.read(ds)
    T = typeof(v)
    return Length{TUNIT,T}(v)
end
_read(::Type{typeof(datetimeformatter)}, ds::HDF5Dataset) = datetimeformatter


#== Helper functions for reading in complex data structures
===============================================================================#

#When type is unknown, _read_typed() figures it out:
function _read_typed(grp::HDF5Group, name::String)
    ds = grp[name]
    t = _read_datatype_attr(ds)
    return _read(t, ds)
end

#_readstructgeneric: Needs object values to be written out with _write_typed():
function _readstructgeneric(::Type{T}, grp::HDF5Group) where T
    vlist = Array{Any}(nothing, fieldcount(T))
    for (i, fname) in enumerate(fieldnames(T))
        vlist[i] = _read_typed(grp, String(fname))
    end
    return T(vlist...)
end

#Read KW from group:
function _read(::Type{KW}, grp::HDF5Group)
    d = KW()
    gnames = names(grp)
    for k in gnames
        try
            v = _read_typed(grp, k)
            d[Symbol(k)] = v
        catch e
            @show e
            @show grp
            @warn("Could not read field $k")
        end
    end
    return d
end


#== _read(): More complex structures.
===============================================================================#

#Catch-all (default behaviour for `struct`s):
_read(T::Type, grp::HDF5Group) = _readstructgeneric(T, grp)

function _read(::Type{Array}, grp::HDF5Group) #Array{Any}
    sz = _read_size_attr(Array, grp)
    if tuple(0) == sz; return []; end
    result = Array{Any}(undef, sz)
    lidx = LinearIndices(sz)

    for iter in eachindex(result)
        coord = lidx[iter]
        idxstr = join(coord, "_")
        result[iter] = _read_typed(grp, "v$idxstr")
    end

    #Hack: Implicitly make Julia detect element type.
    #      (Should probably write it explicitly to file)
    result = [elem for elem in result] #Potentially make more specific
    return reshape(result, sz)
end

_read(::Type{CplxTuple}, grp::HDF5Group) = tuple(_read(Array, grp)...)

function _read(::Type{GridLayout}, grp::HDF5Group)
    #parent = _read_typed(grp, "parent") #Can't use generic reader
    parent = RootLayout() #TODO: support parent???
    minpad = _read_typed(grp, "minpad")
    bbox = _read_typed(grp, "bbox")
    grid = _read_typed(grp, "grid")
    widths = _read_typed(grp, "widths")
    heights = _read_typed(grp, "heights")
    attr = KW() #TODO support attr: _read_typed(grp, "attr")

    return GridLayout(parent, minpad, bbox, grid, widths, heights, attr)
end
#Defaults depends on context. So: user must constructs with defaults, then read.
function _read(::Type{DefaultsDict}, grp::HDF5Group)
    #User should set DefaultsDict.defaults to one of:
    #   _plot_defaults, _subplot_defaults, _axis_defaults, _series_defaults
    path = HDF5.name(ds)
    @warn("Cannot yet read DefaultsDict using _read_typed():\n    $path\nCannot fully reconstruct plot.")
end
function _read(::Type{Axis}, grp::HDF5Group)
    #1st arg appears to be ref to subplots. Seems to work without it.
    return Axis([], DefaultsDict(_read(KW, grp["plotattributes"]), _axis_defaults))
end
function _read(::Type{Subplot}, grp::HDF5Group)
    #Not for use in main "Plot.subplots[]" hierarchy.  Just establishes reference with subplot_index.
    idx = _read_typed(grp, "index")
    return HDF5PLOT_PLOTREF.ref.subplots[idx]
end


#== _read(): Main plot structures
===============================================================================#

function _read(grp::HDF5Group, sp::Subplot)
    listgrp = HDF5.g_open(grp, "series_list")
    nseries = _read_length_attr(Vector, listgrp)

    for i in 1:nseries
        sgrp = HDF5.g_open(listgrp, "$i")
        seriesinfo = _read(KW, sgrp)

        plot!(sp, seriesinfo[:x], seriesinfo[:y]) #Add data & create data structures
        _hdf5_merge!(sp.series_list[end].plotattributes, seriesinfo)
    end

    #Perform after adding series... otherwise values get overwritten:
    agrp = HDF5.g_open(grp, "attr")
    _hdf5_merge!(sp.attr, _read(KW, agrp))

    return sp
end

function _read_plot(grp::HDF5Group)
    listgrp = HDF5.g_open(grp, "subplots")
    n = _read_length_attr(Vector, listgrp)

    #Construct new plot, +allocate subplots:
    plt = plot(layout=n)
    HDF5PLOT_PLOTREF.ref = plt #Used when reading "layout"

    agrp = HDF5.g_open(grp, "attr")
    _hdf5_merge!(plt.attr, _read(KW, agrp))

    for (i, sp) in enumerate(plt.subplots)
        sgrp = HDF5.g_open(listgrp, "$i")
        _read(sgrp, sp)
    end

    return plt
end

function hdf5plot_read(path::AbstractString; name::String="_unnamed")
    HDF5.h5open(path, "r") do file
        grp = HDF5.g_open(file, h5plotpath("_unnamed"))
        return _read_plot(grp)
    end
end


end #module _hdf5_implementation


#==Implement Plots.jl backend interface for HDF5Backend
===============================================================================#

is_marker_supported(::HDF5Backend, shape::Shape) = true

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

# Override this to update plot items (title, xlabel, etc), and add annotations (plotattributes[:annotations])
function _update_plot_object(plt::Plot{HDF5Backend})
    #Do nothing
end

# ----------------------------------------------------------------

# Display/show the plot (open a GUI window, or browser page, for example).
function _display(plt::Plot{HDF5Backend})
    msg = "HDF5 interface does not support `display()` function."
    msg *= "\nUse `Plots.hdf5plot_write(::String)` method to write to .HDF5 \"plot\" file instead."
    @warn(msg)
    return
end

#==Interface actually required to use HDF5Backend
===============================================================================#

hdf5plot_write(plt::Plot{HDF5Backend}, path::AbstractString) = _hdf5_implementation.hdf5plot_write(plt, path)
hdf5plot_write(path::AbstractString) = _hdf5_implementation.hdf5plot_write(current(), path)
hdf5plot_read(path::AbstractString) = _hdf5_implementation.hdf5plot_read(path)

#Last line
