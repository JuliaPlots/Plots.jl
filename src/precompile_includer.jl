should_precompile = true


# Don't edit the following! Instead change the script for `snoop_bot`.
ismultios = true
ismultiversion = true
# precompile_enclosure
@static if !should_precompile
    # nothing
elseif !ismultios && !ismultiversion
    @static if (isfile("../deps/SnoopCompile/precompile/precompile_Plots.jl"))
        include("../deps/SnoopCompile/precompile/precompile_Plots.jl")
        _precompile_()
    end
else
    @static if Sys.islinux()
        @static if v"1.5.0-DEV" <= VERSION <= v"1.5.9"
            @static if (isfile("../deps/SnoopCompile/precompile/linux/1.5/precompile_Plots.jl"))
                include("../deps/SnoopCompile/precompile/linux/1.5/precompile_Plots.jl")
                _precompile_()
            end
        else
            @static if (isfile("../deps/SnoopCompile/precompile/linux/1.5/precompile_Plots.jl"))
                include("../deps/SnoopCompile/precompile/linux/1.5/precompile_Plots.jl")
                _precompile_()
            end
        end

    else
        @static if v"1.5.0-DEV" <= VERSION <= v"1.5.9"
            @static if (isfile("../deps/SnoopCompile/precompile/linux/1.5/precompile_Plots.jl"))
                include("../deps/SnoopCompile/precompile/linux/1.5/precompile_Plots.jl")
                _precompile_()
            end
        else
            @static if (isfile("../deps/SnoopCompile/precompile/linux/1.5/precompile_Plots.jl"))
                include("../deps/SnoopCompile/precompile/linux/1.5/precompile_Plots.jl")
                _precompile_()
            end
        end

    end

end # precompile_enclosure
