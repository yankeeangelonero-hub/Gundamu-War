extends RefCounted
## BuildGrid — pure grid state for the M1 build editor.
##
## The 5×4 backpack. Tracks placed items + cell occupancy and answers placement
## validity (every cell in-grid, no overlap). No rendering. Bag-expansion is M2,
## so in M1 the whole grid is "owned" and placeable.

const BuildData := preload("build_data.gd")

const COLS := 5
const ROWS := 4

## Each placed entry: { iid, def_id, rot, anchor: Vector2i, cells: Array[Vector2i] }.
var placed: Array = []
var _occ: Dictionary = {}   # Vector2i cell -> iid

func in_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < ROWS and cell.y >= 0 and cell.y < COLS

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
func place(iid: String, def_id: String, rot: int, anchor: Vector2i) -> Dictionary:
	var def := BuildData.get_def(def_id)
	if not can_place(def, rot, anchor):
		return {}
	var cells := BuildData.placed_cells(def, rot, anchor)
	var entry := {"iid": iid, "def_id": def_id, "rot": rot, "anchor": anchor, "cells": cells}
	placed.append(entry)
	for cell in cells:
		_occ[cell] = iid
	return entry

func remove(iid: String) -> void:
	for cell in _occ.keys():
		if _occ[cell] == iid:
			_occ.erase(cell)
	placed = placed.filter(func(p): return p.iid != iid)

func item_at(cell: Vector2i) -> String:
	return _occ.get(cell, "")

func clear() -> void:
	placed.clear()
	_occ.clear()
