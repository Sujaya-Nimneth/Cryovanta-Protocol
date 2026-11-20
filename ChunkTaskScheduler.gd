class_name ChunkTaskScheduler
extends Node

## Max-4 Worker Thread Scheduler with fixed-capacity ring buffer.
## Enforces rules.md §1: Max 4 background worker threads and zero steady-state heap allocations.

signal job_completed(job_id: int, result: Variant)

const MAX_CONCURRENT_WORKERS: int = 4
const BUFFER_CAPACITY: int = 64

const STATUS_EMPTY: int = 0
const STATUS_QUEUED: int = 1
const STATUS_RUNNING: int = 2
const STATUS_COMPLETED: int = 3
const STATUS_CANCELLED: int = 4

static var EMPTY_ARGS: Array = []
static var _worker_thread_ids: PackedInt64Array = PackedInt64Array([0, 0, 0, 0])

static func get_current_worker_index() -> int:
	var tid: int = OS.get_thread_caller_id()
	for i in MAX_CONCURRENT_WORKERS:
		if _worker_thread_ids[i] == tid: return i
	return 0
func get_worker_index() -> int: return get_current_worker_index()

var _mutex: Mutex = Mutex.new()
var _semaphore: Semaphore = Semaphore.new()
var _is_running: bool = false
var _active_workers: int = 0
var _workers_ready: int = 0
var _threads: Array[Thread] = []

var _job_ids: PackedInt64Array = PackedInt64Array()
var _job_status: PackedInt32Array = PackedInt32Array()
var _job_cancelled: PackedByteArray = PackedByteArray()
var _job_notified: PackedByteArray = PackedByteArray()
var _auto_reclaim: PackedByteArray = PackedByteArray()
var _slot_generation: PackedInt64Array = PackedInt64Array()
var _free_stack: PackedInt32Array = PackedInt32Array()
var _free_top: int = 0
var _queue: PackedInt32Array = PackedInt32Array()
var _queue_head: int = 0
var _queue_tail: int = 0
var _queue_count: int = 0
var _job_callables: Array[Callable] = []
var _job_args: Array = []
var _job_results: Array = []

func _init() -> void:
	_is_running = true; _free_top = BUFFER_CAPACITY
	_job_ids.resize(BUFFER_CAPACITY); _job_status.resize(BUFFER_CAPACITY); _job_cancelled.resize(BUFFER_CAPACITY)
	_job_notified.resize(BUFFER_CAPACITY); _auto_reclaim.resize(BUFFER_CAPACITY); _slot_generation.resize(BUFFER_CAPACITY)
	_free_stack.resize(BUFFER_CAPACITY); _queue.resize(BUFFER_CAPACITY); _job_callables.resize(BUFFER_CAPACITY)
	_job_args.resize(BUFFER_CAPACITY); _job_results.resize(BUFFER_CAPACITY); _threads.resize(MAX_CONCURRENT_WORKERS)
	for i in BUFFER_CAPACITY:
		_free_stack[i] = i; _slot_generation[i] = 1; _job_ids[i] = 0; _job_status[i] = STATUS_EMPTY
		_job_cancelled[i] = 0; _job_notified[i] = 0; _auto_reclaim[i] = 0; _job_callables[i] = Callable()
		_job_args[i] = EMPTY_ARGS; _job_results[i] = null
	for i in MAX_CONCURRENT_WORKERS:
		var thread: Thread = Thread.new(); _threads[i] = thread; thread.start(_worker_loop.bind(i))
	while true:
		_mutex.lock(); var r: int = _workers_ready; _mutex.unlock()
		if r == MAX_CONCURRENT_WORKERS: break
		OS.delay_usec(50)

func _notification(what: int) -> void: if what == NOTIFICATION_PREDELETE: shutdown()
func _process(_delta: float) -> void: poll()

func _worker_loop(worker_idx: int) -> void:
	_mutex.lock(); _worker_thread_ids[worker_idx] = OS.get_thread_caller_id(); _workers_ready += 1; _mutex.unlock()
	while true:
		_semaphore.wait()
		_mutex.lock()
		if not _is_running:
			_worker_thread_ids[worker_idx] = 0
			_mutex.unlock()
			break
		if _queue_count == 0:
			_mutex.unlock()
			continue
		var slot: int = _queue[_queue_head]
		_queue_head = (_queue_head + 1) % BUFFER_CAPACITY
		_queue_count -= 1
		if _job_cancelled[slot] != 0:
			_job_status[slot] = STATUS_CANCELLED
			_mutex.unlock()
			continue
		_job_status[slot] = STATUS_RUNNING
		_active_workers += 1
		var callable: Callable = _job_callables[slot]
		var args: Array = _job_args[slot]
		_mutex.unlock()
		var result: Variant = null
		if callable.is_valid():
			result = callable.call() if args.is_empty() else callable.callv(args)
		_mutex.lock()
		_active_workers -= 1
		if _job_cancelled[slot] != 0:
			_job_status[slot] = STATUS_CANCELLED
		else:
			_job_results[slot] = result
			_job_status[slot] = STATUS_COMPLETED
		_mutex.unlock()

func _reclaim_slot_unlocked(slot: int) -> void:
	_job_status[slot] = STATUS_EMPTY; _job_ids[slot] = 0; _job_callables[slot] = Callable()
	_job_args[slot] = EMPTY_ARGS; _job_results[slot] = null; _job_cancelled[slot] = 0; _job_notified[slot] = 0
	_auto_reclaim[slot] = 0; _free_stack[_free_top] = slot; _free_top += 1

func submit_job(callable: Callable, args: Array = []) -> int:
	if not callable.is_valid(): return -1
	_mutex.lock()
	if not _is_running or _free_top == 0:
		_mutex.unlock(); return -1
	_free_top -= 1
	var slot: int = _free_stack[_free_top]
	_slot_generation[slot] += 1
	var job_id: int = (_slot_generation[slot] << 6) | slot
	_job_ids[slot] = job_id; _job_callables[slot] = callable; _job_args[slot] = args; _job_results[slot] = null
	_job_status[slot] = STATUS_QUEUED; _job_cancelled[slot] = 0; _job_notified[slot] = 0; _auto_reclaim[slot] = 0
	_queue[_queue_tail] = slot
	_queue_tail = (_queue_tail + 1) % BUFFER_CAPACITY
	_queue_count += 1
	_semaphore.post()
	_mutex.unlock()
	return job_id

func cancel_job(job_id: int, auto_reclaim: bool = false) -> bool:
	if job_id <= 0: return false
	_mutex.lock()
	var slot: int = job_id & 63
	if _job_ids[slot] != job_id:
		_mutex.unlock(); return false
	var status: int = _job_status[slot]
	if status == STATUS_QUEUED or status == STATUS_RUNNING:
		_job_cancelled[slot] = 1
		if auto_reclaim: _auto_reclaim[slot] = 1
		if status == STATUS_QUEUED:
			_job_status[slot] = STATUS_CANCELLED
			for i in _queue_count:
				if _queue[(_queue_head + i) % BUFFER_CAPACITY] == slot:
					for j in range(i, _queue_count - 1):
						_queue[(_queue_head + j) % BUFFER_CAPACITY] = _queue[(_queue_head + j + 1) % BUFFER_CAPACITY]
					_queue_count -= 1
					_queue_tail = (_queue_head + _queue_count) % BUFFER_CAPACITY
					break
		_mutex.unlock(); return true
	_mutex.unlock(); return false

func _cancel_all_unlocked() -> void:
	while _queue_count > 0:
		var slot: int = _queue[_queue_head]
		_queue_head = (_queue_head + 1) % BUFFER_CAPACITY
		_queue_count -= 1
		_job_cancelled[slot] = 1; _job_status[slot] = STATUS_CANCELLED; _auto_reclaim[slot] = 1
	for i in BUFFER_CAPACITY:
		if _job_status[i] != STATUS_EMPTY:
			_job_cancelled[i] = 1; _auto_reclaim[i] = 1

func cancel_all_jobs() -> void:
	_mutex.lock(); _cancel_all_unlocked(); _mutex.unlock()

func is_job_completed(job_id: int) -> bool:
	if job_id <= 0: return false
	_mutex.lock()
	var slot: int = job_id & 63
	var done: bool = (_job_ids[slot] == job_id and (_job_status[slot] == STATUS_COMPLETED or _job_status[slot] == STATUS_CANCELLED))
	_mutex.unlock()
	return done

func get_job_result(job_id: int) -> Variant:
	if job_id <= 0: return null
	_mutex.lock()
	var slot: int = job_id & 63
	var res: Variant = _job_results[slot] if (_job_ids[slot] == job_id and _job_status[slot] == STATUS_COMPLETED) else null
	_mutex.unlock()
	return res

func reclaim_job(job_id: int) -> bool:
	if job_id <= 0: return false
	_mutex.lock()
	var slot: int = job_id & 63
	if _job_ids[slot] != job_id:
		_mutex.unlock(); return false
	var st: int = _job_status[slot]
	if st != STATUS_COMPLETED and st != STATUS_CANCELLED:
		_mutex.unlock(); return false
	_reclaim_slot_unlocked(slot)
	_mutex.unlock()
	return true

func reclaim_cancelled_jobs() -> int:
	_mutex.lock()
	var count: int = 0
	for i in BUFFER_CAPACITY:
		if _job_status[i] == STATUS_CANCELLED:
			_reclaim_slot_unlocked(i)
			count += 1
	_mutex.unlock()
	return count

func poll() -> void:
	_mutex.lock()
	for i in BUFFER_CAPACITY:
		if _job_status[i] == STATUS_COMPLETED:
			if _job_notified[i] == 0:
				_job_notified[i] = 1
				var jid: int = _job_ids[i]
				var res: Variant = _job_results[i]
				_mutex.unlock()
				job_completed.emit(jid, res)
				_mutex.lock()
			if _job_status[i] == STATUS_COMPLETED and _auto_reclaim[i] != 0:
				_reclaim_slot_unlocked(i)
		elif _job_status[i] == STATUS_CANCELLED and _auto_reclaim[i] != 0:
			_reclaim_slot_unlocked(i)
	_mutex.unlock()

func get_active_worker_count() -> int:
	_mutex.lock(); var count: int = _active_workers; _mutex.unlock(); return count
func get_worker_count() -> int: return MAX_CONCURRENT_WORKERS
func get_queue_count() -> int:
	_mutex.lock(); var count: int = _queue_count; _mutex.unlock(); return count
func get_available_slots() -> int:
	_mutex.lock(); var count: int = _free_top; _mutex.unlock(); return count
func is_running() -> bool:
	_mutex.lock(); var r: bool = _is_running; _mutex.unlock(); return r

func get_job_status(job_id: int) -> int:
	if job_id <= 0: return STATUS_EMPTY
	_mutex.lock()
	var slot: int = job_id & 63
	var s: int = _job_status[slot] if _job_ids[slot] == job_id else STATUS_EMPTY
	_mutex.unlock()
	return s

func shutdown() -> void:
	_mutex.lock()
	if not _is_running:
		_mutex.unlock(); return
	_is_running = false
	_cancel_all_unlocked()
	_mutex.unlock()
	for i in MAX_CONCURRENT_WORKERS: _semaphore.post()
	for thread in _threads: if thread != null and thread.is_started(): thread.wait_to_finish()
