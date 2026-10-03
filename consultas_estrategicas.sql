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
