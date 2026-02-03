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

# Attributes
- `inner_radius = 0.92`: Inner radius for ribbons (closer to outer for less wasted space)
- `outer_radius = 1.0`: Outer radius for arcs
- `arc_width = 0.08`: Width of arc segments
- `gap_fraction = 0.03`: Gap between arcs as fraction of circle
- `ribbon_alpha = 0.65`: Transparency for ribbons
- `ribbon_alpha_by_value = false`: If true, scale opacity by ribbon value (min 10%, larger ribbons more visible)
- `ribbon_alpha_scale = :linear`: Scaling method for value-based opacity (`:linear` default, `:log` for better distribution of small integers)
- `ribbon_tension = 0.5`: Bezier curve tension (0=straight, 1=tight)
- `show_labels = true`: Show labels
- `label_offset = 0.12`: Distance from arc to label (increase for longer labels to avoid overlap)
- `label_fontsize = 10`: Label font size
- `rotate_labels = true`: Rotate labels to follow arcs (prevents upside-down text)
- `label_justify = :inside`: Label justification (`:inside` aligns toward circle center, `:outside` aligns away)
- `min_arc_flow = 0`: Filter out arcs and labels with total flow below this value (helps reduce overlap from many small segments)
- `colorscheme = :group`: Color scheme (:group, :categorical, or AbstractColorScheme)
- `arc_strokewidth = 0.5`: Arc border width
- `arc_strokecolor = :black`: Arc border color
- `arc_alpha = 0.65`: Transparency for arcs (matches ribbon_alpha by default for consistent look)
- `label_alpha = 0.65`: Transparency for labels (matches ribbon_alpha by default)
- `sort_by = :group`: How to sort arcs (:group, :value, :none, or :custom with label_order)
- `label_order = nothing`: Fixed order of labels on circle (vector of label indices 1:n, or vector of label names). Use to compare two chord plots with same layout.
- `min_ribbon_value = 0`: Hide ribbons below this value
- `focus_group = nothing`: If set (e.g. :V_call), only this group uses focus/dim styling
- `focus_labels = nothing`: Labels in focus_group to keep colored; others in that group are greyed out
- `dim_color = RGB(0.55, 0.55, 0.55)`: Color for non-focused labels in focus_group
- `dim_alpha = 0.25`: Alpha for non-focused labels, their arcs, and ribbons touching them

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
        # Layout
        inner_radius = 0.92,  # Closer to outer_radius to reduce wasted space
        outer_radius = 1.0,
        arc_width = 0.08,
        gap_fraction = 0.03,
        sort_by = :group,
        
        # Ribbons
        ribbon_alpha = 0.65,  # Slightly more opaque for better visibility
        ribbon_tension = 0.5,
        min_ribbon_value = 0,
        ribbon_alpha_by_value = false,  # Scale opacity by ribbon value (larger = more visible)
        ribbon_alpha_scale = :linear,  # Scaling method: :linear (default) or :log (better for small integers)
        
        # Labels
        show_labels = true,
        label_offset = 0.12,
        label_fontsize = 10,
        rotate_labels = true,
        label_color = :black,
        label_justify = :inside,  # :inside (toward circle) or :outside (away from circle)
        min_arc_flow = 0,  # Filter out arcs (and labels) with total flow below this value
        
        # Colors
        colorscheme = :group,
        
        # Arc styling (alpha matches ribbon by default for consistent transparency)
        arc_strokewidth = 0.5,
        arc_strokecolor = :black,
        arc_alpha = 0.65,
        label_alpha = 0.65,
        
        # Fixed order for comparing plots
        label_order = nothing,
        
        # Focus: emphasize only certain labels in a group; grey out the rest
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

function _resolve_label_order(cooc::AbstractChordData, order)
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

function _dimmed_label_indices(cooc::AbstractChordData, focus_group, focus_labels)
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
        _resolve_label_order(cooc, order)
    end
    
    # Reactive computations
    layout_obs = lift(filtered_cooc_obs, p.inner_radius, p.outer_radius, p.gap_fraction, p.sort_by, resolved_order_obs) do cooc, ir, or, gf, sb, order
        config = LayoutConfig(
            inner_radius = ir,
            outer_radius = or,
            gap_fraction = gf,
            sort_by = sb,
            label_order = order
        )
        compute_layout(cooc, config)
    end
    
    # Dimmed label indices: labels in focus_group not in focus_labels (grey + low alpha)
    dimmed_indices_obs = lift(filtered_cooc_obs, p.focus_group, p.focus_labels) do cooc, fg, fl
        _dimmed_label_indices(cooc, fg, fl)
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
    _draw_ribbons!(p, filtered_cooc_obs, filtered_layout_obs, colorscheme_obs, dimmed_indices_obs)
    
    # Draw arcs
    _draw_arcs!(p, filtered_cooc_obs, layout_obs, colorscheme_obs, dimmed_indices_obs)
    
    # Draw labels
    _draw_labels!(p, filtered_cooc_obs, layout_obs, dimmed_indices_obs)
    
    p
end

#==============================================================================#
# Drawing Components
#==============================================================================#

function _draw_ribbons!(p::ChordPlotType, cooc_obs, layout_obs, colorscheme_obs, dimmed_obs)
    # Pre-compute all ribbon data
    ribbon_data = lift(
        cooc_obs, layout_obs, colorscheme_obs, dimmed_obs,
        p.ribbon_alpha, p.ribbon_tension, p.ribbon_alpha_by_value, p.ribbon_alpha_scale,
        p.dim_color, p.dim_alpha
    ) do cooc, layout, cs, dimmed, alpha, tension, alpha_by_value, alpha_scale, dim_color, dim_alpha
        
        paths_and_colors = Tuple{Vector{Point2f}, RGBA{Float64}}[]
        
        # If alpha_by_value is enabled, compute value range for normalization
        min_alpha = 0.1  # Minimum opacity is always 10%
        max_alpha = alpha  # Maximum opacity is the specified ribbon_alpha
        alpha_range = max_alpha - min_alpha
        
        if alpha_by_value && !isempty(layout.ribbons)
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
            # Dummy values when not using alpha_by_value (won't be used)
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
                ribbon_alpha = dim_alpha
            else
                base_color = resolve_ribbon_color(cs, ribbon, cooc)
                # Calculate opacity based on value if enabled
                if alpha_by_value && !isempty(layout.ribbons)
                if value_range > 0
                    if alpha_scale == :log && min_val > 0
                        # Use logarithmic scaling for better distribution
                        # This spreads out small differences in integer values
                        # making each ribbon have a distinct opacity level
                        log_value = log(ribbon.value)
                        normalized_value = (log_value - log_min) / log_range
                    else
                        # Linear scaling: proportional to value
                        normalized_value = (ribbon.value - min_val) / value_range
                    end
                    # Clamp to [0, 1] to handle any floating point issues
                    normalized_value = clamp(normalized_value, 0.0, 1.0)
                    ribbon_alpha = min_alpha + normalized_value * alpha_range
                else
                    # All ribbons have same value, use max alpha
                    ribbon_alpha = max_alpha
                end
                else
                    ribbon_alpha = alpha
                end
            end
            
            color = RGBA(base_color, ribbon_alpha)
            
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

function _draw_arcs!(p::ChordPlotType, cooc_obs, layout_obs, colorscheme_obs, dimmed_obs)
    # Compute arc polygons with alpha (dimmed arcs use dim_color and dim_alpha)
    arc_data = lift(
        cooc_obs, layout_obs, colorscheme_obs, dimmed_obs,
        p.arc_width, p.arc_alpha, p.dim_color, p.dim_alpha
    ) do cooc, layout, cs, dimmed, arc_width, alpha, dim_color, dim_alpha
        
        polys_colors = Tuple{Vector{Point2f}, RGBA{Float64}}[]
        
        for arc in layout.arcs
            inner_r = layout.outer_radius - arc_width
            outer_r = layout.outer_radius
            
            poly_points = arc_polygon(inner_r, outer_r, arc.start_angle, arc.end_angle; n_points=40)
            if arc.label_idx in dimmed
                color = dim_color
                alpha_use = dim_alpha
            else
                color = resolve_arc_color(cs, arc, cooc)
                alpha_use = alpha
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

function _draw_labels!(p::ChordPlotType, cooc_obs, layout_obs, dimmed_obs)
    # Only draw if show_labels is true; apply label_alpha and dim_color for dimmed labels
    label_data = lift(
        cooc_obs, layout_obs, dimmed_obs,
        p.show_labels, p.label_offset, p.rotate_labels, p.label_justify,
        p.label_color, p.label_alpha, p.dim_color, p.dim_alpha
    ) do cooc, layout, dimmed, show, offset, rotate, justify, label_color, label_alpha, dim_color, dim_alpha
        
        if !show
            return (Point2f[], String[], Float64[], Symbol[], Symbol[], RGBA{Float64}[])
        end
        
        positions = Point2f[]
        texts = String[]
        rotations = Float64[]
        haligns = Symbol[]
        valigns = Symbol[]
        colors = RGBA{Float64}[]
        
        base_color = RGBA(Makie.to_color(label_color), label_alpha)
        dimmed_color = RGBA(dim_color, dim_alpha)
        
        for arc in layout.arcs
            lp = label_position(arc, layout.outer_radius, offset; rotate=rotate, justify=justify)
            push!(positions, lp.point)
            push!(texts, cooc.labels[arc.label_idx])
            push!(rotations, lp.angle)
            push!(haligns, lp.halign)
            push!(valigns, lp.valign)
            push!(colors, arc.label_idx in dimmed ? dimmed_color : base_color)
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
# Axis Configuration
#==============================================================================#

"""
    setup_chord_axis!(ax::Axis)

Configure axis for chord plot display (equal aspect, no decorations).
"""
function setup_chord_axis!(ax::Axis; padding::Real = 0.2)
    ax.aspect = DataAspect()
    hidedecorations!(ax)
    hidespines!(ax)
    limits!(ax, -1-padding, 1+padding, -1-padding, 1+padding)
    ax
end
