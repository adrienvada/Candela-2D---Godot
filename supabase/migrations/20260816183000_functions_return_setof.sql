-- Correctif : « code de récupération inconnu » ne se disait pas.
--
-- Les deux fonctions rendaient `public.players`, et `link_profile` rendait NULL
-- pour signaler un code introuvable. Vu du client, ce NULL n'existe pas :
-- PostgREST sérialise un composite NULL en OBJET DE CHAMPS NULS —
-- {"id":null,"puid":null,…} — et non en `null`. L'Edge Function y voyait donc un
-- profil parfaitement valide et répondait 200 au lieu de 404.
--
-- Constaté en production le 2026-08-16 : un code inventé était accepté.
--
-- Le remède est de rendre le contrat non ambigu à la source. `setof` distingue
-- proprement zéro ligne d'une ligne : un ensemble vide devient `[]`, qu'aucune
-- lecture ne peut confondre avec un profil.
--
-- `create or replace` ne peut pas changer un type de retour : il faut supprimer
-- puis recréer, et reposer les droits que la suppression emporte.

drop function if exists public.identify_player(text, text, text);
drop function if exists public.link_profile(text, text);


create function public.identify_player(
    p_puid text,
    p_code text,
    p_nickname text
)
returns setof public.players
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
    return next result;
    return;
end;
$$;


create function public.link_profile(
    p_code text,
    p_puid text
)
returns setof public.players
language plpgsql
security definer
set search_path = public
as $$
declare
    target public.players;
begin
    select * into target from public.players where code = p_code for update;
    if not found then
        -- Ensemble vide, et rien d'autre : c'est l'unique signal d'échec, et il
        -- ne distingue pas « code faux » de « code d'un autre ».
        return;
    end if;

    if target.puid = p_puid then
        -- Déjà rattaché : le joueur ressaisit son propre code sur sa machine.
        update public.players set seen_at = now() where id = target.id
            returning * into target;
        return next target;
        return;
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
    return next target;
    return;
end;
$$;


revoke all on function public.identify_player(text, text, text) from public, anon, authenticated;
revoke all on function public.link_profile(text, text) from public, anon, authenticated;
grant execute on function public.identify_player(text, text, text) to service_role;
grant execute on function public.link_profile(text, text) to service_role;

notify pgrst, 'reload schema';
