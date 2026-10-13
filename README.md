# Controle de Compras

## Como subir o banco

1. Suba o Oracle XE 21c em Docker:

   ```bash
   docker compose up -d --wait
   ```

   Na primeira inicialização, o container roda os scripts no PDB `XEPDB1`, nesta ordem:

   - `controle_compras_usuarios.sql`, como SYS: cria os usuários `LAB` (dono das tabelas) e `LAB_AUDIT` (dono da auditoria);
   - `controle_compras_ddl.sql` (tabelas, sequences e triggers) e `controle_compras_temporal_ddl.sql` (tabelas de histórico `<TABELA>_HIST` e triggers que gravam cada versão das linhas), como `LAB`;
   - `controle_compras_auditoria_ddl.sql` (tabela `AUDITORIA` e triggers que registram, coluna a coluna, cada `UPDATE` e `DELETE` nas tabelas `_HIST`), como `LAB_AUDIT`.

   Sem Docker, rode os mesmos scripts nessa ordem, cada um com o usuário indicado. Os dados ficam no volume `oracle-data`; `docker compose down -v` apaga tudo, e o próximo `up` recria o schema do zero.

   Para conectar pelo SQL Developer, use host `localhost`, porta `1521` e serviço `XEPDB1`:

   | Usuário | Senha | Acesso |
   | :--- | :--- | :--- |
   | `lab` | `lab` | tabelas e histórico |
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
