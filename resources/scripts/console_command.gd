class_name ConsoleCommand extends Object

const ALLOWED_TYPES : Array[Variant.Type] = [
	TYPE_BOOL,
	TYPE_FLOAT,
	TYPE_INT,
	TYPE_STRING,
]

var name : String
var function : Callable
var required : int
var arguments : Dictionary
var description : String = "No Description."

## constructor
func _init(name: String, function: Callable, arguments : Dictionary = {}, description: String = "", required: int = 0):
	if description.is_empty(): description = "No Description."
	self.name = name
	self.function = function
	self.arguments = arguments
	self.description = description
	self.required = required

func get_arguments_as_string(): 
	var s: String 
	if arguments.size() > 0: s += "<"
	for i in range(0, arguments.size()):
		var type = type_string(arguments.values()[i])
		s += arguments.keys()[i] + ": " if !arguments.keys()[i].is_empty() else ""
		s += ("[u][b]%s[/b][/u]" % type) if i+1 <= required else type 
		if i != arguments.size() - 1: s += ", "
	if arguments.size() > 0: s += ">"
	return s

func get_as_rich_string(cmd_color = Color.CYAN, arg_colors = Color.YELLOW):
	var s: String
	s += "[color=#%s]%s[/color]" % [cmd_color.to_html(), name]
	if arguments.size() > 0: s += " " + get_arguments_as_string()
	return s
	
	
## virtual override for to_string
func _to_string():
	var s: String
	s += name + " "
	if arguments.size() > 0: s += "- " + get_arguments_as_string()
	return s

## tries to parse arg to variant, returns null otherwise
static func arg_to_type(arg: String, type: Variant.Type):
	if type == TYPE_STRING: return arg
	
	var v = str_to_var(arg)
	if typeof(v) != type: return null
	return v
