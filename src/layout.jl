# src/layout.jl
# Layout algorithms for chord diagrams

#==============================================================================#
# Layout Computation
#==============================================================================#

"""
    LayoutConfig{T<:Real}

Configuration for layout computation. Parameters are grouped below; they work together and are non-conflicting.

# Fields (grouped)

## Radii
- `inner_radius::T`: Inner radius for ribbon attachment
- `outer_radius::T`: Outer radius for arcs

## Arc and gap layout (angle allocation)
- `gap_fraction::T`: Fraction of the full circle (2π) reserved for gaps between arcs (baseline)
- `arc_scale::T`: Scale for the arc (content) portion only. Content = (1 - gap_fraction)*arc_scale of 2π; rest is gap. Use < 1 for extra separation.

## Orientation
- `start_angle::T`: Starting angle (0 = right, π/2 = top)
- `direction::Int`: 1 = counterclockwise, -1 = clockwise

## Order
- `sort_by::Symbol`: How to order arcs (`:group`, `:value`, `:none`). Ignored when `label_order` is set.
- `label_order::Union{Nothing, Vector{Int}}`: If set, fixed order of label indices on the circle (overrides `sort_by`)

## Ribbon thickness
- `ribbon_width_power::T`: Exponent for ribbon width (value/flow)^power; > 1 makes thick vs thin more dramatic
"""
struct LayoutConfig{T<:Real}
    inner_radius::T
    outer_radius::T
    gap_fraction::T
    start_angle::T
    direction::Int
    sort_by::Symbol
    label_order::Union{Nothing, Vector{Int}}
    arc_scale::T
    ribbon_width_power::T
end

# Default constructor with Float64 type (kwargs grouped; struct field order unchanged)
function LayoutConfig(;
    # Radii
    inner_radius::Real = 0.92,
    outer_radius::Real = 1.0,
    # Arc and gap layout
    gap_fraction::Real = 0.05,
    arc_scale::Real = 1.0,
    # Orientation
    start_angle::Real = π/2,
    direction::Int = 1,
    # Order
    sort_by::Symbol = :group,
    label_order::Union{Nothing, Vector{Int}} = nothing,
    # Ribbon thickness
    ribbon_width_power::Real = 1.0
)
    LayoutConfig{Float64}(
        Float64(inner_radius),
        Float64(outer_radius),
        Float64(gap_fraction),
        Float64(start_angle),
        direction,
        sort_by,
        label_order,
        Float64(arc_scale),
        Float64(ribbon_width_power)
    )
end

"""
    compute_layout(cooc::AbstractChordData, config::LayoutConfig=LayoutConfig())

Compute the complete layout for a chord diagram.

# Algorithm
1. Calculate total flow for each label
2. Allocate angular width proportional to flow
3. Assign arc positions
4. Generate ribbon endpoints based on co-occurrence values
"""
function compute_layout(
    cooc::AbstractChordData,
    config::LayoutConfig = LayoutConfig()
)
    n = nlabels(cooc)
    
    # Calculate total flow per label
    flows = [total_flow(cooc, i) for i in 1:n]
    total_flow_sum = sum(flows)
    
    if total_flow_sum ≤ 0
        error("Co-occurrence matrix has no positive values")
    end
    
    # Angle allocation: gap_fraction reserves that fraction of 2π for gaps; arc_scale
    # then scales the remaining "content" (arc) portion so < 1 adds extra gap.
    # So: content_angle = (2π - 2π*gap_fraction) * arc_scale; total_gap = 2π - content_angle.
    n_gaps = n
    base_content = 2π * (1 - config.gap_fraction)
    content_angle = base_content * config.arc_scale
    total_gap = 2π - content_angle
    gap_size = total_gap / n_gaps
    
    # Sort indices based on configuration (label_order overrides sort_by when provided)
    order = get_sort_order(cooc, flows, config.sort_by, config.label_order)
    
    # Compute arc positions
    arcs = Vector{ArcSegment{Float64}}(undef, n)
    arc_angle_positions = Vector{Float64}(undef, n)
    
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
    ribbons = compute_ribbon_endpoints(cooc, arcs, arc_angle_positions, config.ribbon_width_power)
    
    ChordLayout{Float64}(
        arcs,
        ribbons,
        Float64(config.inner_radius),
        Float64(config.outer_radius),
        Float64(gap_size)
    )
end

"""
    get_sort_order(cooc, flows, sort_by::Symbol, label_order) -> Vector{Int}

Determine the order in which to place arcs.
"""
function get_sort_order(
    cooc::AbstractChordData,
    flows::Vector{<:Real},
    sort_by::Symbol,
    label_order::Union{Nothing, Vector{Int}} = nothing
)::Vector{Int}
    n = nlabels(cooc)
    
    if label_order !== nothing
        length(label_order) == n || throw(ArgumentError(
            "label_order length ($(length(label_order))) must equal number of labels ($n)"
        ))
        sort(label_order) == collect(1:n) || throw(ArgumentError(
            "label_order must be a permutation of indices 1:$n"
        ))
        return label_order
    end
    
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
        error("Unknown sort_by option: $sort_by (use :group, :value, :none, or provide label_order)")
    end
end

"""
    compute_ribbon_endpoints(cooc, arcs, arc_positions, ribbon_width_power) -> Vector{Ribbon{Float64}}

Compute ribbon endpoints. Ribbon width on each end is proportional to (value/flow)^power,
normalized so each arc is fully used. Power > 1 makes thick ribbons thicker and thin ones thinner.
"""
function compute_ribbon_endpoints(
    cooc::AbstractChordData,
    arcs::Vector{ArcSegment{Float64}},
    arc_positions::Vector{Float64},
    ribbon_width_power::Real = 1.0
)::Vector{Ribbon{Float64}}
    n = nlabels(cooc)
    power = Float64(ribbon_width_power)
    
    # When power != 1, precompute per-arc sum of (value/flow)^power for normalization
    arc_sum_power = zeros(Float64, n)
    if power != 1.0
        for i in 1:n
            for j in (i+1):n
                value = cooc[i, j]
                if value > 0
                    src_flow = arcs[i].value
                    tgt_flow = arcs[j].value
                    src_flow > 0 && (arc_sum_power[i] += (value / src_flow)^power)
                    tgt_flow > 0 && (arc_sum_power[j] += (value / tgt_flow)^power)
                end
            end
        end
    end
    
    positions = copy(arc_positions)
    ribbons = Ribbon{Float64}[]
    
    for i in 1:n
        for j in (i+1):n
            value = cooc[i, j]
            if value > 0
                src_arc = arcs[i]
                tgt_arc = arcs[j]
                src_arc_span = arc_span(src_arc)
                tgt_arc_span = arc_span(tgt_arc)
                src_flow = src_arc.value
                tgt_flow = tgt_arc.value
                
                if power == 1.0
                    src_width = src_flow > 0 ? src_arc_span * (value / src_flow) : 0.0
                    tgt_width = tgt_flow > 0 ? tgt_arc_span * (value / tgt_flow) : 0.0
                else
                    src_ratio = src_flow > 0 ? (value / src_flow)^power : 0.0
                    tgt_ratio = tgt_flow > 0 ? (value / tgt_flow)^power : 0.0
                    src_width = arc_sum_power[i] > 0 ? src_arc_span * src_ratio / arc_sum_power[i] : 0.0
                    tgt_width = arc_sum_power[j] > 0 ? tgt_arc_span * tgt_ratio / arc_sum_power[j] : 0.0
                end
                
                src_start = src_arc.start_angle + positions[i]
                src_end = src_start + src_width
                positions[i] += src_width
                
                tgt_start = tgt_arc.start_angle + positions[j]
                tgt_end = tgt_start + tgt_width
                positions[j] += tgt_width
                
                push!(ribbons, Ribbon{Float64}(
                    RibbonEndpoint{Float64}(i, src_start, src_end),
                    RibbonEndpoint{Float64}(j, tgt_start, tgt_end),
                    Float64(value)
                ))
            end
        end
    end
    
    ribbons
end

#==============================================================================#
# Layout Utilities
#==============================================================================#

"""
    label_order(cooc::AbstractChordData; sort_by=:group, label_order=nothing)

Return the label names in the order they appear around the circle for the given
co-occurrence matrix and layout options. Use this to reuse the same order when
creating a second chord plot for comparison.

# Arguments
- `cooc`: Co-occurrence matrix (from the plot whose order you want to copy).
- `sort_by`: Same as in `chordplot` (`:group`, `:value`, or `:none`). Must match the plot you are copying from.
- `label_order`: If the first plot used a custom order, pass the same here (vector of indices or label names).

# Returns
- Vector of label names in circle order (same element type as `cooc.labels`).

# Example
```julia
# First plot (default sort_by=:group)
fig1, ax1, plt1 = chordplot(cooc_A)
setup_chord_axis!(ax1)

# Get order from cooc_A and apply to cooc_B for comparable layout
order = label_order(cooc_A)
fig2, ax2, plt2 = chordplot(cooc_B; label_order = order)
setup_chord_axis!(ax2)
```
"""
function label_order(
    cooc::AbstractChordData;
    sort_by::Symbol = :group,
    label_order::Union{Nothing, Vector{Int}} = nothing
)
    n = nlabels(cooc)
    flows = [total_flow(cooc, i) for i in 1:n]
    order = get_sort_order(cooc, flows, sort_by, label_order)
    cooc.labels[order]
end

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
