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
--           primária pk_fato_preco_combustivel (id_tempo, id_local, id_combustivel,
--           data_coleta), cujo índice já atende filtros e junções por semestre.
-- Demais FKs: índice simples para junções/filtros por dimensão e para não
-- fazer varredura completa da fato ao validar DELETE/UPDATE nas dimensões.
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS ix_fato_id_local       ON fato_preco_combustivel (id_local);
CREATE INDEX IF NOT EXISTS ix_fato_id_combustivel ON fato_preco_combustivel (id_combustivel);
CREATE INDEX IF NOT EXISTS ix_fato_id_bandeira    ON fato_preco_combustivel (id_bandeira);

-- data_coleta: consultas por dia/mês dentro do semestre.
CREATE INDEX IF NOT EXISTS ix_fato_data_coleta    ON fato_preco_combustivel (data_coleta);

-- -----------------------------------------------------------------------------
-- Dimensões: cnpj, combustivel, periodo já têm índice pelas constraints UNIQUE
-- (que também aceleram os Database Lookup / Insert-Update do PDI).
-- dim_local: análises filtram/agrupam por município e UF.
-- A dim_tempo semestral tem só 13 linhas: nenhum índice extra é necessário.
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS ix_dim_local_uf_municipio ON dim_local (uf, municipio);

-- -----------------------------------------------------------------------------
-- Tabelas de controle do ETL: consultas por carga/arquivo.
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS ix_rejeitados_id_carga ON etl_rejeitados (id_carga);
CREATE INDEX IF NOT EXISTS ix_stg_nome_arquivo    ON stg_precos_combustiveis (nome_arquivo);
CREATE INDEX IF NOT EXISTS ix_stg_limpos_id_carga ON stg_precos_limpos (id_carga);
CREATE INDEX IF NOT EXISTS ix_fato_id_carga       ON fato_preco_combustivel (id_carga);
