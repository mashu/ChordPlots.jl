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
- `inner_radius = 0.8`: Inner radius for ribbons
- `outer_radius = 1.0`: Outer radius for arcs
- `arc_width = 0.08`: Width of arc segments
- `gap_fraction = 0.03`: Gap between arcs as fraction of circle
- `ribbon_alpha = 0.6`: Transparency for ribbons
- `ribbon_tension = 0.5`: Bezier curve tension (0=straight, 1=tight)
- `show_labels = true`: Show labels
- `label_offset = 0.12`: Distance from arc to label
- `label_fontsize = 10`: Label font size
- `rotate_labels = true`: Rotate labels to follow arcs
- `colorscheme = :group`: Color scheme (:group, :categorical, or AbstractColorScheme)
- `arc_strokewidth = 1`: Arc border width
- `arc_strokecolor = :black`: Arc border color
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
        inner_radius = 0.8,
        outer_radius = 1.0,
        arc_width = 0.08,
        gap_fraction = 0.03,
        sort_by = :group,
        
        # Ribbons
        ribbon_alpha = 0.6,
        ribbon_tension = 0.5,
        min_ribbon_value = 0,
        
        # Labels
        show_labels = true,
        label_offset = 0.12,
        label_fontsize = 10,
        rotate_labels = true,
        label_color = :black,
        
        # Colors
        colorscheme = :group,
        
        # Arc styling
        arc_strokewidth = 0.5,
        arc_strokecolor = :black,
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
        p.ribbon_alpha, p.ribbon_tension
    ) do cooc, layout, cs, alpha, tension
        
        paths_and_colors = Tuple{Vector{Point2f}, RGBA{Float64}}[]
        
        for ribbon in layout.ribbons
            path = ribbon_path(ribbon, layout.inner_radius; 
                              tension=tension, n_bezier=40)
            
            base_color = resolve_ribbon_color(cs, ribbon, cooc)
            color = RGBA(base_color, alpha)
            
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
    # Compute arc polygons
    arc_data = lift(
        cooc_obs, layout_obs, colorscheme_obs, p.arc_width
    ) do cooc, layout, cs, arc_width
        
        polys_colors = Tuple{Vector{Point2f}, RGB{Float64}}[]
        
        for arc in layout.arcs
            inner_r = layout.outer_radius - arc_width
            outer_r = layout.outer_radius
            
            poly_points = arc_polygon(inner_r, outer_r, arc.start_angle, arc.end_angle; n_points=40)
            color = resolve_arc_color(cs, arc, cooc)
            
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

function _draw_labels!(p::ChordPlotType, cooc_obs, layout_obs)
    # Only draw if show_labels is true
    label_data = lift(
        cooc_obs, layout_obs, p.show_labels, p.label_offset, p.rotate_labels
    ) do cooc, layout, show, offset, rotate
        
        if !show
            return (Point2f[], String[], Float64[], Symbol[], Symbol[])
        end
        
        positions = Point2f[]
        texts = String[]
        rotations = Float64[]
        haligns = Symbol[]
        valigns = Symbol[]
        
        for arc in layout.arcs
            lp = label_position(arc, layout.outer_radius, offset; rotate=rotate)
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
