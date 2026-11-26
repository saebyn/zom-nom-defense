# Tech Tree Editor Plugin - Testing Guide

## Manual Testing

Since this is an EditorPlugin, it requires manual testing in the Godot Editor.

### Prerequisites
1. Godot 4.4 installed
2. Project opened in Godot Editor
3. Plugin enabled in Project Settings → Plugins

### Test Suite

#### 1. Plugin Loading
- [ ] Plugin appears in the enabled plugins list
- [ ] **"Tech Tree"** tab button appears in the main screen toolbar (next to 2D, 3D, Script, Game, AssetLib)
- [ ] Clicking "Tech Tree" tab shows the full-screen graph editor
- [ ] No errors in the Output/Debugger console
- [ ] Status bar shows "Tech nodes: X | Errors: 0"

#### 2. Data Loading
- [ ] All existing tech nodes from Config/TechTree/ are loaded
- [ ] Graph displays all nodes with correct colors
- [ ] Nodes are positioned correctly (by branch)
- [ ] Expected nodes visible:
  - tur_scrap_shooter (Red - Offensive)
  - ob_crates (Blue - Defensive)
  - eco_scrap_recycler (Green - Economy)
  - tur_boom_barrel (Red - Offensive)
  - tur_molotov_mortar (Red - Offensive)

#### 3. Graph Visualization
- [ ] Nodes are color-coded by branch
- [ ] Node titles display correctly
- [ ] Node details show: ID, Branch, Level
- [ ] Prerequisite counts shown if any
- [ ] Mutual exclusivity warning shown if any
- [ ] Zoom controls work (mouse wheel)
- [ ] Pan controls work (middle-click drag or arrow keys)
- [ ] Minimap is visible and functional

#### 4. Node Selection
- [ ] Clicking a node selects it
- [ ] The selected tech node resource opens in Godot's Inspector dock
- [ ] Inspector shows the tech node properties
- [ ] Clicking empty space deselects node
- [ ] Inspector clears the tech node resource when the node is deselected

#### 5. Node Inspector Editing
Test editing each field in Godot's Inspector:
- [ ] Display Name - text changes
- [ ] Description - text changes
- [ ] Branch - branch name changes
- [ ] Level Requirement - Player Level requirement changes
- [ ] Scrap Cost - number changes
- [ ] Prerequisites - array of tech IDs
- [ ] Achievements - array of achievement IDs
- [ ] Mutually Exclusive - array of tech IDs
- [ ] Unlocked Buildings - array of building IDs
- [ ] Branch Completion - array of branch names
- [ ] Inspector edits are saved automatically to the node's `.tres` file and persist after refreshing from disk
- [ ] Edits to displayed properties (such as Display Name) update the graph without a manual save

#### 6. Node Creation
- [ ] Click "Add Node" button opens dialog
- [ ] ID field accepts input
- [ ] Display Name field accepts input
- [ ] Branch dropdown shows all branches
- [ ] Level spinner (1-10) works
- [ ] Confirm creates new node
- [ ] New node appears in graph
- [ ] New .tres file created in Config/TechTree/
- [ ] Error shown if ID already exists
- [ ] Error shown if ID or name is empty

#### 7. Node Deletion
- [ ] Select node and press Delete key
- [ ] Confirmation dialog appears
- [ ] Dialog shows node to delete
- [ ] If dependencies exist, warning shown
- [ ] Confirm deletes node from graph
- [ ] .tres file removed from Config/TechTree/
- [ ] Can delete multiple nodes (multi-select)

#### 8. Connection Management
- [ ] Drag from one node to another creates connection
- [ ] Connection appears as line in graph
- [ ] Connection saved to prerequisite list
- [ ] Right-click connection and disconnect removes it
- [ ] Prerequisite list updated after disconnect

#### 9. Validation
Click "Validate" button and test each rule:
- [ ] ID uniqueness - duplicate IDs detected
- [ ] Circular dependencies - loops detected
- [ ] Prerequisite existence - missing nodes detected
- [ ] Mutual exclusivity bidirectional - one-way errors caught
- [ ] Branch completion - invalid branch names detected
- [ ] ID prefix consistency - warnings shown
- [ ] Validation panel shows errors
- [ ] Error count shown in status bar
- [ ] Close button hides validation panel

#### 10. Search and Filter
- [ ] Search box filters by ID (partial match)
- [ ] Search box filters by name (partial match)
- [ ] Branch dropdown filters by branch
- [ ] "All Branches" shows all nodes
- [ ] Filtered nodes hidden in graph
- [ ] Status bar shows "Showing X / Y nodes"
- [ ] Clear search restores all nodes

#### 11. Auto-Layout
- [ ] Right-click in graph shows context menu
- [ ] Select "Auto-Layout Graph"
- [ ] Nodes reorganize by branch (columns)
- [ ] Nodes ordered by level within branch
- [ ] Layout is readable and organized

#### 12. Markdown Export
- [ ] Click "Export Markdown" button
- [ ] Dialog shows generated markdown
- [ ] Markdown includes all branches
- [ ] Nodes grouped by branch
- [ ] Nodes sorted by level
- [ ] All properties shown
- [ ] Validation report included
- [ ] Copy to clipboard works
- [ ] Save to file creates user://tech_tree_export.md

#### 13. Keyboard Shortcuts
- [ ] Ctrl+R - Refresh tech tree
- [ ] Ctrl+N - New node dialog
- [ ] Ctrl+V - Validate
- [ ] Ctrl+E - Export markdown
- [ ] Ctrl+F - Focus search box
- [ ] Ctrl+L - Auto-layout

#### 14. Toolbar Tooltips
- [ ] Hover over Refresh shows tooltip
- [ ] Hover over Add Node shows tooltip
- [ ] Hover over Validate shows tooltip
- [ ] Hover over Export shows tooltip
- [ ] Hover over search box shows tooltip
- [ ] Hover over branch filter shows tooltip

#### 15. Context Menu
- [ ] Right-click in graph shows menu
- [ ] Menu items show keyboard shortcuts
- [ ] All menu actions work correctly

### Performance Testing
- [ ] Load time < 2 seconds with 5 nodes
- [ ] Graph rendering smooth at 60fps
- [ ] No lag when selecting nodes
- [ ] No lag when editing properties
- [ ] Auto-layout completes instantly

### Edge Cases
- [ ] Empty tech tree (no .tres files)
- [ ] Corrupted .tres file
- [ ] Missing Config/TechTree/ directory
- [ ] Very long node names (>50 chars)
- [ ] Very long descriptions (>500 chars)
- [ ] Large prerequisite lists (>10 items)
- [ ] Deep prerequisite chains (>5 levels)

### Regression Testing
After making changes to existing tech nodes:
- [ ] TechTreeManager still loads nodes
- [ ] Game still runs without errors
- [ ] Existing save files still work
- [ ] No validation errors introduced

## Automated Testing

Currently, there are no automated tests for the editor plugin since it requires the Godot Editor to run. Future enhancements could include:
- Headless editor testing
- Screenshot comparison testing
- Validation engine unit tests (extract to separate class)

## Bug Reporting

If you find issues, please report with:
1. Godot version
2. Steps to reproduce
3. Expected behavior
4. Actual behavior
5. Console output (if any)
6. Screenshots (if relevant)

## Test Results Template

```
Date: YYYY-MM-DD
Tester: [Name]
Godot Version: 4.4.x
Plugin Version: 1.0.0

[✓] Plugin Loading
[✓] Data Loading
[✓] Graph Visualization
[✓] Node Selection
[✓] Node Inspector Editing
[✓] Node Creation
[✓] Node Deletion
[✓] Connection Management
[✓] Validation
[✓] Search and Filter
[✓] Auto-Layout
[✓] Markdown Export
[✓] Keyboard Shortcuts
[✓] Toolbar Tooltips
[✓] Context Menu

Issues Found:
- None / [List of issues]

Notes:
[Any additional observations]
```
