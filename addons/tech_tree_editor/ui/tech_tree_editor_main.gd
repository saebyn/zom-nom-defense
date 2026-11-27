@tool
extends VBoxContainer

## Tech Tree Editor Main Screen
## Main UI for the tech tree editor (main screen plugin)

# Branch color scheme
const BRANCH_COLORS := {
  "Offensive": Color("#E74C3C"),
  "Defensive": Color("#3498DB"),
  "Economy": Color("#2ECC71"),
  "Support": Color("#F39C12"),
  "Click": Color("#9B59B6"),
  "Advanced": Color("#F1C40F")
}

# Valid branch names
const VALID_BRANCHES := ["Offensive", "Defensive", "Economy", "Support", "Click", "Advanced"]

# ID prefixes for validation
const ID_PREFIXES := {
  "Offensive": ["tur_"],
  "Defensive": ["ob_"],
  "Economy": ["eco_"],
  "Support": ["sup_"],
  "Click": ["clk_"],
  "Advanced": ["adv_"]
}

@onready var graph_edit: GraphEdit = $ContentArea/GraphEdit
@onready var toolbar: HBoxContainer = $Toolbar
@onready var status_label: Label = $StatusBar/StatusLabel
@onready var validation_panel: Panel = $ContentArea/ValidationPanel
@onready var validation_list: ItemList = $ContentArea/ValidationPanel/VBoxContainer/ValidationList

# Data
var tech_nodes: Dictionary = {} # tech_id -> Resource_TechNode
var graph_nodes: Dictionary = {} # tech_id -> GraphNode
var selected_tech_id: String = ""
var validation_errors: Array[String] = []
var filter_timer: Timer = null # Debounce timer for search/filter
var _selected_tech_resource: Resource_TechNode = null # currently inspected resource
var _saving: bool = false # guard against re-entrant saves

const TECH_TREE_PATH := "res://Config/TechTree/"
const FILTER_DEBOUNCE_TIME := 0.3 # seconds

func _ready() -> void:
  if not Engine.is_editor_hint():
    return
  
  # Create filter debounce timer
  filter_timer = Timer.new()
  filter_timer.one_shot = true
  filter_timer.wait_time = FILTER_DEBOUNCE_TIME
  filter_timer.timeout.connect(_apply_filters)
  add_child(filter_timer)
  
  _setup_ui()
  _load_tech_tree()
  _rebuild_graph()
  _update_status()
  
  # Set up keyboard shortcuts
  set_process_unhandled_key_input(true)

func _unhandled_key_input(event: InputEvent) -> void:
  if event is InputEventKey and event.pressed:
    # Ctrl+R - Refresh
    if event.keycode == KEY_R and event.ctrl_pressed:
      _on_refresh_pressed()
      accept_event()
    # Ctrl+N - New node
    elif event.keycode == KEY_N and event.ctrl_pressed:
      _on_add_node_pressed()
      accept_event()
    # Ctrl+V - Validate
    elif event.keycode == KEY_V and event.ctrl_pressed:
      _on_validate_pressed()
      accept_event()
    # Ctrl+E - Export
    elif event.keycode == KEY_E and event.ctrl_pressed:
      _on_export_pressed()
      accept_event()
    # Ctrl+F - Focus search
    elif event.keycode == KEY_F and event.ctrl_pressed:
      var search_edit := toolbar.get_node_or_null("SearchEdit") as LineEdit
      if search_edit:
        search_edit.grab_focus()
      accept_event()
    # Ctrl+L - Auto-layout
    elif event.keycode == KEY_L and event.ctrl_pressed:
      _auto_layout_graph()
      accept_event()

func _setup_ui() -> void:
  # Setup GraphEdit
  graph_edit.connection_request.connect(_on_connection_request)
  graph_edit.disconnection_request.connect(_on_disconnection_request)
  graph_edit.node_selected.connect(_on_node_selected)
  graph_edit.node_deselected.connect(_on_node_deselected)
  graph_edit.delete_nodes_request.connect(_on_delete_nodes_request)
  graph_edit.popup_request.connect(_on_popup_request)
  
  # Setup toolbar buttons
  var refresh_button := Button.new()
  refresh_button.text = "Refresh"
  refresh_button.tooltip_text = "Refresh tech tree from disk (Ctrl+R)"
  refresh_button.pressed.connect(_on_refresh_pressed)
  toolbar.add_child(refresh_button)
  
  var add_node_button := Button.new()
  add_node_button.text = "Add Node"
  add_node_button.tooltip_text = "Create a new tech node (Ctrl+N)"
  add_node_button.pressed.connect(_on_add_node_pressed)
  toolbar.add_child(add_node_button)
  
  var validate_button := Button.new()
  validate_button.text = "Validate"
  validate_button.tooltip_text = "Validate the tech tree (Ctrl+V)"
  validate_button.pressed.connect(_on_validate_pressed)
  toolbar.add_child(validate_button)
  
  var export_button := Button.new()
  export_button.text = "Export Markdown"
  export_button.tooltip_text = "Export tech tree to Markdown (Ctrl+E)"
  export_button.pressed.connect(_on_export_pressed)
  toolbar.add_child(export_button)

  var auto_layout_button := Button.new()
  auto_layout_button.text = "Auto-Layout"
  auto_layout_button.tooltip_text = "Reset all nodes to the default branch/level grid layout (Ctrl+L)"
  auto_layout_button.pressed.connect(_auto_layout_graph)
  toolbar.add_child(auto_layout_button)
  var spacer := Control.new()
  spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  toolbar.add_child(spacer)
  
  var search_label := Label.new()
  search_label.text = "Filter:"
  toolbar.add_child(search_label)
  
  var search_edit := LineEdit.new()
  search_edit.placeholder_text = "Search by ID or name..."
  search_edit.tooltip_text = "Filter tech nodes by ID or display name (Ctrl+F to focus)"
  search_edit.custom_minimum_size = Vector2(150, 0)
  search_edit.text_changed.connect(_on_search_changed)
  search_edit.name = "SearchEdit"
  toolbar.add_child(search_edit)
  
  var branch_filter := OptionButton.new()
  branch_filter.tooltip_text = "Filter tech nodes by branch"
  branch_filter.add_item("All Branches")
  for branch in VALID_BRANCHES:
    branch_filter.add_item(branch)
  branch_filter.item_selected.connect(_on_branch_filter_changed)
  branch_filter.name = "BranchFilter"
  toolbar.add_child(branch_filter)
  
  # Hide validation panel by default
  validation_panel.hide()

func _on_search_changed(search_text: String) -> void:
  # Debounce search to avoid filtering on every keystroke
  if filter_timer:
    filter_timer.start()

func _on_branch_filter_changed(index: int) -> void:
  # Apply filter immediately for dropdown changes
  _apply_filters()

func _apply_filters() -> void:
  var search_edit := toolbar.get_node_or_null("SearchEdit") as LineEdit
  var branch_filter := toolbar.get_node_or_null("BranchFilter") as OptionButton
  
  if not search_edit or not branch_filter:
    return
  
  var search_text := search_edit.text.to_lower()
  var selected_branch := ""
  if branch_filter.selected > 0:
    selected_branch = VALID_BRANCHES[branch_filter.selected - 1]
  
  # Filter graph nodes
  for tech_id in graph_nodes:
    var graph_node = graph_nodes[tech_id]
    var tech = tech_nodes[tech_id]
    
    var visible := true
    
    # Apply search filter
    if not search_text.is_empty():
      if not tech_id.to_lower().contains(search_text) and not tech.display_name.to_lower().contains(search_text):
        visible = false
    
    # Apply branch filter
    if not selected_branch.is_empty():
      if tech.branch_name != selected_branch:
        visible = false
    
    graph_node.visible = visible
  
  var visible_count := 0
  for tech_id in graph_nodes:
    if graph_nodes[tech_id].visible:
      visible_count += 1
  
  _set_status("Showing %d / %d nodes" % [visible_count, tech_nodes.size()])

func _load_tech_tree() -> void:
  tech_nodes.clear()
  
  var dir := DirAccess.open(TECH_TREE_PATH)
  if not dir:
    _set_status("Error: Could not open tech tree directory", true)
    return
  
  dir.list_dir_begin()
  var file_name := dir.get_next()
  
  while file_name != "":
    if not dir.current_is_dir() and file_name.ends_with(".tres"):
      var resource_path := TECH_TREE_PATH + file_name
      var tech_node := load(resource_path) as Resource_TechNode
      
      if tech_node:
        tech_nodes[tech_node.id] = tech_node
    
    file_name = dir.get_next()
  
  dir.list_dir_end()
  
  _set_status("Loaded %d tech nodes" % tech_nodes.size())

func _rebuild_graph() -> void:
  # Clear existing graph nodes
  for node in graph_edit.get_children():
    if node is GraphNode:
      graph_edit.remove_child(node)
      node.queue_free()
  
  graph_nodes.clear()
  
  # Create all graph nodes first (needed for sizing)
  for tech_id in tech_nodes:
    var tech = tech_nodes[tech_id]
    var graph_node := _create_graph_node(tech)
    graph_edit.add_child(graph_node)
    graph_nodes[tech.id] = graph_node
  
  # Apply layout then draw connections
  _apply_layout()
  _draw_connections()

func _create_graph_node(tech: Resource_TechNode) -> GraphNode:
  var graph_node := GraphNode.new()
  graph_node.name = tech.id
  graph_node.title = tech.display_name
  graph_node.resizable = false
  graph_node.draggable = true
  
  # Set color based on branch
  if tech.branch_name in BRANCH_COLORS:
    var color = BRANCH_COLORS[tech.branch_name]
    graph_node.modulate = Color(color.r, color.g, color.b, 1)
  
  # Add content
  var vbox := VBoxContainer.new()
  
  var id_label := Label.new()
  id_label.text = "ID: " + tech.id
  id_label.add_theme_font_size_override("font_size", 10)
  vbox.add_child(id_label)
  
  var branch_label := Label.new()
  branch_label.text = "Branch: " + tech.branch_name
  vbox.add_child(branch_label)
  
  var level_label := Label.new()
  level_label.text = "Level: " + str(tech.level_requirement)
  vbox.add_child(level_label)

  if tech.scrap_cost > 0:
    var cost_label := Label.new()
    cost_label.text = "Cost: %d ⚙" % tech.scrap_cost
    cost_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
    vbox.add_child(cost_label)
  
  if tech.prerequisite_tech_ids.size() > 0:
    var prereq_label := Label.new()
    prereq_label.text = "Prerequisites: " + str(tech.prerequisite_tech_ids.size())
    vbox.add_child(prereq_label)
  
  if tech.mutually_exclusive_with.size() > 0:
    var excl_label := Label.new()
    excl_label.text = "⚠ Mutually Exclusive: " + str(tech.mutually_exclusive_with.size())
    excl_label.add_theme_color_override("font_color", Color.RED)
    vbox.add_child(excl_label)
  
  graph_node.add_child(vbox)
  
  # Configure slots for connections
  # Slot 0: left input (for prerequisites pointing to this node)
  # Slot 0: right output (for this node's prerequisites pointing out)
  graph_node.set_slot(0, true, 0, Color.WHITE, true, 0, Color.WHITE)
  
  return graph_node

func _draw_connections() -> void:
  # Clear existing connections
  graph_edit.clear_connections()
  
  # Draw prerequisite connections (normal lines)
  for tech_id in tech_nodes:
    var tech = tech_nodes[tech_id]
    for prereq_id in tech.prerequisite_tech_ids:
      if prereq_id in graph_nodes:
        graph_edit.connect_node(prereq_id, 0, tech_id, 0)
  
  # Note: GraphEdit doesn't support custom line styles for mutual exclusivity
  # We'll handle this differently in the visual representation

func _validate_tech_tree() -> Array[String]:
  var errors: Array[String] = []
  
  # Check ID uniqueness (already handled by dictionary keys)
  
  # Check for circular dependencies
  for tech_id in tech_nodes:
    if _has_circular_dependency(tech_id):
      errors.append("Circular dependency detected for: " + tech_id)
  
  # Verify prerequisite node existence
  for tech_id in tech_nodes:
    var tech = tech_nodes[tech_id]
    for prereq_id in tech.prerequisite_tech_ids:
      if prereq_id not in tech_nodes:
        errors.append("%s: Prerequisite '%s' does not exist" % [tech_id, prereq_id])
  
  # Validate mutual exclusivity pairs
  for tech_id in tech_nodes:
    var tech = tech_nodes[tech_id]
    for excl_id in tech.mutually_exclusive_with:
      if excl_id not in tech_nodes:
        errors.append("%s: Mutually exclusive tech '%s' does not exist" % [tech_id, excl_id])
      else:
        var other_tech = tech_nodes[excl_id]
        if tech_id not in other_tech.mutually_exclusive_with:
          errors.append("%s: Mutual exclusivity with '%s' is not bidirectional" % [tech_id, excl_id])
  
  # Check branch completion requirements
  for tech_id in tech_nodes:
    var tech = tech_nodes[tech_id]
    for branch in tech.requires_branch_completion:
      if branch not in VALID_BRANCHES:
        errors.append("%s: Invalid branch completion requirement '%s'" % [tech_id, branch])
  
  # Validate ID prefix consistency
  for tech_id in tech_nodes:
    var tech = tech_nodes[tech_id]
    if tech.branch_name in ID_PREFIXES:
      var valid_prefixes: Array = ID_PREFIXES[tech.branch_name]
      var has_valid_prefix := false
      for prefix in valid_prefixes:
        if tech_id.begins_with(prefix):
          has_valid_prefix = true
          break
      if not has_valid_prefix:
        errors.append("%s: ID should start with one of %s for branch '%s'" % [tech_id, str(valid_prefixes), tech.branch_name])
  
  return errors

func _has_circular_dependency(tech_id: String, visited: Dictionary = {}) -> bool:
  if tech_id in visited:
    return true
  
  if tech_id not in tech_nodes:
    return false
  
  # Mark as visited for this path
  visited[tech_id] = true
  
  var tech = tech_nodes[tech_id]
  for prereq_id in tech.prerequisite_tech_ids:
    if _has_circular_dependency(prereq_id, visited):
      visited.erase(tech_id) # Clean up before returning
      return true
  
  # Unmark when backtracking (allows different paths to revisit)
  visited.erase(tech_id)
  return false

func _set_status(text: String, is_error: bool = false) -> void:
  status_label.text = text
  if is_error:
    status_label.add_theme_color_override("font_color", Color.RED)
  else:
    status_label.add_theme_color_override("font_color", Color.WHITE)

func _update_status() -> void:
  _set_status("Tech nodes: %d | Errors: %d" % [tech_nodes.size(), validation_errors.size()], validation_errors.size() > 0)

# Signal handlers
func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
  # Add prerequisite connection
  if to_node in tech_nodes:
    var tech = tech_nodes[to_node]
    if from_node not in tech.prerequisite_tech_ids:
      tech.prerequisite_tech_ids.append(from_node)
      _save_tech_node(tech)
      # Only redraw connections, don't rebuild entire graph
      _draw_connections()
      _update_node_display(to_node)
      # Refresh inspector if this node is currently selected
      if selected_tech_id == to_node:
        EditorInterface.inspect_object(tech)

func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
  # Remove prerequisite connection
  if to_node in tech_nodes:
    var tech = tech_nodes[to_node]
    var idx = tech.prerequisite_tech_ids.find(from_node)
    if idx >= 0:
      tech.prerequisite_tech_ids.remove_at(idx)
      _save_tech_node(tech)
      # Only redraw connections, don't rebuild entire graph
      _draw_connections()
      _update_node_display(to_node)
      # Refresh inspector if this node is currently selected
      if selected_tech_id == to_node:
        EditorInterface.inspect_object(tech)

func _on_node_selected(node: Node) -> void:
  if node is GraphNode:
    selected_tech_id = node.name
    _inspect_selected_tech()

func _on_node_deselected(node: Node) -> void:
  _disconnect_resource_changed()
  selected_tech_id = ""
  EditorInterface.inspect_object(null)

func _on_delete_nodes_request(nodes: Array[StringName]) -> void:
  if nodes.size() == 0:
    return
  
  # Check dependencies
  var dependencies: Array[String] = []
  for node_name in nodes:
    var tech_id := String(node_name)
    # Check if any other nodes depend on this one
    for other_id in tech_nodes:
      if other_id == tech_id:
        continue
      var other_tech = tech_nodes[other_id]
      if tech_id in other_tech.prerequisite_tech_ids:
        dependencies.append("%s is a prerequisite for %s" % [tech_id, other_id])
      if tech_id in other_tech.mutually_exclusive_with:
        dependencies.append("%s is mutually exclusive with %s" % [tech_id, other_id])
  
  # Show confirmation dialog
  var dialog := ConfirmationDialog.new()
  dialog.title = "Delete Tech Nodes"
  
  var message := "Are you sure you want to delete the following tech nodes?\n\n"
  for node_name in nodes:
    message += "• " + String(node_name) + "\n"
  
  if dependencies.size() > 0:
    message += "\n⚠ Warning: Dependencies found:\n"
    for dep in dependencies:
      message += "• " + dep + "\n"
    message += "\nThese references will become invalid!"
  
  dialog.dialog_text = message
  add_child(dialog)
  
  dialog.confirmed.connect(func():
    for node_name in nodes:
      var tech_id := String(node_name)
      if tech_id in tech_nodes:
        # Remove from dictionary
        tech_nodes.erase(tech_id)
        
        # Delete the file
        var file_path := TECH_TREE_PATH + tech_id + ".tres"
        if FileAccess.file_exists(file_path):
          DirAccess.remove_absolute(file_path)
        
        _set_status("Deleted tech node: " + tech_id)
    
    # Clear selection if deleted node was selected
    if selected_tech_id not in tech_nodes:
      _disconnect_resource_changed()
      EditorInterface.inspect_object(null)
      selected_tech_id = ""
      _set_status("Deleted selected tech node. Select another tech node to continue editing.")
    
    # Rebuild graph
    _rebuild_graph()
    dialog.queue_free()
  )
  
  dialog.popup_centered()

func _on_popup_request(position: Vector2) -> void:
  var popup := PopupMenu.new()
  popup.add_item("Add Tech Node (Ctrl+N)", 0)
  popup.add_separator()
  popup.add_item("Auto-Layout Graph (Ctrl+L)", 1)
  popup.add_item("Reset Zoom", 2)
  popup.add_separator()
  popup.add_item("Validate (Ctrl+V)", 3)
  popup.add_item("Export Markdown (Ctrl+E)", 4)
  
  popup.id_pressed.connect(func(id: int):
    match id:
      0: # Add tech node
        _on_add_node_pressed()
      1: # Auto-layout
        _auto_layout_graph()
      2: # Reset zoom
        graph_edit.zoom = 1.0
        graph_edit.scroll_offset = Vector2.ZERO
      3: # Validate
        _on_validate_pressed()
      4: # Export
        _on_export_pressed()
    popup.queue_free()
  )
  
  add_child(popup)
  popup.position = get_global_mouse_position()
  popup.popup()

func _auto_layout_graph() -> void:
  _apply_layout()
  _set_status("Auto-layout applied")

func _apply_layout() -> void:
  # Layout: branch = row band (Y), prerequisite depth = column (X)
  # Connections flow left-to-right: prerequisite -> dependent
  const NODE_WIDTH := 200
  const NODE_HEIGHT := 200
  const COL_GAP := 60 # horizontal gap between depth columns
  const ROW_GAP := 30 # vertical gap between sibling nodes within a band
  const BAND_GAP := 50 # vertical gap between branch bands
  const START := Vector2(50, 50)
  
  # --- Step 1: compute topological depth for every node ---
  # Depth = longest path from any root (node with no prerequisites)
  var depth: Dictionary = {} # tech_id -> int
  
  # Iterative longest-path (handles DAGs correctly)
  # First pass: initialise all depths to 0
  for tech_id in tech_nodes:
    depth[tech_id] = 0
  
  # Repeatedly relax until stable (Bellman-Ford style, but on a DAG so converges fast)
  var changed := true
  while changed:
    changed = false
    for tech_id in tech_nodes:
      var tech = tech_nodes[tech_id]
      for prereq_id in tech.prerequisite_tech_ids:
        if prereq_id in depth:
          var candidate: int = depth[prereq_id] + 1
          if candidate > depth[tech_id]:
            depth[tech_id] = candidate
            changed = true
  
  # --- Step 2: group by branch, then by depth within each branch ---
  # branches_by_depth[branch][depth] = [tech_id, ...]
  var branches_by_depth: Dictionary = {}
  for branch_name in VALID_BRANCHES:
    branches_by_depth[branch_name] = {}
  
  for tech_id in tech_nodes:
    var tech = tech_nodes[tech_id]
    var d: int = depth[tech_id]
    if d not in branches_by_depth[tech.branch_name]:
      branches_by_depth[tech.branch_name][d] = []
    branches_by_depth[tech.branch_name][d].append(tech_id)
  
  # --- Step 3: calculate the height of each branch band ---
  # Band height = max siblings at any depth * (NODE_HEIGHT + ROW_GAP)
  var band_heights: Dictionary = {}
  for branch_name in VALID_BRANCHES:
    var max_siblings := 1
    for d in branches_by_depth[branch_name]:
      var count: int = branches_by_depth[branch_name][d].size()
      if count > max_siblings:
        max_siblings = count
    band_heights[branch_name] = max_siblings * (NODE_HEIGHT + ROW_GAP)
  
  # --- Step 4: find global max depth for column width budget ---
  var max_depth := 0
  for tech_id in depth:
    if depth[tech_id] > max_depth:
      max_depth = depth[tech_id]
  
  var col_step := NODE_WIDTH + COL_GAP
  
  # --- Step 5: position each node ---
  var band_y := START.y
  for branch_name in VALID_BRANCHES:
    if branches_by_depth[branch_name].is_empty():
      continue
    
    var band_h: int = band_heights[branch_name]
    
    for d in branches_by_depth[branch_name]:
      var siblings: Array = branches_by_depth[branch_name][d]
      # Sort siblings by level_requirement for consistent top-to-bottom ordering
      siblings.sort_custom(func(a, b): return tech_nodes[a].level_requirement < tech_nodes[b].level_requirement)
      var total_h := siblings.size() * NODE_HEIGHT + (siblings.size() - 1) * ROW_GAP
      # Centre the sibling stack within the band
      var start_y: float = band_y + (band_h - total_h) * 0.5
      for i in range(siblings.size()):
        var tech_id: String = siblings[i]
        if tech_id in graph_nodes:
          graph_nodes[tech_id].position_offset = Vector2(
            START.x + d * col_step,
            start_y + i * (NODE_HEIGHT + ROW_GAP)
          )
    
    band_y += band_h + BAND_GAP

func _on_refresh_pressed() -> void:
  _disconnect_resource_changed()
  _load_tech_tree()
  _rebuild_graph()
  _update_status()
  # Re-inspect the selected node with the freshly loaded resource
  if selected_tech_id and selected_tech_id in tech_nodes:
    _inspect_selected_tech()

func _on_add_node_pressed() -> void:
  # Create a dialog for adding a new node
  var dialog := AcceptDialog.new()
  dialog.title = "Create New Tech Node"
  dialog.dialog_autowrap = true
  dialog.min_size = Vector2(400, 300)
  
  var vbox := VBoxContainer.new()
  
  # ID field
  var id_hbox := HBoxContainer.new()
  var id_label := Label.new()
  id_label.text = "ID:"
  id_label.custom_minimum_size = Vector2(100, 0)
  id_hbox.add_child(id_label)
  var id_edit := LineEdit.new()
  id_edit.placeholder_text = "e.g., tur_my_turret"
  id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  id_edit.name = "IDEdit"
  id_hbox.add_child(id_edit)
  vbox.add_child(id_hbox)
  
  # Display name field
  var name_hbox := HBoxContainer.new()
  var name_label := Label.new()
  name_label.text = "Display Name:"
  name_label.custom_minimum_size = Vector2(100, 0)
  name_hbox.add_child(name_label)
  var name_edit := LineEdit.new()
  name_edit.placeholder_text = "e.g., My Turret"
  name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  name_edit.name = "NameEdit"
  name_hbox.add_child(name_edit)
  vbox.add_child(name_hbox)
  
  # Branch dropdown
  var branch_hbox := HBoxContainer.new()
  var branch_label := Label.new()
  branch_label.text = "Branch:"
  branch_label.custom_minimum_size = Vector2(100, 0)
  branch_hbox.add_child(branch_label)
  var branch_option := OptionButton.new()
  branch_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  branch_option.name = "BranchOption"
  for branch in VALID_BRANCHES:
    branch_option.add_item(branch)
  branch_hbox.add_child(branch_option)
  vbox.add_child(branch_hbox)
  
  # Level field
  var level_hbox := HBoxContainer.new()
  var level_label := Label.new()
  level_label.text = "Level:"
  level_label.custom_minimum_size = Vector2(100, 0)
  level_hbox.add_child(level_label)
  var level_spin := SpinBox.new()
  level_spin.min_value = 1
  level_spin.max_value = 10
  level_spin.value = 1
  level_spin.name = "LevelSpin"
  level_hbox.add_child(level_spin)
  vbox.add_child(level_hbox)
  
  dialog.add_child(vbox)
  add_child(dialog)
  
  dialog.confirmed.connect(func():
    var new_id := id_edit.text.strip_edges()
    var new_name := name_edit.text.strip_edges()
    var new_branch = VALID_BRANCHES[branch_option.selected]
    var new_level := int(level_spin.value)
    
    if new_id.is_empty():
      _set_status("Error: ID cannot be empty", true)
      return
    
    if new_id in tech_nodes:
      _set_status("Error: Tech node with ID '%s' already exists" % new_id, true)
      return
    
    if new_name.is_empty():
      _set_status("Error: Display name cannot be empty", true)
      return
    
    # Create new tech node resource
    var new_tech := Resource_TechNode.new()
    new_tech.id = new_id
    new_tech.display_name = new_name
    new_tech.branch_name = new_branch
    new_tech.level_requirement = new_level
    new_tech.description = "Description for " + new_name
    
    # Save the new tech node
    tech_nodes[new_id] = new_tech
    _save_tech_node(new_tech)
    
    # Rebuild the graph
    _rebuild_graph()
    _set_status("Created new tech node: " + new_id)
    
    # Auto-inspect the newly created node
    selected_tech_id = new_id
    _inspect_selected_tech()
    
    dialog.queue_free()
  )
  
  dialog.popup_centered()
  id_edit.grab_focus()

func _on_validate_pressed() -> void:
  validation_errors = _validate_tech_tree()
  
  validation_list.clear()
  for error in validation_errors:
    validation_list.add_item(error)
  
  if validation_errors.size() > 0:
    validation_panel.show()
    _set_status("Validation failed: %d errors" % validation_errors.size(), true)
  else:
    validation_panel.hide()
    _set_status("Validation passed!", false)

func _on_export_pressed() -> void:
  var markdown := _generate_markdown()
  
  # Create a dialog to show the markdown
  var dialog := AcceptDialog.new()
  dialog.title = "Export Tech Tree to Markdown"
  dialog.min_size = Vector2(800, 600)
  
  var vbox := VBoxContainer.new()
  
  var label := Label.new()
  label.text = "Generated Markdown:"
  vbox.add_child(label)
  
  var text_edit := TextEdit.new()
  text_edit.text = markdown
  text_edit.editable = false
  text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
  vbox.add_child(text_edit)
  
  var copy_button := Button.new()
  copy_button.text = "Copy to Clipboard"
  copy_button.pressed.connect(func():
    DisplayServer.clipboard_set(markdown)
    _set_status("Markdown copied to clipboard")
  )
  vbox.add_child(copy_button)
  
  var save_button := Button.new()
  save_button.text = "Save to File"
  save_button.pressed.connect(func():
    var file := FileAccess.open("user://tech_tree_export.md", FileAccess.WRITE)
    if file:
      file.store_string(markdown)
      file.close()
      _set_status("Markdown saved to user://tech_tree_export.md")
    else:
      _set_status("Failed to save markdown file", true)
  )
  vbox.add_child(save_button)
  
  dialog.add_child(vbox)
  add_child(dialog)
  dialog.popup_centered()

func _generate_markdown() -> String:
  var md := "# Tech Tree Export\n\n"
  md += "Generated: " + Time.get_datetime_string_from_system() + "\n\n"
  md += "Total Nodes: %d\n\n" % tech_nodes.size()
  
  # Group by branch
  var branches_dict: Dictionary = {}
  for tech_id in tech_nodes:
    var tech = tech_nodes[tech_id]
    if tech.branch_name not in branches_dict:
      branches_dict[tech.branch_name] = []
    branches_dict[tech.branch_name].append(tech)
  
  # Export each branch
  for branch_name in VALID_BRANCHES:
    if branch_name not in branches_dict:
      continue
    
    md += "## %s Branch\n\n" % branch_name
    
    var branch_techs: Array = branches_dict[branch_name]
    # Sort by level
    branch_techs.sort_custom(func(a, b): return a.level_requirement < b.level_requirement)
    
    for tech: Resource_TechNode in branch_techs:
      md += "### %s (`%s`)\n\n" % [tech.display_name, tech.id]
      md += "- **Level Required:** %d\n" % tech.level_requirement
      md += "- **Description:** %s\n" % tech.description
      
      if tech.prerequisite_tech_ids.size() > 0:
        md += "- **Prerequisites:** %s\n" % ", ".join(tech.prerequisite_tech_ids)
      
      if tech.mutually_exclusive_with.size() > 0:
        md += "- **⚠ Mutually Exclusive With:** %s\n" % ", ".join(tech.mutually_exclusive_with)
      
      if tech.requires_branch_completion.size() > 0:
        md += "- **Requires Branch Completion:** %s\n" % ", ".join(tech.requires_branch_completion)
      
      if tech.player_attack_effect:
        md += "- **Unlocks:** Click upgrade\n"
      
      md += "\n"
    
    md += "---\n\n"
  
  # Add validation report
  var errors := _validate_tech_tree()
  md += "## Validation Report\n\n"
  if errors.size() == 0:
    md += "✅ **All validation checks passed!**\n\n"
  else:
    md += "❌ **%d validation errors found:**\n\n" % errors.size()
    for error in errors:
      md += "- %s\n" % error
    md += "\n"
  
  return md

func _inspect_selected_tech() -> void:
  _disconnect_resource_changed()
  if selected_tech_id not in tech_nodes:
    return
  _selected_tech_resource = tech_nodes[selected_tech_id]
  EditorInterface.inspect_object(_selected_tech_resource)
  _selected_tech_resource.changed.connect(_on_selected_resource_changed)

func _disconnect_resource_changed() -> void:
  if is_instance_valid(_selected_tech_resource) and _selected_tech_resource.changed.is_connected(_on_selected_resource_changed):
    _selected_tech_resource.changed.disconnect(_on_selected_resource_changed)
  _selected_tech_resource = null

func _on_selected_resource_changed() -> void:
  if _saving:
    return
  if selected_tech_id in tech_nodes:
    _save_tech_node(tech_nodes[selected_tech_id])
    _update_node_display(selected_tech_id)

func _save_tech_node(tech: Resource_TechNode) -> void:
  _saving = true
  # Temporarily disconnect changed signal to avoid re-entrant callbacks during save
  if is_instance_valid(tech) and tech.changed.is_connected(_on_selected_resource_changed):
    tech.changed.disconnect(_on_selected_resource_changed)
  
  var file_path := TECH_TREE_PATH + tech.id + ".tres"
  
  # Ensure the resource has the correct path
  tech.take_over_path(file_path)
  
  # Save the resource with explicit flags to ensure it's written
  var error := ResourceSaver.save(tech, file_path, ResourceSaver.FLAG_CHANGE_PATH)
  if error != OK:
    _set_status("Failed to save tech node: " + tech.id, true)
  else:
    _set_status("Saved: " + tech.id)
  
  # Reconnect if this is still the selected resource
  if is_instance_valid(tech) and _selected_tech_resource == tech and not tech.changed.is_connected(_on_selected_resource_changed):
    tech.changed.connect(_on_selected_resource_changed)
  _saving = false

func _update_node_display(tech_id: String) -> void:
  # Update a single node's display without rebuilding entire graph
  if tech_id not in tech_nodes or tech_id not in graph_nodes:
    return
  
  var tech = tech_nodes[tech_id]
  var graph_node = graph_nodes[tech_id]
  
  # Update title
  graph_node.title = tech.display_name
  
  # Update color based on branch
  if tech.branch_name in BRANCH_COLORS:
    var color = BRANCH_COLORS[tech.branch_name]
    graph_node.modulate = Color(color.r, color.g, color.b, 1)
  
  # Update content - clear and recreate
  for child in graph_node.get_children():
    child.queue_free()
  
  var vbox := VBoxContainer.new()
  
  var id_label := Label.new()
  id_label.text = "ID: " + tech.id
  id_label.add_theme_font_size_override("font_size", 10)
  vbox.add_child(id_label)
  
  var branch_label := Label.new()
  branch_label.text = "Branch: " + tech.branch_name
  vbox.add_child(branch_label)
  
  var level_label := Label.new()
  level_label.text = "Level: " + str(tech.level_requirement)
  vbox.add_child(level_label)

  if tech.scrap_cost > 0:
    var cost_label := Label.new()
    cost_label.text = "Cost: %d ⚙" % tech.scrap_cost
    cost_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
    vbox.add_child(cost_label)
  
  if tech.prerequisite_tech_ids.size() > 0:
    var prereq_label := Label.new()
    prereq_label.text = "Prerequisites: " + str(tech.prerequisite_tech_ids.size())
    vbox.add_child(prereq_label)
  
  if tech.mutually_exclusive_with.size() > 0:
    var excl_label := Label.new()
    excl_label.text = "⚠ Mutually Exclusive: " + str(tech.mutually_exclusive_with.size())
    excl_label.add_theme_color_override("font_color", Color.RED)
    vbox.add_child(excl_label)
  
  graph_node.add_child(vbox)
  
  # Reconfigure slot for connections after updating content
  graph_node.set_slot(0, true, 0, Color.WHITE, true, 0, Color.WHITE)

func _on_validation_close_pressed() -> void:
  validation_panel.hide()
