extends Node2D

## Suite de verificación automatizada para Jefes de Dominio, TelegraphIndicator y Balas Alienígenas.

func _ready() -> void:
	print("=== INICIANDO TEST: TELEGRAFIADO Y BALÍSTICA EN JEFES DE DOMINIO ===")
	_test_boss_hermit_void()
	_test_boss_ash_clock()
	_test_boss_broken_mirror()
	_test_boss_overflow_vortex()
	_test_elite_herald_boss()
	print("=== TODOS LOS TESTS DE JEFES PASARON CON ÉXITO ===")
	get_tree().quit(0)

func _test_boss_hermit_void() -> void:
	print("1. Verificando BossHermitVoid (Ermitaño del Vacío)...")
	var boss: BossHermitVoid = BossHermitVoid.new()
	add_child(boss)
	assert(boss != null, "BossHermitVoid no pudo ser instanciado")
	assert(is_instance_valid(boss.telegraph_indicator), "BossHermitVoid debe poseer un TelegraphIndicator válido")
	boss._start_telegraph(0.2, Callable(func(): pass), TelegraphIndicator.TelegraphType.RING)
	assert(boss.is_telegraphing, "BossHermitVoid debe estar en estado is_telegraphing durante el aviso")
	boss.queue_free()
	print("   [OK] BossHermitVoid inicializado y telegrafiado verificado.")

func _test_boss_ash_clock() -> void:
	print("2. Verificando BossAshClock (Reloj de Cenizas)...")
	var boss: BossAshClock = BossAshClock.new()
	add_child(boss)
	assert(boss != null, "BossAshClock no pudo ser instanciado")
	assert(is_instance_valid(boss.telegraph_indicator), "BossAshClock debe poseer un TelegraphIndicator válido")
	boss._start_telegraph(0.2, Callable(func(): pass), TelegraphIndicator.TelegraphType.RING)
	assert(boss.is_telegraphing, "BossAshClock debe estar en estado is_telegraphing durante el aviso")
	boss.queue_free()
	print("   [OK] BossAshClock inicializado y telegrafiado verificado.")

func _test_boss_broken_mirror() -> void:
	print("3. Verificando BossBrokenMirror (Espejo Quebrado)...")
	var boss: BossBrokenMirror = BossBrokenMirror.new()
	add_child(boss)
	assert(boss != null, "BossBrokenMirror no pudo ser instanciado")
	assert(is_instance_valid(boss.telegraph_indicator), "BossBrokenMirror debe poseer un TelegraphIndicator válido")
	boss._start_telegraph(0.2, Callable(func(): pass), TelegraphIndicator.TelegraphType.CONE)
	assert(boss.is_telegraphing, "BossBrokenMirror debe estar en estado is_telegraphing durante el aviso")
	boss.queue_free()
	print("   [OK] BossBrokenMirror inicializado y telegrafiado verificado.")

func _test_boss_overflow_vortex() -> void:
	print("4. Verificando BossOverflowVortex (Vórtice del Desborde)...")
	var boss: BossOverflowVortex = BossOverflowVortex.new()
	add_child(boss)
	assert(boss != null, "BossOverflowVortex no pudo ser instanciado")
	assert(is_instance_valid(boss.telegraph_indicator), "BossOverflowVortex debe poseer un TelegraphIndicator válido")
	boss._start_telegraph(0.2, Callable(func(): pass), TelegraphIndicator.TelegraphType.RING)
	assert(boss.is_telegraphing, "BossOverflowVortex debe estar en estado is_telegraphing durante el aviso")
	boss.queue_free()
	print("   [OK] BossOverflowVortex inicializado y telegrafiado verificado.")

func _test_elite_herald_boss() -> void:
	print("5. Verificando EliteHeraldBoss (Heraldo de Dominio)...")
	var boss: EliteHeraldBoss = EliteHeraldBoss.new()
	add_child(boss)
	assert(boss != null, "EliteHeraldBoss no pudo ser instanciado")
	assert(is_instance_valid(boss.telegraph_indicator), "EliteHeraldBoss debe poseer un TelegraphIndicator válido")
	boss._start_herald_telegraph(TelegraphIndicator.TelegraphType.CONE, 0.2, Callable(func(): pass))
	assert(boss.is_telegraphing, "EliteHeraldBoss debe estar en estado is_telegraphing durante el aviso")
	boss.queue_free()
	print("   [OK] EliteHeraldBoss inicializado y telegrafiado verificado.")
