# Use
#    @warnpcfail precompile(args...)
# if you want to be warned when a precompile directive fails
macro warnpcfail(ex::Expr)
    modl = __module__
    file = __source__.file === nothing ? "?" : String(__source__.file)
    line = __source__.line
    quote
        $(esc(ex)) || @warn """precompile directive
     $($(Expr(:quote, ex)))
 failed. Please report an issue in $($modl) (after checking for duplicates) or remove this directive.""" _file=$file _line=$line
    end
end


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
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol, Any},AbstractMatrix{T} where T})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol, Any},AbstractVector{T} where T,AbstractVector{T} where T,Function})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol, Any},Function,Number,Number})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol, Any},GroupBy,Any})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol, Any},Type{SliceIt},Any,Any,Any})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol, Any},Vector{Function},Number,Number})
    Base.precompile(Tuple{typeof(_apply_type_recipe),Any,AbstractArray,Any})
    Base.precompile(Tuple{typeof(_apply_type_recipe),Any,Surface,Any})
    Base.precompile(Tuple{typeof(_compute_xyz),Vector{Float64},Function,Nothing,Bool})
    Base.precompile(Tuple{typeof(_extract_group_attributes),Vector{String},Vector{Float64}})
    Base.precompile(Tuple{typeof(_map_funcs),Function,StepRangeLen{Float64, Base.TwicePrecision{Float64}, Base.TwicePrecision{Float64}}})
    Base.precompile(Tuple{typeof(_process_ribbon),Tuple{LinRange{Float64}, LinRange{Float64}},Dict{Symbol, Any}})
    Base.precompile(Tuple{typeof(_process_seriesrecipe),Any,Any})
    Base.precompile(Tuple{typeof(_process_seriesrecipes!),Any,Any})
    Base.precompile(Tuple{typeof(_scaled_adapted_grid),Function,Symbol,Symbol,Float64,Irrational{:π}})
    Base.precompile(Tuple{typeof(_series_data_vector),Int64,Dict{Symbol, Any}})
    Base.precompile(Tuple{typeof(_series_data_vector),Matrix{Float64},Dict{Symbol, Any}})
    Base.precompile(Tuple{typeof(_series_data_vector),Surface{Matrix{Int64}},Dict{Symbol, Any}})
    Base.precompile(Tuple{typeof(_series_data_vector),Vector{AbstractVector{Float64}},Dict{Symbol, Any}})
    Base.precompile(Tuple{typeof(_series_data_vector),Vector{Function},Dict{Symbol, Any}})
    Base.precompile(Tuple{typeof(_series_data_vector),Vector{Int64},Dict{Symbol, Any}})
    Base.precompile(Tuple{typeof(_series_data_vector),Vector{Real},Dict{Symbol, Any}})
    Base.precompile(Tuple{typeof(_series_data_vector),Vector{String},Dict{Symbol, Any}})
    Base.precompile(Tuple{typeof(_series_data_vector),Vector{Union{Missing, Int64}},Dict{Symbol, Any}})
    Base.precompile(Tuple{typeof(_series_data_vector),Vector{Vector{Float64}},Dict{Symbol, Any}})
    Base.precompile(Tuple{typeof(_series_data_vector),Vector{Vector{T} where T},Dict{Symbol, Any}})
    Base.precompile(Tuple{typeof(filter_data!),Dict{Symbol, Any},Vector{Int64}})
    Base.precompile(Tuple{typeof(recipe_pipeline!),Any,Any,Any})
    Base.precompile(Tuple{typeof(unzip),Vector{Tuple{Float64, Float64}}})
    Base.precompile(Tuple{typeof(unzip),Vector{Tuple{Int64, Int64}}})
    Base.precompile(Tuple{typeof(unzip),Vector{Tuple{Int64, Real}}})
    Base.precompile(Tuple{typeof(unzip),Vector{Tuple{Vector{Float64}, Vector{Float64}}}})
    let fbody = try __lookup_kwbody__(which(_extract_group_attributes, (Vector{String},Vector{Float64},))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Function,typeof(_extract_group_attributes),Vector{String},Vector{Float64},))
        end
    end
end
