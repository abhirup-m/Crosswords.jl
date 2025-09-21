#!/bin/env julia

# ----------------------
# Main crossword runner
# ----------------------
#=
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
=#
function generateCrossword(dataFile::String)

    #=Loads crossword puzzle data from a TOML file.  =#
    #=The TOML file is expected to contain:=#
    #=  - "size": size of the crossword grid (NxN),=#
    #=  - "intersections": required minimum number of intersecting cells,=#
    #=  - "hints": dictionary mapping words to their hints.=#
    data = TOML.parsefile(dataFile)
    hints = Dict(strip(k) => strip(v) for (k,v) in data["hints"])
    gridSize = data["size"]
    reqIntersections = data["intersections"]
    MAX_ITER = data["iterations"]
    MAX_DEPTH = data["depth"]
    sorted_words = sort(String.(collect(keys(hints))), by=length, rev=true)
    prettyOutput = nothing
    intersections = 0

    @sync @showprogress @distributed for i in 1:MAX_ITER
        # Randomize order for next attempt
        shuffSeq = Int[]
        for i in 1:length(sorted_words) 
            num = 0 
            while num == 0 || num ∈ shuffSeq 
                num = 1 + (abs(rand(Int, 1)[1]) % length(sorted_words)) 
            end 
            push!(shuffSeq, num) 
        end
        sorted_words = sorted_words[shuffSeq]

        # Initialize empty grid and metadata
        grid = Dict((i,j) => '#' for i in 0:(gridSize - 1), j in 0:(gridSize - 1))
        cell_direction = Dict((i,j) => "" for i in 0:(gridSize - 1), j in 0:(gridSize - 1))
        connections = Dict((i,j) => [(i,j)] for i in 0:(gridSize - 1), j in 0:(gridSize - 1))
        classification = Dict(0 => Tuple{Int,String}[], 1 => Tuple{Int,String}[])

        # Try to build crossword
        grid, cell_direction, accept, classification, _ =
            createGrid(grid, sorted_words, gridSize, 0, cell_direction, classification, 0, connections, MAX_DEPTH)

        # Check if valid
        if accept && count(v -> length(v) > 1, values(cell_direction)) ≥ reqIntersections
            # Build TOML-style hints dict
            blanks = []
            for i in 0:(gridSize - 1)
                for j in 0:(gridSize - 1)
                    if grid[(j, i)] == '#'
                        push!(blanks, j * gridSize + i)
                    end
                end
            end
            hints = Dict(
                "down" => Dict(word => [loc, hints[word]] for (loc, word) in classification[0]),
                "across" => Dict(word => [loc, hints[word]] for (loc, word) in classification[1]),
                "blanks" => blanks,
                "size" => gridSize
            )

            # Write to file
            open("grid_details.toml", "w") do io
                TOML.print(io, hints)
            end

            # Print crossword
            prettyOutput = join([join([grid[(i,j)] for j in 0:(gridSize - 1)], " ") for i in 0:(gridSize - 1)], "\n")
            intersections = count(v -> length(v) > 1, values(cell_direction))
            
            break
        end
    end

    if isnothing(prettyOutput)
        @info "No valid crossword found after $MAX_ITER attempts with a depth of $MAX_DEPTH. No output generated.\n Consider increasing \"max_iter\" (number of shufflings of words to consider) or \"max_depth\" (number of positionings of a single shuffling).\n If it still doesn't work, you'll have to increase the grid size and/or lower the number of intersections."
    else
        @info "Crossword \n\n" * prettyOutput * "\n\nIntersections: $(intersections)"
    end
end
export generateCrossword

if abspath(PROGRAM_FILE) == @__FILE__
    if isempty(ARGS)
        @assert isfile("requirements.toml") "No requirements.toml file found. Please provide another filename in the directory."
        generateCrossword("requirements.toml")
    else
        generateCrossword(ARGS[1])
    end
end
