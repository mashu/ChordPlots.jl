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
pack them as `layers[i, j, ℓ]`.

For visualization you can choose how per-donor ribbons attach to arcs:
- `layers_pair_span = :per_layer`: each donor independently partitions each arc (pair endpoints may shift)
- `layers_pair_span = :fixed_pairs`: each pair gets a fixed arc segment from the aggregate; donors draw within it
- `layers_pair_span = :stack_layers`: each pair gets a fixed arc segment and donors **partition** it (true stacked decomposition)

Use **translucent** ribbon `alpha` (or `alpha_by_value`) when drawing many donors so overlap remains readable.

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
