-- =====================================================================
-- Projeto: Dashboard Patrimonial - Análise de Carteira de Clientes
-- Autor: Pablo H.
-- =====================================================================

-- =====================================================================
-- 1) CRIAÇÃO DAS TABELAS
-- =====================================================================

DROP TABLE IF EXISTS saldos_mensais;
DROP TABLE IF EXISTS clientes;

CREATE TABLE clientes (
    id_cliente INTEGER PRIMARY KEY,
    nome_cliente TEXT,
    data_entrada DATE,
    tipo_cliente TEXT
);

CREATE TABLE saldos_mensais (
    id_cliente INTEGER,
    data DATE,
    valor_mes REAL,
    status TEXT,
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
);

-- Após criar as tabelas, importar clientes.csv -> clientes
-- e saldos_mensais.csv -> saldos_mensais (INSERT INTO gerado pela
-- ferramenta de import, sem repetir o CREATE TABLE).


-- =====================================================================
-- 2) VALIDAÇÃO DA CARGA DE DADOS
-- =====================================================================

SELECT COUNT(*) FROM clientes;         -- esperado: 500
SELECT COUNT(*) FROM saldos_mensais;   -- esperado: ~7300


-- =====================================================================
-- 3) PERGUNTAS DE NEGÓCIO
-- =====================================================================

-- --------------------------------------------------------------------
-- 3.1) Quantos clientes ativos temos, com saldo entre 100k e 500k?
-- Resultado: 79
-- --------------------------------------------------------------------
SELECT COUNT(*) 
FROM saldos_mensais
WHERE data = (SELECT MAX(data) FROM saldos_mensais)
  AND status = 'Ativo'
  AND valor_mes BETWEEN 100000 AND 500000;


-- --------------------------------------------------------------------
-- 3.2) Quantos clientes novos entraram entre março e maio de 2026?
-- Resultado: 38
-- --------------------------------------------------------------------
SELECT COUNT(*)
FROM clientes
WHERE data_entrada BETWEEN '2026-03-01' AND '2026-05-31';


-- --------------------------------------------------------------------
-- 3.3) Quantos clientes ativos temos hoje (total)?
-- Resultado: 274
-- --------------------------------------------------------------------
SELECT COUNT(*) 
FROM saldos_mensais
WHERE data = (SELECT MAX(data) FROM saldos_mensais)
  AND status = 'Ativo';


-- =====================================================================
-- 4) ANÁLISE DE CHURN
-- =====================================================================

-- --------------------------------------------------------------------
-- 4.1) Encerramentos de conta por ano (visão "bruta", ano completo)
-- Resultado: 2023=32, 2024=64, 2025=78, 2026=52 (2026 incompleto!)
-- --------------------------------------------------------------------
SELECT 
    strftime('%Y', data) AS ano_encerramento,
    COUNT(*) AS qtd_clientes_encerrados
FROM saldos_mensais
WHERE status = 'Encerrado'
GROUP BY ano_encerramento
ORDER BY ano_encerramento;


-- --------------------------------------------------------------------
-- 4.2) Churn comparando SÓ o 1º semestre de 2025 vs 2026
--      (comparação justa - elimina viés de ano incompleto)
-- Resultado: 2025=37, 2026=52
-- --------------------------------------------------------------------
SELECT 
    strftime('%Y', data) AS ano,
    COUNT(*) AS qtd_encerrados
FROM saldos_mensais
WHERE status = 'Encerrado'
  AND (
        (data BETWEEN '2025-01-01' AND '2025-06-30')
        OR 
        (data BETWEEN '2026-01-01' AND '2026-06-30')
      )
GROUP BY ano
ORDER BY ano;


-- --------------------------------------------------------------------
-- 4.3) Churn no 1º semestre de TODOS os anos (visão de tendência)
-- Resultado: 2023=7, 2024=24, 2025=37, 2026=52
-- --------------------------------------------------------------------
SELECT 
    strftime('%Y', data) AS ano,
    COUNT(*) AS qtd_encerrados_1_semestre
FROM saldos_mensais
WHERE status = 'Encerrado'
  AND strftime('%m', data) <= '06'
GROUP BY ano
ORDER BY ano;


-- --------------------------------------------------------------------
-- 4.4) Mix de tipo de cliente entre os que encerraram conta, por ano
-- --------------------------------------------------------------------
SELECT 
    strftime('%Y', s.data) AS ano,
    c.tipo_cliente,
    COUNT(*) AS qtd_encerrados
FROM saldos_mensais s
JOIN clientes c 
    ON s.id_cliente = c.id_cliente
WHERE s.status = 'Encerrado'
GROUP BY ano, c.tipo_cliente
ORDER BY ano, c.tipo_cliente;


-- =====================================================================
-- 5) ANÁLISE DE CONCENTRAÇÃO DE PATRIMÔNIO (RISCO)
-- =====================================================================

-- --------------------------------------------------------------------
-- 5.1) Concentração do patrimônio atual por tipo de cliente
-- Resultado: Private 49% (57 clientes, ~R$9,87M) 
--            Varejo  51% (217 clientes, ~R$10,28M)
-- --------------------------------------------------------------------
SELECT 
    c.tipo_cliente,
    COUNT(*) AS qtd_clientes,
    SUM(s.valor_mes) AS patrimonio_total,
    ROUND(100.0 * SUM(s.valor_mes) / (
        SELECT SUM(valor_mes) 
        FROM saldos_mensais 
        WHERE data = (SELECT MAX(data) FROM saldos_mensais) 
          AND status = 'Ativo'
    ), 1) AS percentual_do_total
FROM saldos_mensais s
JOIN clientes c 
    ON s.id_cliente = c.id_cliente
WHERE s.data = (SELECT MAX(data) FROM saldos_mensais)
  AND s.status = 'Ativo'
GROUP BY c.tipo_cliente;


-- --------------------------------------------------------------------
-- 5.2) Evolução do patrimônio total (AUM) por ano
--      Usa CTE para achar o último mês disponível de cada ano
-- Resultado: 2023=R$11,06M, 2024=R$14,43M, 2025=R$18,04M, 2026=R$20,14M
-- --------------------------------------------------------------------
WITH ultimo_mes_por_ano AS (
    SELECT 
        strftime('%Y', data) AS ano,
        MAX(data) AS ultima_data
    FROM saldos_mensais
    GROUP BY ano
)
SELECT 
    u.ano,
    SUM(s.valor_mes) AS patrimonio_total
FROM saldos_mensais s
JOIN ultimo_mes_por_ano u
    ON s.data = u.ultima_data
WHERE s.status = 'Ativo'
GROUP BY u.ano
ORDER BY u.ano;
