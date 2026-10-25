extends RefCounted
## Hand-made Sushi Loop levels for tests/test_sushi_*.gd, each worked through by hand from the
## rules in docs/SUSHI_LOOP.md (the comments give the expected play). Not a test file (no test_
## prefix, so GUT skips it); preload it. Written from the contract, not from game/sushi/.

const E := -1


## 12 slots; types 0,1,0,1,0,1 in slots 0-5; bentos [0, 1]; one open bento.
## take(2) packs plate 2 and steps to offset 1; take(1) packs plate 0, the window empties and the
## belt rolls on to offset 7, where plate 5 sits at window position 0.
static func rolling() -> SushiLevel:
	return SushiLevel.make([0, 1, 0, 1, 0, 1, E, E, E, E, E, E], [0, 1], 1, 3, 5)


## 12 slots; three type-1 plates (slots 0-2) come before three type-0 plates (slots 3-5); bentos
## [0, 1]; one open bento. The 1s must wait on the counter; when bento 0 closes, bento 1 opens and
## they hop in (the cascade). Path: take(0), take(2) -> counter [0, 1]; the belt rolls to offset 7;
## take(0) x3 packs plates 5, 4, 3 and closes bento 0; plates 0 and 1 cascade; take(0) at offset
## 10 packs plate 2 and wins. Smallest counter that solves it (par): 2.
static func cascade(counter: int = 5) -> SushiLevel:
	return SushiLevel.make([1, 1, 1, 0, 0, 0, E, E, E, E, E, E], [0, 1], 1, 3, counter)


## The cascade path above as window positions (counter 2 or more).
const CASCADE_PATH: Array[int] = [0, 2, 0, 0, 0, 0]


## Two open bentos of the same type: bentos [0, 0, 1]; 0s in slots 0-5, 1s in slots 9-11.
## take(2) three times packs plates 2, 1, 0 (each time the window's last plate is a 0): the first
## goes to slot 0 (tie), the next two to the fuller slot 0, which closes; bento 2 (type 1) opens there.
static func twins() -> SushiLevel:
	return SushiLevel.make([0, 0, 0, 0, 0, 0, E, E, E, 1, 1, 1], [0, 0, 1], 2, 3, 5)


## A state after playing `moves` (window positions) from the start of `level`.
static func played(level: SushiLevel, moves: Array[int]) -> SushiState:
	var state := SushiState.start(level)
	for w in moves:
		assert(state.take(w), "move %d should be legal" % w)
	return state
