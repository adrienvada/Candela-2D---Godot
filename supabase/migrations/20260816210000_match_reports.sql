-- Phase 4, étape 2a : les matchs arrivent en base.
--
-- Toujours aucun ELO. Cette étape se contente d'archiver, fidèlement et sans
-- interprétation, ce que chaque pair déclare du match qu'il vient de jouer.
--
-- Le principe qui gouverne tout le schéma : **on stocke les rapports, on dérive
-- le reste**. La table est immuable et brute ; la concordance, le vainqueur, et
-- demain le classement, sont des VUES calculées par-dessus. Une règle
-- d'interprétation qui se révèle mauvaise se change alors sans migration et
-- sans rien perdre — on recalcule.
--
-- Second principe : **chaque pair ne parle que de lui**. Il déclare « j'ai
-- gagné », jamais « untel a perdu ». Il n'a donc pas besoin de connaître le PUID
-- de son adversaire — le serveur apprend les deux identités des deux jetons
-- Epic, chacun vérifié. C'est aussi ce qui fait fonctionner le rapport en LAN,
-- où aucun PUID ne circule entre les machines.


-- Ce que le joueur dit de SON match. Volontairement pauvre : trois valeurs,
-- pas de score, pas de détail — tout ce qui se déduit se déduira ailleurs.
create type public.outcome as enum ('win', 'loss', 'draw');


create table public.match_reports (
    id uuid primary key default gen_random_uuid(),

    -- Tiré par l'hôte au lancement de la manche et transmis au client par RPC.
    -- Ni un secret, ni une autorité : juste ce qui permet d'apparier deux
    -- rapports venus de deux machines qui ne se parlent plus.
    match_id text not null
        constraint match_id_shape check (match_id ~ '^[0-9a-f]{32}$'),

    -- Qui rapporte. Vient du `sub` d'un jeton Epic vérifié, jamais du corps de
    -- la requête.
    reporter uuid not null references public.players(id) on delete cascade,

    outcome public.outcome not null,

    -- Le match s'est terminé par l'abandon de l'un des deux. Décision actée :
    -- un abandon vaut forfait (voir docs/ROADMAP.md). Le drapeau est conservé
    -- pour que le classement puisse pondérer ces matchs autrement — ou pas.
    forfeit boolean not null default false,

    -- Qui a arbitré ce résultat. `peer` aujourd'hui, puisque l'hôte simule tout.
    arbitration public.arbitration not null default 'peer',

    duration_s numeric(8, 2) not null
        constraint duration_sane check (duration_s >= 0 and duration_s <= 86400),
    map_id text not null
        constraint map_id_length check (char_length(map_id) between 1 and 64),
    weapon_self text not null default ''
        constraint weapon_self_length check (char_length(weapon_self) <= 32),
    weapon_opponent text not null default ''
        constraint weapon_opponent_length check (char_length(weapon_opponent) <= 32),
    format text not null default 'BO1'
        constraint format_known check (format in ('BO1', 'BO3', 'BO5')),

    reported_at timestamptz not null default now(),

    -- Un joueur ne rapporte qu'une fois par match. Ce qui est écrit est écrit :
    -- la fonction plus bas n'écrase jamais un rapport existant.
    constraint one_report_per_player unique (match_id, reporter)
);

create index match_reports_by_match on public.match_reports (match_id);
create index match_reports_by_player on public.match_reports (reporter, reported_at desc);

comment on table public.match_reports is
    'Ce que chaque pair déclare de son propre match. Immuable et brut : la concordance et le vainqueur se dérivent dans la vue public.matches.';
comment on column public.match_reports.match_id is
    'Tiré par l''hôte, transmis au client. Sert seulement à apparier deux rapports.';
comment on column public.match_reports.outcome is
    'Ce que le RAPPORTEUR dit de lui-même. Personne ne déclare le sort d''un autre.';


-- ---------------------------------------------------------------------------
-- LA VUE : deux rapports appariés
-- ---------------------------------------------------------------------------
-- Rien n'est décidé ici non plus, on ne fait que rapprocher. `concordant` dit
-- si les deux récits tiennent ensemble ; il ne dit pas quoi en faire — ça, ce
-- sera l'affaire du classement, et ça pourra changer d'avis.
--
-- Un match dont un seul pair a rapporté n'apparaît pas : la jointure demande
-- deux lignes. Il n'est pas perdu pour autant, il reste dans `match_reports`.
create view public.matches as
select
    a.match_id,
    a.reporter as player_a,
    b.reporter as player_b,
    a.outcome as outcome_a,
    b.outcome as outcome_b,

    -- Deux récits tiennent ensemble si l'un gagne quand l'autre perd, ou si les
    -- deux disent égalité. Tout le reste est un litige, conservé comme tel.
    (a.outcome = 'win'  and b.outcome = 'loss')
        or (a.outcome = 'loss' and b.outcome = 'win')
        or (a.outcome = 'draw' and b.outcome = 'draw') as concordant,

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
    greatest(a.reported_at, b.reported_at) as settled_at
from public.match_reports a
join public.match_reports b
    on a.match_id = b.match_id
    -- Une seule ligne par paire, et jamais un rapport apparié avec lui-même.
    and a.reporter < b.reporter;

comment on view public.matches is
    'Matchs dont les deux pairs ont rapporté. Vue pure : aucune interprétation n''est stockée, tout se recalcule.';


-- ---------------------------------------------------------------------------
-- ROW LEVEL SECURITY — tout fermé, comme players
-- ---------------------------------------------------------------------------
alter table public.match_reports enable row level security;
revoke all on table public.match_reports from anon, authenticated;
revoke all on public.matches from anon, authenticated;
grant all on table public.match_reports to service_role;
grant select on public.matches to service_role;

-- La vue s'exécute avec les droits de son appelant et non de son auteur : sans
-- ça elle contournerait la RLS de la table qu'elle lit.
alter view public.matches set (security_invoker = on);


-- ---------------------------------------------------------------------------
-- ENREGISTRER UN RAPPORT
-- ---------------------------------------------------------------------------
-- Idempotente : rejouer le même envoi rend le rapport déjà écrit sans le
-- modifier. Un réseau qui hoquette fait renvoyer, et renvoyer ne doit jamais
-- réécrire l'histoire.
--
-- Rend un ensemble vide si le PUID est inconnu (jamais identifié) ou si un
-- troisième larron essaie de se greffer sur un match déjà rapporté par deux.
create function public.report_match(
    p_puid text,
    p_match_id text,
    p_outcome text,
    p_forfeit boolean,
    p_duration numeric,
    p_map text,
    p_weapon_self text,
    p_weapon_opponent text,
    p_format text
)
returns setof public.match_reports
language plpgsql
security definer
set search_path = public
as $$
declare
    player_id uuid;
    existing public.match_reports;
begin
    select id into player_id from public.players where puid = p_puid;
    if not found then
        -- Le classement ne connaît pas ce PUID : il ne s'est jamais identifié.
        return;
    end if;

    select * into existing from public.match_reports
        where match_id = p_match_id and reporter = player_id;
    if found then
        -- Déjà rapporté. On rend l'existant tel quel : un rapport ne se corrige
        -- pas, sinon il suffirait de renvoyer pour changer l'issue d'un match.
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
        duration_s, map_id, weapon_self, weapon_opponent, format)
    values (
        p_match_id, player_id, p_outcome::public.outcome, coalesce(p_forfeit, false),
        p_duration, p_map, coalesce(p_weapon_self, ''), coalesce(p_weapon_opponent, ''),
        coalesce(p_format, 'BO1'))
    returning * into existing;

    -- Le joueur vient de jouer : c'est aussi une preuve de vie.
    update public.players set seen_at = now() where id = player_id;

    return next existing;
    return;
end;
$$;

revoke all on function public.report_match(text, text, text, boolean, numeric, text, text, text, text)
    from public, anon, authenticated;
grant execute on function public.report_match(text, text, text, boolean, numeric, text, text, text, text)
    to service_role;

notify pgrst, 'reload schema';
