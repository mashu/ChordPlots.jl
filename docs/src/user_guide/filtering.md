# Filtering and Data Management

Filter data to reduce clutter and focus on important relationships.

## Choosing a Threshold

When filtering by value (e.g. `min_ribbon_value`), it helps to inspect the distribution of values first. Use the built-in value histogram:

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

## Filtering Small Segments

When you have many labels with small co-occurrence values, they can cluster together and overlap:

```julia
chordplot!(ax, cooc;
    min_arc_flow = 10  # Only show arcs with total flow >= 10
)
```

This removes both the arc and its label, reducing clutter.

```@raw html
<img src="assets/examples/filtered.png" alt="Filtered Data" style="max-width: 600px;"/>
```

**What this shows:** Filtering helps focus attention on the strongest relationships and is particularly useful when working with large datasets where many labels have only weak connections that would otherwise create visual clutter.

## Filtering Ribbons

Filter ribbons in the layout:

```julia
layout = compute_layout(cooc)

# Filter by minimum value
layout_filtered = filter_ribbons(layout, 5)

# Keep only top N ribbons
layout_top = filter_ribbons_top_n(layout, 20)
```
