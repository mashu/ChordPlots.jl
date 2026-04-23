# Generate example plots for documentation
# Note: This assumes ChordPlots is already available via Pkg.develop()
using ChordPlots
using CairoMakie
using Random

# Set random seed for reproducibility
Random.seed!(42)

# Publication look for docs (white background)
set_theme!(merge(theme_light(), Theme(
    fontsize = 14,
    figure_padding = (12, 12, 12, 12),
    backgroundcolor = :white,
    Axis = (
        backgroundcolor = :transparent,
        xgridvisible = false,
        ygridvisible = false,
        leftspinevisible = false,
        rightspinevisible = false,
        topspinevisible = false,
        bottomspinevisible = false,
        titlecolor = :black,
    ),
)))

# Create output directory
output_dir = joinpath(@__DIR__, "src", "assets", "examples")
mkpath(output_dir)

# Ensure CairoMakie is set up for headless rendering
CairoMakie.activate!(type = "png")

# Example 1: Basic chord diagram
println("Generating basic example...")
mat_basic = [0 6 2 0 0 0;
             6 0 3 0 0 0;
             2 3 0 0 0 0;
             0 0 0 0 4 1;
             0 0 0 4 0 5;
             0 0 0 1 5 0]
labels_basic = ["V1", "V2", "V3", "D1", "D2", "J1"]
groups_basic = [
    GroupInfo{String}(:V, ["V1", "V2", "V3"], 1:3),
    GroupInfo{String}(:D, ["D1", "D2"], 4:5),
    GroupInfo{String}(:J, ["J1"], 6:6),
]
cooc_basic = CoOccurrenceMatrix(mat_basic, labels_basic, groups_basic)
fig = Figure(size=(600, 600))
ax = Axis(fig[1,1], title="Basic Chord Diagram")
chordplot!(ax, cooc_basic;
    inner_radius = 0.88,
    arc_width = 0.055,
    gap_fraction = 0.08,
    arc_scale = 0.92,
    ribbon_tension = 0.55,
    ribbon_width_power = 1.4,
    alpha = ComponentAlpha(ribbons=0.65, arcs=0.95, labels=1.0),
    alpha_by_value = ValueScaling(enabled=true, components=(ribbons=true, arcs=true, labels=false)),
    min_arc_flow = 1e-9,
    arc_strokewidth = 0.0,
    arc_strokecolor = :transparent,
    label_color = :black,
)
setup_chord_axis!(ax)
save(joinpath(output_dir, "basic.png"), fig)

# Example 2: Decluttered / filtered
println("Generating filtered example...")
fig = Figure(size=(600, 600))
ax = Axis(fig[1,1], title="Decluttered")
chordplot!(ax, cooc_basic;
    inner_radius = 0.88,
    arc_width = 0.055,
    gap_fraction = 0.10,
    arc_scale = 0.92,
    ribbon_tension = 0.55,
    ribbon_width_power = 1.6,
    alpha_by_value = ValueScaling(enabled=true, components=(ribbons=true, arcs=true, labels=false)),
    alpha = ComponentAlpha(ribbons=0.65, arcs=0.95, labels=1.0),
    # Hide low-flow arcs (and their labels) to reduce clutter
    min_arc_flow = 6.0,
    # Hide very weak ribbons too
    min_ribbon_value = 2.5,
    arc_strokewidth = 0.0,
    arc_strokecolor = :transparent,
    label_color = :black,
)
setup_chord_axis!(ax)
save(joinpath(output_dir, "filtered.png"), fig)

# Example 3: Strength-based opacity (ribbons, arcs, labels)
println("Generating opacity example...")
fig = Figure(size=(600, 600))
ax = Axis(fig[1,1], title="Strength-based Opacity")
chordplot!(ax, cooc_basic;
    inner_radius = 0.88,
    arc_width = 0.055,
    gap_fraction = 0.08,
    arc_scale = 0.92,
    ribbon_width_power = 1.6,
    alpha_by_value = ValueScaling(enabled=true, components=(ribbons=true, arcs=true, labels=false)),
    alpha = ComponentAlpha(ribbons=0.7, arcs=0.95, labels=1.0),
    arc_strokewidth = 0.0,
    arc_strokecolor = :transparent,
    label_color = :black,
)
setup_chord_axis!(ax)
save(joinpath(output_dir, "opacity.png"), fig)

# Example 4: Categorical colors
println("Generating categorical colors example...")
fig = Figure(size=(600, 600))
ax = Axis(fig[1,1], title="Categorical Colors")
chordplot!(ax, cooc_basic;
    colorscheme = :categorical,
    inner_radius = 0.88,
    arc_width = 0.055,
    gap_fraction = 0.08,
    arc_scale = 0.92,
    ribbon_width_power = 1.4,
    alpha_by_value = ValueScaling(enabled=true, components=(ribbons=true, arcs=true, labels=false)),
    alpha = ComponentAlpha(ribbons=0.62, arcs=0.95, labels=1.0),
    arc_strokewidth = 0.0,
    arc_strokecolor = :transparent,
    label_color = :black,
)
setup_chord_axis!(ax)
save(joinpath(output_dir, "categorical.png"), fig)

# Example 5: Custom layout
println("Generating custom layout example...")
fig = Figure(size=(600, 600))
ax = Axis(fig[1,1], title="Custom Layout")
chordplot!(ax, cooc_basic;
    sort_by = :value,
    inner_radius = 0.86,
    arc_width = 0.05,
    gap_fraction = 0.10,
    arc_scale = 0.90,
    ribbon_width_power = 1.7,
    alpha_by_value = ValueScaling(enabled=true, components=(ribbons=true, arcs=true, labels=false)),
    alpha = ComponentAlpha(ribbons=0.68, arcs=0.95, labels=1.0),
    arc_strokewidth = 0.0,
    arc_strokecolor = :transparent,
    label_color = :black,
)
setup_chord_axis!(ax)
save(joinpath(output_dir, "layout.png"), fig)

println("All examples generated!")
