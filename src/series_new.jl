
# we are going to build recipes to do the processing and splitting of the args

# instead of process_inputs:

@recipe function f{X<:Number,Y<:Number}(x::AVec{X}, y::AVec{Y})
    x --> x
    y --> y
    ()
end
