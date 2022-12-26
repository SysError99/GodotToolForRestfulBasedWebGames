extends Node
class_name ApiNode


const ACCESS_TOKEN_PATH = "user://access_token"
const CURRENT_VERSION_PATH = "user://current_version"


var custom_host_url := ""
var http_tscn := preload("res://addons/api/http.tscn")
var imported_pcks := []
var window := JavaScript.get_interface("window")


var access_token_loaded := false


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
	var http := http_tscn.instance() as HTTPObject
	http.api = self
	add_child(http)
	return http


func get_access_token() -> String:
	return get_meta("access-token", "")


func get_auth_headers() -> PoolStringArray:
	return PoolStringArray([
		"access-token: " + get_access_token(),
	])


func get_auth_json_headers() -> PoolStringArray:
	return PoolStringArray([
		"access-token: " + get_access_token(),
		"Content-Type: applicaiton/json",
	])


func get_headers() -> PoolStringArray:
	return PoolStringArray([
	])


func get_json_headers() -> PoolStringArray:
	return PoolStringArray([
		"Content-Type: application/json",
	])


func get_url() -> String:
	if custom_host_url != "":
		var url := custom_host_url
		custom_host_url = ""
		return url
	if is_instance_valid(window):
		if is_instance_valid(window.location):
			return window.location.protocol + '//' + window.location.host + "/"
	return "http://localhost:8788/"


func host(url: String) -> ApiNode:
	custom_host_url = url
	return self


func http_auth_get(path: String = "", download_file: String = "") -> HTTPObject:
	var http := create_http()
	http.download_file = download_file
	var req_err := http.request(
		get_url() + path,
		get_auth_headers(),
		true,
		HTTPClient.METHOD_GET,
		""
		)
	
	if req_err != OK:
		printerr("Error while trying to POST, code %d." % req_err)
		http.emit_signal_http_request_completed_error(req_err)
	return http


func http_auth_post(path: String = "", dict_message: Dictionary = {}, download_file: String = "") -> HTTPObject:
	var http := create_http()
	http.download_file = download_file
	var req_err := http.request(
		get_url() + path,
		get_auth_json_headers(),
		true,
		HTTPClient.METHOD_POST,
		JSON.print(dict_message)
		)
	if req_err != OK:
		printerr("Error while trying to POST, code %d." % req_err)
		http.emit_signal_http_request_completed_error(req_err)
	return http


func http_get(path: String = "", download_file: String = "") -> HTTPObject:
	var http := create_http()
	http.download_file = download_file
	var req_err := http.request(
		get_url() + path,
		get_headers(),
		true,
		HTTPClient.METHOD_GET,
		""
		)
	if req_err != OK:
		printerr("Error while trying to POST, code %d." % req_err)
		http.emit_signal_http_request_completed_error(req_err)
	return http


func http_get_pck(path: String, replace = false) -> HTTPObject:
	var http := create_http()
	http.download_file = convert_to_pck_path(path)
	http.set_meta("import_pck_path", path)
	http.set_meta("import_pck", true)
	if http.download_file in imported_pcks:
		printerr("PCK already gets imported, if PCK replace is intended, the game should restart.")
		http.emit_signal_http_request_completed()
		return http
	if !replace:
		var dir := Directory.new()
		if dir.file_exists(http.download_file):
			printerr("File %s already exists, skipping PCK download." % path)
			http.emit_signal_http_request_completed()
			return http
	var req_err := http.request(
		get_url() + path + "?r=%d" % randi(),
		get_headers(),
		true,
		HTTPClient.METHOD_GET,
		""
		)
	if req_err != OK:
		printerr("Error while trying to GET PCK, code %d." % req_err)
		http.emit_signal_http_request_completed_error(req_err)
	return http


func http_post(path: String = "", dict_message: Dictionary = {}, download_file: String = "") -> HTTPObject:
	var http := create_http()
	http.download_file = download_file
	var req_err := http.request(
		get_url() + path,
		get_json_headers(),
		true,
		HTTPClient.METHOD_POST,
		JSON.print(dict_message)
		)
	if req_err != OK:
		printerr("Error while trying to POST, code %d." % req_err)
		http.emit_signal_http_request_completed_error(req_err)
	return http


func load_access_token() -> void:
	var dir := Directory.new()
	if dir.file_exists(ACCESS_TOKEN_PATH):
		var file := File.new()
		if file.open(ACCESS_TOKEN_PATH, File.READ) != OK:
			printerr("Cannot open access token!")
			return
		set_access_token(file.get_as_text())
		file.close()
		print("Access token loaded.")
	access_token_loaded = true


func save_access_token() -> void:
	var file = File.new()
	if file.open(ACCESS_TOKEN_PATH, File.WRITE) != OK:
		printerr("Canot open access token file to write!")
		return
	file.store_string(get_access_token())
	file.close()
	print("Access token saved.")


func set_access_token(value: String) -> void:
	set_meta("access-token", value)
	save_access_token()


func _ready() -> void:
	randomize()
	load_access_token()
	version_check_loop()
	set_meta("imported_pcks", imported_pcks)


func version_check() -> void:
	var file := File.new()
	var dir := Directory.new()
	if !is_instance_valid(window):
		printerr("Cannot get valid 'window' interface, cannot proceed version check.")
		return
	var version_file_url := window.location.href as String
	var version_file_url_splitted := version_file_url.split("/")
	if !".html" in version_file_url_splitted[version_file_url_splitted.size() - 1]:
		version_file_url += "index.html"
	version_file_url += ".ver.txt?r=%d" % randi()
	var http := host(version_file_url).http_get()
	var status_code := yield(http, "completed_status_code") as int
	var content_type := yield(http, "completed_content_type") as String
	var body = yield(http, "completed")
	if status_code != 200 || content_type != "text":
		printerr("%s returns %d (%s), cannnot proceed version check" % [window.location.href, status_code, content_type])
		return
	var version := body as String
	if !dir.file_exists(CURRENT_VERSION_PATH):
		version_control_behaviour()
		print("This game runs on this machine for first time, creating hash file...")
		file.open(CURRENT_VERSION_PATH, File.WRITE)
		file.store_string(version)
		file.close()
		return
	file.open(CURRENT_VERSION_PATH, File.READ_WRITE)
	var current_version := file.get_as_text()
	if current_version == version:
		print("Version is up to date!")
		return
	file.store_string(version)
	file.close()
	version_control_behaviour()
	var os_executable_path := OS.get_executable_path().split('.')
	if os_executable_path.size() == 2:
		var version_from_os := os_executable_path[1]
		if version_from_os == version:
			print("Version reported from OS matches with version from server, no need to refresh.")
			return
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
