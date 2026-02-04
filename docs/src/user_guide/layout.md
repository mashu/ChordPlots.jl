# Layout Configuration

Advanced control over chord diagram layout.

## Custom Layout

Compute layouts manually for advanced control:

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

**What is a custom layout?** A custom layout allows you to control how labels are arranged around the circle, how arcs are sized, and the spacing between elements. This gives you fine-grained control over the visual appearance beyond the default settings.

```@raw html
<img src="assets/examples/layout.png" alt="Custom Layout" style="max-width: 600px;"/>
```

**What this shows:** This example demonstrates several layout customizations applied together:
- **`sort_by=:value`** - Labels are sorted by their total flow (largest first), so the most connected labels get the largest arcs and appear first. Compare this to the basic example where labels are sorted by group - here, the most important labels are visually emphasized.
- **`inner_radius=0.85`** - Ribbons start closer to the center (default is 0.92), creating more space between ribbon endpoints and the outer circle. This gives a different visual balance and can help when you have many connections.
- **`gap_fraction=0.05`** - Slightly larger gaps between arc segments (default is 0.03), making individual arcs more distinct and easier to identify.

These settings work together to create a layout that emphasizes the most important labels and creates a different visual hierarchy compared to the default group-sorted layout.

## Sorting Options

- `:group` - Keep groups together, sort within groups by value (default)
- `:value` - Sort all labels by total flow (descending)
- `:none` - Use original order

## Consistent Ordering Across Multiple Plots

When comparing chord diagrams from different data sources (e.g. different samples or donors), label order should be consistent so viewers can compare positions. There are two approaches:

### Approach 1: `expand_labels` (show all labels, missing ones as empty arcs)

Use `expand_labels` when you want **all labels to appear in both plots**, even if a label only exists in one matrix. Missing labels appear as empty arcs (zero flow, no ribbons).

```julia
# Two matrices with different genes
cooc_A = cooccurrence_matrix(df_A, [:V_call, :J_call])
cooc_B = cooccurrence_matrix(df_B, [:V_call, :J_call])

# Expand to union of labels (missing labels get zero flow → empty arcs)
exp_A, exp_B = expand_labels(cooc_A, cooc_B)

# Now both have the same labels; plot with consistent positions
order = label_order(exp_A)  # or label_order(exp_B) — same labels
chordplot!(ax1, exp_A; label_order = order)
chordplot!(ax2, exp_B; label_order = order)
```

### Approach 2: `label_order` only (each plot shows only its own labels)

Use `label_order` alone when you want each plot to show **only its own labels**, but with shared labels in consistent positions. Labels unique to one matrix won't appear in the other plot.

```julia
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
