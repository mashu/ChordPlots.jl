# Filtering and Data Management

Filter data to reduce clutter and focus on important relationships.

## Choosing a Threshold

When filtering by value (e.g. `filter_by_threshold` or `min_ribbon_value`), it helps to inspect the distribution of co-occurrence values first. Use the built-in value histogram:

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
cooc_filtered = filter_by_threshold(cooc, 5)
# or chordplot!(ax, cooc; min_ribbon_value = 5)
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

**What this shows:** This example demonstrates filtering using `filter_top_n()`, which keeps only the top 8 labels by total flow (sum of all connections). The original dataset had many more labels (A1-A8, B1-B5, C1-C4), but only the 8 most connected labels are displayed. Filtering helps focus attention on the strongest relationships and is particularly useful when working with large datasets where many labels have only weak connections that would otherwise create visual clutter.

## Filtering Before Plotting

Filter the data before plotting:

```julia
# Keep only top N labels by total flow
cooc_top = filter_top_n(cooc, 15)

# Filter by minimum co-occurrence value
cooc_filtered = filter_by_threshold(cooc, 5)

# Normalize to frequencies
cooc_norm = normalize(cooc)
```

## Filtering Ribbons

Filter ribbons in the layout:

```julia
layout = compute_layout(cooc)

# Filter by minimum value
layout_filtered = filter_ribbons(layout, 5)

# Keep only top N ribbons
layout_top = filter_ribbons_top_n(layout, 20)
```
