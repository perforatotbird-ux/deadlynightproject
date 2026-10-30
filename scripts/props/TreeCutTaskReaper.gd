extends Node
# Dispose jobs from unloaded trees without stalling the next scene's main thread.
var task_id: int = -1
var job: RefCounted
func _process(_delta: float) -> void:
	if task_id >= 0 and WorkerThreadPool.is_task_completed(task_id):
		WorkerThreadPool.wait_for_task_completion(task_id)
		job = null
		queue_free()
