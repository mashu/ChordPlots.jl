# Creating Co-occurrence Data

You pass a weight matrix (counts, frequencies, scores, etc.); ChordPlots does not normalize or build matrices from tables.

## Matrices and groups

Use [`groups_from`](@ref) unless you already have [`GroupInfo`](@ref) ranges worked out:

```julia
matrix = [0 10 2;
          10 0 3;
          2  3 0]

# Build the flat label vector and the group structure together
labels, groups = groups_from((:Group1 => ["A", "B"], :Group2 => ["C"]))
cooc = CoOccurrenceMatrix(matrix, labels, groups)
```

Explicit constructor:

```julia
labels = ["A", "B", "C"]
groups = [
    GroupInfo{String}(:Group1, ["A", "B"], 1:2),
    GroupInfo{String}(:Group2, ["C"],      3:3),
]
cooc = CoOccurrenceMatrix(matrix, labels, groups)
```

## Layers (e.g. one matrix per donor)

Stack matrices as `layers[i, j, ℓ]` (same `n` and comparable scale). Ribbon placement:

| `layers_pair_span` | Effect |
|--------------------|--------|
| `:per_layer` | Each layer partitions arcs independently (endpoints can shift). |
| `:fixed_pairs` | Fixed arc segment per pair from the aggregate; donors stay inside it. |
| `:stack_layers` | Fixed segment per pair; donors split it (stacked). |

Use lower ribbon `alpha` (and/or `alpha_by_value`) when many layers overlap.

```julia
layers = cat([0.0 0.3; 0.0 0.0], [0.0 0.2; 0.0 0.0]; dims=3)  # 2×2×2, upper triangle only
cooc = CoOccurrenceLayers(layers, ["A", "B"], [GroupInfo{String}(:G, ["A", "B"], 1:2)])
# cooc.matrix is the sum over layers (used for net flow on arcs, etc.)
```

Example with several donors: **[Multiple layers](../examples/cooccurrence_layers.md)**.

**Values:** anything nonnegative you define (counts, normalized frequencies, scores). ChordPlots maps them to thickness/opacity/color via kwargs, not via its own normalization.
