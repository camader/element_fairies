# Session Notes — 2026-06-19

All work was in the tangram mini-game and the shared mini-game base class.

---

## 1. Rotate a placed piece (right-click)

**File:** `scripts/minigames/tangram.gd`

Added `MOUSE_BUTTON_RIGHT` handling in `_on_cell_gui_input`. When the user right-clicks a cell that contains a piece, `_try_rotate_placed(piece_index)` is called.

`_try_rotate_placed` works by:
1. Temporarily clearing the piece from `grid_occupied`
2. Computing the next rotation using the top-left corner of the piece's current bounding box as the anchor
3. Checking whether the new rotation fits (in-bounds, no overlaps)
4. Applying the new rotation, or silently restoring the original if it doesn't fit

---

## 2. Remove a placed piece by dragging it back to the tray

**File:** `scripts/minigames/tangram.gd`

`_try_drop_drag` now checks whether the drop position is inside `_left_panel.get_global_rect()` before trying the grid. If a piece that came from the grid is dropped over the tray, the drag simply ends without restoring — the piece was already erased from the grid when the drag started, so it effectively returns to the library.

`_left_panel: Control` was added as a class variable and assigned in `_build_ui`.

---

## 3. Drag pieces from the library directly onto the board

**File:** `scripts/minigames/tangram.gd`

Tray buttons now connect `gui_input` instead of `pressed`, so mouse-down immediately starts a drag rather than waiting for mouse-up. `_on_piece_btn_gui_input` handles this:

- Sets `_drag_origin_cells` to empty (the "from library" flag)
- Creates the drag visual at the mouse position
- If the drag is dropped on the grid, `_attempt_place_drag` places it normally
- If dropped back on the tray (quick tap), `_try_drop_drag` falls back to click-to-select behaviour

---

## 4. Tray UI: piece image instead of letter

**File:** `scripts/minigames/tangram.gd`

The tray was redesigned from `[Letter Button] [Preview Control]` to a single `Button` per piece with the coloured piece squares drawn as children directly on the button. Advantages:

- The whole button area is the drag source (more natural to grab)
- Placed pieces dim to 35% opacity via `btn.modulate` rather than a separate style swap
- `piece_preview_containers` array was removed; `piece_buttons` now serves both roles

---

## 5. Rotation bug fix: library drag picks up the tray's current rotation

**File:** `scripts/minigames/tangram.gd`

Added `_tray_rotations: Array[int]` — one entry per piece, initialised to 0 in `_build_ui` and reset in `_clear_board`.

Previously, dragging from the library always started at rotation 0, ignoring any rotation the piece preview was already showing.

- `_on_piece_btn_gui_input` now reads `_tray_rotations[piece_index]` as the drag's starting rotation
- Pressing R while a piece is selected writes back to `_tray_rotations[selected_piece_index]`
- The click-to-select fallback in `_try_drop_drag` restores `selected_rotation` from `_tray_rotations`
- `_clear_board` resets all entries to 0 and redraws tray previews at rotation 0

---

## 6. Celebratory win screen for all mini-games

**File:** `scripts/minigames/mini_game_base.gd`

`_complete(success)` was changed to branch on the result:

- **`_complete(false)`** — unchanged: emits `mini_game_completed(false)` and calls `queue_free()` immediately (quit button, failure states)
- **`_complete(true)`** — now calls `_show_win_screen()` instead of closing immediately

`_show_win_screen()` builds an overlay in code:

1. Full-rect `ColorRect` with `MOUSE_FILTER_STOP` — freezes the game underneath
2. `CenterContainer` → `PanelContainer` (dark background, gold border) centred on screen
3. Contents: gold star row, large "YOU WIN!" label, "Congratulations!" subtext, green "Continue" button
4. Continue button lambda: emits `mini_game_completed(true)` then calls `queue_free()`

Because every mini-game inherits `_complete` from the base class, all 13 mini-games gain the win screen without any per-game changes.
