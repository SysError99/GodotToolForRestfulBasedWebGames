extends Node
class_name ApiNode


const USE_ROOT_URL = true
const ALPHABETS = "abcdefghijklmnopqrstuvwxyz"


var http_count := 0


class HTTPObject extends HTTPRequest:
	signal completed(body)
	signal completed_content_type(type)
	signal completed_status_code(status_code)


	var api: ApiNode
	var import_pck := false
	var import_pck_path := ""
	var import_pck_req_params := []


	func _init(parent: ApiNode) -> void:
		api = parent
		if connect("request_completed", self, "_request_completed") != OK:
			printerr("Cannot connect a signal of HTTPObject!")
		if connect("completed", self, "_completed_queue_free") != OK:
			printerr("Cannot connect a signal to queuefree itself.")


	func _completed_queue_free(_body) -> void:
		queue_free()


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
					import_pck_req_params[0] = api.get_path_force_cache_bust(url.substr(0, url.find("?")))
					api.clear_pck([ import_pck_path ])
					callv("safe_request", import_pck_req_params)
					printerr("Cannot import resource pack of path '%s', trying to redownload..." % import_pck_path)
					return
				api.imported_pcks.push_back(download_file)
				api._add_to_downloaded_pcks(download_file)
				print("Downloaded PCK: %s" % import_pck_path)
			else:
				printerr("PCK download of %s failed, target returns %d." % [import_pck_path, status_code])
				api.clear_pck([ import_pck_path ])
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
const ACCESS_TOKEN_KEYWORD = "gdtrbwg_access_token"
const CURRENT_VERSION_KEYWORD = "gdtrbwg_current_version"


var imported_pcks := []
var downloaded_pcks := {}
var window := JavaScript.get_interface("window")
var location := JavaScript.get_interface("location")
var local_storage := JavaScript.get_interface("localStorage")


var access_token := ""
var access_token_loaded := false
var http_headers := []
var version_checked := false


var version_control_function: FuncRef


func generate_word(length: int) -> String:
	var word := ""
	var n_char := len(ALPHABETS)
	for _i in range(length):
		word += ALPHABETS[randi() % n_char]
	return word


func get_path_force_cache_bust(path: String) -> String:
	return "%s?%s=%d" % [ path, generate_word(randi() % 16), generate_word(randi() % 16) ]


func get_item(key: String):
	key = "_LS" + key.sha256_text()
	if not local_storage:
		key = "user://" + key
		var file := File.new()
		if not file.file_exists(key):
			return null
		file.open(key, File.READ)
		var data = JSON.parse(file.get_as_text()).result
		file.close()
		return data
	var value = local_storage.getItem(key)
	if value is String:
		return JSON.parse(value).result
	return value


func set_item(key: String, data) -> void:
	key = "_LS" + key.sha256_text()
	if not local_storage:
		key = "user://" + key
		var file := File.new()
		file.open(key, File.WRITE)
		file.store_string(JSON.print(data))
		file.close()
		return
	local_storage.setItem(key, JSON.print(data))


func parse_path(path: String) -> String:
	if not ("://" in path):
		if location:
			if path[0] == "/":
				return location.protocol + "//" + location.hostname + path
			else:
				return location.protocol + "//" + location.hostname + location.pathname + path
		else:
			return "http://127.0.0.1:8080/" + path
	return path


func _get_downloaded_pcks() -> void:
	var cached_pcks_uncast = get_item("downloaded_pcks")
	if cached_pcks_uncast is Dictionary:
		downloaded_pcks = cached_pcks_uncast


func _set_downloaded_pcks() -> void:
	set_item("downloaded_pcks", downloaded_pcks)


func _add_to_downloaded_pcks(path: String) -> void:
	downloaded_pcks[path] = 0
	_set_downloaded_pcks()


func clear_all_pck() -> void:
	downloaded_pcks = {}
	_set_downloaded_pcks()


func clear_pck(list: Array) -> void:
	for e in list:
		var path := convert_to_pck_path(e)
		downloaded_pcks.erase(path)
		print("Removed old PCK file: %s" % e)
	_set_downloaded_pcks()


func convert_to_pck_path(string: String) -> String:
	string = string.substr(0, string.find("?"))
	return "user://" + Marshalls.variant_to_base64(string).replace("/", "-").replace("=", "_") + ".pck"


func create_http() -> HTTPObject:
	var http := HTTPObject.new(self)
	http.name = "_%d" % http_count
	http_count += 1
	add_child(http)
	return http


func get_auth_headers() -> PoolStringArray:
	return PoolStringArray(http_headers_get() + [
		"access-token: " + access_token,
	])


func get_auth_json_headers() -> PoolStringArray:
	return PoolStringArray(http_headers_get() + [
		"access-token: " + access_token,
		"Content-Type: applicaiton/json",
	])


func get_headers() -> PoolStringArray:
	return PoolStringArray(http_headers_get())


func get_json_headers() -> PoolStringArray:
	return PoolStringArray(http_headers_get() + [
		"Content-Type: application/json",
	])


func http_headers_add(headers: Array) -> ApiNode:
	http_headers += headers
	return self


func http_headers_get() -> Array:
	var headers := http_headers
	http_headers = []
	return headers


func http_headers_set(headers: Array) -> ApiNode:
	http_headers = headers
	return self


func http_auth_get(path: String = "", download_file: String = "") -> HTTPObject:
	var http := create_http()
	path = parse_path(path)
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
	path = parse_path(path)
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
	path = parse_path(path)
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
	path = parse_path(path)
	var req_params := [
		get_path_force_cache_bust(path),
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
		print("PCK %s lready gets imported, if PCK-replace is intended, the game should restart." % path)
		http.emit_signal_http_request_completed()
		return http
	if !replace:
		if http.download_file in downloaded_pcks:
			print("File %s already exists, trying to import..." % path)
			http.emit_signal_http_request_completed()
			return http
	http.callv("safe_request", req_params)
	return http


func http_post(path: String = "", dict_message: Dictionary = {}, download_file: String = "") -> HTTPObject:
	var http := create_http()
	path = parse_path(path)
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
	var token = get_item(ACCESS_TOKEN_KEYWORD)
	access_token_loaded = true
	if token is String:
		access_token = token 


func save_access_token() -> void:
	set_item(ACCESS_TOKEN_KEYWORD, access_token)


func set_access_token(value: String) -> void:
	access_token = value
	save_access_token()


func _ready() -> void:
	randomize()
	_get_downloaded_pcks()
	load_access_token()
	version_check_loop()


func version_check() -> void:
	var version := ""
	if is_instance_valid(window) && is_instance_valid(location) && is_instance_valid(local_storage):
		var version_file_url := location.href.split("?")[0] as String
		var version_file_url_splitted := version_file_url.split("/")
		if !".html" in version_file_url_splitted[version_file_url_splitted.size() - 1]:
			version_file_url += "index.html"
		var http := http_get(get_path_force_cache_bust(version_file_url))
		var status_code := yield(http, "completed_status_code") as int
		var content_type := yield(http, "completed_content_type") as String
		if status_code != 200 or content_type != "text":
			printerr("%s returns %d (%s), cannnot proceed version check" % [version_file_url, status_code, content_type])
			return
		version = yield(http, "completed")
	else:
		version = "%d" % int(Time.get_unix_time_from_system() * 1000)
	var current_version = get_item(CURRENT_VERSION_KEYWORD)
	set_item(CURRENT_VERSION_KEYWORD, version)
	version_checked = true
	if not current_version:
		# Legacy migration
		var dir := Directory.new()
		if dir.file_exists("user://current_version"):
			print("Old version control detected, migrating...")
			dir.remove("user://current_version")
		else:
			print("First time launch, will not trigger anything.")
			return
	if current_version == version:
		print("The game is up to date!")
		return
	version_control_behaviour()


func version_check_loop() -> void:
	while true:
		version_check()
		yield(get_tree().create_timer(60), "timeout")


func version_control_behaviour() -> void:
	if is_instance_valid(version_control_function):
		version_control_function.call_func()
		return
	clear_all_pck()
	if is_instance_valid(window) && is_instance_valid(location):
		window.alert("There is a newer version, app will reload!")
		yield(get_tree().create_timer(1), "timeout")
		location.href = location.href
