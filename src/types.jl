# src/types.jl
# Core data types for ChordPlots with parametric types for compile-time type stability

using Statistics

"""
    AbstractChordData

Abstract supertype for chord data.

All subtypes must have fields: `matrix`, `labels`, `groups`, `label_to_index`.
Use `CoOccurrenceMatrix` for a single weight matrix, or `CoOccurrenceLayers` for
one layer per condition (e.g. donor) with shared geometry and per-layer overdrawn ribbons.
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

# Dictionary-like access: map a label in this group to its global index.
#
# Note: `indices` must align with `labels` (same length, same order).
function Base.getindex(g::GroupInfo, label::AbstractString)::Int
    length(g.indices) == length(g.labels) || throw(ArgumentError(
        "GroupInfo indices must align with labels (got $(length(g.indices)) indices, $(length(g.labels)) labels)"
    ))
    pos = findfirst(==(label), g.labels)
    pos === nothing && throw(KeyError(label))
    first(g.indices) + (pos - 1)
end

Base.haskey(g::GroupInfo, label::AbstractString)::Bool = findfirst(==(label), g.labels) !== nothing
Base.keys(g::GroupInfo) = g.labels
Base.get(g::GroupInfo, label::AbstractString, default) = haskey(g, label) ? g[label] : default

"""
    CoOccurrenceMatrix{T<:Real, S<:AbstractString}

Stores co-occurrence counts between labels with group information.

# Type Parameters
- `T`: Numeric type for counts (enables Integer or Float)
- `S`: String type for labels

# Fields
- `matrix::AbstractMatrix{T}`: Symmetric weight matrix (dense or sparse; counts, frequencies, scores, etc.)
- `labels::Vector{S}`: Combined list of all labels
- `groups::Vector{GroupInfo{S}}`: Group information
- `label_to_index::Dict{S, Int}`: Fast label lookup

# Example
```julia
cooc = CoOccurrenceMatrix(df, [:V_call, :D_call, :J_call])
cooc["IGHV1-2*01", "IGHD2-2*01"]  # Get co-occurrence count
```
"""
struct CoOccurrenceMatrix{T<:Real, S<:AbstractString, M<:AbstractMatrix{T}} <: AbstractChordData
    matrix::M
    labels::Vector{S}
    groups::Vector{GroupInfo{S}}
    label_to_index::Dict{S, Int}
    
    function CoOccurrenceMatrix{T, S}(
        matrix::M,
        labels::Vector{S},
        groups::Vector{GroupInfo{S}}
    ) where {T<:Real, S<:AbstractString, M<:AbstractMatrix{T}}
        n = length(labels)
        size(matrix) == (n, n) || throw(DimensionMismatch(
            "Matrix size $(size(matrix)) doesn't match label count $n"
        ))
        
        label_to_index = Dict{S, Int}(l => i for (i, l) in enumerate(labels))
        new{T, S, M}(matrix, labels, groups, label_to_index)
    end
end

# Convenience constructor with type inference
function CoOccurrenceMatrix(
    matrix::M,
    labels::Vector{S},
    groups::Vector{GroupInfo{S}}
) where {T<:Real, S<:AbstractString, M<:AbstractMatrix{T}}
    CoOccurrenceMatrix{T, S}(matrix, labels, groups)
end

"""
    CoOccurrenceLayers{T, S, A, M} <: AbstractChordData

Per-layer co-occurrence data: `layers[i, j, ℓ]` is the link strength between
labels *i* and *j* in layer *ℓ* (e.g. one layer per donor). The field `matrix`
is an **aggregate** across layers (by default **sum**; see `aggregate=` in the
constructor). It drives arc sizing/coloring (via `total_flow`) while ribbons
keep the per-layer values for color and width.

# Layout
Arcs are sized from the chosen aggregate `matrix` (`aggregate = :mean` / `:median` / `:sum`).
Ribbons are then laid out **per layer**, each starting from the same arc origin for a given
label, so multiple donors are directly comparable: donors differ by which links exist and
their values, but not by an arbitrary offset caused by stacking layers into a single arc
partition. Colors still use the layer’s signed value in `resolve_ribbon_color`.

Ribbons are drawn **separately** in layer order (standard alpha compositing). For
**overdrawn** look on similar geometry, use a **lower** base ribbon opacity
(e.g. `ComponentAlpha(ribbons = 0.35, ...)`) on **repeated** samples; for thin
slices, opaque ribbons are usually readable.
"""
struct CoOccurrenceLayers{T<:Real, S<:AbstractString, A<:AbstractArray{T,3}, M<:AbstractMatrix{T}} <:
       AbstractChordData
    layers::A
    matrix::M
    labels::Vector{S}
    groups::Vector{GroupInfo{S}}
    label_to_index::Dict{S, Int}

    function CoOccurrenceLayers(
        layers::A,
        matrix::M,
        labels::Vector{S},
        groups::Vector{GroupInfo{S}}
    ) where {T<:Real, S<:AbstractString, A<:AbstractArray{T,3}, M<:AbstractMatrix{T}}
        n, m, nL = size(layers)
        n == m || throw(DimensionMismatch("layers must be n×n×L, got size $(size(layers))"))
        n == length(labels) || throw(DimensionMismatch("layers first dimension and labels differ"))
        size(matrix) == (n, n) || throw(DimensionMismatch("matrix and layers disagree in size"))
        new{T, S, A, M}(layers, matrix, labels, groups, Dict{S,Int}(l => k for (k, l) in enumerate(labels)))
    end
end

function aggregate_layers(layers::AbstractArray{T,3}, aggregate::Symbol) where {T<:Real}
    n, m, L = size(layers)
    n == m || throw(DimensionMismatch("layers must be n×n×L, got size $(size(layers))"))
    aggregate in (:sum, :mean, :median) || throw(ArgumentError("aggregate must be :sum, :mean, or :median, got $aggregate"))
    out = zeros(T, n, n)
    if aggregate === :sum
        out .= dropdims(sum(layers, dims=3), dims=3)
        return out
    elseif aggregate === :mean
        out .= dropdims(sum(layers, dims=3), dims=3) ./ T(L)
        return out
    else
        @inbounds for i in 1:n, j in 1:n
            out[i, j] = median(@view layers[i, j, :])
        end
        return out
    end
end

function CoOccurrenceLayers(
    layers::A,
    labels::Vector{S},
    groups::Vector{GroupInfo{S}};
    aggregate::Symbol = :sum
) where {T<:Real, S<:AbstractString, A<:AbstractArray{T,3}}
    n, m, nL = size(layers)
    n == m || throw(DimensionMismatch("layers must be n×n×L, got size $(size(layers))"))
    nL ≥ 1 || throw(ArgumentError("layers must have a third dimension ≥ 1, got L=$nL"))
    n == length(labels) || throw(DimensionMismatch("Number of labels $(length(labels)) != n ($n)"))
    matrix = aggregate_layers(layers, aggregate)
    return CoOccurrenceLayers(layers, matrix, labels, groups)
end

#------------------------------------------------------------------------------
# Shared accessors for AbstractChordData
#------------------------------------------------------------------------------

Base.size(c::AbstractChordData) = size(c.matrix)
Base.length(c::AbstractChordData) = length(c.labels)
nlabels(c::AbstractChordData) = length(c.labels)
ngroups(c::AbstractChordData) = length(c.groups)

function Base.getindex(c::AbstractChordData, label1::AbstractString, label2::AbstractString)
    i = c.label_to_index[label1]
    j = c.label_to_index[label2]
    c.matrix[i, j]
end
Base.getindex(c::AbstractChordData, i::Int, j::Int) = c.matrix[i, j]

function total_flow(c::AbstractChordData, label_idx::Int)
    sum(@view c.matrix[label_idx, :])
end
function total_flow(c::AbstractChordData, label::AbstractString)
    total_flow(c, c.label_to_index[label])
end

"""
    abs_total_flow(c::AbstractChordData, label_idx::Int) -> Float64

Sum of absolute values in row `label_idx`. Use this for layout computation
when the matrix may contain negative values (e.g., from `diff()`).
"""
function abs_total_flow(c::AbstractChordData, label_idx::Int)
    sum(abs, @view c.matrix[label_idx, :])
end
function abs_total_flow(c::AbstractChordData, label::AbstractString)
    abs_total_flow(c, c.label_to_index[label])
end

"""
    n_layers(c::CoOccurrenceLayers) -> Int

Number of matrix layers (third index of `c.layers`, e.g. one per donor).
"""
n_layers(c::CoOccurrenceLayers) = size(c.layers, 3)

function abs_total_flow(c::CoOccurrenceLayers, label_idx::Int)
    sum(abs, @view c.matrix[label_idx, :])
end
function abs_total_flow(c::CoOccurrenceLayers, label::AbstractString)
    abs_total_flow(c, c.label_to_index[label])
end

function diverging_pairwise_ribbon_values(cooc::AbstractChordData)
    n = nlabels(cooc)
    vals = Float64[]
    for j in 2:n
        for i in 1:(j - 1)
            push!(vals, Float64(cooc.matrix[i, j]))
        end
    end
    vals
end

function diverging_pairwise_ribbon_values(cooc::CoOccurrenceLayers)
    n, _, nL = size(cooc.layers)
    vals = Float64[]
    for j in 2:n
        for i in 1:(j - 1)
            for ℓ in 1:nL
                push!(vals, Float64(cooc.layers[i, j, ℓ]))
            end
        end
    end
    vals
end

function get_group(c::AbstractChordData, label_idx::Int)::Symbol
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
# Opacity Configuration Types
#==============================================================================#

"""
    ComponentAlpha

Named opacity settings for chord diagram components. All values are clamped to [0, 1].

# Fields
- `ribbons::Float64`: Opacity for ribbons (connections)
- `arcs::Float64`: Opacity for arcs (outer segments)
- `labels::Float64`: Opacity for labels

# Constructors
- `ComponentAlpha(ribbons, arcs, labels)`: Set each component separately
- `ComponentAlpha(v)`: Set all components to the same value
- `ComponentAlpha((r, a, l))`: Construct from a tuple

# Example
```julia
# All components at 70% opacity
chordplot(cooc; alpha=ComponentAlpha(0.7))

# Semi-transparent ribbons, solid arcs and labels
chordplot(cooc; alpha=ComponentAlpha(0.5, 1.0, 1.0))

# Using named arguments for clarity
chordplot(cooc; alpha=ComponentAlpha(ribbons=0.5, arcs=1.0, labels=1.0))
```
"""
struct ComponentAlpha
    ribbons::Float64
    arcs::Float64
    labels::Float64
    
    function ComponentAlpha(ribbons::Real, arcs::Real, labels::Real)
        new(clamp(Float64(ribbons), 0.0, 1.0),
            clamp(Float64(arcs), 0.0, 1.0),
            clamp(Float64(labels), 0.0, 1.0))
    end
end

# Convenience constructors
ComponentAlpha(v::Real) = ComponentAlpha(v, v, v)
ComponentAlpha(t::Tuple{Real, Real, Real}) = ComponentAlpha(t[1], t[2], t[3])
ComponentAlpha(; ribbons::Real=1.0, arcs::Real=1.0, labels::Real=1.0) = 
    ComponentAlpha(ribbons, arcs, labels)

"""
    ValueScaling

Value-based opacity scaling. Each of ribbons, arcs, and labels is a **toggle**:
- **On** (true): opacity is scaled by value from `min_alpha` (weakest) to the component's base alpha from `alpha` (strongest).
- **Off** (false): opacity is the component's **base alpha** from `alpha` (fixed; no scaling). Use `alpha=ComponentAlpha(ribbons=0.6, arcs=0.8, labels=1)` for fixed per-component opacity when not scaling.

# Fields
- `enabled::Bool`: Master switch; when false, no component is scaled.
- `ribbons::Bool`: Toggle ribbon opacity by co-occurrence value.
- `arcs::Bool`: Toggle arc opacity by total flow.
- `labels::Bool`: Toggle label opacity by total flow.
- `min_alpha::Float64`: Minimum opacity when scaling (used only for components that are on).
- `scale::Symbol`: `:linear` or `:log` scaling.

# Components argument
`components` can be given as:
- **Named tuple** (recommended): `(ribbons=true, arcs=true, labels=false)` — order and meaning are clear.
- **Positional tuple**: `(ribbons, arcs, labels)` i.e. `(true, true, false)` in that order.

# Examples
```julia
# Scale all three by value
chordplot(cooc; alpha_by_value=ValueScaling(enabled=true))

# Scale ribbons and arcs only; labels fully opaque
chordplot(cooc; alpha_by_value=ValueScaling(
    enabled=true,
    components=(ribbons=true, arcs=true, labels=false),
    min_alpha=0.2
))

# Only ribbons scaled; arcs and labels at 1.0
chordplot(cooc; alpha_by_value=ValueScaling(enabled=true, components=(ribbons=true, arcs=false, labels=false)))
```
"""
struct ValueScaling
    enabled::Bool
    ribbons::Bool
    arcs::Bool
    labels::Bool
    min_alpha::Float64
    scale::Symbol
    
    function ValueScaling(enabled::Bool, ribbons::Bool, arcs::Bool, labels::Bool, 
                          min_alpha::Real, scale::Symbol)
        scale in (:linear, :log) || throw(ArgumentError("scale must be :linear or :log"))
        new(enabled, ribbons, arcs, labels, clamp(Float64(min_alpha), 0.0, 1.0), scale)
    end
end

# Normalize components to (ribbons, arcs, labels); accept named or positional tuple
function _components_tuple(c)
    if c isa NamedTuple
        haskey(c, :ribbons) && haskey(c, :arcs) && haskey(c, :labels) ||
            throw(ArgumentError("components as NamedTuple must have keys :ribbons, :arcs, :labels"))
        return (c.ribbons, c.arcs, c.labels)
    elseif c isa Tuple && length(c) == 3
        return (Bool(c[1]), Bool(c[2]), Bool(c[3]))
    else
        throw(ArgumentError("components must be (ribbons, arcs, labels) or (ribbons=..., arcs=..., labels=...)"))
    end
end

# Convenience constructors
function ValueScaling(;
    enabled::Bool = false,
    components = (true, true, true),
    min_alpha::Real = 0.1,
    scale::Symbol = :linear
)
    r, a, l = _components_tuple(components)
    ValueScaling(enabled, r, a, l, min_alpha, scale)
end

# When enabled=false, no component is scaled (all get 1.0). When enabled=true, scale all by default.
ValueScaling(enabled::Bool) = ValueScaling(
    enabled,
    enabled,  # ribbons
    enabled,  # arcs
    enabled,  # labels
    0.1,
    :linear
)

