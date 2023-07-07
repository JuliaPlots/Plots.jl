using Scratch
using REPL

const _plotly_local_file_path = Ref{Union{Nothing,String}}(nothing)
# use fixed version of Plotly instead of the latest one for stable dependency
# see github.com/JuliaPlots/Plots.jl/pull/2779
const _plotly_min_js_filename = "plotly-2.6.3.min.js"

const _use_local_dependencies = Ref(false)
const _use_local_plotlyjs = Ref(false)

_plots_defaults() =
    if isdefined(Main, :PLOTS_DEFAULTS)
        copy(Dict{Symbol,Any}(Main.PLOTS_DEFAULTS))
    else
        Dict{Symbol,Any}()
    end

function _plots_theme_defaults()
    user_defaults = _plots_defaults()
    theme(pop!(user_defaults, :theme, :default); user_defaults...)
end

function _plots_plotly_defaults()
    if bool_env("PLOTS_HOST_DEPENDENCY_LOCAL", "false")
        _plotly_local_file_path[] =
            fn = joinpath(@get_scratch!("plotly"), _plotly_min_js_filename)
        isfile(fn) ||
            Downloads.download("https://cdn.plot.ly/$(_plotly_min_js_filename)", fn)
        _use_local_plotlyjs[] = true
    end
    _use_local_dependencies[] = _use_local_plotlyjs[]
end

function __init__()
    _plots_theme_defaults()
    _plots_plotly_defaults()

    insert!(
        Base.Multimedia.displays,
        findlast(
            x -> x isa Base.TextDisplay || x isa REPL.REPLDisplay,
            Base.Multimedia.displays,
        ) + 1,
        PlotsDisplay(),
    )

    i ->
        begin
            while PlotsDisplay() in Base.Multimedia.displays
                popdisplay(PlotsDisplay())
            end
            insert!(
                Base.Multimedia.displays,
                findlast(x -> x isa REPL.REPLDisplay, Base.Multimedia.displays) + 1,
                PlotsDisplay(),
            )
        end |> atreplinit

    _runtime_init(backend())
    nothing
end

##################################################################

# COV_EXCL_START
# TODO: revise and re-enable before release
# @setup_workload begin
#     @debug backend_package_name()
#     n = length(_examples)
#     imports = sizehint!(Expr[], n)
#     examples = sizehint!(Expr[], 10n)
#     for i in setdiff(1:n, _backend_skips[backend_name()], _animation_examples)
#         _examples[i].external && continue
#         (imp = _examples[i].imports) === nothing || push!(imports, imp)
#         func = gensym(string(i))
#         push!(
#             examples,
#             quote
#                 $func() = begin  # evaluate each example in a local scope
#                     $(_examples[i].exprs)
#                     $i == 1 || return  # only for one example
#                     fn = tempname()
#                     pl = current()
#                     show(devnull, pl)
#                     # FIXME: pgfplotsx requires bug
#                     backend_name() === :pgfplotsx && return
#                     if backend_name() === :unicodeplots
#                         savefig(pl, "$fn.txt")
#                         return
#                     end
#                     showable(MIME"image/png"(), pl) && savefig(pl, "$fn.png")
#                     showable(MIME"application/pdf"(), pl) && savefig(pl, "$fn.pdf")
#                     if showable(MIME"image/svg+xml"(), pl)
#                         show(IOBuffer(), MIME"image/svg+xml"(), pl)
#                     end
#                     nothing
#                 end
#                 $func()
#             end,
#         )
#     end
#     withenv("GKSwstype" => "nul") do
#         @compile_workload begin
#             load_default_backend()
#             eval.(imports)
#             eval.(examples)
#         end
#     end
#     CURRENT_PLOT.nullableplot = nothing
# end
# # COV_EXCL_STOP
