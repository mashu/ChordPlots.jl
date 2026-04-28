# src/value_utils.jl
# Lightweight helpers for inspecting value distributions (no semantics enforced).

"""
    cooccurrence_values(cooc::AbstractChordData) -> Vector{Float64}

Return the non-zero upper-triangle values (each pair counted once). Signed values
are kept as-is (so a histogram of a diff matrix shows positive and negative bars);
exact zeros are dropped because they correspond to absent links.

Use this together with [`value_histogram`](@ref) to choose a threshold such as
`min_ribbon_value` (which is itself a magnitude threshold — `abs(value) >= threshold`).
"""
function cooccurrence_values(cooc::AbstractChordData)
    n = nlabels(cooc)
    vals = Float64[]
    @inbounds for j in 2:n
        for i in 1:(j - 1)
            v = Float64(cooc.matrix[i, j])
            v != 0.0 && push!(vals, v)
        end
    end
    vals
end

"""
    cooccurrence_values(coocs::AbstractVector{<:AbstractChordData}) -> Vector{Float64}

Concatenate `cooccurrence_values` across multiple matrices.
"""
function cooccurrence_values(coocs::AbstractVector{<:AbstractChordData})
    vcat((cooccurrence_values(c) for c in coocs)...)
end

function cooccurrence_values(cooc::CoOccurrenceLayers)
    n, _, nL = size(cooc.layers)
    vals = Float64[]
    @inbounds for j in 2:n
        for i in 1:(j - 1)
            for k in 1:nL
                v = Float64(cooc.layers[i, j, k])
                v != 0.0 && push!(vals, v)
            end
        end
    end
    vals
end

