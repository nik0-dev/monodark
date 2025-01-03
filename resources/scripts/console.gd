## A console for logging and using commands.
class_name MDConsole extends CanvasLayer

## Checks if an input action exists for 'console_toggle'.
@onready var _use_fallback_key : bool = !InputMap.has_action("console_toggle") 

## A reference to the MDConsole user interface.
var interface : MDConsoleUI
const INTERFACE_PATH : String = "res://addons/monodark/console_interface.tscn"

## Allows console configuration logging messages to be broadcasted. (default = true)
var _echo_cfg_logs : bool = true
## Allows any console command configuration logging messages to be broadcasted. (default = false)
var _echo_cmd_cfg_logs : bool = true

var plugin_name : String = "Unable to fetch plugin name..."
var author : String = "Unable to fetch author..."
var version : String = "Unable to fetch version..."
var description : String = "Unable to fetch description..."

var commands = {}
var history : Array[String] = []

const CMD_REF_COLOR = Color.CYAN

#  ======== Initialization ========

func _ready():
	var cfg = ConfigFile.new()
	if cfg.load("res://addons/monodark/plugin.cfg") == OK: 
		plugin_name = cfg.get_value("plugin", "name", "Unable to fetch plugin name...")
		author = cfg.get_value("plugin", "author", "Unable to fetch author...")
		version = cfg.get_value("plugin", "version", "Unable to fetch version...")
		description = cfg.get_value("plugin", "description", "Unable to fetch description...")
	
	process_mode = PROCESS_MODE_ALWAYS
	_initialize_interface()
	_connect_signals()
	_add_base_commands()
	if _use_fallback_key && _echo_cfg_logs: broadcast_warning(_get_md_no_mapping_warning())
	
func _add_base_commands():
	suppress_cmd_cfg_logs()
	add_command("help", help, {"command": TYPE_STRING}, "gives the user basic information about the console...\nwhen supplied with a command name it gives more information about the command.", 0)
	add_command("command_list", command_list, {}, "lists all the current registered commands and their usage")
	add_command("about", about, {}, "gives more information about the console.")
	add_command("cls", cls, {}, "clears the console")
	add_command("clear", cls, {}, "clears the console, an alias for %s" % cmd_ref("cls"))
	enable_cmd_cfg_logs()
	
func _initialize_interface():
	interface = preload(INTERFACE_PATH).instantiate()
	add_child(interface)
	interface.set_active(false)
	enable()
	
func _connect_signals():
	interface.input.text_submitted.connect(_handle_input_submission)

# ======== Methods ========

## Suppresses any logs from command configuration functions.
func suppress_cmd_cfg_logs(): _echo_cmd_cfg_logs = false
## Enables any logs from command configuration functions.
func enable_cmd_cfg_logs(): _echo_cmd_cfg_logs = true

## Adds an existing command to the console registry if it's able.
func add_existing_command(cmd: ConsoleCommand):
	add_command(cmd.name, cmd.function, cmd.arguments, cmd.description, cmd.required)

## Add a command to the console registry if it's able.
func add_command(name: String, function: Callable, arguments: Dictionary = {}, description: String = "", required: int = 0):
	var cmd = ConsoleCommand.new(name, function, arguments, description, required)
	if cmd.name.is_empty():
		_push_cmd_cfg_log(broadcast_error.bind("Failed to add command, name cannot be empty."))
		return
		
	for arg in cmd.arguments.keys():
		if arg is not String:
			_push_cmd_cfg_log(broadcast_error.bind("Failed to add '%s', parameter name was not a string." % cmd.name))
			return
			
	for arg in cmd.arguments.values():
		if arg not in ConsoleCommand.ALLOWED_TYPES:
			_push_cmd_cfg_log(broadcast_error.bind("Failed to add '%s', types not supported." % cmd.name))
			return
	
	if commands.has(cmd.name):
		_push_cmd_cfg_log(broadcast_error.bind("Failed to add '%s', a command is already registered with that name." % cmd.name))
		return 
	else:
		commands[cmd.name] = cmd
		_push_cmd_cfg_log(broadcast_success.bind("Command '%s' successfully added!" % cmd.name))

## Calls a loggable function if command configuration logging is enabled.
func _push_cmd_cfg_log(fn: Callable):
	if _echo_cmd_cfg_logs: 
		fn.call()
		
## Removes a command from the console registry.
func remove_command(cmd: ConsoleCommand):
	if commands.has(cmd.name):
		if commands[cmd.name] == cmd:
			commands.erase(cmd.name)
			if _echo_cmd_cfg_logs:
				broadcast_success("Successfully removed '%s'" % cmd.name)
		else:
			if _echo_cmd_cfg_logs:
				broadcast_warning("'%s' shares a name with another command, but is not the registered command, ignoring removal." % cmd.name)
	else:
			if _echo_cmd_cfg_logs:
				broadcast_warning("Command '%s' not found in list, ignoring removal." % cmd.name)

## Parses text and tries to call a command in the registry.
func process_cmd(cmd: String):
	var text_split = cmd.split(" ")
	var text_command = text_split[0]
	if commands.has(text_command):
		var arguments : Array = text_split.slice(1)
		
		if arguments.size() < commands[text_command].required:
			log_error("Not enough arguments, command requires %d argument(s)." % commands[text_command].required)
			return
		elif arguments.size() > commands[text_command].arguments.size():
			log_error("Too many arguments, command has a maximum of %d argument(s)." % commands[text_command].arguments.size())
			return

		var converted_args : Array
		for i in range(arguments.size()):
			var cmd_obj = commands[text_command] as ConsoleCommand
			var conv_type = cmd_obj.arg_to_type(arguments[i], cmd_obj.arguments.values()[i])
			if conv_type == null:
				log_error("Invalid parameter types, use %s %s for more information." % [cmd_ref("help"), cmd_ref(text_command)])
				return 
			converted_args.append(conv_type)
		
		while (arguments.size() < commands[text_command].arguments.size()): 
			arguments.append("")
		
		
		commands[text_command].function.callv(arguments)
	else:
		log_error("Command not found. For a list of all commands type %s." % cmd_ref("command_list"))

## Clears the Console.
func cls(): interface.output.clear()
## Changes the opacity of the output area. (0.0 - 1.0).
func change_opacity(value: float): interface.change_opacity(value)
## Enables the Console, useful for externally controlling console activity.
func enable(): interface.enable()
## Disables the Console, useful for externally controlling console activity.
func disable(): interface.disable()
## Flips the Console's current state, useful for externally controlling console activity.
func toggle(): interface.disable() if interface.visible else interface.enable() 

## Logs a message to the Console, and optionally broadcasts to Godot's Console.
func log_msg(msg: String, color: Color = Color.WHITE, broadcast: bool = false, use_time_stamp: bool = false): 
	var time = Time.get_datetime_dict_from_system()
	var stamp = "[%02d:%02d:%02d] - " % [time.hour, time.minute, time.second]
	var fmt_msg = msg if color == Color.WHITE else color(msg, color)
	
	write(stamp)
	write_line(fmt_msg)
	
	if broadcast: print_rich("[b][MONODARK][/b] - %s" % fmt_msg)

## Writes the exact contents to the interface, used for more control over text presentation.
func write(msg: String): 
	interface.write(msg)

## Writes line without any other formatting, used for more control over text presentation.
func write_line(msg: String = ""): 
	interface.write(msg + "\n")

## Broadcasts a message to both Monodark and Godot Consoles.
func broadcast_msg(msg: String, color: Color = Color.WHITE): log_msg(msg, color, true)
## Broadcasts a warning to both Monodark and Godot Consoles.
func broadcast_warning(msg: String): log_warning(msg, true)
## Broadcasts an error to both Monodark and Godot Consoles.
func broadcast_error(msg: String): log_error(msg, true)
## Broadcasts a successs message to both Monodark and Godot Consoles.
func broadcast_success(msg: String): log_success(msg, true)

## Logs an error to the Console, and optionally broadcasts to Godot's Console.
func log_error(msg: String, broadcast: bool = false): log_msg(_create_status_msg(msg, "ERROR"), Color8(255, 29, 101), broadcast)
## Logs a warning to the Console, and optionally broadcasts to Godot's Console.
func log_warning(msg: String, broadcast: bool = false): log_msg(_create_status_msg(msg, "WARNING"), Color.YELLOW, broadcast)
## Logs a success message to the Console, and optionally broadcasts to Godot's Console.
func log_success(msg: String, broadcast: bool = false): log_msg(_create_status_msg(msg, "SUCCESS"), Color.GREEN, broadcast)

## Creates a status badge for a message.  
static func _create_status_msg(msg: String, status: String): return "[b][%s]: %s[/b]" % [status, msg]
## Wraps a message in a BBCode color.
static func color(msg: String, color: Color): return "[color=#%s]%s[/color]" % [color.to_html(), msg]
## Returns a string with the color of a referenced command name
static func cmd_ref(cmd_name: String): return "[b]%s[/b]" % color(cmd_name, CMD_REF_COLOR)

## Displayed warning for no console_toggle mapping.
func _get_md_no_mapping_warning() -> String: 
	return "Using fallback key ('F7') ... Consider setting an input action for 'console_toggle'."

func help(cmd: String = ""):
	if cmd.is_empty():
		write_line("\n- Welcome to the [pulse]Monodark[/pulse] Console!")
		write_line("- Type %s for more information about a command." % cmd_ref("help <command>"))
		write_line("- Type %s to learn more." % cmd_ref("about"))
		write_line("- Type %s for a list of commands.\n" % cmd_ref("command_list"))
	else:
		if commands.has(cmd):
			write_line("\n[b][i]Parameters that are [u]underlined[/u] are required.[/i][/b]")
			write_line("[b]> syntax: [/b]" + (commands[cmd] as ConsoleCommand).get_as_rich_string())
			write_line("[b]> required-args: [/b]%s" % color(str(commands[cmd].required), Color.CYAN))
			write_line("[b]> description: [/b]%s\n" % color(commands[cmd].description, Color.BISQUE))
		else:
			log_error("No command with that name found.")
	

func about():
	write_line("\nAuthor: [b][rainbow freq=0.1]%s[/rainbow][/b] | Version: %s\n" % [author, version])
	write_line("[b]Description:[/b] [i]%s[/i]\n" % description)
	
#func _fetch_prop_err(msg: String):
	
# ======== Events ========

func command_list():
	write_line("\n[b][i]Parameters that are [u]underlined[/u] are required.[/i][/b]")
	for command in commands.keys():
		write_line("[b]>[/b] %s" % (commands[command] as ConsoleCommand).get_as_rich_string())

func _handle_input_submission(text: String):
	if !text.strip_edges().is_empty():
		interface.scroll_to_newest()
		interface.input.clear()
		log_msg("[i]%s[/i]" % text )
		process_cmd(text.c_unescape())
	
func _input(event):
	if _use_fallback_key:
		if event is InputEventKey:
			if event.physical_keycode == KEY_F7 && !event.is_echo() && !event.is_released():
				toggle()
	else:
		if InputMap.has_action("console_toggle"):
			if Input.is_action_just_pressed("console_toggle"):
				toggle()
