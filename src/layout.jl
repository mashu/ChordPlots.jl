# src/layout.jl
# Layout algorithms for chord diagrams

#==============================================================================#
# Layout Computation
#==============================================================================#

"""
    LayoutConfig{T<:Real}

Configuration for layout computation.

# Fields
- `inner_radius::T`: Inner radius for ribbon attachment
- `outer_radius::T`: Outer radius for arcs
- `gap_fraction::T`: Fraction of circle to use for gaps between arcs
- `start_angle::T`: Starting angle (0 = right, π/2 = top)
- `direction::Int`: 1 for counterclockwise, -1 for clockwise
- `sort_by::Symbol`: How to sort arcs (:group, :value, :none)
"""
struct LayoutConfig{T<:Real}
    inner_radius::T
    outer_radius::T
    gap_fraction::T
    start_angle::T
    direction::Int
    sort_by::Symbol
end

# Default constructor with Float64 type
function LayoutConfig(;
    inner_radius::Real = 0.92,  # Closer to outer_radius to reduce wasted space
    outer_radius::Real = 1.0,
    gap_fraction::Real = 0.05,
    start_angle::Real = π/2,
    direction::Int = 1,
    sort_by::Symbol = :group
)
    LayoutConfig{Float64}(
        Float64(inner_radius),
        Float64(outer_radius),
        Float64(gap_fraction),
        Float64(start_angle),
        direction,
        sort_by
    )
end

"""
    compute_layout(cooc::CoOccurrenceMatrix{T, S}, config::LayoutConfig=LayoutConfig()) where {T, S}

Compute the complete layout for a chord diagram.

# Algorithm
1. Calculate total flow for each label
2. Allocate angular width proportional to flow
3. Assign arc positions
4. Generate ribbon endpoints based on co-occurrence values
"""
function compute_layout(
    cooc::CoOccurrenceMatrix{T, S},
    config::LayoutConfig = LayoutConfig()
) where {T, S}
    
    n = nlabels(cooc)
    
    # Calculate total flow per label
    flows = [total_flow(cooc, i) for i in 1:n]
    total_flow_sum = sum(flows)
    
    if total_flow_sum ≤ 0
        error("Co-occurrence matrix has no positive values")
    end
    
    # Available angle for content (excluding gaps)
    n_gaps = n  # Gap after each arc
    total_gap = 2π * config.gap_fraction
    gap_size = total_gap / n_gaps
    content_angle = 2π - total_gap
    
    # Sort indices based on configuration
    order = _get_sort_order(cooc, flows, config.sort_by)
    
    # Compute arc positions
    arcs = Vector{ArcSegment{Float64}}(undef, n)
    arc_angle_positions = Vector{Float64}(undef, n)  # Track consumed angle per arc
    
    current_angle = config.start_angle
    
    for idx in order
        flow = flows[idx]
        arc_width = content_angle * (flow / total_flow_sum)
        
        start_angle = current_angle
        end_angle = current_angle + config.direction * arc_width
        
        arcs[idx] = ArcSegment{Float64}(
            idx,
            min(start_angle, end_angle),
            max(start_angle, end_angle),
            Float64(flow)
        )
        arc_angle_positions[idx] = 0.0  # Start ribbon allocation at arc start
        
        current_angle = end_angle + config.direction * gap_size
    end
    
    # Compute ribbon positions
    ribbons = _compute_ribbons(cooc, arcs, arc_angle_positions)
    
    ChordLayout{Float64}(
        arcs,
        ribbons,
        Float64(config.inner_radius),
        Float64(config.outer_radius),
        Float64(gap_size)
    )
end

"""
    _get_sort_order(cooc, flows, sort_by::Symbol) -> Vector{Int}

Determine the order in which to place arcs.
"""
function _get_sort_order(
    cooc::CoOccurrenceMatrix,
    flows::Vector{<:Real},
    sort_by::Symbol
)::Vector{Int}
    n = nlabels(cooc)
    
    if sort_by == :none
        return collect(1:n)
    elseif sort_by == :value
        return sortperm(flows, rev=true)
    elseif sort_by == :group
        # Keep groups together, sort within groups by value
        order = Int[]
        for group in cooc.groups
            group_flows = [(i, flows[i]) for i in group.indices]
            sort!(group_flows, by=x -> -x[2])  # Descending by flow
            append!(order, [x[1] for x in group_flows])
        end
        return order
    else
        error("Unknown sort_by option: $sort_by")
    end
end

"""
    _compute_ribbons(cooc, arcs, arc_positions) -> Vector{Ribbon{Float64}}

Compute ribbon endpoints. Each ribbon connects two labels based on co-occurrence.

The ribbon width on each end is proportional to the co-occurrence value relative
to that label's total flow.
"""
function _compute_ribbons(
    cooc::CoOccurrenceMatrix{T, S},
    arcs::Vector{ArcSegment{Float64}},
    arc_positions::Vector{Float64}
)::Vector{Ribbon{Float64}} where {T, S}
    
    n = nlabels(cooc)
    ribbons = Ribbon{Float64}[]
    
    # Track current position within each arc
    positions = copy(arc_positions)
    
    # Process upper triangle of matrix (i < j) - skip diagonal (no self-loops)
    for i in 1:n
        for j in (i+1):n  # Start from i+1 to skip diagonal
            value = cooc[i, j]
            if value > 0
                # Source endpoint on arc i
                src_arc = arcs[i]
                src_arc_span = arc_span(src_arc)
                src_flow = src_arc.value
                
                # Width proportional to this connection vs total flow
                src_width = src_arc_span * (value / src_flow)
                src_start = src_arc.start_angle + positions[i]
                src_end = src_start + src_width
                positions[i] += src_width
                
                # Target endpoint on arc j
                tgt_arc = arcs[j]
                tgt_arc_span = arc_span(tgt_arc)
                tgt_flow = tgt_arc.value
                
                tgt_width = tgt_arc_span * (value / tgt_flow)
                tgt_start = tgt_arc.start_angle + positions[j]
                tgt_end = tgt_start + tgt_width
                positions[j] += tgt_width
                
                src_endpoint = RibbonEndpoint{Float64}(i, src_start, src_end)
                tgt_endpoint = RibbonEndpoint{Float64}(j, tgt_start, tgt_end)
                
                push!(ribbons, Ribbon{Float64}(src_endpoint, tgt_endpoint, Float64(value)))
            end
        end
    end
    
    ribbons
end

#==============================================================================#
# Layout Utilities
#==============================================================================#

"""
    filter_ribbons(layout::ChordLayout, min_value::Real)

Filter ribbons below a minimum value threshold.
"""
function filter_ribbons(layout::ChordLayout{T}, min_value::Real) where T
    filtered = filter(r -> r.value >= min_value, layout.ribbons)
    ChordLayout{T}(
        layout.arcs,
        filtered,
        layout.inner_radius,
        layout.outer_radius,
        layout.gap_angle
    )
end

"""
    filter_ribbons_top_n(layout::ChordLayout, n::Int)

Keep only the top n ribbons by value.
"""
function filter_ribbons_top_n(layout::ChordLayout{T}, n::Int) where T
    sorted = sort(layout.ribbons, by=r -> r.value, rev=true)
    filtered = sorted[1:min(n, length(sorted))]
    ChordLayout{T}(
        layout.arcs,
        filtered,
        layout.inner_radius,
        layout.outer_radius,
        layout.gap_angle
    )
end
