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
- `normalize::Bool=false`: If true, normalize counts to frequencies

# Returns
- `CoOccurrenceMatrix`: Matrix of co-occurrence counts/frequencies

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
    filter_by_threshold(cooc::CoOccurrenceMatrix{T, S}, min_value::T) where {T, S}

Create a new CoOccurrenceMatrix with values below threshold set to zero.
"""
function filter_by_threshold(cooc::CoOccurrenceMatrix{T, S}, min_value::T) where {T, S}
    filtered = copy(cooc.matrix)
    filtered[filtered .< min_value] .= zero(T)
    CoOccurrenceMatrix(filtered, copy(cooc.labels), copy(cooc.groups))
end

"""
    filter_top_n(cooc::CoOccurrenceMatrix, n::Int)

Keep only the top n labels by total flow.
"""
function filter_top_n(cooc::CoOccurrenceMatrix{T, S}, n::Int) where {T, S}
    flows = [total_flow(cooc, i) for i in 1:nlabels(cooc)]
    top_indices = partialsortperm(flows, 1:min(n, length(flows)), rev=true)
    
    new_matrix = cooc.matrix[top_indices, top_indices]
    new_labels = cooc.labels[top_indices]
    
    # Rebuild groups with only remaining labels
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
    
    CoOccurrenceMatrix(new_matrix, new_labels, new_groups)
end

"""
    normalize(cooc::CoOccurrenceMatrix{T, S}) where {T, S}

Return a normalized version where all values sum to 1.
"""
function normalize(cooc::CoOccurrenceMatrix{T, S}) where {T, S}
    total = sum(cooc.matrix)
    if total > 0
        normalized = cooc.matrix ./ total
        CoOccurrenceMatrix(normalized, copy(cooc.labels), copy(cooc.groups))
    else
        cooc
    end
end
