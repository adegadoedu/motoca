-- =====================================================================
--  Adega do Edu · Ranking do Motoca
--  Cole tudo no SQL Editor do Supabase e clique em Run (uma vez só).
--  Cria a tabela de recordes do Motoca e 2 funções: enviar recorde e
--  ver ranking. Usa a mesma conta (jogadores) do jogo da Adega e não
--  mexe em nada do jogo da Adega nem dos cupons.
-- =====================================================================

-- 1) Recordes por fase (melhor pontuação e melhor tempo de cada jogador)
create table if not exists public.motoca_recordes (
  jogador_id   uuid not null references public.jogadores(id) on delete cascade,
  ato          integer not null check (ato between 1 and 18),
  pontos       integer not null check (pontos between 0 and 200000),
  tempo        integer not null check (tempo between 1 and 3600),
  atualizado_em timestamptz not null default now(),
  primary key (jogador_id, ato)
);
alter table public.motoca_recordes enable row level security;
revoke all on public.motoca_recordes from public, anon, authenticated;

-- 2) Enviar recorde: só o próprio jogador (id + token), guarda sempre o melhor
create or replace function public.motoca_enviar_recorde(p_id uuid, p_token uuid, p_ato integer, p_pontos integer, p_tempo integer)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.jogadores where id = p_id and token = p_token) then
    raise exception 'jogador_invalido';
  end if;
  if p_ato is null or p_ato < 1 or p_ato > 18
     or p_pontos is null or p_pontos < 0 or p_pontos > 200000
     or p_tempo is null or p_tempo < 1 or p_tempo > 3600 then
    raise exception 'valor_invalido';
  end if;
  insert into public.motoca_recordes (jogador_id, ato, pontos, tempo)
  values (p_id, p_ato, p_pontos, p_tempo)
  on conflict (jogador_id, ato) do update
     set pontos = greatest(public.motoca_recordes.pontos, excluded.pontos),
         tempo  = least(public.motoca_recordes.tempo, excluded.tempo),
         atualizado_em = now();
end $$;

-- 3) Ranking: soma dos melhores pontos de cada fase (top 50 + a sua posição)
create or replace function public.motoca_ranking(p_id uuid default null)
returns table(posicao bigint, apelido text, pontos bigint, fases bigint, eu boolean)
language sql stable security definer set search_path = public as $$
  with soma as (
    select r.jogador_id, sum(r.pontos)::bigint as pontos, count(*)::bigint as fases
      from public.motoca_recordes r
     group by r.jogador_id
  ), ordenado as (
    select s.jogador_id, j.apelido::text as apelido, s.pontos, s.fases,
           rank() over (order by s.pontos desc) as posicao
      from soma s join public.jogadores j on j.id = s.jogador_id
  )
  select posicao, apelido, pontos, fases, coalesce(jogador_id = p_id, false)
    from ordenado
   where posicao <= 50 or jogador_id = p_id
   order by posicao
   limit 51;
$$;

revoke all on function public.motoca_enviar_recorde(uuid, uuid, integer, integer, integer) from public;
revoke all on function public.motoca_ranking(uuid) from public;
grant execute on function public.motoca_enviar_recorde(uuid, uuid, integer, integer, integer) to anon, authenticated;
grant execute on function public.motoca_ranking(uuid) to anon, authenticated;
