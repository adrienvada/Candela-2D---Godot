-- ===========================================================================
-- PE2.3 (2026-09-10) — les CONDITIONS du match voyagent avec le rapport
-- ===========================================================================
--
-- Jusqu'ici la base disait le RÉSULTAT d'un match et rien de ce qu'il avait
-- coûté à la machine qui l'a joué. Depuis le schéma 5 du journal local
-- (`conditions_de_match.gd`), chaque match archive sa cadence par image
-- (médiane, 1 % bas, pire image), son lien (RTT) et sa machine (système, carte
-- graphique, pilote, fenêtre) — mais chez le joueur. Décision d'Adrien du
-- 2026-09-10 : ces conditions remontent avec le rapport des matchs EN LIGNE,
-- amicaux et classés, pour qu'un relevé de cadence arrive ici sans qu'on ait à
-- le demander à un testeur. L'écran scindé et l'entraînement ne rapportent
-- rien et n'en envoient donc pas.
--
-- Une colonne `jsonb` plutôt que vingt colonnes : la forme du relevé est celle
-- du jeu, versionnée par la clé `version` du bloc, et une clé de plus côté jeu
-- ne demande aucune migration. La vue `conditions_de_match`, plus bas, aplatit
-- ce qu'on lit le plus souvent.
--
-- ⚠️ Jamais un motif de refus. L'Edge Function passe le bloc au tamis
-- (`parseConditions`) ; ici, seconde barrière : un objet, ou NULL. Le match a été
-- joué et c'est le rapport qui fait foi — un relevé mal formé ne doit jamais
-- faire perdre un match au classement (même arbitrage que le format inconnu
-- ramené à BO1, et que la nature illisible ramenée à amical).

alter table public.match_reports
    add column conditions jsonb;

comment on column public.match_reports.conditions is
    'PE2.3 — cadence par image (fps_median, fps_1pc_bas, pire_image_ms…), lien (rtt_moyen_ms) et machine (bloc machine : os, gpu, gpu_pilote, fenetre…) du RAPPORTEUR, tels que conditions_de_match.gd les relève. NULL : client d''avant PE2.3, ou rien à garder. Jamais un motif de refus du rapport.';


-- Même geste que la migration `match_kind` : on SUPPRIME l'ancienne signature au
-- lieu d'en ajouter une. Deux fonctions du même nom ne se départageraient que
-- sur les clés du corps de requête, et un client d'une version antérieure
-- continuerait d'appeler l'ancienne sans que rien ne le signale.
drop function if exists public.report_match(text, text, text, boolean, numeric, text, text, text, text, text);


-- `p_conditions` est en dernier et porte un défaut, pour la même raison de
-- déploiement que `p_kind` : la migration et la fonction Edge ne partent pas
-- d'un seul geste, et pendant l'intervalle l'ancien code appelle encore sans
-- conditions. Le défaut lui évite d'échouer.
create function public.report_match(
    p_puid text,
    p_match_id text,
    p_outcome text,
    p_forfeit boolean,
    p_duration numeric,
    p_map text,
    p_weapon_self text,
    p_weapon_opponent text,
    p_format text,
    p_kind text default null,
    p_conditions jsonb default null
)
returns setof public.match_reports
language plpgsql
security definer
set search_path = public
as $$
declare
    player_id uuid;
    existing public.match_reports;
    kind_value public.match_kind;
    conditions_value jsonb;
begin
    -- Règle 1, seconde barrière. L'Edge Function normalise déjà, mais un appel
    -- direct ne doit pas pouvoir classer un match par inadvertance.
    --
    -- Le cast `p_kind::public.match_kind` est écarté volontairement : sur un mot
    -- inconnu il lèverait 22P02 et FERAIT PERDRE le rapport, alors que c'est le
    -- rapport qui fait foi. Un mot inconnu vaut donc amical, et le match reste
    -- écrit — même arbitrage que le format inconnu ramené à BO1.
    kind_value := case
        when p_kind = 'ranked' then 'ranked'::public.match_kind
        else 'friendly'::public.match_kind
    end;

    -- Un objet, ou rien. Un tableau, un scalaire ou un bloc de plus de 8 Ko —
    -- aucun relevé honnête n'en approche le dixième — vaut NULL : le rapport,
    -- lui, s'écrit quand même.
    conditions_value := case
        when p_conditions is not null
             and jsonb_typeof(p_conditions) = 'object'
             and pg_column_size(p_conditions) <= 8192 then p_conditions
        else null
    end;

    select id into player_id from public.players where puid = p_puid;
    if not found then
        -- Le classement ne connaît pas ce PUID : il ne s'est jamais identifié.
        return;
    end if;

    select * into existing from public.match_reports
        where match_id = p_match_id and reporter = player_id;
    if found then
        -- Déjà rapporté. On rend l'existant tel quel : un rapport ne se corrige
        -- pas — ni son issue, ni sa nature, ni ses conditions —, sinon il
        -- suffirait de renvoyer pour changer l'une ou l'autre.
        return next existing;
        return;
    end if;

    -- Un match oppose deux joueurs. Sans ce garde-fou, quiconque devine un
    -- identifiant de match pourrait y ajouter son propre récit et brouiller
    -- l'appariement.
    if (select count(distinct reporter) from public.match_reports
            where match_id = p_match_id) >= 2 then
        return;
    end if;

    insert into public.match_reports (
        match_id, reporter, outcome, forfeit,
        duration_s, map_id, weapon_self, weapon_opponent, format, kind, conditions)
    values (
        p_match_id, player_id, p_outcome::public.outcome, coalesce(p_forfeit, false),
        p_duration, p_map, coalesce(p_weapon_self, ''), coalesce(p_weapon_opponent, ''),
        coalesce(p_format, 'BO1'), kind_value, conditions_value)
    returning * into existing;

    -- Le joueur vient de jouer : c'est aussi une preuve de vie.
    update public.players set seen_at = now() where id = player_id;

    return next existing;
    return;
end;
$$;

revoke all on function public.report_match(text, text, text, boolean, numeric, text, text, text, text, text, jsonb)
    from public, anon, authenticated;
grant execute on function public.report_match(text, text, text, boolean, numeric, text, text, text, text, text, jsonb)
    to service_role;


-- ---------------------------------------------------------------------------
-- LA VUE : ce qu'on lit dans l'éditeur SQL sans écrire de `->>`
-- ---------------------------------------------------------------------------
-- Une ligne par rapport qui porte des conditions. Les clés absentes rendent
-- NULL, jamais zéro : un `vram_mo` à 0 est un pilote qui ne compte pas, un
-- `vram_mo` NULL est un client qui n'a pas envoyé la clé.
create view public.conditions_de_match as
select
    r.match_id,
    r.reporter,
    r.kind,
    r.reported_at,
    r.outcome,
    r.duration_s,
    r.map_id,
    r.conditions->'machine'->>'version'   as version_jeu,
    r.conditions->'machine'->>'os'        as os,
    r.conditions->'machine'->>'os_version' as os_version,
    r.conditions->'machine'->>'cpu'       as cpu,
    r.conditions->'machine'->>'gpu'       as gpu,
    r.conditions->'machine'->>'gpu_pilote' as gpu_pilote,
    r.conditions->'machine'->>'rendu'     as rendu,
    r.conditions->'machine'->>'fenetre'   as fenetre,
    (r.conditions->'machine'->>'plein_ecran')::boolean as plein_ecran,
    (r.conditions->'machine'->>'vram_mo')::numeric     as vram_mo,
    round((r.conditions->>'images')::numeric)::integer as images,
    (r.conditions->>'duree_s')::numeric        as duree_relevee_s,
    (r.conditions->>'fps_moyen')::numeric      as fps_moyen,
    (r.conditions->>'fps_median')::numeric     as fps_median,
    (r.conditions->>'fps_1pc_bas')::numeric    as fps_1pc_bas,
    (r.conditions->>'pire_image_ms')::numeric  as pire_image_ms,
    round((r.conditions->>'trous')::numeric)::integer  as trous,
    (r.conditions->>'rtt_moyen_ms')::numeric   as rtt_moyen_ms,
    (r.conditions->>'rtt_max_ms')::numeric     as rtt_max_ms
from public.match_reports r
where r.conditions is not null;

-- Comme `matches` et `leaderboard` : la vue n'élargit aucun droit.
alter view public.conditions_de_match set (security_invoker = on);

comment on view public.conditions_de_match is
    'PE2.3 — les conditions de chaque rapport de match, aplaties : une ligne par rapporteur. Exemple de lecture : select gpu, count(*), percentile_cont(0.5) within group (order by fps_1pc_bas) from conditions_de_match group by gpu order by 2 desc;';

revoke all on public.conditions_de_match from anon, authenticated;
grant select on public.conditions_de_match to service_role;

notify pgrst, 'reload schema';
