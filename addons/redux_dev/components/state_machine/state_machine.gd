@icon("uid://c62fk8rmsd0do")
@tool
class_name StateMachine
extends Node

@export_group("Internal", "__")
@export var __root_node_path: NodePath
@export var __last_editor_position: Vector2
@export var __last_editor_zoom: float
@export var __states: Dictionary[StringName, State] # [State Name, State]
@export var __annotations: Dictionary[String, Dictionary] # [Annotation UUID, {text, pos}]
@export var __transitions: Dictionary[String, StateTransition]  # uuid -> resource
