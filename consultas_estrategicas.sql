-- =============================================================================
-- CONSULTAS ESTRATÉGICAS - CONTROLE DE COMPRAS E USINAGEM
--
-- As consultas não possuem WHERE ou HAVING. Recortes por período, fornecedor,
-- status, material, OS ou demais dimensões devem ser aplicados no BI.
-- =============================================================================

-- 1. Desempenho de entrega por fornecedor
-- Permite comparar volume, entregas registradas, atrasos e prazo médio.
SELECT
    f.FOR_NOME AS Fornecedor,
    COUNT(c.COM_ID) AS Total_Pedidos,
    COUNT(c.COM_DT_CHEGADA_MATERIAL) AS Pedidos_Com_Chegada_Registrada,
    SUM(
        CASE
            WHEN c.COM_DT_CHEGADA_MATERIAL > c.COM_DT_PRAZO THEN 1
            ELSE 0
        END
    ) AS Pedidos_Atrasados,
    ROUND(AVG(c.COM_DT_CHEGADA_MATERIAL - c.COM_DT_PEDIDO), 1) AS Tempo_Medio_Entrega_Dias
FROM COMPRAS c
JOIN FORNECEDORES f ON c.COM_FORNECEDOR = f.FOR_ID
GROUP BY f.FOR_NOME
ORDER BY Pedidos_Atrasados DESC, Total_Pedidos DESC;

-- 2. Curva de consumo por material e perfil
-- Mostra os materiais e formatos com maior volume e frequência de aquisição.
SELECT
    m.MAT_NOME AS Material,
    p.PER_NOME AS Perfil,
    SUM(c.COM_QTD) AS Quantidade_Total_Comprada,
    COUNT(c.COM_ID) AS Frequencia_Compras
FROM COMPRAS c
JOIN MATERIAIS m ON c.COM_MATERIAL = m.MAT_ID
LEFT JOIN PERFIS p ON c.COM_PERFIL = p.PER_ID
GROUP BY m.MAT_NOME, p.PER_NOME
ORDER BY Quantidade_Total_Comprada DESC;

-- 3. Evolução mensal de compras por status
-- Base para gráficos de tendência e acompanhamento do funil de compras.
SELECT
    TO_CHAR(c.COM_DT_PEDIDO, 'YYYY-MM') AS Mes_Ano,
    st.STA_NOME AS Status_Pedido,
    COUNT(c.COM_ID) AS Total_Pedidos,
    SUM(c.COM_QTD) AS Quantidade_Total_Comprada
FROM COMPRAS c
LEFT JOIN STATUS st ON c.COM_STATUS = st.STA_ID
GROUP BY TO_CHAR(c.COM_DT_PEDIDO, 'YYYY-MM'), st.STA_NOME
ORDER BY Mes_Ano DESC, Total_Pedidos DESC;

-- 4. Matriz de especialidade de fornecedores
-- Evidencia a recorrência e o volume comprado de cada material por fornecedor.
SELECT
    m.MAT_NOME AS Material,
    f.FOR_NOME AS Fornecedor,
    COUNT(c.COM_ID) AS Frequencia_Pedidos,
    SUM(c.COM_QTD) AS Volume_Total_Pecas
FROM COMPRAS c
JOIN MATERIAIS m ON c.COM_MATERIAL = m.MAT_ID
JOIN FORNECEDORES f ON c.COM_FORNECEDOR = f.FOR_ID
GROUP BY m.MAT_NOME, f.FOR_NOME
ORDER BY Material ASC, Frequencia_Pedidos DESC;

-- =============================================================================
-- CONSULTAS ESTRATÉGICAS: DADOS CORRENTES E HISTÓRICOS
-- Cada consulta une os registros correntes às versões históricas. Origem_Dados
-- deve permanecer disponível no BI para separar pedidos vigentes de versões.
-- Não há WHERE ou HAVING: os recortes devem ser aplicados no BI.
-- =============================================================================

-- 5. Desempenho de entrega por fornecedor em todos os períodos
SELECT
    Fornecedor,
    Origem_Dados,
    COUNT(*) AS Total_Registros,
    COUNT(Data_Chegada_Material) AS Registros_Com_Chegada,
    SUM(
        CASE
            WHEN Data_Chegada_Material > Data_Prazo THEN 1
            ELSE 0
        END
    ) AS Registros_Atrasados,
    ROUND(AVG(Data_Chegada_Material - Data_Pedido), 1) AS Tempo_Medio_Entrega_Dias
FROM (
    SELECT
        f.FOR_NOME AS Fornecedor,
        'CORRENTE' AS Origem_Dados,
        c.COM_DT_PEDIDO AS Data_Pedido,
        c.COM_DT_PRAZO AS Data_Prazo,
        c.COM_DT_CHEGADA_MATERIAL AS Data_Chegada_Material
    FROM COMPRAS c
    JOIN FORNECEDORES f ON c.COM_FORNECEDOR = f.FOR_ID
    UNION ALL
    SELECT
        COALESCE(fh.FOR_NOME, 'FORNECEDOR NÃO IDENTIFICADO') AS Fornecedor,
        'HISTORICO' AS Origem_Dados,
        ch.COM_DT_PEDIDO AS Data_Pedido,
        ch.COM_DT_PRAZO AS Data_Prazo,
        ch.COM_DT_CHEGADA_MATERIAL AS Data_Chegada_Material
    FROM COMPRAS_HIST ch
    LEFT JOIN FORNECEDORES_HIST fh
        ON ch.COM_FORNECEDOR = fh.FOR_ID
       AND ch.COM_HIST_DT_INICIO >= fh.FOR_HIST_DT_INICIO
       AND (ch.COM_HIST_DT_INICIO < fh.FOR_HIST_DT_FIM OR fh.FOR_HIST_DT_FIM IS NULL)
)
GROUP BY Fornecedor, Origem_Dados
ORDER BY Registros_Atrasados DESC, Total_Registros DESC;

-- 6. Curva de consumo por material e perfil em todos os períodos
SELECT
    Material,
    Perfil,
    Origem_Dados,
    SUM(Quantidade) AS Quantidade_Total,
    COUNT(*) AS Frequencia_Registros
FROM (
    SELECT
        m.MAT_NOME AS Material,
        COALESCE(p.PER_NOME, 'SEM PERFIL') AS Perfil,
        'CORRENTE' AS Origem_Dados,
        c.COM_QTD AS Quantidade
    FROM COMPRAS c
    JOIN MATERIAIS m ON c.COM_MATERIAL = m.MAT_ID
    LEFT JOIN PERFIS p ON c.COM_PERFIL = p.PER_ID
    UNION ALL
    SELECT
        COALESCE(mh.MAT_NOME, 'MATERIAL NÃO IDENTIFICADO') AS Material,
        COALESCE(ph.PER_NOME, 'SEM PERFIL') AS Perfil,
        'HISTORICO' AS Origem_Dados,
        ch.COM_QTD AS Quantidade
    FROM COMPRAS_HIST ch
    LEFT JOIN MATERIAIS_HIST mh
        ON ch.COM_MATERIAL = mh.MAT_ID
       AND ch.COM_HIST_DT_INICIO >= mh.MAT_HIST_DT_INICIO
       AND (ch.COM_HIST_DT_INICIO < mh.MAT_HIST_DT_FIM OR mh.MAT_HIST_DT_FIM IS NULL)
    LEFT JOIN PERFIS_HIST ph
        ON ch.COM_PERFIL = ph.PER_ID
       AND ch.COM_HIST_DT_INICIO >= ph.PER_HIST_DT_INICIO
       AND (ch.COM_HIST_DT_INICIO < ph.PER_HIST_DT_FIM OR ph.PER_HIST_DT_FIM IS NULL)
)
GROUP BY Material, Perfil, Origem_Dados
ORDER BY Quantidade_Total DESC;

-- 7. Evolução mensal de compras por status em todos os períodos
SELECT
    TO_CHAR(Data_Referencia, 'YYYY-MM') AS Mes_Ano,
    Status_Pedido,
    Origem_Dados,
    COUNT(*) AS Total_Registros,
    SUM(Quantidade) AS Quantidade_Total
FROM (
    SELECT
        c.COM_DT_PEDIDO AS Data_Referencia,
        COALESCE(st.STA_NOME, 'STATUS NÃO IDENTIFICADO') AS Status_Pedido,
        'CORRENTE' AS Origem_Dados,
        c.COM_QTD AS Quantidade
    FROM COMPRAS c
    LEFT JOIN STATUS st ON c.COM_STATUS = st.STA_ID
    UNION ALL
    SELECT
        ch.COM_HIST_DT_INICIO AS Data_Referencia,
        COALESCE(sh.STA_NOME, 'STATUS NÃO IDENTIFICADO') AS Status_Pedido,
        'HISTORICO' AS Origem_Dados,
        ch.COM_QTD AS Quantidade
    FROM COMPRAS_HIST ch
    LEFT JOIN STATUS_HIST sh
        ON ch.COM_STATUS = sh.STA_ID
       AND ch.COM_HIST_DT_INICIO >= sh.STA_HIST_DT_INICIO
       AND (ch.COM_HIST_DT_INICIO < sh.STA_HIST_DT_FIM OR sh.STA_HIST_DT_FIM IS NULL)
)
GROUP BY TO_CHAR(Data_Referencia, 'YYYY-MM'), Status_Pedido, Origem_Dados
ORDER BY Mes_Ano DESC, Total_Registros DESC;

-- 8. Matriz de especialidade de fornecedores em todos os períodos
SELECT
    Material,
    Fornecedor,
    Origem_Dados,
    COUNT(*) AS Frequencia_Registros,
    SUM(Quantidade) AS Volume_Total
FROM (
    SELECT
        m.MAT_NOME AS Material,
        f.FOR_NOME AS Fornecedor,
        'CORRENTE' AS Origem_Dados,
        c.COM_QTD AS Quantidade
    FROM COMPRAS c
    JOIN MATERIAIS m ON c.COM_MATERIAL = m.MAT_ID
    JOIN FORNECEDORES f ON c.COM_FORNECEDOR = f.FOR_ID
    UNION ALL
    SELECT
        COALESCE(mh.MAT_NOME, 'MATERIAL NÃO IDENTIFICADO') AS Material,
        COALESCE(fh.FOR_NOME, 'FORNECEDOR NÃO IDENTIFICADO') AS Fornecedor,
        'HISTORICO' AS Origem_Dados,
        ch.COM_QTD AS Quantidade
    FROM COMPRAS_HIST ch
    LEFT JOIN MATERIAIS_HIST mh
        ON ch.COM_MATERIAL = mh.MAT_ID
       AND ch.COM_HIST_DT_INICIO >= mh.MAT_HIST_DT_INICIO
       AND (ch.COM_HIST_DT_INICIO < mh.MAT_HIST_DT_FIM OR mh.MAT_HIST_DT_FIM IS NULL)
    LEFT JOIN FORNECEDORES_HIST fh
        ON ch.COM_FORNECEDOR = fh.FOR_ID
       AND ch.COM_HIST_DT_INICIO >= fh.FOR_HIST_DT_INICIO
       AND (ch.COM_HIST_DT_INICIO < fh.FOR_HIST_DT_FIM OR fh.FOR_HIST_DT_FIM IS NULL)
)
GROUP BY Material, Fornecedor, Origem_Dados
ORDER BY Material ASC, Frequencia_Registros DESC;
