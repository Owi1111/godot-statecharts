@icon('Mermaid_Logo.png')
extends Node2D
class_name StateChartMermaid

@export var chart: StateChart
@export var enabled: bool = false

var states_string: String = ''
var transitions_string: String = ''
var node_to_unique_name: Dictionary = {}
var name_count: Dictionary = {}

func pascal_case_to_snake_case(s: String) -> String:
	var result := ""
	for i in range(s.length()):
		var c := s[i]
		if c == c.to_upper() and c != c.to_lower():
			if i > 0:
				result += "_"
			result += c.to_lower()
		else:
			result += c
	return result

func _ready() -> void:
	if !OS.is_debug_build() or !enabled:
		return
	
	if chart == null or chart.get_child_count() < 1:
		return

	var scene_path := get_tree().current_scene.scene_file_path
	var dir = scene_path.get_base_dir()
	var file_path := dir.path_join(pascal_case_to_snake_case(chart.name) + '.html')

	generate_states_string_dfs(chart.get_child(0))
	generate_transitions_string_dfs(chart.get_child(0), chart)
	print(states_string)
	print(transitions_string)
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string('<!doctype html>\n<html lang="en">\n  <body>\n    <pre class="mermaid">\nstateDiagram-v2\n\n')
		file.store_string(states_string)
		file.store_string(transitions_string)
		file.store_string('''</pre>\n    <script type="module">\n      import mermaid from \'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs\';\n    </script>\n  </body>\n</html>''')
		file.close()
	
func get_count(counter: Dictionary, key: String) -> int:
	if key not in counter:
		return 0
	return counter[key]

func generate_states_string_dfs(node, depth: int = 0) -> void:
	if node == null:
		return
	
	var count := get_count(name_count, node.name)
	var unique_name: String = node.name + ('' if count == 0 else str(count))
	if node is ParallelState:
		unique_name += '(Parallel)'
	name_count[node.name] = count + 1
	node_to_unique_name[node] = unique_name
	if node is CompoundState or node is ParallelState:
		states_string += '  '.repeat(depth) + 'state ' + unique_name + ' {\n'
		for child in node.get_children():
			generate_states_string_dfs(child, depth + 1)
		if node is CompoundState and node.get_node_or_null(node.initial_state) != null:
			states_string += '  '.repeat(depth + 1) + '[*] --> ' + node_to_unique_name[node.get_node_or_null(node.initial_state)] + '\n'
		states_string += '  '.repeat(depth) + '}\n'
	elif node is StateChartState:
		states_string += '  '.repeat(depth) + unique_name + '\n'
		for child in node.get_children():
			generate_states_string_dfs(child, depth + 1)
			
func generate_transitions_string_dfs(node, parent, depth: int = 0) -> void:
	if node == null:
		return
	if node is Transition and node.get_node_or_null(node.to) != null:
			transitions_string += node_to_unique_name[parent] + ' --> ' + node_to_unique_name[node.get_node_or_null(node.to)]
			if node.event.length() > 0:
				transitions_string += ': ' + node.event
			if node.delay_in_seconds != '0.0' and node.delay_in_seconds.length() > 0:
				transitions_string += '(after ' + node.delay_in_seconds + ')'
			transitions_string += '\n'
	for child in node.get_children():
		generate_transitions_string_dfs(child, node, depth + 1)
