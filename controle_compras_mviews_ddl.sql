--------------------------------------------------------
--  Views do dashboard de compras
--  Executar como LAB depois de controle_compras_temporal_ddl.sql.
--
--  Fonte: última versão de cada compra em COMPRAS_HIST. COMPRAS guarda só a carga
--  vigente; o histórico tem todas as compras já carregadas, inclusive as removidas
--  por 'apagar'. Não unir com COMPRAS: a versão vigente já está no histórico e
--  seria contada duas vezes.
--
--  Idade e prazo vencido são medidos contra DT_CORTE, a data do pedido mais recente.
--  A planilha é uma fotografia de agosto/2026; contra SYSDATE, todo pedido em aberto
--  pareceria velho e quase todo prazo, vencido. Em operação, trocar por TRUNC(SYSDATE).
--
--  Pedido em aberto = status diferente de ENTREGUE. A data de chegada não serve:
--  boa parte dos pedidos entregues está sem ela.
--
--  As MVs guardam somas e contagens; médias e percentuais ficam no BI, para que os
--  filtros não produzam média de médias. Refresh: carga_planilha.py, ao fim de cada
--  carga ou exclusão (COMPLETE: as funções analíticas impedem o FAST).
--------------------------------------------------------

CREATE OR REPLACE VIEW "VW_COMPRAS_CONSOLIDADAS" AS
SELECT
    ch.COM_ID,
    ch.COM_DT_PEDIDO AS DT_PEDIDO,
    TRUNC(ch.COM_DT_PEDIDO, 'MM') AS MES_PEDIDO,
    os.OS_ID,
    os.OS_NUMERO,
    so.SOL_NOME AS SOLICITANTE,
    f.FOR_ID,
    f.FOR_NOME AS FORNECEDOR,
    m.MAT_NOME AS MATERIAL,
    COALESCE(p.PER_NOME, 'SEM PERFIL') AS PERFIL,
    COALESCE(st.STA_NOME, 'SEM STATUS') AS STATUS_PEDIDO,
    CASE WHEN st.STA_NOME = 'ENTREGUE' THEN 'N' ELSE 'S' END AS EM_ABERTO,
    cf.CON_FRE_NOME AS FRETE,
    ch.COM_QTD AS QTD,
    ch.COM_DT_PRAZO AS DT_PRAZO,
    ch.COM_DT_COMPRA_MATERIAL AS DT_COMPRA,
    ch.COM_DT_CHEGADA_MATERIAL AS DT_CHEGADA,
    ch.DT_CORTE,
    ch.DT_CORTE - ch.COM_DT_PEDIDO AS IDADE_DIAS
FROM (
    SELECT
        h.*,
        ROW_NUMBER() OVER (PARTITION BY h.COM_ID ORDER BY h.COM_HIST_DT_INICIO DESC) AS RN,
        MAX(h.COM_DT_PEDIDO) OVER () AS DT_CORTE
    FROM COMPRAS_HIST h
) ch
JOIN ORDENS_SERVICO os ON ch.COM_OS = os.OS_ID
JOIN SOLICITANTES so ON os.OS_SOLICITANTE = so.SOL_ID
JOIN FORNECEDORES f ON ch.COM_FORNECEDOR = f.FOR_ID
JOIN MATERIAIS m ON ch.COM_MATERIAL = m.MAT_ID
LEFT JOIN PERFIS p ON ch.COM_PERFIL = p.PER_ID
LEFT JOIN STATUS st ON ch.COM_STATUS = st.STA_ID
LEFT JOIN CONDICOES_FRETE cf ON ch.COM_FRETE = cf.CON_FRE_ID
WHERE ch.RN = 1;

-- Desempenho por fornecedor (consulta 1): concentração de pedidos, atraso, tempo de
-- cotação e de entrega, frete. Tempo médio = SOMA_DIAS_* / pedidos com a data.
CREATE MATERIALIZED VIEW "MV_DESEMPENHO_FORNECEDOR"
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT
    FOR_ID,
    FORNECEDOR,
    MES_PEDIDO,
    COUNT(*) AS TOTAL_PEDIDOS,
    SUM(QTD) AS QUANTIDADE_PECAS,
    COUNT(DT_COMPRA) AS PEDIDOS_COMPRADOS,
    COUNT(DT_CHEGADA) AS PEDIDOS_COM_CHEGADA,
    SUM(CASE WHEN DT_CHEGADA > DT_PRAZO THEN 1 ELSE 0 END) AS PEDIDOS_ATRASADOS,
    SUM(DT_COMPRA - DT_PEDIDO) AS SOMA_DIAS_COTACAO,
    SUM(DT_CHEGADA - DT_PEDIDO) AS SOMA_DIAS_ENTREGA,
    SUM(CASE WHEN FRETE = 'CIF' THEN 1 ELSE 0 END) AS PEDIDOS_CIF,
    SUM(CASE WHEN FRETE = 'FOB' THEN 1 ELSE 0 END) AS PEDIDOS_FOB
FROM VW_COMPRAS_CONSOLIDADAS
GROUP BY FOR_ID, FORNECEDOR, MES_PEDIDO;

-- Evolução mensal por status (consulta 3): demanda e mix de status de todos os pedidos.
CREATE MATERIALIZED VIEW "MV_EVOLUCAO_STATUS"
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT
    MES_PEDIDO,
    STATUS_PEDIDO,
    EM_ABERTO,
    COUNT(*) AS TOTAL_PEDIDOS,
    SUM(QTD) AS QUANTIDADE_PECAS
FROM VW_COMPRAS_CONSOLIDADAS
GROUP BY MES_PEDIDO, STATUS_PEDIDO, EM_ABERTO;

-- Backlog: só pedidos em aberto, por fornecedor e faixa de idade na data de corte.
-- ORDEM_FAIXA serve para ordenar FAIXA_IDADE no BI.
CREATE MATERIALIZED VIEW "MV_BACKLOG_COMPRAS"
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT
    MES_PEDIDO,
    STATUS_PEDIDO,
    FOR_ID,
    FORNECEDOR,
    DECODE(ORDEM_FAIXA, 1, '0-30', 2, '31-60', 3, '61-90', '90+') AS FAIXA_IDADE,
    ORDEM_FAIXA,
    COUNT(*) AS TOTAL_PEDIDOS,
    SUM(QTD) AS QUANTIDADE_PECAS,
    COUNT(*) - COUNT(DT_PRAZO) AS PEDIDOS_SEM_PRAZO,
    SUM(CASE WHEN DT_PRAZO < DT_CORTE THEN 1 ELSE 0 END) AS PEDIDOS_PRAZO_VENCIDO,
    MAX(IDADE_DIAS) AS IDADE_MAX_DIAS,
    DT_CORTE
FROM (
    SELECT
        v.*,
        CASE
            WHEN v.IDADE_DIAS <= 30 THEN 1
            WHEN v.IDADE_DIAS <= 60 THEN 2
            WHEN v.IDADE_DIAS <= 90 THEN 3
            ELSE 4
        END AS ORDEM_FAIXA
    FROM VW_COMPRAS_CONSOLIDADAS v
    WHERE v.EM_ABERTO = 'S'
)
GROUP BY MES_PEDIDO, STATUS_PEDIDO, FOR_ID, FORNECEDOR, ORDEM_FAIXA, DT_CORTE;

-- Prontidão das OS: a OS só entra em usinagem com todo o material entregue.
-- A carga cria uma ORDENS_SERVICO por par número + solicitante.
CREATE MATERIALIZED VIEW "MV_PRONTIDAO_OS"
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT
    OS_ID,
    OS_NUMERO,
    SOLICITANTE,
    DT_PRIMEIRO_PEDIDO,
    TRUNC(DT_PRIMEIRO_PEDIDO, 'MM') AS MES_PRIMEIRO_PEDIDO,
    ITENS_TOTAL,
    ITENS_ENTREGUES,
    ITENS_COTANDO,
    ITENS_PARADOS,
    FORNECEDORES_DISTINTOS,
    CASE
        WHEN ITENS_ENTREGUES = ITENS_TOTAL THEN 'PRONTA'
        WHEN ITENS_ENTREGUES = 0 THEN 'AGUARDANDO'
        ELSE 'PARCIAL'
    END AS SITUACAO_OS,
    CASE WHEN ITENS_ENTREGUES < ITENS_TOTAL THEN DT_CORTE - DT_PRIMEIRO_PEDIDO END AS DIAS_AGUARDANDO,
    PRAZO_ULTIMO_ITEM
FROM (
    SELECT
        OS_ID,
        OS_NUMERO,
        SOLICITANTE,
        MIN(DT_PEDIDO) AS DT_PRIMEIRO_PEDIDO,
        COUNT(*) AS ITENS_TOTAL,
        SUM(CASE WHEN EM_ABERTO = 'N' THEN 1 ELSE 0 END) AS ITENS_ENTREGUES,
        SUM(CASE WHEN STATUS_PEDIDO = 'COTANDO' THEN 1 ELSE 0 END) AS ITENS_COTANDO,
        SUM(CASE WHEN STATUS_PEDIDO = 'PARADO' THEN 1 ELSE 0 END) AS ITENS_PARADOS,
        COUNT(DISTINCT FOR_ID) AS FORNECEDORES_DISTINTOS,
        MAX(CASE WHEN EM_ABERTO = 'S' THEN DT_PRAZO END) AS PRAZO_ULTIMO_ITEM,
        MAX(DT_CORTE) AS DT_CORTE
    FROM VW_COMPRAS_CONSOLIDADAS
    GROUP BY OS_ID, OS_NUMERO, SOLICITANTE
);
