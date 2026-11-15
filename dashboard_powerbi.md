# Dashboard de Compras no Power BI

Quatro páginas, cada uma lendo uma view materializada criada por `controle_compras_mviews_ddl.sql`. As colunas de cada view estão em [dicionario_dados.md](dicionario_dados.md#3-views-do-dashboard).

## Conexão

1. **Obter dados > Banco de dados Oracle**. Servidor: `localhost:1521/XEPDB1`. Modo: **Importar**.
2. Credenciais de banco de dados: usuário `lab`, senha `lab`.
3. No navegador, abra o schema `LAB` e marque as quatro `MV_*`. Se elas não aparecerem, use a opção de instrução SQL com `SELECT * FROM LAB.MV_DESEMPENHO_FORNECEDOR` (e o mesmo para as outras).
4. No Power Query, renomeie cada consulta para o nome da view, sem o prefixo do schema. As medidas abaixo usam esses nomes.

Se o Power BI pedir driver Oracle, instale o Oracle Client for Microsoft Tools.

As tabelas ficam independentes, sem relacionamentos. Cada página filtra só a própria tabela.

Depois de uma carga (`python carga_planilha.py ...`), as views já estão atualizadas no banco; basta clicar em **Atualizar** no Power BI.

## Ajustes no modelo

- `MV_BACKLOG_COMPRAS[FAIXA_IDADE]`: **Classificar por coluna** `ORDEM_FAIXA`.
- Colunas `MES_PEDIDO` e `MES_PRIMEIRO_PEDIDO`: formato `mmm/yyyy`.
- A planilha não tem pedidos em maio e julho de 2026. Use eixo categórico nos gráficos mensais para mostrar só os 5 meses com dados.

## Página 1: Fornecedores

Tabela: `MV_DESEMPENHO_FORNECEDOR`. Pergunta: qual fornecedor concentra pedidos, entrega no prazo e com que frete?

```dax
Pedidos Fornecedor = SUM(MV_DESEMPENHO_FORNECEDOR[TOTAL_PEDIDOS])
Fornecedores Ativos = DISTINCTCOUNT(MV_DESEMPENHO_FORNECEDOR[FOR_ID])
Chegadas = SUM(MV_DESEMPENHO_FORNECEDOR[PEDIDOS_COM_CHEGADA])
% Com Chegada = DIVIDE([Chegadas], [Pedidos Fornecedor])
Taxa Atraso = DIVIDE(SUM(MV_DESEMPENHO_FORNECEDOR[PEDIDOS_ATRASADOS]), [Chegadas])
Tempo Medio Entrega = DIVIDE(SUM(MV_DESEMPENHO_FORNECEDOR[SOMA_DIAS_ENTREGA]), [Chegadas])
Tempo Medio Cotacao = DIVIDE(SUM(MV_DESEMPENHO_FORNECEDOR[SOMA_DIAS_COTACAO]), SUM(MV_DESEMPENHO_FORNECEDOR[PEDIDOS_COMPRADOS]))
Pedidos CIF = SUM(MV_DESEMPENHO_FORNECEDOR[PEDIDOS_CIF])
Pedidos FOB = SUM(MV_DESEMPENHO_FORNECEDOR[PEDIDOS_FOB])
```

| Visual | Campos |
| :--- | :--- |
| Cartões | `Fornecedores Ativos`, `% Com Chegada`, `Tempo Medio Cotacao` (dias) |
| Barras: pedidos por fornecedor | Eixo `FORNECEDOR`; valor `Pedidos Fornecedor`; filtro Top N = 10 por `Pedidos Fornecedor` |
| Tabela: desempenho de entrega | `FORNECEDOR`, `Chegadas`, `Taxa Atraso`, `Tempo Medio Entrega`; filtro `Chegadas` > 0 |
| Colunas empilhadas: frete | Eixo `FORNECEDOR`; valores `Pedidos CIF` e `Pedidos FOB` |
| Segmentação | `MES_PEDIDO` |

Deixe um aviso na página: a taxa de atraso e o tempo de entrega vêm só dos pedidos com data de chegada (80 de 573, de 9 fornecedores). A coluna `Chegadas` na tabela mostra o tamanho da amostra de cada fornecedor.

## Página 2: Evolução mensal

Tabela: `MV_EVOLUCAO_STATUS`. Pergunta: como a demanda e o mix de status mudam mês a mês?

```dax
Pedidos Mes = SUM(MV_EVOLUCAO_STATUS[TOTAL_PEDIDOS])
Pecas Mes = SUM(MV_EVOLUCAO_STATUS[QUANTIDADE_PECAS])
% Entregue = DIVIDE(CALCULATE([Pedidos Mes], MV_EVOLUCAO_STATUS[STATUS_PEDIDO] = "ENTREGUE"), [Pedidos Mes])
```

| Visual | Campos |
| :--- | :--- |
| Cartões | `Pedidos Mes`, `Pecas Mes`, `% Entregue` |
| Colunas: demanda | Eixo `MES_PEDIDO`; valor `Pedidos Mes` |
| Colunas 100% empilhadas: mix de status | Eixo `MES_PEDIDO`; legenda `STATUS_PEDIDO`; valor `Pedidos Mes` |
| Linha: taxa de conclusão | Eixo `MES_PEDIDO`; valor `% Entregue` |

Não use segmentação por status nesta página: `% Entregue` troca o filtro de status no numerador.

## Página 3: Backlog

Tabela: `MV_BACKLOG_COMPRAS`, que só tem pedidos em aberto. Pergunta: o que está em aberto, com quem e há quanto tempo?

```dax
Em Aberto = SUM(MV_BACKLOG_COMPRAS[TOTAL_PEDIDOS])
Prazo Vencido = SUM(MV_BACKLOG_COMPRAS[PEDIDOS_PRAZO_VENCIDO])
Sem Prazo = SUM(MV_BACKLOG_COMPRAS[PEDIDOS_SEM_PRAZO])
Idade Maxima = MAX(MV_BACKLOG_COMPRAS[IDADE_MAX_DIAS])
Data de Corte = "Situação em " & FORMAT(MAX(MV_BACKLOG_COMPRAS[DT_CORTE]), "dd/mm/yyyy")
```

| Visual | Campos |
| :--- | :--- |
| Cartões | `Em Aberto`, `Prazo Vencido`, `Sem Prazo`, `Idade Maxima` (dias) |
| Cartão de texto | `Data de Corte` |
| Colunas empilhadas: envelhecimento | Eixo `FAIXA_IDADE`; legenda `STATUS_PEDIDO`; valor `Em Aberto` |
| Barras: backlog por fornecedor | Eixo `FORNECEDOR`; valores `Em Aberto` e `Prazo Vencido`; Top N = 10 por `Em Aberto` |
| Matriz | Linhas `STATUS_PEDIDO`; colunas `FAIXA_IDADE`; valor `Em Aberto` |
| Segmentações | `STATUS_PEDIDO`, `FORNECEDOR` |

A idade e o prazo vencido são medidos na data de corte (o pedido mais recente da planilha), não na data de hoje. O cartão `Data de Corte` deixa isso visível.

## Página 4: Prontidão das OS

Tabela: `MV_PRONTIDAO_OS`. Pergunta: quais OS já têm todo o material para entrar em usinagem?

```dax
OS = COUNTROWS(MV_PRONTIDAO_OS)
OS Prontas = CALCULATE([OS], MV_PRONTIDAO_OS[SITUACAO_OS] = "PRONTA")
% OS Prontas = DIVIDE([OS Prontas], [OS])
Itens Pendentes = SUM(MV_PRONTIDAO_OS[ITENS_TOTAL]) - SUM(MV_PRONTIDAO_OS[ITENS_ENTREGUES])
```

| Visual | Campos |
| :--- | :--- |
| Cartões | `OS Prontas`, `% OS Prontas`, `Itens Pendentes` |
| Rosca: OS por situação | Legenda `SITUACAO_OS`; valor `OS` |
| Barras empilhadas: solicitantes | Eixo `SOLICITANTE`; legenda `SITUACAO_OS`; valor `OS` |
| Tabela: OS travadas | `OS_NUMERO`, `SOLICITANTE`, `SITUACAO_OS`, `DIAS_AGUARDANDO`, `ITENS_TOTAL`, `ITENS_ENTREGUES`, `ITENS_COTANDO`, `ITENS_PARADOS`, `FORNECEDORES_DISTINTOS`, `PRAZO_ULTIMO_ITEM`; filtro `SITUACAO_OS` diferente de `PRONTA`; ordem decrescente por `DIAS_AGUARDANDO` |
| Segmentação | `SOLICITANTE` |
