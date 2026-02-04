# Comparing Matrices

Compare two co-occurrence matrices to visualize what changed between conditions
(e.g., before vs after treatment, wild-type vs knockout).

## Signed Differences with Diverging Colors

Use `diff()` to compute the difference between two matrices and `diff_colors()` (or 
`diverging_colors()`) to show increases vs decreases with a diverging colormap:

```julia
using CairoMakie, ChordPlots, DataFrames

# Two conditions: before and after some intervention
df_before = DataFrame(
    V = ["V1", "V1", "V1", "V2", "V2"],
    D = ["D1", "D1", "D2", "D1", "D2"],
    J = ["J1", "J2", "J1", "J1", "J2"]
)

df_after = DataFrame(
    V = ["V1", "V2", "V2", "V2", "V2"],
    D = ["D1", "D1", "D1", "D2", "D2"],
    J = ["J1", "J1", "J2", "J1", "J2"]
)

cooc_before = cooccurrence_matrix(df_before, [:V, :D, :J])
cooc_after = cooccurrence_matrix(df_after, [:V, :D, :J])

# Compute difference: after - before
# Positive values = connections that INCREASED
# Negative values = connections that DECREASED
d = diff(cooc_after, cooc_before)

# Plot with diverging colors: blue = decrease, red = increase
fig, ax, plt = chordplot(d; colorscheme=diff_colors(d))
setup_chord_axis!(ax)
ax.title = "Changes: After - Before"
fig
```

The colormap defaults to:
- **Blue**: connections that decreased (negative difference)
- **White/neutral**: little or no change
- **Red**: connections that increased (positive difference)

## Customizing Colors

You can customize the diverging color scheme:

```julia
# Custom colors: green for increase, purple for decrease
cs = diverging_colors(d; 
    negative = RGB(0.5, 0.0, 0.5),  # purple for decrease
    neutral = RGB(1.0, 1.0, 1.0),   # white
    positive = RGB(0.0, 0.5, 0.0)   # green for increase
)
chordplot(d; colorscheme=cs)
```

## Absolute Differences

If you only care about the **magnitude** of change (not direction), use `absolute=true`:

```julia
# All differences as positive values (magnitude only)
d_abs = diff(cooc_after, cooc_before; absolute=true)

# Use a sequential colormap like :Reds
chordplot(d_abs; colorscheme=:Reds)
```

## Understanding the Direction

The sign convention is `diff(a, b) = a - b`:

| `diff(after, before)` | Meaning |
|-----------------------|---------|
| Positive values | Connection increased (`after > before`) |
| Negative values | Connection decreased (`after < before`) |
| Zero | No change |

If you want the opposite interpretation (positive = decrease), swap the arguments:

```julia
# Positive = what was lost (before > after)
d_loss = diff(cooc_before, cooc_after)
```

## Combined Workflow

A typical comparison workflow:

```julia
using CairoMakie, ChordPlots, DataFrames

# Load your data
df_control = ...  # control/baseline condition
df_treated = ...  # experimental condition

# Build matrices
cooc_control = cooccurrence_matrix(df_control, [:V, :D, :J])
cooc_treated = cooccurrence_matrix(df_treated, [:V, :D, :J])

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

# Difference (treated - control)
d = diff(cooc_treated, cooc_control)
ax3 = Axis(fig[1,3], title="Difference\n(Blue↓ Red↑)")
chordplot!(ax3, d; colorscheme=diff_colors(d))
setup_chord_axis!(ax3)

fig
```

## Notes

- `diff()` normalizes both matrices before computing differences, so results are 
  in frequency space (fractions, not raw counts)
- Matrices can have different label sets; they are automatically aligned to the 
  union of all labels
- The result is a `NormalizedCoOccurrenceMatrix` (does not sum to 1 since it's a 
  difference, not a probability distribution)
- Arc widths in the difference plot are based on **absolute** difference magnitudes
  (so both increases and decreases appear as thick ribbons if the change is large)
