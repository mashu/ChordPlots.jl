# Creating Co-occurrence Data

There are several ways to create co-occurrence data for chord diagrams.

## From DataFrames

The most common approach is to use a DataFrame where each row represents an observation:

```julia
df = DataFrame(
    Group1 = ["A", "A", "B", "B", "C"],
    Group2 = ["X", "Y", "X", "Y", "X"],
    Group3 = ["1", "1", "2", "2", "1"]
)

cooc = cooccurrence_matrix(df, [:Group1, :Group2, :Group3])
```

The function automatically:
- Extracts unique labels from each column
- Groups labels by their source column
- Counts co-occurrences between labels from different groups
- Creates a symmetric co-occurrence matrix

## From Raw Matrices

For more control, create a `CoOccurrenceMatrix` directly:

```julia
matrix = [10 5 2; 5 8 3; 2 3 6]
labels = ["A", "B", "C"]
groups = [
    GroupInfo{String}(:Group1, ["A", "B"], 1:2),
    GroupInfo{String}(:Group2, ["C"], 3:3)
]

cooc = CoOccurrenceMatrix(matrix, labels, groups)
```

## Handling Missing Values

Missing values are automatically skipped:

```julia
df = DataFrame(
    A = ["a1", missing, "a2"],
    B = ["b1", "b1", missing]
)
cooc = cooccurrence_matrix(df, [:A, :B])  # Handles missing gracefully
```

## Normalization and combined data

Convert counts to frequencies (matrix sums to 1):

```julia
cooc = cooccurrence_matrix(df, [:V, :D, :J])
cooc_norm = normalize(cooc)  # returns NormalizedCoOccurrenceMatrix
```

To combine multiple matrices (e.g. one per donor/sample), use `mean_normalized(coocs)`: each matrix is normalized by its own total sum and the element-wise mean is taken. When label sets differ across matrices, they are aligned to the union of all labels (missing entries as zero). Same group structure (group names and order) is required.

```julia
coocs = [cooccurrence_matrix(df_i, cols) for df_i in list_of_dfs]
combined = mean_normalized(coocs)
chordplot(combined; min_ribbon_value=0.001)
```

Both `CoOccurrenceMatrix` (counts) and `NormalizedCoOccurrenceMatrix` (frequencies) work with `chordplot`, `compute_layout`, and the rest of the API.
