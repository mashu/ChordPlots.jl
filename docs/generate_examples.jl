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

# -----------------------------------------------------------------------------#
# V/D/J-style shared data: mean matrix, envelope bounds
# -----------------------------------------------------------------------------#
mean_mat = [0.0 6.0 2.0 0.0 0.0 0.0
            6.0 0.0 3.0 0.0 0.0 0.0
            2.0 3.0 0.0 0.0 0.0 0.0
            0.0 0.0 0.0 0.0 4.0 1.0
            0.0 0.0 0.0 4.0 0.0 5.0
            0.0 0.0 0.0 1.0 5.0 0.0]
# Large spread in doc figure so the pale band is unambiguous; geometry also enforces a minimum frill
s_rel = 0.5
sd = s_rel .* max.(mean_mat, 1.0)
for d in 1:6
    sd[d, d] = 0.0
end
envelope_lo = max.(0.0, mean_mat .- sd)
envelope_hi = max.(0.0, mean_mat .+ sd)
labels_e = ["V1", "V2", "V3", "D1", "D2", "J1"]
groups_e = [
    GroupInfo{String}(:V, ["V1", "V2", "V3"], 1:3),
    GroupInfo{String}(:D, ["D1", "D2"], 4:5),
    GroupInfo{String}(:J, ["J1"], 6:6),
]
cooc_e = CoOccurrenceMatrix(mean_mat, labels_e, groups_e)
envelope_doc_style = (
    inner_radius = 0.86,
    arc_width = 0.052,
    gap_fraction = 0.08,
    arc_scale = 0.92,
    ribbon_tension = 0.55,
    ribbon_width_power = 1.4,
    alpha = ComponentAlpha(ribbons = 0.9, arcs = 0.95, labels = 1.0),
    # Fixed opacity on ribbons in the static PNG so envelope vs mean is easy to read
    alpha_by_value = ValueScaling(false),
    arc_strokewidth = 0.0,
    arc_strokecolor = :transparent,
    label_color = :black,
)

# Example 6: Ribbon envelope (explicit tunnel + two-band confidence)
println("Generating ribbon envelope example...")
fig = Figure(size = (600, 600))
ax = Axis(
    fig[1, 1];
    title = "Tunnel mean + two-band confidence (ribbon_envelope_mean = :tunnel)",
    titlesize = 15,
    titlealign = :center,
)
chordplot!(
    ax, cooc_e;
    envelope_doc_style...,
    ribbon_envelope_low = envelope_lo,
    ribbon_envelope_high = envelope_hi,
    ribbon_envelope_bands = 2,
    ribbon_envelope_mean = :tunnel,
    ribbon_envelope_mean_faint_fill = 0.32,
    ribbon_envelope_mean_strokewidth = 1.25,
)
setup_chord_axis!(ax; outer_radius = 1.0, label_offset = 0.12, padding = 0.2)
save(joinpath(output_dir, "ribbon_envelope.png"), fig)

# -----------------------------------------------------------------------------#
# Example 7: CoOccurrenceLayers — union labels across donors
# -----------------------------------------------------------------------------#
println("Generating CoOccurrenceLayers (union labels across donors) example...")

# V/D/J-style labels (gene segments / calls) for docs
labels_u = [
    "IGHV1-2", "IGHV1-3", "IGHV2-8",
    "IGHD3-3", "IGHD3-10", "IGHD4-4",
    "IGHJ1", "IGHJ4", "IGHJ6",
]
groups_u = [
    GroupInfo{String}(:V, labels_u[1:3], 1:3),
    GroupInfo{String}(:D, labels_u[4:6], 4:6),
    GroupInfo{String}(:J, labels_u[7:9], 7:9),
]

# Ten donors: same label universe, slightly different link strengths
rng = MersenneTwister(7)
n_u = length(labels_u)
L = 10
layers_u = zeros(Float64, n_u, n_u, L)
l2u = Dict{String, Int}(l => i for (i, l) in enumerate(labels_u))

function add_link!(layers, l2i, a::String, b::String, μ::Float64, σ::Float64, ℓ::Int, rng)
    i = l2i[a]
    j = l2i[b]
    v = max(0.0, μ + σ * randn(rng))
    layers[i, j, ℓ] = v
    layers[j, i, ℓ] = v
    nothing
end

for ℓ in 1:L
    # V–D links (stronger)
    add_link!(layers_u, l2u, "IGHV1-2", "IGHD3-3", 0.30, 0.12, ℓ, rng)
    add_link!(layers_u, l2u, "IGHV1-3", "IGHD3-10", 0.22, 0.10, ℓ, rng)
    add_link!(layers_u, l2u, "IGHV2-8", "IGHD4-4", 0.18, 0.09, ℓ, rng)
    add_link!(layers_u, l2u, "IGHV1-2", "IGHD4-4", 0.12, 0.08, ℓ, rng)

    # D–J links (moderate)
    add_link!(layers_u, l2u, "IGHD3-3", "IGHJ4", 0.20, 0.10, ℓ, rng)
    add_link!(layers_u, l2u, "IGHD3-10", "IGHJ6", 0.16, 0.09, ℓ, rng)
    add_link!(layers_u, l2u, "IGHD4-4", "IGHJ1", 0.14, 0.08, ℓ, rng)

    # A couple weaker cross links
    add_link!(layers_u, l2u, "IGHV2-8", "IGHJ6", 0.07, 0.06, ℓ, rng)
end

# Arcs from aggregate (mean donor), ribbons from individual donors
cooc_layers = CoOccurrenceLayers(layers_u, labels_u, groups_u; aggregate = :mean)
cs_ld = group_colors(cooc_layers)

fig = Figure(size = (780, 780))
ax = Axis(fig[1, 1]; title = "CoOccurrenceLayers: 10 donors (V/D/J example)", titlesize = 14)
chordplot!(
    ax,
    cooc_layers;
    inner_radius = 0.86,
    arc_width = 0.055,
    gap_fraction = 0.08,
    arc_scale = 0.92,
    ribbon_tension = 0.55,
    ribbon_width_power = 1.35,
    colorscheme = cs_ld,
    alpha_by_value = ValueScaling(
        enabled = true,
        components = (ribbons = true, arcs = false, labels = false),
        min_alpha = 0.02,
    ),
    alpha = ComponentAlpha(ribbons = 0.2, arcs = 0.95, labels = 1.0),
    arc_strokewidth = 0.0,
    arc_strokecolor = :transparent,
    label_color = :black,
    min_arc_flow = 1e-9,
    min_ribbon_value = 0.0,
)
setup_chord_axis!(ax; outer_radius = 1.0, label_offset = 0.12, padding = 0.2)
save(joinpath(output_dir, "cooccurrence_layers.png"), fig)

println("All examples generated!")
