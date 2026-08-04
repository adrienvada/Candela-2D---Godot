## Expérience de la Mission B : un tick EOS supplémentaire par pas physique.
##
## EOSGRuntime n'appelle IEOS.tick() qu'une fois par image rendue. À 60 fps, le
## SDK ne pompe donc le réseau que toutes les 16 ms, ce qui se paie sur le RTT.
## Ce nœud sert à mesurer ce que rapporte un tick de plus — il n'est branché que
## par le banc d'essai, jamais par le jeu.
extends Node

func _physics_process(_delta: float) -> void:
	IEOS.tick()
