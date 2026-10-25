class_name Rack
extends RefCounted
## A row of buffer slots (Sushi Loop's counter; a basket or dock in later games). Items are ids
## waiting in arrival order; drain() moves the ones a new target accepts out in that order (the
## relief cascade). What an item matches on comes from a kinds table, so ids stay unique.

var capacity: int = 0
var items := PackedInt32Array()


func _init(size: int = 0) -> void:
	capacity = size


func copy() -> Rack:
	var rack := Rack.new(capacity)
	rack.items = items.duplicate()
	return rack


func size() -> int:
	return items.size()


func room() -> int:
	return capacity - items.size()


func is_full() -> bool:
	return items.size() >= capacity


## Adds `item` at the end; false (and nothing changes) if the rack is full.
func push(item: int) -> bool:
	if is_full():
		return false
	items.append(item)
	return true


## How many items have kind `kind` (kinds[item]).
func count_kind(kinds: PackedInt32Array, kind: int) -> int:
	var count := 0
	for item in items:
		if kinds[item] == kind:
			count += 1
	return count


## Removes up to `limit` items of kind `kind`, oldest first, and returns them in that order.
func drain(kinds: PackedInt32Array, kind: int, limit: int) -> PackedInt32Array:
	var taken := PackedInt32Array()
	var kept := PackedInt32Array()
	for item in items:
		if taken.size() < limit and kinds[item] == kind:
			taken.append(item)
		else:
			kept.append(item)
	items = kept
	return taken
