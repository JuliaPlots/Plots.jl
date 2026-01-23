#=

# HDF5 Plots: Save/replay plots to/from HDF5

# Usage
Write to .hdf5 file using:
    p = plot(...)
   Plots.hdf5plot_write(p, "plotsave.hdf5")

Read from .hdf5 file using:
    pyplot()  # Must first select backend
    pread = Plots.hdf5plot_read("plotsave.hdf5")
    display(pread)

# TODO
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
=#

"""
    _hdf5_implementation

Create module (namespace) for implementing HDF5 "plots".
(Avoid name collisions, while keeping names short)
"""
module _hdf5_implementation  # Tools required to implements HDF5 "plots"

    import Dates

    # Plots.jl imports HDF5 to main:
    import ..HDF5
    import ..HDF5: Group, Dataset

    import ..Colors, ..Colorant
    import ..PlotUtils.ColorSchemes.ColorScheme

    import ..HDF5Backend, .._current_plots_version
    import ..HDF5PLOT_MAP_STR2TELEM, ..HDF5PLOT_MAP_TELEM2STR
    import ..HDF5Plot_PlotRef, ..HDF5PLOT_PLOTREF
    import ..BoundingBox, ..Extrema, ..Length
    import ..RecipesPipeline.datetimeformatter
    import ..PlotUtils.ColorPalette,
        ..PlotUtils.CategoricalColorGradient, ..PlotUtils.ContinuousColorGradient
    import ..Surface, ..Shape, ..Arrow
    import ..GridLayout, ..RootLayout
    import ..Font, ..PlotText, ..SeriesAnnotations
    import ..Axis, ..Subplot, ..Plot
    import ..AKW, ..KW, ..DefaultsDict
    import .._axis_defaults
    import ..plot, ..plot!

    # Types that already have built-in HDF5 support (just write out natively):
    const HDF5_SupportedTypes = Union{Number, String}

    # Dispatch types:
    struct CplxTuple end  # Identifies a "complex" tuple structure (not merely numbers)

    # HDF5 reader will auto-detect type correctly:
    struct HDF5_AutoDetect end  # See HDF5_SupportedTypes

    if length(HDF5PLOT_MAP_TELEM2STR) < 1
        # Possible element types of high-level data types:
        # (Used to add type information as an HDF5 string attribute)
        # (Also used to dispatch appropriate read function through _read_typed())
        _telem2str = Dict{String, Type}(
            "NOTHING" => Nothing,
            "SYMBOL" => Symbol,
            "RGBA" => Colorant,  # Write out any Colorant to an #RRGGBBAA string
            "TUPLE" => Tuple,
            "CTUPLE" => CplxTuple,
            "EXTREMA" => Extrema,
            "LENGTH" => Length,
            "ARRAY" => Array,  # Array{Any} (because Array{T<:Union{Number, String}} natively supported by HDF5)

            # Sub-structure types:
            "T_DATETIMEFORMATTER" => typeof(datetimeformatter),

            # Sub-structure types:
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
        merge!(HDF5PLOT_MAP_STR2TELEM, _telem2str)  # Faster to create than push!()??
        merge!(
            HDF5PLOT_MAP_TELEM2STR,
            Dict{Type, String}(v => k for (k, v) in HDF5PLOT_MAP_STR2TELEM),
        )
    end

    # Helper functions

    h5plotpath(plotname::String) = "plots/$plotname"

    _hdf5_merge!(dest::AKW, src::AKW) =
        for (k, v) in src
        if isa(v, Axis)
            _hdf5_merge!(dest[k].plotattributes, v.plotattributes)
        else
            dest[k] = v
        end
    end

    # _type_for_map returns the type to use with HDF5PLOT_MAP_TELEM2STR[], in case it is not concrete:
    _type_for_map(::Type{T}) where {T} = T # Catch-all
    _type_for_map(::Type{T}) where {T <: BoundingBox} = BoundingBox
    _type_for_map(::Type{T}) where {T <: ColorScheme} = ColorScheme
    _type_for_map(::Type{T}) where {T <: Surface} = Surface

    # Read/write things like type name in attributes
    _write_datatype_attr(ds::Union{Group, Dataset}, ::Type{T}) where {T} =
        HDF5.attributes(ds)["TYPE"] = HDF5PLOT_MAP_TELEM2STR[T]

    function _read_datatype_attr(ds::Union{Group, Dataset})
        Base.haskey(HDF5.attributes(ds), "TYPE") || return HDF5_AutoDetect
        return HDF5PLOT_MAP_STR2TELEM[HDF5.read(HDF5.attributes(ds)["TYPE"])]
    end

    # Type parameter attributes:
    _write_typeparam_attr(ds::Dataset, v::Length{T}) where {T} =
        HDF5.attributes(ds)["TYPEPARAM"] = string(T) # Need to add units for Length

    _read_typeparam_attr(ds::Dataset) = HDF5.read(HDF5.attributes(ds)["TYPEPARAM"])

    _write_length_attr(grp::Group, v::Vector) = HDF5.attributes(grp)["LENGTH"] = length(v)
    _read_length_attr(::Type{Vector}, grp::Group) = HDF5.read(HDF5.attributes(grp)["LENGTH"])

    _write_size_attr(grp::Group, v::Array) = HDF5.attributes(grp)["SIZE"] = [size(v)...]

    _read_size_attr(::Type{Array}, grp::Group) =
        tuple(HDF5.read(HDF5.attributes(grp)["SIZE"])...)

    # _write_typed(): Simple (leaf) datatypes. (Labels with type name.)

    set_value!(grp::Group, name::String, v) = (grp[name] = v; grp[name])

    # Default behaviour: Assumes value is supported by HDF5 format
    _write_typed(grp::Group, name::String, v::HDF5_SupportedTypes) =
        (set_value!(grp, name, v); nothing)  # No need to _write_datatype_attr

    _write_typed(grp::Group, name::String, v::Nothing) =
        _write_datatype_attr(set_value!(grp, name, "nothing"), Nothing) # Redundancy check/easier to read HDF5 file

    _write_typed(grp::Group, name::String, v::Symbol) =
        _write_datatype_attr(set_value!(grp, name, string(v)), Symbol)

    _write_typed(grp::Group, name::String, v::Colorant) =
        _write_datatype_attr(set_value!(grp, name, "#" * Colors.hex(v, :RRGGBBAA)), Colorant)

    _write_typed(grp::Group, name::String, v::Extrema) =
        _write_datatype_attr(set_value!(grp, name, [v.emin, v.emax]), Extrema)  # More compact than writing struct

    function _write_typed(grp::Group, name::String, v::Length)
        grp[name] = v.value
        _write_datatype_attr(grp[name], Length)
        return _write_typeparam_attr(grp[name], v)
    end

    _write_typed(grp::Group, name::String, v::typeof(datetimeformatter)) =
        _write_datatype_attr(set_value!(grp, name, string(v)), typeof(datetimeformatter))  # Just write something that helps reader

    _write_typed(grp::Group, name::String, v::Array{T}) where {T <: Number} =
        (set_value!(grp, name, v); nothing)  # No need to _write_datatype_attr

    _write_typed(grp::Group, name::String, v::AbstractRange) =
        _write_typed(grp, name, collect(v)) # For now

    # Helper functions for writing complex data structures

    # Write an array using HDF5 hierarchy (when not using simple numeric eltype):
    function _write_harray(grp::Group, name::String, v::Array)
        sgrp = HDF5.create_group(grp, name)
        lidx = LinearIndices(size(v))

        for iter in eachindex(v)
            coord = lidx[iter]
            elem = v[iter]
            idxstr = join(coord, "_")
            _write_typed(sgrp, "v$idxstr", elem)
        end

        return _write_size_attr(sgrp, v)
    end

    # Write Dict without tagging with type:
    _write(grp::Group, name::String, d::AbstractDict) =
    let sgrp = HDF5.create_group(grp, name)
        for (k, v) in d
            kstr = string(k)
            _write_typed(sgrp, kstr, v)
        end
    end

    # Write out arbitrary `struct`s:
    _writestructgeneric(grp::Group, obj::T) where {T} =
        for fname in fieldnames(T)
        v = getfield(obj, fname)
        _write_typed(grp, String(fname), v)
    end

    # _write_typed(): More complex structures. (Labels with type name.)

    # Catch-all (default behaviour for `struct`s):
    function _write_typed(grp::Group, name::String, v::T) where {T}
        # NOTE: need "name" parameter so that call signature is same with built-ins
        MT = _type_for_map(T)
        try # Check to see if type is supported
            typestr = HDF5PLOT_MAP_TELEM2STR[MT]
        catch
            @warn "HDF5Plots does not yet support structs of type `$MT`\n\n$grp"
            return
        end

        # If attribute is supported and no writer is defined, then this should work:
        objgrp = HDF5.create_group(grp, name)
        _write_datatype_attr(objgrp, MT)
        return _writestructgeneric(objgrp, v)
    end

    function _write_typed(grp::Group, name::String, v::Array{T}) where {T}
        _write_harray(grp, name, v)
        return _write_datatype_attr(grp[name], Array) # Any
    end

    function _write_typed(grp::Group, name::String, v::Tuple, ::Type{ELT}) where {ELT <: Number} # Basic Tuple
        _write_typed(grp, name, [v...])
        return _write_datatype_attr(grp[name], Tuple)
    end
    function _write_typed(grp::Group, name::String, v::Tuple, ::Type) # CplxTuple
        _write_harray(grp, name, [v...])
        return _write_datatype_attr(grp[name], CplxTuple)
    end
    _write_typed(grp::Group, name::String, v::Tuple) = _write_typed(grp, name, v, eltype(v))

    _write_typed(grp::Group, name::String, v::Dict) = nothing

    function _write_typed(grp::Group, name::String, d::DefaultsDict) # Typically for plot attributes
        _write(grp, name, d)
        return _write_datatype_attr(grp[name], DefaultsDict)
    end

    function _write_typed(grp::Group, name::String, v::Axis)
        sgrp = HDF5.create_group(grp, name)
        # Ignore: sps::Vector{Subplot}
        _write_typed(sgrp, "plotattributes", v.plotattributes)
        return _write_datatype_attr(sgrp, Axis)
    end

    function _write_typed(grp::Group, name::String, v::Subplot)
        # Not for use in main "Plot.subplots[]" hierarchy.  Just establishes reference with subplot_index.
        sgrp = HDF5.create_group(grp, name)
        _write_typed(sgrp, "index", v[:subplot_index])
        _write_datatype_attr(sgrp, Subplot)
        return
    end

    _write_typed(grp::Group, name::String, v::Plot) = nothing  # Don't write plot references

    # _write(): Write out more complex structures
    # NOTE: No need to write out type information (inferred from hierarchy)

    function _write(grp::Group, sp::Subplot{HDF5Backend})
        _write_typed(grp, "attr", sp.attr)

        listgrp = HDF5.create_group(grp, "series_list")
        _write_length_attr(listgrp, sp.series_list)
        for (i, series) in enumerate(sp.series_list)
            # Just write .plotattributes part:
            _write(listgrp, "$i", series.plotattributes)
        end
        return
    end

    function _write(grp::Group, plt::Plot{HDF5Backend})
        _write_typed(grp, "attr", plt.attr)

        listgrp = HDF5.create_group(grp, "subplots")
        _write_length_attr(listgrp, plt.subplots)
        for (i, sp) in enumerate(plt.subplots)
            sgrp = HDF5.create_group(listgrp, "$i")
            _write(sgrp, sp)
        end
        return
    end

    function hdf5plot_write(
            plt::Plot{HDF5Backend},
            path::AbstractString;
            name::String = "_unnamed",
        )
        return HDF5.h5open(path, "w") do file
            HDF5.write_dataset(file, "VERSION_INFO", string(_current_plots_version))
            grp = HDF5.create_group(file, h5plotpath(name))
            _write(grp, plt)
        end
    end

    # _read(): Read data, but not type information.

    # Types with built-in HDF5 support:
    _read(::Type{HDF5_AutoDetect}, ds::Dataset) = HDF5.read(ds)

    function _read(::Type{Nothing}, ds::Dataset)
        nstr = "nothing"
        v = HDF5.read(ds)
        nstr == v || throw(
            Meta.ParseError("_read(::Nothing, ::Group): Read $v != $nstr:\n$(HDF5.name(ds))"),
        )
        return
    end
    _read(::Type{Symbol}, ds::Dataset) = Symbol(HDF5.read(ds))
    _read(::Type{Colorant}, ds::Dataset) = parse(Colorant, HDF5.read(ds))
    _read(::Type{Tuple}, ds::Dataset) = tuple(HDF5.read(ds)...)
    _read(::Type{Extrema}, ds::Dataset) =
    let v = HDF5.read(ds)
        Extrema(v[1], v[2])
    end
    function _read(::Type{Length}, ds::Dataset)
        TUNIT = Symbol(_read_typeparam_attr(ds))
        v = HDF5.read(ds)
        return Length{TUNIT, typeof(v)}(v)
    end
    _read(::Type{typeof(datetimeformatter)}, ds::Dataset) = datetimeformatter

    # Helper functions for reading in complex data structures

    # When type is unknown, _read_typed() figures it out:
    function _read_typed(grp::Group, name::String)
        ds = grp[name]
        return _read(_read_datatype_attr(ds), ds)
    end

    # _readstructgeneric: Needs object values to be written out with _write_typed():
    function _readstructgeneric(::Type{T}, grp::Group) where {T}
        vlist = Array{Any}(nothing, fieldcount(T))
        for (i, fname) in enumerate(fieldnames(T))
            vlist[i] = _read_typed(grp, String(fname))
        end
        return T(vlist...)
    end

    # Read KW from group:
    function _read(::Type{KW}, grp::Group)
        d = KW()
        gkeys = keys(grp)
        for k in gkeys
            try
                v = _read_typed(grp, k)
                d[Symbol(k)] = v
            catch e
                @warn "Could not read field $k" e grp
            end
        end
        return d
    end

    # _read(): More complex structures.

    # Catch-all (default behaviour for `struct`s):
    _read(T::Type, grp::Group) = _readstructgeneric(T, grp)

    function _read(::Type{Array}, grp::Group) # Array{Any}
        sz = _read_size_attr(Array, grp)
        tuple(0) == sz && return []
        result = Array{Any}(undef, sz)
        lidx = LinearIndices(sz)

        for iter in eachindex(result)
            coord = lidx[iter]
            idxstr = join(coord, "_")
            result[iter] = _read_typed(grp, "v$idxstr")
        end

        # Hack: Implicitly make Julia detect element type.
        #       (Should probably write it explicitly to file)
        result = [elem for elem in result]  # Potentially make more specific
        return reshape(result, sz)
    end

    _read(::Type{CplxTuple}, grp::Group) = tuple(_read(Array, grp)...)

    function _read(::Type{GridLayout}, grp::Group)
        # parent = _read_typed(grp, "parent")  # Can't use generic reader
        parent = RootLayout()  # TODO: support parent???
        minpad = _read_typed(grp, "minpad")
        bbox = _read_typed(grp, "bbox")
        grid = _read_typed(grp, "grid")
        widths = _read_typed(grp, "widths")
        heights = _read_typed(grp, "heights")
        attr = KW() # TODO support attr: _read_typed(grp, "attr")

        return GridLayout(parent, minpad, bbox, grid, widths, heights, attr)
    end
    # Defaults depends on context. So: user must constructs with defaults, then read.
    function _read(::Type{DefaultsDict}, grp::Group)
        # User should set DefaultsDict.defaults to one of:
        #    _plot_defaults, _subplot_defaults, _axis_defaults, _series_defaults
        path = HDF5.name(ds)
        return @warn "Cannot yet read DefaultsDict using _read_typed():\n    $path\nCannot fully reconstruct plot."
    end

    # 1st arg appears to be ref to subplots. Seems to work without it.
    _read(::Type{Axis}, grp::Group) =
        Axis([], DefaultsDict(_read(KW, grp["plotattributes"]), _axis_defaults))

    # Not for use in main "Plot.subplots[]" hierarchy.  Just establishes reference with subplot_index.
    _read(::Type{Subplot}, grp::Group) =
        HDF5PLOT_PLOTREF.ref.subplots[_read_typed(grp, "index")]

    # _read(): Main plot structures

    function _read(grp::Group, sp::Subplot)
        listgrp = HDF5.open_group(grp, "series_list")
        nseries = _read_length_attr(Vector, listgrp)

        for i in 1:nseries
            sgrp = HDF5.open_group(listgrp, "$i")
            seriesinfo = _read(KW, sgrp)

            plot!(sp, seriesinfo[:x], seriesinfo[:y]) # Add data & create data structures
            _hdf5_merge!(sp.series_list[end].plotattributes, seriesinfo)
        end

        # Perform after adding series... otherwise values get overwritten:
        agrp = HDF5.open_group(grp, "attr")
        _hdf5_merge!(sp.attr, _read(KW, agrp))

        return sp
    end

    function _read_plot(grp::Group)
        listgrp = HDF5.open_group(grp, "subplots")
        n = _read_length_attr(Vector, listgrp)

        # Construct new plot, +allocate subplots:
        plt = plot(layout = n)
        HDF5PLOT_PLOTREF.ref = plt  # Used when reading "layout"

        agrp = HDF5.open_group(grp, "attr")
        _hdf5_merge!(plt.attr, _read(KW, agrp))

        for (i, sp) in enumerate(plt.subplots)
            sgrp = HDF5.open_group(listgrp, "$i")
            _read(sgrp, sp)
        end

        return plt
    end

    hdf5plot_read(path::AbstractString; name::String = "_unnamed") =
        HDF5.h5open(path, "r") do file
        grp = HDF5.open_group(file, h5plotpath("_unnamed"))
        return _read_plot(grp)
    end

end  # module _hdf5_implementation

# Implement Plots.jl backend interface for HDF5Backend

is_marker_supported(::HDF5Backend, shape::Shape) = true

# Create the window/figure for this backend.
function _create_backend_figure(plt::Plot{HDF5Backend}) end

# Set up the subplot within the backend object.
function _initialize_subplot(plt::Plot{HDF5Backend}, sp::Subplot{HDF5Backend}) end

# Add one series to the underlying backend object.
# Called once per series
# NOTE: Seems to be called when user calls plot()... even if backend
#       plot, sp.o has not yet been constructed...
function _series_added(plt::Plot{HDF5Backend}, series::Series) end

# When series data is added/changed, this callback can do dynamic updates to the backend object.
# note: if the backend rebuilds the plot from scratch on display, then you might not do anything here.
function _series_updated(plt::Plot{HDF5Backend}, series::Series) end

# called just before updating layout bounding boxes... in case you need to prep
# for the calcs
function _before_layout_calcs(plt::Plot{HDF5Backend}) end

# Set the (left, top, right, bottom) minimum padding around the plot area
# to fit ticks, tick labels, guides, colorbars, etc.
function _update_min_padding!(sp::Subplot{HDF5Backend}) end

# Override this to update plot items (title, xlabel, etc), and add annotations (plotattributes[:annotations])
function _update_plot_object(plt::Plot{HDF5Backend}) end

# ----------------------------------------------------------------

# Display/show the plot (open a GUI window, or browser page, for example).
function _display(plt::Plot{HDF5Backend})
    msg = "HDF5 interface does not support `display()` function."
    msg *= "\nUse `Plots.hdf5plot_write(::String)` method to write to .HDF5 \"plot\" file instead."
    @warn msg
    return
end

# Interface actually required to use HDF5Backend

hdf5plot_write(plt::Plot{HDF5Backend}, path::AbstractString) =
    _hdf5_implementation.hdf5plot_write(plt, path)
hdf5plot_write(path::AbstractString) = _hdf5_implementation.hdf5plot_write(current(), path)
hdf5plot_read(path::AbstractString) = _hdf5_implementation.hdf5plot_read(path)
