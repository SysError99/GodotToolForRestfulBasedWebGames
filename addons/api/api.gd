extends Node
class_name ApiNode


const USE_ROOT_URL = true


class HTTPObject extends HTTPRequest:
	signal completed(body)
	signal completed_content_type(type)
	signal completed_status_code(status_code)
	signal get_pck_again(path)


	var api: ApiNode
	var import_pck := false
	var import_pck_path := ""
	var import_pck_req_params := []


	func _init(parent: ApiNode) -> void:
		api = parent
		if connect("request_completed", self, "_request_completed") != OK:
			printerr("Cannot connect a signal of HTTPObject!")


	func safe_request(url: String, custom_headers: PoolStringArray = PoolStringArray(), ssl_validation_domain: bool = true, method: int = 0, request_data: String = "") -> void:
		if not is_inside_tree():
			yield(self, "tree_entered")
		yield(get_tree(), "idle_frame")
		request(url, custom_headers, ssl_validation_domain, method, request_data)


	func emit_signal_http_request_completed(status_code = 200, headers = PoolStringArray(), body = PoolByteArray()) -> void:
		if not is_inside_tree():
			yield(self, "tree_entered")
		yield(get_tree(), "idle_frame")
		emit_signal("request_completed", OK, status_code, headers, body)


	func emit_signal_http_request_completed_error(err) -> void:
		if not is_inside_tree():
			yield(self, "tree_entered")
		yield(get_tree(), "idle_frame")
		emit_signal("request_completed", err, 0, PoolStringArray(), PoolByteArray())


	func _request_completed(result: int, status_code: int, headers: PoolStringArray, body: PoolByteArray) -> void:
		if import_pck:
			if status_code == 200:
				if !ProjectSettings.load_resource_pack(download_file):
					var url := import_pck_req_params[0] as String
					import_pck_req_params[0] = url.substr(0, url.find("?")) + ("?r=%d" % randi())
					api.clear_pck([ import_pck_path ])
					callv("safe_request", import_pck_req_params)
					printerr("Cannot import resource pack of path '%s', trying to redownload..." % import_pck_path)
					return
				api.imported_pcks.push_back(download_file)
			else:
				printerr("PCK download of %s failed, target returns %d." % [import_pck_path, status_code])
				api.clear_pck([ import_pck_path ])
		queue_free()
		if result != OK:
			emit_signal("completed_status_code", -result)
			emit_signal("completed_content_type", "text")
			emit_signal("completed", "")
			return
		emit_signal("completed_status_code", status_code)
		for label in headers:
			if "access-token: " in label:
				api.access_token = label.replace("access-token: ", "")
				api.save_access_token()
			if "access-token:" in label:
				api.access_token = label.replace("access-token:", "")
				api.save_access_token()
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


const ACCESS_TOKEN_PATH = "user://access_token"
const CURRENT_VERSION_PATH = "user://current_version"


var imported_pcks := []
var window := JavaScript.get_interface("window")


var access_token := ""
var access_token_loaded := false
var version_checked := false


func clear_all_pck() -> void:
	var dir := Directory.new()
	if dir.open("user://") != OK:
		printerr("Cannot open user folder when trying to clean up all PCKs!")
		return
	dir.list_dir_begin(true, true)
	while true:
		var file := dir.get_next()
		if file == "":
			break
		if file.begins_with("."):
			continue
		if ".pck" in file:
			var path := "user://" + file
			dir.remove(path)
			print("Removed PCK:: %s" % path)
	dir.list_dir_end()


func clear_pck(list: Array) -> void:
	var dir := Directory.new()
	for e in list:
		var path := convert_to_pck_path(e)
		if dir.file_exists(path):
			dir.remove(path)
			print("Removed old PCK file: %s" % e)

func convert_to_pck_path(string: String) -> String:
	string = string.substr(0, string.find("?"))
	return "user://" + Marshalls.variant_to_base64(string).replace("/", "-").replace("=", "_") + ".pck"


func create_http() -> HTTPObject:
	var http := HTTPObject.new(self)
	add_child(http)
	return http


func get_auth_headers() -> PoolStringArray:
	return PoolStringArray([
		"access-token: " + access_token,
	])


func get_auth_json_headers() -> PoolStringArray:
	return PoolStringArray([
		"access-token: " + access_token,
		"Content-Type: applicaiton/json",
	])


func get_headers() -> PoolStringArray:
	return PoolStringArray([
	])


func get_json_headers() -> PoolStringArray:
	return PoolStringArray([
		"Content-Type: application/json",
	])


func http_auth_get(path: String = "", download_file: String = "") -> HTTPObject:
	var http := create_http()
	http.download_file = download_file
	http.safe_request(
		path,
		get_auth_headers(),
		true,
		HTTPClient.METHOD_GET,
		""
		)
	return http


func http_auth_post(path: String = "", dict_message: Dictionary = {}, download_file: String = "") -> HTTPObject:
	var http := create_http()
	http.download_file = download_file
	http.safe_request(
		path,
		get_auth_json_headers(),
		true,
		HTTPClient.METHOD_POST,
		JSON.print(dict_message)
		)
	return http


func http_get(path: String = "", download_file: String = "") -> HTTPObject:
	var http := create_http()
	http.download_file = download_file
	http.safe_request(
		path,
		get_headers(),
		true,
		HTTPClient.METHOD_GET,
		""
		)
	return http


func http_get_pck(path: String, replace = false) -> HTTPObject:
	var http := create_http()
	var req_params := [
		path + "?r=%d" % randi(),
		get_headers(),
		true,
		HTTPClient.METHOD_GET,
		"",
	]
	http.download_file = convert_to_pck_path(path)
	http.import_pck_req_params = req_params
	http.import_pck_path = path
	http.import_pck = true
	if http.download_file in imported_pcks:
		printerr("PCK already gets imported, if PCK replace is intended, the game should restart.")
		http.emit_signal_http_request_completed()
		return http
	if !replace:
		var dir := Directory.new()
		if dir.file_exists(http.download_file):
			printerr("File %s already exists, trying to import..." % path)
			http.emit_signal_http_request_completed()
			return http
	http.callv("safe_request", req_params)
	return http


func http_post(path: String = "", dict_message: Dictionary = {}, download_file: String = "") -> HTTPObject:
	var http := create_http()
	http.download_file = download_file
	http.safe_request(
		path,
		get_json_headers(),
		true,
		HTTPClient.METHOD_POST,
		JSON.print(dict_message)
		)
	return http


func load_access_token() -> void:
	var dir := Directory.new()
	if dir.file_exists(ACCESS_TOKEN_PATH):
		var file := File.new()
		if file.open(ACCESS_TOKEN_PATH, File.READ) != OK:
			printerr("Cannot open access token!")
			return
		access_token = file.get_as_text()
		file.close()
		print("Access token loaded.")
	access_token_loaded = true


func save_access_token() -> void:
	var file = File.new()
	if file.open(ACCESS_TOKEN_PATH, File.WRITE) != OK:
		printerr("Canot open access token file to write!")
		return
	file.store_string(access_token)
	file.close()
	print("Access token saved.")


func set_access_token(value: String) -> void:
	access_token = value
	save_access_token()


func _ready() -> void:
	randomize()
	load_access_token()
	version_check_loop()


func version_check() -> void:
	var file := File.new()
	var dir := Directory.new()
	if !is_instance_valid(window):
		printerr("Cannot get valid 'window' interface, cannot proceed version check.")
		version_checked = true
		return
	var version_file_url := window.location.href as String
	var version_file_url_splitted := version_file_url.split("/")
	if !".html" in version_file_url_splitted[version_file_url_splitted.size() - 1]:
		version_file_url += "index.html"
	version_file_url += ".ver.txt?r=%d" % randi()
	var http := http_get(version_file_url)
	var status_code := yield(http, "completed_status_code") as int
	var content_type := yield(http, "completed_content_type") as String
	var body = yield(http, "completed")
	if status_code != 200 || content_type != "text":
		printerr("%s returns %d (%s), cannnot proceed version check" % [window.location.href, status_code, content_type])
		version_checked = true
		return
	var version := body as String
	if !dir.file_exists(CURRENT_VERSION_PATH):
		version_control_behaviour()
		print("Generating version indicator...")
		file.open(CURRENT_VERSION_PATH, File.WRITE)
		file.store_string(version)
		file.close()
		version_checked = true
		return
	file.open(CURRENT_VERSION_PATH, File.READ_WRITE)
	var current_version := file.get_as_text()
	file.store_string(version)
	file.close()
	if current_version == version:
		print("Version is up to date!")
		version_checked = true
		return
	version_control_behaviour()
	dir.remove(CURRENT_VERSION_PATH)
	yield(get_tree().create_timer(1), "timeout")
	print("Version isn't up to date, trying to refresh.")
	JavaScript.eval("alert('There is newer version, app will reload.');")
	JavaScript.eval("window.location.href = window.location.href;")


func version_check_loop() -> void:
	while true:
		version_check()
		yield(get_tree().create_timer(60), "timeout")


func version_control_behaviour() -> void:
	clear_all_pck()
