# Controle de Compras

## Como subir o banco

1. Suba o Oracle XE 21c em Docker:

   ```bash
   docker compose up -d --wait
   ```

   Na primeira inicialização, o container roda os scripts no PDB `XEPDB1`, nesta ordem:

   - `controle_compras_usuarios.sql`, como SYS: cria os usuários `LAB` (dono das tabelas) e `LAB_AUDIT` (dono da auditoria);
   - `controle_compras_ddl.sql` (tabelas, sequences e triggers), `controle_compras_temporal_ddl.sql` (tabelas de histórico `<TABELA>_HIST` e triggers que gravam cada versão das linhas) e `controle_compras_mviews_ddl.sql` (views do dashboard, ver [Views do dashboard](#views-do-dashboard)), como `LAB`;
   - `controle_compras_auditoria_ddl.sql` (tabela `AUDITORIA` e triggers que registram, coluna a coluna, cada `UPDATE` e `DELETE` nas tabelas `_HIST`), como `LAB_AUDIT`.

   Sem Docker, rode os mesmos scripts nessa ordem, cada um com o usuário indicado. Os dados ficam no volume `oracle-data`; `docker compose down -v` apaga tudo, e o próximo `up` recria o schema do zero.

   Para conectar pelo SQL Developer, use host `localhost`, porta `1521` e serviço `XEPDB1`:

   | Usuário | Senha | Acesso |
   | :--- | :--- | :--- |
   | `lab` | `lab` | tabelas, histórico e views do dashboard |
   | `lab_audit` | `lab_audit` | tabela `AUDITORIA` (o `lab` não tem acesso) |
   | `system` | `oracle` | administração |

2. Ciclo de cargas da planilha `CONTROLE_COMPRAS.xlsx` (aba `MATÉRIA PRIMA (2)`), por data do pedido:

   ```bash
   pip install -r requirements.txt
   python carga_planilha.py 1       # fev–mar/2026
   python carga_planilha.py apagar
   python carga_planilha.py 2       # abr–jun/2026
   python carga_planilha.py apagar
   python carga_planilha.py 3       # jul–ago/2026
   ```

   `apagar` remove só as compras; cada exclusão fecha a versão da linha em `COMPRAS_HIST`, e o fechamento fica registrado em `AUDITORIA` (`COM_HIST_DT_FIM` de nulo para a data da exclusão). A terceira carga fica no banco como estado vigente (`apagar` também funciona depois dela, se precisar). As tabelas de domínio (materiais, fornecedores, status etc.) são cadastro: ficam no banco, e cada carga reaproveita os valores que já existem e insere só os novos.

## Views do dashboard

`controle_compras_mviews_ddl.sql` cria as views que o Power BI lê (montagem das páginas em [dashboard_powerbi.md](dashboard_powerbi.md)):

| View | Uma linha por | Uso |
| :--- | :--- | :--- |
| `VW_COMPRAS_CONSOLIDADAS` | compra | Base das MVs: última versão de cada compra em `COMPRAS_HIST`, com os nomes das dimensões. |
| `MV_DESEMPENHO_FORNECEDOR` | fornecedor × mês | Pedidos, atraso, tempo de cotação e de entrega, frete. |
| `MV_EVOLUCAO_STATUS` | mês × status | Demanda e mix de status ao longo dos meses. |
| `MV_BACKLOG_COMPRAS` | mês × status × fornecedor × faixa de idade | Pedidos em aberto, prazo vencido e idade. |
| `MV_PRONTIDAO_OS` | OS | Quais OS já têm todo o material entregue. |

As views leem `COMPRAS_HIST`, não `COMPRAS`: o histórico tem todas as compras já carregadas, inclusive as que o `apagar` removeu. Depois do ciclo completo, são 573 compras de fev a ago/2026. Por isso, repetir uma carga depois do `apagar` duplica as compras daquele período nas views.

Idade e prazo vencido são medidos contra a data do pedido mais recente (`DT_CORTE`), não contra a data de hoje, porque a planilha é uma fotografia de agosto/2026.

`carga_planilha.py` atualiza as views materializadas ao fim de cada carga e de cada `apagar`. Para atualizar à mão, como `lab`:

```sql
EXEC DBMS_MVIEW.REFRESH('MV_DESEMPENHO_FORNECEDOR,MV_EVOLUCAO_STATUS,MV_BACKLOG_COMPRAS,MV_PRONTIDAO_OS', 'CCCC');
```

Num volume criado antes deste script, o `up` não roda a inicialização de novo. Crie as views sem apagar os dados:

1. Como `system`: `GRANT CREATE VIEW, CREATE MATERIALIZED VIEW TO LAB;`
2. Como `lab`: rode `controle_compras_mviews_ddl.sql`.
