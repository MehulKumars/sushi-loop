extends GutTest
## Rack (game/kit/): buffer slots that keep arrival order and drain by kind.


func test_push_until_full() -> void:
	var rack := Rack.new(2)
	assert_true(rack.push(5))
	assert_true(rack.push(7))
	assert_true(rack.is_full())
	assert_false(rack.push(9))
	assert_eq(rack.items, PackedInt32Array([5, 7]))
	assert_eq(rack.room(), 0)


func test_drain_takes_the_oldest_of_a_kind_up_to_a_limit() -> void:
	var kinds := PackedInt32Array([0, 1, 0, 0, 1, 0])
	var rack := Rack.new(6)
	for item: int in [5, 0, 1, 2, 3, 4]:
		rack.push(item)
	assert_eq(rack.count_kind(kinds, 0), 4)
	var taken := rack.drain(kinds, 0, 3)
	assert_eq(taken, PackedInt32Array([5, 0, 2]))
	assert_eq(rack.items, PackedInt32Array([1, 3, 4]), "the rest keep their order")
	assert_eq(rack.drain(kinds, 2, 3).size(), 0)


func test_copy_is_independent() -> void:
	var rack := Rack.new(3)
	rack.push(1)
	var twin := rack.copy()
	twin.push(2)
	assert_eq(rack.size(), 1)
	assert_eq(twin.size(), 2)
	assert_eq(twin.capacity, 3)
