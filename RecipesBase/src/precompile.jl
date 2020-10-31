function _precompile_()
    ccall(:jl_generating_output, Cint, ()) == 1 || return nothing
    Base.precompile(Tuple{typeof(RecipesBase.create_kw_body),Expr})
    Base.precompile(Tuple{typeof(RecipesBase.get_function_def),Expr,Array{Any,1}})
    Base.precompile(Tuple{typeof(map),Function,Array{AbstractLayout,1}})
    Base.precompile(Tuple{typeof(map),Function,Array{AbstractLayout,2}})
end

_precompile_()
