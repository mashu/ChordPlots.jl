# API Reference

Complete reference for the package's exported types and functions, grouped by purpose.

## Plotting

The single entry point. `chordplot` builds a new figure; `chordplot!` draws into an
existing axis. Both accept the same keyword arguments — see the `chordplot`
docstring for the full list.

```@docs
chordplot
setup_chord_axis!
chord_theme
```

`chordplot!(ax, cooc; kwargs...)` is the in-place form of [`chordplot`](@ref) and accepts the same keyword arguments.

## Data Types

User-facing data containers. `groups_from` is the recommended way to assemble a
labelled-group structure without bookkeeping the per-group index ranges yourself.

```@docs
AbstractChordData
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

Pre-built and customisable colour schemes for arcs and ribbons.

```@docs
group_colors
gradient_colors
diverging_colors
diff_colors
GroupColorScheme
CategoricalColorScheme
GradientColorScheme
DivergingColorScheme
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
