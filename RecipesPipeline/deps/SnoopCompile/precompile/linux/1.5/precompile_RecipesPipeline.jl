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
    Base.precompile(Tuple{typeof(Base.Broadcast.materialize),Base.Broadcast.Broadcasted{Base.Broadcast.DefaultArrayStyle{1},Nothing,typeof(RecipesPipeline._scaled_adapted_grid),Tuple{Array{Function,1},Base.RefValue{Symbol},Base.RefValue{Symbol},Float64,Float64}}})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol,Any},AbstractArray{T,2} where T})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol,Any},Array{Function,1},Number,Number})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol,Any},Function,Number,Number})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol,Any},RecipesPipeline.GroupBy,Any})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol,Any},Type{SliceIt},Any,Any,Any})
    Base.precompile(Tuple{typeof(RecipesPipeline._apply_type_recipe),Any,AbstractArray,Any})
    Base.precompile(Tuple{typeof(RecipesPipeline._apply_type_recipe),Any,Surface,Any})
    Base.precompile(Tuple{typeof(RecipesPipeline._extract_group_attributes),Array{String,1},Array{Float64,1}})
    Base.precompile(Tuple{typeof(RecipesPipeline._map_funcs),Function,StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}}})
    Base.precompile(Tuple{typeof(RecipesPipeline._process_ribbon),Tuple{LinRange{Float64},LinRange{Float64}},Dict{Symbol,Any}})
    Base.precompile(Tuple{typeof(RecipesPipeline._process_seriesrecipe),Any,Any})
    Base.precompile(Tuple{typeof(RecipesPipeline._process_seriesrecipes!),Any,Any})
    Base.precompile(Tuple{typeof(RecipesPipeline._scaled_adapted_grid),Function,Symbol,Symbol,Float64,Irrational{:π}})
    Base.precompile(Tuple{typeof(RecipesPipeline._series_data_vector),Array{AbstractArray{Float64,1},1},Dict{Symbol,Any}})
    Base.precompile(Tuple{typeof(RecipesPipeline._series_data_vector),Array{Array{Float64,1},1},Dict{Symbol,Any}})
    Base.precompile(Tuple{typeof(RecipesPipeline._series_data_vector),Array{Array{T,1} where T,1},Dict{Symbol,Any}})
    Base.precompile(Tuple{typeof(RecipesPipeline._series_data_vector),Array{Float64,1},Dict{Symbol,Any}})
    Base.precompile(Tuple{typeof(RecipesPipeline._series_data_vector),Array{Float64,2},Dict{Symbol,Any}})
    Base.precompile(Tuple{typeof(RecipesPipeline._series_data_vector),Array{Function,1},Dict{Symbol,Any}})
    Base.precompile(Tuple{typeof(RecipesPipeline._series_data_vector),Array{Int64,1},Dict{Symbol,Any}})
    Base.precompile(Tuple{typeof(RecipesPipeline._series_data_vector),Array{Real,1},Dict{Symbol,Any}})
    Base.precompile(Tuple{typeof(RecipesPipeline._series_data_vector),Array{String,1},Dict{Symbol,Any}})
    Base.precompile(Tuple{typeof(RecipesPipeline._series_data_vector),Array{Union{Missing, Int64},1},Dict{Symbol,Any}})
    Base.precompile(Tuple{typeof(RecipesPipeline._series_data_vector),Int64,Dict{Symbol,Any}})
    Base.precompile(Tuple{typeof(RecipesPipeline._series_data_vector),StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Dict{Symbol,Any}})
    Base.precompile(Tuple{typeof(RecipesPipeline._series_data_vector),StepRange{Int64,Int64},Dict{Symbol,Any}})
    Base.precompile(Tuple{typeof(RecipesPipeline._series_data_vector),Surface{Array{Int64,2}},Dict{Symbol,Any}})
    Base.precompile(Tuple{typeof(RecipesPipeline.filter_data),Array{Float64,1},Array{Int64,1}})
    Base.precompile(Tuple{typeof(RecipesPipeline.userrecipe_signature_string),Any,Vararg{Any,N} where N})
    Base.precompile(Tuple{typeof(RecipesPipeline.userrecipe_signature_string),Any})
    Base.precompile(Tuple{typeof(copy),Base.Broadcast.Broadcasted{Base.Broadcast.Style{Tuple},Nothing,typeof(string),Tuple{Base.Broadcast.Broadcasted{Base.Broadcast.Style{Tuple},Nothing,typeof(typeof),Tuple{Tuple{Array{Dates.DateTime,1},UnitRange{Int64},Surface{Array{Float64,2}}}}}}}})
    Base.precompile(Tuple{typeof(copy),Base.Broadcast.Broadcasted{Base.Broadcast.Style{Tuple},Nothing,typeof(string),Tuple{Base.Broadcast.Broadcasted{Base.Broadcast.Style{Tuple},Nothing,typeof(typeof),Tuple{Tuple{Array{Float64,1},Array{Float64,1},Surface{Array{Float64,2}}}}}}}})
    Base.precompile(Tuple{typeof(copy),Base.Broadcast.Broadcasted{Base.Broadcast.Style{Tuple},Nothing,typeof(string),Tuple{Base.Broadcast.Broadcasted{Base.Broadcast.Style{Tuple},Nothing,typeof(typeof),Tuple{Tuple{Array{String,1},Array{String,1},Surface{Array{Float64,2}}}}}}}})
    Base.precompile(Tuple{typeof(copy),Base.Broadcast.Broadcasted{Base.Broadcast.Style{Tuple},Nothing,typeof(string),Tuple{Base.Broadcast.Broadcasted{Base.Broadcast.Style{Tuple},Nothing,typeof(typeof),Tuple{Tuple{Base.OneTo{Int64},Base.OneTo{Int64},Surface{Array{Int64,2}}}}}}}})
    Base.precompile(Tuple{typeof(copy),Base.Broadcast.Broadcasted{Base.Broadcast.Style{Tuple},Nothing,typeof(string),Tuple{Base.Broadcast.Broadcasted{Base.Broadcast.Style{Tuple},Nothing,typeof(typeof),Tuple{Tuple{DataType,RecipesPipeline.Formatted{Array{Int64,1}},UnitRange{Int64},Surface{Array{Float64,2}}}}}}}})
    Base.precompile(Tuple{typeof(copy),Base.Broadcast.Broadcasted{Base.Broadcast.Style{Tuple},Nothing,typeof(string),Tuple{Base.Broadcast.Broadcasted{Base.Broadcast.Style{Tuple},Nothing,typeof(typeof),Tuple{Tuple{RecipesPipeline.Formatted{Array{Int64,1}},UnitRange{Int64},Surface{Array{Float64,2}}}}}}}})
    Base.precompile(Tuple{typeof(copy),Base.Broadcast.Broadcasted{Base.Broadcast.Style{Tuple},Nothing,typeof(string),Tuple{Base.Broadcast.Broadcasted{Base.Broadcast.Style{Tuple},Nothing,typeof(typeof),Tuple{Tuple{RecipesPipeline.GroupBy,Array{Float64,1}}}}}}})
    Base.precompile(Tuple{typeof(copy),Base.Broadcast.Broadcasted{Base.Broadcast.Style{Tuple},Nothing,typeof(string),Tuple{Base.Broadcast.Broadcasted{Base.Broadcast.Style{Tuple},Nothing,typeof(typeof),Tuple{Tuple{StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Surface{Array{Float64,2}}}}}}}})
    Base.precompile(Tuple{typeof(recipe_pipeline!),Any,Any,Any})
    Base.precompile(Tuple{typeof(unzip),Array{Tuple{Array{Float64,1},Array{Float64,1}},1}})
    Base.precompile(Tuple{typeof(unzip),Array{Tuple{Int64,Int64},1}})
    Base.precompile(Tuple{typeof(unzip),Array{Tuple{Int64,Real},1}})
    let fbody = try __lookup_kwbody__(which(RecipesPipeline._extract_group_attributes, (Array{String,1},Array{Float64,1},))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Function,typeof(RecipesPipeline._extract_group_attributes),Array{String,1},Array{Float64,1},))
        end
    end
end
