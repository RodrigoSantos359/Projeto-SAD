# Projeto da cadeira Sistema de Apoio a decisão

## Data Mart de preços de combustíveis


Processo ETL em **Pentaho Data Integration (PDI)** que lê os arquivos de preços de
combustíveis da **ANP**, faz limpeza, padronização e validação, e carrega um Data Mart
dimensional no **PostgreSQL**, restrito ao estado de **Pernambuco** entre
**01/01/2020 e 30/06/2026** (períodos 2020.1 a 2026.1).

```text
CSV bruto da ANP (semestral, nacional) → validação do layout → filtro PE → STAGING bruta → limpeza/validação
→ STAGING limpa → dimensões → fato → controle da carga
                         ↘ etl_rejeitados (nada é descartado em silêncio)
```
###### Fonte dos dados brutos: [Série Histórica de Preços de Combustíveis](https://www.gov.br/anp/pt-br/centrais-de-conteudo/dados-abertos/serie-historica-de-precos-de-combustiveis)

**Estrutura do banco**

```text
                    dim_tempo (id_tempo = AAAAMMDD)
                         │
dim_combustivel ── fato_preco_combustivel ── dim_localizacao
                     │            │
               dim_revenda    dim_bandeira
```

Foi utilizado o Docker para criar um container para o banco de dados Postgres, para ter uma melhor organização do projeto,
abaixo irei mostra alguns comandos para a criação do database e das tabelas desse projeto.

```bash
# 1) banco (conectado ao banco postgres) 
docker exec -i dw_combustiveis psql -U postgres -d postgres          < sql/01_create_database.sql
# 2) a 5) tabelas e índices (conectado ao novo banco)
docker exec -i dw_combustiveis psql -U postgres -d dm_anp_pernambuco < sql/02_create_staging.sql
docker exec -i dw_combustiveis psql -U postgres -d dm_anp_pernambuco < sql/03_create_dimensions.sql
docker exec -i dw_combustiveis psql -U postgres -d dm_anp_pernambuco < sql/04_create_fact.sql
docker exec -i dw_combustiveis psql -U postgres -d dm_anp_pernambuco < sql/05_indexes.sql

```
Veja os arquivos na pasta:

- [01_create_database.sql](ETL/sql/01_create_database.sql)

- [02_create_staging.sql](ETL/sql/02_create_staging.sql)

- [03_create_dimensions.sql](ETL/sql/03_create_dimensions.sql)

- [04_create_fact.sql](ETL/sql/04_create_fact.sql)

- [05_indexes.sql](ETL/sql/05_indexes.sql)

### Plano de Carga ELT:

<div align="center">

00_ETLANP_DataMart.ktr

<img alt="GitHub language count" src=https://github.com/RodrigoSantos359/Projeto-SAD/blob/main/ETL/prints/00_ETL_ANP_DataMart.png width="420px">


00_Validar_Layout.ktr

<img alt="GitHub language count" src=https://github.com/RodrigoSantos359/Projeto-SAD/blob/main/ETL/prints/00_Validar_layout.png width="420px">

01_Carga_Staging.ktr

<img alt="GitHub language count" src=https://github.com/RodrigoSantos359/Projeto-SAD/blob/main/ETL/prints/01_Carga_Staging.png width="420px">

02_Limpeza_Dados.ktr

<img alt="GitHub language count" src=https://github.com/RodrigoSantos359/Projeto-SAD/blob/main/ETL/prints/02_Limpeza_Dados.png width="420px">

03_Dim_Tempo.ktr

<img alt="GitHub language count" src=https://github.com/RodrigoSantos359/Projeto-SAD/blob/main/ETL/prints/03_Dim_Tempo.png width="420px">

04_Dim_Combustivel.ktr

<img alt="GitHub language count" src=https://github.com/RodrigoSantos359/Projeto-SAD/blob/main/ETL/prints/04_Dim_Combustivel.png width="420px">

05_Dim_Localizacao.ktr

<img alt="GitHub language count" src=https://github.com/RodrigoSantos359/Projeto-SAD/blob/main/ETL/prints/05_Dim_Localizacao.png width="420px">

06_Dim_Revenda.ktr

<img alt="GitHub language count" src=https://github.com/RodrigoSantos359/Projeto-SAD/blob/main/ETL/prints/06_Dim_Revenda.png width="420px">

07_Dim_Bandeira.ktr

<img alt="GitHub language count" src=https://github.com/RodrigoSantos359/Projeto-SAD/blob/main/ETL/prints/07_Dim_Bandeira.png width="420px">

08_Carga_Fato_Preco

<img alt="GitHub language count" src=https://github.com/RodrigoSantos359/Projeto-SAD/blob/main/ETL/prints/08_Carga_Fato_Preco.png width="420px">

</div>