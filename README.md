# Crossy.jl

**Crossy.jl** is a crossword generator written in Julia. The input is a TOML file (`requirements.toml` in the repository) which contains the list of words to be put on the crossword and some other requirements for the crossword (size etc). The script tries to obtain a compatible arrangement of words on a grid that satisfies all requirements. If such an arrangement is found, it spits out another TOML file (`grid_details.toml`) with sufficient details to reconstruct the grid using a suitable parser.

## Usage

```sh
$ git pull https://github.com/abhirup-m/Crossy.jl.git
$ cd Crossy.jl
$ chmod +x crossy.jl
$ ./crossy.jl words.json
```

## Input file structure
The `requirements.toml` file passed as input to the script has the following structure:
```toml
size = 14
intersections = 12
iterations = 500
depth = 1000000

[hints]
MALARIA = "Infectious, misfolded protein that causes healthy proteins to misfold, leading to fatal neurodegenerative diseases"
MICROGLIA = "Brain’s resident immune cells that protect neurons but can drive chronic inflammation in disease."
INTEGRINS = "Cell surface receptors that anchor cells to the extracellular matrix and relay mechanical signals inside."
INFLAMMATION = "A bodily response to infection or injury, often causing redness and swelling."
ALLOSTASIS = "The process of achieving stability through physiological or behavioral changes in response to stress."
ASTROCYTES = "Star-shaped support cells in the brain that nourish neurons, maintain homeostasis, and turn harmful when reactive in disease."
HYPOXIA = "Low oxygen zones inside tumors that trigger survival, angiogenesis, and therapy resistance."
PARKINSON = "A neurodegenerative disorder marked by tremors and dopamine depletion."
ANGIOGENESIS = "Formation of new blood vessels that feed tumors and support their growth and spread."
VIRULENCE = "The degree of pathogenicity or ability of a microbe to cause disease."
```

## Example output

Running the script on a file with easy enough requirements leads to the following typical output:
```
┌ Info: Crossword 
│ 
│ M # # # # # H # # # # # # #
│ A S T R O C Y T E S # # # #
│ L # # # # # P # # # # # M #
│ A # A N G I O G E N E S I S
│ R # # # # # X # # # # # C #
│ I # V # # # I # # P # # R #
│ A # I N F L A M M A T I O N
│ # # R # # # # # # R # # G #
│ # # U # # # # # # K # # L #
│ # A L L O S T A S I S # I #
│ # # E # # # # # # N # # A #
│ # I N T E G R I N S # # # #
│ # # C # # # # # # O # # # #
│ # # E # # # # # # N # # # #
│ 
└ Intersections: 12
```

The script lso generates a TOML file with details of the grid; it can be used to uniquely reconstruct the crossword by a suitable parser:
```toml
blanks = [126, 140, 154, 168, 182, 1, 29, 43, 57, 71, 85, 99, 113, 141, 169, 183, 2, 30, 58, 3, 31, 59, 73, 101, 115, 143, 171, 185, 4, 32, 60, 74, 102, 116, 144, 172, 186, 5, 33, 61, 75, 103, 117, 145, 173, 187, 104, 118, 146, 174, 188, 7, 35, 63, 77, 189, 8, 36, 64, 78, 106, 120, 148, 176, 190, 9, 37, 65, 79, 107, 121, 149, 177, 191, 10, 24, 38, 66, 80, 108, 122, 150, 164, 178, 192, 11, 25, 39, 67, 81, 109, 123, 137, 151, 165, 179, 193, 12, 26, 166, 180, 194, 13, 27, 41, 69, 83, 111, 125, 139, 153, 167, 181, 195]
size = 14

[across]
INTEGRINS = [155, "Cell surface receptors that anchor cells to the extracellular matrix and relay mechanical signals inside."]
ANGIOGENESIS = [44, "Formation of new blood vessels that feed tumors and support their growth and spread."]
ALLOSTASIS = [127, "The process of achieving stability through physiological or behavioral changes in response to stress."]
INFLAMMATION = [86, "A bodily response to infection or injury, often causing redness and swelling."]
ASTROCYTES = [14, "Star-shaped support cells in the brain that nourish neurons, maintain homeostasis, and turn harmful when reactive in disease."]

[down]
MICROGLIA = [40, "Brain’s resident immune cells that protect neurons but can drive chronic inflammation in disease."]
HYPOXIA = [6, "Low oxygen zones inside tumors that trigger survival, angiogenesis, and therapy resistance."]
MALARIA = [91, "Infectious, misfolded protein that causes healthy proteins to misfold, leading to fatal neurodegenerative diseases"]
VIRULENCE = [72, "The degree of pathogenicity or ability of a microbe to cause disease."]
PARKINSON = [0, "A neurodegenerative disorder marked by tremors and dopamine depletion."]
```
