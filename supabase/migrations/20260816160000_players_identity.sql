-- Phase 4, étape 1 : l'identité, et rien d'autre.
--
-- Aucun ELO n'est calculé ici. Cette migration établit QUI EST QUI de façon
-- infalsifiable : un classement dont on peut usurper les profils ne vaut rien,
-- et tout ce qui suivra pointera sur `players.id`.
--
-- Deux règles gouvernent ce fichier :
--   1. Le jeu n'écrit JAMAIS en direct. Il ne connaît que la clé publiable, et
--      la Row Level Security ci-dessous lui refuse tout. Les seules écritures
--      passent par les deux fonctions du bas, appelées par les Edge Functions
--      avec la clé secrète, après vérification du jeton signé par Epic.
--   2. Le PUID posté par un client ne prouve rien à lui seul. Ce qui entre ici
--      vient du `sub` d'un jeton Epic vérifié, jamais du corps de la requête.


-- ---------------------------------------------------------------------------
-- ORIGINE DE L'ARBITRAGE
-- ---------------------------------------------------------------------------
-- Aujourd'hui l'hôte simule le match : l'arbitre est un pair, et il peut donc
-- mentir (décision « P2P conservé » dans docs/ROADMAP.md — la bascule vers un
-- serveur dédié est différée, pas écartée). Le jour où un serveur arbitre, ses
-- résultats ne seront pas de même nature que les précédents.
--
-- Le type existe dès maintenant pour que ce jour-là rien de déjà écrit n'ait à
-- être réinterprété ni jeté : chaque ligne arbitrée porte son arbitre.
create type public.arbitration as enum ('peer', 'server');


-- ---------------------------------------------------------------------------
-- JOUEURS
-- ---------------------------------------------------------------------------
create table public.players (
    id uuid primary key default gen_random_uuid(),

    -- PUID Epic COURANT — il change quand le joueur rattache une nouvelle
    -- machine. L'identité durable du profil est `id`, jamais le PUID : c'est
    -- ce qui permettra à un historique de survivre à un changement d'ordinateur.
    puid text not null unique,

    -- Code de récupération, en clair, et pour une raison précise : le jeu le
    -- réaffiche à chaque lancement pour que le joueur puisse le recopier. Un
    -- condensat l'interdirait. Le compromis est déjà consigné dans la roadmap —
    -- c'est un secret au porteur, qui l'obtient prend le profil — et jugé
    -- proportionné à l'enjeu d'un classement de jeu.
    --
    -- 12 caractères sur un alphabet de 32, soit 60 bits : assez pour qu'une
    -- attaque en ligne soit hors de portée, là où les 6 caractères d'un code de
    -- salon (30 bits) ne protégeraient rien.
    code text not null unique
        constraint code_shape check (code ~ '^[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{12}$'),

    nickname text not null
        constraint nickname_length check (char_length(nickname) between 1 and 24),

    -- Régime d'arbitrage sous lequel ce profil est inscrit. Sa place définitive
    -- est sur la ligne de résultat, quand la table des matchs existera ; il est
    -- porté ici dès l'étape 1 pour que le type soit versionné avec le schéma et
    -- que la première ligne écrite dise déjà qui l'a arbitrée.
    arbitration public.arbitration not null default 'peer',

    created_at timestamptz not null default now(),
    -- Touché à chaque identification : c'est le seul moyen de voir, depuis le
    -- tableau de bord, que deux machines distinctes portent bien deux profils.
    seen_at timestamptz not null default now()
);

comment on table public.players is
    'Profils classés. Le jeu n''y écrit jamais en direct : tout passe par les Edge Functions, après vérification d''un jeton Epic.';
comment on column public.players.puid is
    'PUID Epic courant. Change au rattachement d''une nouvelle machine ; l''identité durable est id.';
comment on column public.players.code is
    'Code de récupération, 12 caractères sans I/O/0/1. Secret au porteur, en clair car réaffiché à chaque lancement.';
comment on column public.players.arbitration is
    'Qui a arbitré : pair (hôte-autoritaire) ou serveur dédié. Prévu pour qu''un serveur introduit plus tard n''invalide pas l''historique.';


-- ---------------------------------------------------------------------------
-- ROW LEVEL SECURITY — tout fermé
-- ---------------------------------------------------------------------------
-- C'est cette section, et elle seule, qui rend la clé publiable sûre : sans
-- elle, la clé embarquée dans le jeu ouvrirait la table en lecture comme en
-- écriture. RLS activée SANS AUCUNE POLITIQUE signifie « refusé à tout le
-- monde » — l'absence de politique est donc ici le contenu, pas un oubli.
--
-- Seule la clé secrète (rôle `service_role`, réservé aux Edge Functions)
-- contourne la RLS. Elle n'entre jamais dans un build du jeu.
alter table public.players enable row level security;

-- Ceinture et bretelles : la RLS suffirait, mais Supabase accorde par défaut
-- tous les droits sur les tables de `public` aux rôles anonyme et authentifié.
-- On les retire, pour qu'une politique ajoutée par erreur plus tard n'ouvre pas
-- accidentellement toute la table.
revoke all on table public.players from anon, authenticated;
grant all on table public.players to service_role;


-- ---------------------------------------------------------------------------
-- IDENTIFICATION
-- ---------------------------------------------------------------------------
-- Crée le profil du PUID, ou rend celui qui existe déjà.
--
-- En fonction plutôt qu'en deux requêtes depuis l'Edge Function : deux instances
-- lancées en même temps sur la même machine se présenteraient sinon toutes deux
-- comme « inconnues », et la seconde échouerait sur la contrainte d'unicité.
-- `on conflict` règle la course en une seule opération atomique.
--
-- `p_code` n'est consommé que si une ligne est réellement insérée : un profil
-- existant conserve le code qu'il a toujours eu.
create or replace function public.identify_player(
    p_puid text,
    p_code text,
    p_nickname text
)
returns public.players
language plpgsql
security definer
set search_path = public
as $$
declare
    result public.players;
begin
    insert into public.players (puid, code, nickname)
    values (p_puid, p_code, p_nickname)
    on conflict (puid) do update set seen_at = now()
    returning * into result;
    return result;
end;
$$;


-- ---------------------------------------------------------------------------
-- RATTACHEMENT D'UNE NOUVELLE MACHINE
-- ---------------------------------------------------------------------------
-- Le Device ID Epic est lié à la machine : un joueur qui change d'ordinateur
-- arrive avec un PUID neuf. Sur présentation de son code — et d'un jeton Epic
-- valide, vérifié en amont par l'Edge Function — son profil suit.
--
-- Rend NULL si le code est inconnu : c'est l'unique signal d'échec, et il ne
-- distingue pas « code faux » de « code d'un autre », ce qui est voulu.
create or replace function public.link_profile(
    p_code text,
    p_puid text
)
returns public.players
language plpgsql
security definer
set search_path = public
as $$
declare
    target public.players;
begin
    select * into target from public.players where code = p_code for update;
    if not found then
        return null;
    end if;

    if target.puid = p_puid then
        -- Déjà rattaché : le joueur ressaisit son propre code sur sa machine.
        update public.players set seen_at = now() where id = target.id
            returning * into target;
        return target;
    end if;

    -- La nouvelle machine s'est identifiée avant que le joueur ne saisisse son
    -- code : elle s'est donc créé un profil vierge, qui n'a jamais servi. Il
    -- s'efface au profit de celui qu'on rattache, sans quoi l'unicité du PUID
    -- ferait échouer le rattachement.
    --
    -- À revoir le jour où des matchs pointeront vers un profil : effacer
    -- deviendra alors une fusion, pas une suppression.
    delete from public.players where puid = p_puid and id <> target.id;

    update public.players
        set puid = p_puid, seen_at = now()
        where id = target.id
        returning * into target;
    return target;
end;
$$;


-- Les deux fonctions écrivent : personne d'autre que les Edge Functions ne doit
-- pouvoir les appeler, surtout pas la clé publiable embarquée dans le jeu.
revoke all on function public.identify_player(text, text, text) from public, anon, authenticated;
revoke all on function public.link_profile(text, text) from public, anon, authenticated;
grant execute on function public.identify_player(text, text, text) to service_role;
grant execute on function public.link_profile(text, text) to service_role;

-- PostgREST garde le schéma en cache : sans ce signal, les fonctions ci-dessus
-- restent invisibles jusqu'au prochain redémarrage de l'API.
notify pgrst, 'reload schema';
