# Creating Co-occurrence Data

ChordPlots is a plotting package: **you provide the data** (counts, frequencies, scores, etc.).
The package does not assume any normalization scheme and does not compute co-occurrence matrices
from tabular data.

## From Raw Matrices (recommended)

Create a `CoOccurrenceMatrix` directly from your preprocessed weights:

```julia
matrix = [0 10 2;
          10 0 3;
          2  3 0]
labels = ["A", "B", "C"]
groups = [
    GroupInfo{String}(:Group1, ["A", "B"], 1:2),
    GroupInfo{String}(:Group2, ["C"], 3:3),
]

cooc = CoOccurrenceMatrix(matrix, labels, groups)
```

## Several layers (e.g. one matrix per donor)

If each observation (donor, batch, etc.) has its own `n×n` matrix in a **common value range**,
pack them as `layers[i, j, ℓ]`. The layout allocates a **bundle** for each pair from the sum of
**absolute** values, then **splits** the bundle: each layer’s segment width is proportional to its
share of that sum, so per-donor **thickness** encodes |value| (e.g. link strengths differ slightly
between donors). Ribbons are drawn in order; use **translucent** ribbon `alpha` to stack or opaque
to read each slice. Lower `alpha` also helps if you draw **repeated** ribbons on the same path (see example docs).

```julia
layers = cat([0.0 0.3; 0.0 0.0], [0.0 0.2; 0.0 0.0]; dims=3)  # 2×2×2, upper triangle only
cooc = CoOccurrenceLayers(layers, ["A", "B"], [GroupInfo{String}(:G, ["A", "B"], 1:2)])
# cooc.matrix is the sum over layers (used for net flow on arcs, etc.)
```

For a generated **single-plot** showcase over the **union** of labels across donors, see **[Multiple layers (donors)](../examples/cooccurrence_layers.md)**.

## What values should you put in `matrix`?

- **Counts**: raw co-occurrence counts
- **Frequencies**: counts normalized however you prefer
- **Scores**: e.g. mutual information, correlations, signed differences, etc.

ChordPlots will **respect your values** and only map them to visual properties (width/opacity/colors)
according to the plot settings you choose.
