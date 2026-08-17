-- Phase 8, étape 8.1 : séparer l'amical du classé.
--
-- **Correctif, pas fonctionnalité.** Rien ne distinguait un match amical d'un
-- match classé : `report_match` n'avait aucun paramètre pour le dire, et le rejeu
-- relisait « tous les matchs concordants » sans filtre. Le jour où un match
-- amical devient jouable — c'est imminent — il aurait alimenté l'ELO EN SILENCE,
-- et il aurait alors fallu deviner lesquels étaient amicaux : une information que
-- personne n'aurait écrite. Le défaut se corrige pour presque rien aujourd'hui,
-- parce qu'aucun match amical n'existe encore.
--
-- Trois règles gouvernent ce fichier, et aucune n'est un détail de forme :
--
--   1. **Le classé est le cas EXPLICITE, l'amical le défaut.** Champ absent,
--      null, mot inconnu : amical. Le sens de ce défaut est la moitié du
--      correctif — un bogue de client peut ainsi faire PERDRE des matchs au
--      classement, ce qu'un rejeu rattrape, jamais en AJOUTER, ce qui exigerait
--      de retrouver après coup une information jamais écrite.
--   2. **Les deux pairs doivent s'accorder sur la nature**, exactement comme ils
--      le font déjà sur l'issue. Un match déclaré classé par l'un et amical par
--      l'autre est discordant : il ne compte pour rien, au même titre que deux
--      récits qui se contredisent. C'est la vue `matches` qui le dit.
--   3. **Le passé se décide ici**, il ne se devine pas plus tard (voir l'update).


-- La nature du match. Type énuméré, sur le modèle de `arbitration` et de
-- `outcome` : le mot écrit en base est celui qui circule, et un troisième régime
-- — tournoi, matchs de placement — s'ajouterait au type sans toucher aux
-- colonnes ni aux vues.
create type public.match_kind as enum ('friendly', 'ranked');


-- Le défaut de la colonne EST la règle 1 : un insert qui oublie la nature écrit
-- un match amical, jamais un classé. C'est vrai de la fonction plus bas comme de
-- la main d'un administrateur.
alter table public.match_reports
    add column kind public.match_kind not null default 'friendly';

comment on column public.match_reports.kind is
    'Nature déclarée par CE rapporteur. Le classé est explicite, l''amical est le défaut : un oubli ne doit jamais ajouter un match au classement.';


-- ---------------------------------------------------------------------------
-- DÉCIDER DU PASSÉ
-- ---------------------------------------------------------------------------
-- Tout ce qui est déjà dans la table a été joué avant que l'amical existe :
-- aucun de ces matchs n'a pu être autre chose qu'un classé, et le défaut
-- « amical » qu'on vient de poser les effacerait tous du classement au prochain
-- rejeu. On l'écrit donc, une fois, plutôt que de laisser un futur lecteur le
-- supposer — ou l'oublier.
--
-- Sans clause `where` : la migration passe avant qu'un seul client ait pu
-- déclarer autre chose, il n'y a donc rien à épargner.
update public.match_reports set kind = 'ranked';


-- ---------------------------------------------------------------------------
-- LA VUE : la nature aussi doit concorder
-- ---------------------------------------------------------------------------
-- `concordant` change de sens sans changer de nom : deux récits ne tiennent
-- ensemble que s'ils s'accordent sur l'issue ET sur la nature. C'est délibéré —
-- un match dont les deux pairs ne disent pas la même chose de sa nature ne doit
-- pas devenir classé par le seul fait qu'ils s'accordent sur le vainqueur, et
-- tout lecteur de la vue qui filtre sur `concordant` hérite de la protection
-- sans avoir eu à y penser.
--
-- `create or replace` plutôt qu'un `drop` : il conserve les droits et le
-- `security_invoker` posés en 20260816210000, qu'une suppression emporterait
-- silencieusement. Le prix est qu'il n'autorise l'ajout de colonnes qu'à la FIN,
-- d'où `kind_a`/`kind_b` loin de `outcome_a`/`outcome_b`, qui serait leur place
-- naturelle. Le contrat vaut mieux que l'esthétique.
create or replace view public.matches as
select
    a.match_id,
    a.reporter as player_a,
    b.reporter as player_b,
    a.outcome as outcome_a,
    b.outcome as outcome_b,

    -- Deux récits tiennent ensemble si l'un gagne quand l'autre perd, ou si les
    -- deux disent égalité — et si les deux disent du match la même nature. Tout
    -- le reste est un litige, conservé comme tel.
    (
        (a.outcome = 'win'  and b.outcome = 'loss')
        or (a.outcome = 'loss' and b.outcome = 'win')
        or (a.outcome = 'draw' and b.outcome = 'draw')
    ) and (a.kind = b.kind) as concordant,

    case
        when a.outcome = 'win'  and b.outcome = 'loss' then a.reporter
        when b.outcome = 'win'  and a.outcome = 'loss' then b.reporter
    end as winner,

    -- Il suffit qu'un des deux ait vu un abandon pour que le match en soit un :
    -- celui qui part n'est pas toujours en état de le dire.
    (a.forfeit or b.forfeit) as forfeit,
    a.arbitration,
    greatest(a.duration_s, b.duration_s) as duration_s,
    a.map_id,
    a.format,
    least(a.reported_at, b.reported_at) as first_reported_at,
    greatest(a.reported_at, b.reported_at) as settled_at,

    -- Ce que chacun déclare, sans interprétation, comme pour l'issue : c'est ce
    -- qui rend un litige de nature diagnosticable au lieu d'être seulement
    -- écarté sans laisser de trace.
    a.kind as kind_a,
    b.kind as kind_b,

    -- La nature RETENUE, ou `null` quand les deux pairs ne s'accordent pas
    -- dessus. `null` et non `'friendly'` : « ils se contredisent » n'est pas
    -- « ils ont déclaré amical », et les deux se lisent en base. Le filtre
    -- `kind = 'ranked'` écarte l'un comme l'autre, ce qui est le comportement
    -- voulu — un litige ne compte pour rien.
    case when a.kind = b.kind then a.kind end as kind
from public.match_reports a
join public.match_reports b
    on a.match_id = b.match_id
    -- Une seule ligne par paire, et jamais un rapport apparié avec lui-même.
    and a.reporter < b.reporter;

comment on view public.matches is
    'Matchs dont les deux pairs ont rapporté. Vue pure : aucune interprétation n''est stockée. `concordant` couvre l''issue ET la nature ; `kind` vaut null quand les deux pairs ne s''accordent pas sur la nature.';


-- ---------------------------------------------------------------------------
-- ENREGISTRER UN RAPPORT — un paramètre de plus
-- ---------------------------------------------------------------------------
-- `create or replace` ne suffirait pas : une liste de paramètres différente crée
-- une SURCHARGE au lieu de remplacer. PostgREST se retrouverait devant deux
-- fonctions du même nom, dont l'ancienne — celle qui ignore la nature — resterait
-- appelable, et le choix se ferait sur les clés du corps de requête. Un client
-- d'une version antérieure continuerait donc d'écrire des rapports sans nature,
-- sans que rien ne le signale. On supprime, et on repose les droits que la
-- suppression emporte.
drop function if exists public.report_match(text, text, text, boolean, numeric, text, text, text, text);


-- Idempotente : rejouer le même envoi rend le rapport déjà écrit sans le
-- modifier. Un réseau qui hoquette fait renvoyer, et renvoyer ne doit jamais
-- réécrire l'histoire.
--
-- Rend un ensemble vide si le PUID est inconnu (jamais identifié) ou si un
-- troisième larron essaie de se greffer sur un match déjà rapporté par deux.
--
-- `p_kind` est en dernier et porte un défaut pour une raison de déploiement : la
-- migration et les fonctions Edge ne partent pas d'un seul geste, et pendant
-- l'intervalle l'ancien code appelle encore sans nature. Le défaut lui évite
-- d'échouer, et il vaut `null`, donc amical : cet intervalle peut au pire faire
-- manquer des matchs au classement, jamais en inventer. Déployer les fonctions
-- juste après reste la bonne pratique.
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
    p_kind text default null
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

    select id into player_id from public.players where puid = p_puid;
    if not found then
        -- Le classement ne connaît pas ce PUID : il ne s'est jamais identifié.
        return;
    end if;

    select * into existing from public.match_reports
        where match_id = p_match_id and reporter = player_id;
    if found then
        -- Déjà rapporté. On rend l'existant tel quel : un rapport ne se corrige
        -- pas — ni son issue, ni sa nature —, sinon il suffirait de renvoyer pour
        -- changer l'une ou l'autre.
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
        duration_s, map_id, weapon_self, weapon_opponent, format, kind)
    values (
        p_match_id, player_id, p_outcome::public.outcome, coalesce(p_forfeit, false),
        p_duration, p_map, coalesce(p_weapon_self, ''), coalesce(p_weapon_opponent, ''),
        coalesce(p_format, 'BO1'), kind_value)
    returning * into existing;

    -- Le joueur vient de jouer : c'est aussi une preuve de vie.
    update public.players set seen_at = now() where id = player_id;

    return next existing;
    return;
end;
$$;

revoke all on function public.report_match(text, text, text, boolean, numeric, text, text, text, text, text)
    from public, anon, authenticated;
grant execute on function public.report_match(text, text, text, boolean, numeric, text, text, text, text, text)
    to service_role;

notify pgrst, 'reload schema';
