using SnoopPrecompile

if get(ENV, "PLOTS_PRECOMPILE", "true") == "true"
    @precompile_setup begin
        n = length(_examples)
        imports = sizehint!(Expr[], n)
        examples = sizehint!(Expr[], 10n)
        for i in setdiff(1:n, _backend_skips[:gr])
            _examples[i].external && continue
            (imp = _examples[i].imports) === nothing || push!(imports, imp)
            func = gensym(string(i))
            push!(examples, quote
                $func() = begin  # evaluate each example in a local scope
                    # @show $i  # debug
                    $(_examples[i].exprs)
                    if $i == 1  # only for one example
                        fn = tempname()
                        pl = current()
                        gui(pl)
                        savefig(pl, "$fn.png")
                        savefig(pl, "$fn.pdf")
                    end
                    nothing
                end
                try
                    # During precompilation on the Windows GitHub CI in Julia 1.8.2+,
                    # can fail here due to GR potentially failing to write out the
                    # temporary file. Pending a fix, swallow the error and continue.
                    $func()
                catch
                    @warn "Plots: Failed a trial save during precompilation"
                end
            end)
        end
        withenv("GKSwstype" => "nul") do
            @precompile_all_calls begin
                eval.(imports)
                gr()
                eval.(examples)
                # eventually eval for another backend ...
            end
        end
    end
end
