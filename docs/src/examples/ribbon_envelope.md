# Ribbon envelope

You can draw a **wider, translucent band** around each **mean** (or primary) ribbon by passing two matrices, `ribbon_envelope_low` and `ribbon_envelope_high`, of the same size as the weight matrix in your `CoOccurrenceMatrix`. For each link between labels *i* and *j* the recipe uses the entry at `minmax(i, j)` and sets the band width from the value span `high - low`. You decide what those numbers mean (e.g. range from your donors, min–max, mean ± spread in the same units as the plotted weights); the package does not compute statistics for you.

**Default `ribbon_envelope_mode = :ring`:** the uncertainty is a **ring** (only the **margin** between the mean outline and the widened outline is filled), not a second full-width ribbon under a solid mean. **Default `ribbon_envelope_bands = 2`:** the margin is split into an **inner** and **outer** band with `ribbon_envelope_lighten_inner` and `ribbon_envelope_lighten` (more toward white on the outside) so the interval reads as a **graded** edge, not a second chord. **Default `ribbon_envelope_mean = :hollow`** (alias `:tunnel`): the **mean** is a **stroke in the link color** plus a **faint** fill in the same hue (`ribbon_envelope_mean_faint_fill`, default 0.32 of the ribbon’s fill alpha) so the estimate still reads as a **single object inside** the confidence margin—not an empty cutout, and not a second solid slab. Set **`ribbon_envelope_mean_faint_fill = 0`** for a fully **empty** tunnel. Use `ribbon_envelope_mean = :solid` for a fully filled mean. Use `ribbon_envelope_mode = :fill` for the older full-widened fill under a solid mean.

The figure below is produced by `docs/generate_examples.jl` as `ribbon_envelope.png` (V/D/J toy data, `ValueScaling(false)` on ribbons in the static PNG).

```@raw html
<img src="../assets/examples/ribbon_envelope.png" alt="Chord diagram with ribbon envelope" style="max-width: 600px;"/>
```

## Opacity, `alpha_by_value`, and the envelope

These are **independent** in the implementation:

- **`alpha` / `ValueScaling` (`alpha_by_value`)** applies to the **mean** stroke/fill (and to arcs/labels, depending on `components=...`). With **`:hollow`**, the stroke still follows the same opacities. Weaker links get **lower** opacity on that layer when scaling is enabled.
- The **envelope** is drawn *under* the mean. It uses a **fixed** fill opacity `ribbon_envelope_alpha` and is **not** scaled by link strength. For **two** bands, tune **`ribbon_envelope_lighten_inner`** (stronger, next to the mean) and **`ribbon_envelope_lighten`** (paler outside).
- **`ribbon_envelope_stroke`**: optional **white** hairline on a **:solid** mean with an envelope. Ignored for **:hollow**; use **`ribbon_envelope_mean_strokewidth`** for the tunnel outline.

If a **weak** link’s mean ribbon is dim from `alpha_by_value` but the band still looks strong, use **`alpha_by_value = ValueScaling(false)`** for a static figure, or lower `ribbon_envelope_alpha`, raise `ribbon_envelope_lighten`, or filter links.

## Minimal code (tunnel + band)

```julia
chordplot!(ax, cooc;
    ribbon_envelope_low = lo,
    ribbon_envelope_high = hi,
    ribbon_envelope_bands = 2,
    ribbon_envelope_mean = :tunnel,              # or :hollow; stroke + faint same-hue fill
    ribbon_envelope_mean_faint_fill = 0.32,    # 0 = fully empty tube
    alpha = ComponentAlpha(ribbons = 0.9, arcs = 0.95, labels = 1.0),
    alpha_by_value = ValueScaling(false),
)
```

Full matrices and layout options: `docs/generate_examples.jl` (V/D/J block).
