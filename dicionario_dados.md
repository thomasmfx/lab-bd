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
