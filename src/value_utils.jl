# src/value_utils.jl
# Lightweight helpers for inspecting value distributions (no semantics enforced).

"""
    cooccurrence_values(cooc::AbstractChordData) -> Vector{Float64}

Return the upper-triangle values (each pair counted once).

This is a small helper for choosing visualization thresholds (e.g. `min_ribbon_value`).
No normalization or scaling is performed; values are returned as-is (filtered to `> 0`).
"""
function cooccurrence_values(cooc::AbstractChordData)
    n = nlabels(cooc)
    vals = Float64[]
    for j in 2:n
        for i in 1:(j - 1)
            v = cooc.matrix[i, j]
            v > 0 && push!(vals, Float64(v))
        end
    end
    vals
end

"""
    cooccurrence_values(coocs::AbstractVector{<:AbstractChordData}) -> Vector{Float64}

Concatenate `cooccurrence_values` across matrices.
"""
function cooccurrence_values(coocs::AbstractVector{<:AbstractChordData})
    vcat((cooccurrence_values(c) for c in coocs)...)
end

function cooccurrence_values(cooc::CoOccurrenceLayers)
    n, _, nL = size(cooc.layers)
    vals = Float64[]
    for j in 2:n
        for i in 1:(j - 1)
            for k in 1:nL
                v = cooc.layers[i, j, k]
                v > 0 && push!(vals, Float64(v))
            end
        end
    end
    vals
end

