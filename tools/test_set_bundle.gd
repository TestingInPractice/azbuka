class_name TestSetBundle
extends Resource
## Тестовый набор, упакованный в один ресурс.
##
## Зачем: веб-экспорт не кладёт в PCK исходные .png и .wav (они считаются
## импортируемыми ресурсами), поэтому сидер в браузере не находил файлы.
## Ресурс с байтами — обычная зависимость скрипта, и экспорт её включает.
##
## Байты те же, что в tools/test_set_assets: PNG-карточки и WAV-озвучка.
## Ничего не декодируется при загрузке, чтобы не зависеть от импортёра.

@export var words: Dictionary = {}
@export var images: Dictionary = {}
@export var audios: Dictionary = {}
@export var audio_extensions: Dictionary = {}
