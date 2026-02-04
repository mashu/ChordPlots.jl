# src/recipe.jl
# Makie plotting recipe for chord diagrams

using Makie
using GeometryBasics: Point2f, Polygon

#==============================================================================#
# Main Recipe: chordplot
#==============================================================================#

"""
    chordplot(cooc::AbstractChordData)
    chordplot!(ax, cooc::AbstractChordData)

Create a chord diagram from co-occurrence data.

# Attributes (grouped by purpose)

## Radii and arc size
- `inner_radius = 0.92`: Inner radius for ribbons (closer to outer for less wasted space)
- `outer_radius = 1.0`: Outer radius for arcs
- `arc_width = 0.08`: Width of arc segments (band thickness around the circle)

## Arc and gap layout (angle allocation)
- `gap_fraction = 0.03`: Fraction of the full circle reserved for gaps between arcs (baseline spacing)
- `arc_scale = 1.0`: Scale for the arc (content) portion only; < 1 uses less space for arcs and adds extra gap. Works with `gap_fraction`: content = (1 - gap_fraction)*arc_scale; rest is gap.
- `sort_by = :group`: How to order arcs around the circle (`:group`, `:value`, `:none`). Ignored when `label_order` is set.
- `label_order = nothing`: Fixed order on the circle (vector of label indices or names). When set, overrides `sort_by`.

## Ribbon thickness and visibility
- `ribbon_width_power = 1.0`: Exponent for proportional ribbon width (value/flow)^power; use > 1 (e.g. `1.5` or `2`) to make thick ribbons visibly thicker and thin ones thinner (more dramatic spread)
- `min_ribbon_value = 0`: Hide ribbons below this value (use `value_histogram(cooc)` to choose a threshold)

## Ribbon appearance
- `ribbon_alpha = 0.65`: Transparency for ribbons
- `alpha_by_value = false`: When true, scale opacity by **strength** for the components enabled in `alpha_by_value_components`: ribbons by co-occurrence value, arcs and labels by total flow of that label.
- `alpha_by_value_components = (true, true, true)`: Which parts get strength-based opacity when `alpha_by_value` is true: **(ribbons, arcs, labels)**. Use e.g. `[true, false, false]` to scale only ribbons, or `[false, false, true]` only labels. Tuple or vector of 3 `Bool`s.
- `ribbon_alpha_scale = :linear`: Scaling for strength-based opacity (`:linear` or `:log`), used for whichever components are enabled in `alpha_by_value_components`
- `ribbon_tension = 0.5`: Bezier curve tension (0 = straight, 1 = tight)

## Arc appearance
- `arc_strokewidth = 0.5`: Arc border width
- `arc_strokecolor = :black`: Arc border color
- `arc_alpha = 0.65`: Transparency for arcs (default matches `ribbon_alpha`)

## Labels
- `show_labels = true`: Whether to show labels
- `label_offset = 0.12`: Distance from arc to label (increase for longer labels). If you use a larger value, call `setup_chord_axis!(ax; label_offset=...)` with the same value so the axis limits fit the labels and the title does not overlap.
- `label_fontsize = 10`: Label font size
- `label_color = :black`: Label color. Use `:group` to color each label by its category (same as arc/ribbon group colors from `colorscheme`).
- `label_alpha = 0.65`: Transparency for labels (default matches `ribbon_alpha`)
- `rotate_labels = true`: Rotate labels to follow arcs (avoids upside-down text)
- `label_justify = :inside`: `:inside` (toward center) or `:outside` (away from center)
- `min_arc_flow = 0`: Hide arcs (and their labels) whose total flow is below this value (reduces clutter)

## Colors
- `colorscheme = :group`: Color scheme (`:group`, `:categorical`, or an `AbstractColorScheme`)

## Overall opacity
- `alpha = 1.0`: Global opacity multiplier applied to arcs, ribbons, and labels. Use < 1 (e.g. `0.7`) to fade the whole diagram; individual `arc_alpha`, `ribbon_alpha`, and `label_alpha` are multiplied by this.

## Focus (emphasize a subset of labels in one group)
When `focus_group` and `focus_labels` are set, non-focused labels in that group are dimmed. **Dimming is applied automatically** to their labels, arcs, and any ribbons touching them; no extra steps needed.
- `focus_group = nothing`: If set (e.g. `:V_call`), only this group uses focus/dim styling
- `focus_labels = nothing`: Labels in `focus_group` to keep colored; others in that group are dimmed
- `dim_color = RGB(0.55, 0.55, 0.55)`: Color for dimmed labels, arcs, and ribbons
- `dim_alpha = 0.25`: Alpha for dimmed elements

# Parameter interactions
- **Arc/gap**: `gap_fraction` reserves that fraction of the circle for gaps; `arc_scale` then scales the remaining content (arcs). So they combine; use `arc_scale` < 1 for extra separation.
- **Order**: When `label_order` is set, it overrides `sort_by`.
- **Filtering**: `min_arc_flow` removes whole arcs (and labels); `min_ribbon_value` only hides ribbons. Both can be used.

# Example
```julia
using CairoMakie, ChordPlots, DataFrames

df = DataFrame(
    V_call = ["V1", "V1", "V2", "V2", "V3"],
    D_call = ["D1", "D2", "D1", "D2", "D1"],
    J_call = ["J1", "J1", "J2", "J2", "J1"]
)

cooc = cooccurrence_matrix(df, [:V_call, :D_call, :J_call])
fig, ax, plt = chordplot(cooc)
```
"""
@recipe(ChordPlot, cooc) do scene
    Attributes(
        # Radii and arc size
        inner_radius = 0.92,
        outer_radius = 1.0,
        arc_width = 0.08,
        # Arc and gap layout
        gap_fraction = 0.03,
        arc_scale = 1.0,
        sort_by = :group,
        label_order = nothing,
        # Ribbon thickness and visibility
        ribbon_width_power = 1.0,
        min_ribbon_value = 0,
        # Ribbon appearance (alpha_by_value + alpha_by_value_components control strength-based opacity)
        ribbon_alpha = 0.65,
        alpha_by_value = false,
        alpha_by_value_components = (true, true, true),  # (ribbons, arcs, labels)
        ribbon_alpha_scale = :linear,
        ribbon_tension = 0.5,
        # Arc appearance
        arc_strokewidth = 0.5,
        arc_strokecolor = :black,
        arc_alpha = 0.65,
        # Labels
        show_labels = true,
        label_offset = 0.12,
        label_fontsize = 10,
        label_color = :black,
        label_alpha = 0.65,
        rotate_labels = true,
        label_justify = :inside,
        min_arc_flow = 0,
        # Colors
        colorscheme = :group,
        # Overall opacity (multiplier for arc_alpha, ribbon_alpha, label_alpha)
        alpha = 1.0,
        # Focus (emphasize subset of labels in one group; dimming applied to labels, arcs, and ribbons automatically)
        focus_group = nothing,
        focus_labels = nothing,
        dim_color = RGB(0.55, 0.55, 0.55),
        dim_alpha = 0.25,
    )
end

# Type alias for convenience
const ChordPlotType = ChordPlot{<:Tuple{AbstractChordData}}

#==============================================================================#
# Helpers for order and focus
#==============================================================================#

function resolve_label_order(cooc::AbstractChordData, order)
    order === nothing && return nothing
    isempty(order) && return nothing
    n = nlabels(cooc)
    if order isa AbstractVector{<:Integer}
        lo = collect(Int, order)
        return length(lo) == n ? lo : nothing
    elseif order isa AbstractVector{<:AbstractString}
        length(order) != n && return nothing
        try
            idx = [cooc.label_to_index[l] for l in order]
            sort(idx) == collect(1:n) || return nothing  # must be permutation
            return idx
        catch
            return nothing
        end
    else
        return nothing
    end
end

function dimmed_label_indices(cooc::AbstractChordData, focus_group, focus_labels)
    (focus_group === nothing || focus_labels === nothing) && return Set{Int}()
    fl_set = Set(focus_labels)
    dimmed = Int[]
    for g in cooc.groups
        g.name != focus_group && continue
        for i in g.indices
            cooc.labels[i] in fl_set || push!(dimmed, i)
        end
        break
    end
    Set(dimmed)
end

#==============================================================================#
# Plot Implementation
#==============================================================================#

function Makie.plot!(p::ChordPlotType)
    # Extract observables
    cooc_obs = p[:cooc]
    
    # Filter co-occurrence matrix by minimum arc flow if specified
    filtered_cooc_obs = lift(cooc_obs, p.min_arc_flow) do cooc, min_flow
        if min_flow > 0
            # Filter out labels with total flow below threshold
            flows = [total_flow(cooc, i) for i in 1:nlabels(cooc)]
            keep_indices = [i for i in 1:nlabels(cooc) if flows[i] >= min_flow]
            
            if length(keep_indices) < nlabels(cooc)
                # Create filtered matrix
                new_matrix = cooc.matrix[keep_indices, keep_indices]
                new_labels = cooc.labels[keep_indices]
                
                # Rebuild groups with only remaining labels
                # Extract type parameters from cooc
                T = eltype(cooc.matrix)
                S = eltype(cooc.labels)
                new_groups = GroupInfo{S}[]
                idx = 1
                for g in cooc.groups
                    group_mask = [i in g.indices for i in keep_indices]
                    remaining = new_labels[group_mask]
                    if !isempty(remaining)
                        n_remaining = length(remaining)
                        push!(new_groups, GroupInfo{S}(g.name, remaining, idx:idx+n_remaining-1))
                        idx += n_remaining
                    end
                end
                
                if cooc isa NormalizedCoOccurrenceMatrix
                    return NormalizedCoOccurrenceMatrix(new_matrix, new_labels, new_groups; check_sum=false)
                else
                    return CoOccurrenceMatrix{T, S}(new_matrix, new_labels, new_groups)
                end
            end
        end
        cooc
    end
    
    # Resolve label_order to indices (permutation of 1:n) for fixed circle order
    resolved_order_obs = lift(filtered_cooc_obs, p.label_order) do cooc, order
        resolve_label_order(cooc, order)
    end
    
    # Reactive computations
    layout_obs = lift(filtered_cooc_obs, p.inner_radius, p.outer_radius, p.gap_fraction, p.sort_by, resolved_order_obs, p.arc_scale, p.ribbon_width_power) do cooc, ir, or, gf, sb, order, arc_scale, ribbon_power
        config = LayoutConfig(
            inner_radius = ir,
            outer_radius = or,
            gap_fraction = gf,
            sort_by = sb,
            label_order = order,
            arc_scale = arc_scale,
            ribbon_width_power = ribbon_power
        )
        compute_layout(cooc, config)
    end
    
    # Dimmed label indices: labels in focus_group not in focus_labels (grey + low alpha)
    dimmed_indices_obs = lift(filtered_cooc_obs, p.focus_group, p.focus_labels) do cooc, fg, fl
        dimmed_label_indices(cooc, fg, fl)
    end
    
    # Filter ribbons by minimum value
    filtered_layout_obs = lift(layout_obs, p.min_ribbon_value) do layout, min_val
        if min_val > 0
            filter_ribbons(layout, min_val)
        else
            layout
        end
    end
    
    # Color scheme (use filtered cooc for consistency)
    colorscheme_obs = lift(filtered_cooc_obs, p.colorscheme) do cooc, cs
        if cs == :group
            group_colors(cooc)
        elseif cs == :categorical
            categorical_colors(nlabels(cooc))
        elseif cs isa AbstractColorScheme
            cs
        else
            group_colors(cooc)
        end
    end
    
    # Draw ribbons first (behind arcs)
    draw_ribbons!(p, filtered_cooc_obs, filtered_layout_obs, colorscheme_obs, dimmed_indices_obs)
    
    # Draw arcs
    draw_arcs!(p, filtered_cooc_obs, layout_obs, colorscheme_obs, dimmed_indices_obs)
    
    # Draw labels
    draw_labels!(p, filtered_cooc_obs, layout_obs, colorscheme_obs, dimmed_indices_obs)
    
    p
end

#==============================================================================#
# Drawing Components
#==============================================================================#

function draw_ribbons!(p::ChordPlotType, cooc_obs, layout_obs, colorscheme_obs, dimmed_obs)
    # Pre-compute all ribbon data
    ribbon_data = lift(
        cooc_obs, layout_obs, colorscheme_obs, dimmed_obs,
        p.ribbon_alpha, p.alpha, p.ribbon_tension, p.alpha_by_value, p.alpha_by_value_components, p.ribbon_alpha_scale,
        p.dim_color, p.dim_alpha
    ) do cooc, layout, cs, dimmed, ribbon_alpha, global_alpha, tension, alpha_by_value, components, alpha_scale, dim_color, dim_alpha
        
        paths_and_colors = Tuple{Vector{Point2f}, RGBA{Float64}}[]
        
        min_alpha = 0.1
        max_alpha = ribbon_alpha * global_alpha
        alpha_range = max_alpha - min_alpha
        scale_ribbons = length(components) >= 1 && components[1]
        use_value_alpha = alpha_by_value && scale_ribbons && !isempty(layout.ribbons)
        if use_value_alpha
            ribbon_values = [r.value for r in layout.ribbons]
            min_val = minimum(ribbon_values)
            max_val = maximum(ribbon_values)
            value_range = max_val - min_val
            
            # Use logarithmic scaling to better spread out small integer values
            # This makes differences more visible when values are close together
            if value_range > 0 && min_val > 0
                # Log scale: log(value) normalized to [0, 1]
                log_min = log(min_val)
                log_max = log(max_val)
                log_range = log_max - log_min
            else
                log_min = 0.0
                log_max = 1.0
                log_range = 1.0
            end
        else
            # Not using strength-based alpha; dummy values (unused)
            min_val = 0.0
            max_val = 1.0
            value_range = 1.0
            log_min = 0.0
            log_max = 1.0
            log_range = 1.0
        end
        
        for ribbon in layout.ribbons
            path = ribbon_path(ribbon, layout.inner_radius; 
                              tension=tension, n_bezier=40)
            
            # Dimmed: ribbon touches a dimmed label -> grey and low alpha
            src_dimmed = ribbon.source.label_idx in dimmed
            tgt_dimmed = ribbon.target.label_idx in dimmed
            if src_dimmed || tgt_dimmed
                base_color = dim_color
                alpha_use = dim_alpha * global_alpha
            else
                base_color = resolve_ribbon_color(cs, ribbon, cooc)
                if use_value_alpha
                    if value_range > 0
                        if alpha_scale == :log && min_val > 0
                            log_value = log(ribbon.value)
                            normalized_value = (log_value - log_min) / log_range
                        else
                            normalized_value = (ribbon.value - min_val) / value_range
                        end
                        normalized_value = clamp(normalized_value, 0.0, 1.0)
                        alpha_use = min_alpha + normalized_value * alpha_range
                    else
                        alpha_use = max_alpha
                    end
                else
                    alpha_use = ribbon_alpha * global_alpha
                end
            end
            
            color = RGBA(base_color, alpha_use)
            
            push!(paths_and_colors, (path.points, color))
        end
        
        paths_and_colors
    end
    
    # Draw each ribbon as a polygon
    for_each_ribbon = lift(ribbon_data) do data
        polys = [Polygon(d[1]) for d in data]
        colors = [d[2] for d in data]
        (polys, colors)
    end
    
    polys_obs = lift(x -> x[1], for_each_ribbon)
    colors_obs = lift(x -> x[2], for_each_ribbon)
    
    poly!(p, polys_obs; color=colors_obs, strokewidth=0)
end

function draw_arcs!(p::ChordPlotType, cooc_obs, layout_obs, colorscheme_obs, dimmed_obs)
    # Compute arc polygons with alpha (dimmed arcs use dim_color and dim_alpha; alpha_by_value scales by total flow)
    arc_data = lift(
        cooc_obs, layout_obs, colorscheme_obs, dimmed_obs,
        p.arc_width, p.arc_alpha, p.alpha, p.alpha_by_value, p.alpha_by_value_components, p.ribbon_alpha_scale, p.dim_color, p.dim_alpha
    ) do cooc, layout, cs, dimmed, arc_width, arc_alpha, global_alpha, alpha_by_value, components, alpha_scale, dim_color, dim_alpha
        
        polys_colors = Tuple{Vector{Point2f}, RGBA{Float64}}[]
        min_alpha = 0.1
        scale_arcs = length(components) >= 2 && components[2]
        flows = [arc.value for arc in layout.arcs]
        flow_min = isempty(flows) ? 0.0 : minimum(flows)
        flow_max = isempty(flows) ? 1.0 : maximum(flows)
        flow_range = flow_max - flow_min
        if alpha_by_value && scale_arcs && flow_range > 0 && flow_min > 0 && alpha_scale == :log
            log_min = log(flow_min)
            log_max = log(flow_max)
            log_range = log_max - log_min
        else
            log_min = 0.0
            log_max = 1.0
            log_range = 1.0
        end
        
        for arc in layout.arcs
            inner_r = layout.outer_radius - arc_width
            outer_r = layout.outer_radius
            
            poly_points = arc_polygon(inner_r, outer_r, arc.start_angle, arc.end_angle; n_points=40)
            if arc.label_idx in dimmed
                color = dim_color
                alpha_use = dim_alpha * global_alpha
            else
                color = resolve_arc_color(cs, arc, cooc)
                if alpha_by_value && scale_arcs && flow_range > 0
                    if alpha_scale == :log && flow_min > 0
                        norm = (log(arc.value) - log_min) / log_range
                    else
                        norm = (arc.value - flow_min) / flow_range
                    end
                    norm = clamp(norm, 0.0, 1.0)
                    alpha_use = (min_alpha + norm * (arc_alpha - min_alpha)) * global_alpha
                else
                    alpha_use = arc_alpha * global_alpha
                end
            end
            color_with_alpha = RGBA(color, alpha_use)
            
            push!(polys_colors, (poly_points, color_with_alpha))
        end
        
        polys_colors
    end
    
    arc_polys_obs = lift(d -> [Polygon(x[1]) for x in d], arc_data)
    arc_colors_obs = lift(d -> [x[2] for x in d], arc_data)
    
    poly!(p, arc_polys_obs;
          color = arc_colors_obs,
          strokewidth = p.arc_strokewidth,
          strokecolor = p.arc_strokecolor)
end

function draw_labels!(p::ChordPlotType, cooc_obs, layout_obs, colorscheme_obs, dimmed_obs)
    # Only draw if show_labels is true; apply label_alpha and dim_color for dimmed; alpha_by_value scales by total flow; label_color = :group uses colorscheme per label
    label_data = lift(
        cooc_obs, layout_obs, colorscheme_obs, dimmed_obs,
        p.show_labels, p.label_offset, p.rotate_labels, p.label_justify,
        p.label_color, p.label_alpha, p.alpha, p.alpha_by_value, p.alpha_by_value_components, p.ribbon_alpha_scale, p.dim_color, p.dim_alpha
    ) do cooc, layout, cs, dimmed, show, offset, rotate, justify, label_color, label_alpha, global_alpha, alpha_by_value, components, alpha_scale, dim_color, dim_alpha
        
        if !show
            return (Point2f[], String[], Float64[], Symbol[], Symbol[], RGBA{Float64}[])
        end
        
        positions = Point2f[]
        texts = String[]
        rotations = Float64[]
        haligns = Symbol[]
        valigns = Symbol[]
        colors = RGBA{Float64}[]
        
        min_alpha = 0.1
        scale_labels = length(components) >= 3 && components[3]
        flows = [arc.value for arc in layout.arcs]
        flow_min = isempty(flows) ? 0.0 : minimum(flows)
        flow_max = isempty(flows) ? 1.0 : maximum(flows)
        flow_range = flow_max - flow_min
        if alpha_by_value && scale_labels && flow_range > 0 && flow_min > 0 && alpha_scale == :log
            log_min = log(flow_min)
            log_max = log(flow_max)
            log_range = log_max - log_min
        else
            log_min = 0.0
            log_max = 1.0
            log_range = 1.0
        end
        
        dimmed_color = RGBA(dim_color, dim_alpha * global_alpha)
        use_group_color = label_color === :group

        for arc in layout.arcs
            lp = label_position(arc, layout.outer_radius, offset; rotate=rotate, justify=justify)
            push!(positions, lp.point)
            push!(texts, cooc.labels[arc.label_idx])
            push!(rotations, lp.angle)
            push!(haligns, lp.halign)
            push!(valigns, lp.valign)
            if arc.label_idx in dimmed
                push!(colors, dimmed_color)
            else
                base_color = use_group_color ? resolve_arc_color(cs, arc, cooc) : Makie.to_color(label_color)
                if alpha_by_value && scale_labels && flow_range > 0
                    if alpha_scale == :log && flow_min > 0
                        norm = (log(arc.value) - log_min) / log_range
                    else
                        norm = (arc.value - flow_min) / flow_range
                    end
                    norm = clamp(norm, 0.0, 1.0)
                    a = (min_alpha + norm * (label_alpha - min_alpha)) * global_alpha
                    push!(colors, RGBA(base_color, a))
                else
                    push!(colors, RGBA(base_color, label_alpha * global_alpha))
                end
            end
        end
        
        (positions, texts, rotations, haligns, valigns, colors)
    end
    
    # Draw labels with proper alignment and per-label color/alpha
    positions_obs = lift(d -> d[1], label_data)
    texts_obs = lift(d -> d[2], label_data)
    rotations_obs = lift(d -> d[3], label_data)
    colors_obs = lift(d -> d[6], label_data)
    
    text!(p, positions_obs;
          text = texts_obs,
          rotation = rotations_obs,
          fontsize = p.label_fontsize,
          color = colors_obs,
          align = (:center, :center))
end

#==============================================================================#
# Convenience Functions
#==============================================================================#

"""
    chordplot(df::DataFrame, columns; kwargs...)

Create chord plot directly from DataFrame.
"""
function chordplot(df::DataFrame, columns::Vector{Symbol}; kwargs...)
    cooc = cooccurrence_matrix(df, columns)
    chordplot(cooc; kwargs...)
end

function chordplot!(ax, df::DataFrame, columns::Vector{Symbol}; kwargs...)
    cooc = cooccurrence_matrix(df, columns)
    chordplot!(ax, cooc; kwargs...)
end

#==============================================================================#
# Value distribution histogram (for choosing min_ribbon_value)
#==============================================================================#

"""
    value_histogram!(ax, data; kwargs...)

Plot histogram of co-occurrence values on the given axis. `data` can be a single
`AbstractChordData` or an abstract container of them (e.g. `Vector` of matrices).
Use to inspect the distribution and choose a threshold (e.g. `min_ribbon_value`).
Keyword arguments are passed to `histogram!`.
"""
function value_histogram!(ax::Axis, data; kwargs...)
    vals = data isa AbstractChordData ? cooccurrence_values(data) : cooccurrence_values(collect(data))
    isempty(vals) && return ax
    histogram!(ax, vals; kwargs...)
    ax
end

"""
    value_histogram(data; kwargs...)

Create a figure with a histogram of co-occurrence values. `data` can be a single
`AbstractChordData` or an abstract container of them. Returns `(fig, ax, hist)`.
Use to choose `min_ribbon_value` from the distribution.
"""
function value_histogram(data; kwargs...)
    fig = Figure()
    ax = Axis(fig[1, 1], xlabel = "Co-occurrence value", ylabel = "Count")
    value_histogram!(ax, data; kwargs...)
    (fig, ax)
end

#==============================================================================#
# Axis Configuration
#==============================================================================#

"""
    setup_chord_axis!(ax::Axis; outer_radius=1.0, label_offset=0.12, padding=0.2)

Configure axis for chord plot display (equal aspect, no decorations). Sets axis limits
so that the circle and labels fit: limits extend to `outer_radius + label_offset + padding`.
Use the same `outer_radius` and `label_offset` as in your `chordplot!` call so that large
label offsets don't get clipped and the title doesn't overlap the labels.
"""
function setup_chord_axis!(ax::Axis; outer_radius::Real = 1.0, label_offset::Real = 0.12, padding::Real = 0.2)
    ax.aspect = DataAspect()
    hidedecorations!(ax)
    hidespines!(ax)
    limit = Float64(outer_radius) + Float64(label_offset) + Float64(padding)
    limits!(ax, -limit, limit, -limit, limit)
    ax
end
