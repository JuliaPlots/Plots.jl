module PkgDeps

using GraphRecipes

# const _pkgs = Pkg.available()
# const _idxmap = Dict(p=>i for (i,p) in enumerate(_pkgs))
# const _alist = [Int[] for i=1:length(_pkgs)]

# for pkg in _pkgs
# 	i = _idxmap[pkg]
# 	for dep in Pkg.dependents(pkg)
# 		if !haskey(_idxmap, dep)
# 			push!(_pkgs, dep)
# 			push!(_alist, [])
# 			_idxmap[dep] = length(_pkgs)
# 		end
# 		j = _idxmap[dep]
# 		push!(_alist[j], i)
# 	end
# end

@userplot DepsGraph
@recipe function f(g::DepsGraph)
    source, destiny, names = g.args
    arrow --> arrow()
    markersize --> 50
    markeralpha --> 0.2
    linealpha --> 0.4
    linewidth --> 2
    names --> names
    func --> :tree
    root --> :left
    GraphRecipes.GraphPlot((source, destiny))
end

# const args = (source, destiny, pkgs)

const all_pkgs = Pkg.available()
@show all_pkgs
const deplists = Dict(pkg => Pkg.dependents(pkg) for pkg in all_pkgs)
@show deplists

const childlists = Dict(pkg => Set{String}() for pkg in all_pkgs)
for pkg in all_pkgs
    for dep in deplists[pkg]
        if haskey(childlists, dep)
            push!(childlists[dep], pkg)
        else
            warn("Package $dep wasn't in Pkg.available()")
            deplists[dep] = []
            childlists[dep] = Set([pkg])
        end
    end
end
@show childlists

function add_deps(pkg, deps = Set([pkg]))
    for dep in deplists[pkg]
        if !(dep in deps)
            push!(deps, dep)
            add_deps(dep, deps)
        end
    end
    return deps
end

function add_children(pkg, children = Set([pkg]))
    for child in childlists[pkg]
        if !(child in children)
            push!(children, child)
            add_children(child, children)
        end
    end
    return children
end

function plotdeps(pkg)
    pkgs = unique(union(add_deps(pkg), add_children(pkg)))
    idxmap = Dict(p => i for (i, p) in enumerate(pkgs))

    source, destiny = Int[], Int[]
    for pkg in pkgs
        i = idxmap[pkg]
        for dep in deplists[pkg]
            # if !haskey(_idxmap, dep)
            # 	push!(pkgs, dep)
            # 	push!(_alist, [])
            # 	_idxmap[dep] = length(pkgs)
            # end
            if !haskey(idxmap, dep)
                warn("missing: ", dep)
                continue
            end
            j = idxmap[dep]
            push!(source, j)
            push!(destiny, i)
            # push!(_alist[j], i)
        end
    end
    return depsgraph(source, destiny, pkgs, root = :bottom)
end

# # pkgs = Set([pkg])
# idx = _idxmap[pkg]
# source, destiny = Int[], Int[]
# for j in _alist[i]
# 	push!(pkgs, _pkgs[j])
# 	push!(source, j)
# 	push!(destiny, i)
# end

# to use:
# depsgraph(PkgDeps.args...)

end # module
