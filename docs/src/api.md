# API Reference

Complete reference for all exported functions and types.

## Main Functions

```@docs
cooccurrence_matrix
chordplot
setup_chord_axis!
compute_layout
```

## Data Types

```@docs
AbstractChordData
CoOccurrenceMatrix
NormalizedCoOccurrenceMatrix
```

## Data Management

```@docs
filter_top_n
filter_by_threshold
normalize
mean_normalized
expand_labels
```

## Comparison

```@docs
Base.diff
```

## Data Exploration

Inspect the distribution of co-occurrence values to choose thresholds (e.g. `min_ribbon_value`, `filter_by_threshold`):

```@docs
cooccurrence_values
value_histogram
value_histogram!
```

## Layout Functions

```@docs
filter_ribbons
filter_ribbons_top_n
label_order
LayoutConfig
ChordLayout
```

## Color Functions

```@docs
group_colors
gradient_colors
diverging_colors
diff_colors
with_alpha
darken
lighten
GroupColorScheme
CategoricalColorScheme
GradientColorScheme
DivergingColorScheme
```

**`categorical_colors(n::Int; palette=:default)`** - Create n distinguishable colors using Makie's default categorical palette (same as AlgebraOfGraphics uses - Wong colors, colorblind-friendly).

## Geometry Functions

```@docs
arc_points
arc_polygon
ribbon_path
ribbon_paths
label_position
label_positions
ArcSegment
RibbonEndpoint
Ribbon
RibbonPath
```

## Types

```@docs
GroupInfo
```

## Utility Functions

These functions are exported but don't have separate docstrings:

- `nlabels(cooc)` - Number of labels in co-occurrence matrix
- `ngroups(cooc)` - Number of groups  
- `total_flow(cooc, label_idx)` - Total flow for a label (sum of all connections)
- `get_group(cooc, label_idx)` - Get group symbol for a label
- `narcs(layout)` - Number of arcs in layout
- `nribbons(layout)` - Number of ribbons in layout
- `arc_span(arc)` - Span angle of an arc
- `arc_midpoint(arc)` - Midpoint angle of an arc
- `endpoint_span(endpoint)` - Span of a ribbon endpoint
- `endpoint_midpoint(endpoint)` - Midpoint of a ribbon endpoint
- `is_self_loop(ribbon)` - Check if ribbon is a self-loop
- `resolve_arc_color(scheme, arc, cooc)` - Resolve color for an arc
- `resolve_ribbon_color(scheme, ribbon, cooc)` - Resolve color for a ribbon
- `chordplot!(ax, cooc; kwargs...)` - In-place version of `chordplot`
