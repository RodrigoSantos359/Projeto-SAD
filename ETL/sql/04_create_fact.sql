-- =============================================================================
-- 04_create_fact.sql
-- Tabela fato (grão: 1 coleta de preço = 1 posto x 1 combustível x 1 data).
-- A dimensão tempo é semestral; a data exata da coleta fica na própria fato.
--
--   psql -h localhost -U postgres -d dm_anp_pernambuco -f sql/04_create_fact.sql
-- =============================================================================

CREATE TABLE IF NOT EXISTS fato_preco_combustivel (
    id_tempo              INTEGER       NOT NULL,   -- semestre (dim_tempo)
    id_local              INTEGER       NOT NULL,   -- posto e sua localização (dim_local)
    id_combustivel        INTEGER       NOT NULL,
    id_bandeira           INTEGER       NOT NULL,
    data_coleta           DATE          NOT NULL,   -- dia da coleta (dimensão degenerada)
    semestre              VARCHAR(6)    NOT NULL,   -- semestre da coleta, ex.: 2024.1
    valor_venda           NUMERIC(12,2) NOT NULL,
    valor_compra          NUMERIC(12,2),            -- NULL = não informado pela ANP
    margem                NUMERIC(12,2),            -- NULL quando valor_compra é NULL
    quantidade_registros  INTEGER       NOT NULL DEFAULT 1,
    id_carga              BIGINT,                   -- rastreabilidade (etl_controle_carga)

    CONSTRAINT fk_fato_tempo
        FOREIGN KEY (id_tempo)       REFERENCES dim_tempo (id_tempo),
    CONSTRAINT fk_fato_local
        FOREIGN KEY (id_local)       REFERENCES dim_local (id_local),
    CONSTRAINT fk_fato_combustivel
        FOREIGN KEY (id_combustivel) REFERENCES dim_combustivel (id_combustivel),
    CONSTRAINT fk_fato_bandeira
        FOREIGN KEY (id_bandeira)    REFERENCES dim_bandeira (id_bandeira),

    -- Chave primária: identifica uma coleta = semestre + posto + combustível + dia.
    -- (id_tempo vem antes para o índice da PK atender filtros por semestre.)
    -- id_bandeira não entra: é determinada pelo posto naquele dia.
    -- A PK também garante idempotência: recarregar não duplica.
    CONSTRAINT pk_fato_preco_combustivel PRIMARY KEY (id_tempo, id_local, id_combustivel, data_coleta),

    CONSTRAINT ck_fato_semestre     CHECK (semestre ~ '^[0-9]{4}\.[12]$'),
    CONSTRAINT ck_fato_valor_venda  CHECK (valor_venda > 0),
    CONSTRAINT ck_fato_valor_compra CHECK (valor_compra IS NULL OR valor_compra > 0),
    CONSTRAINT ck_fato_margem CHECK (
        (valor_compra IS NULL AND margem IS NULL)
        OR margem = valor_venda - valor_compra
    )
);

COMMENT ON TABLE  fato_preco_combustivel             IS 'Preços de revenda coletados pela ANP em Pernambuco (1 linha por coleta)';
COMMENT ON COLUMN fato_preco_combustivel.data_coleta IS 'Data da coleta; o semestre está em id_tempo/semestre';
COMMENT ON COLUMN fato_preco_combustivel.semestre    IS 'Semestre da coleta no formato AAAA.S (ex.: 2024.1); igual a dim_tempo.periodo';
COMMENT ON COLUMN fato_preco_combustivel.margem      IS 'valor_venda - valor_compra; NULL se valor_compra não informado';
