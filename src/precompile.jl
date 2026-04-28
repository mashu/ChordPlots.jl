# src/precompile.jl
# Reduce time-to-first-plot by exercising the backend-independent layout and
# colour pipeline at package precompile time. The recipe itself is exercised
# in user code where a Makie backend is loaded.

PrecompileTools.@compile_workload begin
    matrix = [0 3 1 0;
              3 0 2 0;
              1 2 0 1;
              0 0 1 0]
    labels, groups = groups_from((:G1 => ["A", "B"], :G2 => ["C", "D"]))
    cooc = CoOccurrenceMatrix(matrix, labels, groups)

    # Layout pipeline
    layout = compute_layout(cooc)
    filter_ribbons(layout, 0)
    filter_ribbons_top_n(layout, 2)
    label_order(cooc)
    cooccurrence_values(cooc)

    # Color resolution (covers the three exported scheme types)
    gcs = group_colors(cooc)
    ccs = categorical_colors(nlabels(cooc))
    dcs = diverging_colors(cooc)
    arc = first(layout.arcs)
    resolve_arc_color(gcs, arc, cooc)
    resolve_arc_color(ccs, arc, cooc)
    resolve_arc_color(dcs, arc, cooc)
end
