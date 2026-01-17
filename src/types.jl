# src/types.jl
# Core data types for ChordPlots with parametric types for compile-time type stability

"""
    AbstractChordData

Abstract supertype for all chord data representations.
Enables multiple dispatch for different data sources.
"""
abstract type AbstractChordData end

"""
    AbstractLayout

Abstract supertype for layout computation results.
"""
abstract type AbstractLayout end

"""
    AbstractGeometry

Abstract supertype for geometric primitives used in rendering.
"""
abstract type AbstractGeometry end

#==============================================================================#
# Co-occurrence Data Types
#==============================================================================#

"""
    GroupInfo{S<:AbstractString}

Information about a group of labels (e.g., V calls, D calls, J calls).

# Fields
- `name::Symbol`: Group identifier
- `labels::Vector{S}`: Labels belonging to this group
- `indices::UnitRange{Int}`: Index range in the combined label list
"""
struct GroupInfo{S<:AbstractString}
    name::Symbol
    labels::Vector{S}
    indices::UnitRange{Int}
end

Base.length(g::GroupInfo) = length(g.labels)
Base.iterate(g::GroupInfo, state=1) = state > length(g) ? nothing : (g.labels[state], state + 1)

"""
    CoOccurrenceMatrix{T<:Real, S<:AbstractString}

Stores co-occurrence counts between labels with group information.

# Type Parameters
- `T`: Numeric type for counts (enables Integer or Float)
- `S`: String type for labels

# Fields
- `matrix::Matrix{T}`: Symmetric co-occurrence matrix
- `labels::Vector{S}`: Combined list of all labels
- `groups::Vector{GroupInfo{S}}`: Group information
- `label_to_index::Dict{S, Int}`: Fast label lookup

# Example
```julia
cooc = CoOccurrenceMatrix(df, [:V_call, :D_call, :J_call])
cooc["IGHV1-2*01", "IGHD2-2*01"]  # Get co-occurrence count
```
"""
struct CoOccurrenceMatrix{T<:Real, S<:AbstractString} <: AbstractChordData
    matrix::Matrix{T}
    labels::Vector{S}
    groups::Vector{GroupInfo{S}}
    label_to_index::Dict{S, Int}
    
    function CoOccurrenceMatrix{T, S}(
        matrix::Matrix{T},
        labels::Vector{S},
        groups::Vector{GroupInfo{S}}
    ) where {T<:Real, S<:AbstractString}
        n = length(labels)
        size(matrix) == (n, n) || throw(DimensionMismatch(
            "Matrix size $(size(matrix)) doesn't match label count $n"
        ))
        
        label_to_index = Dict{S, Int}(l => i for (i, l) in enumerate(labels))
        new{T, S}(matrix, labels, groups, label_to_index)
    end
end

# Convenience constructor with type inference
function CoOccurrenceMatrix(
    matrix::Matrix{T},
    labels::Vector{S},
    groups::Vector{GroupInfo{S}}
) where {T<:Real, S<:AbstractString}
    CoOccurrenceMatrix{T, S}(matrix, labels, groups)
end

# Accessors
Base.size(c::CoOccurrenceMatrix) = size(c.matrix)
Base.length(c::CoOccurrenceMatrix) = length(c.labels)
nlabels(c::CoOccurrenceMatrix) = length(c.labels)
ngroups(c::CoOccurrenceMatrix) = length(c.groups)

# Indexing by label names
function Base.getindex(c::CoOccurrenceMatrix{T, S}, label1::S, label2::S) where {T, S}
    i = c.label_to_index[label1]
    j = c.label_to_index[label2]
    c.matrix[i, j]
end

# Indexing by integers
Base.getindex(c::CoOccurrenceMatrix, i::Int, j::Int) = c.matrix[i, j]

# Get total flow for a label (sum of all connections)
function total_flow(c::CoOccurrenceMatrix, label_idx::Int)
    sum(@view c.matrix[label_idx, :])
end

function total_flow(c::CoOccurrenceMatrix{T, S}, label::S) where {T, S}
    total_flow(c, c.label_to_index[label])
end

# Get group for a label
function get_group(c::CoOccurrenceMatrix, label_idx::Int)::Symbol
    for g in c.groups
        if label_idx in g.indices
            return g.name
        end
    end
    error("Label index $label_idx not found in any group")
end

#==============================================================================#
# Geometry Types
#==============================================================================#

"""
    ArcSegment{T<:Real}

Represents an arc on the outer circle for a single label.

# Fields
- `label_idx::Int`: Index into the label array
- `start_angle::T`: Starting angle in radians
- `end_angle::T`: Ending angle in radians  
- `value::T`: Total flow value (determines arc width)
"""
struct ArcSegment{T<:Real} <: AbstractGeometry
    label_idx::Int
    start_angle::T
    end_angle::T
    value::T
end

arc_span(a::ArcSegment) = a.end_angle - a.start_angle
arc_midpoint(a::ArcSegment) = (a.start_angle + a.end_angle) / 2

"""
    RibbonEndpoint{T<:Real}

Represents one end of a ribbon attached to an arc.

# Fields
- `label_idx::Int`: Which label this endpoint is on
- `start_angle::T`: Start angle on the arc
- `end_angle::T`: End angle on the arc
"""
struct RibbonEndpoint{T<:Real}
    label_idx::Int
    start_angle::T
    end_angle::T
end

endpoint_span(e::RibbonEndpoint) = e.end_angle - e.start_angle
endpoint_midpoint(e::RibbonEndpoint) = (e.start_angle + e.end_angle) / 2

"""
    Ribbon{T<:Real}

Represents a ribbon connecting two labels.

# Fields
- `source::RibbonEndpoint{T}`: Source endpoint
- `target::RibbonEndpoint{T}`: Target endpoint
- `value::T`: Co-occurrence value
"""
struct Ribbon{T<:Real} <: AbstractGeometry
    source::RibbonEndpoint{T}
    target::RibbonEndpoint{T}
    value::T
end

# Self-loop detection
is_self_loop(r::Ribbon) = r.source.label_idx == r.target.label_idx

#==============================================================================#
# Layout Types
#==============================================================================#

"""
    ChordLayout{T<:Real}

Complete layout information for rendering a chord diagram.

# Fields
- `arcs::Vector{ArcSegment{T}}`: Arc segments for each label
- `ribbons::Vector{Ribbon{T}}`: All ribbons
- `inner_radius::T`: Inner radius for ribbons
- `outer_radius::T`: Outer radius for arcs
- `gap_angle::T`: Gap between adjacent arcs
"""
struct ChordLayout{T<:Real} <: AbstractLayout
    arcs::Vector{ArcSegment{T}}
    ribbons::Vector{Ribbon{T}}
    inner_radius::T
    outer_radius::T
    gap_angle::T
end

narcs(l::ChordLayout) = length(l.arcs)
nribbons(l::ChordLayout) = length(l.ribbons)

#==============================================================================#
# Style Configuration
#==============================================================================#

"""
    ChordStyle

Configuration for chord diagram appearance.

# Fields
- `arc_width::Float64`: Width of outer arcs
- `label_offset::Float64`: Distance from arc to label
- `label_fontsize::Float64`: Font size for labels
- `ribbon_alpha::Float64`: Transparency for ribbons
- `show_labels::Bool`: Whether to display labels
- `rotate_labels::Bool`: Rotate labels to follow arc
"""
Base.@kwdef struct ChordStyle
    arc_width::Float64 = 0.05
    label_offset::Float64 = 0.1
    label_fontsize::Float64 = 10.0
    ribbon_alpha::Float64 = 0.6
    show_labels::Bool = true
    rotate_labels::Bool = true
end
