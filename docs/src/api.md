# API Reference

Complete reference for all exported functions and types.

## Plotting

```@docs
chordplot
setup_chord_axis!
```

`chordplot!(ax, cooc; kwargs...)` is the in-place form of [`chordplot`](@ref) and accepts the same keyword arguments.

## Data Types

```@docs
AbstractChordData
CoOccurrenceMatrix
CoOccurrenceLayers
GroupInfo
```

## Data Exploration

Inspect the distribution of values to choose thresholds (e.g. `min_ribbon_value`):

```@docs
cooccurrence_values
value_histogram
value_histogram!
```

## Layout

```@docs
compute_layout
filter_ribbons
filter_ribbons_top_n
label_order
LayoutConfig
ChordLayout
```

## Opacity Configuration

```@docs
ComponentAlpha
ValueScaling
```

## Color Schemes

```@docs
group_colors
categorical_colors
gradient_colors
diverging_colors
diff_colors
GroupColorScheme
CategoricalColorScheme
GradientColorScheme
DivergingColorScheme
```

## Color Utilities

```@docs
with_alpha
darken
lighten
```

## Geometry

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
```

## Accessors

```@docs
nlabels
ngroups
total_flow
abs_total_flow
n_layers
narcs
nribbons
get_group
arc_span
arc_midpoint
endpoint_span
endpoint_midpoint
is_self_loop
```
