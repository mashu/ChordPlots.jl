# test/runtests.jl
using Test
using ChordPlots
using Colors

@testset "ChordPlots.jl" begin
    
    @testset "Types" begin
        @testset "GroupInfo" begin
            g = GroupInfo{String}(:test, ["a", "b", "c"], 1:3)
            @test length(g) == 3
            @test g.name == :test
            @test g.indices == 1:3
            
            # Iteration
            labels = collect(g)
            @test labels == ["a", "b", "c"]
        end
        
        @testset "ArcSegment" begin
            arc = ArcSegment{Float64}(1, 0.0, π/2, 10.0)
            @test arc.label_idx == 1
            @test arc_span(arc) ≈ π/2
            @test arc_midpoint(arc) ≈ π/4
        end
        
        @testset "RibbonEndpoint" begin
            ep = RibbonEndpoint{Float64}(1, 0.0, π/4)
            @test endpoint_span(ep) ≈ π/4
            @test endpoint_midpoint(ep) ≈ π/8
        end
        
        @testset "Ribbon" begin
            src = RibbonEndpoint{Float64}(1, 0.0, 0.1)
            tgt = RibbonEndpoint{Float64}(2, π, π+0.1)
            r = Ribbon{Float64}(src, tgt, 5.0)
            @test !is_self_loop(r)
            
            # Self-loop
            self = Ribbon{Float64}(src, src, 3.0)
            @test is_self_loop(self)
        end
    end
    
    @testset "CoOccurrenceMatrix Construction" begin
        @testset "Direct construction" begin
            matrix = [4 2 1; 2 3 2; 1 2 2]
            labels = ["x", "y", "z"]
            groups = [GroupInfo{String}(:G1, ["x", "y"], 1:2),
                     GroupInfo{String}(:G2, ["z"], 3:3)]
            
            cooc = CoOccurrenceMatrix(matrix, labels, groups)
            
            @test cooc["x", "y"] == 2
            @test cooc[1, 2] == 2
            @test total_flow(cooc, 1) == sum(matrix[1, :])
        end
    end

    @testset "CoOccurrenceLayers" begin
        l1 = [0.0 0.4; 0.0 0.0]
        l2 = [0.0 0.2; 0.0 0.0]
        layers = cat(l1, l2; dims=3)
        labels = ["A", "B"]
        groups = [GroupInfo{String}(:G, labels, 1:2)]
        cooc = CoOccurrenceLayers(layers, labels, groups)
        @test nlayers(cooc) == 2
        @test cooc[1, 2] ≈ 0.6
        @test abs_total_flow(cooc, 1) ≈ 0.6
        layout = compute_layout(cooc)
        @test nribbons(layout) == 2
        # Each donor layer starts from the same arc origin for that label
        r1, r2 = layout.ribbons[1], layout.ribbons[2]
        @test r1.source.start_angle ≈ r2.source.start_angle
        @test r1.target.start_angle ≈ r2.target.start_angle
        dcs = diverging_colors(cooc)
        @test dcs.range[1] < dcs.range[2]
    end
    
    @testset "Layout Computation" begin
        matrix = [0 3 1 0 0 0;
                  3 0 2 0 0 0;
                  1 2 0 0 0 0;
                  0 0 0 0 2 1;
                  0 0 0 2 0 3;
                  0 0 0 1 3 0]
        labels = ["V1", "V2", "V3", "D1", "D2", "J1"]
        groups = [
            GroupInfo{String}(:V, ["V1", "V2", "V3"], 1:3),
            GroupInfo{String}(:D, ["D1", "D2"], 4:5),
            GroupInfo{String}(:J, ["J1"], 6:6),
        ]
        cooc = CoOccurrenceMatrix(matrix, labels, groups)
        
        @testset "Default layout" begin
            layout = compute_layout(cooc)
            
            @test narcs(layout) == nlabels(cooc)
            @test nribbons(layout) > 0
            @test layout.inner_radius < layout.outer_radius
        end
        
        @testset "Custom config" begin
            config = LayoutConfig(
                inner_radius = 0.5,
                outer_radius = 0.9,
                gap_fraction = 0.1
            )
            layout = compute_layout(cooc, config)
            
            @test layout.inner_radius == 0.5
            @test layout.outer_radius == 0.9
        end
        
        @testset "Ribbon filtering" begin
            layout = compute_layout(cooc)
            n_original = nribbons(layout)
            
            # Filter should reduce ribbons (or keep same if all above threshold)
            filtered = filter_ribbons(layout, 1.0)
            @test nribbons(filtered) <= n_original
        end
        
        @testset "Fixed label order" begin
            # Same data, fixed order of label indices -> reproducible layout for comparison
            order = [3, 1, 2, 4, 5, 6]  # permutation of 1:6
            config = LayoutConfig(label_order = order)
            layout = compute_layout(cooc, config)
            @test narcs(layout) == 6
            # First arc along the circle (smallest start_angle) should be for label 3
            first_label = argmin([a.start_angle for a in layout.arcs])
            @test first_label == 3
        end
        
        @testset "label_order() fetches order for reuse" begin
            # Get order as label names from one cooc, apply to another for comparable plots
            names_in_order = label_order(cooc)
            @test length(names_in_order) == nlabels(cooc)
            @test Set(names_in_order) == Set(cooc.labels)
            # Using that order in chordplot should be valid (same set)
            config = LayoutConfig(label_order = [cooc.label_to_index[l] for l in names_in_order])
            layout = compute_layout(cooc, config)
            @test narcs(layout) == 6
        end
        
        @testset "label_order() for multiple matrices" begin
            # Two matrices with partially overlapping labels (user-preprocessed)
            labels1 = ["V1", "D1", "D2", "J1"]
            groups1 = [
                GroupInfo{String}(:V, ["V1"], 1:1),
                GroupInfo{String}(:D, ["D1", "D2"], 2:3),
                GroupInfo{String}(:J, ["J1"], 4:4),
            ]
            mat1 = [0 2 1 0;
                    2 0 1 3;
                    1 1 0 1;
                    0 3 1 0]
            cooc1 = CoOccurrenceMatrix(mat1, labels1, groups1)

            labels2 = ["V2", "D1", "D3", "J1", "J2"]
            groups2 = [
                GroupInfo{String}(:V, ["V2"], 1:1),
                GroupInfo{String}(:D, ["D1", "D3"], 2:3),
                GroupInfo{String}(:J, ["J1", "J2"], 4:5),
            ]
            mat2 = [0 1 0 0 0;
                    1 0 2 1 1;
                    0 2 0 0 1;
                    0 1 0 0 3;
                    0 1 1 3 0]
            cooc2 = CoOccurrenceMatrix(mat2, labels2, groups2)
            
            # Should include union of all labels (V1, V2, D1, D2, D3, J1, J2)
            order_all = label_order(cooc1, cooc2)  # varargs
            @test length(order_all) == 7
            @test "V1" in order_all && "V2" in order_all
            @test "D1" in order_all && "D2" in order_all && "D3" in order_all
            @test "J1" in order_all && "J2" in order_all
            
            # With include_all=false, only common labels
            order_common = label_order([cooc1, cooc2]; include_all=false)
            @test "D1" in order_common && "J1" in order_common
            @test !("V1" in order_common)  # V1 only in cooc1
            @test !("D2" in order_common)  # D2 only in cooc1
            
            # sort_by options
            order_val = label_order([cooc1, cooc2]; sort_by=:value)
            @test length(order_val) == 7
            order_none = label_order([cooc1, cooc2]; sort_by=:none)
            @test length(order_none) == 7
            
            # Test that superset order can be applied to individual matrices
            # (order_all has 7 labels but cooc1 only has 5, cooc2 only has 5)
            # resolve_label_order should filter to matching labels while preserving order
            resolved1 = ChordPlots.resolve_label_order(cooc1, order_all)
            resolved2 = ChordPlots.resolve_label_order(cooc2, order_all)
            @test resolved1 !== nothing
            @test resolved2 !== nothing
            @test length(resolved1) == nlabels(cooc1)  # 5 labels
            @test length(resolved2) == nlabels(cooc2)  # 5 labels
            
            # The relative order of common labels should be the same
            # Find indices of D1 and J1 in both resolved orders
            d1_pos_1 = findfirst(i -> cooc1.labels[i] == "D1", resolved1)
            j1_pos_1 = findfirst(i -> cooc1.labels[i] == "J1", resolved1)
            d1_pos_2 = findfirst(i -> cooc2.labels[i] == "D1", resolved2)
            j1_pos_2 = findfirst(i -> cooc2.labels[i] == "J1", resolved2)
            # D1 should come before J1 in both (if order_all has D1 before J1)
            d1_in_order = findfirst(==("D1"), order_all)
            j1_in_order = findfirst(==("J1"), order_all)
            @test (d1_in_order < j1_in_order) == (d1_pos_1 < j1_pos_1)
            @test (d1_in_order < j1_in_order) == (d1_pos_2 < j1_pos_2)
        end
    end
    
    @testset "Geometry" begin
        @testset "Arc points" begin
            points = arc_points(0.0, π/2, 1.0; n_points=5)
            @test length(points) == 5
            @test points[1] ≈ Point2f(1, 0) atol=1e-6
            @test points[end] ≈ Point2f(0, 1) atol=1e-6
        end
        
        @testset "Arc polygon" begin
            poly = arc_polygon(0.8, 1.0, 0.0, π/2; n_points=10)
            @test length(poly) == 20  # 10 outer + 10 inner
        end
        
        @testset "Ribbon path" begin
            src = RibbonEndpoint{Float64}(1, 0.0, 0.2)
            tgt = RibbonEndpoint{Float64}(2, π, π+0.2)
            ribbon = Ribbon{Float64}(src, tgt, 5.0)
            
            path = ribbon_path(ribbon, 0.8)
            @test length(path.points) > 0
            @test path.source_idx == 1
            @test path.target_idx == 2
        end
        
        @testset "Ribbon envelope geometry" begin
            src = RibbonEndpoint{Float64}(1, 0.1, 0.3)
            tgt = RibbonEndpoint{Float64}(2, 2.0, 2.2)
            ribbon = Ribbon{Float64}(src, tgt, 10.0)
            at_zero = ChordPlots.ribbon_for_envelope_draw(ribbon, 0.0)
            @test endpoint_span(at_zero.source) ≈ endpoint_span(ribbon.source)
            # scale = 1 + span / (2|m|)  →  span=20, m=10  →  factor 2
            twox = ChordPlots.ribbon_for_envelope_draw(ribbon, 20.0)
            @test endpoint_span(twox.source) ≈ 2 * endpoint_span(ribbon.source)
            # span=60, m=10 → 1 + 3 = 4
            fourx = ChordPlots.ribbon_for_envelope_draw(ribbon, 60.0)
            @test endpoint_span(fourx.source) ≈ 4 * endpoint_span(ribbon.source)
            # Small span: minimum extra angular width (1.15) applies when 1+span/2m would be below that
            tight = ChordPlots.ribbon_for_envelope_draw(ribbon, 1.0)  # raw 1+1/20; floor 1.15
            @test endpoint_span(tight.source) ≈ 1.15 * endpoint_span(ribbon.source)
            @test_throws ArgumentError ChordPlots.ribbon_for_envelope_draw(ribbon, -0.1)
        end

        @testset "envelope_widen_scale matches envelope ribbon" begin
            src = RibbonEndpoint{Float64}(1, 0.1, 0.3)
            tgt = RibbonEndpoint{Float64}(2, 2.0, 2.2)
            ribbon = Ribbon{Float64}(src, tgt, 10.0)
            s = ChordPlots.envelope_widen_scale(ribbon, 9.0)
            rw = ChordPlots.ribbon_widened(ribbon, s)
            re = ChordPlots.ribbon_for_envelope_draw(ribbon, 9.0)
            @test rw.source.start_angle == re.source.start_angle
        end

        @testset "Envelope ring polygon" begin
            src = RibbonEndpoint{Float64}(1, 0.1, 0.3)
            tgt = RibbonEndpoint{Float64}(2, 2.0, 2.2)
            ribbon = Ribbon{Float64}(src, tgt, 10.0)
            wide = ChordPlots.ribbon_for_envelope_draw(ribbon, 20.0)
            p_m = ribbon_path(ribbon, 0.8; n_bezier = 20)
            p_w = ribbon_path(wide, 0.8; n_bezier = 20)
            ring = ChordPlots.ribbon_envelope_ring_polygon(p_m, p_w)
            @test !isempty(ring.interiors)
        end
        
        @testset "Label position" begin
            arc = ArcSegment{Float64}(1, 0.0, π/4, 10.0)
            lp = label_position(arc, 1.0, 0.1)
            
            @test lp.point[1] > 0  # Right side of circle
            @test lp.point[2] > 0  # Upper half
        end
    end
    
    @testset "Colors" begin
        matrix = [0 2 1 0;
                  2 0 0 3;
                  1 0 0 1;
                  0 3 1 0]
        labels = ["a1", "a2", "b1", "b2"]
        groups = [
            GroupInfo{String}(:A, ["a1", "a2"], 1:2),
            GroupInfo{String}(:B, ["b1", "b2"], 3:4),
        ]
        cooc = CoOccurrenceMatrix(matrix, labels, groups)
        
        @testset "Group colors" begin
            cs = group_colors(cooc)
            @test cs isa GroupColorScheme
            @test haskey(cs.group_colors, :A)
            @test haskey(cs.group_colors, :B)
        end
        
        @testset "Categorical colors" begin
            cs = categorical_colors(5)
            @test length(cs.colors) == 5
        end
        
        @testset "Color resolution" begin
            cs = group_colors(cooc)
            arc = ArcSegment{Float64}(1, 0.0, 0.5, 1.0)
            color = resolve_arc_color(cs, arc, cooc)
            @test color isa RGB
        end
        
        @testset "Color utilities" begin
            c = RGB(0.5, 0.5, 0.5)
            
            ca = with_alpha(c, 0.5)
            @test ca isa RGBA
            @test alpha(ca) == 0.5
            
            dark = darken(c, 0.2)
            @test dark.r < c.r
            
            light = lighten(c, 0.2)
            @test light.r > c.r
        end
        
        @testset "Diverging colors" begin
            # Signed matrix: user-preprocessed (negative/decrease, positive/increase)
            matrix = [0.0  0.5 -0.2;
                      0.5  0.0  0.1;
                     -0.2  0.1  0.0]
            labels = ["A", "B", "C"]
            groups = [GroupInfo{String}(:G, labels, 1:3)]
            d = CoOccurrenceMatrix(matrix, labels, groups)
            @test any(x -> x < 0, d.matrix)
            @test any(x -> x > 0, d.matrix)
            
            # Create diverging color scheme
            cs = diverging_colors(d)
            @test cs isa DivergingColorScheme
            @test cs.symmetric == true
            @test cs.range[1] < 0 && cs.range[2] > 0
            
            # diff_colors is alias
            cs2 = diff_colors(d)
            @test cs2 isa DivergingColorScheme
            
            # Test color mapping
            min_val, max_val = cs.range
            color_neg = ChordPlots.diverging_color(cs, min_val)
            color_neu = ChordPlots.diverging_color(cs, 0.0)
            color_pos = ChordPlots.diverging_color(cs, max_val)
            
            # Negative should be bluish (default), positive should be reddish
            @test color_neg.r < color_neg.b  # blue dominant
            @test color_pos.r > color_pos.b  # red dominant
            @test isapprox(color_neu.r, color_neu.g, atol=0.1)  # neutral ~white
            @test isapprox(color_neu.g, color_neu.b, atol=0.1)
            
            # Layout should work with signed values
            layout = compute_layout(d)
            @test narcs(layout) > 0
            @test nribbons(layout) > 0
            
            # Ribbon color resolution
            if !isempty(layout.ribbons)
                r = layout.ribbons[1]
                ribbon_color = resolve_ribbon_color(cs, r, d)
                @test ribbon_color isa RGB
            end
        end
    end
    
    @testset "Value histogram" begin
        using CairoMakie
        matrix = [0 4 1; 4 0 2; 1 2 0]
        labels = ["A", "B", "C"]
        groups = [GroupInfo{String}(:G, labels, 1:3)]
        cooc = CoOccurrenceMatrix(matrix, labels, groups)
        @test cooccurrence_values(cooc) == [4.0, 1.0, 2.0]
        fig, ax = value_histogram(cooc)
        @test fig isa Figure
        # Multiple matrices share the histogram
        fig2, ax2 = value_histogram([cooc, cooc])
        @test fig2 isa Figure
    end

    @testset "Recipe optional envelope" begin
        using CairoMakie
        matrix = [0 4 1; 4 0 2; 1 2 0]
        labels = ["A", "B", "C"]
        groups = [GroupInfo{String}(:G, labels, 1:3)]
        cooc = CoOccurrenceMatrix(matrix, labels, groups)
        lo = zeros(3, 3)
        hi = zeros(3, 3)
        hi[1, 2] = hi[2, 1] = 8
        hi[1, 3] = hi[3, 1] = 4
        hi[2, 3] = hi[3, 2] = 5
        fig, ax, plt = chordplot(
            cooc;
            ribbon_envelope_low = lo,
            ribbon_envelope_high = hi,
        )
        @test fig isa Figure
    end
    
    @testset "Edge Cases" begin
        @testset "Empty co-occurrence" begin
            # Labels that never co-occur
            matrix = [1 0; 0 1]
            labels = ["x", "y"]
            groups = [GroupInfo{String}(:G, labels, 1:2)]

            cooc = CoOccurrenceMatrix(matrix, labels, groups)
            layout = compute_layout(cooc)

            # Should still produce valid layout
            @test narcs(layout) == 2
        end
    end

    @testset "groups_from helper" begin
        labels, groups = groups_from((:V => ["V1", "V2", "V3"], :D => ["D1", "D2"], :J => ["J1"]))
        @test labels == ["V1", "V2", "V3", "D1", "D2", "J1"]
        @test length(groups) == 3
        @test groups[1].name === :V && groups[1].indices == 1:3
        @test groups[2].name === :D && groups[2].indices == 4:5
        @test groups[3].name === :J && groups[3].indices == 6:6

        # Round-trip with CoOccurrenceMatrix
        matrix = zeros(Int, length(labels), length(labels))
        cooc = CoOccurrenceMatrix(matrix, labels, groups)
        @test ngroups(cooc) == 3
    end

    @testset "Recipe smoke tests" begin
        using CairoMakie
        labels, groups = groups_from((:V => ["V1", "V2"], :D => ["D1", "D2"], :J => ["J1"]))
        matrix = [0 2 1 0 0;
                  2 0 0 1 0;
                  1 0 0 2 1;
                  0 1 2 0 3;
                  0 0 1 3 0]
        cooc = CoOccurrenceMatrix(matrix, labels, groups)

        for kw in (
            (;),
            (colorscheme = :categorical,),
            (colorscheme = gradient_colors(min_val = 0.0, max_val = 5.0),),
            (alpha = 0.6,),
            (alpha = ComponentAlpha(0.5, 0.9, 1.0),),
            (alpha_by_value = true,),
            (alpha_by_value = ValueScaling(enabled = true,
                                           components = (ribbons = true, arcs = false, labels = false)),),
            (focus_group = :V, focus_labels = ["V1"]),
            (sort_by = :value,),
            (label_order = labels,),
            (min_ribbon_value = 1.5,),
            (min_arc_flow = 2.0,),
        )
            fig = Figure(size = (300, 300))
            ax = Axis(fig[1, 1])
            chordplot!(ax, cooc; kw...)
            setup_chord_axis!(ax)
            @test fig isa Figure
        end

        # Signed weights with diverging scheme
        signed = [0.0 0.4 -0.1 0.0 0.0;
                  0.4 0.0 0.0 -0.2 0.0;
                  -0.1 0.0 0.0 0.3 0.1;
                  0.0 -0.2 0.3 0.0 0.5;
                  0.0 0.0 0.1 0.5 0.0]
        scooc = CoOccurrenceMatrix(signed, labels, groups)
        fig, ax, _ = chordplot(scooc; colorscheme = diff_colors(scooc))
        @test fig isa Figure

        # Layered with stacked decomposition
        L = 3
        layers_arr = zeros(Float64, length(labels), length(labels), L)
        for ℓ in 1:L
            layers_arr[:, :, ℓ] .= matrix .* (0.5 + 0.2 * ℓ)
        end
        clay = CoOccurrenceLayers(layers_arr, labels, groups; aggregate = :sum)
        fig, ax, _ = chordplot(clay; layers_pair_span = :stack_layers)
        @test fig isa Figure
    end

    @testset "chord_theme" begin
        t = chord_theme()
        @test t isa Theme
    end

    @testset "Type Stability" begin
        matrix = [0 1; 1 0]
        labels = ["a", "b"]
        groups = [GroupInfo{String}(:G, labels, 1:2)]
        cooc = CoOccurrenceMatrix(matrix, labels, groups)

        # These should not throw type instability warnings
        @inferred nlabels(cooc)
        @inferred ngroups(cooc)
        @inferred total_flow(cooc, 1)

        layout = compute_layout(cooc)
        @inferred narcs(layout)
        @inferred nribbons(layout)
    end

    @testset "Show methods" begin
        matrix = [0 2; 2 0]
        labels = ["a", "b"]
        groups = [GroupInfo{String}(:G, labels, 1:2)]
        cooc = CoOccurrenceMatrix(matrix, labels, groups)
        s = sprint(show, MIME"text/plain"(), cooc)
        @test occursin("CoOccurrenceMatrix", s)
        @test occursin(":G", s)

        layout = compute_layout(cooc)
        s = sprint(show, MIME"text/plain"(), layout)
        @test occursin("ChordLayout", s)
        @test occursin("arcs", s)

        # Layered show
        layers_arr = cat([0.0 1.0; 1.0 0.0], [0.0 0.5; 0.5 0.0]; dims = 3)
        clay = CoOccurrenceLayers(layers_arr, labels, groups; aggregate = :sum)
        s = sprint(show, MIME"text/plain"(), clay)
        @test occursin("CoOccurrenceLayers", s)
        @test occursin("layer", s)

        # Compact show for ArcSegment / Ribbon / GroupInfo
        @test occursin("ArcSegment(label=1", sprint(show, layout.arcs[1]))
        @test occursin("Ribbon(", sprint(show, layout.ribbons[1]))
        @test occursin("GroupInfo(:G", sprint(show, groups[1]))
    end

    @testset "Group / palette helpers" begin
        @test ChordPlots.palette_colors(:default) == ChordPlots.wong_palette()
        @test ChordPlots.palette_colors(:modern)  == ChordPlots.modern_palette()
        @test_throws ArgumentError ChordPlots.palette_colors(:nonexistent)

        # Wong palette is now 7 distinct colors
        @test length(ChordPlots.wong_palette()) == 7
        @test length(unique(ChordPlots.wong_palette())) == 7

        # `take_n_colors` returns the prefix when n <= length(palette)
        small = ChordPlots.take_n_colors(ChordPlots.wong_palette(), 3)
        @test length(small) == 3
        @test small == ChordPlots.wong_palette()[1:3]

        # `take_n_colors` falls back to `distinguishable_colors` for n > length
        many = ChordPlots.take_n_colors(ChordPlots.wong_palette(), 15)
        @test length(many) == 15
        @test length(unique(many)) == 15  # no duplicates from cycling
        @test many[1:7] == ChordPlots.wong_palette()
    end

    @testset "categorical_colors palettes" begin
        cs1 = categorical_colors(5; palette = :default)
        @test length(cs1.colors) == 5
        cs2 = categorical_colors(5; palette = :modern)
        @test length(cs2.colors) == 5
        @test cs1.colors[1] != cs2.colors[1]
        @test_throws ArgumentError categorical_colors(3; palette = :unknown)
    end

    @testset "group_colors palette options" begin
        labels, groups = groups_from((:G1 => ["a"], :G2 => ["b"]))
        cooc = CoOccurrenceMatrix([0 1; 1 0], labels, groups)
        cs_default = group_colors(cooc)
        cs_modern  = group_colors(cooc; palette = :modern)
        @test cs_default isa GroupColorScheme
        @test cs_modern  isa GroupColorScheme
        @test cs_default.group_colors[:G1] != cs_modern.group_colors[:G1]
    end

    @testset "GradientColorScheme resolves arc + ribbon colors" begin
        labels, groups = groups_from((:G => ["a", "b", "c"]))
        cooc = CoOccurrenceMatrix([0.0 2.0 1.0; 2.0 0.0 3.0; 1.0 3.0 0.0], labels, groups)
        scheme = gradient_colors(colormap = :viridis, min_val = 0.0, max_val = 6.0)
        layout = compute_layout(cooc)
        # Both methods used to throw `MethodError`; they now return concrete colors.
        @test resolve_arc_color(scheme, layout.arcs[1], cooc) isa RGB
        @test resolve_ribbon_color(scheme, layout.ribbons[1], cooc) isa RGB
        # Degenerate range falls back to mid-gradient (no DivideError)
        scheme0 = gradient_colors(colormap = :viridis, min_val = 0.0, max_val = 0.0)
        @test resolve_arc_color(scheme0, layout.arcs[1], cooc) isa RGB
    end

    @testset "DivergingColorScheme arc by net flow" begin
        # Net flow is signed, so red <-> blue depends on arc index
        signed = [0.0  1.0  -2.0;
                  1.0  0.0   0.5;
                 -2.0  0.5   0.0]
        labels, groups = groups_from((:G => ["A", "B", "C"]))
        cooc = CoOccurrenceMatrix(signed, labels, groups)
        cs = diverging_colors(cooc)
        layout = compute_layout(cooc)
        # Arc A (net flow = -1.0) should be more blue; B (net flow = 1.5) more red.
        col_A = resolve_arc_color(cs, layout.arcs[1], cooc)
        col_B = resolve_arc_color(cs, layout.arcs[2], cooc)
        @test col_A.b > col_A.r
        @test col_B.r > col_B.b
    end

    @testset "filter_ribbons / filter_ribbons_top_n use magnitude" begin
        labels, groups = groups_from((:G => ["A", "B", "C"]))
        cooc = CoOccurrenceMatrix([0.0 5.0 -1.0;
                                    5.0 0.0  3.0;
                                   -1.0 3.0  0.0], labels, groups)
        layout = compute_layout(cooc)
        @test nribbons(layout) == 3

        kept = filter_ribbons(layout, 2.0)
        @test all(abs(r.value) >= 2.0 for r in kept.ribbons)
        @test nribbons(kept) == 2  # |5|, |3| but not |-1|

        # `filter_ribbons_top_n` selects by magnitude (so a strong negative beats a small positive)
        cooc2 = CoOccurrenceMatrix([0.0 1.0 -8.0;
                                     1.0 0.0  2.0;
                                    -8.0 2.0  0.0], labels, groups)
        layout2 = compute_layout(cooc2)
        top1 = filter_ribbons_top_n(layout2, 1)
        @test nribbons(top1) == 1
        @test top1.ribbons[1].value == -8.0  # magnitude wins

        # n > nribbons keeps all; n <= 0 keeps none
        @test nribbons(filter_ribbons_top_n(layout, 10)) == 3
        @test nribbons(filter_ribbons_top_n(layout, 0)) == 0
    end

    @testset "label_order varargs and label resolution" begin
        labels1, groups1 = groups_from((:V => ["V1"], :D => ["D1", "D2"], :J => ["J1"]))
        cooc1 = CoOccurrenceMatrix([0 2 1 0; 2 0 1 3; 1 1 0 1; 0 3 1 0], labels1, groups1)
        labels2, groups2 = groups_from((:V => ["V2"], :D => ["D1", "D3"], :J => ["J1", "J2"]))
        cooc2 = CoOccurrenceMatrix([0 1 0 0 0;
                                    1 0 2 1 1;
                                    0 2 0 0 1;
                                    0 1 0 0 3;
                                    0 1 1 3 0], labels2, groups2)
        # Varargs form
        order = label_order(cooc1, cooc2)
        @test "V1" in order && "V2" in order && "D3" in order
        # Varargs with kwargs (intersection)
        order_inter = label_order(cooc1, cooc2; include_all = false)
        @test "D1" in order_inter
        @test !("V1" in order_inter)
        # Empty list
        @test label_order(typeof(cooc1)[]) == String[]
    end

    @testset "ribbon_paths / label_positions / arc helpers" begin
        labels, groups = groups_from((:G => ["a", "b", "c"]))
        cooc = CoOccurrenceMatrix([0.0 1.0 1.0; 1.0 0.0 1.0; 1.0 1.0 0.0], labels, groups)
        layout = compute_layout(cooc)

        paths = ribbon_paths(layout.ribbons, layout.inner_radius; n_bezier = 16)
        @test length(paths) == nribbons(layout)
        @test all(!isempty(p.points) for p in paths)

        positions = label_positions(layout.arcs, layout.outer_radius, 0.1)
        @test length(positions) == narcs(layout)
        @test all(p.point isa ChordPlots.Point2f for p in positions)

        # arc_polygon basic shape
        poly = arc_polygon(0.8, 1.0, 0.0, π/2; n_points = 8)
        @test length(poly) == 16  # outer + inner
    end

    @testset "get_group" begin
        labels, groups = groups_from((:V => ["V1", "V2"], :D => ["D1"]))
        cooc = CoOccurrenceMatrix(zeros(Int, 3, 3), labels, groups)
        @test get_group(cooc, 1) === :V
        @test get_group(cooc, 3) === :D
        @test_throws ArgumentError get_group(cooc, 99)
    end

    @testset "n_layers deprecation alias" begin
        layers_arr = cat([0.0 1.0; 1.0 0.0], [0.0 0.5; 0.5 0.0]; dims = 3)
        labels, groups = groups_from((:G => ["a", "b"]))
        cooc = CoOccurrenceLayers(layers_arr, labels, groups; aggregate = :sum)
        # `n_layers` is deprecated but must still return the correct count for back-compat
        @test n_layers(cooc) == nlayers(cooc) == 2
    end

    @testset "aggregate_layers handles Int input" begin
        # Previously :mean / :median crashed for Int layers (InexactError)
        layers_int = cat([0 2; 2 0], [0 1; 1 0], [0 4; 4 0]; dims = 3)
        labels, groups = groups_from((:G => ["a", "b"]))
        cooc_sum    = CoOccurrenceLayers(layers_int, labels, groups; aggregate = :sum)
        cooc_mean   = CoOccurrenceLayers(layers_int, labels, groups; aggregate = :mean)
        cooc_median = CoOccurrenceLayers(layers_int, labels, groups; aggregate = :median)
        @test cooc_sum[1, 2]    == 7
        @test cooc_mean[1, 2]   ≈ 7 / 3
        @test cooc_median[1, 2] == 2
        # Compute layout on each
        @test narcs(compute_layout(cooc_sum))    == 2
        @test narcs(compute_layout(cooc_mean))   == 2
        @test narcs(compute_layout(cooc_median)) == 2
    end

    @testset "cooccurrence_values for layered + signed" begin
        # Layered: one entry per (i<j, layer) for non-zero values; signed values kept
        layers_arr = cat([0.0 2.0; 2.0 0.0], [0.0 -1.0; -1.0 0.0]; dims = 3)
        labels, groups = groups_from((:G => ["a", "b"]))
        clay = CoOccurrenceLayers(layers_arr, labels, groups; aggregate = :sum)
        @test cooccurrence_values(clay) == [2.0, -1.0]

        # Signed dense matrix: keeps both positive and negative non-zero entries
        labels3, groups3 = groups_from((:G => ["a", "b", "c"]))
        signed = CoOccurrenceMatrix([0.0 -3.0 0.0; -3.0 0.0 4.0; 0.0 4.0 0.0], labels3, groups3)
        # Upper triangle traversal: (1,2)=-3.0, (1,3)=0.0 (skipped), (2,3)=4.0
        @test cooccurrence_values(signed) == [-3.0, 4.0]
    end

    @testset "ComponentAlpha clamping and constructors" begin
        @test ComponentAlpha(0.5).ribbons == 0.5
        @test ComponentAlpha(-1.0).ribbons == 0.0  # clamped
        @test ComponentAlpha(2.0).labels  == 1.0  # clamped
        ca = ComponentAlpha((0.1, 0.5, 1.0))
        @test ca.ribbons == 0.1
        ca2 = ComponentAlpha(; ribbons = 0.3, arcs = 0.7, labels = 1.0)
        @test ca2.arcs == 0.7
    end

    @testset "ValueScaling validation and constructors" begin
        @test ValueScaling(false).enabled == false
        @test ValueScaling(true).ribbons == true
        vs = ValueScaling(; enabled = true,
                            components = (ribbons = true, arcs = false, labels = true),
                            min_alpha = 0.05, scale = :log)
        @test vs.arcs == false && vs.scale === :log
        # Positional tuple form
        vs2 = ValueScaling(; enabled = true, components = (true, false, true))
        @test vs2.arcs == false
        # Validation
        @test_throws ArgumentError ValueScaling(; scale = :linlog)
        @test_throws ArgumentError ChordPlots.components_tuple((ribbons = true,))  # missing keys
        @test_throws ArgumentError ChordPlots.components_tuple("not a tuple")
    end

    @testset "color utilities" begin
        c = RGB(0.5, 0.6, 0.7)
        @test alpha(with_alpha(c, 0.4)) ≈ 0.4
        d = darken(c, 0.5)
        @test d.r ≈ 0.25
        l = lighten(c, 0.5)
        @test l.r ≈ 0.75
    end

    @testset "setup_chord_axis! sets limits" begin
        using CairoMakie
        fig = Figure()
        ax = Axis(fig[1, 1])
        setup_chord_axis!(ax; outer_radius = 2.0, label_offset = 0.5, padding = 0.1)
        # limits are set via an Observable; just check the call returns the axis
        @test ax isa Axis
    end

    @testset "chord_theme accepts kwargs" begin
        t = chord_theme(; fontsize = 18, background = :transparent)
        @test t isa Theme
    end

    @testset "LayoutConfig direction = -1 (clockwise)" begin
        labels, groups = groups_from((:G => ["a", "b", "c"]))
        cooc = CoOccurrenceMatrix([0 1 1; 1 0 1; 1 1 0], labels, groups)
        cfg = LayoutConfig(direction = -1)
        layout = compute_layout(cooc, cfg)
        @test narcs(layout) == 3
        # All arcs still well-formed (start <= end)
        @test all(a.start_angle <= a.end_angle for a in layout.arcs)
    end

    @testset "compute_layout errors on all-zero matrix" begin
        labels, groups = groups_from((:G => ["a", "b"]))
        cooc = CoOccurrenceMatrix(zeros(Int, 2, 2), labels, groups)
        @test_throws Exception compute_layout(cooc)
    end

    @testset "label_order invalid permutation" begin
        labels, groups = groups_from((:G => ["a", "b", "c"]))
        cooc = CoOccurrenceMatrix([0 1 1; 1 0 1; 1 1 0], labels, groups)
        # Wrong length is silently ignored at the recipe level (resolve_label_order),
        # but compute_layout via LayoutConfig errors loudly.
        @test_throws ArgumentError compute_layout(cooc, LayoutConfig(label_order = [1, 2]))
        @test_throws ArgumentError compute_layout(cooc, LayoutConfig(label_order = [1, 1, 2]))  # not a perm
    end

    @testset "GroupInfo getindex / get / haskey" begin
        g = GroupInfo{String}(:G, ["x", "y"], 5:6)
        @test g["x"] == 5
        @test g["y"] == 6
        @test get(g, "z", -1) == -1
        @test haskey(g, "x")
        @test !haskey(g, "z")
        @test_throws KeyError g["z"]
    end

    @testset "CoOccurrenceMatrix dimension mismatch" begin
        @test_throws DimensionMismatch CoOccurrenceMatrix([0 1; 1 0], ["a"], [GroupInfo{String}(:G, ["a"], 1:1)])
    end

    @testset "CoOccurrenceLayers validation" begin
        labels, groups = groups_from((:G => ["a", "b"]))
        # Wrong outer constructor: non-square first two dims
        @test_throws DimensionMismatch CoOccurrenceLayers(zeros(Float64, 2, 3, 1), labels, groups)
        # Empty layers (third dim = 0)
        @test_throws ArgumentError CoOccurrenceLayers(zeros(Float64, 2, 2, 0), labels, groups)
        # Bad aggregate symbol
        @test_throws ArgumentError CoOccurrenceLayers(zeros(Float64, 2, 2, 1), labels, groups; aggregate = :nope)
    end

    @testset "resolve_label_order with String vector" begin
        labels, groups = groups_from((:G => ["a", "b", "c"]))
        cooc = CoOccurrenceMatrix([0 1 1; 1 0 1; 1 1 0], labels, groups)
        @test ChordPlots.resolve_label_order(cooc, ["c", "a", "b"]) == [3, 1, 2]
        @test ChordPlots.resolve_label_order(cooc, String[]) === nothing
        @test ChordPlots.resolve_label_order(cooc, nothing) === nothing
        # Subset (length mismatch) is rejected
        @test ChordPlots.resolve_label_order(cooc, ["a", "b"]) === nothing
    end

    @testset "abs_total_flow with signed matrix and string label" begin
        labels, groups = groups_from((:G => ["a", "b"]))
        cooc = CoOccurrenceMatrix([0.0 -3.0; -3.0 0.0], labels, groups)
        @test abs_total_flow(cooc, "a") ≈ 3.0
        @test total_flow(cooc, "a")     ≈ -3.0
    end
end

println("All tests passed!")
