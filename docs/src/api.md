# API Reference

Exported types and functions by topic. Full kwargs for plotting live on [`chordplot`](@ref).

## Plotting

[`chordplot`](@ref) can create a figure or use `chordplot!` in an existing axis.

```@docs
chordplot
setup_chord_axis!
chord_theme
```

## Data Types

Use [`groups_from`](@ref) to build label lists and group ranges in one step.

```@docs
AbstractChordData
AbstractLayout
AbstractGeometry
CoOccurrenceMatrix
CoOccurrenceLayers
GroupInfo
groups_from
```

## Data Exploration

Inspect the distribution of values to choose thresholds (e.g. `min_ribbon_value`):

```@docs
cooccurrence_values
value_histogram
value_histogram!
```

## Layout

Compute and post-process arc/ribbon layouts independently of the recipe.

```@docs
compute_layout
filter_ribbons
filter_ribbons_top_n
label_order
LayoutConfig
ChordLayout
```

## Opacity Configuration

Bundle component-level opacity and value-scaling settings to pass via `alpha=` /
`alpha_by_value=`.

```@docs
ComponentAlpha
ValueScaling
```

## Color Schemes

Pre-built and customisable colour schemes for arcs and ribbons. To convert a
scheme + element into a concrete colour, use the `resolve_*` helpers (these are
how the recipe colours each ribbon and arc internally).

```@docs
AbstractColorScheme
group_colors
gradient_colors
diverging_colors
diff_colors
GroupColorScheme
CategoricalColorScheme
GradientColorScheme
DivergingColorScheme
resolve_arc_color
resolve_ribbon_color
```

`categorical_colors(n::Int; palette=:default)` returns a [`CategoricalColorScheme`](@ref) with `n` distinct colours. The default palette is the Wong colourblind-friendly palette (deduplicated to 7 unique hues); for `n` larger than the palette ChordPlots falls back to perceptually distinguishable colours via `Colors.distinguishable_colors`. It is not listed in the `@docs` block above because Makie also exports a function of the same name, so Documenter resolves the binding to Makie rather than ChordPlots; the local methods are still available via `ChordPlots.categorical_colors`.

## Color Utilities

```@docs
with_alpha
darken
lighten
```

## Geometry

Lower-level primitives reused by the recipe; useful for custom drawing or
inspection. Internal envelope helpers (`ChordPlots.widen_ribbon_endpoint`,
`ChordPlots.envelope_widen_scale`, `ChordPlots.ribbon_widened`,
`ChordPlots.ribbon_for_envelope_draw`, `ChordPlots.ribbon_envelope_ring_polygon`)
are intentionally unexported.

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

Lightweight introspection helpers for chord data and layouts.

```@docs
nlabels
ngroups
total_flow
abs_total_flow
nlayers
narcs
nribbons
get_group
arc_span
arc_midpoint
endpoint_span
endpoint_midpoint
is_self_loop
```
