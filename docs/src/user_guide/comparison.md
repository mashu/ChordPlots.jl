# Comparing Matrices

Compare two co-occurrence matrices to visualize what changed between conditions
(e.g., before vs after treatment, wild-type vs knockout).

## Signed Differences with Diverging Colors

Provide a **signed** weight matrix (computed externally) and use `diff_colors()` (or
`diverging_colors()`) to show increases vs decreases with a diverging colormap:

```julia
using CairoMakie, ChordPlots

# Signed weights (example): positive = increased, negative = decreased
matrix = [ 0.0  0.4 -0.1;
           0.4  0.0  0.2;
          -0.1  0.2  0.0 ]
labels = ["A", "B", "C"]
groups = [GroupInfo{String}(:G, labels, 1:3)]
d = CoOccurrenceMatrix(matrix, labels, groups)

# Plot with diverging colors: blue = decrease, red = increase
fig, ax, plt = chordplot(d; colorscheme=diff_colors(d))
setup_chord_axis!(ax)
ax.title = "Changes: After - Before"
fig
```

The colormap uses the same diverging scale for both ribbons and arcs:

**Ribbons** (connections):
- **Blue**: connections that decreased (negative difference)
- **White/neutral**: little or no change
- **Red**: connections that increased (positive difference)

**Arcs** (labels):
- **Blue arc**: label with overall **depleted** connections (net negative change)
- **White arc**: label with balanced changes (net ≈ zero)
- **Red arc**: label with overall **enriched** connections (net positive change)

This makes it easy to see at a glance which genes/labels gained or lost connections overall.

## Customizing Colors

You can customize the diverging color scheme:

```julia
using Colors  # for RGB

# Custom colors: green for enrichment, purple for depletion
cs = diverging_colors(d; 
    negative = RGB(0.5, 0.0, 0.5),  # purple for depletion
    neutral = RGB(1.0, 1.0, 1.0),   # white
    positive = RGB(0.0, 0.5, 0.0)   # green for enrichment
)
chordplot(d; colorscheme=cs)
```

## Absolute Differences

If you only care about the **magnitude** of change (not direction), compute absolute
values externally (e.g. `abs.(matrix)`):

```julia
matrix_abs = abs.(matrix)
d_abs = CoOccurrenceMatrix(matrix_abs, labels, groups)
chordplot(d_abs; colorscheme=:Reds)
```

## Understanding the Direction

The sign convention is whatever you choose when preparing your signed weights.

## Combined Workflow

A typical comparison workflow (all preprocessing external):

```julia
using CairoMakie, ChordPlots

cooc_control = CoOccurrenceMatrix(mat_control, labels, groups)
cooc_treated = CoOccurrenceMatrix(mat_treated, labels, groups)

# Create comparison figure
fig = Figure(size=(1200, 500))

# Original control
ax1 = Axis(fig[1,1], title="Control")
chordplot!(ax1, cooc_control)
setup_chord_axis!(ax1)

# Treated condition  
ax2 = Axis(fig[1,2], title="Treated")
chordplot!(ax2, cooc_treated)
setup_chord_axis!(ax2)

# Difference (treated - control), computed externally as signed weights
d = CoOccurrenceMatrix(mat_treated .- mat_control, labels, groups)
ax3 = Axis(fig[1,3], title="Difference\n(Blue↓ Red↑)")
chordplot!(ax3, d; colorscheme=diff_colors(d))
setup_chord_axis!(ax3)

fig
```

## Notes

- ChordPlots does not normalize or align datasets for you; decide on label sets and
  any normalization in your preprocessing pipeline.
