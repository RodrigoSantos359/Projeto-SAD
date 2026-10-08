-- =============================================================================
-- 01_create_database.sql
-- Cria o banco do Data Mart de preços de combustíveis de Pernambuco.
--
-- Executar conectado ao banco "postgres" (CREATE DATABASE não roda dentro de
-- uma transação nem dentro do próprio banco que está sendo criado):
--
--   psql -h localhost -U postgres -d postgres -f sql/01_create_database.sql
--
-- Foi usado um banco separado (dm_anp_pernambuco) para não colidir com as
-- tabelas já existentes no banco dw_combustiveis (ex.: dim_tempo).
-- =============================================================================

CREATE DATABASE dm_anp_pernambuco
    WITH ENCODING = 'UTF8'
         TEMPLATE = template0;

COMMENT ON DATABASE dm_anp_pernambuco IS
    'Data Mart de preços de combustíveis - Pernambuco (ANP, 2021 a 2026.1)';
