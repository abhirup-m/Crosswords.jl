// file: crossword.go
package main

import (
	"fmt"
	"math/rand"
	"strings"
	"github.com/cheggaaa/pb/v3"
)

type Pos struct {
	R, C int
}

type Placement struct {
	Loc  int    // encoded start position: R*gridSize + C
	Word string // placed word
}

const (
	HORIZONTAL = 0
	VERTICAL   = 1
)

func main() {
	// === user-editable inputs ===
	gridSize := 14
	reqIntersections := 12    // minimum required intersecting cells
	MAX_ITER := 2000          // number of shuffles to try
	MAX_DEPTH := 100000      // recursion placement limit (global)
	words := []string{
		"INTEGRINS", "ANGIOGENESIS", "ALLOSTASIS", "INFLAMMATION", "ASTROCYTES", "MICROGLIA",
		"MICROGLIA", "HYPOXIA", "MALARIA", "VIRULENCE", "PARKINSON",
	}
	// ============================

	// sort words by length descending (like Julia code)
	// simple bubble-ish sort for clarity
	for i := 0; i < len(words); i++ {
		for j := i + 1; j < len(words); j++ {
			if len([]rune(words[j])) > len([]rune(words[i])) {
				words[i], words[j] = words[j], words[i]
			}
		}
	}

	var bestGrid map[Pos]rune
	// var bestCellDir map[Pos]string
	var bestClassification map[int][]Placement
	bestIntersections := -1
	bar := pb.StartNew(MAX_ITER)
	for iter := 0; iter < MAX_ITER; iter++ {
		// shuffle copy of words
		shuffled := make([]string, len(words))
		copy(shuffled, words)
		rand.Shuffle(len(shuffled), func(i, j int) { shuffled[i], shuffled[j] = shuffled[j], shuffled[i] })
		// shuffled = []string{"ANGIOGENESIS", "ALLOSTASIS", "INFLAMMATION", "INTEGRINS", "MICROGLIA", "ASTROCYTES"}
		// fmt.Println(shuffled)

		// initialize containers for createGrid
		grid := initGrid(gridSize)
		cellDir := initCellDir(gridSize)
		connections := initConnections(gridSize)
		classification := map[int][]Placement{0: {}, 1: {}}
		depth := 0

		accept, intersections := createGrid(&grid, shuffled, gridSize, HORIZONTAL, &cellDir, &classification, &depth, &connections, MAX_DEPTH, reqIntersections)
		if accept && intersections >= reqIntersections {
			bestGrid = grid
			// bestCellDir = cellDir
			bestClassification = classification
			bestIntersections = intersections
			// we found one satisfying the requirement; stop early
			break
		}
		// keep the one with max intersections so far
		if intersections > bestIntersections {
			bestGrid = grid
			// bestCellDir = cellDir
			bestClassification = classification
			bestIntersections = intersections
		}
		bar.Increment()
	}
	bar.Finish()

	if bestGrid == nil {
		fmt.Println("No valid crossword produced.")
		return
	}

	// print grid
	fmt.Println("Crossword:")
	for r := 0; r < gridSize; r++ {
		row := make([]string, gridSize)
		for c := 0; c < gridSize; c++ {
			ch := bestGrid[Pos{r, c}]
			row[c] = string(ch)
		}
		fmt.Println(strings.Join(row, " "))
	}
	fmt.Printf("\nIntersections: %d\n", bestIntersections)

	// print classification (down=0? We used 0=horizontal,1=vertical similar to Julia where classification[0] likely down)
	fmt.Println("\nClassification:")
	fmt.Println("Across:")
	for _, p := range bestClassification[HORIZONTAL] {
		fmt.Printf("  %d -> %s\n", p.Loc, p.Word)
	}
	fmt.Println("Down:")
	for _, p := range bestClassification[VERTICAL] {
		fmt.Printf("  %d -> %s\n", p.Loc, p.Word)
	}
}

// --- initializers
func initGrid(size int) map[Pos]rune {
	grid := make(map[Pos]rune)
	for r := 0; r < size; r++ {
		for c := 0; c < size; c++ {
			grid[Pos{r, c}] = '#'
		}
	}
	return grid
}

func initCellDir(size int) map[Pos]string {
	cd := make(map[Pos]string)
	for r := 0; r < size; r++ {
		for c := 0; c < size; c++ {
			cd[Pos{r, c}] = ""
		}
	}
	return cd
}

func initConnections(size int) map[Pos][]Pos {
	conn := make(map[Pos][]Pos)
	for r := 0; r < size; r++ {
		for c := 0; c < size; c++ {
			p := Pos{r, c}
			conn[p] = []Pos{p}
		}
	}
	return conn
}

// --- getSequence
func getSequence(head Pos, direction int, word string) []Pos {
	runes := []rune(word)
	seq := make([]Pos, len(runes))
	if direction == HORIZONTAL {
		for i := range runes {
			seq[i] = Pos{head.R + i, head.C}
		}
	} else {
		for i := range runes {
			seq[i] = Pos{head.R, head.C + i}
		}
	}
	return seq
}

// --- isAcceptable
func isAcceptable(word string, sequence []Pos, direction int, crossword map[Pos]rune, cellDirection map[Pos]string, gridSize int, connections map[Pos][]Pos) bool {
	runes := []rune(word)
	// 1. Boundary check
	last := sequence[len(sequence)-1]
	first := sequence[0]
	if last.R >= gridSize || last.C >= gridSize || first.R < 0 || first.C < 0 {
		return false
	}

	// 2. Adjacent check: ensure word doesn't touch other words from head/tail
	for _, shift := range []int{0, -1} {
		var adjacent Pos
		if shift == 0 {
			adjacent = sequence[0]
		} else {
			adjacent = sequence[len(sequence)-1]
		}
		// move two cells backwards/forwards along direction
		if shift == 0 {
			if direction == HORIZONTAL {
				adjacent = Pos{adjacent.R - 1, adjacent.C}
			} else {
				adjacent = Pos{adjacent.R, adjacent.C - 1}
			}
		} else {
			if direction == HORIZONTAL {
				adjacent = Pos{adjacent.R + 1, adjacent.C}
			} else {
				adjacent = Pos{adjacent.R, adjacent.C + 1}
			}
		}
		// check bounds and occupancy
		if adjacent.R >= 0 && adjacent.R < gridSize && adjacent.C >= 0 && adjacent.C < gridSize {
			if crossword[adjacent] != '#' {
				return false
			}
		}
	}

	// 3. Per-character checks
	for idx, loc := range sequence {
		char := runes[idx]
		// Ensure no illegal touching left/right (if vertical) or up/down (if horizontal)
		for _, shift := range []int{-1, 1} {
			var adjacent Pos
			if direction == HORIZONTAL {
				adjacent = Pos{loc.R, loc.C + shift}
			} else {
				adjacent = Pos{loc.R + shift, loc.C}
			}
			if adjacent.R >= 0 && adjacent.R < gridSize && adjacent.C >= 0 && adjacent.C < gridSize {
				if crossword[adjacent] != '#' {
					// if loc is not part of connections[adjacent], then illegal touching
					if !posInSlice(loc, connections[adjacent]) {
						return false
					}
				}
			}
		}

		// Ensure overlaps match existing letters and directions
		if crossword[loc] != '#' {
			if crossword[loc] != char {
				return false
			}
			// cellDirection should be the opposite direction (like Julia check)
			existing := cellDirection[loc]
			expected := fmt.Sprintf("%d", 1-direction)
			// if existing is not exactly expected (because Julia required equal string), reject
			// In Julia they do: cell_direction[loc] != string(1 - direction)
			// We'll enforce the same: existing must equal opposite direction when overlap happens.
			if existing != expected {
				return false
			}
		}
	}
	// deltas := []Pos{{-1, 0}, {1, 0}, {0, -1}, {0, 1}}
	// for _, loc := range sequence {
	// 	for _, d := range deltas {
	// 		nb := Pos{loc.R + d.R, loc.C + d.C}
	// 		if nb.R < 0 || nb.R >= gridSize || nb.C < 0 || nb.C >= gridSize {
	// 			continue
	// 		}
	// 		if crossword[nb] != '#' {
	// 			// neighbor occupied but not intersecting -> invalid
	// 			if !posInSlice(nb, connections[loc]) {
	// 				return false
	// 			}
	// 		}
	// 	}
	// }

	return true
}

func posInSlice(p Pos, list []Pos) bool {
	for _, q := range list {
		if q == p {
			return true
		}
	}
	return false
}

// --- intersectingHead
func intersectingHead(word string, direction int, cellDirection map[Pos]string, crossword map[Pos]rune, gridSize int) []Pos {
	// If grid empty (all '#'), return (0,0)
	allEmpty := true
	for _, v := range crossword {
		if v != '#' {
			allEmpty = false
			break
		}
	}
	if allEmpty {
		return []Pos{{0, 0}}
	}

	var allowed []Pos
	runes := []rune(word)
	for k, v := range crossword {
		// Must intersect with a matching character
		if !runeInRunes(v, runes) {
			continue
		}
		// Skip if direction already occupied at that cell
		if strings.Contains(cellDirection[k], fmt.Sprintf("%d", direction)) {
			continue
		}
		// find first matching index in word (like Julia's findfirst)
		matchIdx := indexOfRuneInRunes(v, runes)
		if matchIdx == -1 {
			continue
		}
		// matchIdx is 0-based; Julia used 1-based match so subtract accordingly
		if direction == HORIZONTAL {
			head := Pos{k.R - matchIdx, k.C}
			allowed = append(allowed, head)
		} else {
			head := Pos{k.R, k.C - matchIdx}
			allowed = append(allowed, head)
		}
	}
	return allowed
}

func runeInRunes(r rune, arr []rune) bool {
	for _, x := range arr {
		if x == r {
			return true
		}
	}
	return false
}
func indexOfRuneInRunes(r rune, arr []rune) int {
	for i, x := range arr {
		if x == r {
			return i
		}
	}
	return -1
}

// --- addToGrid / removeFromGrid
func addToGrid(word string, sequence []Pos, direction int, grid map[Pos]rune, cellDirection map[Pos]string, connections map[Pos][]Pos) {
	runes := []rune(word)
	for idx, loc := range sequence {
		grid[loc] = runes[idx]
		// append the direction char to the cellDirection string (mimic Julia string concat)
		cellDirection[loc] = cellDirection[loc] + fmt.Sprintf("%d", direction)
		// update connections
		for _, loc2 := range sequence {
			if loc2 != loc {
				connections[loc] = append(connections[loc], loc2)
			}
		}
	}
}

func removeFromGrid(word string, sequence []Pos, direction int, grid map[Pos]rune, cellDirection map[Pos]string, connections map[Pos][]Pos) {
	// revert placement similar to Julia:
	// pop connections for each loc (length(sequence)-1) times
	for _, loc := range sequence {
		// pop last (length(sequence)-1) entries
		removeCount := len(sequence) - 1
		if removeCount > len(connections[loc]) {
			connections[loc] = []Pos{loc}
		} else {
			connections[loc] = connections[loc][:len(connections[loc])-removeCount]
		}
		if len(cellDirection[loc]) == 1 {
			grid[loc] = '#'
			cellDirection[loc] = ""
		} else {
			// drop last char
			cellDirection[loc] = cellDirection[loc][:len(cellDirection[loc])-1]
		}
	}
}

// --- createGrid (recursive backtracking)
func createGrid(grid *map[Pos]rune, wordsList []string, gridSize int, direction int, cellDirection *map[Pos]string,
	classification *map[int][]Placement, depth *int, connections *map[Pos][]Pos, MAX_DEPTH int, reqIntersections int) (bool, int) {

	// if depth == 0: initialization already done by caller in this Go version

	// Helper to count intersections
	countIntersections := func() int {
		cnt := 0
		for _, v := range *cellDirection {
			if len(v) > 1 {
				cnt++
			}
		}
		return cnt
	}

	// iterate over words
	for _, word := range wordsList {
		// allowedHeads
		var allowedHeads []Pos
		if allGridEmpty(*grid) {
			allowedHeads = []Pos{}
			// produce all cells (Julia used all cells first time)
			for r := 0; r < gridSize; r++ {
				for c := 0; c < gridSize; c++ {
					allowedHeads = append(allowedHeads, Pos{r, c})
				}
			}
		} else {
			allowedHeads = intersectingHead(word, direction, *cellDirection, *grid, gridSize)
		}

		for _, head := range allowedHeads {
			*depth++
			if *depth > MAX_DEPTH {
				return false, countIntersections()
			}

			sequence := getSequence(head, direction, word)
			if isAcceptable(word, sequence, direction, *grid, *cellDirection, gridSize, *connections) {
				addToGrid(word, sequence, direction, *grid, *cellDirection, *connections)
				accept := false
				if len(wordsList) > 1 {
					// create new words list without current word
					newWords := filterOut(wordsList, word)
					ok, _ := createGrid(grid, newWords, gridSize, 1-direction, cellDirection, classification, depth, connections, MAX_DEPTH, reqIntersections)
					accept = ok
				} else {
					accept = true
				}
				if accept {
					// if intersections enough, mimic touch("lockfile") by simply noting success
					if countIntersections() >= reqIntersections {
						// record classification
					}
					// push classification for this direction
					start := sequence[0]
					(*classification)[direction] = append((*classification)[direction], Placement{Loc: gridSize*start.R + start.C, Word: word})
					return true, countIntersections()
				} else {
					removeFromGrid(word, sequence, direction, *grid, *cellDirection, *connections)
				}
			}
		}
	}

	return false, countIntersections()
}

// --- helpers used in createGrid
func allGridEmpty(grid map[Pos]rune) bool {
	for _, v := range grid {
		if v != '#' {
			return false
		}
	}
	return true
}

func filterOut(words []string, target string) []string {
	out := make([]string, 0, len(words)-1)
	for _, w := range words {
		if w != target {
			out = append(out, w)
		}
	}
	return out
}
