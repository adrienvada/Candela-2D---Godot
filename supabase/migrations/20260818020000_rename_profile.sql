-- Renommer son profil — Phase 5, étape 6.
--
-- L'écran du profil réservait la place depuis le début ; l'action n'était pas
-- offerte, faute d'un point d'entrée serveur. Le voici.
--
-- Le pseudo est la SEULE chose qu'un joueur peut changer de son profil. Ni son
-- identifiant, ni son code de récupération, ni son classement : tout le reste
-- est dérivé ou constitutif.

create or replace function public.rename_profile(
    p_puid text,
    p_nickname text
)
returns setof public.players
language plpgsql
security definer
set search_path = public
as $$
declare
    target public.players;
begin
    -- La contrainte `nickname_length` (1 à 24 caractères) est déjà sur la
    -- colonne ; on la double ici pour rendre un ensemble vide plutôt qu'une
    -- exception, l'appelant ne sachant pas lire une violation de contrainte.
    if p_nickname is null or char_length(p_nickname) < 1
        or char_length(p_nickname) > 24 then
        return;
    end if;

    -- On renomme par le PUID et lui seul : c'est ce que le jeton Epic prouve.
    -- Passer l'identifiant du profil laisserait renommer celui d'un autre à qui
    -- saurait le deviner.
    update public.players
        set nickname = p_nickname,
            seen_at = now()
        where puid = p_puid
        returning * into target;

    if not found then
        -- Aucun profil pour ce PUID : la machine ne s'est jamais identifiée.
        -- Ensemble vide, comme `link_profile`, et pour la même raison — c'est
        -- l'unique signal d'échec de cette famille de fonctions.
        return;
    end if;

    return next target;
end;
$$;

comment on function public.rename_profile(text, text) is
    'Change le pseudo du profil rattaché à ce PUID. Ensemble vide si le PUID est inconnu ou le pseudo hors bornes.';
