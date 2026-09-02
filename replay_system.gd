extends Node

signal replay_spawn_bullet(shooter_id: int, pos: Vector2, rot: float, weapon: WeaponData, fatal: bool)

var recording: bool = false
var playing_back: bool = false
var playback_index: float = 0.0
var freeze_time_remaining: float = 0.0
var snapshots: Array = []

## Cadence d'enregistrement, volontairement découplée de la cadence d'image.
##
## Le tampon est dimensionné en NOMBRE d'instantanés : enregistrer une image
## sur deux ou toutes les images change donc la DURÉE couverte. Depuis le
## déplafonnement des fps, une machine à 490 images/s ne gardait plus que
## 0,9 seconde de partie là où une machine à 60 en gardait 7,5 — le tir fatal
## était purgé avant même la fin de la manche, et la killcam ne montrait plus
## que des déplacements. Pire : la fenêtre différait d'une machine à l'autre.
##
## Enregistrer à cadence fixe rend la killcam identique partout, et laisse
## intacte toute la logique de relecture, qui raisonne en images de 1/60 s.
const RECORD_HZ := 60.0
const RECORD_PERIOD := 1.0 / RECORD_HZ
var _record_accum: float = 0.0

var max_snapshots: int = 450 # 7,5 s à la cadence d'enregistrement ci-dessus
var impact_frame: int = -1

## L'impact a-t-il été détecté pour la manche en cours.
##
## `impact_frame == -1` ne peut pas tenir ce rôle : l'indice glisse d'un cran à
## chaque image purgée du tampon, si bien qu'il **repasse par -1** une fois la
## mort sortie de la fenêtre de rejeu. La détection se réarmait alors sur un
## joueur toujours mort, replaçant l'impact au plafond du tampon — et
## recommençait sans fin, à ~450 images d'intervalle.
##
## Visible dans le banc `test_online_match` sous la forme d'un `[REPLAY] P2 died.
## impact_frame=450` répété indéfiniment ; la séquence de fin ne se terminait
## jamais. En jeu fenêtré l'enregistrement s'arrête plus tôt, ce qui masquait le
## défaut sans le corriger.
var _impact_seen: bool = false
var slow_mo_start_frame: int = -1
var bullet_events: Array = []
var last_played_frame: int = -1
var time_since_impact_real: float = 0.0

class Snapshot:
	var p1_pos: Vector2
	var p1_rot: float
	var p1_hp: float
	var p1_visible: bool
	var p1_light: bool
	var p1_flash: float
	var p2_pos: Vector2
	var p2_rot: float
	var p2_hp: float
	var p2_visible: bool
	var p2_light: bool
	var p2_flash: float
	
	var p1_weapon: WeaponData
	var p2_weapon: WeaponData

func start_recording():
	snapshots.clear()
	bullet_events.clear()
	recording = true
	playing_back = false
	_record_accum = 0.0
	
	impact_frame = -1
	slow_mo_start_frame = -1
	_impact_seen = false
	last_played_frame = -1
	time_since_impact_real = 0.0
	playback_index = 0.0

func stop_recording():
	recording = false

## `delta` pilote la cadence d'enregistrement. Le laisser à zéro enregistre à
## chaque appel — comportement d'avant, réservé aux tests.
func record_frame(p1: Node2D, p2: Node2D, bullets_node: Node2D, delta: float = 0.0):
	if not recording: return
	if delta > 0.0:
		_record_accum += delta
		if _record_accum < RECORD_PERIOD:
			return
		# Soustraire la période plutôt que remettre à zéro : une machine rapide
		# ne doit pas dériver sous la cadence visée.
		_record_accum -= RECORD_PERIOD

	var snap = Snapshot.new()
	if p1:
		snap.p1_pos = p1.global_position
		snap.p1_rot = p1.rotation
		snap.p1_hp = p1.hp
		
		# Detect impact
		if p1.hp <= 0 and not _impact_seen:
			_impact_seen = true
			impact_frame = snapshots.size()
			# Borné à zéro, comme le chemin nominal quinze lignes plus bas. Sans ça,
			# une mort survenue dans les quinze premières images rend une ancre
			# NÉGATIVE — et `start_playback` ne la rejette pas, puisque sa sentinelle
			# est -1 et non « négatif ». Le ralenti se calcule alors sur un vol de
			# balle qui déborde avant le début de l'enregistrement : sa progression
			# démarre déjà passé le seuil d'accélération, donc le ralenti n'a pas lieu.
			slow_mo_start_frame = maxi(0, impact_frame - 15) # repli
			for i in range(bullet_events.size() - 1, -1, -1):
				if bullet_events[i].shooter == 1: # P2 is the killer
					slow_mo_start_frame = max(0, bullet_events[i].frame - 1)
					break
			print("[REPLAY] P1 died. impact_frame=", impact_frame, " slow_mo_start_frame=", slow_mo_start_frame)
			
		snap.p1_visible = p1.visual.visible
		snap.p1_light = p1.flashlight_on
		snap.p1_flash = p1.get_node("MuzzleFlash").energy if p1.get_node("MuzzleFlash").enabled else 0.0
		snap.p1_weapon = p1.current_weapon
	
	if p2:
		snap.p2_pos = p2.global_position
		snap.p2_rot = p2.rotation
		snap.p2_hp = p2.hp
		
		# Detect impact
		if p2.hp <= 0 and not _impact_seen:
			_impact_seen = true
			impact_frame = snapshots.size()
			# Borné à zéro, comme le chemin nominal quinze lignes plus bas. Sans ça,
			# une mort survenue dans les quinze premières images rend une ancre
			# NÉGATIVE — et `start_playback` ne la rejette pas, puisque sa sentinelle
			# est -1 et non « négatif ». Le ralenti se calcule alors sur un vol de
			# balle qui déborde avant le début de l'enregistrement : sa progression
			# démarre déjà passé le seuil d'accélération, donc le ralenti n'a pas lieu.
			slow_mo_start_frame = maxi(0, impact_frame - 15) # repli
			for i in range(bullet_events.size() - 1, -1, -1):
				if bullet_events[i].shooter == 0: # P1 is the killer
					slow_mo_start_frame = max(0, bullet_events[i].frame - 1)
					break
			print("[REPLAY] P2 died. impact_frame=", impact_frame, " slow_mo_start_frame=", slow_mo_start_frame)
			
		snap.p2_visible = p2.visual.visible
		snap.p2_light = p2.flashlight_on
		snap.p2_flash = p2.get_node("MuzzleFlash").energy if p2.get_node("MuzzleFlash").enabled else 0.0
		snap.p2_weapon = p2.current_weapon
		
	snapshots.append(snap)
	if snapshots.size() > max_snapshots:
		snapshots.pop_front()
		# Arrêt à 0, et non à -1 : laisser l'indice continuer de descendre le fait
		# repasser par la sentinelle « aucun impact », puis devenir négatif — donc
		# servir d'ancre de rejeu négative. Quand la mort sort de la fenêtre, la
		# plus vieille image retenue est la meilleure approximation qui reste.
		if impact_frame > 0:
			impact_frame -= 1
		if slow_mo_start_frame > 0:
			slow_mo_start_frame -= 1
		for ev in bullet_events:
			ev.frame -= 1
		var new_events = []
		for ev in bullet_events:
			if ev.frame >= 0:
				new_events.append(ev)
		bullet_events = new_events

func record_bullet_fired(shooter_id: int, pos: Vector2, rot: float, weapon: WeaponData):
	if recording:
		bullet_events.append({
			"frame": snapshots.size(),
			"shooter": shooter_id,
			"pos": pos,
			"rot": rot,
			"weapon": weapon
		})

## V6.2 — d'où est parti le coup fatal, et où il a touché.
##
## Rend `[origine, impact]`, ou un tableau vide quand l'enregistrement ne permet
## pas de le dire — mort par chrono, tir sorti de la fenêtre, impact inconnu.
## **Vide plutôt qu'approximatif** : une trajectoire fausse enseignerait une
## leçon fausse, ce qui est pire que de ne rien enseigner.
##
## La victime est celle dont les points de vie sont tombés à l'image d'impact ;
## le tueur est l'autre. On remonte alors ses tirs jusqu'au dernier qui précède
## l'impact — c'est la même règle que celle qui fixe le départ du ralenti, et
## elle doit le rester : deux façons de désigner le tir fatal finiraient par
## désigner deux tirs différents.
func trajectoire_fatale() -> PackedVector2Array:
	var i := index_du_tir_fatal()
	if i < 0:
		return PackedVector2Array()
	var snap = snapshots[impact_frame]
	var impact: Vector2 = snap.p1_pos if snap.p1_hp <= 0.0 else snap.p2_pos
	return PackedVector2Array([bullet_events[i]["pos"], impact])


## Tout ce qu'il faut pour relever le tir fatal. Vide s'il n'y en a pas.
##
## ⚠️ **Le relevé DA4.6 a besoin de l'angle RÉEL du tir, et pas seulement de ses
## deux bouts.** Ce qu'il montre est l'écart entre la trajectoire suivie et celle
## qui aurait fait le maximum de dégâts : sans `rot`, l'écart ne se calcule pas,
## et le relevé retomberait à coter une distance de tir — ce qu'Adrien a
## justement écarté le 2026-08-27.
##
## Une seule fonction pour tout donner, plutôt que trois accesseurs : le relevé
## et la trajectoire doivent parler du **même** tir, et trois appels séparés,
## c'est trois occasions de n'en désigner pas le même.
func releve_du_tir_fatal() -> Dictionary:
	var i := index_du_tir_fatal()
	if i < 0:
		return {}
	var snap = snapshots[impact_frame]
	var ev: Dictionary = bullet_events[i]
	return {
		"origine": ev["pos"],
		"cible": snap.p1_pos if snap.p1_hp <= 0.0 else snap.p2_pos,
		"angle": ev["rot"],
		"arme": ev["weapon"],
	}


## L'indice, dans `bullet_events`, du tir qui a tué. `-1` s'il n'y en a pas.
##
## ⚠️ **Extrait de `trajectoire_fatale()` plutôt que réécrit à côté**, et le
## commentaire ci-dessus disait déjà pourquoi : *deux façons de désigner le tir
## fatal finiraient par désigner deux tirs différents*. Le relevé DA4.6 avait
## besoin de savoir QUEL tir, pas seulement d'où à où — la tentation était
## d'ajouter une seconde boucle qui remonte les tirs. Elle aurait été juste le
## jour de son écriture.
##
## La victime est celle dont les points de vie sont tombés à l'image d'impact ;
## le tueur est l'autre. On remonte alors ses tirs jusqu'au dernier qui précède
## l'impact — **le dernier tir tout court ne convient pas** : un tir de la
## victime juste avant sa mort n'est pas le coup fatal, et
## `tools/test_rejeu.gd` tient cette distinction depuis V6.1.
func index_du_tir_fatal() -> int:
	if impact_frame < 0 or impact_frame >= snapshots.size():
		return -1
	var snap = snapshots[impact_frame]
	var victime_p1: bool = snap.p1_hp <= 0.0
	if not victime_p1 and snap.p2_hp > 0.0:
		return -1
	var tueur := 1 if victime_p1 else 0
	for i in range(bullet_events.size() - 1, -1, -1):
		var ev: Dictionary = bullet_events[i]
		if int(ev["shooter"]) == tueur and int(ev["frame"]) <= impact_frame:
			return i
	return -1

## DA4.6 — durée du pré-tracé, en secondes de temps RÉEL.
##
## **Avant que le ralenti reprenne, la trajectoire se dessine.** Comme l'analyse
## d'une action de football : on retrace le trajet, puis on rejoue le geste et
## l'on voit le ballon suivre la ligne annoncée. Un tracé qui suit la balle
## *constate* ; un tracé qui la précède **annonce**, et l'action devient une
## vérification.
##
## Deux temps, pris à la charte plutôt qu'inventés : `D_LONG` pour la pousse du
## trait, `D_MOYEN` pour le temps de lecture avant que ça reparte.
const PRETRACE_POUSSE := 0.30
const PRETRACE_LECTURE := 0.18

## ⚠️ **Le monde rampe, il ne s'arrête pas.** `Engine.time_scale = 0` gèlerait
## bien l'action — et gèlerait aussi le `delta` qui fait avancer le pré-tracé,
## puisque celui-ci arrive déjà multiplié par l'échelle. Le compte à rebours ne
## descendrait jamais et la killcam resterait suspendue pour toujours. À 0,05, le
## temps réel se retrouve par division et l'action est immobile à l'œil.
const PRETRACE_ECHELLE := 0.05

## Progression du pré-tracé, de 0 à 1. Vaut 1 dès qu'il est terminé.
var pretrace_t: float = 0.0
var _pretrace_reste: float = -1.0
var _pretrace_fait: bool = false

## Les trois moments du pré-tracé.
##
## ⚠️ **Trois, et pas deux — un booléen a déjà menti ici.** Le premier jet
## exposait `pretrace_en_cours()`, qui répond « non » aussi bien AVANT
## qu'APRÈS. L'appelant prenait donc la branche « c'est fini » dès la première
## image de la killcam et posait la ligne **entière**, trois secondes trop tôt ;
## le pré-tracé la redessinait ensuite au bon moment. Relevé par Adrien à
## l'écran le 2026-08-27 — *« il est tracé dès le début de la killcam, puis se
## redessine ensuite »*.
##
## **Un état à trois valeurs ne se range pas dans un booléen**, et le défaut
## n'est pas que l'appelant se soit trompé : c'est que la question posée n'avait
## pas assez de réponses. L'énumération rend l'oubli impossible plutôt
## qu'improbable.
enum Pretrace { AVANT, PENDANT, APRES }

## Où en est le pré-tracé. `game_state` s'y branche pour dessiner le relevé.
func pretrace_etat() -> Pretrace:
	if _pretrace_fait:
		return Pretrace.APRES
	if _pretrace_reste > 0.0:
		return Pretrace.PENDANT
	return Pretrace.AVANT


## Nombre d'images montrées avant l'impact — trois secondes de contexte.
const PRE_IMPACT_FRAMES := 180.0
## Marge devant le tir fatal, pour qu'on voie partir la balle et non la voir
## déjà en vol.
const PRE_SHOT_MARGIN := 30.0

func start_playback():
	if snapshots.is_empty(): return
	recording = false
	playing_back = true

	# La fenêtre se cale sur l'impact, jamais sur la fin de l'enregistrement :
	# celui-ci continue après la mort, le temps de capter le sang et la
	# réaction. Calée sur la fin, elle laissait le tir fatal hors champ — la
	# killcam montrait la mort sans la balle qui l'avait causée.
	var anchor := float(impact_frame) if impact_frame != -1 else float(snapshots.size())
	var start_frame := anchor - PRE_IMPACT_FRAMES
	if slow_mo_start_frame != -1:
		# Un tir parti d'encore plus loin (arbalète lente, longue trajectoire)
		# doit rester visible : c'est lui le sujet de la séquence.
		start_frame = minf(start_frame, float(slow_mo_start_frame) - PRE_SHOT_MARGIN)

	playback_index = maxf(0.0, start_frame)
	last_played_frame = floori(playback_index) - 1
	freeze_time_remaining = 2.0
	time_since_impact_real = 0.0
	pretrace_t = 0.0
	_pretrace_reste = -1.0
	_pretrace_fait = false

func get_next_frame(delta: float):
	if not playing_back or snapshots.is_empty(): return null
	
	var idx1 = floori(playback_index)
	var idx2 = mini(idx1 + 1, snapshots.size() - 1)
	var t = playback_index - idx1
	
	var unscaled_delta = delta / Engine.time_scale if Engine.time_scale > 0 else delta

	# DA4.6 — le pré-tracé, juste avant que le ralenti commence.
	#
	# ⚠️ **On n'avance PAS `playback_index` pendant ce temps.** Les joueurs sont
	# posés depuis l'instantané courant : ne pas bouger l'indice les fige
	# exactement, sans avoir à les toucher. Seul le trait avance.
	if not _pretrace_fait and impact_frame != -1 and slow_mo_start_frame != -1 \
			and idx1 >= slow_mo_start_frame and idx1 < impact_frame:
		if _pretrace_reste < 0.0:
			_pretrace_reste = PRETRACE_POUSSE + PRETRACE_LECTURE
		_pretrace_reste -= unscaled_delta
		var ecoule := (PRETRACE_POUSSE + PRETRACE_LECTURE) - _pretrace_reste
		pretrace_t = clampf(ecoule / PRETRACE_POUSSE, 0.0, 1.0)
		if _pretrace_reste > 0.0:
			Engine.time_scale = PRETRACE_ECHELLE
			var fige = Snapshot.new()
			_melanger(fige, snapshots[idx1], snapshots[idx2], t)
			return fige
		_pretrace_fait = true
		pretrace_t = 1.0

	if idx1 >= snapshots.size() - 1:
		idx1 = snapshots.size() - 1
		idx2 = idx1
		t = 0.0
		# Only fallback to freeze_time if we haven't stopped via impact timer
		if freeze_time_remaining > 0:
			freeze_time_remaining -= unscaled_delta
		else:
			playing_back = false
			Engine.time_scale = 1.0 # Ensure it's reset
			return null
		
	# Determine playback speed
	var target_time_scale = 1.0
	
	if impact_frame != -1 and slow_mo_start_frame != -1:
		if idx1 >= slow_mo_start_frame and idx1 < impact_frame:
			# Calculate how many frames the bullet is in the air
			var travel_frames = max(1.0, float(impact_frame - slow_mo_start_frame))
			var frames_elapsed = (float(idx1 - slow_mo_start_frame) + t)
			
			var progress = clamp(frames_elapsed / travel_frames, 0.0, 1.0)
			
			# We want it to be very slow at the start, and smoothly accelerate to 1.0 right before impact
			# Using a smooth bezier-like curve for the acceleration
			var slow_scale = clamp(travel_frames / (5.0 * 60.0), 0.005, 1.0)
			
			# Smoothstep (Hermite interpolation) for a fluid bezier feel
			var ease_progress = progress * progress * (3.0 - 2.0 * progress)
			
			# Extreme slow mo at start (ease_progress ~ 0), normal speed at impact (ease_progress ~ 1)
			# We keep it slow for the first 60% of the travel, then accelerate
			if progress < 0.6:
				target_time_scale = slow_scale
			else:
				var accel_progress = (progress - 0.6) / 0.4
				accel_progress = accel_progress * accel_progress * (3.0 - 2.0 * accel_progress)
				target_time_scale = lerp(slow_scale, 1.0, accel_progress)
				
		elif idx1 >= impact_frame:
			time_since_impact_real += unscaled_delta
			if time_since_impact_real < 0.6:
				# Extremely slow for the first 0.6 seconds after impact
				target_time_scale = 0.03
			elif time_since_impact_real < 1.0:
				# Sudden rapid acceleration over 0.4 seconds
				var t_accel = clamp((time_since_impact_real - 0.6) / 0.4, 0.0, 1.0)
				# Very smooth ease-in-out using Hermite/Bezier-like curve
				t_accel = t_accel * t_accel * (3.0 - 2.0 * t_accel)
				target_time_scale = lerp(0.03, 6.0, t_accel)
			else:
				# Stop playback exactly 1.0 second after the bullet hits
				playing_back = false
				Engine.time_scale = 1.0
				return null
			
	Engine.time_scale = target_time_scale
	
	# delta is already scaled by Engine.time_scale!
	# So we just advance by delta * 60.0, which naturally advances playback slowly.
	playback_index += delta * 60.0
	
	var current_frame = floori(playback_index)
	# DA4.6 — un seul tir porte le relevé coté : celui qui a tué. Une killcam
	# rejoue tout ce qui a été tiré dans la fenêtre ; coter chaque balle
	# empilerait des cotes sur des tirs manqués, et **ce qui compte partout ne
	# désigne plus rien**.
	var fatal := index_du_tir_fatal()
	for i in bullet_events.size():
		var ev: Dictionary = bullet_events[i]
		if ev.frame > last_played_frame and ev.frame <= current_frame:
			replay_spawn_bullet.emit(ev.shooter, ev.pos, ev.rot, ev.weapon,
				i == fatal)
	last_played_frame = current_frame
	
	# INTERPOLATE SNAPSHOTS for perfectly smooth slow motion
	var interp = Snapshot.new()
	_melanger(interp, snapshots[idx1], snapshots[idx2], t)
	return interp


## Pose dans `sortie` l'etat interpole entre deux instantanes.
##
## Extrait de `get_next_frame` pour que le pre-trace de DA4.6 puisse rendre
## exactement le meme etat sans avancer la lecture. Une seconde copie de ces
## quatorze lignes aurait derive au premier champ ajoute a `Snapshot`.
func _melanger(sortie: Snapshot, s1: Snapshot, s2: Snapshot, t: float) -> void:
	sortie.p1_pos = s1.p1_pos.lerp(s2.p1_pos, t)
	sortie.p1_rot = lerp_angle(s1.p1_rot, s2.p1_rot, t)
	sortie.p1_hp = s1.p1_hp
	sortie.p1_visible = s1.p1_visible
	sortie.p1_light = s1.p1_light
	sortie.p1_flash = lerp(s1.p1_flash, s2.p1_flash, t)

	sortie.p2_pos = s1.p2_pos.lerp(s2.p2_pos, t)
	sortie.p2_rot = lerp_angle(s1.p2_rot, s2.p2_rot, t)
	sortie.p2_hp = s1.p2_hp
	sortie.p2_visible = s1.p2_visible
	sortie.p2_light = s1.p2_light
	sortie.p2_flash = lerp(s1.p2_flash, s2.p2_flash, t)

	sortie.p1_weapon = s1.p1_weapon
	sortie.p2_weapon = s1.p2_weapon
