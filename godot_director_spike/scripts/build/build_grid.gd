extends RefCounted
## BuildGrid — pure grid state for the M1 build editor.
##
## The 5×4 backpack. Tracks placed items + cell occupancy and answers placement
## validity (every cell in-grid, no overlap). No rendering.
##
## Bag expansion (P1): container items placed in the grid call grant_cells() to
## add their extra cells to _extra. Those cells are treated identically to base-grid
## cells for placement purposes. Removing the container revokes its grant.

const BuildData := preload("build_data.gd")

const COLS := 5
const ROWS := 4

## Each placed entry: { iid, def_id, rot, anchor: Vector2i, cells: Array[Vector2i] }.
var placed: Array = []
var _occ: Dictionary = {}         # Vector2i cell -> iid
var _extra: Dictionary = {}       # Vector2i cell -> iid (the container that granted it)
var _container_grants: Dictionary = {}  # container iid -> Array[Vector2i] of granted cells

func in_grid(cell: Vector2i) -> bool:
	if cell.x >= 0 and cell.x < ROWS and cell.y >= 0 and cell.y < COLS:
		return true
	return _extra.has(cell)

## Valid if every footprint cell is in-grid and free (ignoring ignore_iid, so an
## item can be validity-checked against its own current cells when moving it).
func can_place(def: Dictionary, rot: int, anchor: Vector2i, ignore_iid := "") -> bool:
	for cell in BuildData.placed_cells(def, rot, anchor):
		if not in_grid(cell):
			return false
		var owner: String = _occ.get(cell, "")
		if owner != "" and owner != ignore_iid:
			return false
	return true

## Place an item; returns its placed entry, or {} if invalid.
## If the item is a container, its extra cells are granted immediately.
func place(iid: String, def_id: String, rot: int, anchor: Vector2i) -> Dictionary:
	var def := BuildData.get_def(def_id)
	if not can_place(def, rot, anchor):
		return {}
	var cells := BuildData.placed_cells(def, rot, anchor)
	var entry := {"iid": iid, "def_id": def_id, "rot": rot, "anchor": anchor, "cells": cells}
	placed.append(entry)
	for cell in cells:
		_occ[cell] = iid
	# Container: grant extra cells anchored to the bottom-right of its footprint.
	if def.get("kind", "") == "container":
		_grant_container(iid, def, rot, anchor)
	return entry

func remove(iid: String) -> void:
	# Revoke any container grant first.
	if _container_grants.has(iid):
		for cell in _container_grants[iid]:
			_extra.erase(cell)
		_container_grants.erase(iid)
	for cell in _occ.keys():
		if _occ[cell] == iid:
			_occ.erase(cell)
	placed = placed.filter(func(p): return p.iid != iid)

func item_at(cell: Vector2i) -> String:
	return _occ.get(cell, "")

func clear() -> void:
	placed.clear()
	_occ.clear()
	_extra.clear()
	_container_grants.clear()

## Total owned cell count: base grid + extra cells granted by containers.
func owned_cell_count() -> int:
	return ROWS * COLS + _extra.size()

## All extra cells granted by containers (for the grid view to render them).
func extra_cells() -> Array:
	return _extra.keys()

# ---- internals ---------------------------------------------------------------

## Grant extra cells for a container. Cells are appended below/right of the
## container's footprint along a new column starting at the first empty column
## past the base grid's right edge, offset by the container's row anchor.
func _grant_container(iid: String, def: Dictionary, rot: int, anchor: Vector2i) -> void:
	var extra_rows: int = int(def.get("extra_rows", 0))
	var extra_cols: int = int(def.get("extra_cols", 0))
	if extra_rows == 0 or extra_cols == 0:
		return
	# Find the rightmost occupied column among base cells and existing extras.
	var max_col := COLS - 1
	for cell in _extra.keys():
		if cell.y > max_col:
			max_col = cell.y
	var start_col := max_col + 1
	var granted: Array = []
	for dr in extra_rows:
		for dc in extra_cols:
			var cell := Vector2i(anchor.x + dr, start_col + dc)
			_extra[cell] = iid
			granted.append(cell)
	_container_grants[iid] = granted
