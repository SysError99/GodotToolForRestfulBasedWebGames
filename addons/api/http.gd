extends HTTPRequest
class_name HTTPObject


signal completed(body)
signal completed_content_type(type)
signal completed_status_code(status_code)


var api: Node


func emit_signal_http_request_completed(status_code = 200, headers = PoolStringArray(), body = PoolByteArray()) -> void:
	for n in 2:
		yield(get_tree(), "idle_frame")
	emit_signal("request_completed", OK, status_code, headers, body)


func emit_signal_http_request_completed_error(err) -> void:
	for n in 2:
		yield(get_tree(), "idle_frame")
	emit_signal("request_completed", err, 0, PoolStringArray(), PoolByteArray())


func _init() -> void:
	if connect("request_completed", self, "_request_completed") != OK:
		printerr("Cannot connect a signal of HTTPObject!")

func _request_completed(result: int, status_code: int, headers: PoolStringArray, body: PoolByteArray) -> void:
	queue_free()
	if get_meta("import_pck", false) && status_code == 200:
		if !ProjectSettings.load_resource_pack(download_file):
			printerr('Cannot import resource pack of path %s' % get_meta('import_pck_path'))
		else:
			var imported_pcks := api.get_meta("imported_pcks", []) as Array
			imported_pcks.push_back(download_file)
	if result != OK:
		emit_signal("completed_status_code", -result)
		emit_signal("completed_content_type", "text")
		emit_signal("completed", "")
		return
	else:
		emit_signal("completed_status_code", status_code)
	for label in headers:
		if "access-token: " in label:
			api.set_meta("access-token", label.replace('access-token: ',""))
			api.call_deferred("save_access_token")
		if "access-token:" in label:
			api.access_token = label.replace('access-token:',"")
			api.call_deferred("save_access_token")
		if "application/json" in label:
			emit_signal("completed_content_type", "json")
			emit_signal("completed", JSON.parse(body.get_string_from_utf8()).result)
			return
		if "text/" in label:
			emit_signal("completed_content_type", "text")
			emit_signal("completed", body.get_string_from_utf8())
			return
	emit_signal("completed_content_type", "bin")
	emit_signal("completed", body)
