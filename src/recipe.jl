# src/recipe.jl
# Makie plotting recipe for chord diagrams

using Colors: RGBA, RGB, alpha
using Makie
using GeometryBasics: Point2f, Polygon

#==============================================================================#
# Internal Configuration Types
#==============================================================================#

"""
Internal configuration for drawing functions. Consolidates all appearance settings.
"""
struct DrawConfig
    alpha::ComponentAlpha
    scaling::ValueScaling
    dim_color::RGB{Float64}
    dim_alpha::Float64
end

"""
Internal helper for normalizing values to [0,1] range with optional log scaling.
Used for value-based opacity calculations.
"""
struct ValueNormalizer
    min_val::Float64
    range::Float64
    log_min::Float64
    log_range::Float64
    use_log::Bool
end

function ValueNormalizer(values::AbstractVector{<:Real}, use_log::Bool)
    isempty(values) && return ValueNormalizer(0.0, 1.0, 0.0, 1.0, false)
    min_val = Float64(minimum(values))
    max_val = Float64(maximum(values))
    range = max_val - min_val
    
    if use_log && range > 0 && min_val > 0
        log_min = log(min_val)
        log_range = log(max_val) - log_min
        ValueNormalizer(min_val, range, log_min, log_range, true)
    else
        ValueNormalizer(min_val, range, 0.0, 1.0, false)
    end
end

"""
Map a value to the [0, 1] range for visual scaling.
"""
function normalize_value(n::ValueNormalizer, value::Real)::Float64
    # When range is 0, return 0 so alpha = min_alpha (so min_alpha is always respected)
    n.range <= 0 && return 0.0
    if n.use_log && value > 0
        clamp((log(Float64(value)) - n.log_min) / n.log_range, 0.0, 1.0)
    else
        clamp((Float64(value) - n.min_val) / n.range, 0.0, 1.0)
    end
end

"""
Compute alpha value based on normalized value, scaling from min_alpha to base_alpha.
Clamps so the result is always in [min_alpha, base_alpha] (so min_alpha is never exceeded downward).
"""
function compute_scaled_alpha(norm::ValueNormalizer, value::Real, 
                              base_alpha::Float64, min_alpha::Float64)::Float64
    t = normalize_value(norm, abs(value))
    alpha = min_alpha + t * (base_alpha - min_alpha)
    clamp(alpha, min(min_alpha, base_alpha), max(min_alpha, base_alpha))
end

"""
Parse alpha input into ComponentAlpha. Accepts:
- Real (single value for all)
- Tuple{Real,Real,Real} 
- ComponentAlpha (pass through)
"""
function parse_alpha(alpha)::ComponentAlpha
    if alpha isa ComponentAlpha
        alpha
    elseif alpha isa Tuple && length(alpha) >= 3
        ComponentAlpha(alpha[1], alpha[2], alpha[3])
    elseif alpha isa AbstractVector && length(alpha) >= 3
        ComponentAlpha(alpha[1], alpha[2], alpha[3])
    else
        ComponentAlpha(Float64(alpha))
    end
end

"""
Parse alpha_by_value input into ValueScaling. Accepts:
- Bool (simple on/off)
- ValueScaling (pass through)
- Tuple of (enabled, components, min_alpha, scale) for legacy compatibility
"""
function parse_scaling(scaling, components, min_alpha, scale)::ValueScaling
    if scaling isa ValueScaling
        scaling
    elseif scaling isa Bool
        ValueScaling(scaling, components[1], components[2], components[3], min_alpha, scale)
    else
        ValueScaling(false, true, true, true, 0.1, :linear)
    end
end

#==============================================================================#
# Main Recipe: chordplot
#==============================================================================#

"""
    chordplot(cooc::AbstractChordData)
    chordplot!(ax, cooc::AbstractChordData)

Create a chord diagram from co-occurrence data.

# Attributes (grouped by purpose)

## Radii and arc size
- `inner_radius = 0.92`: Inner radius for ribbons
- `outer_radius = 1.0`: Outer radius for arcs
- `arc_width = 0.08`: Width of arc segments

## Arc and gap layout
- `gap_fraction = 0.03`: Fraction of circle reserved for gaps
- `arc_scale = 1.0`: Scale for arc portion; < 1 adds extra gaps
- `sort_by = :group`: Order arcs by `:group`, `:value`, or `:none`
- `label_order = nothing`: Fixed order (overrides `sort_by`)

## Ribbon appearance
- `ribbon_width_power = 1.0`: Exponent for ribbon width
- `min_ribbon_value = 0`: Hide ribbons below this value
- `ribbon_tension = 0.5`: Bezier curve tension

## Arc appearance
- `arc_strokewidth = 0.5`: Border width
- `arc_strokecolor = :black`: Border color

## Labels
- `show_labels = true`: Whether to show labels
- `label_offset = 0.12`: Distance from arc to label
- `label_fontsize = 10`: Font size
- `label_color = :black`: Color (use `:group` for category colors)
- `rotate_labels = true`: Rotate labels to follow arcs
- `label_justify = :inside`: `:inside` or `:outside`
- `min_arc_flow = 0`: Hide arcs below this flow

## Colors
- `colorscheme = :group`: Color scheme (`:group`, `:categorical`, or `AbstractColorScheme`)

## Opacity (unified)
- `alpha = 1.0`: Base opacity per component (ribbons, arcs, labels). Accepts `Real`, `Tuple`, or `ComponentAlpha`. Scaling off = fixed opacity; scaling on = upper bound (min_alpha to this).
- `alpha_by_value = false`: Value-based scaling. Accepts `Bool` or `ValueScaling`. This is the **only** toggle for “scale by value” vs “fully opaque”:
  - For each component (ribbons, arcs, labels), **on** → opacity scales by value from `min_alpha` to the component’s base `alpha`; **off** → opacity is that component base alpha (fixed).
  - `false` or unknown → no scaling (all components 1.0). `true` → all components scaled. `ValueScaling(; components=(ribbons=..., arcs=..., labels=...))` → per-component.

For `CoOccurrenceLayers` with several donors on the **same** ribbon path, prefer **moderate** ribbon `alpha` (e.g. `0.3`–`0.45` per ribbon) so each layer stays visible and overlap reads as stronger color (variance / agreement), not a single opaque slab.

## Focus (highlight subset)
- `focus_group = nothing`: Group to apply focus styling
- `focus_labels = nothing`: Labels to keep highlighted
- `dim_color = RGB(0.55, 0.55, 0.55)`: Color for dimmed elements
- `dim_alpha = 0.25`: Alpha for dimmed elements

## Ribbon envelope (optional uncertainty band)
Supply symmetric matrices the same size as the **input** `cooc.matrix` (before `min_arc_flow` filtering; they are sliced the same way as the matrix when labels are dropped). The package does not compute means or SDs — you choose the bounds (e.g. mean ± SD per pair). Angular width scales as `1 + (high - low) / (2|mean|)` on each end relative to the mean layer so a visible band is **wider** than the mean, not the same.
- `ribbon_envelope_low = nothing`, `ribbon_envelope_high = nothing`: both required to draw; each entry `high[i,j] - low[i,j]` drives the extra width behind the mean ribbon.
- `ribbon_envelope_alpha = 0.38`: opacity of the envelope fill. `ValueScaling` / `alpha_by_value` does **not** change envelope opacity.
- `ribbon_envelope_color = nothing`: `nothing` → use the same hue as the mean ribbon, blended; otherwise any Makie color.
- `ribbon_envelope_lighten = 0.55`: (outer band) blend fill toward white; for two bands, pair with `ribbon_envelope_lighten_inner`.
- `ribbon_envelope_stroke = 0.0`: optional **white** hairline on the **mean** when it is still filled (`:solid`); 0 = off. Ignored for `:hollow` (see `ribbon_envelope_mean`).
- `ribbon_envelope_mode = :ring`: `:ring` fills only the **margin** between the mean and widened outlines. Use `:fill` for the full wide shape under a solid mean.
- `ribbon_envelope_bands = 2` (`:ring` only): `2` = two tints, **inner** and **outer** (see `ribbon_envelope_lighten_inner` / `ribbon_envelope_lighten`). `1` = single ring (previous look).
- `ribbon_envelope_lighten_inner` (e.g. `0.2`): for two bands, blend toward **white** less for the **inner** half of the margin (closer to the mean), more for the **outer** (`ribbon_envelope_lighten`).
- `ribbon_envelope_mean = :hollow` (`:solid` or `:hollow` / alias `:tunnel`): with an envelope, draw the **mean** as a **stroke in the link color** and, by default, a **faint** same-hue fill (`ribbon_envelope_mean_faint_fill`) so the estimate reads as a **tinted tube inside** the band—not an empty cutout, and not a second opaque ribbon. Set **faint fill to 0** for a fully empty tunnel. `:solid` keeps a fully filled mean (optional `ribbon_envelope_stroke` for a light edge).
- `ribbon_envelope_mean_faint_fill = 0.32`: for `:hollow`, **multiply** the mean ribbon’s fill alpha by this (0 = fully transparent fill, 1 = same opacity as a solid mean’s fill). Ignored for `:solid`.
- `ribbon_envelope_mean_strokewidth = 1.25` (Makie units): stroke width for `:hollow`.

# Example
```julia
using CairoMakie, ChordPlots

matrix = [0 3 1;
          3 0 2;
          1 2 0]
labels = ["A", "B", "C"]
groups = [GroupInfo{String}(:G, labels, 1:3)]
cooc = CoOccurrenceMatrix(matrix, labels, groups)

# Basic plot
fig, ax, plt = chordplot(cooc)

# Per-component opacity
chordplot(cooc; alpha=ComponentAlpha(ribbons=0.5, arcs=1.0, labels=1.0))

# Value-based scaling (ribbons and arcs only; labels at 1.0)
chordplot(cooc; alpha_by_value=ValueScaling(
    enabled=true,
    components=(ribbons=true, arcs=true, labels=false)
))
```
"""
@recipe(ChordPlot, cooc) do scene
    Attributes(
        # Geometry
        inner_radius = 0.92,
        outer_radius = 1.0,
        arc_width = 0.08,
        gap_fraction = 0.03,
        arc_scale = 1.0,
        # Order
        sort_by = :group,
        label_order = nothing,
        # Ribbons
        ribbon_width_power = 1.0,
        min_ribbon_value = 0,
        ribbon_tension = 0.5,
        # CoOccurrenceLayers: how to anchor per-donor slices along arcs
        # - :fixed_pairs (default): each label-pair gets a fixed arc sub-span from the aggregate; donors vary within it
        # - :per_layer: each donor independently partitions the arc (previous behavior)
        layers_pair_span = :fixed_pairs,
        # Arcs
        arc_strokewidth = 0.5,
        arc_strokecolor = :black,
        # Labels
        show_labels = true,
        label_offset = 0.12,
        label_fontsize = 10,
        label_color = :black,
        rotate_labels = true,
        label_justify = :inside,
        min_arc_flow = 0,
        # Colors
        colorscheme = :group,
        # Opacity (Real, Tuple, or ComponentAlpha)
        alpha = 1.0,
        # Value-based scaling (Bool or ValueScaling). Default ValueScaling(false) so user's ValueScaling is stored (not converted to Bool).
        alpha_by_value = ValueScaling(false),
        # Focus
        focus_group = nothing,
        focus_labels = nothing,
        dim_color = RGB(0.55, 0.55, 0.55),
        dim_alpha = 0.25,
        # Ribbon envelope (user-supplied bounds; same matrix size as input cooc)
        ribbon_envelope_low = nothing,
        ribbon_envelope_high = nothing,
        ribbon_envelope_alpha = 0.38,
        ribbon_envelope_color = nothing,
        # Two-band ring: outer = more pale (higher = more toward white); inner = `ribbon_envelope_lighten_inner`
        ribbon_envelope_lighten = 0.55,
        ribbon_envelope_lighten_inner = 0.2,
        # Optional white hairline on mean when `ribbon_envelope_mean = :solid` (0 = off)
        ribbon_envelope_stroke = 0.0,
        # :ring = annulus; :fill = full wide under mean
        ribbon_envelope_mode = :ring,
        # 1 = one band; 2 = inner+outer tints (ring only)
        ribbon_envelope_bands = 2,
        # :solid = filled mean; :hollow / :tunnel = stroke + optional faint same-hue fill
        ribbon_envelope_mean = :hollow,
        # Hollow only: mean fill alpha = ribbon alpha × this (0 = empty tunnel)
        ribbon_envelope_mean_faint_fill = 0.32,
        ribbon_envelope_mean_strokewidth = 1.25,
    )
end

# Type alias for convenience
const ChordPlotType = ChordPlot{<:Tuple{AbstractChordData}}

#==============================================================================#
# Helpers for order and focus
#==============================================================================#

function resolve_label_order(cooc::AbstractChordData, order)
    order === nothing && return nothing
    isempty(order) && return nothing
    n = nlabels(cooc)
    if order isa AbstractVector{<:Integer}
        lo = collect(Int, order)
        return length(lo) == n ? lo : nothing
    elseif order isa AbstractVector{<:AbstractString}
        # Filter to labels that exist in this cooc, preserving order
        # This allows unified orders from label_order([cooc1, cooc2, ...]) to work
        idx = Int[]
        for l in order
            if haskey(cooc.label_to_index, l)
                push!(idx, cooc.label_to_index[l])
            end
        end
        # Must cover all labels in cooc (superset order is fine, subset is not)
        length(idx) != n && return nothing
        sort(idx) == collect(1:n) || return nothing  # must be permutation of 1:n
        return idx
    else
        return nothing
    end
end

function dimmed_label_indices(cooc::AbstractChordData, focus_group, focus_labels)
    (focus_group === nothing || focus_labels === nothing) && return Set{Int}()
    fl_set = Set(focus_labels)
    dimmed = Int[]
    for g in cooc.groups
        g.name != focus_group && continue
        for i in g.indices
            cooc.labels[i] in fl_set || push!(dimmed, i)
        end
        break
    end
    Set(dimmed)
end

"""
    apply_min_arc_flow(cooc, min_flow) -> (filtered_cooc, keep_indices)

If `min_flow > 0`, drop low-flow labels: for `CoOccurrenceMatrix` the criterion is
the **signed** row sum (`total_flow`); for `CoOccurrenceLayers` it is
the **absolute** row sum over all layers (`abs_total_flow`, matching
`compute_layout`).

Returns the subsetted chord data and `keep_indices` (`nothing` if nothing was removed), a
`Vector{Int}` of original label indices into the input `cooc`.
"""
function apply_min_arc_flow(cooc::AbstractChordData, min_flow::Real)
    if min_flow <= 0
        return cooc, nothing
    end
    flows = [total_flow(cooc, i) for i in 1:nlabels(cooc)]
    keep_indices = Int[i for i in 1:nlabels(cooc) if flows[i] >= min_flow]
    if length(keep_indices) == nlabels(cooc)
        return cooc, nothing
    end
    new_matrix = cooc.matrix[keep_indices, keep_indices]
    new_labels = cooc.labels[keep_indices]
    T = eltype(cooc.matrix)
    S = eltype(cooc.labels)
    new_groups = GroupInfo{S}[]
    idx = 1
    for g in cooc.groups
        group_mask = [i in g.indices for i in keep_indices]
        remaining = new_labels[group_mask]
        if !isempty(remaining)
            n_remaining = length(remaining)
            push!(new_groups, GroupInfo{S}(g.name, remaining, idx:idx + n_remaining - 1))
            idx += n_remaining
        end
    end
    return CoOccurrenceMatrix{T, S}(new_matrix, new_labels, new_groups), keep_indices
end

function apply_min_arc_flow(cooc::CoOccurrenceLayers, min_flow::Real)
    if min_flow <= 0
        return cooc, nothing
    end
    n = nlabels(cooc)
    flows = [abs_total_flow(cooc, i) for i in 1:n]
    keep_indices = [i for i in 1:n if flows[i] >= min_flow]
    if length(keep_indices) == n
        return cooc, nothing
    end
    new_layers = cooc.layers[keep_indices, keep_indices, :]
    new_labels = cooc.labels[keep_indices]
    S = eltype(cooc.labels)
    new_groups = GroupInfo{S}[]
    idx = 1
    for g in cooc.groups
        group_mask = [i in g.indices for i in keep_indices]
        remaining = new_labels[group_mask]
        if !isempty(remaining)
            n_rem = length(remaining)
            push!(new_groups, GroupInfo{S}(g.name, remaining, idx:idx + n_rem - 1))
            idx += n_rem
        end
    end
    return CoOccurrenceLayers(new_layers, new_labels, new_groups), keep_indices
end

function slice_matrix_keep(mat::AbstractMatrix, keep::Nothing)
    mat
end

function slice_matrix_keep(mat::AbstractMatrix, keep::Vector{Int})
    mat[keep, keep]
end

#==============================================================================#
# Plot Implementation
#==============================================================================#

function Makie.plot!(p::ChordPlotType)
    # Extract observables
    cooc_obs = p[:cooc]
    
    filtered_pack_obs = lift(cooc_obs, p.min_arc_flow) do cooc, min_flow
        apply_min_arc_flow(cooc, min_flow)
    end
    filtered_cooc_obs = lift(x -> x[1], filtered_pack_obs)
    kept_label_indices_obs = lift(x -> x[2], filtered_pack_obs)
    
    # Resolve label_order to indices (permutation of 1:n) for fixed circle order
    resolved_order_obs = lift(filtered_cooc_obs, p.label_order) do cooc, order
        resolve_label_order(cooc, order)
    end
    
    # Reactive computations
    layout_obs = lift(filtered_cooc_obs, p.inner_radius, p.outer_radius, p.gap_fraction, p.sort_by, resolved_order_obs, p.arc_scale, p.ribbon_width_power) do cooc, ir, or, gf, sb, order, arc_scale, ribbon_power
        config = LayoutConfig(
            inner_radius = ir,
            outer_radius = or,
            gap_fraction = gf,
            sort_by = sb,
            label_order = order,
            arc_scale = arc_scale,
            ribbon_width_power = ribbon_power
        )
        compute_layout(cooc, config)
    end
    
    # Dimmed label indices: labels in focus_group not in focus_labels (grey + low alpha)
    dimmed_indices_obs = lift(filtered_cooc_obs, p.focus_group, p.focus_labels) do cooc, fg, fl
        dimmed_label_indices(cooc, fg, fl)
    end
    
    # Filter ribbons by minimum value
    filtered_layout_obs = lift(layout_obs, p.min_ribbon_value) do layout, min_val
        if min_val > 0
            filter_ribbons(layout, min_val)
        else
            layout
        end
    end
    
    # Color scheme (use filtered cooc for consistency)
    colorscheme_obs = lift(filtered_cooc_obs, p.colorscheme) do cooc, cs
        if cs == :group
            group_colors(cooc)
        elseif cs == :categorical
            categorical_colors(nlabels(cooc))
        elseif cs isa AbstractColorScheme
            cs
        else
            group_colors(cooc)
        end
    end
    
    # Consolidate drawing configuration into single struct
    # ValueScaling: on = scale by value (min_alpha .. base alpha), off = use base alpha (fixed).
    # Bool false / unknown → no scaling (each component uses its base alpha). Bool true → all scaled. ValueScaling → use as-is.
    draw_config_obs = lift(p.alpha, p.alpha_by_value, p.dim_color, p.dim_alpha) do alpha, scaling, dim_color, dim_alpha
        ca = parse_alpha(alpha)
        vs = if scaling isa ValueScaling
            scaling
        elseif scaling === true
            ValueScaling(true)
        else
            # false, nothing, or unknown: no scaling for any component (all opaque)
            ValueScaling(false, false, false, false, 0.1, :linear)
        end
        DrawConfig(ca, vs, RGB{Float64}(dim_color), Float64(dim_alpha))
    end
    
    envelope_matrices_obs = lift(
        filtered_cooc_obs, kept_label_indices_obs, p.ribbon_envelope_low, p.ribbon_envelope_high
    ) do cooc, keep, low, high
        if low === nothing || high === nothing
            return nothing
        end
        size(low) == size(high) || throw(DimensionMismatch("ribbon_envelope_low and ribbon_envelope_high must have the same size"))
        size(low) == size(cooc.matrix) || throw(DimensionMismatch(
            "ribbon envelope matrices size $(size(low)) do not match displayed co-occurrence size $(size(cooc.matrix))"
        ))
        (slice_matrix_keep(low, keep), slice_matrix_keep(high, keep))
    end
    
    # Envelope ribbons, then mean ribbons (behind arcs)
    draw_ribbon_envelopes!(
        p, filtered_cooc_obs, filtered_layout_obs, envelope_matrices_obs,
        colorscheme_obs, dimmed_indices_obs, draw_config_obs
    )
    draw_ribbons!(
        p, filtered_cooc_obs, filtered_layout_obs, colorscheme_obs, dimmed_indices_obs, draw_config_obs, envelope_matrices_obs
    )
    
    # Draw arcs
    draw_arcs!(p, filtered_cooc_obs, layout_obs, colorscheme_obs, dimmed_indices_obs, draw_config_obs)
    
    # Draw labels
    draw_labels!(p, filtered_cooc_obs, layout_obs, colorscheme_obs, dimmed_indices_obs, draw_config_obs)
    
    p
end

#==============================================================================#
# Drawing Components
#==============================================================================#

function draw_ribbon_envelopes!(
    p::ChordPlotType, cooc_obs, layout_obs, envelope_obs, colorscheme_obs, dimmed_obs, config_obs
)
    envelope_data = lift(
        cooc_obs, layout_obs, envelope_obs, colorscheme_obs, dimmed_obs, config_obs,
        p.ribbon_tension, p.ribbon_envelope_alpha, p.ribbon_envelope_color, p.ribbon_envelope_lighten,
        p.ribbon_envelope_lighten_inner, p.ribbon_envelope_mode, p.ribbon_envelope_bands
    ) do cooc, layout, envpack, cs, dimmed, cfg, tension, env_alpha, env_color_spec, env_lightn_out,
        env_lightn_in, env_mode, env_bands
        polys_and_colors = Tuple{Any, RGBA{Float64}}[]
        envpack === nothing && return polys_and_colors
        low, high = envpack
        isempty(layout.ribbons) && return polys_and_colors
        env_a = Float64(env_alpha)
        env_a = clamp(env_a, 0.0, 1.0)
        l_out = Float64(env_lightn_out)
        l_out = clamp(l_out, 0.0, 1.0)
        l_in = Float64(env_lightn_in)
        l_in = clamp(l_in, 0.0, 1.0)
        mode = env_mode isa Symbol ? env_mode : Symbol(env_mode)
        mode === :ring || mode === :fill || throw(ArgumentError("ribbon_envelope_mode must be :ring or :fill, got $env_mode"))
        bands = Int(env_bands)
        (bands == 1 || bands == 2) || throw(ArgumentError("ribbon_envelope_bands must be 1 or 2, got $env_bands"))
        r = layout.inner_radius
        n_bez = 40

        function env_rgba_duo(is_dimmed, base_rgb, light_inner, light_outer)
            if is_dimmed
                c = RGBA(cfg.dim_color, cfg.dim_alpha * env_a)
                return (c, c)
            end
            c_in = if light_inner > 0; lighten(base_rgb, light_inner); else; base_rgb; end
            c_out = if light_outer > 0; lighten(base_rgb, light_outer); else; base_rgb; end
            (RGBA(c_in, env_a), RGBA(c_out, env_a))
        end
        function env_rgba_base(is_dimmed, base_rgb, light1)
            if is_dimmed
                return RGBA(cfg.dim_color, cfg.dim_alpha * env_a)
            end
            fill_rgb = light1 > 0 ? lighten(base_rgb, light1) : base_rgb
            return RGBA(fill_rgb, env_a)
        end
        
        # One envelope per label pair: CoOccurrenceLayers may have several ribbons (layers) for the same pair
        seen_pairs = Set{Tuple{Int, Int}}()
        for ribbon in layout.ribbons
            i = ribbon.source.label_idx
            j = ribbon.target.label_idx
            a, b = minmax(i, j)
            (a, b) in seen_pairs && continue
            push!(seen_pairs, (a, b))
            span = Float64(high[a, b]) - Float64(low[a, b])
            span <= 0 && continue
            
            sc = envelope_widen_scale(ribbon, span)
            erw = ribbon_widened(ribbon, sc)
            is_dimmed = ribbon.source.label_idx in dimmed || ribbon.target.label_idx in dimmed
            if env_color_spec === nothing
                base_color = resolve_ribbon_color(cs, ribbon, cooc)
                base_rgb = RGB{Float64}(base_color)
            else
                c0 = Makie.to_color(env_color_spec)
                base_rgb = RGB{Float64}(c0)
            end

            if mode === :ring
                path_mean = ribbon_path(ribbon, r; tension = tension, n_bezier = n_bez)
                path_env = ribbon_path(erw, r; tension = tension, n_bezier = n_bez)
                if bands === 1
                    c = env_rgba_base(is_dimmed, base_rgb, l_out)
                    ring_poly = ribbon_envelope_ring_polygon(path_mean, path_env)
                    push!(polys_and_colors, (ring_poly, c))
                else
                    c_in, c_out = env_rgba_duo(is_dimmed, base_rgb, l_in, l_out)
                    s_mid = (1.0 + sc) / 2
                    rib_mid = ribbon_widened(ribbon, s_mid)
                    path_mid = ribbon_path(rib_mid, r; tension = tension, n_bezier = n_bez)
                    ring_outer = ribbon_envelope_ring_polygon(path_mid, path_env)
                    ring_inner = ribbon_envelope_ring_polygon(path_mean, path_mid)
                    push!(polys_and_colors, (ring_outer, c_out))
                    push!(polys_and_colors, (ring_inner, c_in))
                end
            else
                c = env_rgba_base(is_dimmed, base_rgb, l_out)
                path = ribbon_path(erw, r; tension = tension, n_bezier = n_bez)
                push!(polys_and_colors, (Polygon(path.points), c))
            end
        end
        polys_and_colors
    end
    
    for_each_env = lift(envelope_data) do data
        # Makie `poly!` needs `Vector{<:Polygon}` (not `Any` or `AbstractPolygon`); empty must stay typed
        if isempty(data)
            return (Polygon{2,Float32}[], RGBA{Float64}[])
        end
        polys = [d[1] for d in data]
        colors = [d[2] for d in data]
        (polys, colors)
    end
    env_polys_obs = lift(x -> x[1], for_each_env)
    env_colors_obs = lift(x -> x[2], for_each_env)
    poly!(p, env_polys_obs; color = env_colors_obs, strokewidth = 0)
end

function draw_ribbons!(p::ChordPlotType, cooc_obs, layout_obs, colorscheme_obs, dimmed_obs, config_obs, envelope_obs)
    ribbon_data = lift(
        cooc_obs, layout_obs, colorscheme_obs, dimmed_obs, config_obs, p.ribbon_tension
    ) do cooc, layout, cs, dimmed, cfg, tension
        
        paths_colors = Tuple{Vector{Point2f}, RGBA{Float64}}[]
        isempty(layout.ribbons) && return paths_colors
        
        # Build normalizer only if scaling ribbons
        normalizer = if cfg.scaling.enabled && cfg.scaling.ribbons
            values = [abs(r.value) for r in layout.ribbons]
            ValueNormalizer(values, cfg.scaling.scale == :log)
        else
            nothing
        end
        
        for ribbon in layout.ribbons
            path = ribbon_path(ribbon, layout.inner_radius; tension=tension, n_bezier=40)
            
            # Dimmed: ribbon touches a dimmed label
            is_dimmed = ribbon.source.label_idx in dimmed || ribbon.target.label_idx in dimmed
            
            if is_dimmed
                color = RGBA(cfg.dim_color, cfg.dim_alpha)
            else
                base_color = resolve_ribbon_color(cs, ribbon, cooc)
                # Toggle off → fixed base alpha; on → scaled by value (or base alpha if no normalizer)
                alpha = if !cfg.scaling.ribbons
                    cfg.alpha.ribbons
                elseif normalizer !== nothing
                    compute_scaled_alpha(normalizer, ribbon.value, 
                                         cfg.alpha.ribbons, cfg.scaling.min_alpha)
                else
                    cfg.alpha.ribbons
                end
                color = RGBA(base_color, alpha)
            end
            
            push!(paths_colors, (path.points, color))
        end
        
        paths_colors
    end
    
    # Draw each ribbon as a polygon
    for_each_ribbon = lift(ribbon_data) do data
        polys = [Polygon(d[1]) for d in data]
        colors = [d[2] for d in data]
        (polys, colors)
    end
    
    polys_obs = lift(x -> x[1], for_each_ribbon)
    colors_obs = lift(x -> x[2], for_each_ribbon)

    has_env = lift(envelope_obs) do e; e !== nothing; end
    use_hollow = lift(envelope_obs, p.ribbon_envelope_mean) do env, m
        env === nothing && return false
        ms = m isa Symbol ? m : Symbol(m)
        ms === :hollow || ms === :tunnel
    end
    # Hollow: faint same-hue fill (ties tube to the band) + edge stroke; solid+envelope: optional white hairline
    fill_color_obs = lift(use_hollow, colors_obs, p.ribbon_envelope_mean_faint_fill) do hollow, cols, faint_in
        hollow || return cols
        k = clamp(Float64(faint_in), 0.0, 1.0)
        if k <= 0.0
            return [RGBA(Float64(c.r), Float64(c.g), Float64(c.b), 0.0) for c in cols]
        end
        return [
            RGBA(
                Float64(c.r), Float64(c.g), Float64(c.b), min(1.0, Float64(alpha(c)) * k)
            ) for c in cols
        ]
    end
    stroke_w_obs = lift(use_hollow, has_env, p.ribbon_envelope_stroke, p.ribbon_envelope_mean_strokewidth) do hollow, he, w_hair, w_mean
        if hollow
            w_mean > 0 ? Float64(w_mean) : 0.0
        elseif he && w_hair > 0
            Float64(w_hair)
        else
            0.0
        end
    end
    stroke_c_obs = lift(use_hollow, has_env, p.ribbon_envelope_stroke, colors_obs) do hollow, he, w_hair, cols
        n = length(cols)
        if hollow
            return [
                RGBA(
                    Float64(c.r), Float64(c.g), Float64(c.b), max(min(Float64(alpha(c)), 1.0), 0.0)
                ) for c in cols
            ]
        end
        if he && w_hair > 0
            return [RGBA(1.0, 1.0, 1.0, 0.5) for _ in 1:n]
        end
        return [RGBA(0.0, 0.0, 0.0, 0.0) for _ in 1:n]
    end
    poly!(p, polys_obs; color=fill_color_obs, strokewidth=stroke_w_obs, strokecolor=stroke_c_obs)
end

function draw_arcs!(p::ChordPlotType, cooc_obs, layout_obs, colorscheme_obs, dimmed_obs, config_obs)
    arc_data = lift(
        cooc_obs, layout_obs, colorscheme_obs, dimmed_obs, config_obs, p.arc_width
    ) do cooc, layout, cs, dimmed, cfg, arc_width
        
        polys_colors = Tuple{Vector{Point2f}, RGBA{Float64}}[]
        isempty(layout.arcs) && return polys_colors
        
        # Build normalizer only if scaling arcs
        normalizer = if cfg.scaling.enabled && cfg.scaling.arcs
            values = [abs(arc.value) for arc in layout.arcs]
            ValueNormalizer(values, cfg.scaling.scale == :log)
        else
            nothing
        end
        
        for arc in layout.arcs
            inner_r = layout.outer_radius - arc_width
            outer_r = layout.outer_radius
            poly_points = arc_polygon(inner_r, outer_r, arc.start_angle, arc.end_angle; n_points=40)
            
            if arc.label_idx in dimmed
                color = RGBA(cfg.dim_color, cfg.dim_alpha)
            else
                base_color = resolve_arc_color(cs, arc, cooc)
                # Toggle off → fixed base alpha; on → scaled by value (or base alpha if no normalizer)
                alpha = if !cfg.scaling.arcs
                    cfg.alpha.arcs
                elseif normalizer !== nothing
                    compute_scaled_alpha(normalizer, arc.value, 
                                         cfg.alpha.arcs, cfg.scaling.min_alpha)
                else
                    cfg.alpha.arcs
                end
                color = RGBA(base_color, alpha)
            end
            
            push!(polys_colors, (poly_points, color))
        end
        
        polys_colors
    end
    
    arc_polys_obs = lift(d -> [Polygon(x[1]) for x in d], arc_data)
    arc_colors_obs = lift(d -> [x[2] for x in d], arc_data)
    
    poly!(p, arc_polys_obs;
          color = arc_colors_obs,
          strokewidth = p.arc_strokewidth,
          strokecolor = p.arc_strokecolor)
end

function draw_labels!(p::ChordPlotType, cooc_obs, layout_obs, colorscheme_obs, dimmed_obs, config_obs)
    label_data = lift(
        cooc_obs, layout_obs, colorscheme_obs, dimmed_obs, config_obs,
        p.show_labels, p.label_offset, p.rotate_labels, p.label_justify, p.label_color
    ) do cooc, layout, cs, dimmed, cfg, show, offset, rotate, justify, label_color
        
        if !show
            return (Point2f[], String[], Float64[], Symbol[], Symbol[], RGBA{Float64}[])
        end
        
        positions = Point2f[]
        texts = String[]
        rotations = Float64[]
        haligns = Symbol[]
        valigns = Symbol[]
        colors = RGBA{Float64}[]
        
        isempty(layout.arcs) && return (positions, texts, rotations, haligns, valigns, colors)
        
        # Build normalizer only if scaling labels
        normalizer = if cfg.scaling.enabled && cfg.scaling.labels
            values = [abs(arc.value) for arc in layout.arcs]
            ValueNormalizer(values, cfg.scaling.scale == :log)
        else
            nothing
        end
        
        dimmed_color = RGBA(cfg.dim_color, cfg.dim_alpha)
        use_group_color = label_color === :group
        # For labels, :group always means group identity colors (V, D, etc.), not the
        # current colorscheme (which may be diverging/gradient and give near-white for small values).
        group_cs = use_group_color ? group_colors(cooc) : nothing

        for arc in layout.arcs
            lp = label_position(arc, layout.outer_radius, offset; rotate=rotate, justify=justify)
            push!(positions, lp.point)
            push!(texts, cooc.labels[arc.label_idx])
            push!(rotations, lp.angle)
            push!(haligns, lp.halign)
            push!(valigns, lp.valign)
            
            if arc.label_idx in dimmed
                push!(colors, dimmed_color)
            else
                base_color = use_group_color ? resolve_arc_color(group_cs, arc, cooc) : Makie.to_color(label_color)
                # Toggle off → fixed base alpha; on → scaled from min_alpha to cfg.alpha.labels
                alpha = if !cfg.scaling.labels
                    cfg.alpha.labels
                elseif normalizer !== nothing
                    compute_scaled_alpha(normalizer, arc.value, cfg.alpha.labels, cfg.scaling.min_alpha)
                else
                    cfg.alpha.labels
                end
                push!(colors, RGBA(RGB(base_color), alpha))
            end
        end
        
        (positions, texts, rotations, haligns, valigns, colors)
    end
    
    # Draw labels with proper alignment and per-label color/alpha
    positions_obs = lift(d -> d[1], label_data)
    texts_obs = lift(d -> d[2], label_data)
    rotations_obs = lift(d -> d[3], label_data)
    colors_obs = lift(d -> d[6], label_data)
    
    text!(p, positions_obs;
          text = texts_obs,
          rotation = rotations_obs,
          fontsize = p.label_fontsize,
          color = colors_obs,
          align = (:center, :center))
end

#==============================================================================#
# Value distribution histogram (for choosing min_ribbon_value)
#==============================================================================#

"""
    value_histogram!(ax, data; kwargs...)

Plot histogram of co-occurrence values on the given axis. `data` can be a single
`AbstractChordData` or an abstract container of them (e.g. `Vector` of matrices).
Use to inspect the distribution and choose a threshold (e.g. `min_ribbon_value`).
Keyword arguments are passed to `histogram!`.
"""
function value_histogram!(ax::Axis, data; kwargs...)
    vals = data isa AbstractChordData ? cooccurrence_values(data) : cooccurrence_values(collect(data))
    isempty(vals) && return ax
    histogram!(ax, vals; kwargs...)
    ax
end

"""
    value_histogram(data; kwargs...)

Create a figure with a histogram of co-occurrence values. `data` can be a single
`AbstractChordData` or an abstract container of them. Returns `(fig, ax, hist)`.
Use to choose `min_ribbon_value` from the distribution.
"""
function value_histogram(data; kwargs...)
    fig = Figure()
    ax = Axis(fig[1, 1], xlabel = "Co-occurrence value", ylabel = "Count")
    value_histogram!(ax, data; kwargs...)
    (fig, ax)
end

#==============================================================================#
# Axis Configuration
#==============================================================================#

"""
    setup_chord_axis!(ax::Axis; outer_radius=1.0, label_offset=0.12, padding=0.2)

Configure axis for chord plot display (equal aspect, no decorations). Sets axis limits
so that the circle and labels fit: limits extend to `outer_radius + label_offset + padding`.
Use the same `outer_radius` and `label_offset` as in your `chordplot!` call so that large
label offsets don't get clipped and the title doesn't overlap the labels.
"""
function setup_chord_axis!(ax::Axis; outer_radius::Real = 1.0, label_offset::Real = 0.12, padding::Real = 0.2)
    ax.aspect = DataAspect()
    hidedecorations!(ax)
    hidespines!(ax)
    limit = Float64(outer_radius) + Float64(label_offset) + Float64(padding)
    limits!(ax, -limit, limit, -limit, limit)
    ax
end
