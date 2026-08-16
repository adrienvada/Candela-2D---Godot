extends Node
# Modèle de configuration Supabase.
#
# Recopier ce fichier en `res://supabase_config.gd` (ignoré par git) et y
# coller les valeurs du tableau de bord Supabase.
#
# Sans ce fichier, le jeu démarre normalement : le classement reste à l'état
# « non configuré » et tout le reste fonctionne.
#
# --- Sur les clés ---------------------------------------------------------
# Ce projet utilise le NOUVEAU système de clés Supabase (publiable / secrète),
# et non l'ancien couple anon / service_role.
#
# PUBLISHABLE_KEY est conçue pour vivre dans le client : Supabase la déclare
# explicitement « safe to share publicly ». Sa sûreté repose entièrement sur
# la Row Level Security — tant qu'aucune politique RLS n'est en place, elle
# donne accès aux tables exposées. Elle reste donc hors de git jusqu'à ce que
# les politiques soient écrites.
#
# La clé SECRÈTE n'a rien à faire ici, ni dans aucun build. Elle ne vit que
# dans les variables d'environnement des Edge Functions, où Supabase l'injecte
# lui-même. Ne la copiez jamais dans le projet.

const PROJECT_URL := ""
const PUBLISHABLE_KEY := ""

## Informatif : sert aux messages de diagnostic, pas à la connexion.
const PROJECT_REF := ""
const REGION := ""
