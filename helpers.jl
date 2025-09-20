# ----------------------
# Utility functions
# ----------------------

#=
    getSequence(head::Tuple{Int,Int}, direction::Int, word::String)

Given the starting coordinate `head`, the orientation `direction`,  
and a word, returns the list of grid coordinates where the word would fit.

- direction = 0 → horizontal placement,
- direction = 1 → vertical placement.

Coordinates are 0-indexed tuples `(row, col)`.
=#
function getSequence(head::Tuple{Int,Int}, direction::Int, word::String)
    if direction == 0
        return [(head[1] + i, head[2]) for i in 0:(length(word)-1)]  # horizontal
    else
        return [(head[1], head[2] + i) for i in 0:(length(word)-1)]  # vertical
    end
end


#=
    isAcceptable(word, sequence, direction, crossword, cell_direction, size, connections)

Checks whether a given `word` can legally be placed at the grid positions
`sequence`, respecting crossword constraints.

Validates:
  - Word fits inside the grid.
  - No illegal adjacency (extra touching of words not via intersections).
  - Matches existing characters if overlapping.
  - Consistent with cell directions already assigned.
=#
function isAcceptable(word::String, sequence::Vector{Tuple{Int,Int}}, direction::Int,
                      crossword::Dict{Tuple{Int,Int},Char},
                      cell_direction::Dict{Tuple{Int,Int},String},
                      gridSize::Int, connections::Dict{Tuple{Int,Int},Vector{Tuple{Int,Int}}})

    # 1. Boundary check
    if sequence[end][1] ≥ gridSize || sequence[end][2] ≥ gridSize ||
       sequence[1][1] < 0 || sequence[1][2] < 0
        return false
    end

    # 2. Adjacent check: ensure word doesn't touch other words from head/tail
    for shift in (0, -1)
        adjacent = collect(sequence[shift == 0 ? 1 : end])  # pick start or end
        adjacent[direction+1] -= Int(2 * (shift + 0.5))
        if 0 ≤ adjacent[direction+1] < gridSize &&
           crossword[(adjacent[1], adjacent[2])] != '#'
            return false
        end
    end

    # 3. Per-character checks
    for (loc, char) in zip(sequence, word)

        # Ensure no illegal touching to left/right (if vertical) or up/down (if horizontal)
        for shift in (-1, 1)
            adjacent = if direction == 0
                (loc[1], loc[2] + shift)
            else
                (loc[1] + shift, loc[2])
            end
            if 0 ≤ adjacent[1] < gridSize && 0 ≤ adjacent[2] < gridSize &&
               crossword[adjacent] != '#' &&
               !(loc in connections[adjacent])
                return false
            end
        end

        # Ensure overlaps match existing letters and directions
        if crossword[loc] != '#' &&
           (crossword[loc] != char || cell_direction[loc] != string(1 - direction))
            return false
        end
    end

    return true
end


#=
    intersectingHead(word, direction, cell_direction, crossword)

Finds all possible starting positions (`heads`) for placing `word`
in a given direction, by looking for intersecting letters in the current grid.

- If the grid is empty, returns (0,0) as a trivial start.
- Otherwise, returns all valid heads that align with existing matching letters.
=#
function intersectingHead(word::String, direction::Int,
                          cell_direction::Dict{Tuple{Int,Int},String},
                          crossword::Dict{Tuple{Int,Int},Char})
    if all(v -> v == '#', values(crossword))
        return [(0,0)]
    end

    allowedHeads = Tuple{Int,Int}[]
    for (k,v) in crossword
        # Must intersect with a matching character
        if !(v in word)
            continue
        end
        # Skip if direction already occupied
        if occursin(string(direction), cell_direction[k])
            continue
        end
        # Find where to shift start position
        match = findfirst(==(v), collect(word))
        if match !== nothing
            if direction == 0
                head = (k[1] - (match-1), k[2])
            else
                head = (k[1], k[2] - (match-1))
            end
            push!(allowedHeads, head)
        end
    end
    return allowedHeads
end
