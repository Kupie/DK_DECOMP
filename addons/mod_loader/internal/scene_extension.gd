class_name _ModLoaderSceneExtension
extends RefCounted




const LOG_NAME: = "ModLoader:SceneExtension"




static func refresh_scenes() -> void :
	for scene_path in ModLoaderStore.scenes_to_refresh:

		var _scene_from_file: PackedScene = ResourceLoader.load(
			scene_path, "", ResourceLoader.CACHE_MODE_REPLACE
		)
		ModLoaderLog.debug("Refreshed scene at path: %s" % scene_path, LOG_NAME)



static func handle_scene_extensions() -> void :
	for scene_path in ModLoaderStore.scenes_to_modify.keys():
		for scene_edit_callable in ModLoaderStore.scenes_to_modify[scene_path]:
			var cached_scene: PackedScene = load(scene_path)
			var cached_scene_instance: Node = cached_scene.instantiate()
			var edited_scene: Node = scene_edit_callable.call(cached_scene_instance)
			if not edited_scene:
				ModLoaderLog.fatal(
					(
						"Scene extension of \"%s\" failed since the edit callable \"%s\" does not return the modified scene_instance"
						%[scene_path, scene_edit_callable.get_method()]
					), 
					LOG_NAME
				)
				return
			_save_scene(edited_scene, scene_path)










static func _save_scene(modified_scene: Node, scene_path: String) -> void :
	var packed_scene: = PackedScene.new()
	var _pack_error: = packed_scene.pack(modified_scene)
	ModLoaderLog.debug("packing scene -> %s" % packed_scene, LOG_NAME)
	packed_scene.take_over_path(scene_path)
	ModLoaderLog.debug(
		"save_scene - taking over path - new path -> %s" % packed_scene.resource_path, LOG_NAME
	)
	ModLoaderStore.saved_objects.append(packed_scene)
