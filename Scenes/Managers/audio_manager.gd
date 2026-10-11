# This script is an autoload, that can be accessed from any other script!

extends Node

@onready var jump_sfx = $JumpSfx
@onready var coin_pickup_sfx = $CoinPickup
@onready var death_sfx = $DeathSfx
@onready var respawn_sfx = $RespawnSfx
@onready var level_complete_sfx = $LevelCompleteSfx

# Extra sound effects for The Last Knight (Assets/Sound/sfx_*.ogg)
const SFX = {
	"jump": "res://Assets/Sound/sfx_jump.ogg",
	"jump_high": "res://Assets/Sound/sfx_jump-high.ogg",
	"coin": "res://Assets/Sound/sfx_coin.ogg",
	"gem": "res://Assets/Sound/sfx_gem.ogg",
	"hurt": "res://Assets/Sound/sfx_hurt.ogg",
	"magic": "res://Assets/Sound/sfx_magic.ogg",
	"select": "res://Assets/Sound/sfx_select.ogg",
	"slash": "res://Assets/Sound/sfx_throw.ogg",
	"stomp": "res://Assets/Sound/sfx_bump.ogg",
	"vanish": "res://Assets/Sound/sfx_disappear.ogg",
	"explosion": "res://Assets/Sound/FX/explosion.wav",
}

var _players := {}

func _ready() -> void:
	for key in SFX:
		var p := AudioStreamPlayer.new()
		p.stream = load(SFX[key])
		p.bus = &"sfx"
		p.max_polyphony = 4
		add_child(p)
		_players[key] = p

# AudioManager.play("coin")
func play(key: String, pitch_random := 0.0) -> void:
	if not _players.has(key):
		return
	var p: AudioStreamPlayer = _players[key]
	p.pitch_scale = 1.0 + randf_range(-pitch_random, pitch_random)
	p.play()
