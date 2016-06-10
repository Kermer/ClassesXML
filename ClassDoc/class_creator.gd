extends Panel


#var name = ""
#var inherits = ""
#var brief_desc = ""
#var desc = ""
#
#var methods = []
#
#var methods_list










var file = File.new()
var fpath = ""
var foffset = -1
var fendoffset = -1

var methods_list = {}
var constants = {}



func _ready():
	get_node("BriefDesc").connect("focus_enter",self,"_show_desc_overflow",[get_node("BriefDesc")])
#	get_node("BriefDesc").connect("focus_exit",self,"_hide_desc_overflow")
	get_node("BriefDesc").connect("text_changed",self,"_desc_updated",[get_node("BriefDesc")])
	get_node("Desc").connect("focus_enter",self,"_show_desc_overflow",[get_node("Desc")])
#	get_node("Desc").connect("focus_exit",self,"_hide_desc_overflow")
	get_node("Desc").connect("text_changed",self,"_desc_updated",[get_node("Desc")])
	
	get_node("MethodsList/BAdd").connect("pressed",self,"_edit_method")
	get_node("MethodsList/BDel").connect("pressed",self,"_delete_method")
	get_node("MethodsList/Selected").connect("text_changed",self,"_method_changed")
	
	get_node("BSave").connect("pressed",self,"_save_class")
	get_node("BBack").connect("pressed",self,"_go_back")
	pass

func set_class(fpath,cname,file_offset=-1):
	clear()
	print("Opening class \"",cname,"\"")
	print("File offset for this class: ",file_offset)
	get_node("ClassNode/Name").set_text(cname)
	self.fpath = fpath
	if file.is_open():
		file.close()
	var err = file.open(fpath, File.READ) # keep the file open to prevent deleting it
	if err != OK:
		print("set_class(): unable to open file (",fpath,"). Error: ",err)
		return
	if file_offset <= 0:
		file_offset = -1
	foffset = file_offset
	if file_offset > 0:
		load_class_data(fpath,foffset)
	pass

func load_class_data(fpath, foffset):
	var xml = XMLParser.new()
	var err = xml.open(fpath)
	if err != OK:
		print("load_class_data(): XMLParser is unable to open file (",fpath,"). Error: ",err)
		return
	xml.seek(foffset) # <class
	var cname = get_node("ClassNode/Name").get_text()
	if xml.get_node_type() != xml.NODE_ELEMENT or xml.get_node_name() != "class" or xml.get_named_attribute_value("name") != cname:
		print("load_class_data(): WARNING! XMLParser expected [NODE_ELEMENT class name=\"",cname,"\"]")
		print("     got [",xml.get_node_type()," ",xml.get_node_name()," name=\"",xml.get_named_attribute_value("name"),"\"]")
	# if above "WARNING" is true, code below might not work properly
	print("Loading class data from xml...")
	var timestamp = OS.get_ticks_msec()
	if xml.has_attribute("inherits"):
		get_node("ClassNode/Inherits").set_text( xml.get_named_attribute_value("inherits") )
	if xml.has_attribute("category"):
		get_node("ClassNode/Category").set_text( xml.get_named_attribute_value("category") )
	
	# ======================================
	# GENERATING CLASS INFO AND METHODS LIST
	# ======================================
	var current_node = "class"
	var current_method = null
	# clear() is called on set_class()
	while( true ): # putting condition below, it's easier to read it this way
		if xml.get_node_type() == xml.NODE_ELEMENT_END and xml.get_node_name() == "class":
			break
		xml.read()
		# <...>
		if xml.get_node_type() == xml.NODE_ELEMENT:
			if current_node == "class":
				if xml.get_node_name() == "brief_description" or xml.get_node_name() == "description":
					var brief = (xml.get_node_name()=="brief_description")
					xml.read()
					if xml.get_node_type() == xml.NODE_TEXT:
						set_desc( xml.get_node_data().strip_edges(), brief )
					xml.read() # </description>
				elif xml.get_node_name() == "methods":
					current_node = "methods"
					continue
				elif xml.get_node_name() == "constants":
					current_node = "constants"
					continue
			elif current_node == "methods":
				if xml.get_node_name() == "method":
					current_node = "method"
					var method = new_method()
					method.name = xml.get_named_attribute_value("name")
					method.offset = xml.get_node_offset()
					if xml.has_attribute("qualifiers"):
						method.qualifiers = xml.get_named_attribute_value("qualifiers")
					current_method = method
			elif current_node == "method":
				if xml.get_node_name() == "return":
					current_method.return_type = xml.get_named_attribute_value("type")
					xml.read() # </return>
				elif xml.get_node_name() == "argument":
					# currently no invalid index checks
					var idx = xml.get_named_attribute_value("index")
					var arg = {"name":"arg"+str(idx),"type":"null","default":"null"}
					arg.name = xml.get_named_attribute_value("name")
					arg.type = xml.get_named_attribute_value("type")
					if xml.has_attribute("default"):
						arg.default = xml.get_named_attribute_value("default")
					current_method.args.append(arg)
					xml.read() # </argument>
				elif xml.get_node_name() == "description":
					xml.read()
					if xml.get_node_type() == xml.NODE_TEXT:
						current_method.desc = xml.get_node_data().strip_edges()
					xml.read() # </description>
			elif current_node == "constants":
				if xml.get_node_name() == "constant":
					var constant = {"name":"","value":"","desc":""}
					constant.name = xml.get_named_attribute_value("name")
					constant.value = xml.get_named_attribute_value("value")
					xml.read()
					if xml.get_node_type() == xml.NODE_TEXT:
						constant.desc = xml.get_node_data().strip_edges()
					elif xml.get_node_type() == xml.NODE_ELEMENT_END: # </constant>
						current_node = "class"
					constants[constant.name] = constant # Dictionary = in case i'll want to add later option to edit constant's descriptions
		
		# </...>
		elif xml.get_node_type() == xml.NODE_ELEMENT_END:
			if current_node == xml.get_node_name():
				if current_node == "method":
					current_node = "methods"
					methods_list[ current_method.name ] = current_method # save info about our method
					current_method = null
				elif current_node == "methods" or current_node == "constants":
					# back to class
					current_node = "class"
				elif current_node == "class":
					break # if we would continue, it would "break" at the beginning of the next loop
	# End of while loop
	print("    Loading done (",OS.get_ticks_msec()-timestamp,"ms)")
	# Showing our methods list
	yield(get_tree(),"idle_frame") # wait 1 frame, so previous buttons have time to be deleted
	for mname in methods_list:
		get_node("MethodsList/C/Control").add_button(mname)
	

func _method_changed(mname):
	if mname.strip_edges() == "":
		get_node("MethodsList/BAdd").set_disabled(true)
		get_node("MethodsList/BDel").set_disabled(true)
	elif methods_list.has(mname):
		get_node("MethodsList/BAdd").set_disabled(false)
		get_node("MethodsList/BAdd").set_text("Edit Method")
		get_node("MethodsList/BDel").set_disabled(false)
	else:
		get_node("MethodsList/BAdd").set_disabled(false)
		get_node("MethodsList/BAdd").set_text("Create Method")
		get_node("MethodsList/BDel").set_disabled(true)
	# MethodCreator.load_method
	pass

func _edit_method():
	var mname = get_node("MethodsList/Selected").get_text()
	var method
	if methods_list.has(mname):
		method = methods_list[mname]
	else:
		method = new_method()
		method.name = mname
		methods_list[ mname ] = method
		get_node("MethodsList/C/Control").add_button(mname)
		get_node("MethodsList/C/Control").scroll_down()
	var mcreator = get_node("MethodCreator")
	if mcreator.is_hidden():
		mcreator.show()
	mcreator.set_method(method)
	_method_changed(mname)

func _delete_method():
	var mname = get_node("MethodsList/Selected").get_text()
	if !methods_list.has(mname):
		return
	# delete it from our MethodsList
	get_node("MethodsList/C/Control").delete_button(mname)
	methods_list.erase(mname)
	_method_changed(mname)


func new_method():
	var method = {
		"name":"",
		"offset":-1,
		"args":[],
		"desc":"",
		"return_type":"void",
		"qualifiers":""
		}
	return method

func clear():
	clear_methods_list()
	clear_constants()
	for c in get_node("ClassNode").get_children():
		if c extends LineEdit:
			c.set_text("")
	get_node("BriefDesc").set_text("")
	get_node("Desc").set_text("")

func clear_methods_list():
	methods_list.clear()
	get_node("MethodsList/C/Control").clear()
func clear_constants():
	constants.clear()

func set_desc( text, brief=false ):
	var line_edit
	text = str(text)
	if brief:
		line_edit = get_node("BriefDesc")
	else:
		line_edit = get_node("Desc")
	# temp
#	text = text.replace("\n","")
#	text = text.replace("\r","")
	# /temp
	line_edit.set_text( text )


func tab(amount):
	var tabs = ""
	for i in range(amount):
		tabs += "\t"
	return tabs
func _save_class():
	print("Saving class...")
	var timestamp = OS.get_ticks_msec()
	if foffset == -1:
		print("Adding new classes not supported yet :(")
		popup("Adding new classes not supported yet :(","Failed to save")
		return
	if !file.is_open():
		# huh, it should be open already 0.o
		print("classes.xml isn't open?!")
		popup("Failed to save \nclasses.xml isn't open?!","Failed to save")
		return
	print("    Saving class to \"user://class.xml\"...")
	if save_class_as_xml() != OK:
		popup("Failed to save")
		return
	print("        ",OS.get_ticks_msec()-timestamp,"ms");timestamp = OS.get_ticks_msec()
	print("    Getting buffers of \"class.xml\" and \"classes.xml\"...")
	var fclass = File.new()
	fclass.open("user://class.xml",File.READ) # we just wrote to it, so it should be accessible, right?
	var class_buffer = fclass.get_buffer( fclass.get_len() )
	file.seek(0) # it should be at 0, but just in=case
	var file_buffer = file.get_buffer( file.get_len() )
	print("        ",OS.get_ticks_msec()-timestamp,"ms");timestamp = OS.get_ticks_msec()
	print("    Merging buffers...")
	var class_start = foffset+1
	var class_end = get_class_end_offset() + "</class>".length() + 1
	print("class_start=",class_start)
	print("class_end=",class_end)
	var merged_buffer = RawArray()
	for i in range(class_start):
		merged_buffer.push_back(file_buffer[i])
	#<class>
	for i in range(class_buffer.size()):
		merged_buffer.push_back(class_buffer[i])
	#</class>
	for i in range(class_end,file_buffer.size()):
		merged_buffer.push_back(file_buffer[i])
	file.close()
	file.open(fpath,File.WRITE) # gotta add error checking, "just in=case" :P
	file.store_buffer( merged_buffer )
	file.close()
	file.open(fpath,File.READ) # keep the file open = prevent deleting
	
	print("        ",OS.get_ticks_msec()-timestamp,"ms")
	print("    Saving done")
	print("------------------------------")
	popup("Class saved!","Done")
	pass

func save_class_as_xml():
	var f = File.new()
	var err = f.open("user://class.xml",File.WRITE)
	if err != OK:
		print("save_class_as_xml(): failed to open \"user://class.xml\". Error: ",err)
		return FAILED
	# get data from Controls
	var name = get_node("ClassNode/Name").get_text()
	var inherits = get_node("ClassNode/Inherits").get_text().strip_edges()
	var category = get_node("ClassNode/Category").get_text().strip_edges()
	var brief_desc = get_node("BriefDesc").get_text().strip_edges()
	var desc = get_node("Desc").get_text().strip_edges()
	
	var line = ""
	#	<class name inherits category>
	line += "<class name=\""+name+"\""
	if inherits != "":
		line += " inherits=\""+inherits+"\""
	if category == "":
		category = "Core"
	line += " category=\""+category+"\">"
	f.store_line(line)
	#		<brief_description>
	line = tab(1)+"<brief_description>"
	f.store_line(line)
	if brief_desc != "":
		line = tab(1)+brief_desc
		f.store_line(line)
	line = tab(1)+"</brief_description>"
	f.store_line(line)
	#		</brief_description>
	#		<description>
	line = tab(1)+"<description>"
	f.store_line(line)
	if desc != "":
		line = tab(1)+desc
		f.store_line(line)
	line = tab(1)+"</description>"
	f.store_line(line)
	#		</description>
	#		<methods>
	line = tab(1)+"<methods>"
	f.store_line(line)
	for mname in methods_list:
		var method = methods_list[mname]
	#			<method name qualifiers>
		line = tab(2)+"<method name=\""+method.name+"\""
		if method.qualifiers != "":
			line += " qualifiers=\""+method.qualifiers+"\""
		line += ">"
		f.store_line(line)
	#				<return type>
		if method.return_type == "":
			method.return_type = "void"
		if method.return_type != "void":
			line = tab(3)+"<return type=\""+method.return_type+"\">"
			f.store_line(line)
			f.store_line(tab(3)+"</return>")
		for i in range(method.args.size()):
			var arg = method.args[i]
	#				<argument index name type default>
			line = tab(3)+"<argument index=\""+str(i)+"\" name=\""+arg.name+"\" type=\""+arg.type+"\""
			if arg.has("default"):
				line += " default=\""+arg.default+"\""
			line += ">"
			f.store_line(line)
			f.store_line(tab(3)+"</argument>")
	#				<description>
		f.store_line(tab(3)+"<description>")
		if method.desc != "":
			f.store_line(tab(3)+method.desc)
		f.store_line(tab(3)+"</description>")
	#				</description>
		f.store_line(tab(2)+"</method>")
	#			</method>
	f.store_line(tab(1)+"</methods>")
	#		</methods>
	#		<constants>
	f.store_line(tab(1)+"<constants>")
	for cname in constants:
		var constant = constants[cname]
	#			<constant name value>
		line = tab(2)+"<constant name=\""+constant.name+"\" value=\""+constant.value+"\">"
		f.store_line(line)
		if constant.desc != "":
			f.store_line(tab(2)+constant.desc)
		f.store_line(tab(2)+"</constant>")
	#			</constant>
	f.store_line(tab(1)+"</constants>")
	#		</constants>
	f.store_line("</class>")
	#	</class>
	
	f.close() # save file
	return OK

func _go_back():
	print("==============================")
	if file.is_open():
		file.close()
	hide()
	get_node("../ClassLoader").show()

func _show_desc_overflow(node):
	get_node("DescOverflow").set_global_pos( node.get_global_pos() + Vector2(0,node.get_size().y) )
	var rt = get_node("DescOverflow/Text")
	rt.clear()
	rt.add_text(node.get_text())
	get_node("DescOverflow").resize(node.get_size().x)
	get_node("DescOverflow").show()
func _hide_desc_overflow():
	get_node("DescOverflow").hide()
func _desc_updated(text,node):
	var nline_pos = text.find("\\n")
	if nline_pos != -1:
		text = text.replace("\\n","\n")
		node.set_text(text)
		node.set_cursor_pos(nline_pos+1)
	_update_desc_overflow(text)
	pass
func _update_desc_overflow(text):
	if get_node("DescOverflow").is_visible():
		get_node("DescOverflow/Text").clear()
		get_node("DescOverflow/Text").add_text(text)

func _exit_tree():
	if file.is_open():
		file.close()


func popup( s, title="ClassCreator" ):
	var popup = get_node("../Popup")
	popup.set_text(str(s))
	popup.set_title(str(title))
	popup.popup_centered()

func get_doc_end_offset():
	var xml = XMLParser.new()
	var err = xml.open(fpath)
	if err != OK or xml.is_empty():
		return -1
	var timestamp = OS.get_ticks_msec()
	while( true ):
		if OS.get_ticks_msec()-timestamp > 500: # looking for the <doc> longer than 0.5 second
			return -1
		if xml.get_node_type() == xml.NODE_ELEMENT:
			if xml.get_node_name() == "doc":
				xml.skip_section()
				return xml.get_node_offset()
		xml.read()

func get_class_end_offset():
	if foffset == -1: # probably new class or some error/bug
		return -1
	var xml = XMLParser.new()
	var err = xml.open(fpath)
	if err != OK or xml.is_empty():
		return -1
	xml.seek( foffset )
	var timestamp = OS.get_ticks_msec()
	while( true ):
		if OS.get_ticks_msec()-timestamp > 500: # looking for the </class> longer than 0.5 second
			return -1
		if xml.get_node_type() == xml.NODE_ELEMENT:
			if xml.get_node_name() == "class":
				xml.skip_section()
				return xml.get_node_offset()
		xml.read()











# DEPRICATED CODE

#func _export_xml():
#	var s = ""
#	var nl = "\n"
#	var tab = "\t"
#	# <class>
#	s += tab+"<class name=\""+name+"\""
#	if inherits != "":
#		s += " inherits=\""+inherits+"\""
#	s += " category=\"Core\">"+nl
#	#	<brief_description>
#	s += tab+tab+"<brief_description>"+nl
#	if brief_desc != "":
#		s += tab+brief_desc+nl
#	s += tab+tab+"</brief_description>"+nl
#	#	</brief_description>
#	#	<description>
#	s += tab+tab+"<description>"+nl
#	if desc != "":
#		s += tab+desc+nl
#	s += tab+tab+"</description>"+nl
#	#	</description>
#	#	<methods>
#	s += tab+tab+"<methods>"+nl
#	for method in methods:
#	#		<method>
#		if method.name == "": # skip unnamed
#			continue
#		s += tab+tab+tab+"<method name=\""+method.name+"\">"+nl
#	#			<return_type>
#		if method.return_type != "":
#			s += tab+tab+tab+tab+"<return_type=\""+method.return_type+"\"></return_type>"+nl
#	#			<description>
#		s += tab+tab+tab+tab+"<description>"+nl
#		if method.description != "":
#			s += tab+tab+tab+tab+method.description+nl
#		s += tab+tab+tab+tab+"</description>"+nl
#	#			<argument>
#		var idx = 0
#		for i in range(method.arg_count):
#			var arg = method.arguments[i]
#			if arg.type == "":
#				#print("Skipping incorrect argument (",i,")")
#				continue
#			if arg.name == "":
#				arg.name == "arg"+str(idx)
#			s += tab+tab+tab+tab+"<argument index="+str(idx)+" name=\""+arg.name+"\" type=\""+arg.type+"\">"+nl
#			s += tab+tab+tab+tab+"</argument>"+nl
#			idx += 1
#	#			</argument>
#	s += tab+tab+"</methods>"+nl
#	#	</methods>
#	s += tab+"</class>"
#	# </class>
#	save_xml(s,"res://test.xml")
#
#func save_xml( s, path ):
#	var f  File.new()
#	f.open(path,File.WRITE)
#	f.store_string(s)
#	f.close()

