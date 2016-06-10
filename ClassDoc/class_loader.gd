
extends Node

onready var fdialog = get_node("FileDialog")
var class_list = {}


func _ready():
	fdialog.set_mode( FileDialog.MODE_OPEN_FILE )
	fdialog.set_access( FileDialog.ACCESS_FILESYSTEM )
	fdialog.add_filter("*.xml")
	fdialog.connect("file_selected",self,"_file_selected")
	var fpath = Config.get_filepath()
	if fpath != null:
		fdialog.set_current_dir(fpath)
	
	get_node("File/Select").connect("pressed",fdialog,"popup")
	get_node("File/Load").connect("pressed",self,"_load_classes")
	
	get_node("ClassList/Selected").connect("text_changed",self,"_classname_changed")
	get_node("ClassList/Load").connect("pressed",self,"_load_class")
	popup("It's pretty early version, so you might \nwant to backup your file before using \nthis program","Attention")

func _file_selected( path ):
	get_node("File/Path").set_text(path)
	get_node("File/Load").set_disabled(false)

func _load_classes():
	var fpath = get_node("File/Path").get_text()
	Config.set_filepath(fpath.get_base_dir())
	var f = File.new()
	var err = f.open( fpath, File.READ ) # trying to keep it open as long as possible, so it can't get erased while creating doc
	if err != OK:
		print("_load_classes(): Failed to open file (",fpath,"). Error: ",err)
		return
	var xml = XMLParser.new()
	err = xml.open(fpath)
	if err != OK:
		print("_load_classes(): XMLParser is unable to open file (",fpath,"). Error: ",err)
		f.close()
		return
	if xml.is_empty():
		print("_load_classes(): XMLParser: file is_empty (",fpath,")")
		f.close()
		return
	print("Loading classes from \"",fpath,"\"...")
	var timestamp = OS.get_ticks_msec()
	clear_class_list()
	xml.read() # <?xml version
	xml.read() # <doc version
	var i = 0
	# Caution: this loop happens till it finds </doc>
	while( true ): # putting condition below, it's easier to read it this way
		if xml.get_node_type() == xml.NODE_ELEMENT_END and xml.get_node_name() == "doc":
			break
		if xml.get_node_type() == xml.NODE_ELEMENT and xml.get_node_name() == "class":
			if xml.has_attribute("name"):
				class_list[ xml.get_named_attribute_value("name") ] = xml.get_node_offset()
				xml.skip_section()
			# else: error handling?
		else:
			xml.read()
	print("    Loading done (",OS.get_ticks_msec()-timestamp,"ms)")
	print("Classes count: ",class_list.size())
	
	yield(get_tree(),"idle_frame") # wait 1 frame, so previous buttons have time to be deleted
	var container = get_node("ClassList/C/Control")
	for class_name in class_list:
		container.add_button(class_name)
	
	get_node("ClassList").show()
	
	f.close()

func clear_class_list():
	class_list.clear()
	get_node("ClassList/C/Control").clear()

func _classname_changed( nval ):
	if nval == "":
		get_node("ClassList/Load").set_disabled(true)
	else:
		get_node("ClassList/Load").set_disabled(false)
		if class_list.has(nval):
			get_node("ClassList/Load").set_text("Edit Class")
		else:
			get_node("ClassList/Load").set_text("Create Class")

func _load_class():
	var cname = get_node("ClassList/Selected").get_text()
	var class_creator = get_node("../ClassCreator")
	var fpath = get_node("File/Path").get_text()
	hide()
	if class_list.has(cname):
		class_creator.set_class(fpath,cname,class_list[cname])
	else:
		class_creator.set_class(fpath,cname)
	class_creator.show()


func popup( s, title="ClassLoader" ):
	var popup = get_node("../Popup")
	popup.set_text(str(s))
	popup.set_title(str(title))
	popup.popup_centered()


