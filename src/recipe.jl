# src/recipe.jl
# Makie plotting recipe for chord diagrams

using Makie
using GeometryBasics: Point2f, Polygon

#==============================================================================#
# Internal Configuration Types
#==============================================================================#

"""
Internal configuration for drawing functions. Consolidates all appearance settings.
"""
struct DrawConfig
    alpha::ComponentAlpha
    scaling::ValueScaling
    dim_color::RGB{Float64}
    dim_alpha::Float64
end

"""
Internal helper for normalizing values to [0,1] range with optional log scaling.
Used for value-based opacity calculations.
"""
struct ValueNormalizer
    min_val::Float64
    range::Float64
    log_min::Float64
    log_range::Float64
    use_log::Bool
end

function ValueNormalizer(values::AbstractVector{<:Real}, use_log::Bool)
    isempty(values) && return ValueNormalizer(0.0, 1.0, 0.0, 1.0, false)
    min_val = Float64(minimum(values))
    max_val = Float64(maximum(values))
    range = max_val - min_val
    
    if use_log && range > 0 && min_val > 0
        log_min = log(min_val)
        log_range = log(max_val) - log_min
        ValueNormalizer(min_val, range, log_min, log_range, true)
    else
        ValueNormalizer(min_val, range, 0.0, 1.0, false)
    end
end

"""
Normalize a value to [0, 1] range using the normalizer's configuration.
"""
function normalize_value(n::ValueNormalizer, value::Real)::Float64
    n.range <= 0 && return 1.0
    if n.use_log && value > 0
        clamp((log(Float64(value)) - n.log_min) / n.log_range, 0.0, 1.0)
    else
        clamp((Float64(value) - n.min_val) / n.range, 0.0, 1.0)
    end
end

"""
Compute alpha value based on normalized value, scaling from min_alpha to base_alpha.
"""
function compute_scaled_alpha(norm::ValueNormalizer, value::Real, 
                              base_alpha::Float64, min_alpha::Float64)::Float64
    t = normalize_value(norm, abs(value))
    min_alpha + t * (base_alpha - min_alpha)
end

"""
Parse alpha input into ComponentAlpha. Accepts:
- Real (single value for all)
- Tuple{Real,Real,Real} 
- ComponentAlpha (pass through)
"""
function parse_alpha(alpha)::ComponentAlpha
    if alpha isa ComponentAlpha
        alpha
    elseif alpha isa Tuple && length(alpha) >= 3
        ComponentAlpha(alpha[1], alpha[2], alpha[3])
    elseif alpha isa AbstractVector && length(alpha) >= 3
        ComponentAlpha(alpha[1], alpha[2], alpha[3])
    else
        ComponentAlpha(Float64(alpha))
    end
end

"""
Parse alpha_by_value input into ValueScaling. Accepts:
- Bool (simple on/off)
- ValueScaling (pass through)
- Tuple of (enabled, components, min_alpha, scale) for legacy compatibility
"""
function parse_scaling(scaling, components, min_alpha, scale)::ValueScaling
    if scaling isa ValueScaling
        scaling
    elseif scaling isa Bool
        ValueScaling(scaling, components[1], components[2], components[3], min_alpha, scale)
    else
        ValueScaling(false, true, true, true, 0.1, :linear)
    end
end

#==============================================================================#
# Main Recipe: chordplot
#==============================================================================#

"""
    chordplot(cooc::AbstractChordData)
    chordplot!(ax, cooc::AbstractChordData)

Create a chord diagram from co-occurrence data.

# Attributes (grouped by purpose)

## Radii and arc size
- `inner_radius = 0.92`: Inner radius for ribbons
- `outer_radius = 1.0`: Outer radius for arcs
- `arc_width = 0.08`: Width of arc segments

## Arc and gap layout
- `gap_fraction = 0.03`: Fraction of circle reserved for gaps
- `arc_scale = 1.0`: Scale for arc portion; < 1 adds extra gaps
- `sort_by = :group`: Order arcs by `:group`, `:value`, or `:none`
- `label_order = nothing`: Fixed order (overrides `sort_by`)

## Ribbon appearance
- `ribbon_width_power = 1.0`: Exponent for ribbon width
- `min_ribbon_value = 0`: Hide ribbons below this value
- `ribbon_tension = 0.5`: Bezier curve tension

## Arc appearance
- `arc_strokewidth = 0.5`: Border width
- `arc_strokecolor = :black`: Border color

## Labels
- `show_labels = true`: Whether to show labels
- `label_offset = 0.12`: Distance from arc to label
- `label_fontsize = 10`: Font size
- `label_color = :black`: Color (use `:group` for category colors)
- `rotate_labels = true`: Rotate labels to follow arcs
- `label_justify = :inside`: `:inside` or `:outside`
- `min_arc_flow = 0`: Hide arcs below this flow

## Colors
- `colorscheme = :group`: Color scheme (`:group`, `:categorical`, or `AbstractColorScheme`)

## Opacity
- `alpha = 1.0`: Opacity for components. Accepts:
  - `Real`: Same value for all (e.g., `alpha=0.7`)
  - `Tuple`: Per-component `(ribbons, arcs, labels)` 
  - `ComponentAlpha`: Named fields for clarity

## Value-based opacity scaling
- `alpha_by_value = false`: Scale opacity by value. Accepts `Bool` or `ValueScaling`

When `alpha_by_value=true` (or a `ValueScaling`):
- Ribbons scale by co-occurrence value
- Arcs/labels scale by total flow
- Components excluded from scaling stay fully opaque

## Focus (highlight subset)
- `focus_group = nothing`: Group to apply focus styling
- `focus_labels = nothing`: Labels to keep highlighted
- `dim_color = RGB(0.55, 0.55, 0.55)`: Color for dimmed elements
- `dim_alpha = 0.25`: Alpha for dimmed elements

# Example
```julia
using CairoMakie, ChordPlots, DataFrames

df = DataFrame(
    V_call = ["V1", "V1", "V2", "V2", "V3"],
    D_call = ["D1", "D2", "D1", "D2", "D1"],
    J_call = ["J1", "J1", "J2", "J2", "J1"]
)
cooc = cooccurrence_matrix(df, [:V_call, :D_call, :J_call])

# Basic plot
fig, ax, plt = chordplot(cooc)

# Per-component opacity
chordplot(cooc; alpha=ComponentAlpha(ribbons=0.5, arcs=1.0, labels=1.0))

# Value-based scaling (ribbons and arcs only)
chordplot(cooc; alpha_by_value=ValueScaling(
    enabled=true,
    components=(true, true, false)
))
```
"""
@recipe(ChordPlot, cooc) do scene
    Attributes(
        # Geometry
        inner_radius = 0.92,
        outer_radius = 1.0,
        arc_width = 0.08,
        gap_fraction = 0.03,
        arc_scale = 1.0,
        # Order
        sort_by = :group,
        label_order = nothing,
        # Ribbons
        ribbon_width_power = 1.0,
        min_ribbon_value = 0,
        ribbon_tension = 0.5,
        # Arcs
        arc_strokewidth = 0.5,
        arc_strokecolor = :black,
        # Labels
        show_labels = true,
        label_offset = 0.12,
        label_fontsize = 10,
        label_color = :black,
        rotate_labels = true,
        label_justify = :inside,
        min_arc_flow = 0,
        # Colors
        colorscheme = :group,
        # Opacity (Real, Tuple, or ComponentAlpha)
        alpha = 1.0,
        # Value-based scaling (Bool or ValueScaling)
        alpha_by_value = false,
        # Focus
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
        # Filter to labels that exist in this cooc, preserving order
        # This allows unified orders from label_order([cooc1, cooc2, ...]) to work
        idx = Int[]
        for l in order
            if haskey(cooc.label_to_index, l)
                push!(idx, cooc.label_to_index[l])
            end
        end
        # Must cover all labels in cooc (superset order is fine, subset is not)
        length(idx) != n && return nothing
        sort(idx) == collect(1:n) || return nothing  # must be permutation of 1:n
        return idx
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
    
    # Consolidate drawing configuration into single struct
    draw_config_obs = lift(p.alpha, p.alpha_by_value, p.dim_color, p.dim_alpha) do alpha, scaling, dim_color, dim_alpha
        ca = parse_alpha(alpha)
        vs = if scaling isa ValueScaling
            scaling
        elseif scaling isa Bool
            ValueScaling(scaling)
        else
            ValueScaling(false)
        end
        DrawConfig(ca, vs, RGB{Float64}(dim_color), Float64(dim_alpha))
    end
    
    # Draw ribbons first (behind arcs)
    draw_ribbons!(p, filtered_cooc_obs, filtered_layout_obs, colorscheme_obs, dimmed_indices_obs, draw_config_obs)
    
    # Draw arcs
    draw_arcs!(p, filtered_cooc_obs, layout_obs, colorscheme_obs, dimmed_indices_obs, draw_config_obs)
    
    # Draw labels
    draw_labels!(p, filtered_cooc_obs, layout_obs, colorscheme_obs, dimmed_indices_obs, draw_config_obs)
    
    p
end

#==============================================================================#
# Drawing Components
#==============================================================================#

function draw_ribbons!(p::ChordPlotType, cooc_obs, layout_obs, colorscheme_obs, dimmed_obs, config_obs)
    ribbon_data = lift(
        cooc_obs, layout_obs, colorscheme_obs, dimmed_obs, config_obs, p.ribbon_tension
    ) do cooc, layout, cs, dimmed, cfg, tension
        
        paths_colors = Tuple{Vector{Point2f}, RGBA{Float64}}[]
        isempty(layout.ribbons) && return paths_colors
        
        # Build normalizer only if scaling ribbons
        normalizer = if cfg.scaling.enabled && cfg.scaling.ribbons
            values = [abs(r.value) for r in layout.ribbons]
            ValueNormalizer(values, cfg.scaling.scale == :log)
        else
            nothing
        end
        
        for ribbon in layout.ribbons
            path = ribbon_path(ribbon, layout.inner_radius; tension=tension, n_bezier=40)
            
            # Dimmed: ribbon touches a dimmed label
            is_dimmed = ribbon.source.label_idx in dimmed || ribbon.target.label_idx in dimmed
            
            if is_dimmed
                color = RGBA(cfg.dim_color, cfg.dim_alpha)
            else
                base_color = resolve_ribbon_color(cs, ribbon, cooc)
                alpha = if normalizer !== nothing
                    compute_scaled_alpha(normalizer, ribbon.value, 
                                         cfg.alpha.ribbons, cfg.scaling.min_alpha)
                elseif cfg.scaling.enabled && !cfg.scaling.ribbons
                    1.0  # excluded from scaling = fully opaque
                else
                    cfg.alpha.ribbons
                end
                color = RGBA(base_color, alpha)
            end
            
            push!(paths_colors, (path.points, color))
        end
        
        paths_colors
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

function draw_arcs!(p::ChordPlotType, cooc_obs, layout_obs, colorscheme_obs, dimmed_obs, config_obs)
    arc_data = lift(
        cooc_obs, layout_obs, colorscheme_obs, dimmed_obs, config_obs, p.arc_width
    ) do cooc, layout, cs, dimmed, cfg, arc_width
        
        polys_colors = Tuple{Vector{Point2f}, RGBA{Float64}}[]
        isempty(layout.arcs) && return polys_colors
        
        # Build normalizer only if scaling arcs
        normalizer = if cfg.scaling.enabled && cfg.scaling.arcs
            values = [abs(arc.value) for arc in layout.arcs]
            ValueNormalizer(values, cfg.scaling.scale == :log)
        else
            nothing
        end
        
        for arc in layout.arcs
            inner_r = layout.outer_radius - arc_width
            outer_r = layout.outer_radius
            poly_points = arc_polygon(inner_r, outer_r, arc.start_angle, arc.end_angle; n_points=40)
            
            if arc.label_idx in dimmed
                color = RGBA(cfg.dim_color, cfg.dim_alpha)
            else
                base_color = resolve_arc_color(cs, arc, cooc)
                alpha = if normalizer !== nothing
                    compute_scaled_alpha(normalizer, arc.value, 
                                         cfg.alpha.arcs, cfg.scaling.min_alpha)
                elseif cfg.scaling.enabled && !cfg.scaling.arcs
                    1.0  # excluded from scaling = fully opaque
                else
                    cfg.alpha.arcs
                end
                color = RGBA(base_color, alpha)
            end
            
            push!(polys_colors, (poly_points, color))
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

function draw_labels!(p::ChordPlotType, cooc_obs, layout_obs, colorscheme_obs, dimmed_obs, config_obs)
    label_data = lift(
        cooc_obs, layout_obs, colorscheme_obs, dimmed_obs, config_obs,
        p.show_labels, p.label_offset, p.rotate_labels, p.label_justify, p.label_color
    ) do cooc, layout, cs, dimmed, cfg, show, offset, rotate, justify, label_color
        
        if !show
            return (Point2f[], String[], Float64[], Symbol[], Symbol[], RGBA{Float64}[])
        end
        
        positions = Point2f[]
        texts = String[]
        rotations = Float64[]
        haligns = Symbol[]
        valigns = Symbol[]
        colors = RGBA{Float64}[]
        
        isempty(layout.arcs) && return (positions, texts, rotations, haligns, valigns, colors)
        
        # Build normalizer only if scaling labels
        normalizer = if cfg.scaling.enabled && cfg.scaling.labels
            values = [abs(arc.value) for arc in layout.arcs]
            ValueNormalizer(values, cfg.scaling.scale == :log)
        else
            nothing
        end
        
        dimmed_color = RGBA(cfg.dim_color, cfg.dim_alpha)
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
                alpha = if normalizer !== nothing
                    compute_scaled_alpha(normalizer, arc.value, 
                                         cfg.alpha.labels, cfg.scaling.min_alpha)
                elseif cfg.scaling.enabled && !cfg.scaling.labels
                    1.0  # excluded from scaling = fully opaque
                else
                    cfg.alpha.labels
                end
                push!(colors, RGBA(RGB(base_color), alpha))
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
