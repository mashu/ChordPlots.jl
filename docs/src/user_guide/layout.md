# Layout Configuration

## `LayoutConfig` / `compute_layout`

```julia
config = LayoutConfig(
    inner_radius = 0.75,    # Ribbon attachment radius
    outer_radius = 1.0,     # Arc outer radius
    gap_fraction = 0.05,    # Gap between arcs
    arc_scale = 1.0,        # Fraction of width for arcs; < 1 adds gaps between arcs/labels
    ribbon_width_power = 1.0, # Exponent for ribbon thickness; > 1 makes thick vs thin more dramatic
    start_angle = π/2,      # Start at top (0 = right)
    direction = 1,          # 1 = counterclockwise, -1 = clockwise
    sort_by = :group        # :group, :value, or :none
)

layout = compute_layout(cooc, config)
```

- **`gap_fraction`**: Fraction of the full circle reserved for gaps (e.g. `0.05` → 5% gap, 95% for arcs).
- **`arc_scale`**: Scale factor for the arc (content) portion only; the rest is gap. With `arc_scale = 1.0` the arcs use all of the non-gap space; with `arc_scale < 1` (e.g. `0.7`) arcs use less and gaps grow. So it does not conflict with `gap_fraction` — it adds extra separation on top of it.
- **`ribbon_width_power`**: Exponent for ribbon thickness: `(value/flow)^power`. Use > 1 (e.g. `1.5` or `2`) to make thick ribbons thicker and thin ones thinner.

Same options exist as keywords on [`chordplot`](@ref). Doc example (`sort_by = :value`, tighter radii): **[Gallery — Layout by value](../examples/gallery.md#Layout-by-value)**.

## Sorting

- `:group` - Keep groups together, sort within groups by value (default)
- `:value` - Sort all labels by total flow (descending)
- `:none` - Use original order

## Consistent Ordering Across Multiple Plots

When comparing chord diagrams from different data sources, label order should be consistent so viewers can compare positions. Use `label_order` to compute a unified order across multiple matrices; then pass that order into each plot. Each plot will show its own labels, but shared labels will appear in consistent positions.

```julia
# Two user-preprocessed matrices
cooc_A = CoOccurrenceMatrix(mat_A, labels_A, groups_A)
cooc_B = CoOccurrenceMatrix(mat_B, labels_B, groups_B)

# Get a unified order (union of labels, sorted by combined flow)
order = label_order(cooc_A, cooc_B)

# Plot with same positions for shared labels; unique labels only in their plot
chordplot!(ax1, cooc_A; label_order = order)
chordplot!(ax2, cooc_B; label_order = order)
```

### Single-Matrix Order (reuse from one plot)

When matrices have the same labels, simply reuse the order from one:

```julia
# First plot
fig1, ax1, plt1 = chordplot(cooc_A)

# Extract and reuse its order for a comparable second plot
order = label_order(cooc_A)
fig2, ax2, plt2 = chordplot(cooc_B; label_order = order)
```

### Options for `label_order` with Multiple Matrices

- **`sort_by`**: `:group` (default), `:value`, or `:none` — how labels are sorted.
- **`include_all`**: If `true` (default), include **all** labels from any matrix. If `false`, include only labels present in **all** matrices (intersection).

```julia
# Only labels that exist in BOTH matrices
order_common = label_order(cooc_A, cooc_B; include_all = false)

# Sort by total combined flow across both
order_by_value = label_order(cooc_A, cooc_B; sort_by = :value)
```

## Accessing Layout Data

```julia
layout = compute_layout(cooc)

# Get information
narcs(layout)      # Number of arcs
nribbons(layout)   # Number of ribbons

# Access arcs
for arc in layout.arcs
    println("Label $(arc.label_idx): $(arc.start_angle) to $(arc.end_angle)")
end

# Access ribbons
for ribbon in layout.ribbons
    println("Connection: $(ribbon.source.label_idx) → $(ribbon.target.label_idx), value: $(ribbon.value)")
end
```
