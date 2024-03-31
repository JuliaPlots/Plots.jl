struct NoBackend <: AbstractBackend end

backend_name(::NoBackend) = :none

for s in (:attr, :seriestype, :marker, :style, :scale)
    f1 = Symbol("is_", s, "_supported")
    f2 = Symbol("supported_", s, "s")
    @eval begin
        $f1(::NoBackend, $s::Symbol) = true
        $f2(::NoBackend) = $(getproperty(Commons, Symbol("_all_", s, 's')))
    end
end

_display(::Plot{NoBackend}) =
    @info "No backend activated yet. Load the backend library and call the activation function to do so.\nE.g. `import GR; gr()` activates the GR backend."
