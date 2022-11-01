# # Grouping

"A special type that will break up incoming data into groups, and allow for easier creation of grouped plots"
mutable struct GroupBy
    group_labels::Vector                # length == numGroups
    group_indices::Vector{Vector{Int}}  # list of indices for each group
end

# this is when given a vector-type of values to group by
function _extract_group_attributes(v::AVec, args...; legend_entry = string)
    res = Dict{eltype(v),Vector{Int}}()
    for (i, label) in enumerate(v)
        if haskey(res, label)
            push!(res[label], i)
        else
            res[label] = [i]
        end
    end
    group_labels = (sort ∘ collect ∘ keys)(res)
    group_indices = getindex.(Ref(res), group_labels)

    GroupBy(map(legend_entry, group_labels), group_indices)
end
legend_entry_from_tuple(ns::Tuple) = join(ns, ' ')

# this is when given a tuple of vectors of values to group by
function _extract_group_attributes(vs::Tuple, args...)
    isempty(vs) && return GroupBy([""], [axes(args[1], 1)])
    v = map(tuple, vs...)
    _extract_group_attributes(v, args...; legend_entry = legend_entry_from_tuple)
end

# allow passing NamedTuples for a named legend entry
legend_entry_from_tuple(ns::NamedTuple) = join(["$k = $v" for (k, v) in pairs(ns)], ", ")

function _extract_group_attributes(vs::NamedTuple, args...)
    isempty(vs) && return GroupBy([""], [axes(args[1], 1)])
    v = map(NamedTuple{keys(vs)} ∘ tuple, values(vs)...)
    _extract_group_attributes(v, args...; legend_entry = legend_entry_from_tuple)
end

# expecting a mapping of "group label" to "group indices"
function _extract_group_attributes(idxmap::Dict{T,V}, args...) where {T,V<:AVec{Int}}
    group_labels = (sort ∘ collect ∘ keys)(idxmap)
    group_indices = Vector{Int}[collect(idxmap[k]) for k in group_labels]
    GroupBy(group_labels, group_indices)
end

filter_data(v::AVec, idxfilter::AVec{Int}) = v[idxfilter]
filter_data(v, idxfilter) = v

function filter_data!(plotattributes::AKW, idxfilter)
    for s in (:x, :y, :z)
        plotattributes[s] = filter_data(get(plotattributes, s, nothing), idxfilter)
    end
end

function _filter_input_data!(plotattributes::AKW)
    idxfilter = pop!(plotattributes, :idxfilter, nothing)
    idxfilter ≡ nothing || filter_data!(plotattributes, idxfilter)
end

function groupedvec2mat(x_ind, x, y::AbstractArray, groupby, def_val = y[1])
    y_mat = Array{promote_type(eltype(y), typeof(def_val))}(
        undef,
        length(keys(x_ind)),
        length(groupby.group_labels),
    )
    fill!(y_mat, def_val)
    for i in eachindex(groupby.group_labels)
        xi = x[groupby.group_indices[i]]
        yi = y[groupby.group_indices[i]]
        y_mat[getindex.(Ref(x_ind), xi), i] = yi
    end
    y_mat
end

groupedvec2mat(x_ind, x, y::Tuple, groupby) =
    Tuple(groupedvec2mat(x_ind, x, v, groupby) for v in y)

group_as_matrix(t) = false  # used in `StatsPlots`

# split the group into 1 series per group, and set the label and idxfilter for each
@recipe function f(groupby::GroupBy, args...)  # COV_EXCL_LINE
    plt = plotattributes[:plot_object]
    group_length = maximum(union(groupby.group_indices...))
    if !group_as_matrix(args[1])
        for (i, glab) in enumerate(groupby.group_labels)
            @series begin
                label --> string(glab)
                idxfilter --> groupby.group_indices[i]
                for (key, val) in plotattributes
                    if splittable_attribute(plt, key, val, group_length)
                        :($key) := split_attribute(plt, key, val, groupby.group_indices[i])
                    end
                end
                args
            end
        end
    else
        g = args[1]
        if length(g.args) == 1
            x = zeros(Int, group_length)
            for indexes in groupby.group_indices
                x[indexes] = eachindex(indexes)
            end
            last_args = g.args
        else
            x, last_args... = g.args
        end
        x_u = unique(sort(x))
        x_ind = Dict(zip(x_u, eachindex(x_u)))
        for (key, val) in plotattributes
            if splittable_attribute(plt, key, val, group_length)
                :($key) := groupedvec2mat(x_ind, x, val, groupby)
            end
        end
        label --> reshape(groupby.group_labels, 1, :)
        typeof(g)((
            x_u,
            (groupedvec2mat(x_ind, x, arg, groupby, NaN) for arg in last_args)...,
        ))
    end
end
