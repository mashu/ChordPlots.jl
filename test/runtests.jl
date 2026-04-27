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
        @test n_layers(cooc) == 2
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
            at_zero = ribbon_for_envelope_draw(ribbon, 0.0)
            @test endpoint_span(at_zero.source) ≈ endpoint_span(ribbon.source)
            # scale = 1 + span / (2|m|)  →  span=20, m=10  →  factor 2
            twox = ribbon_for_envelope_draw(ribbon, 20.0)
            @test endpoint_span(twox.source) ≈ 2 * endpoint_span(ribbon.source)
            # span=60, m=10 → 1 + 3 = 4
            fourx = ribbon_for_envelope_draw(ribbon, 60.0)
            @test endpoint_span(fourx.source) ≈ 4 * endpoint_span(ribbon.source)
            # Small span: minimum extra angular width (1.15) applies when 1+span/2m would be below that
            tight = ribbon_for_envelope_draw(ribbon, 1.0)  # raw 1+1/20; floor 1.15
            @test endpoint_span(tight.source) ≈ 1.15 * endpoint_span(ribbon.source)
            @test_throws ArgumentError ribbon_for_envelope_draw(ribbon, -0.1)
        end
        
        @testset "envelope_widen_scale matches envelope ribbon" begin
            src = RibbonEndpoint{Float64}(1, 0.1, 0.3)
            tgt = RibbonEndpoint{Float64}(2, 2.0, 2.2)
            ribbon = Ribbon{Float64}(src, tgt, 10.0)
            s = envelope_widen_scale(ribbon, 9.0)
            rw = ribbon_widened(ribbon, s)
            re = ribbon_for_envelope_draw(ribbon, 9.0)
            @test rw.source.start_angle == re.source.start_angle
        end

        @testset "Envelope ring polygon" begin
            src = RibbonEndpoint{Float64}(1, 0.1, 0.3)
            tgt = RibbonEndpoint{Float64}(2, 2.0, 2.2)
            ribbon = Ribbon{Float64}(src, tgt, 10.0)
            wide = ribbon_for_envelope_draw(ribbon, 20.0)
            p_m = ribbon_path(ribbon, 0.8; n_bezier = 20)
            p_w = ribbon_path(wide, 0.8; n_bezier = 20)
            ring = ribbon_envelope_ring_polygon(p_m, p_w)
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
end

println("All tests passed!")
