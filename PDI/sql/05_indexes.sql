-- =============================================================================
-- 05_indexes.sql
-- Índices. Criar somente o necessário: cada índice extra custa espaço e deixa
-- a carga mais lenta.
--
--   psql -h localhost -U postgres -d dm_anp_pernambuco -f sql/05_indexes.sql
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Tabela fato: o PostgreSQL NÃO cria índice automático para FOREIGN KEY.
--
-- id_tempo: NÃO precisa de índice próprio. Ele é a primeira coluna da chave
--           primária pk_fato_preco_combustivel (id_tempo, id_revenda, id_combustivel),
--           cujo índice já atende filtros e junções por id_tempo.
-- Demais FKs: índice simples para junções/filtros por dimensão e para não
-- fazer varredura completa da fato ao validar DELETE/UPDATE nas dimensões.
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS ix_fato_id_combustivel ON fato_preco_combustivel (id_combustivel);
CREATE INDEX IF NOT EXISTS ix_fato_id_localizacao ON fato_preco_combustivel (id_localizacao);
CREATE INDEX IF NOT EXISTS ix_fato_id_revenda     ON fato_preco_combustivel (id_revenda);
CREATE INDEX IF NOT EXISTS ix_fato_id_bandeira    ON fato_preco_combustivel (id_bandeira);

-- semestre: filtro/agrupamento mais comum nas análises (2021.1 ... 2026.1).
CREATE INDEX IF NOT EXISTS ix_fato_semestre       ON fato_preco_combustivel (semestre);

-- -----------------------------------------------------------------------------
-- Dimensões: data, combustivel, municipio já têm índice pelas constraints
-- UNIQUE (uq_dim_tempo_data, uq_dim_combustivel, uq_dim_localizacao).
-- Esses índices também aceleram os Database Lookup / Insert-Update do PDI.
--
-- periodo / ano: a dim_tempo tem ~2.000 linhas, então um índice quase não ajuda
-- (o PostgreSQL faz seq scan em milissegundos). Criado só porque é o filtro
-- mais usado nas análises semestrais e custa praticamente nada.
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS ix_dim_tempo_periodo ON dim_tempo (periodo);

-- -----------------------------------------------------------------------------
-- Tabelas de controle do ETL: consultas por carga/arquivo.
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS ix_rejeitados_id_carga ON etl_rejeitados (id_carga);
CREATE INDEX IF NOT EXISTS ix_stg_nome_arquivo    ON stg_precos_combustiveis (nome_arquivo);
CREATE INDEX IF NOT EXISTS ix_stg_limpos_id_carga ON stg_precos_limpos (id_carga);
CREATE INDEX IF NOT EXISTS ix_fato_id_carga       ON fato_preco_combustivel (id_carga);
