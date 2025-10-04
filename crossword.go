package main

import (
	"fmt"
	// "slices"
)

const MAXDEPTH = 1000000

type Vertex struct {
	letters string
	// head position is calculated as 
	// 0 1 2
	// 3 4 5
	// 6 7 8
	// The formula comes out to be
	// x + y * ncol, setting (0, 0)
	// as top left corner
	head [2]int
	tail [2]int
	// across: 0, down: 1
	across bool
	squares []int
}

func make2D(loc int, size int) [2]int {
	return [2]int{loc / size, loc % size}
}

func CheckBounds(squares []int, across bool, size int) bool {
	end := len(squares) - 1
	if squares[end] > size * size - 1 {
		return false
	}
	if across && squares[0] / size != squares[end] / size {
		return false
	}
	return true
}

func Squares(length int, head int, across bool, size int) []int {
	squares := make([]int, length)
	for i := 0; i < length; i++ {
		if across {
			squares[i] = head + i
		} else {
			squares[i] = head + i * size
		}
	}
	return squares
}

func AreCompatible(v1 Vertex, v2 Vertex, size int) bool {
	w1 := v1.letters
	w2 := v2.letters

	// if it's the same word, they must be incompatible,
	// because we would have multiple heads or directions
	// for the same word
	if w1 == w2 {
		return false
	}

	// checking for incompatibility arising from
	// overlapping squares
	for i1, square1 := range v1.squares {
		for i2, square2 := range v2.squares {
			if square1 == square2 {
				 // if there's overlap, the letters have
				 // to be the same
				if v1.letters[i1] != v2.letters[i2] {
					return false
				}

				 // if there's overlap, and the letters
				 // are the same, the directions must be
				 // orthogonal
				if v1.across == v2.across {
					return false
				}
			}
			r1 := make2D(square1, size)
			r2 := make2D(square2, size)
			if (r1[0] - r2[0]) * (r1[0] - r2[0]) == 1 && r1[1] == r2[1] {
				return false
			}
			if (r1[1] - r2[1]) * (r1[1] - r2[1]) == 1 && r1[0] == r2[0] {
				return false
			}
		}
	}
	return true
}

func FindClique(vertices []Vertex, clique []Vertex, cliqueSize int, depth int, size int) ([]Vertex, []Vertex, int) {
	if len(clique) == cliqueSize || depth > MAXDEPTH {
		return vertices, clique, cliqueSize
	}
	var truncVertices []Vertex
	for index, v := range vertices {
		areCompatible := true
		for _, vExisting := range clique {
			if !AreCompatible(v, vExisting, size) {
				areCompatible = false
			}
		}
		if areCompatible {
			clique = append(clique, v)
			truncVertices = append(truncVertices, vertices[0:index]...)
			truncVertices = append(truncVertices, vertices[index+1:]...)
			break
		}
	}
	return FindClique(truncVertices, clique, cliqueSize, depth + 1, size)
}

func Crossword(size int, words []string) []Vertex {
	var vertices []Vertex
	index := 0
	for _, thisword := range words {
		for thishead := 0; thishead < size * size; thishead++ {
			for thisdir :=0; thisdir < 2; thisdir++ {
				vertices = append(vertices, Vertex{letters: thisword, head: make2D(thishead, size), across: thisdir == 0})
				vertices[index].squares = Squares(len(thisword), thishead, vertices[index].across, size)
				vertices[index].tail = make2D(vertices[index].squares[len(thisword)-1], size)
				if CheckBounds(vertices[index].squares, vertices[index].across, size) {
					index += 1
				} else {
					if index > 0 {
						vertices = vertices[:index]
					} else {
						vertices = []Vertex{}
					}
				}
			}
		}
	}
	return vertices
}

func main() {
	size := 11
	words := []string{"APPLE", "BRICK", "CLOUD", "DREAM", "EAGLE", "FLAME", "GRASS", "HOUSE", "MUSIC", "RIVER"}
	vertices := Crossword(size, words)
	vertices, clique, _ := FindClique(vertices, []Vertex{}, len(words), 0, size)
	if len(clique) < len(words) {
		fmt.Println("Could not find a clique.")
	}
	var crossword [][]string
	for i := 0; i < size; i++ {
		crossword = append(crossword, make([]string, size))
	}
	for _,v := range clique {
		for index,square := range v.squares {
			r := make2D(square, size)
			crossword[r[0]][r[1]] = string(v.letters[index])
		}
	}
	for i := 0;  i < size; i++ {
		for j := 0;  j < size; j++ {
			if len(crossword[i][j]) == 0 {
				fmt.Print("■")
			} else {
				fmt.Print(crossword[i][j])
			}
		}
		fmt.Println()
	}
}
