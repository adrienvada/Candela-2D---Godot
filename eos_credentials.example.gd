extends Node
# Modèle des identifiants Epic Online Services.
#
# Recopier ce fichier en `res://eos_credentials.gd` (ignoré par git) et y coller
# les valeurs du portail Epic Developer. Sans ce fichier, le jeu démarre
# normalement : EOS reste à l'état « non configuré » et seul le transport ENet
# (LAN/debug) est disponible.
#
# Le CLIENT_SECRET et l'ENCRYPTION_KEY sont des secrets : ils ne doivent jamais
# être commités ni transmis par un canal public.

const PRODUCT_NAME := "Candela 2D"
const PRODUCT_VERSION := "1.0"
const PRODUCT_ID := ""
const SANDBOX_ID := ""
const DEPLOYMENT_ID := ""
const CLIENT_ID := ""
const CLIENT_SECRET := ""
const ENCRYPTION_KEY := ""
