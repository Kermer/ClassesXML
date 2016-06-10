
extends Panel

var method

func _ready():
	get_node("Desc").connect("focus_enter",get_parent(),"_show_desc_overflow",[get_node("Desc")])
	get_node("Desc").connect("text_changed",get_parent(),"_desc_updated",[get_node("Desc")])
	pass


func set_method( new_method ):
	save_method()
	clear()
	method = new_method
	get_node("Name").set_text(method.name)
	get_node("ReturnType").set_text(method.return_type)
	get_node("Qualifiers").set_text(method.qualifiers)
	get_node("Desc").set_text(method.desc)
	
	var args = method.args # [ {"name","type"} ]
	var args_count = args.size()
	args_count = min(args_count,4) # max 4 editable args ATM. If there are more in method, they won't be deleted, but won't be displayed as well
	# TODO: add ScrollContainer for args
	for i in range(args_count):
		var arg = args[i]
		var node = get_node("Arg"+str(i))
		node.set_text( arg.name )
		node.get_node("Type").set_text( arg.type )

func clear():
	method = null
	get_node("Name").set_text("")
	get_node("ReturnType").set_text("")
	get_node("Qualifiers").set_text("")
	get_node("Desc").set_text("")
	for i in range(4):
		var node = get_node("Arg"+str(i))
		node.set_text("")
		node.get_node("Type").set_text("")

func save_method():
	if method == null:
		return
#	method.name = get_node("Name").get_text()
	method.return_type = get_node("ReturnType").get_text().strip_edges()
	method.qualifiers = get_node("Qualifiers").get_text().strip_edges()
	method.desc = get_node("Desc").get_text().strip_edges()
	var args_count = 0
	for i in range(4):
		var node = get_node("Arg"+str(i))
		var arg_name = node.get_text().strip_edges()
		var arg_type = node.get_node("Type").get_text().strip_edges()
		if arg_name == "" or arg_type == "":
			continue
		args_count += 1
	if method.args.size() < args_count:
		method.args.resize(args_count)
	for i in range(4):
		var node = get_node("Arg"+str(i))
		var arg_name = node.get_text().strip_edges()
		var arg_type = node.get_node("Type").get_text().strip_edges()
		if arg_name == "" or arg_type == "":
			continue
		var arg
		if typeof(method.args[i]) == TYPE_DICTIONARY:
			arg = method.args[i]
			arg.name = arg_name
			arg.type = arg_type
		else:
			arg = {"name":arg_name,"type":arg_type} # ,"default"
		method.args[i] = arg
	
	# "method" is a reference so there's no need for the line below
#	get_parent().methods_list[ method.name ] = method


