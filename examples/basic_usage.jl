# examples/basic_usage.jl
# Example usage of ChordPlots.jl

using Pkg
Pkg.activate("..")

using ChordPlots
using CairoMakie

# Provide a preprocessed weight matrix (counts, frequencies, scores, etc.)
matrix = [
    0 6 2 0 0 0;
    6 0 3 0 0 0;
    2 3 0 0 0 0;
    0 0 0 0 4 1;
    0 0 0 4 0 5;
    0 0 0 1 5 0;
]
labels = ["V1", "V2", "V3", "D1", "D2", "J1"]
groups = [
    GroupInfo{String}(:V, ["V1", "V2", "V3"], 1:3),
    GroupInfo{String}(:D, ["D1", "D2"], 4:5),
    GroupInfo{String}(:J, ["J1"], 6:6),
]
cooc = CoOccurrenceMatrix(matrix, labels, groups)

println("  Labels: ", nlabels(cooc))
println("  Groups: ", ngroups(cooc))

# Create figure
fig = Figure(size=(800, 800))
ax = Axis(fig[1,1], title="VDJ Gene Segment Co-occurrence")

chordplot!(ax, cooc;
    label_fontsize = 9,
    arc_width = 0.06,
    alpha = 0.6
)

setup_chord_axis!(ax; padding=0.25)

save("example1_basic.png", fig)
println("  Saved: example1_basic.png")
