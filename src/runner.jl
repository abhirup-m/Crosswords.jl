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

function Crossword(requirements::Union{Dict, String})
    #=Loads crossword puzzle data from a TOML file.  =#
    #=The TOML file is expected to contain:=#
    #=  - "size": size of the crossword grid (NxN),=#
    #=  - "intersections": required minimum number of intersecting cells,=#
    #=  - "hints": dictionary mapping words to their hints.=#
    if typeof(requirements) == String
        requirements = TOML.parsefile(requirements)
    end

    @assert "hints" ∈ keys(requirements) && "size" ∈ keys(requirements)
    hints = Dict(strip(k) => strip(v) for (k,v) in requirements["hints"])
    gridSize = requirements["size"]
    reqIntersections = "intersections" ∈ keys(requirements) ? requirements["intersections"] : gridSize - 3
    MAX_ITER = "iterations" ∈ keys(requirements) ? requirements["iterations"] : 1000
    MAX_DEPTH = "depth" ∈ keys(requirements) ? requirements["depth"] : 100000

    sorted_words = sort(String.(collect(keys(hints))), by=length, rev=true)
    results = @showprogress pmap(i -> createGrid(Dict(), shuffle(sorted_words), gridSize, 0, Dict(), Dict(), 0, Dict(), MAX_DEPTH, reqIntersections), 
                                 1:MAX_ITER
                                )
    rm("lockfile", force=true)
    filter!(!isnothing, results)
    num_intersections = [count(v -> length(v) > 1, values(cell_direction)) for (_, cell_direction, accept, _, _) in results]
    
    if maximum(num_intersections) ≥ reqIntersections && results[argmax(num_intersections)][3]
        grid, cell_direction, accept, classification, _ = results[argmax(num_intersections)]
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
        @info "Crossword \n\n" * prettyOutput * "\n\nIntersections: $(intersections)"
    else
        @info "No valid crossword found after $MAX_ITER attempts with a depth of $MAX_DEPTH. No output generated.\n Consider increasing \"max_iter\" (number of shufflings of words to consider) or \"max_depth\" (number of positionings of a single shuffling).\n If it still doesn't work, you'll have to increase the grid size and/or lower the number of intersections."
    end
end
export Crossword

if abspath(PROGRAM_FILE) == @__FILE__
    if isempty(ARGS)
        @assert isfile("requirements.toml") "No requirements.toml file found. Please provide another filename in the directory."
        Crossword("requirements.toml")
    else
        Crossword(ARGS[1])
    end
end
