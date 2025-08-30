using JSON, Random, ProgressMeter

# ----------------------
# Load crossword data
# ----------------------
"""
    loadData(dataFile::String)

Loads crossword puzzle data from a JSON file.  
The JSON file is expected to contain:
  - "size": size of the crossword grid (NxN),
  - "intersections": required minimum number of intersecting cells,
  - "hints": dictionary mapping words to their hints.

Returns:
  (size, intersections, hints::Dict{String,String})
"""
function loadData(dataFile::String)
    words_data = JSON.parsefile(dataFile)
    hints = Dict(strip(k) => strip(v) for (k,v) in words_data["hints"])
    return words_data["size"], words_data["intersections"], hints
end


# ----------------------
# Utility functions
# ----------------------

"""
    getSequence(head::Tuple{Int,Int}, direction::Int, word::String)

Given the starting coordinate `head`, the orientation `direction`,  
and a word, returns the list of grid coordinates where the word would fit.

- direction = 0 → horizontal placement,
- direction = 1 → vertical placement.

Coordinates are 0-indexed tuples `(row, col)`.
"""
function getSequence(head::Tuple{Int,Int}, direction::Int, word::String)
    if direction == 0
        return [(head[1] + i, head[2]) for i in 0:(length(word)-1)]  # horizontal
    else
        return [(head[1], head[2] + i) for i in 0:(length(word)-1)]  # vertical
    end
end


"""
    isAcceptable(word, sequence, direction, crossword, cell_direction, size, connections)

Checks whether a given `word` can legally be placed at the grid positions
`sequence`, respecting crossword constraints.

Validates:
  - Word fits inside the grid.
  - No illegal adjacency (extra touching of words not via intersections).
  - Matches existing characters if overlapping.
  - Consistent with cell directions already assigned.
"""
function isAcceptable(word::String, sequence::Vector{Tuple{Int,Int}}, direction::Int,
                      crossword::Dict{Tuple{Int,Int},Char},
                      cell_direction::Dict{Tuple{Int,Int},String},
                      size::Int, connections::Dict{Tuple{Int,Int},Vector{Tuple{Int,Int}}})

    # 1. Boundary check
    if sequence[end][1] ≥ size || sequence[end][2] ≥ size ||
       sequence[1][1] < 0 || sequence[1][2] < 0
        return false
    end

    # 2. Adjacent check: ensure word doesn't touch other words from head/tail
    for shift in (0, -1)
        adjacent = collect(sequence[shift == 0 ? 1 : end])  # pick start or end
        adjacent[direction+1] -= Int(2 * (shift + 0.5))
        if 0 ≤ adjacent[direction+1] < size &&
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
            if 0 ≤ adjacent[1] < size && 0 ≤ adjacent[2] < size &&
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


"""
    intersectingHead(word, direction, cell_direction, crossword)

Finds all possible starting positions (`heads`) for placing `word`
in a given direction, by looking for intersecting letters in the current grid.

- If the grid is empty, returns (0,0) as a trivial start.
- Otherwise, returns all valid heads that align with existing matching letters.
"""
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


"""
    addToGrid(word, sequence, direction, grid, cell_direction, connections)

Writes `word` into the crossword `grid` at the given `sequence` of coordinates.
Also updates:
  - `cell_direction` to track directions each cell is used in,
  - `connections` to track which letters belong to which word.
"""
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


"""
    removeFromGrid(word, sequence, direction, grid, cell_direction, connections)

Undo the placement of a `word`:
  - Restores `grid` to '#' where needed,
  - Removes last direction from `cell_direction`,
  - Pops connections to other letters.
"""
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
"""
    createGrid(...)

Recursive backtracking algorithm:
- Iterates over `words_list`,
- For each word, finds valid starting heads,
- Tries to place word, recurses on the remaining words,
- If fails, backtracks and tries alternatives.

Returns:
  (grid, cell_direction, accept::Bool, classification, depth)
"""
function createGrid(grid, words_list, size, direction, cell_direction, classification,
                    depth, connections, MAX_DEPTH)
    for word in words_list
        allowedHeads = all(v -> v == '#', values(grid)) ?
                        [(i,j) for i in 0:size-1, j in 0:size-1] :
                        intersectingHead(word, direction, cell_direction, grid)

        for head in allowedHeads
            depth += 1
            if depth > MAX_DEPTH
                return grid, cell_direction, false, classification, depth
            end

            sequence = getSequence(head, direction, word)
            if isAcceptable(word, sequence, direction, grid, cell_direction, size, connections)
                addToGrid(word, sequence, direction, grid, cell_direction, connections)
                accept = false
                if length(words_list) > 1
                    grid, cell_direction, accept, classification, depth =
                        createGrid(grid, filter(!=(word), words_list), size, 1-direction,
                                   cell_direction, classification, depth, connections, MAX_DEPTH)
                else
                    accept = true
                end
                if accept
                    push!(classification[direction], (size * sequence[1][1] + sequence[1][2], word))
                    return grid, cell_direction, true, classification, depth
                else
                    removeFromGrid(word, sequence, direction, grid, cell_direction, connections)
                end
            end
        end
    end
    return grid, cell_direction, false, classification, depth
end


# ----------------------
# Main crossword runner
# ----------------------
"""
    runCrossword(dataFile; MAX_ITER=100, MAX_DEPTH=100000)

Driver function:
- Loads crossword words + metadata.
- Repeatedly attempts to construct a valid crossword (`MAX_ITER` trials).
- Uses recursive backtracking with limit `MAX_DEPTH`.
- Randomizes word order between attempts.

On success:
  - Prints crossword grid,
  - Returns classification of words into Across/Down.
On failure:
  - Throws error after exhausting iterations.
"""
function runCrossword(dataFile::String; MAX_ITER::Int=100, MAX_DEPTH::Int=100000)
    size, reqIntersections, words_data = loadData(dataFile)
    sorted_words = sort(String.(collect(keys(words_data))), by=length, rev=true)

    @showprogress for _ in 1:MAX_ITER
        # Initialize empty grid and metadata
        grid = Dict((i,j) => '#' for i in 0:size-1, j in 0:size-1)
        cell_direction = Dict((i,j) => "" for i in 0:size-1, j in 0:size-1)
        connections = Dict((i,j) => [(i,j)] for i in 0:size-1, j in 0:size-1)
        classification = Dict(0 => Tuple{Int,String}[], 1 => Tuple{Int,String}[])

        # Try to build crossword
        grid, cell_direction, accept, classification, depth =
            createGrid(grid, sorted_words, size, 0, cell_direction, classification, 0, connections, MAX_DEPTH)

        # Check if valid
        if accept && count(v -> length(v) > 1, values(cell_direction)) ≥ reqIntersections
            # Print crossword
            for i in 0:size-1
                println(join([grid[(i,j)] for j in 0:size-1], " "))
            end
            return classification
        end

        # Randomize order for next attempt
        sorted_words = shuffle(sorted_words)
    end

    error("No valid crossword found after $MAX_ITER attempts")
end
