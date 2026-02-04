# src/cooccurrence.jl
# Functions to compute co-occurrence matrices from DataFrames

using DataFrames

#==============================================================================#
# DataFrame to CoOccurrenceMatrix Conversion
#==============================================================================#

"""
    cooccurrence_matrix(df::DataFrame, columns::Vector{Symbol}; normalize=false)

Compute a co-occurrence matrix from a DataFrame.

Each row in the DataFrame represents one observation. Labels from different
columns that appear in the same row are considered co-occurring.

# Arguments
- `df::DataFrame`: Input data
- `columns::Vector{Symbol}`: Column names to analyze

# Keywords
- `normalize::Bool=false`: If true, normalize counts so matrix sums to 1 (frequencies)

# Returns
- `CoOccurrenceMatrix`: Matrix of co-occurrence counts or frequencies

# Note on normalized / combined data
The matrix can hold raw counts or proportions. To combine multiple donors/samples,
normalize each by its own total sum then take the element-wise mean — use
[`mean_normalized`](@ref). Layout uses only relative magnitudes; set
`min_ribbon_value` and `min_arc_flow` to match your scale (e.g. small for proportions).

# Example
```julia
df = DataFrame(
    V_call = ["IGHV1-2*01", "IGHV1-2*01", "IGHV3-23*01"],
    D_call = ["IGHD2-2*01", "IGHD3-10*01", "IGHD2-2*01"],
    J_call = ["IGHJ6*01", "IGHJ6*01", "IGHJ4*02"]
)
cooc = cooccurrence_matrix(df, [:V_call, :D_call, :J_call])
```
"""
function cooccurrence_matrix(
    df::DataFrame,
    columns::Vector{Symbol};
    normalize::Bool = false
)
    # Extract unique labels per column and build groups
    groups = GroupInfo{String}[]
    all_labels = String[]
    current_idx = 1
    
    for col in columns
        col_labels = unique(skipmissing(df[!, col]))
        col_labels_str = string.(col_labels)
        sort!(col_labels_str)  # Consistent ordering
        
        n = length(col_labels_str)
        indices = current_idx:(current_idx + n - 1)
        push!(groups, GroupInfo{String}(col, col_labels_str, indices))
        append!(all_labels, col_labels_str)
        current_idx += n
    end
    
    n_labels = length(all_labels)
    label_to_idx = Dict(l => i for (i, l) in enumerate(all_labels))
    
    # Build co-occurrence matrix
    counts = zeros(Int, n_labels, n_labels)
    
    for row in eachrow(df)
        # Get indices of all labels in this row
        row_indices = Int[]
        for col in columns
            val = row[col]
            if !ismissing(val)
                label = string(val)
                if haskey(label_to_idx, label)
                    push!(row_indices, label_to_idx[label])
                end
            end
        end
        
        # Increment co-occurrence for all pairs (excluding self-pairs i == j)
        for i in row_indices
            for j in row_indices
                if i != j  # Skip diagonal - labels don't co-occur with themselves
                    counts[i, j] += 1
                end
            end
        end
    end
    
    # Make symmetric (should already be, but ensure)
    counts = (counts + counts') .÷ 2
    
    if normalize
        total = sum(counts)
        if total > 0
            matrix = counts ./ total
            return CoOccurrenceMatrix(matrix, all_labels, groups)
        end
    end
    
    CoOccurrenceMatrix(counts, all_labels, groups)
end

# Convenience method for column names as strings
function cooccurrence_matrix(df::DataFrame, columns::Vector{String}; kwargs...)
    cooccurrence_matrix(df, Symbol.(columns); kwargs...)
end

#==============================================================================#
# Direct Matrix Construction
#==============================================================================#

"""
    CoOccurrenceMatrix(matrix::Matrix, labels::Vector{String}, group_names::Vector{Symbol}, group_sizes::Vector{Int})

Construct a CoOccurrenceMatrix from raw components.

# Arguments
- `matrix`: Square co-occurrence matrix
- `labels`: Label names (must match matrix dimensions)
- `group_names`: Names for each group
- `group_sizes`: Number of labels in each group (must sum to length(labels))
"""
function CoOccurrenceMatrix(
    matrix::Matrix{T},
    labels::Vector{S},
    group_names::Vector{Symbol},
    group_sizes::Vector{Int}
) where {T<:Real, S<:AbstractString}
    length(group_names) == length(group_sizes) || throw(ArgumentError(
        "group_names and group_sizes must have same length"
    ))
    sum(group_sizes) == length(labels) || throw(ArgumentError(
        "group_sizes must sum to number of labels"
    ))
    
    groups = GroupInfo{S}[]
    idx = 1
    for (name, size) in zip(group_names, group_sizes)
        group_labels = labels[idx:idx+size-1]
        push!(groups, GroupInfo{S}(name, group_labels, idx:idx+size-1))
        idx += size
    end
    
    CoOccurrenceMatrix(matrix, labels, groups)
end

#==============================================================================#
# Utility Functions
#==============================================================================#

"""
    filter_by_threshold(cooc::AbstractChordData, min_value)

Create a new matrix with values below threshold set to zero. Returns the same type as `cooc`.
"""
function filter_by_threshold(cooc::CoOccurrenceMatrix{T, S}, min_value::T) where {T, S}
    filtered = copy(cooc.matrix)
    filtered[filtered .< min_value] .= zero(T)
    CoOccurrenceMatrix(filtered, copy(cooc.labels), copy(cooc.groups))
end
function filter_by_threshold(cooc::NormalizedCoOccurrenceMatrix{T, S}, min_value::T) where {T, S}
    filtered = copy(cooc.matrix)
    filtered[filtered .< min_value] .= zero(T)
    NormalizedCoOccurrenceMatrix(filtered, copy(cooc.labels), copy(cooc.groups); check_sum=false)
end

"""
    filter_top_n(cooc::AbstractChordData, n::Int)

Keep only the top n labels by total flow. Returns the same type as `cooc`.
"""
function filter_top_n(cooc::CoOccurrenceMatrix{T, S}, n::Int) where {T, S}
    filter_top_n_impl(cooc, n, CoOccurrenceMatrix)
end
function filter_top_n(cooc::NormalizedCoOccurrenceMatrix{T, S}, n::Int) where {T, S}
    filter_top_n_impl(cooc, n, NormalizedCoOccurrenceMatrix)
end
function filter_top_n_impl(cooc::AbstractChordData, n::Int, out_type::Type{<:AbstractChordData})
    S = eltype(cooc.labels)
    flows = [total_flow(cooc, i) for i in 1:nlabels(cooc)]
    top_indices = partialsortperm(flows, 1:min(n, length(flows)), rev=true)
    new_matrix = cooc.matrix[top_indices, top_indices]
    new_labels = cooc.labels[top_indices]
    new_groups = GroupInfo{S}[]
    idx = 1
    for g in cooc.groups
        group_mask = [i in g.indices for i in top_indices]
        remaining = new_labels[group_mask]
        if !isempty(remaining)
            n_remaining = length(remaining)
            push!(new_groups, GroupInfo{S}(g.name, remaining, idx:idx+n_remaining-1))
            idx += n_remaining
        end
    end
    if out_type == NormalizedCoOccurrenceMatrix
        NormalizedCoOccurrenceMatrix(new_matrix, new_labels, new_groups; check_sum=false)
    else
        CoOccurrenceMatrix(new_matrix, new_labels, new_groups)
    end
end

"""
    normalize(cooc::CoOccurrenceMatrix) -> NormalizedCoOccurrenceMatrix

Return a normalized version where all values sum to 1. Use for comparing
matrices from different sample sizes or before combining multiple sources.
"""
function normalize(cooc::CoOccurrenceMatrix{T, S}) where {T, S}
    total = sum(cooc.matrix)
    if total > 0
        normalized = cooc.matrix ./ total
        NormalizedCoOccurrenceMatrix(normalized, copy(cooc.labels), copy(cooc.groups); check_sum=true)
    else
        # Return normalized type with zeros (avoid returning unnormalized type)
        NormalizedCoOccurrenceMatrix(copy(cooc.matrix), copy(cooc.labels), copy(cooc.groups); check_sum=false)
    end
end

"""
    normalize(cooc::NormalizedCoOccurrenceMatrix)

Return copy unchanged (already normalized).
"""
normalize(cooc::NormalizedCoOccurrenceMatrix) = NormalizedCoOccurrenceMatrix(
    copy(cooc.matrix), copy(cooc.labels), copy(cooc.groups); check_sum=false
)

# Union of labels across matrices: all labels from all coocs are kept (no discarding).
# Group order from first cooc; within each group, union of labels, sorted.
function union_labels_and_groups(coocs::AbstractVector{<:AbstractChordData})
    isempty(coocs) && throw(ArgumentError("at least one matrix required"))
    first_cooc = coocs[1]
    group_names = [g.name for g in first_cooc.groups]
    union_labels = String[]
    new_groups = GroupInfo{String}[]
    idx = 1
    for gname in group_names
        labels_in_group = Set{String}()
        for c in coocs
            for g in c.groups
                if g.name == gname
                    for l in g.labels
                        push!(labels_in_group, l)
                    end
                    break
                end
            end
        end
        sorted_labels = sort(collect(labels_in_group))
        n_here = length(sorted_labels)
        push!(new_groups, GroupInfo{String}(gname, sorted_labels, idx:(idx + n_here - 1)))
        append!(union_labels, sorted_labels)
        idx += n_here
    end
    (union_labels, new_groups)
end

function expand_cooc_to_canonical(cooc::AbstractChordData, canonical_labels::Vector{String}, canonical_groups::Vector{GroupInfo{String}})
    n = length(canonical_labels)
    to_cooc = zeros(Int, n)
    for (i, l) in enumerate(canonical_labels)
        to_cooc[i] = get(cooc.label_to_index, l, 0)
    end
    mat = zeros(Float64, n, n)
    for i in 1:n
        ii = to_cooc[i]
        for j in 1:n
            jj = to_cooc[j]
            if ii > 0 && jj > 0
                mat[i, j] = cooc.matrix[ii, jj]
            end
        end
    end
    CoOccurrenceMatrix(mat, copy(canonical_labels), copy(canonical_groups))
end

"""
    expand_labels(coocs::AbstractVector{<:AbstractChordData}) -> Vector{AbstractChordData}

Expand all matrices to a common label set (union of all labels per group). Labels not
present in a matrix get zero flow/connections. Use this when you want to plot multiple
matrices with the **same labels appearing in the same positions**, even if some matrices
are missing certain labels.

Returns matrices of the same type as input (CoOccurrenceMatrix or NormalizedCoOccurrenceMatrix).

# Example
```julia
# Two matrices with different genes
cooc_A = cooccurrence_matrix(df_A, [:V_call, :J_call])
cooc_B = cooccurrence_matrix(df_B, [:V_call, :J_call])

# Expand to union of labels (missing labels get zero flow → empty arcs)
expanded_A, expanded_B = expand_labels([cooc_A, cooc_B])

# Now both have the same labels; plot with consistent positions
order = label_order(expanded_A)  # or label_order(expanded_B) — same labels
chordplot!(ax1, expanded_A; label_order = order)
chordplot!(ax2, expanded_B; label_order = order)
```
"""
function expand_labels(coocs::AbstractVector{<:AbstractChordData})
    isempty(coocs) && return AbstractChordData[]
    canonical_labels, canonical_groups = union_labels_and_groups(coocs)
    result = AbstractChordData[]
    for c in coocs
        expanded = expand_cooc_to_canonical(c, canonical_labels, canonical_groups)
        # Preserve type: if input was NormalizedCoOccurrenceMatrix, convert back
        if c isa NormalizedCoOccurrenceMatrix
            push!(result, NormalizedCoOccurrenceMatrix(expanded.matrix, expanded.labels, expanded.groups; check_sum=false))
        else
            push!(result, expanded)
        end
    end
    result
end

# Varargs convenience
expand_labels(cooc1::AbstractChordData, coocs::AbstractChordData...) = expand_labels([cooc1, coocs...])

"""
    mean_normalized(coocs::AbstractVector{<:AbstractChordData}) -> NormalizedCoOccurrenceMatrix

Combine multiple co-occurrence matrices by normalizing each by its own total sum
and taking the element-wise mean. Result sums to 1. Matrices may have different
labels; they are aligned to the union of all labels (per group), missing entries as zero.
"""
function mean_normalized(coocs::AbstractVector{<:AbstractChordData})
    isempty(coocs) && throw(ArgumentError("mean_normalized requires at least one matrix"))
    canonical_labels, canonical_groups = union_labels_and_groups(coocs)
    aligned = [expand_cooc_to_canonical(c, canonical_labels, canonical_groups) for c in coocs]
    n = length(canonical_labels)
    acc = zeros(Float64, n, n)
    for c in aligned
        total = sum(c.matrix)
        if total > 0
            acc .+= c.matrix ./ total
        end
    end
    acc ./= length(aligned)
    NormalizedCoOccurrenceMatrix(acc, copy(canonical_labels), copy(canonical_groups); check_sum=true)
end

#------------------------------------------------------------------------------
# Value distribution (for threshold choice)
#------------------------------------------------------------------------------

"""
    cooccurrence_values(cooc::AbstractChordData) -> Vector{Float64}

Return the upper-triangle co-occurrence values (each pair counted once).
Use with `histogram(cooccurrence_values(cooc))` to inspect the distribution and choose `min_ribbon_value`.
"""
function cooccurrence_values(cooc::AbstractChordData)
    n = nlabels(cooc)
    vals = Float64[]
    for j in 2:n
        for i in 1:(j-1)
            v = cooc.matrix[i, j]
            v > 0 && push!(vals, Float64(v))
        end
    end
    vals
end

"""
    cooccurrence_values(coocs::AbstractVector{<:AbstractChordData}) -> Vector{Float64}

Concatenate co-occurrence values from all matrices. Use to plot the combined distribution
when choosing a threshold across multiple donors/samples.
"""
function cooccurrence_values(coocs::AbstractVector{<:AbstractChordData})
    vcat((cooccurrence_values(c) for c in coocs)...)
end
