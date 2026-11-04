extends RefCounted
## Утилита для валидаторов: уводит CustomSetsStore.sets_dir в тестовый каталог,
## чтобы прогон не читал и не удалял медиа реальных наборов ребёнка.
## Парная к переопределению CustomSetsStore.save_path в каждом валидаторе.


## Запоминает текущий sets_dir, включает тестовый и чистит его остатки.
static func begin(test_dir: String) -> String:
	var saved := CustomSetsStore.sets_dir
	remove(test_dir)
	CustomSetsStore.sets_dir = test_dir
	return saved


## Возвращает боевой sets_dir и удаляет тестовый каталог со всем содержимым.
static func end(saved: String, test_dir: String) -> void:
	CustomSetsStore.sets_dir = saved
	remove(test_dir)


## Рекурсивно удаляет user://-каталог, если он существует.
static func remove(user_path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(user_path)
	var dir := DirAccess.open(abs_path)
	if dir == null:
		return
	for child: String in dir.get_directories():
		remove(user_path.path_join(child))
	for file_name: String in dir.get_files():
		DirAccess.remove_absolute(abs_path.path_join(file_name))
	DirAccess.remove_absolute(abs_path)
