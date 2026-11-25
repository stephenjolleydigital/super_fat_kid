extends RefCounted
## Validate authored IDs against all owners, including chest rewards not spawned yet.
static func validate(owner: Node, id: String) -> bool:
	if id.strip_edges().is_empty():
		push_error("Missing persistent ID: " + str(owner.get_path()))
		return false
	var matches := 0
	for candidate in owner.get_tree().get_nodes_in_group("persistent_owners"):
		if candidate.persistence_id() == id:
			matches += 1
	if matches > 1:
		for candidate in owner.get_tree().get_nodes_in_group("persistent_owners"):
			if candidate.persistence_id() == id:
				candidate.invalidate_persistence()
		push_error("Duplicate persistent ID: " + id)
		return false
	return true
