extends Node

signal freeze_requested(freeze_slow: float, freeze_time: float)

var camera: CustomCamera
var is_time_scale_locked: bool = false
