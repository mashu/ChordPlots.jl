# src/ChordPlots.jl
"""
    ChordPlots

A Makie-based package for creating chord diagrams from co-occurrence data.

# Overview
ChordPlots visualizes relationships between categorical variables using chord diagrams.
Labels are arranged on the outer circle, and ribbons connect labels that co-occur,
with ribbon thickness proportional to co-occurrence frequency.

# Quick Start
```julia
using CairoMakie, ChordPlots, DataFrames

# Create sample data
df = DataFrame(
    V_call = ["IGHV1-2*01", "IGHV1-2*01", "IGHV3-23*01", "IGHV3-23*01"],
    D_call = ["IGHD2-2*01", "IGHD3-10*01", "IGHD2-2*01", "IGHD3-10*01"],
    J_call = ["IGHJ6*01", "IGHJ4*02", "IGHJ6*01", "IGHJ4*02"]
)

# Create chord plot
cooc = cooccurrence_matrix(df, [:V_call, :D_call, :J_call])
fig, ax, plt = chordplot(cooc)
setup_chord_axis!(ax)
fig
```

# Main Types
- [`AbstractChordData`](@ref): Abstract supertype for chord data
- [`CoOccurrenceMatrix`](@ref): Raw co-occurrence counts
- [`NormalizedCoOccurrenceMatrix`](@ref): Frequencies or combined (e.g. mean normalized) data
- [`ChordLayout`](@ref): Computed layout for rendering
- [`GroupColorScheme`](@ref), [`CategoricalColorScheme`](@ref): Color schemes

# Main Functions
- [`cooccurrence_matrix`](@ref): Create co-occurrence matrix from DataFrame
- [`normalize`](@ref), [`mean_normalized`](@ref): Normalize or combine multiple matrices
- [`chordplot`](@ref), [`chordplot!`](@ref): Create chord diagram
- [`compute_layout`](@ref): Compute layout manually
- [`setup_chord_axis!`](@ref): Configure axis for chord display
"""
module ChordPlots

using Reexport

# Dependencies
using DataFrames
using Colors
using GeometryBasics
@reexport using Makie

# Include submodules in dependency order
include("types.jl")
include("cooccurrence.jl")
include("geometry.jl")
include("layout.jl")
include("colors.jl")
include("recipe.jl")

# Export types
export AbstractChordData, AbstractLayout, AbstractGeometry
export CoOccurrenceMatrix, NormalizedCoOccurrenceMatrix, GroupInfo
export ArcSegment, RibbonEndpoint, Ribbon, RibbonPath
export ChordLayout, ChordStyle
export LayoutConfig

# Export color types and functions
export AbstractColorScheme, GroupColorScheme, CategoricalColorScheme, GradientColorScheme
export group_colors, categorical_colors, gradient_colors
export with_alpha, darken, lighten
export resolve_arc_color, resolve_ribbon_color

# Export data functions
export cooccurrence_matrix
export nlabels, ngroups, total_flow, get_group
export filter_by_threshold, filter_top_n, normalize, mean_normalized
export expand_labels
export cooccurrence_values, value_histogram, value_histogram!

# Re-export Base.diff extended for AbstractChordData (no need to export, just document)

# Export layout functions
export compute_layout, filter_ribbons, filter_ribbons_top_n
export label_order
export narcs, nribbons

# Export geometry functions
export arc_points, arc_polygon
export ribbon_path, ribbon_paths
export label_position, label_positions
export arc_span, arc_midpoint, endpoint_span, endpoint_midpoint
export is_self_loop

# Export plot functions
export chordplot, chordplot!
export setup_chord_axis!

end # module
