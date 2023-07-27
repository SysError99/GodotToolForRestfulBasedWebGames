# Godot Tool For RESTful-Based Web Games
GDScript and Node.JS-based automation tool I made to ease building process of RESTful API HTML5 games made with Godot.

# NOTICE
There are breaking changes in current version. If you are looking for previous version, visit [this branch](/SysError99/GodotToolForRestfulBasedWebGames/tree/v0).

---
## Why making this?
Godot is never meant to be run on HTML5 platform but Godot team managed to port them into it with surprisingly good results. However, the engine still has combinations of super large files (mainly the engine itself and a PCK file), and loading single large PCK file at startup is painfully slow, even with decent internet connection. 

There are several ways to mitigate it, one of them is to separate PCK into pieces and download them on-demand. This method comes with a cost, that you need to keep exporting all PCK files related every time you want to update your game. Even worse that you need to also make change of PCK URL parameters to trigger cache reset in browser and download newer version of PCK files. This tool will ease exporting process by help automating build process of PCK files, providing application interface for RESTful API, and PCK downloading and updating functions.

*In case you wonder if this project is really used in real world scenarios, I'm already using this tool in my own production work :)*

---
## Features
1. Simple one-line command to automate building process of specified PCK presets from `export_presets.cfg`, along with generating build revision indicator file, making HTML5 game updating easier.
2. GDScript file that contains API calling functions, PCK download/update functions, and automatic access token saver.

---
## Limitations
1. Only tested on Linux.
2. Dosen't have advanced build number specifier.
3. Node.JS 16 minimum is required to run this tool.
4. On WebKit-based platforms (iOS, iPadOS, macOS, tvOS, and many others), you only have 500 MB maximum of space for persistent storage stuffs. Means that you'll also need other techniques to exceed this barrier, such as downloading files and import them directly without writing them to persistent storage (works well with Godot's PNG, JPG, and MP3 importers, perfect for large files such as large sprites, background music, voice files, etc.).

---
## Quickstart

### Building Games
1. Simply copy all files from this repository (excluding Git-related stuffs, and `README.md`) to your Godot project folder. Then, in command line shell of project folder, run:

```
node build.mjs
```

on your project folder to initialise `build.config.json` file.

Its structure will look something like this:

```json
{
	"bin": "/path/to/godot/headless/bin",
	"mainPreset": "Production",
	"mainPresetPath": "./build/index.html",
	"pckPresets": {
		"NameOfPck": "./build/pck/name_of.pck",
	},
}
```

*You can remove `NameOfPck` part as we will create proper ones later.*

2. In the generated `build.config.json` file, make change of `bin` path with path of your Godot Editor (or headless) executable.

3. Create `build` folder in your project folder, and put empty `.gdignore` file in it. This will be your default build folder for your project (you can specify your own build folder).

4. In Godot export options, create an export preset with `HTML5` platform, and name it `Production`.

4. On the command line, run `node build.mjs` to build your project and store it in the `build` folder.

### Creating PCK Exporting Preset And Importing It At Runtime
This will help reducing your main PCK size, by separating it into pieces and downloading it on-demand.

First and foremost, I recommend to also separate folder for all exporting presets, which helps selecting files for each presets , and excluding files in main preset to be much easier. For example, create a folder named `pck` to store all folders for each exporting presets.

```
- your_project
	- addons
	- fnt
	- img
	- obj
	- res
	- pck
		- pck_2022_12_12_patch
		- pck_2022_12_20_patch
		- pck_2022_12_30_patch
		...
	- pck.core
		- core_gameplay
		- core_assets
	- scn
	- snd
	- icon.png
```

In your main exporting preset, assuming that it's named `Production`, you also need to exclude files that already got selected in exporting preset from step 1. If you already separated folder following the method suggested above, you may just add wildcard (in this case `pck/*`, and `pck.core/*`) into `Filter to exclude file/folders from project` to prevent your main preset to export PCK files intended to be downloaded separately.

1. In Godot export options, create new preset with `HTML5` platform, and name it anything you want (e.g., `pck_2022_12_12_patch`). In `Resources` Tab, select `Export selected resources (and all dependencies)` which will let you select all related files that will be included in the preset.

Note: Sometimes, if the PCK also depends on resources on folders outside itself or `/pck/`, you also need to add list of folders outside its PCK directory into `Filters to exclude files/folders from project` to explicitly exclude files and folders that already have been loaded in other PCK files or the game itself. The easiest way is to just add all folder names inside root folder of the project (in this case, `addons/*,fnt/*,img/*,obj/*,res/*,scn/*,snd/*`).

2. In `build.config.json`, at `pckPresets`, add new preset with name as `key`, along with export path.
For example, if you want to add `pck_2022_12_12_patch` and export it to build folder, it will be something like this:

```json
"pckPresets": {
	"pck_2022_12_12_patch": "./build/pck/pck_2022_12_12_patch.pck"
}
```

3. To download PCK files and import it, you need to first adding `api.gd` provided by this repository into AutoLoad (Singleton) of your Godot project. In this case, we will import it as `Api`. After this one-time procedure, you can now use PCK download function.

Then, simply call GDScript function and wait until it's completed. Assuming that you also uploaded PCK at a same hosting server that you store your main game files, and it's stored at `pck` folder and name of the file is `pck_2022_12_12_patch.pck` , its path will be `https://your.web.site/pck/pck_2022_12_12_patch.pck`. Then, you can call function to download PCK file and download it automatically:

```gdscript
	var http := Api.http_get_pck("pck/pck_2022_12_12_patch.pck")
	yield(http, "completed")
	# Anything else can be added after this line.
	# For example, to open up new scene from downloaded PCK.
	get_tree().change_scene("res://pck_2022_12_12_patch/new_scene.tscn")
```

Still, if you aren't sure that if the PCK gets downloaded and imported properly, the function also provides status code from HTTP request object:

```gdscript
	var http := Api.http_get_pck("pck/pck_2022_12_12_patch.pck")
	var status_code := yield(http, "completed_status_code")
	if status_code != 200:
		printerr("Cannot download new PCK file properly!")
		return
	get_tree().change_scene("res://pck_2022_12_12_patch/new_scene.tscn")
```

If you upload PCK files at different hosting server, you need to change hostname to that location by using `Api.host()` function, chained with `http.get_pck()` as usual:

```gdscript
	var http := Api.host("http://cdn.of.new.site/").http_get_pck("pck/pck_2022_12_12_patch")
	yield(http, "completed")
	get_tree().change_scene("res://pck_2022_12_12_patch/new_scene.tscn")
```

4. To build the project along with PCK files, run `node build.mjs` to build your project, then publish build folder in your desired methods.

---
### Functions
In GDScript file provided in this repository has many of functions that making API calling stuffs in GDScript much easier. Assuming you imported `api.gd` as `Api` in AutoLoad (Singleton).

#### `Api.version_checked: bool`
Check if game versions is checked by this addon. Very useful if you wanted to make sure if game version is checked before attempitng to download PCK files.

```gdscript
while not Api.version_checked:
	yield(get_tree(), "idle_frame")
```

#### `Api.clear_all_pck(): void`
Clear all PCKs downloaded (perform automatically by default when the game get updated). You can make change of the script in `_ready()` function and remove `Api.clear_all_pck()` function from it.

#### `Api.clear_pck(url: Array<String>): void`
Specify an array of URL list of PCKs to be removed from the device.

#### `Api.http_auth_get(url: String = "", download_file: String = ""): HTTPObject`
Make an HTTP GET request with `access-token` attached. If you specify `download_file` with non-empty parameter, it will also download any of results into path specified with it. You can `yield()` each parameters in this format (cannot change order):
```gdscript
	var http := Api.http_auth_get(url)
	var status_code := yield(http, "completed_status_code")
	var content_type := yield(http, "completed_content_type")
	var body := yield(http, "completed")
```

#### `Api.http_auth_post(url: String = "", data: Dictionary = {}, download_file: String = ""): HTTPObject`
Make an HTTP POST request with `access-token` attached. If you specify `download_file` with non-empty parameter, it will also download any of results into path specified with it.

#### `Api.http_get(url: String = "", download_file: String = ""): HTTPObject`
Make an HTTP GET request. If you specify `download_file` with non-empty parameter, it will also download any of results into path specified with it.

#### `Api.http_get_pck(url: String, replace: bool = false): HTTPObject`
Download PCK file from specified URL and import it automatically if it gets download successfully. `replace` parameter specifies if you want to replace original file no matter what.

#### `Api.http_post(url: String = "", data: Dictionary = {}, download_file: String = ""): HTTPObject`
Make an HTTP POST request. If you specify `download_file` with non-empty parameter, it will also download any of results into path specified with it.


---
### Internal Functions
These functions aren't supposed to be used regularly, but you still can use them if you want.


#### `Api.convert_to_pck_path(url: String): void`
Convert URL into `user://` PCK path.

#### `Api.create_http(): HTTPObject`
Manually create an `HTTPObject` that is used internally by many of functions in the script.

#### `Api.get_access_token(): String`
Read access token savend in the device, returns an empty string if not found.

#### `Api.get_auth_headers(): PoolStringArray`
Create an HTTP headers that contain `access-token` from saved token.

#### `Api.get_auth_json_headers(): PoolStringArray`
Create an HTTP headers that contain both `access-token` and `content-type: application/json`.

#### `Api.get_headers(): PoolStringArray`
Create an empty HTTP headers.

#### `Api.get_json_headers(): PoolStringArray`
Create an HTTP header that has `content-type: json`.

#### `Api.get_url(): String`
Get hostname URL from browser. If it's not running on HTML5 platform, it will fallback to `http://localhost:8080`.

#### `Api.load_access_token()`
Load access token from storage and store it in this function. Can be accessed with `Api.access_token`. If you want to know if the function loads the access token but also wanted to know if it actually exists or not, you can check with `Api.access_token_loaded` in loop:
```gdscript
	while !Api.access_token_loaded:
		yield(get_tree(), "idle_frame")
```

#### `Api.set_access_token(value: String): void`
Set access token, and save it automatically.
