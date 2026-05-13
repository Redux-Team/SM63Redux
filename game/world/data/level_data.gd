# LevelData <- [LevelAreaData] <- [LevelLayerData] <- [LevelObjectData]
class_name LevelData
extends Resource

@export var author: String
@export_multiline var description: String
@export var areas: Array[LevelAreaData]
@export var scenarios: Array[LevelScenarioData]
