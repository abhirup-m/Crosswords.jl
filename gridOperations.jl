include("helpers.jl")

# ----------------------
# Utility functions
# ----------------------

#=
    addToGrid(word, sequence, direction, grid, cell_direction, connections)

Writes `word` into the crossword `grid` at the given `sequence` of coordinates.
Also updates:
  - `cell_direction` to track directions each cell is used in,
  - `connections` to track which letters belong to which word.
=#
function addToGrid(word::String, sequence::Vector{Tuple{Int,Int}}, direction::Int,
                   grid::Dict{Tuple{Int,Int},Char},
                   cell_direction::Dict{Tuple{Int,Int},String},
                   connections::Dict{Tuple{Int,Int},Vector{Tuple{Int,Int}}})
    for (loc, char) in zip(sequence, word)
        grid[loc] = char
        cell_direction[loc] *= string(direction)
        for locprime in sequence
            if locprime != loc
                push!(connections[loc], locprime)
            end
        end
    end
end


#=
    removeFromGrid(word, sequence, direction, grid, cell_direction, connections)

Undo the placement of a `word`:
  - Restores `grid` to '#' where needed,
  - Removes last direction from `cell_direction`,
  - Pops connections to other letters.
=#
function removeFromGrid(word::String, sequence::Vector{Tuple{Int,Int}}, direction::Int,
                        grid::Dict{Tuple{Int,Int},Char},
                        cell_direction::Dict{Tuple{Int,Int},String},
                        connections::Dict{Tuple{Int,Int},Vector{Tuple{Int,Int}}})
    for (loc, _) in zip(sequence, word)
        for _ in 1:(length(sequence)-1)
            pop!(connections[loc])
        end
        if length(cell_direction[loc]) == 1
            grid[loc] = '#'
            cell_direction[loc] = ""
        else
            cell_direction[loc] = cell_direction[loc][1:end-1]
        end
    end
end


# ----------------------
# Recursive placement
# ----------------------
#=
    createGrid(...)

Recursive backtracking algorithm:
- Iterates over `words_list`,
- For each word, finds valid starting heads,
- Tries to place word, recurses on the remaining words,
- If fails, backtracks and tries alternatives.

Returns:
  (grid, cell_direction, accept::Bool, classification, depth)
=#
function createGrid(grid, words_list, gridSize, direction, cell_direction, classification,
                    depth, connections, MAX_DEPTH)
    for word in words_list
        allowedHeads = all(v -> v == '#', values(grid)) ?
                        [(i,j) for i in 0:(gridSize - 1), j in 0:(gridSize - 1)] :
                        intersectingHead(word, direction, cell_direction, grid)

        for head in allowedHeads
            depth += 1
            if depth > MAX_DEPTH
                return grid, cell_direction, false, classification, depth
            end

            sequence = getSequence(head, direction, word)
            if isAcceptable(word, sequence, direction, grid, cell_direction, gridSize, connections)
                addToGrid(word, sequence, direction, grid, cell_direction, connections)
                accept = false
                if length(words_list) > 1
                    grid, cell_direction, accept, classification, depth =
                        createGrid(grid, filter(!=(word), words_list), gridSize, 1-direction,
                                   cell_direction, classification, depth, connections, MAX_DEPTH)
                else
                    accept = true
                end
                if accept
                    push!(classification[direction], (gridSize * sequence[1][1] + sequence[1][2], word))
                    return grid, cell_direction, true, classification, depth
                else
                    removeFromGrid(word, sequence, direction, grid, cell_direction, connections)
                end
            end
        end
    end
    return grid, cell_direction, false, classification, depth
end


