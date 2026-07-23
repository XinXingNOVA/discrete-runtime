extends GutTest


func test_runtime_entry_types_are_available_without_gameplay_packages() -> void:
	var effect := EffectEntry.new().configure(
		&"increment",
		&"counter",
		[],
		{&"amount": 1},
		PackedStringArray(["smoke"]),
		0,
		&"runtime_smoke_test"
	)

	assert_not_null(effect)
	assert_eq(effect.kind, DiscreteEntry.KIND_EFFECT)
	assert_eq(effect.op_name, &"increment")
	assert_eq(effect.payload, {&"amount": 1})
	assert_eq(effect.source, &"runtime_smoke_test")


func test_workspace_starts_with_no_active_entries() -> void:
	var workspace := DiscreteWorkspace.new()

	assert_false(workspace.has_active_entries())
	assert_false(workspace.has_error())
	assert_null(workspace.pending_exit)
