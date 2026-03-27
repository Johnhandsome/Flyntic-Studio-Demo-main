extends RefCounted

func export_bundle(session_id: String, source_dir: String, target_path: String) -> bool:
	var packer = ZIPPacker.new()
	var err = packer.open(target_path)
	if err != OK:
		return false
		
	var files = [
		session_id + ".csv",
		session_id + ".jsonl",
		session_id + ".manifest.json"
	]
	
	var all_ok: bool = true
	for f in files:
		var full_path = source_dir + "/" + f
		if FileAccess.file_exists(full_path):
			var data = FileAccess.get_file_as_bytes(full_path)
			packer.start_file(f)
			packer.write_file(data)
			packer.close_file()
		else:
			all_ok = false
			
	packer.close()
	return all_ok
