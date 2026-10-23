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
-- Cada consulta une a tabela corrente (COMPRAS, versão vigente) às versões
-- encerradas de COMPRAS_HIST (COM_HIST_DT_FIM preenchido: versão substituída por
-- UPDATE ou removida por DELETE) e agrega tudo. A versão vigente não é lida do
-- histórico porque já vem de COMPRAS, o que evita contá-la duas vezes.
-- Na parte histórica, os JOINs temporais recuperam os nomes de dimensão vigentes
-- quando a versão foi registrada.
-- O único WHERE é essa exclusão da versão vigente do histórico: os recortes por
-- período, fornecedor, status etc. devem ser aplicados no BI.
-- =============================================================================

-- 5. Desempenho histórico de entrega por fornecedor
-- Compara as versões de compras (vigentes e encerradas) por fornecedor, incluindo entregas e atrasos.
WITH compras_versoes AS (
    SELECT
        c.COM_ID,
        f.FOR_NOME AS Fornecedor,
        c.COM_DT_PEDIDO,
        c.COM_DT_PRAZO,
        c.COM_DT_CHEGADA_MATERIAL
    FROM COMPRAS c
    LEFT JOIN FORNECEDORES f ON c.COM_FORNECEDOR = f.FOR_ID
    UNION ALL
    SELECT
        ch.COM_ID,
        fh.FOR_NOME,
        ch.COM_DT_PEDIDO,
        ch.COM_DT_PRAZO,
        ch.COM_DT_CHEGADA_MATERIAL
    FROM COMPRAS_HIST ch
    LEFT JOIN FORNECEDORES_HIST fh
        ON ch.COM_FORNECEDOR = fh.FOR_ID
       AND ch.COM_HIST_DT_INICIO >= fh.FOR_HIST_DT_INICIO
       AND (ch.COM_HIST_DT_INICIO < fh.FOR_HIST_DT_FIM OR fh.FOR_HIST_DT_FIM IS NULL)
    WHERE ch.COM_HIST_DT_FIM IS NOT NULL
)
SELECT
    COALESCE(v.Fornecedor, 'FORNECEDOR NÃO IDENTIFICADO') AS Fornecedor,
    COUNT(v.COM_ID) AS Total_Versoes_Compra,
    COUNT(v.COM_DT_CHEGADA_MATERIAL) AS Versoes_Com_Chegada_Registrada,
    SUM(
        CASE
            WHEN v.COM_DT_CHEGADA_MATERIAL > v.COM_DT_PRAZO THEN 1
            ELSE 0
        END
    ) AS Versoes_Atrasadas,
    ROUND(AVG(v.COM_DT_CHEGADA_MATERIAL - v.COM_DT_PEDIDO), 1) AS Tempo_Medio_Entrega_Dias
FROM compras_versoes v
GROUP BY COALESCE(v.Fornecedor, 'FORNECEDOR NÃO IDENTIFICADO')
ORDER BY Versoes_Atrasadas DESC, Total_Versoes_Compra DESC;

-- 6. Curva histórica de consumo por material e perfil
-- Mostra quantidade e frequência acumuladas nas versões vigentes e encerradas.
WITH compras_versoes AS (
    SELECT
        c.COM_ID,
        c.COM_QTD,
        m.MAT_NOME AS Material,
        p.PER_NOME AS Perfil
    FROM COMPRAS c
    LEFT JOIN MATERIAIS m ON c.COM_MATERIAL = m.MAT_ID
    LEFT JOIN PERFIS p ON c.COM_PERFIL = p.PER_ID
    UNION ALL
    SELECT
        ch.COM_ID,
        ch.COM_QTD,
        mh.MAT_NOME,
        ph.PER_NOME
    FROM COMPRAS_HIST ch
    LEFT JOIN MATERIAIS_HIST mh
        ON ch.COM_MATERIAL = mh.MAT_ID
       AND ch.COM_HIST_DT_INICIO >= mh.MAT_HIST_DT_INICIO
       AND (ch.COM_HIST_DT_INICIO < mh.MAT_HIST_DT_FIM OR mh.MAT_HIST_DT_FIM IS NULL)
    LEFT JOIN PERFIS_HIST ph
        ON ch.COM_PERFIL = ph.PER_ID
       AND ch.COM_HIST_DT_INICIO >= ph.PER_HIST_DT_INICIO
       AND (ch.COM_HIST_DT_INICIO < ph.PER_HIST_DT_FIM OR ph.PER_HIST_DT_FIM IS NULL)
    WHERE ch.COM_HIST_DT_FIM IS NOT NULL
)
SELECT
    COALESCE(v.Material, 'MATERIAL NÃO IDENTIFICADO') AS Material,
    COALESCE(v.Perfil, 'SEM PERFIL') AS Perfil,
    SUM(v.COM_QTD) AS Quantidade_Acumulada_Nas_Versoes,
    COUNT(v.COM_ID) AS Frequencia_Versoes
FROM compras_versoes v
GROUP BY
    COALESCE(v.Material, 'MATERIAL NÃO IDENTIFICADO'),
    COALESCE(v.Perfil, 'SEM PERFIL')
ORDER BY Quantidade_Acumulada_Nas_Versoes DESC;

-- 7. Evolução mensal das versões de compras por status
-- O mês é o do pedido (COM_DT_PEDIDO), comum à tabela corrente e ao histórico.
WITH compras_versoes AS (
    SELECT
        c.COM_ID,
        c.COM_DT_PEDIDO,
        c.COM_QTD,
        st.STA_NOME AS Status_Pedido
    FROM COMPRAS c
    LEFT JOIN STATUS st ON c.COM_STATUS = st.STA_ID
    UNION ALL
    SELECT
        ch.COM_ID,
        ch.COM_DT_PEDIDO,
        ch.COM_QTD,
        sh.STA_NOME
    FROM COMPRAS_HIST ch
    LEFT JOIN STATUS_HIST sh
        ON ch.COM_STATUS = sh.STA_ID
       AND ch.COM_HIST_DT_INICIO >= sh.STA_HIST_DT_INICIO
       AND (ch.COM_HIST_DT_INICIO < sh.STA_HIST_DT_FIM OR sh.STA_HIST_DT_FIM IS NULL)
    WHERE ch.COM_HIST_DT_FIM IS NOT NULL
)
SELECT
    TO_CHAR(v.COM_DT_PEDIDO, 'YYYY-MM') AS Mes_Ano,
    COALESCE(v.Status_Pedido, 'STATUS NÃO IDENTIFICADO') AS Status_Pedido,
    COUNT(v.COM_ID) AS Total_Versoes_Compra,
    SUM(v.COM_QTD) AS Quantidade_Acumulada_Nas_Versoes
FROM compras_versoes v
GROUP BY
    TO_CHAR(v.COM_DT_PEDIDO, 'YYYY-MM'),
    COALESCE(v.Status_Pedido, 'STATUS NÃO IDENTIFICADO')
ORDER BY Mes_Ano DESC, Total_Versoes_Compra DESC;

-- 8. Matriz histórica de especialidade de fornecedores
-- Evidencia a recorrência e o volume das versões vigentes e encerradas por material e fornecedor.
WITH compras_versoes AS (
    SELECT
        c.COM_ID,
        c.COM_QTD,
        m.MAT_NOME AS Material,
        f.FOR_NOME AS Fornecedor
    FROM COMPRAS c
    LEFT JOIN MATERIAIS m ON c.COM_MATERIAL = m.MAT_ID
    LEFT JOIN FORNECEDORES f ON c.COM_FORNECEDOR = f.FOR_ID
    UNION ALL
    SELECT
        ch.COM_ID,
        ch.COM_QTD,
        mh.MAT_NOME,
        fh.FOR_NOME
    FROM COMPRAS_HIST ch
    LEFT JOIN MATERIAIS_HIST mh
        ON ch.COM_MATERIAL = mh.MAT_ID
       AND ch.COM_HIST_DT_INICIO >= mh.MAT_HIST_DT_INICIO
       AND (ch.COM_HIST_DT_INICIO < mh.MAT_HIST_DT_FIM OR mh.MAT_HIST_DT_FIM IS NULL)
    LEFT JOIN FORNECEDORES_HIST fh
        ON ch.COM_FORNECEDOR = fh.FOR_ID
       AND ch.COM_HIST_DT_INICIO >= fh.FOR_HIST_DT_INICIO
       AND (ch.COM_HIST_DT_INICIO < fh.FOR_HIST_DT_FIM OR fh.FOR_HIST_DT_FIM IS NULL)
    WHERE ch.COM_HIST_DT_FIM IS NOT NULL
)
SELECT
    COALESCE(v.Material, 'MATERIAL NÃO IDENTIFICADO') AS Material,
    COALESCE(v.Fornecedor, 'FORNECEDOR NÃO IDENTIFICADO') AS Fornecedor,
    COUNT(v.COM_ID) AS Frequencia_Versoes,
    SUM(v.COM_QTD) AS Volume_Acumulado_Nas_Versoes
FROM compras_versoes v
GROUP BY
    COALESCE(v.Material, 'MATERIAL NÃO IDENTIFICADO'),
    COALESCE(v.Fornecedor, 'FORNECEDOR NÃO IDENTIFICADO')
ORDER BY Material ASC, Frequencia_Versoes DESC;
