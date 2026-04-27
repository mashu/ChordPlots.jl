# Multiple layers (per donor): V/D/J example

When you have **one co-occurrence matrix per donor** (or batch) in a **shared numeric range**, use `CoOccurrenceLayers`: `layers[i, j, ℓ]` is the strength for pair `(i, j)` in layer `ℓ`.

This example uses V/D/J-style labels (`IGHV…`, `IGHD…`, `IGHJ…`) with distinct categories. Ribbons are colored by category (V, D, J), and per-donor variation is encoded by different ribbon slice widths for each donor.

**Layout** sizes **arcs** from an **aggregate** (here `aggregate = :mean`, so arcs reflect a typical donor), then lays out **ribbons per donor** starting from the same arc origin for each label. This way all donors “start at the bottom” of the arc, and only the donor-specific links and strengths change.

```@raw html
<img src="../assets/examples/cooccurrence_layers.png" alt="Chord diagram: V/D/J per-donor layers" style="max-width: 780px;"/>
```

## Minimal code (V/D/J groups)

```julia
using CairoMakie, ChordPlots, Random

labels = [
    "IGHV1-2", "IGHV1-3", "IGHV2-8",
    "IGHD3-3", "IGHD3-10", "IGHD4-4",
    "IGHJ1", "IGHJ4", "IGHJ6",
]
groups = [
    GroupInfo{String}(:V, labels[1:3], 1:3),
    GroupInfo{String}(:D, labels[4:6], 4:6),
    GroupInfo{String}(:J, labels[7:9], 7:9),
]

Random.seed!(1)
L = 10
n = length(labels)
layers = zeros(Float64, n, n, L)
for ℓ in 1:L
    layers[1, 4, ℓ] = max(0.0, 0.30 + 0.12 * randn())  # V1-2—D3-3
    layers[2, 5, ℓ] = max(0.0, 0.22 + 0.10 * randn())  # V1-3—D3-10
    layers[3, 6, ℓ] = max(0.0, 0.18 + 0.09 * randn())  # V2-8—D4-4
    layers[4, 8, ℓ] = max(0.0, 0.20 + 0.10 * randn())  # D3-3—J4
    layers[5, 9, ℓ] = max(0.0, 0.16 + 0.09 * randn())  # D3-10—J6
    layers[6, 7, ℓ] = max(0.0, 0.14 + 0.08 * randn())  # D4-4—J1
    # symmetry
    for j in 2:n, i in 1:(j - 1)
        layers[j, i, ℓ] = layers[i, j, ℓ]
    end
end

cooc = CoOccurrenceLayers(layers, labels, groups; aggregate = :mean)

fig = Figure(size = (600, 600))
ax = Axis(fig[1, 1]; title = "Per-donor V/D/J ribbons (arcs from mean)")
chordplot!(
    ax, cooc;
    colorscheme = group_colors(cooc),
    # Wider opacity range: very faint single-donor slices, strong overlap buildup
    alpha_by_value = ValueScaling(enabled = true, components = (ribbons = true, arcs = false, labels = false), min_alpha = 0.03),
    alpha = ComponentAlpha(ribbons = 0.25, arcs = 0.95, labels = 1.0),
    layers_pair_span = :fixed_pairs,
)
setup_chord_axis!(ax)
fig
```

The full V/D/J showcase figure is Example 7 in `docs/generate_examples.jl`.
