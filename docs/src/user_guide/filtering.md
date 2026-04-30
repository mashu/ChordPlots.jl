# Filtering

## Thresholds from the value distribution

Inspect values before picking cutoffs:

```julia
# Single matrix: histogram of all co-occurrence values (upper triangle, non-zero)
value_histogram(cooc)

# Or on an existing axis
value_histogram!(ax, cooc; bins = 30)
```

For multiple matrices (e.g. several donors), pass a vector to use the combined distribution:

```julia
value_histogram([cooc1, cooc2, cooc3])
```

You can also get the raw values and plot them yourself:

```julia
vals = cooccurrence_values(cooc)
# Use vals to pick a threshold, then:
chordplot!(ax, cooc; min_ribbon_value = 5)
```

## Arcs (`min_arc_flow`)

Drop weak arcs (and their labels):

```julia
chordplot!(ax, cooc; min_arc_flow = 10)
```

Example: **[Gallery — Filtered](../examples/gallery.md#Filtered)**.

## Ribbon layout filters

Inspect or trim ribbons without changing `cooc`:

```julia
layout = compute_layout(cooc)

# Filter by minimum value
layout_filtered = filter_ribbons(layout, 5)

# Keep only top N ribbons
layout_top = filter_ribbons_top_n(layout, 20)
```
