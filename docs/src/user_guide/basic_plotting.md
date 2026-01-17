# Basic Plotting

Learn how to create and customize chord diagrams.

## Simple Plot

```julia
fig = Figure(size=(800, 800))
ax = Axis(fig[1,1], title="My Chord Diagram")
chordplot!(ax, cooc)
setup_chord_axis!(ax)
fig
```

```@raw html
<img src="assets/examples/basic.png" alt="Basic Plot" style="max-width: 600px;"/>
```

## Standalone Plot

You can also create a plot without explicitly creating an axis:

```julia
fig, ax, plt = chordplot(cooc)
setup_chord_axis!(ax)
fig
```

## Essential Setup

Always call `setup_chord_axis!` after plotting to:
- Set equal aspect ratio
- Remove axis decorations
- Set appropriate limits

```julia
setup_chord_axis!(ax; padding=0.2)  # padding controls margin around plot
```

## Plotting from DataFrame

You can plot directly from a DataFrame:

```julia
chordplot!(ax, df, [:V, :D, :J])
```

This is equivalent to:
```julia
cooc = cooccurrence_matrix(df, [:V, :D, :J])
chordplot!(ax, cooc)
```
