extends Node
class_name LetterCardContent
## Содержимое карточки: большая буква, картинка слова, подпись набора и
## сброс мини-игры. Отдельный компонент, чтобы экран не смешивал данные,
## вёрстку и обработку кнопок.

var _owner: Control
var _letter_label: Label
var _word_image: TextureRect
var _set_label: Label
var _word_game: LetterCardWordGame
var _reset_idle: Callable
var _letter_provider: Callable


func setup(
	owner: Control,
	word_game: LetterCardWordGame,
	reset_idle: Callable,
	letter_provider: Callable
) -> void:
	_owner = owner
	_letter_label = owner.get_node("%LetterLabel")
	_word_image = owner.get_node("%WordImage")
	_set_label = owner.get_node("%SetLabel")
	_word_game = word_game
	_reset_idle = reset_idle
	_letter_provider = letter_provider


func update() -> void:
	var letter: String = str(_letter_provider.call())
	_letter_label.text = letter + letter.to_lower()
	# Текстуру слова берём из SetRepository: он сам различает встроенный набор
	# (res://) и пользовательский (user://, через Image.load_from_file -
	# в веб-сборке у таких файлов нет импорта).
	var tex := SetRepository.get_word_texture(letter)
	if tex != null:
		_word_image.texture = tex
		_word_image.visible = true
		var vp: Vector2 = _owner.get_viewport_rect().size
		var img_w: float = vp.x * 0.5
		_word_image.custom_minimum_size = Vector2(
			img_w, img_w * float(tex.get_height()) / float(tex.get_width())
		)
	else:
		_word_image.texture = null
		_word_image.visible = false
	_update_set_label()
	_word_game.reset(letter)
	_reset_idle.call()


## Подпись активного набора. Та же логика, что на экране «Азбука»: имя есть
## только у пользовательского набора, а у встроенного и удалённого его нет.
func _update_set_label() -> void:
	var set_name := SetRepository.get_active_set_name()
	_set_label.visible = not set_name.is_empty()
	_set_label.text = ("Набор: " + set_name) if not set_name.is_empty() else ""
