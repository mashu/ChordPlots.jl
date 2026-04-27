# src/ChordPlots.jl
"""
    ChordPlots

A Makie-based package for creating chord diagrams from co-occurrence data.

# Overview
ChordPlots visualizes relationships between categorical variables using chord diagrams.
Labels are arranged on the outer circle, and ribbons connect labels that co-occur,
with ribbon thickness proportional to the weights you provide.

# Quick Start
```julia
using CairoMakie, ChordPlots

# Provide your own preprocessed weight matrix
matrix = [0 3 1;
          3 0 2;
          1 2 0]
labels = ["A", "B", "C"]
groups = [GroupInfo{String}(:G, labels, 1:3)]
cooc = CoOccurrenceMatrix(matrix, labels, groups)
fig, ax, plt = chordplot(cooc)
setup_chord_axis!(ax)
fig
```

# Main Types
- [`AbstractChordData`](@ref): Abstract supertype for chord data
- [`CoOccurrenceMatrix`](@ref), [`CoOccurrenceLayers`](@ref): User-supplied weights (single matrix or one layer per donor/condition)
- [`ChordLayout`](@ref): Computed layout for rendering
- [`GroupColorScheme`](@ref), [`CategoricalColorScheme`](@ref): Color schemes

# Main Functions
- [`chordplot`](@ref), [`chordplot!`](@ref): Create chord diagram
- [`compute_layout`](@ref): Compute layout manually
- [`setup_chord_axis!`](@ref): Configure axis for chord display
"""
module ChordPlots

using Reexport

# Dependencies
using Colors
using GeometryBasics
@reexport using Makie

# Include submodules in dependency order
include("types.jl")
include("geometry.jl")
include("layout.jl")
include("colors.jl")
include("value_utils.jl")
include("recipe.jl")

# Export types
export AbstractChordData, AbstractLayout, AbstractGeometry
export CoOccurrenceMatrix, CoOccurrenceLayers, GroupInfo
export ArcSegment, RibbonEndpoint, Ribbon
export ChordLayout
export LayoutConfig
export ComponentAlpha, ValueScaling

# Export color types and functions
export AbstractColorScheme, GroupColorScheme, CategoricalColorScheme, GradientColorScheme, DivergingColorScheme
export group_colors, categorical_colors, gradient_colors, diverging_colors, diff_colors
export with_alpha, darken, lighten
export resolve_arc_color, resolve_ribbon_color

export nlabels, ngroups, n_layers, total_flow, abs_total_flow, get_group
# Re-export convenience helpers that do not impose semantics on weights
export cooccurrence_values
export value_histogram, value_histogram!

# Export layout functions
export compute_layout, filter_ribbons, filter_ribbons_top_n
export label_order
export narcs, nribbons

# Export geometry functions
export arc_points, arc_polygon
export ribbon_path, ribbon_paths
export widen_ribbon_endpoint, envelope_widen_scale, ribbon_widened, ribbon_for_envelope_draw, ribbon_envelope_ring_polygon
export label_position, label_positions
export arc_span, arc_midpoint, endpoint_span, endpoint_midpoint
export is_self_loop

# Export plot functions
export chordplot, chordplot!
export setup_chord_axis!

end # module
