# src/layout.jl
# Layout algorithms for chord diagrams

using SparseArrays

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
    layers_pair_span::Symbol
    layers_stack_order::Symbol
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
    ribbon_width_power::Real = 1.0,
    # CoOccurrenceLayers: anchor per-donor slices to fixed pair spans (:fixed_pairs) or
    # let each layer partition arc independently (:per_layer; legacy)
    layers_pair_span::Symbol = :fixed_pairs,
    # CoOccurrenceLayers only (when layers_pair_span = :stack_layers): order donor slices in each pair
    layers_stack_order::Symbol = :given
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
        Float64(ribbon_width_power),
        layers_pair_span,
        layers_stack_order
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
    
    # Calculate total flow per label (use absolute values for layout in case of signed matrices)
    # This handles diff() results where values can be negative
    flows = [abs_total_flow(cooc, i) for i in 1:n]
    total_flow_sum = sum(flows)
    
    if total_flow_sum ≤ 0
        error("Co-occurrence matrix has no non-zero values")
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
    ribbons = compute_ribbon_endpoints(
        cooc,
        arcs,
        arc_angle_positions,
        config.ribbon_width_power,
        config.layers_pair_span,
        config.layers_stack_order,
    )
    
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
scaled so each arc is fully used. Power > 1 makes thick ribbons thicker and thin ones thinner.
"""
function compute_ribbon_endpoints(
    cooc::AbstractChordData,
    arcs::Vector{ArcSegment{Float64}},
    arc_positions::Vector{Float64},
    ribbon_width_power::Real = 1.0,
    layers_pair_span::Symbol = :fixed_pairs,
    layers_stack_order::Symbol = :given
)::Vector{Ribbon{Float64}}
    # layers_pair_span / layers_stack_order are ignored for non-layer data
    n = nlabels(cooc)
    power = Float64(ribbon_width_power)

    pairs = upper_triangle_nonzero_pairs(cooc)
    
    # When power != 1, precompute per-arc sum of (|value|/flow)^power for normalization
    # Use absolute values for sizing (handles signed diff matrices)
    arc_sum_power = zeros(Float64, n)
    if power != 1.0
        for (i, j, value) in pairs
            abs_value = abs(value)
            src_flow = arcs[i].value
            tgt_flow = arcs[j].value
            src_flow > 0 && (arc_sum_power[i] += (abs_value / src_flow)^power)
            tgt_flow > 0 && (arc_sum_power[j] += (abs_value / tgt_flow)^power)
        end
    end
    
    positions = copy(arc_positions)
    ribbons = Ribbon{Float64}[]
    
    for (i, j, value) in pairs
        abs_value = abs(value)
        src_arc = arcs[i]
        tgt_arc = arcs[j]
        src_arc_span = arc_span(src_arc)
        tgt_arc_span = arc_span(tgt_arc)
        src_flow = src_arc.value
        tgt_flow = tgt_arc.value
        
        # Use absolute value for width computation
        if power == 1.0
            src_width = src_flow > 0 ? src_arc_span * (abs_value / src_flow) : 0.0
            tgt_width = tgt_flow > 0 ? tgt_arc_span * (abs_value / tgt_flow) : 0.0
        else
            src_ratio = src_flow > 0 ? (abs_value / src_flow)^power : 0.0
            tgt_ratio = tgt_flow > 0 ? (abs_value / tgt_flow)^power : 0.0
            src_width = arc_sum_power[i] > 0 ? src_arc_span * src_ratio / arc_sum_power[i] : 0.0
            tgt_width = arc_sum_power[j] > 0 ? tgt_arc_span * tgt_ratio / arc_sum_power[j] : 0.0
        end
        
        src_start = src_arc.start_angle + positions[i]
        src_end = src_start + src_width
        positions[i] += src_width
        
        tgt_start = tgt_arc.start_angle + positions[j]
        tgt_end = tgt_start + tgt_width
        positions[j] += tgt_width
        
        # Store original (possibly signed) value for coloring
        push!(ribbons, Ribbon{Float64}(
            RibbonEndpoint{Float64}(i, src_start, src_end),
            RibbonEndpoint{Float64}(j, tgt_start, tgt_end),
            Float64(value)
        ))
    end
    
    ribbons
end

function compute_ribbon_endpoints(
    cooc::CoOccurrenceLayers,
    arcs::Vector{ArcSegment{Float64}},
    arc_positions::Vector{Float64},
    ribbon_width_power::Real = 1.0,
    layers_pair_span::Symbol = :fixed_pairs,
    layers_stack_order::Symbol = :given
)::Vector{Ribbon{Float64}}
    n, _, nL = size(cooc.layers)
    power = Float64(ribbon_width_power)

    ribbons = Ribbon{Float64}[]

    if layers_pair_span === :per_layer
        # Legacy behavior: each layer independently partitions each arc, so pair endpoints
        # can shift around across donors when values differ.
        for ℓ in 1:nL
            layer = @view cooc.layers[:, :, ℓ]
            pairs = upper_triangle_nonzero_pairs(layer, n)

            arc_sum_power = zeros(Float64, n)
            if power != 1.0
                for (i, j, value) in pairs
                    abs_value = abs(value)
                    src_flow = arcs[i].value
                    tgt_flow = arcs[j].value
                    src_flow > 0 && (arc_sum_power[i] += (abs_value / src_flow)^power)
                    tgt_flow > 0 && (arc_sum_power[j] += (abs_value / tgt_flow)^power)
                end
            end

            positions = copy(arc_positions)
            for (i, j, value) in pairs
                abs_value = abs(value)
                src_arc = arcs[i]
                tgt_arc = arcs[j]
                src_arc_span = arc_span(src_arc)
                tgt_arc_span = arc_span(tgt_arc)
                src_flow = src_arc.value
                tgt_flow = tgt_arc.value

                if power == 1.0
                    src_width = src_flow > 0 ? src_arc_span * (abs_value / src_flow) : 0.0
                    tgt_width = tgt_flow > 0 ? tgt_arc_span * (abs_value / tgt_flow) : 0.0
                else
                    src_ratio = src_flow > 0 ? (abs_value / src_flow)^power : 0.0
                    tgt_ratio = tgt_flow > 0 ? (abs_value / tgt_flow)^power : 0.0
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
        return ribbons
    end

    (layers_pair_span === :fixed_pairs || layers_pair_span === :stack_layers) ||
        throw(ArgumentError("layers_pair_span must be :fixed_pairs, :stack_layers, or :per_layer, got $layers_pair_span"))

    # Precompute a fixed arc sub-span for each label pair from the aggregate matrix.
    agg_pairs = upper_triangle_nonzero_pairs(cooc.matrix, n)
    agg_arc_sum_power = zeros(Float64, n)
    if power != 1.0
        for (i, j, value) in agg_pairs
            abs_value = abs(value)
            src_flow = arcs[i].value
            tgt_flow = arcs[j].value
            src_flow > 0 && (agg_arc_sum_power[i] += (abs_value / src_flow)^power)
            tgt_flow > 0 && (agg_arc_sum_power[j] += (abs_value / tgt_flow)^power)
        end
    end

    fixed_pos = copy(arc_positions)
    # Keep a deterministic pair order (same as aggregate pair traversal) and a lookup table.
    fixed_pair_order = Tuple{Int, Int}[]
    fixed_segments = Dict{Tuple{Int,Int}, Tuple{Float64,Float64,Float64,Float64,Float64}}()
    # (i,j) => (src_start, src_width, tgt_start, tgt_width, agg_abs)
    for (i, j, value) in agg_pairs
        agg_abs = abs(value)
        src_arc = arcs[i]
        tgt_arc = arcs[j]
        src_span = arc_span(src_arc)
        tgt_span = arc_span(tgt_arc)
        src_flow = src_arc.value
        tgt_flow = tgt_arc.value

        if power == 1.0
            src_width = src_flow > 0 ? src_span * (agg_abs / src_flow) : 0.0
            tgt_width = tgt_flow > 0 ? tgt_span * (agg_abs / tgt_flow) : 0.0
        else
            src_ratio = src_flow > 0 ? (agg_abs / src_flow)^power : 0.0
            tgt_ratio = tgt_flow > 0 ? (agg_abs / tgt_flow)^power : 0.0
            src_width = agg_arc_sum_power[i] > 0 ? src_span * src_ratio / agg_arc_sum_power[i] : 0.0
            tgt_width = agg_arc_sum_power[j] > 0 ? tgt_span * tgt_ratio / agg_arc_sum_power[j] : 0.0
        end

        src_start = src_arc.start_angle + fixed_pos[i]
        fixed_pos[i] += src_width
        tgt_start = tgt_arc.start_angle + fixed_pos[j]
        fixed_pos[j] += tgt_width

        push!(fixed_pair_order, (i, j))
        fixed_segments[(i, j)] = (src_start, src_width, tgt_start, tgt_width, agg_abs)
    end

    if layers_pair_span === :stack_layers
        # True stacked decomposition: for each fixed pair segment, donors partition that segment.
        # Width allocation is proportional to each layer's |value| within that pair and fills the full segment.
        order_mode = layers_stack_order
        (order_mode === :given || order_mode === :value_desc || order_mode === :value_asc) ||
            throw(ArgumentError("layers_stack_order must be :given, :value_desc, or :value_asc, got $order_mode"))

        # Iterate in deterministic (aggregate) pair order.
        for (i, j) in fixed_pair_order
            seg = fixed_segments[(i, j)]
            src_start, src_width_full, tgt_start, tgt_width_full, agg_abs = seg
            agg_abs > 0 || continue

            abs_vals = Vector{Float64}(undef, nL)
            signed_vals = Vector{Float64}(undef, nL)
            @inbounds for ℓ in 1:nL
                v = Float64(cooc.layers[i, j, ℓ])
                signed_vals[ℓ] = v
                abs_vals[ℓ] = abs(v)
            end

            total_abs = sum(abs_vals)
            total_abs > 0 || continue
            idxs = collect(1:nL)
            if order_mode === :value_desc
                sort!(idxs, by = ℓ -> abs_vals[ℓ], rev = true)
            elseif order_mode === :value_asc
                sort!(idxs, by = ℓ -> abs_vals[ℓ], rev = false)
            end

            src_pos = src_start
            tgt_pos = tgt_start
            @inbounds for ℓ in idxs
                a = abs_vals[ℓ]
                a > 0 || continue
                # Each donor gets a share of the fixed segment proportional to |value|.
                frac = a / total_abs
                src_end = src_pos + frac * src_width_full
                tgt_end = tgt_pos + frac * tgt_width_full

                push!(ribbons, Ribbon{Float64}(
                    RibbonEndpoint{Float64}(i, src_pos, src_end),
                    RibbonEndpoint{Float64}(j, tgt_pos, tgt_end),
                    signed_vals[ℓ],
                ))

                src_pos = src_end
                tgt_pos = tgt_end
            end
        end

        return ribbons
    end

    # Draw each layer's value inside the fixed segment for that pair, starting at the segment start.
    for ℓ in 1:nL
        layer = @view cooc.layers[:, :, ℓ]
        pairs = upper_triangle_nonzero_pairs(layer, n)
        for (i, j, value) in pairs
            key = (i, j)
            seg = get(fixed_segments, key, nothing)
            seg === nothing && continue
            src_start, src_width_full, tgt_start, tgt_width_full, agg_abs = seg
            frac = agg_abs > 0 ? min(1.0, abs(value) / agg_abs) : 0.0

            src_end = src_start + frac * src_width_full
            tgt_end = tgt_start + frac * tgt_width_full

            push!(ribbons, Ribbon{Float64}(
                RibbonEndpoint{Float64}(i, src_start, src_end),
                RibbonEndpoint{Float64}(j, tgt_start, tgt_end),
                Float64(value)
            ))
        end
    end

    ribbons
end

#==============================================================================#
# Layout Utilities
#==============================================================================#

upper_triangle_nonzero_pairs(cooc::AbstractChordData) =
    upper_triangle_nonzero_pairs(cooc.matrix, nlabels(cooc))

function upper_triangle_nonzero_pairs(mat::SparseMatrixCSC, n::Int)
    I, J, V = findnz(mat)
    pairs = Tuple{Int, Int, Float64}[]
    @inbounds for k in eachindex(V)
        i = I[k]
        j = J[k]
        if i < j
            v = Float64(V[k])
            v != 0.0 && push!(pairs, (i, j, v))
        end
    end
    pairs
end

function upper_triangle_nonzero_pairs(mat::AbstractMatrix, n::Int)
    pairs = Tuple{Int, Int, Float64}[]
    @inbounds for i in 1:n
        for j in (i + 1):n
            v = Float64(mat[i, j])
            v != 0.0 && push!(pairs, (i, j, v))
        end
    end
    pairs
end

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
    label_order(coocs::AbstractVector{<:AbstractChordData}; sort_by=:group, include_all=true)

Compute a unified label order from multiple co-occurrence matrices with potentially different
label sets. Returns a Vector{String} of labels suitable for `chordplot(...; label_order=...)`
to ensure consistent label positioning across plots.

# Arguments
- `coocs`: Vector of co-occurrence matrices (may have different labels).

# Keywords
- `sort_by::Symbol = :group`: Sorting method (`:group` keeps groups together sorted by flow, `:value` sorts all by flow, `:none` uses union order).
- `include_all::Bool = true`: If `true`, include all labels from the union (labels missing in some matrices contribute zero flow). If `false`, include only labels present in **all** matrices.

# Returns
- Vector{String} of label names in order.

# Example
```julia
# Two matrices with overlapping but different label sets (user-preprocessed)
cooc_A = CoOccurrenceMatrix(mat_A, labels_A, groups_A)
cooc_B = CoOccurrenceMatrix(mat_B, labels_B, groups_B)

# Get a combined order that works for both
order = label_order([cooc_A, cooc_B])

# Plot with same label positions
chordplot!(ax1, cooc_A; label_order = order)
chordplot!(ax2, cooc_B; label_order = order)
```
"""
function label_order(
    coocs::AbstractVector{<:AbstractChordData};
    sort_by::Symbol = :group,
    include_all::Bool = true
)
    isempty(coocs) && return String[]
    
    # Build union of groups (preserve order from first cooc that has each group)
    group_order = Symbol[]
    group_labels = Dict{Symbol, Vector{String}}()  # group => labels in that group
    label_group = Dict{String, Symbol}()           # label => its group
    label_flow = Dict{String, Float64}()           # label => summed flow
    
    for cooc in coocs
        for g in cooc.groups
            if !haskey(group_labels, g.name)
                push!(group_order, g.name)
                group_labels[g.name] = String[]
            end
            for i in g.indices
                lbl = cooc.labels[i]
                if !haskey(label_group, lbl)
                    label_group[lbl] = g.name
                    push!(group_labels[g.name], lbl)
                    label_flow[lbl] = 0.0
                end
                label_flow[lbl] += total_flow(cooc, i)
            end
        end
    end
    
    # If include_all=false, keep only labels present in ALL matrices
    if !include_all
        all_label_sets = [Set(c.labels) for c in coocs]
        common = intersect(all_label_sets...)
        for (g, lbls) in group_labels
            filter!(l -> l in common, lbls)
        end
        filter!(kv -> kv.first in common, label_flow)
    end
    
    # Sort within groups or globally
    if sort_by == :value
        # Sort all labels by flow descending
        all_labels = collect(keys(label_flow))
        sort!(all_labels, by = l -> -label_flow[l])
        return all_labels
    elseif sort_by == :group
        # Keep groups together; within each group sort by flow descending
        result = String[]
        for g in group_order
            lbls = group_labels[g]
            sort!(lbls, by = l -> -label_flow[l])
            append!(result, lbls)
        end
        return result
    else  # :none
        # Just return in the order we encountered them (groups in order, labels in insertion order)
        result = String[]
        for g in group_order
            append!(result, group_labels[g])
        end
        return result
    end
end

# Varargs convenience: label_order(cooc1, cooc2, ...; kwargs...)
label_order(cooc1::AbstractChordData, cooc2::AbstractChordData, coocs::AbstractChordData...; kwargs...) =
    label_order([cooc1, cooc2, coocs...]; kwargs...)

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
