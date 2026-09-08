-- =================================================================================
-- CONSULTAS ESTRATÉGICAS - CONTROLE DE COMPRAS E USINAGEM
-- =================================================================================

-- 1. Análise de Desempenho e Atrasos de Fornecedores
-- Identifica quais parceiros estão cumprindo prazos e calcula o tempo médio de entrega.
SELECT 
    f.FOR_NOME AS Fornecedor,
    COUNT(c.COM_ID) AS Total_Pedidos,
    SUM(CASE WHEN c.COM_DT_CHEGADA_MATERIAL > c.COM_DT_PRAZO THEN 1 ELSE 0 END) AS Pedidos_Atrasados,
    ROUND(AVG(c.COM_DT_CHEGADA_MATERIAL - c.COM_DT_PEDIDO), 1) AS Tempo_Medio_Entrega_Dias
FROM COMPRAS c
JOIN FORNECEDORES f ON c.COM_FORNECEDOR = f.FOR_ID
WHERE c.COM_DT_CHEGADA_MATERIAL IS NOT NULL
GROUP BY f.FOR_NOME
ORDER BY Pedidos_Atrasados DESC, Total_Pedidos DESC;

-- 2. Gargalos de Produção (Materiais Pendentes por OS)
-- Lista as Ordens de Serviço com materiais ainda não entregues, ordenando pelo prazo crítico.
SELECT 
    s.SOL_NOME AS Solicitante,
    os.OS_NUMERO AS Ordem_Servico,
    COUNT(c.COM_ID) AS Materiais_Pendentes,
    MIN(c.COM_DT_PRAZO) AS Prazo_Mais_Critico
FROM COMPRAS c
JOIN ORDENS_SERVICO os ON c.COM_OS = os.OS_ID
JOIN SOLICITANTES s ON os.OS_SOLICITANTE = s.SOL_ID
JOIN STATUS st ON c.COM_STATUS = st.STA_ID
WHERE st.STA_NOME NOT IN ('ENTREGUE', 'CANCELADO') 
GROUP BY s.SOL_NOME, os.OS_NUMERO
ORDER BY Prazo_Mais_Critico ASC;

-- 3. Curva de Consumo por Material e Perfil
-- Consolidado para entender quais dimensões e tipos de ligas/materiais têm maior saída.
SELECT 
    m.MAT_NOME AS Material,
    p.PER_NOME AS Perfil,
    SUM(c.COM_QTD) AS Quantidade_Total_Comprada,
    COUNT(c.COM_ID) AS Frequencia_Compras
FROM COMPRAS c
JOIN MATERIAIS m ON c.COM_MATERIAL = m.MAT_ID
JOIN PERFIS p ON c.COM_PERFIL = p.PER_ID
GROUP BY m.MAT_NOME, p.PER_NOME
ORDER BY Quantidade_Total_Comprada DESC;

-- 4. Indicador de Possível Sucata ou Retrabalho
-- Identifica múltiplas compras do mesmo material para a mesma OS e desenho.
SELECT 
    os.OS_NUMERO AS Ordem_Servico,
    d.DES_NOME AS Desenho_Peca,
    m.MAT_NOME AS Material,
    COUNT(c.COM_ID) AS Quantidade_Pedidos_Diferentes,
    SUM(c.COM_QTD) AS Total_Itens_Comprados
FROM COMPRAS c
JOIN ORDENS_SERVICO os ON c.COM_OS = os.OS_ID
JOIN DESENHOS d ON c.COM_DESENHO = d.DES_ID
JOIN MATERIAIS m ON c.COM_MATERIAL = m.MAT_ID
GROUP BY os.OS_NUMERO, d.DES_NOME, m.MAT_NOME
HAVING COUNT(c.COM_ID) > 1
ORDER BY Quantidade_Pedidos_Diferentes DESC, Total_Itens_Comprados DESC;

-- 5. Agrupamento para Gráficos de Dashboard (Visão Mensal)
-- Sumariza o volume de compras por mês e separa por status.
SELECT 
    TO_CHAR(c.COM_DT_PEDIDO, 'YYYY-MM') AS Mes_Ano,
    st.STA_NOME AS Status_Pedido,
    COUNT(c.COM_ID) AS Total_Pedidos
FROM COMPRAS c
JOIN STATUS st ON c.COM_STATUS = st.STA_ID
GROUP BY TO_CHAR(c.COM_DT_PEDIDO, 'YYYY-MM'), st.STA_NOME
ORDER BY Mes_Ano DESC, Total_Pedidos DESC;

-- 6. Impacto da Modalidade de Frete nos Prazos (FOB vs. CIF)
-- Avalia como a logística (FOB/CIF) afeta o tempo de entrega dos materiais.
SELECT 
    cf.CON_FRE_NOME AS Modalidade_Frete,
    COUNT(c.COM_ID) AS Volume_Total_Pedidos,
    ROUND(AVG(c.COM_DT_CHEGADA_MATERIAL - c.COM_DT_PEDIDO), 1) AS Tempo_Medio_Entrega_Dias
FROM COMPRAS c
JOIN CONDICOES_FRETE cf ON c.COM_FRETE = cf.CON_FRE_ID
WHERE c.COM_DT_CHEGADA_MATERIAL IS NOT NULL
GROUP BY cf.CON_FRE_NOME
ORDER BY Tempo_Medio_Entrega_Dias ASC;

-- 7. Rastreio de Peças Brutas de Grande Porte
-- Filtra pedidos de matéria-prima que ultrapassam dimensões comuns (ex: diâmetro > 100).
SELECT 
    c.COM_ID AS ID_Compra,
    os.OS_NUMERO AS Ordem_Servico,
    m.MAT_NOME AS Material,
    p.PER_NOME AS Perfil,
    c.COM_DIAMETRO_EXT AS Diametro_Externo,
    c.COM_ESPESSURA AS Espessura,
    c.COM_QTD AS Quantidade,
    f.FOR_NOME AS Fornecedor
FROM COMPRAS c
JOIN MATERIAIS m ON c.COM_MATERIAL = m.MAT_ID
JOIN PERFIS p ON c.COM_PERFIL = p.PER_ID
JOIN ORDENS_SERVICO os ON c.COM_OS = os.OS_ID
JOIN FORNECEDORES f ON c.COM_FORNECEDOR = f.FOR_ID
WHERE c.COM_DIAMETRO_EXT > 100 OR c.COM_ESPESSURA > 50
ORDER BY c.COM_DIAMETRO_EXT DESC;

-- 8. Matriz de Especialidade de Fornecedores
-- Cruza os materiais e agrupa pela volumetria de compras por parceiro.
SELECT 
    m.MAT_NOME AS Material,
    f.FOR_NOME AS Fornecedor,
    COUNT(c.COM_ID) AS Frequencia_Pedidos,
    SUM(c.COM_QTD) AS Volume_Total_Pecas
FROM COMPRAS c
JOIN MATERIAIS m ON c.COM_MATERIAL = m.MAT_ID
JOIN FORNECEDORES f ON c.COM_FORNECEDOR = f.FOR_ID
GROUP BY m.MAT_NOME, f.FOR_NOME
HAVING COUNT(c.COM_ID) > 2
ORDER BY Material ASC, Frequencia_Pedidos DESC;
