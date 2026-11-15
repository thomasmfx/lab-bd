# Dicionário de Dados - Sistema de Controle de Compras (Usinagem)

## 1. Tabela: COMPRAS
Responsável por armazenar todos os registros de aquisição de matéria-prima. É a tabela fato do sistema, centralizando os prazos, dimensões e referências.

| Coluna | Tipo de Dado | Restrições | Descrição |
| :--- | :--- | :--- | :--- |
| `COM_ID` | NUMBER(10,0) / BIGINT | PK, NOT NULL | Identificador único do registro de compra (Sequence `SEQ_COMPRAS`). |
| `COM_DT_PEDIDO` | DATE | NOT NULL | Data em que a necessidade de compra foi registrada no sistema interno. |
| `COM_OS` | NUMBER(10,0) / BIGINT | FK, NOT NULL | Referência à Ordem de Serviço da peça (`ORDENS_SERVICO`). |
| `COM_DESENHO` | NUMBER(10,0) / BIGINT | FK, NOT NULL | Referência ao desenho técnico da peça a ser usinada (`DESENHOS`). |
| `COM_MATERIAL` | NUMBER(10,0) / BIGINT | FK, NOT NULL | Referência à liga/tipo do material exigido (`MATERIAIS`). |
| `COM_DESCRICAO_MATERIAL` | VARCHAR2(100) / TEXT | NULL | Detalhamentos textuais extras sobre o material. |
| `COM_QTD` | NUMBER(10,0) / INT | NOT NULL | Quantidade de peças brutas, chapas ou barras a serem compradas. |
| `COM_PERFIL` | NUMBER(10,0) / BIGINT | FK, NULL | Referência ao formato geométrico bruto do material (`PERFIS`). |
| `COM_DIAMETRO_INT` | NUMBER(8,2) / DECIMAL | NULL | Medida do diâmetro interno (geralmente em mm). |
| `COM_DIAMETRO_EXT` | NUMBER(8,2) / DECIMAL | NULL | Medida do diâmetro externo (geralmente em mm). |
| `COM_ESPESSURA` | NUMBER(8,2) / DECIMAL | NULL | Medida da espessura do material (geralmente em mm). |
| `COM_LARGURA` | NUMBER(8,2) / DECIMAL | NULL | Medida da largura do material (geralmente em mm). |
| `COM_COMPRIMENTO` | NUMBER(8,2) / DECIMAL | NULL | Medida do comprimento bruto do material (geralmente em mm). |
| `COM_DT_PRAZO` | DATE | NULL | Data limite exigida pelo planejamento de produção para entrega da matéria-prima. |
| `COM_STATUS` | NUMBER(10,0) / BIGINT | FK, NULL | Referência ao status atual da compra no funil (`STATUS`). |
| `COM_FORNECEDOR` | NUMBER(10,0) / BIGINT | FK, NOT NULL | Referência ao parceiro comercial escolhido (`FORNECEDORES`). |
| `COM_DT_COMPRA_MATERIAL` | DATE | NULL | Data exata em que o pedido foi formalizado junto ao fornecedor. |
| `COM_FRETE` | NUMBER(10,0) / BIGINT | FK, NULL | Referência à modalidade logística, como CIF ou FOB (`CONDICOES_FRETE`). |
| `COM_NFE` | VARCHAR2(32) / TEXT | NULL | Número ou chave de acesso da Nota Fiscal Eletrônica de entrada. |
| `COM_DT_CHEGADA_MATERIAL` | DATE | NULL | Data física do recebimento do material no barracão da fábrica. |
| `COM_INFO_ADICIONAIS` | VARCHAR2(500) / TEXT | NULL | Campo livre para observações gerais sobre negociação ou recebimento. |

## 2. Tabelas de Domínio (Dimensões)
Tabelas auxiliares utilizadas para normalizar os dados, garantir integridade referencial e facilitar a expansão do sistema (ideal para mapeamento de entidades relativas no back-end).

### ORDENS_SERVICO
| Coluna | Tipo | Restrições | Descrição |
| :--- | :--- | :--- | :--- |
| `OS_ID` | NUMBER(10,0) | PK, NOT NULL | Identificador único interno da OS. |
| `OS_NUMERO` | VARCHAR2(100) | NOT NULL | Código alfanumérico de identificação da Ordem de Serviço na fábrica. |
| `OS_SOLICITANTE` | NUMBER(10,0) | FK, NOT NULL | Referência ao cliente, setor ou pessoa que requisitou a OS (`SOLICITANTES`). |

### MATERIAIS
| Coluna | Tipo | Restrições | Descrição |
| :--- | :--- | :--- | :--- |
| `MAT_ID` | NUMBER(10,0) | PK, NOT NULL | Identificador único do material. |
| `MAT_NOME` | VARCHAR2(100) | NOT NULL | Nomenclatura técnica da liga metálica/material (ex: AISI 304, 4140, AL 7075). |

### DESENHOS
| Coluna | Tipo | Restrições | Descrição |
| :--- | :--- | :--- | :--- |
| `DES_ID` | NUMBER(10,0) | PK, NOT NULL | Identificador único do desenho. |
| `DES_NOME` | VARCHAR2(100) | NOT NULL | Código de revisão ou nome do desenho técnico de engenharia (ex: C203-M-64225). |

### FORNECEDORES
| Coluna | Tipo | Restrições | Descrição |
| :--- | :--- | :--- | :--- |
| `FOR_ID` | NUMBER(10,0) | PK, NOT NULL | Identificador único do fornecedor. |
| `FOR_NOME` | VARCHAR2(100) | NOT NULL | Razão social ou nome fantasia do parceiro que fornece os insumos industriais. |

### SOLICITANTES
| Coluna | Tipo | Restrições | Descrição |
| :--- | :--- | :--- | :--- |
| `SOL_ID` | NUMBER(10,0) | PK, NOT NULL | Identificador único do solicitante. |
| `SOL_NOME` | VARCHAR2(100) | NOT NULL | Nome da entidade, pessoa ou setor que abriu a demanda (ex: KCC SZ). |

### STATUS
| Coluna | Tipo | Restrições | Descrição |
| :--- | :--- | :--- | :--- |
| `STA_ID` | NUMBER(10,0) | PK, NOT NULL | Identificador único do status. |
| `STA_NOME` | VARCHAR2(32) | NOT NULL | Descrição textual da fase atual no funil de compras (ex: COTANDO, ENTREGUE). |

### PERFIS
| Coluna | Tipo | Restrições | Descrição |
| :--- | :--- | :--- | :--- |
| `PER_ID` | NUMBER(10,0) | PK, NOT NULL | Identificador único do perfil. |
| `PER_NOME` | VARCHAR2(100) | NOT NULL | Geometria bruta da matéria-prima (ex: REDONDO, CHAPA, TUBO). |

### CONDICOES_FRETE
| Coluna | Tipo | Restrições | Descrição |
| :--- | :--- | :--- | :--- |
| `CON_FRE_ID` | NUMBER(10,0) | PK, NOT NULL | Identificador único da condição logística. |
| `CON_FRE_NOME` | VARCHAR2(3) | NOT NULL | Sigla da modalidade logística de transporte (ex: CIF, FOB). |

## 3. Views do Dashboard
Criadas por `controle_compras_mviews_ddl.sql`. Leem a última versão de cada compra em `COMPRAS_HIST`, que inclui as compras removidas pelo `apagar`. As views materializadas (`MV_*`) guardam somas e contagens; médias e percentuais são calculados no BI.

### VW_COMPRAS_CONSOLIDADAS (view)
Uma linha por compra. Base das views materializadas.

| Coluna | Tipo | Descrição |
| :--- | :--- | :--- |
| `COM_ID` | NUMBER | Identificador da compra. |
| `DT_PEDIDO` | DATE | Data do pedido. |
| `MES_PEDIDO` | DATE | Primeiro dia do mês do pedido. |
| `OS_ID` | NUMBER | Identificador da OS. |
| `OS_NUMERO` | VARCHAR2(100) | Número da OS. |
| `SOLICITANTE` | VARCHAR2(100) | Solicitante da OS. |
| `FOR_ID` | NUMBER | Identificador do fornecedor. |
| `FORNECEDOR` | VARCHAR2(100) | Nome do fornecedor. |
| `MATERIAL` | VARCHAR2(100) | Nome do material. |
| `PERFIL` | VARCHAR2(100) | Perfil do material; `SEM PERFIL` quando nulo. |
| `STATUS_PEDIDO` | VARCHAR2(32) | Status da compra; `SEM STATUS` quando nulo. |
| `EM_ABERTO` | CHAR(1) | `N` se o status é `ENTREGUE`; `S` nos demais casos. |
| `FRETE` | VARCHAR2(3) | Condição de frete (CIF, FOB) ou nulo. |
| `QTD` | NUMBER | Quantidade de peças. |
| `DT_PRAZO` | DATE | Prazo de entrega. |
| `DT_COMPRA` | DATE | Data da compra junto ao fornecedor. |
| `DT_CHEGADA` | DATE | Data de chegada do material. |
| `DT_CORTE` | DATE | Data do pedido mais recente; referência para idade e prazo vencido. |
| `IDADE_DIAS` | NUMBER | Dias entre o pedido e `DT_CORTE`. |

### MV_DESEMPENHO_FORNECEDOR
Uma linha por fornecedor e mês do pedido.

| Coluna | Tipo | Descrição |
| :--- | :--- | :--- |
| `FOR_ID` | NUMBER | Identificador do fornecedor. |
| `FORNECEDOR` | VARCHAR2(100) | Nome do fornecedor. |
| `MES_PEDIDO` | DATE | Primeiro dia do mês do pedido. |
| `TOTAL_PEDIDOS` | NUMBER | Quantidade de compras. |
| `QUANTIDADE_PECAS` | NUMBER | Soma das quantidades de peças. |
| `PEDIDOS_COMPRADOS` | NUMBER | Compras com data de compra registrada. |
| `PEDIDOS_COM_CHEGADA` | NUMBER | Compras com data de chegada registrada. |
| `PEDIDOS_ATRASADOS` | NUMBER | Compras com chegada depois do prazo. |
| `SOMA_DIAS_COTACAO` | NUMBER | Soma dos dias entre pedido e compra. Dividir por `PEDIDOS_COMPRADOS` para a média. |
| `SOMA_DIAS_ENTREGA` | NUMBER | Soma dos dias entre pedido e chegada. Dividir por `PEDIDOS_COM_CHEGADA` para a média. |
| `PEDIDOS_CIF` | NUMBER | Compras com frete CIF. |
| `PEDIDOS_FOB` | NUMBER | Compras com frete FOB. |

### MV_EVOLUCAO_STATUS
Uma linha por mês do pedido e status.

| Coluna | Tipo | Descrição |
| :--- | :--- | :--- |
| `MES_PEDIDO` | DATE | Primeiro dia do mês do pedido. |
| `STATUS_PEDIDO` | VARCHAR2(32) | Status da compra. |
| `EM_ABERTO` | CHAR(1) | `S` para status diferente de `ENTREGUE`. |
| `TOTAL_PEDIDOS` | NUMBER | Quantidade de compras. |
| `QUANTIDADE_PECAS` | NUMBER | Soma das quantidades de peças. |

### MV_BACKLOG_COMPRAS
Só compras em aberto. Uma linha por mês do pedido, status, fornecedor e faixa de idade.

| Coluna | Tipo | Descrição |
| :--- | :--- | :--- |
| `MES_PEDIDO` | DATE | Primeiro dia do mês do pedido. |
| `STATUS_PEDIDO` | VARCHAR2(32) | Status da compra. |
| `FOR_ID` | NUMBER | Identificador do fornecedor. |
| `FORNECEDOR` | VARCHAR2(100) | Nome do fornecedor. |
| `FAIXA_IDADE` | VARCHAR2(5) | Idade do pedido em `DT_CORTE`: `0-30`, `31-60`, `61-90` ou `90+` dias. |
| `ORDEM_FAIXA` | NUMBER | Ordem da faixa (1 a 4), para ordenação no BI. |
| `TOTAL_PEDIDOS` | NUMBER | Quantidade de compras em aberto. |
| `QUANTIDADE_PECAS` | NUMBER | Soma das quantidades de peças. |
| `PEDIDOS_SEM_PRAZO` | NUMBER | Compras sem prazo registrado. |
| `PEDIDOS_PRAZO_VENCIDO` | NUMBER | Compras com prazo anterior a `DT_CORTE`. |
| `IDADE_MAX_DIAS` | NUMBER | Idade da compra mais antiga do grupo, em dias. |
| `DT_CORTE` | DATE | Data de referência da idade e do prazo vencido. |

### MV_PRONTIDAO_OS
Uma linha por OS (par número + solicitante, como a carga registra).

| Coluna | Tipo | Descrição |
| :--- | :--- | :--- |
| `OS_ID` | NUMBER | Identificador da OS. |
| `OS_NUMERO` | VARCHAR2(100) | Número da OS. |
| `SOLICITANTE` | VARCHAR2(100) | Solicitante da OS. |
| `DT_PRIMEIRO_PEDIDO` | DATE | Data do primeiro pedido de material da OS. |
| `MES_PRIMEIRO_PEDIDO` | DATE | Primeiro dia do mês do primeiro pedido. |
| `ITENS_TOTAL` | NUMBER | Compras da OS. |
| `ITENS_ENTREGUES` | NUMBER | Compras com status `ENTREGUE`. |
| `ITENS_COTANDO` | NUMBER | Compras com status `COTANDO`. |
| `ITENS_PARADOS` | NUMBER | Compras com status `PARADO`. |
| `FORNECEDORES_DISTINTOS` | NUMBER | Fornecedores diferentes envolvidos na OS. |
| `SITUACAO_OS` | VARCHAR2(10) | `PRONTA` (todas as compras entregues), `PARCIAL` ou `AGUARDANDO` (nenhuma entregue). |
| `DIAS_AGUARDANDO` | NUMBER | Dias entre o primeiro pedido e `DT_CORTE`; nulo se a OS está pronta. |
| `PRAZO_ULTIMO_ITEM` | DATE | Maior prazo entre as compras em aberto da OS. |
