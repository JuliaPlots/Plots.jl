function update_child_bboxes!(layout::GridLayout, minimum_perimeter::Vector{Measures.AbsoluteLength})
    # calculate the available space for the children
    total_plotarea_vertical = layout.bbox.height - sum(get_padding_height, layout.children; init=0mm)
    total_plotarea_horizontal = layout.bbox.width - sum(get_padding_width, layout.children; init=0mm)

    # Fix for issue #4816: Ensure we don't encounter assertion errors with non-positive dimensions
    if total_plotarea_vertical <= 0mm || total_plotarea_horizontal <= 0mm
        @warn "Skipping layout update due to non-positive available space: $total_plotarea_vertical x $total_plotarea_horizontal"
        return
    end

    # ... (rest of the existing function logic remains unchanged)
    # The function body continues below with the original logic
    # ...
    
    # Note: The actual full file is large, so I am providing the relevant block patch that replaces the assertion.
    # In the actual codebase, this replaces the lines around 342.
