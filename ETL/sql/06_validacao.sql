-- =============================================================================
-- 06_validacao.sql
-- Consultas de validação após executar o job 00_ETL_ANP_DataMart.
--
--   psql -h localhost -U postgres -d dm_anp_pernambuco -f sql/06_validacao.sql
-- =============================================================================

\echo '== 1. Quantidade de registros na fato'
SELECT COUNT(*) AS registros_fato
FROM fato_preco_combustivel;

\echo '== 2. Controle de cargas (lidos = processados + rejeitados + fora do escopo)'
SELECT id_carga, nome_arquivo, status,
       quantidade_lida, quantidade_processada, quantidade_rejeitada, quantidade_fora_escopo,
       quantidade_lida = quantidade_processada + quantidade_rejeitada + quantidade_fora_escopo AS fecha,
       data_inicio, data_fim
FROM etl_controle_carga
ORDER BY id_carga;

\echo '== 3. Período carregado (menor e maior data)'
SELECT MIN(t.data) AS menor_data, MAX(t.data) AS maior_data
FROM fato_preco_combustivel f
JOIN dim_tempo t ON t.id_tempo = f.id_tempo;

\echo '== 4. Estados presentes (deve existir somente PE)'
SELECT l.uf, COUNT(*) AS registros
FROM fato_preco_combustivel f
JOIN dim_localizacao l ON l.id_localizacao = f.id_localizacao
GROUP BY l.uf;

\echo '== 5. Combustíveis carregados'
SELECT c.combustivel, c.categoria, c.unidade_medida, COUNT(*) AS registros
FROM fato_preco_combustivel f
JOIN dim_combustivel c ON c.id_combustivel = f.id_combustivel
GROUP BY c.combustivel, c.categoria, c.unidade_medida
ORDER BY registros DESC;

\echo '== 6. Municípios de Pernambuco'
/* Municípios de Pernambuco */

SELECT l.municipio, COUNT(*) AS registros, COUNT(DISTINCT f.id_revenda) AS postos
FROM fato_preco_combustivel f
JOIN dim_localizacao l ON l.id_localizacao = f.id_localizacao
GROUP BY l.municipio
ORDER BY registros DESC;

\echo '== 7. Semestres: todos os períodos esperados (2020.1 a 2026.1) e quantos registros cada um tem'
/* Semestres: todos os períodos esperados (2020.1 a 2026.1) e quantos registros cada um tem */

SELECT p.periodo AS semestre, COUNT(f.semestre) AS registros,
       CASE WHEN COUNT(f.semestre) = 0 THEN 'SEM DADOS' ELSE 'OK' END AS situacao
FROM (SELECT DISTINCT periodo FROM dim_tempo) p
LEFT JOIN fato_preco_combustivel f ON f.semestre = p.periodo
GROUP BY p.periodo
ORDER BY p.periodo;

\echo '== 7b. Coluna semestre da fato confere com a data da coleta (deve ser 0)'
SELECT COUNT(*) AS semestre_divergente
FROM fato_preco_combustivel f
JOIN dim_tempo t ON t.id_tempo = f.id_tempo
WHERE f.semestre <> t.periodo;

\echo '== 8. Estatísticas de valor_venda por combustível'
/* Estatísticas de valor_venda por combustível */

SELECT c.combustivel,
       MIN(f.valor_venda)            AS minimo,
       MAX(f.valor_venda)            AS maximo,
       ROUND(AVG(f.valor_venda), 4)  AS media,
       ROUND(STDDEV(f.valor_venda), 4) AS desvio_padrao
FROM fato_preco_combustivel f
JOIN dim_combustivel c ON c.id_combustivel = f.id_combustivel
GROUP BY c.combustivel
ORDER BY c.combustivel;

\echo '== 9. Valores suspeitos: fora de média ± 3 desvios do mesmo combustível no mesmo mês'
/* Valores suspeitos: fora de média ± 3 desvios do mesmo combustível no mesmo mês */

WITH base AS (
    SELECT c.combustivel, t.ano, t.mes, t.data, r.cnpj, r.nome_revenda, f.valor_venda,
           AVG(f.valor_venda)    OVER (PARTITION BY f.id_combustivel, t.ano, t.mes) AS media_mes,
           STDDEV(f.valor_venda) OVER (PARTITION BY f.id_combustivel, t.ano, t.mes) AS desvio_mes
    FROM fato_preco_combustivel f
    JOIN dim_combustivel c ON c.id_combustivel = f.id_combustivel
    JOIN dim_tempo t       ON t.id_tempo       = f.id_tempo
    JOIN dim_revenda r     ON r.id_revenda     = f.id_revenda
)
SELECT combustivel, data, cnpj, nome_revenda, valor_venda,
       ROUND(media_mes, 4) AS media_mes, ROUND(desvio_mes, 4) AS desvio_mes
FROM base
WHERE desvio_mes > 0
  AND ABS(valor_venda - media_mes) > 3 * desvio_mes
ORDER BY combustivel, data;

\echo '== 9b. Valores repetidos nos extremos: o mesmo preço como mínimo/máximo de vários combustíveis'
\echo '       (sinal de valores truncados/editados na origem; na planilha antiga apareciam 2,94 e 7,52)'
WITH extremos AS (
    SELECT f.id_combustivel,
           MIN(f.valor_venda) AS minimo,
           MAX(f.valor_venda) AS maximo
    FROM fato_preco_combustivel f
    GROUP BY f.id_combustivel
), valores AS (
    SELECT minimo AS valor, 'MINIMO' AS tipo, id_combustivel FROM extremos
    UNION ALL
    SELECT maximo, 'MAXIMO', id_combustivel FROM extremos
)
SELECT v.tipo, v.valor,
       COUNT(DISTINCT v.id_combustivel) AS combustiveis_com_esse_extremo,
       (SELECT COUNT(*) FROM fato_preco_combustivel f WHERE f.valor_venda = v.valor) AS registros_com_esse_valor
FROM valores v
GROUP BY v.tipo, v.valor
HAVING COUNT(DISTINCT v.id_combustivel) >= 3
ORDER BY v.tipo, v.valor;

\echo '== 10. Margem: deve ser NULL sempre que valor_compra for NULL'
SELECT COUNT(*) FILTER (WHERE valor_compra IS NULL)                     AS sem_valor_compra,
       COUNT(*) FILTER (WHERE valor_compra IS NULL AND margem IS NOT NULL) AS margem_indevida,
       COUNT(*) FILTER (WHERE valor_compra IS NOT NULL)                 AS com_valor_compra
FROM fato_preco_combustivel;

\echo '== 11. Duplicidades na fato (deve retornar 0 linhas)'
SELECT id_tempo, id_revenda, id_combustivel, COUNT(*)
FROM fato_preco_combustivel
GROUP BY id_tempo, id_revenda, id_combustivel
HAVING COUNT(*) > 1;

\echo '== 12. Registros rejeitados por motivo'
SELECT etapa, motivo, COUNT(*) AS registros
FROM etl_rejeitados
GROUP BY etapa, motivo
ORDER BY registros DESC;

\echo '== 13. Integridade: linhas da fato sem dimensão (deve ser 0 - garantido pelas FKs)'
SELECT COUNT(*) AS orfaos
FROM fato_preco_combustivel f
LEFT JOIN dim_tempo t       ON t.id_tempo       = f.id_tempo
LEFT JOIN dim_combustivel c ON c.id_combustivel = f.id_combustivel
LEFT JOIN dim_localizacao l ON l.id_localizacao = f.id_localizacao
LEFT JOIN dim_revenda r     ON r.id_revenda     = f.id_revenda
LEFT JOIN dim_bandeira b    ON b.id_bandeira    = f.id_bandeira
WHERE t.id_tempo IS NULL OR c.id_combustivel IS NULL OR l.id_localizacao IS NULL
   OR r.id_revenda IS NULL OR b.id_bandeira IS NULL;
