
extends Node

var cfg = ConfigFile.new()
const cfg_path = "user://config.cfg"

func _init():
	cfg.load(cfg_path)

func get_filepath():
	return cfg.get_value("ClassLoader","filepath")
func set_filepath(path):
	cfg.set_value("ClassLoader","filepath",path)
	cfg.save(cfg_path)


