# src/recipe.jl
# Makie plotting recipe for chord diagrams

using Makie
using GeometryBasics: Point2f, Polygon

#==============================================================================#
# Main Recipe: chordplot
#==============================================================================#

"""
    chordplot(cooc::CoOccurrenceMatrix)
    chordplot!(ax, cooc::CoOccurrenceMatrix)

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
- `colorscheme = :group`: Color scheme (:group, :categorical, or AbstractColorScheme)
- `arc_strokewidth = 0.5`: Arc border width
- `arc_strokecolor = :black`: Arc border color
- `arc_alpha = 0.9`: Transparency for arcs (slight transparency for modern look)
- `sort_by = :group`: How to sort arcs (:group, :value, :none)
- `min_ribbon_value = 0`: Hide ribbons below this value

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
        
        # Colors
        colorscheme = :group,
        
        # Arc styling
        arc_strokewidth = 0.5,
        arc_strokecolor = :black,
        arc_alpha = 0.9,  # Slight transparency for modern look
    )
end

# Type alias for convenience
const ChordPlotType = ChordPlot{<:Tuple{CoOccurrenceMatrix}}

#==============================================================================#
# Plot Implementation
#==============================================================================#

function Makie.plot!(p::ChordPlotType)
    # Extract observables
    cooc_obs = p[:cooc]
    
    # Reactive computations
    layout_obs = lift(cooc_obs, p.inner_radius, p.outer_radius, p.gap_fraction, p.sort_by) do cooc, ir, or, gf, sb
        config = LayoutConfig(
            inner_radius = ir,
            outer_radius = or,
            gap_fraction = gf,
            sort_by = sb
        )
        compute_layout(cooc, config)
    end
    
    # Filter ribbons by minimum value
    filtered_layout_obs = lift(layout_obs, p.min_ribbon_value) do layout, min_val
        if min_val > 0
            filter_ribbons(layout, min_val)
        else
            layout
        end
    end
    
    # Color scheme
    colorscheme_obs = lift(cooc_obs, p.colorscheme) do cooc, cs
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
    _draw_ribbons!(p, cooc_obs, filtered_layout_obs, colorscheme_obs)
    
    # Draw arcs
    _draw_arcs!(p, cooc_obs, layout_obs, colorscheme_obs)
    
    # Draw labels
    _draw_labels!(p, cooc_obs, layout_obs)
    
    p
end

#==============================================================================#
# Drawing Components
#==============================================================================#

function _draw_ribbons!(p::ChordPlotType, cooc_obs, layout_obs, colorscheme_obs)
    # Pre-compute all ribbon data
    ribbon_data = lift(
        cooc_obs, layout_obs, colorscheme_obs, 
        p.ribbon_alpha, p.ribbon_tension, p.ribbon_alpha_by_value, p.ribbon_alpha_scale
    ) do cooc, layout, cs, alpha, tension, alpha_by_value, alpha_scale
        
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

function _draw_arcs!(p::ChordPlotType, cooc_obs, layout_obs, colorscheme_obs)
    # Compute arc polygons with alpha
    arc_data = lift(
        cooc_obs, layout_obs, colorscheme_obs, p.arc_width, p.arc_alpha
    ) do cooc, layout, cs, arc_width, alpha
        
        polys_colors = Tuple{Vector{Point2f}, RGBA{Float64}}[]
        
        for arc in layout.arcs
            inner_r = layout.outer_radius - arc_width
            outer_r = layout.outer_radius
            
            poly_points = arc_polygon(inner_r, outer_r, arc.start_angle, arc.end_angle; n_points=40)
            color = resolve_arc_color(cs, arc, cooc)
            color_with_alpha = RGBA(color, alpha)
            
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

function _draw_labels!(p::ChordPlotType, cooc_obs, layout_obs)
    # Only draw if show_labels is true
    label_data = lift(
        cooc_obs, layout_obs, p.show_labels, p.label_offset, p.rotate_labels, p.label_justify
    ) do cooc, layout, show, offset, rotate, justify
        
        if !show
            return (Point2f[], String[], Float64[], Symbol[], Symbol[])
        end
        
        positions = Point2f[]
        texts = String[]
        rotations = Float64[]
        haligns = Symbol[]
        valigns = Symbol[]
        
        for arc in layout.arcs
            lp = label_position(arc, layout.outer_radius, offset; rotate=rotate, justify=justify)
            push!(positions, lp.point)
            push!(texts, cooc.labels[arc.label_idx])
            push!(rotations, lp.angle)
            push!(haligns, lp.halign)
            push!(valigns, lp.valign)
        end
        
        (positions, texts, rotations, haligns, valigns)
    end
    
    # Draw labels with proper alignment
    positions_obs = lift(d -> d[1], label_data)
    texts_obs = lift(d -> d[2], label_data)
    rotations_obs = lift(d -> d[3], label_data)
    
    # Use text! with position broadcasting
    text!(p, positions_obs;
          text = texts_obs,
          rotation = rotations_obs,
          fontsize = p.label_fontsize,
          color = p.label_color,
          align = (:center, :center))  # Will be overridden per-label ideally
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
