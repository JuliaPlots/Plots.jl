#! format: off
should_precompile = true


# Don't edit the following! Instead change the script for `snoop_bot`.
ismultios = false
ismultiversion = true
# precompile_enclosure
@static if !should_precompile
    # nothing
elseif !ismultios && !ismultiversion
    @static if isfile(joinpath(@__DIR__, "../deps/SnoopCompile/precompile/precompile_Plots.jl"))
        include("../deps/SnoopCompile/precompile/precompile_Plots.jl")
        _precompile_()
    end
else
    @static if v"1.6.0-DEV" <= VERSION <= v"1.6.9"
        @static if isfile(joinpath(@__DIR__, "../deps/SnoopCompile/precompile//1.6/precompile_Plots.jl"))
            include("../deps/SnoopCompile/precompile//1.6/precompile_Plots.jl")
            _precompile_()
        end
    elseif v"1.7.0-DEV" <= VERSION <= v"1.7.9" 
        @static if isfile(joinpath(@__DIR__, "../deps/SnoopCompile/precompile//1.7/precompile_Plots.jl"))
            include("../deps/SnoopCompile/precompile//1.7/precompile_Plots.jl")
            _precompile_()
        end
    else 
    end

end # precompile_enclosure
