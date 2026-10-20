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
-- CONSULTAS ESTRATÉGICAS HISTÓRICAS
-- Cada linha de COMPRAS_HIST representa uma versão da compra. Os JOINs temporais
-- recuperam os nomes de dimensão vigentes quando a versão foi registrada.
-- Não há WHERE ou HAVING: os recortes devem ser aplicados no BI.
-- =============================================================================

-- 5. Desempenho histórico de entrega por fornecedor
-- Compara as versões de compras por fornecedor, incluindo entregas e atrasos.
SELECT
    COALESCE(fh.FOR_NOME, 'FORNECEDOR NÃO IDENTIFICADO') AS Fornecedor,
    COUNT(ch.COM_HIST_ID) AS Total_Versoes_Compra,
    COUNT(ch.COM_DT_CHEGADA_MATERIAL) AS Versoes_Com_Chegada_Registrada,
    SUM(
        CASE
            WHEN ch.COM_DT_CHEGADA_MATERIAL > ch.COM_DT_PRAZO THEN 1
            ELSE 0
        END
    ) AS Versoes_Atrasadas,
    ROUND(AVG(ch.COM_DT_CHEGADA_MATERIAL - ch.COM_DT_PEDIDO), 1) AS Tempo_Medio_Entrega_Dias
FROM COMPRAS_HIST ch
LEFT JOIN FORNECEDORES_HIST fh
    ON ch.COM_FORNECEDOR = fh.FOR_ID
   AND ch.COM_HIST_DT_INICIO >= fh.FOR_HIST_DT_INICIO
   AND (ch.COM_HIST_DT_INICIO < fh.FOR_HIST_DT_FIM OR fh.FOR_HIST_DT_FIM IS NULL)
GROUP BY COALESCE(fh.FOR_NOME, 'FORNECEDOR NÃO IDENTIFICADO')
ORDER BY Versoes_Atrasadas DESC, Total_Versoes_Compra DESC;

-- 6. Curva histórica de consumo por material e perfil
-- Mostra quantidade e frequência acumuladas em todas as versões registradas.
SELECT
    COALESCE(mh.MAT_NOME, 'MATERIAL NÃO IDENTIFICADO') AS Material,
    COALESCE(ph.PER_NOME, 'SEM PERFIL') AS Perfil,
    SUM(ch.COM_QTD) AS Quantidade_Acumulada_Nas_Versoes,
    COUNT(ch.COM_HIST_ID) AS Frequencia_Versoes
FROM COMPRAS_HIST ch
LEFT JOIN MATERIAIS_HIST mh
    ON ch.COM_MATERIAL = mh.MAT_ID
   AND ch.COM_HIST_DT_INICIO >= mh.MAT_HIST_DT_INICIO
   AND (ch.COM_HIST_DT_INICIO < mh.MAT_HIST_DT_FIM OR mh.MAT_HIST_DT_FIM IS NULL)
LEFT JOIN PERFIS_HIST ph
    ON ch.COM_PERFIL = ph.PER_ID
   AND ch.COM_HIST_DT_INICIO >= ph.PER_HIST_DT_INICIO
   AND (ch.COM_HIST_DT_INICIO < ph.PER_HIST_DT_FIM OR ph.PER_HIST_DT_FIM IS NULL)
GROUP BY
    COALESCE(mh.MAT_NOME, 'MATERIAL NÃO IDENTIFICADO'),
    COALESCE(ph.PER_NOME, 'SEM PERFIL')
ORDER BY Quantidade_Acumulada_Nas_Versoes DESC;

-- 7. Evolução mensal das versões de compras por status
-- A data da versão indica quando a informação entrou no histórico.
SELECT
    TO_CHAR(ch.COM_HIST_DT_INICIO, 'YYYY-MM') AS Mes_Ano,
    COALESCE(sh.STA_NOME, 'STATUS NÃO IDENTIFICADO') AS Status_Pedido,
    COUNT(ch.COM_HIST_ID) AS Total_Versoes_Compra,
    SUM(ch.COM_QTD) AS Quantidade_Acumulada_Nas_Versoes
FROM COMPRAS_HIST ch
LEFT JOIN STATUS_HIST sh
    ON ch.COM_STATUS = sh.STA_ID
   AND ch.COM_HIST_DT_INICIO >= sh.STA_HIST_DT_INICIO
   AND (ch.COM_HIST_DT_INICIO < sh.STA_HIST_DT_FIM OR sh.STA_HIST_DT_FIM IS NULL)
GROUP BY
    TO_CHAR(ch.COM_HIST_DT_INICIO, 'YYYY-MM'),
    COALESCE(sh.STA_NOME, 'STATUS NÃO IDENTIFICADO')
ORDER BY Mes_Ano DESC, Total_Versoes_Compra DESC;

-- 8. Matriz histórica de especialidade de fornecedores
-- Evidencia a recorrência e o volume de versões por material e fornecedor.
SELECT
    COALESCE(mh.MAT_NOME, 'MATERIAL NÃO IDENTIFICADO') AS Material,
    COALESCE(fh.FOR_NOME, 'FORNECEDOR NÃO IDENTIFICADO') AS Fornecedor,
    COUNT(ch.COM_HIST_ID) AS Frequencia_Versoes,
    SUM(ch.COM_QTD) AS Volume_Acumulado_Nas_Versoes
FROM COMPRAS_HIST ch
LEFT JOIN MATERIAIS_HIST mh
    ON ch.COM_MATERIAL = mh.MAT_ID
   AND ch.COM_HIST_DT_INICIO >= mh.MAT_HIST_DT_INICIO
   AND (ch.COM_HIST_DT_INICIO < mh.MAT_HIST_DT_FIM OR mh.MAT_HIST_DT_FIM IS NULL)
LEFT JOIN FORNECEDORES_HIST fh
    ON ch.COM_FORNECEDOR = fh.FOR_ID
   AND ch.COM_HIST_DT_INICIO >= fh.FOR_HIST_DT_INICIO
   AND (ch.COM_HIST_DT_INICIO < fh.FOR_HIST_DT_FIM OR fh.FOR_HIST_DT_FIM IS NULL)
GROUP BY
    COALESCE(mh.MAT_NOME, 'MATERIAL NÃO IDENTIFICADO'),
    COALESCE(fh.FOR_NOME, 'FORNECEDOR NÃO IDENTIFICADO')
ORDER BY Material ASC, Frequencia_Versoes DESC;
