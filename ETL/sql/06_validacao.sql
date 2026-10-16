-- =============================================================================
-- 06_validacao.sql
-- Consultas de validação após executar o job 00_ETL_ANP_DataMart.
-- Modelo: dim_tempo (semestre), dim_local (posto + localização),
--         dim_combustivel, dim_bandeira; fato com 1 linha por coleta.
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

\echo '== 3. Período carregado (menor e maior data de coleta, primeiro e último semestre)'
SELECT MIN(f.data_coleta) AS menor_data, MAX(f.data_coleta) AS maior_data,
       MIN(t.periodo) AS primeiro_semestre, MAX(t.periodo) AS ultimo_semestre
FROM fato_preco_combustivel f
JOIN dim_tempo t ON t.id_tempo = f.id_tempo;

\echo '== 4. Estados presentes (deve existir somente PE)'
SELECT l.uf, l.estado, l.regiao, COUNT(*) AS registros
FROM fato_preco_combustivel f
JOIN dim_local l ON l.id_local = f.id_local
GROUP BY l.uf, l.estado, l.regiao;

\echo '== 5. Combustíveis carregados'
SELECT c.combustivel, c.categoria, c.unidade_medida, COUNT(*) AS registros
FROM fato_preco_combustivel f
JOIN dim_combustivel c ON c.id_combustivel = f.id_combustivel
GROUP BY c.combustivel, c.categoria, c.unidade_medida
ORDER BY registros DESC;

\echo '== 6. Municípios de Pernambuco'
/* Municípios de Pernambuco */

SELECT l.municipio, COUNT(*) AS registros, COUNT(DISTINCT f.id_local) AS postos
FROM fato_preco_combustivel f
JOIN dim_local l ON l.id_local = f.id_local
GROUP BY l.municipio
ORDER BY registros DESC;

\echo '== 6b. Postos por município (de onde é cada revenda)'
SELECT l.municipio, l.uf, l.cnpj, l.nome_revenda, l.bairro
FROM dim_local l
ORDER BY l.municipio, l.nome_revenda
LIMIT 20;

\echo '== 7. Semestres: todos os períodos esperados (2020.1 a 2026.1) e quantos registros cada um tem'
/* Semestres: todos os períodos esperados (2020.1 a 2026.1) e quantos registros cada um tem */

SELECT t.periodo AS semestre, t.nome_semestre, COUNT(f.id_tempo) AS registros,
       CASE WHEN COUNT(f.id_tempo) = 0 THEN 'SEM DADOS' ELSE 'OK' END AS situacao
FROM dim_tempo t
LEFT JOIN fato_preco_combustivel f ON f.id_tempo = t.id_tempo
GROUP BY t.periodo, t.nome_semestre
ORDER BY t.periodo;

\echo '== 7b. Semestre da fato confere com a data da coleta (deve ser 0)'
SELECT COUNT(*) AS semestre_divergente
FROM fato_preco_combustivel f
JOIN dim_tempo t ON t.id_tempo = f.id_tempo
WHERE f.semestre <> t.periodo
   OR t.ano <> EXTRACT(YEAR FROM f.data_coleta)
   OR t.semestre <> CASE WHEN EXTRACT(MONTH FROM f.data_coleta) <= 6 THEN 1 ELSE 2 END;

\echo '== 8. Estatísticas de valor_venda por combustível'
/* Estatísticas de valor_venda por combustível */

SELECT c.combustivel,
       MIN(f.valor_venda)              AS minimo,
       MAX(f.valor_venda)              AS maximo,
       ROUND(AVG(f.valor_venda), 2)    AS media,
       ROUND(STDDEV(f.valor_venda), 2) AS desvio_padrao
FROM fato_preco_combustivel f
JOIN dim_combustivel c ON c.id_combustivel = f.id_combustivel
GROUP BY c.combustivel
ORDER BY c.combustivel;

\echo '== 8b. Preço médio por combustível e semestre'
SELECT c.combustivel, t.periodo, ROUND(AVG(f.valor_venda), 2) AS preco_medio, COUNT(*) AS coletas
FROM fato_preco_combustivel f
JOIN dim_combustivel c ON c.id_combustivel = f.id_combustivel
JOIN dim_tempo t       ON t.id_tempo       = f.id_tempo
GROUP BY c.combustivel, t.periodo
ORDER BY c.combustivel, t.periodo;

\echo '== 9. Valores suspeitos: fora de média ± 3 desvios do mesmo combustível no mesmo mês'
/* Valores suspeitos: fora de média ± 3 desvios do mesmo combustível no mesmo mês */

WITH base AS (
    SELECT c.combustivel, f.data_coleta, l.cnpj, l.nome_revenda, l.municipio, f.valor_venda,
           AVG(f.valor_venda)    OVER (PARTITION BY f.id_combustivel, date_trunc('month', f.data_coleta)) AS media_mes,
           STDDEV(f.valor_venda) OVER (PARTITION BY f.id_combustivel, date_trunc('month', f.data_coleta)) AS desvio_mes
    FROM fato_preco_combustivel f
    JOIN dim_combustivel c ON c.id_combustivel = f.id_combustivel
    JOIN dim_local l       ON l.id_local       = f.id_local
)
SELECT combustivel, data_coleta, cnpj, nome_revenda, municipio, valor_venda,
       ROUND(media_mes, 2) AS media_mes, ROUND(desvio_mes, 2) AS desvio_mes
FROM base
WHERE desvio_mes > 0
  AND ABS(valor_venda - media_mes) > 3 * desvio_mes
ORDER BY combustivel, data_coleta;

\echo '== 10. Margem: deve ser NULL sempre que valor_compra for NULL'
SELECT COUNT(*) FILTER (WHERE valor_compra IS NULL)                     AS sem_valor_compra,
       COUNT(*) FILTER (WHERE valor_compra IS NULL AND margem IS NOT NULL) AS margem_indevida,
       COUNT(*) FILTER (WHERE valor_compra IS NOT NULL)                 AS com_valor_compra
FROM fato_preco_combustivel;

\echo '== 11. Duplicidades na fato (deve retornar 0 linhas)'
SELECT id_local, id_combustivel, data_coleta, COUNT(*)
FROM fato_preco_combustivel
GROUP BY id_local, id_combustivel, data_coleta
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
LEFT JOIN dim_local l       ON l.id_local       = f.id_local
LEFT JOIN dim_combustivel c ON c.id_combustivel = f.id_combustivel
LEFT JOIN dim_bandeira b    ON b.id_bandeira    = f.id_bandeira
WHERE t.id_tempo IS NULL OR l.id_local IS NULL OR c.id_combustivel IS NULL OR b.id_bandeira IS NULL;
