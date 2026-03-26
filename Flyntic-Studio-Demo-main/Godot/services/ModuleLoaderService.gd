extends RefCounted

func load_modules(specs: Array[Dictionary]) -> Dictionary:
	var modules := {}
	var warnings: Array[String] = []

	for spec in specs:
		var key = str(spec.get("key", ""))
		var path = str(spec.get("path", ""))
		var missing_msg = str(spec.get("missing_msg", "Module missing"))
		if key == "" or path == "":
			continue

		var script = load(path)
		if script == null:
			warnings.append(missing_msg)
			continue

		var instance = script.new()
		if instance == null:
			warnings.append("Failed to instantiate %s" % key)
			continue

		var configure_data: Dictionary = spec.get("configure", {})
		if configure_data.size() > 0 and instance.has_method("configure"):
			instance.configure(configure_data)

		var post_init: Callable = spec.get("post_init", Callable())
		if post_init.is_valid():
			post_init.call(instance)

		modules[key] = instance

	return {
		"modules": modules,
		"warnings": warnings,
	}
