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

## What values should you put in `matrix`?

- **Counts**: raw co-occurrence counts
- **Frequencies**: counts normalized however you prefer
- **Scores**: e.g. mutual information, correlations, signed differences, etc.

ChordPlots will **respect your values** and only map them to visual properties (width/opacity/colors)
according to the plot settings you choose.
