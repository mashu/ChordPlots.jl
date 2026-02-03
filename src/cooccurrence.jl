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
    _filter_top_n(cooc, n, CoOccurrenceMatrix)
end
function filter_top_n(cooc::NormalizedCoOccurrenceMatrix{T, S}, n::Int) where {T, S}
    _filter_top_n(cooc, n, NormalizedCoOccurrenceMatrix)
end
function _filter_top_n(cooc::AbstractChordData, n::Int, out_type::Type{<:AbstractChordData})
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

"""
    mean_normalized(coocs::AbstractVector{<:AbstractChordData}) -> NormalizedCoOccurrenceMatrix

Combine multiple co-occurrence matrices (e.g. one per donor/sample) by normalizing
each matrix by its **own total sum** (so each sums to 1), then taking the
element-wise mean of these normalized matrices. All inputs must have the same
labels and groups (in the same order). The result sums to 1.
"""
function mean_normalized(coocs::AbstractVector{<:AbstractChordData})
    isempty(coocs) && throw(ArgumentError("mean_normalized requires at least one matrix"))
    first_cooc = coocs[1]
    labels = first_cooc.labels
    groups = first_cooc.groups
    n = length(labels)
    for c in coocs
        c.labels == labels || throw(ArgumentError("mean_normalized: all matrices must have the same labels in the same order"))
        size(c.matrix) == (n, n) || throw(DimensionMismatch("mean_normalized: all matrices must be $n×$n"))
    end
    acc = zeros(Float64, n, n)
    for c in coocs
        total = sum(c.matrix)
        if total > 0
            acc .+= c.matrix ./ total
        end
    end
    acc ./= length(coocs)
    NormalizedCoOccurrenceMatrix(acc, copy(labels), copy(groups); check_sum=true)
end
