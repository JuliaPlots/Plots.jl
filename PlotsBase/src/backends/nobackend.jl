struct NoBackend <: AbstractBackend end

backend_name(::NoBackend) = :none

for sym in (:attr, :seriestype, :marker, :style, :scale)
    f1 = Symbol("is_$(sym)_supported")
    f2 = Symbol("supported_$(sym)s")
    @eval begin
        $f1(::NoBackend, $sym::Symbol) = true
        $f2(::NoBackend) = $(getproperty(Commons, Symbol("_all_$(sym)s")))
    end
end

_display(::Plot{NoBackend}) =
    @info "No backend activated yet. Load the backend library and call the activation function to do so.\nE.g. `import GR; gr()` activates the GR backend."
