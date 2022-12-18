extends Node
class_name ApiNode


const ACCESS_TOKEN_PATH = "user://access_token"
const BUILD_NUMBER_FILENAME = "build.number.txt"
const BUILD_NUMBER_PATH = "res://build.number.txt"
const CURRENT_BUILD_NUMBER_PATH = 'user://current_build'
const USE_VERSION_CONTROL = true


var build_number_search_params := ""
var custom_host_url := ""


var http_tscn := preload("res://addons/api/http.tscn")
var window := JavaScript.get_interface("window")


var access_token_loaded := false


func clear_all_pck() -> void:
	var dir := Directory.new()
	if dir.open("user://") != OK:
		printerr("Cannot open user folder when trying to clearn up all PCKs!")
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


func http_auth_get(path: String, download_file: String = "") -> HTTPObject:
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


func http_auth_post(path: String, dict_message: Dictionary, download_file: String = "") -> HTTPObject:
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


func http_get(path: String, download_file: String = "") -> HTTPObject:
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
	if !replace:
		var dir := Directory.new()
		if dir.file_exists(http.download_file):
			printerr("File %s already exists, skipping PCK download." % path)
			http.emit_signal_http_request_completed()
			return http
	var req_err := http.request(
		get_url() + path + build_number_search_params,
		get_headers(),
		true,
		HTTPClient.METHOD_GET,
		""
		)
	if req_err != OK:
		printerr("Error while trying to GET PCK, code %d." % req_err)
		http.emit_signal_http_request_completed_error(req_err)
	return http


func http_post(path: String, dict_message: Dictionary, download_file: String = "") -> HTTPObject:
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
	if USE_VERSION_CONTROL:
		var file := File.new()
		var dir := Directory.new()
		if !dir.file_exists(BUILD_NUMBER_PATH):
			printerr("Cannot find build number file, cannot automate version control.")
			return
		file.open(BUILD_NUMBER_PATH, File.READ)
		var build_number := file.get_as_text()
		build_number_search_params = "?v=" + build_number
		print("Current build number is " + build_number)
		file.close()
		if !dir.file_exists(CURRENT_BUILD_NUMBER_PATH):
			file.open(CURRENT_BUILD_NUMBER_PATH, File.WRITE)
			file.store_string(build_number)
			file.close()
			return
		file.open(CURRENT_BUILD_NUMBER_PATH, File.READ_WRITE)
		var current_build := file.get_as_text()
		file.close()
		if current_build != build_number:
			file.store_string(build_number)
			# Version control behaviour
			Api.clear_all_pck()
			# End Version control behaviour
		if !OS.get_name() == "HTML5":
			return
		var http := http_get(BUILD_NUMBER_FILENAME)
		var status := yield(http, "completed_status_code") as int
		var content_type := yield(http, "completed_content_type") as String
		var body = yield(http, "completed")
		if status < 200 || status > 299 || content_type != "text":
			printerr('%s returns %d (%s)' % [BUILD_NUMBER_FILENAME, status, content_type])
			return
		var version := body as String
		if version == build_number:
			print("Version is up to date!")
			return
		print("Version isn't up to date, trying to refresh.")
		if !OS.has_feature('JavaScript'):
			return
		var window := JavaScript.get_interface("window")
		if !is_instance_valid(window):
			return
		window.reload()
