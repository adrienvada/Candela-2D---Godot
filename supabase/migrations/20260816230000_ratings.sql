-- Phase 4, étape 2b : le classement.
--
-- **Cette table est DÉRIVÉE.** Elle ne fait pas foi ; `match_reports` fait foi.
-- Rien ne l'édite ligne à ligne : elle est reconstruite en entier par un rejeu
-- de tout l'historique concordant, et le calcul lui-même vit dans
-- `supabase/functions/_shared/elo.ts`, où il est testé hors ligne.
--
-- C'est ce qui rend les réglages réversibles. Un mauvais facteur K, un mauvais
-- classement de départ, une mauvaise pondération du forfait : on change la
-- constante, on rejoue, et le classement est juste. Sans cette propriété, la
-- première erreur de réglage serait définitive — et on ne saurait même pas
-- qu'elle en est une avant longtemps.
--
-- Pourquoi le calcul n'est pas en SQL : parce qu'il serait alors intestable
-- hors ligne. Le classement est la partie du système où une erreur est la plus
-- difficile à voir après coup — un classement faux reste plausible.

create table public.ratings (
    player_id uuid primary key references public.players(id) on delete cascade,

    rating integer not null,
    matches integer not null default 0,
    wins integer not null default 0,
    losses integer not null default 0,
    draws integer not null default 0,

    -- Quand ce classement a été recalculé, pas quand le joueur a joué.
    computed_at timestamptz not null default now()
);

create index ratings_by_rank on public.ratings (rating desc, matches desc);

comment on table public.ratings is
    'DÉRIVÉE — reconstruite par rejeu de match_reports, jamais éditée à la main. La source de vérité est l''historique des matchs.';


-- ---------------------------------------------------------------------------
-- LE TABLEAU
-- ---------------------------------------------------------------------------
-- Le rang se calcule à la lecture plutôt que de se stocker : le stocker
-- obligerait à réécrire toute la table dès qu'un seul classement bouge.
create view public.leaderboard as
select
    r.player_id,
    p.nickname,
    r.rating,
    r.matches,
    r.wins,
    r.losses,
    r.draws,
    rank() over (order by r.rating desc, r.matches desc, p.created_at asc) as rank
from public.ratings r
join public.players p on p.id = r.player_id;

alter view public.leaderboard set (security_invoker = on);

comment on view public.leaderboard is
    'Classement lisible, rang calculé à la lecture. Aucune donnée propre : tout vient de ratings et players.';


-- ---------------------------------------------------------------------------
-- ROW LEVEL SECURITY — tout fermé, comme le reste
-- ---------------------------------------------------------------------------
alter table public.ratings enable row level security;
revoke all on table public.ratings from anon, authenticated;
revoke all on public.leaderboard from anon, authenticated;
grant all on table public.ratings to service_role;
grant select on public.leaderboard to service_role;


-- ---------------------------------------------------------------------------
-- APPLIQUER UN RECALCUL
-- ---------------------------------------------------------------------------
-- Remplace le contenu de la table en une seule transaction. Prend le résultat
-- complet du rejeu, pas une mise à jour partielle : un classement recalculé
-- n'est vrai que dans son ensemble, et appliquer la moitié d'un rejeu laisserait
-- une table qui ne correspond à aucun historique.
--
-- Les joueurs absents du rejeu sont supprimés : ils n'ont plus de match
-- concordant, donc plus de classement. Ne pas les effacer laisserait traîner
-- des classements que plus rien ne justifie.
create function public.apply_ratings(p_rows jsonb)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    touched integer;
begin
    with incoming as (
        select
            (value->>'player_id')::uuid as player_id,
            (value->>'rating')::integer as rating,
            (value->>'matches')::integer as matches,
            (value->>'wins')::integer as wins,
            (value->>'losses')::integer as losses,
            (value->>'draws')::integer as draws
        from jsonb_array_elements(coalesce(p_rows, '[]'::jsonb))
    ),
    -- Le joueur doit exister : un rejeu ne peut pas inventer d'identité.
    valid as (
        select i.* from incoming i join public.players p on p.id = i.player_id
    ),
    removed as (
        delete from public.ratings
            where player_id not in (select player_id from valid)
    ),
    upserted as (
        insert into public.ratings
            (player_id, rating, matches, wins, losses, draws, computed_at)
        select player_id, rating, matches, wins, losses, draws, now() from valid
        on conflict (player_id) do update set
            rating = excluded.rating,
            matches = excluded.matches,
            wins = excluded.wins,
            losses = excluded.losses,
            draws = excluded.draws,
            computed_at = excluded.computed_at
        returning 1
    )
    select count(*) into touched from upserted;
    return touched;
end;
$$;

revoke all on function public.apply_ratings(jsonb) from public, anon, authenticated;
grant execute on function public.apply_ratings(jsonb) to service_role;

notify pgrst, 'reload schema';
