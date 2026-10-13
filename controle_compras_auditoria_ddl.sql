--------------------------------------------------------
--  Auditoria das tabelas de histórico
--  Executar como LAB_AUDIT, depois de controle_compras_temporal_ddl.sql.
--  Os triggers ficam no schema do LAB_AUDIT, sobre as tabelas do LAB (por isso o CREATE ANY TRIGGER
--  em controle_compras_usuarios.sql); o LAB não tem acesso à AUDITORIA.
--
--  Cada UPDATE ou DELETE numa tabela <T>_HIST grava em AUDITORIA uma linha por coluna alterada,
--  com o valor antigo e o novo; no DELETE o valor novo fica nulo, e colunas já nulas não entram.
--  AUD_REGISTRO: <X>_HIST_ID da linha alterada. AUD_TP_OPERACAO: U = UPDATE, D = DELETE.
--  Valores de data são gravados como YYYY-MM-DD HH24:MI:SS (DATE) ou YYYY-MM-DD HH24:MI:SS.FF6
--  (TIMESTAMP), qualquer que seja o NLS da sessão.
--
--  O trigger temporal fecha a versão vigente com UPDATE de <X>_HIST_DT_FIM, então todo UPDATE ou
--  DELETE nas tabelas de origem também gera uma linha aqui: <X>_HIST_DT_FIM de nulo para a data
--  do fechamento.
--
--  Alterações de uma versão, por exemplo:
--    SELECT * FROM AUDITORIA
--     WHERE AUD_TABELA = 'COMPRAS_HIST' AND AUD_REGISTRO = :id
--     ORDER BY AUD_ID;
--------------------------------------------------------

--------------------------------------------------------
--  DDL for Sequences
--------------------------------------------------------

CREATE SEQUENCE "SEQ_AUDITORIA" MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 NOCACHE NOORDER NOCYCLE NOKEEP NOSCALE GLOBAL;

--------------------------------------------------------
--  DDL for Tables
--------------------------------------------------------

CREATE TABLE "AUDITORIA"
(
    "AUD_ID" NUMBER(10,0),
    "AUD_TABELA" VARCHAR2(30),
    "AUD_REGISTRO" NUMBER(10,0),
    "AUD_COLUNA" VARCHAR2(30),
    "AUD_VALOR_ANTIGO" VARCHAR2(500),
    "AUD_VALOR_NOVO" VARCHAR2(500),
    "AUD_TP_OPERACAO" CHAR(1),
    "AUD_DATA_ENTRADA" TIMESTAMP,
    "AUD_BD_USER" VARCHAR2(128),
    "AUD_SO_USER" VARCHAR2(255)
);

--------------------------------------------------------
--  DDL for Procedures
--------------------------------------------------------

CREATE OR REPLACE NONEDITIONABLE PROCEDURE "PR_INSERE_AUDITORIA" (
    p_tabela       IN VARCHAR2,
    p_registro     IN NUMBER,
    p_coluna       IN VARCHAR2,
    p_valor_antigo IN VARCHAR2,
    p_valor_novo   IN VARCHAR2,
    p_tp_operacao  IN VARCHAR2,
    p_data_entrada IN TIMESTAMP
)
IS
BEGIN
    -- Coluna sem alteração não entra; nulo conta como valor, então nulo -> X e X -> nulo entram.
    IF p_valor_antigo = p_valor_novo OR (p_valor_antigo IS NULL AND p_valor_novo IS NULL) THEN
        RETURN;
    END IF;

    INSERT INTO "AUDITORIA" (
        "AUD_TABELA",
        "AUD_REGISTRO",
        "AUD_COLUNA",
        "AUD_VALOR_ANTIGO",
        "AUD_VALOR_NOVO",
        "AUD_TP_OPERACAO",
        "AUD_DATA_ENTRADA",
        "AUD_BD_USER",
        "AUD_SO_USER"
    ) VALUES (
        p_tabela,
        p_registro,
        p_coluna,
        p_valor_antigo,
        p_valor_novo,
        p_tp_operacao,
        p_data_entrada,
        USER,
        SYS_CONTEXT('USERENV', 'OS_USER')
    );
END;
/

--------------------------------------------------------
--  DDL for Triggers
--------------------------------------------------------

CREATE OR REPLACE NONEDITIONABLE TRIGGER "TG_SEQ_AUDITORIA"
BEFORE INSERT ON "AUDITORIA"
FOR EACH ROW
BEGIN
    :NEW.AUD_ID := SEQ_AUDITORIA.NEXTVAL;
END;
/
ALTER TRIGGER "TG_SEQ_AUDITORIA" ENABLE;

CREATE OR REPLACE NONEDITIONABLE TRIGGER "TG_AUD_COMPRAS_HIST"
BEFORE UPDATE OR DELETE ON LAB."COMPRAS_HIST"
FOR EACH ROW
DECLARE
    c_data      CONSTANT VARCHAR2(30) := 'YYYY-MM-DD HH24:MI:SS';
    c_timestamp CONSTANT VARCHAR2(30) := 'YYYY-MM-DD HH24:MI:SS.FF6';
    v_agora     TIMESTAMP := SYSTIMESTAMP;
    v_operacao  CHAR(1) := CASE WHEN DELETING THEN 'D' ELSE 'U' END;
    v_registro  NUMBER(10,0) := :OLD.COM_HIST_ID;

    PROCEDURE audita(p_coluna VARCHAR2, p_antigo VARCHAR2, p_novo VARCHAR2) IS
    BEGIN
        PR_INSERE_AUDITORIA('COMPRAS_HIST', v_registro, p_coluna, p_antigo, p_novo, v_operacao, v_agora);
    END;
BEGIN
    audita('COM_HIST_ID', :OLD.COM_HIST_ID, :NEW.COM_HIST_ID);
    audita('COM_ID', :OLD.COM_ID, :NEW.COM_ID);
    audita('COM_DT_PEDIDO', TO_CHAR(:OLD.COM_DT_PEDIDO, c_data), TO_CHAR(:NEW.COM_DT_PEDIDO, c_data));
    audita('COM_OS', :OLD.COM_OS, :NEW.COM_OS);
    audita('COM_DESENHO', :OLD.COM_DESENHO, :NEW.COM_DESENHO);
    audita('COM_MATERIAL', :OLD.COM_MATERIAL, :NEW.COM_MATERIAL);
    audita('COM_DESCRICAO_MATERIAL', :OLD.COM_DESCRICAO_MATERIAL, :NEW.COM_DESCRICAO_MATERIAL);
    audita('COM_QTD', :OLD.COM_QTD, :NEW.COM_QTD);
    audita('COM_PERFIL', :OLD.COM_PERFIL, :NEW.COM_PERFIL);
    audita('COM_DIAMETRO_INT', :OLD.COM_DIAMETRO_INT, :NEW.COM_DIAMETRO_INT);
    audita('COM_DIAMETRO_EXT', :OLD.COM_DIAMETRO_EXT, :NEW.COM_DIAMETRO_EXT);
    audita('COM_ESPESSURA', :OLD.COM_ESPESSURA, :NEW.COM_ESPESSURA);
    audita('COM_LARGURA', :OLD.COM_LARGURA, :NEW.COM_LARGURA);
    audita('COM_COMPRIMENTO', :OLD.COM_COMPRIMENTO, :NEW.COM_COMPRIMENTO);
    audita('COM_DT_PRAZO', TO_CHAR(:OLD.COM_DT_PRAZO, c_data), TO_CHAR(:NEW.COM_DT_PRAZO, c_data));
    audita('COM_STATUS', :OLD.COM_STATUS, :NEW.COM_STATUS);
    audita('COM_FORNECEDOR', :OLD.COM_FORNECEDOR, :NEW.COM_FORNECEDOR);
    audita('COM_DT_COMPRA_MATERIAL', TO_CHAR(:OLD.COM_DT_COMPRA_MATERIAL, c_data), TO_CHAR(:NEW.COM_DT_COMPRA_MATERIAL, c_data));
    audita('COM_FRETE', :OLD.COM_FRETE, :NEW.COM_FRETE);
    audita('COM_NFE', :OLD.COM_NFE, :NEW.COM_NFE);
    audita('COM_DT_CHEGADA_MATERIAL', TO_CHAR(:OLD.COM_DT_CHEGADA_MATERIAL, c_data), TO_CHAR(:NEW.COM_DT_CHEGADA_MATERIAL, c_data));
    audita('COM_INFO_ADICIONAIS', :OLD.COM_INFO_ADICIONAIS, :NEW.COM_INFO_ADICIONAIS);
    audita('COM_HIST_DT_INICIO', TO_CHAR(:OLD.COM_HIST_DT_INICIO, c_timestamp), TO_CHAR(:NEW.COM_HIST_DT_INICIO, c_timestamp));
    audita('COM_HIST_DT_FIM', TO_CHAR(:OLD.COM_HIST_DT_FIM, c_timestamp), TO_CHAR(:NEW.COM_HIST_DT_FIM, c_timestamp));
    audita('COM_HIST_OPERACAO', :OLD.COM_HIST_OPERACAO, :NEW.COM_HIST_OPERACAO);
    audita('COM_HIST_USUARIO', :OLD.COM_HIST_USUARIO, :NEW.COM_HIST_USUARIO);
END;
/
ALTER TRIGGER "TG_AUD_COMPRAS_HIST" ENABLE;

CREATE OR REPLACE NONEDITIONABLE TRIGGER "TG_AUD_MATERIAIS_HIST"
BEFORE UPDATE OR DELETE ON LAB."MATERIAIS_HIST"
FOR EACH ROW
DECLARE
    c_timestamp CONSTANT VARCHAR2(30) := 'YYYY-MM-DD HH24:MI:SS.FF6';
    v_agora     TIMESTAMP := SYSTIMESTAMP;
    v_operacao  CHAR(1) := CASE WHEN DELETING THEN 'D' ELSE 'U' END;
    v_registro  NUMBER(10,0) := :OLD.MAT_HIST_ID;

    PROCEDURE audita(p_coluna VARCHAR2, p_antigo VARCHAR2, p_novo VARCHAR2) IS
    BEGIN
        PR_INSERE_AUDITORIA('MATERIAIS_HIST', v_registro, p_coluna, p_antigo, p_novo, v_operacao, v_agora);
    END;
BEGIN
    audita('MAT_HIST_ID', :OLD.MAT_HIST_ID, :NEW.MAT_HIST_ID);
    audita('MAT_ID', :OLD.MAT_ID, :NEW.MAT_ID);
    audita('MAT_NOME', :OLD.MAT_NOME, :NEW.MAT_NOME);
    audita('MAT_HIST_DT_INICIO', TO_CHAR(:OLD.MAT_HIST_DT_INICIO, c_timestamp), TO_CHAR(:NEW.MAT_HIST_DT_INICIO, c_timestamp));
    audita('MAT_HIST_DT_FIM', TO_CHAR(:OLD.MAT_HIST_DT_FIM, c_timestamp), TO_CHAR(:NEW.MAT_HIST_DT_FIM, c_timestamp));
    audita('MAT_HIST_OPERACAO', :OLD.MAT_HIST_OPERACAO, :NEW.MAT_HIST_OPERACAO);
    audita('MAT_HIST_USUARIO', :OLD.MAT_HIST_USUARIO, :NEW.MAT_HIST_USUARIO);
END;
/
ALTER TRIGGER "TG_AUD_MATERIAIS_HIST" ENABLE;

CREATE OR REPLACE NONEDITIONABLE TRIGGER "TG_AUD_DESENHOS_HIST"
BEFORE UPDATE OR DELETE ON LAB."DESENHOS_HIST"
FOR EACH ROW
DECLARE
    c_timestamp CONSTANT VARCHAR2(30) := 'YYYY-MM-DD HH24:MI:SS.FF6';
    v_agora     TIMESTAMP := SYSTIMESTAMP;
    v_operacao  CHAR(1) := CASE WHEN DELETING THEN 'D' ELSE 'U' END;
    v_registro  NUMBER(10,0) := :OLD.DES_HIST_ID;

    PROCEDURE audita(p_coluna VARCHAR2, p_antigo VARCHAR2, p_novo VARCHAR2) IS
    BEGIN
        PR_INSERE_AUDITORIA('DESENHOS_HIST', v_registro, p_coluna, p_antigo, p_novo, v_operacao, v_agora);
    END;
BEGIN
    audita('DES_HIST_ID', :OLD.DES_HIST_ID, :NEW.DES_HIST_ID);
    audita('DES_ID', :OLD.DES_ID, :NEW.DES_ID);
    audita('DES_NOME', :OLD.DES_NOME, :NEW.DES_NOME);
    audita('DES_HIST_DT_INICIO', TO_CHAR(:OLD.DES_HIST_DT_INICIO, c_timestamp), TO_CHAR(:NEW.DES_HIST_DT_INICIO, c_timestamp));
    audita('DES_HIST_DT_FIM', TO_CHAR(:OLD.DES_HIST_DT_FIM, c_timestamp), TO_CHAR(:NEW.DES_HIST_DT_FIM, c_timestamp));
    audita('DES_HIST_OPERACAO', :OLD.DES_HIST_OPERACAO, :NEW.DES_HIST_OPERACAO);
    audita('DES_HIST_USUARIO', :OLD.DES_HIST_USUARIO, :NEW.DES_HIST_USUARIO);
END;
/
ALTER TRIGGER "TG_AUD_DESENHOS_HIST" ENABLE;

CREATE OR REPLACE NONEDITIONABLE TRIGGER "TG_AUD_STATUS_HIST"
BEFORE UPDATE OR DELETE ON LAB."STATUS_HIST"
FOR EACH ROW
DECLARE
    c_timestamp CONSTANT VARCHAR2(30) := 'YYYY-MM-DD HH24:MI:SS.FF6';
    v_agora     TIMESTAMP := SYSTIMESTAMP;
    v_operacao  CHAR(1) := CASE WHEN DELETING THEN 'D' ELSE 'U' END;
    v_registro  NUMBER(10,0) := :OLD.STA_HIST_ID;

    PROCEDURE audita(p_coluna VARCHAR2, p_antigo VARCHAR2, p_novo VARCHAR2) IS
    BEGIN
        PR_INSERE_AUDITORIA('STATUS_HIST', v_registro, p_coluna, p_antigo, p_novo, v_operacao, v_agora);
    END;
BEGIN
    audita('STA_HIST_ID', :OLD.STA_HIST_ID, :NEW.STA_HIST_ID);
    audita('STA_ID', :OLD.STA_ID, :NEW.STA_ID);
    audita('STA_NOME', :OLD.STA_NOME, :NEW.STA_NOME);
    audita('STA_HIST_DT_INICIO', TO_CHAR(:OLD.STA_HIST_DT_INICIO, c_timestamp), TO_CHAR(:NEW.STA_HIST_DT_INICIO, c_timestamp));
    audita('STA_HIST_DT_FIM', TO_CHAR(:OLD.STA_HIST_DT_FIM, c_timestamp), TO_CHAR(:NEW.STA_HIST_DT_FIM, c_timestamp));
    audita('STA_HIST_OPERACAO', :OLD.STA_HIST_OPERACAO, :NEW.STA_HIST_OPERACAO);
    audita('STA_HIST_USUARIO', :OLD.STA_HIST_USUARIO, :NEW.STA_HIST_USUARIO);
END;
/
ALTER TRIGGER "TG_AUD_STATUS_HIST" ENABLE;

CREATE OR REPLACE NONEDITIONABLE TRIGGER "TG_AUD_SOLICITANTES_HIST"
BEFORE UPDATE OR DELETE ON LAB."SOLICITANTES_HIST"
FOR EACH ROW
DECLARE
    c_timestamp CONSTANT VARCHAR2(30) := 'YYYY-MM-DD HH24:MI:SS.FF6';
    v_agora     TIMESTAMP := SYSTIMESTAMP;
    v_operacao  CHAR(1) := CASE WHEN DELETING THEN 'D' ELSE 'U' END;
    v_registro  NUMBER(10,0) := :OLD.SOL_HIST_ID;

    PROCEDURE audita(p_coluna VARCHAR2, p_antigo VARCHAR2, p_novo VARCHAR2) IS
    BEGIN
        PR_INSERE_AUDITORIA('SOLICITANTES_HIST', v_registro, p_coluna, p_antigo, p_novo, v_operacao, v_agora);
    END;
BEGIN
    audita('SOL_HIST_ID', :OLD.SOL_HIST_ID, :NEW.SOL_HIST_ID);
    audita('SOL_ID', :OLD.SOL_ID, :NEW.SOL_ID);
    audita('SOL_NOME', :OLD.SOL_NOME, :NEW.SOL_NOME);
    audita('SOL_HIST_DT_INICIO', TO_CHAR(:OLD.SOL_HIST_DT_INICIO, c_timestamp), TO_CHAR(:NEW.SOL_HIST_DT_INICIO, c_timestamp));
    audita('SOL_HIST_DT_FIM', TO_CHAR(:OLD.SOL_HIST_DT_FIM, c_timestamp), TO_CHAR(:NEW.SOL_HIST_DT_FIM, c_timestamp));
    audita('SOL_HIST_OPERACAO', :OLD.SOL_HIST_OPERACAO, :NEW.SOL_HIST_OPERACAO);
    audita('SOL_HIST_USUARIO', :OLD.SOL_HIST_USUARIO, :NEW.SOL_HIST_USUARIO);
END;
/
ALTER TRIGGER "TG_AUD_SOLICITANTES_HIST" ENABLE;

CREATE OR REPLACE NONEDITIONABLE TRIGGER "TG_AUD_FORNECEDORES_HIST"
BEFORE UPDATE OR DELETE ON LAB."FORNECEDORES_HIST"
FOR EACH ROW
DECLARE
    c_timestamp CONSTANT VARCHAR2(30) := 'YYYY-MM-DD HH24:MI:SS.FF6';
    v_agora     TIMESTAMP := SYSTIMESTAMP;
    v_operacao  CHAR(1) := CASE WHEN DELETING THEN 'D' ELSE 'U' END;
    v_registro  NUMBER(10,0) := :OLD.FOR_HIST_ID;

    PROCEDURE audita(p_coluna VARCHAR2, p_antigo VARCHAR2, p_novo VARCHAR2) IS
    BEGIN
        PR_INSERE_AUDITORIA('FORNECEDORES_HIST', v_registro, p_coluna, p_antigo, p_novo, v_operacao, v_agora);
    END;
BEGIN
    audita('FOR_HIST_ID', :OLD.FOR_HIST_ID, :NEW.FOR_HIST_ID);
    audita('FOR_ID', :OLD.FOR_ID, :NEW.FOR_ID);
    audita('FOR_NOME', :OLD.FOR_NOME, :NEW.FOR_NOME);
    audita('FOR_HIST_DT_INICIO', TO_CHAR(:OLD.FOR_HIST_DT_INICIO, c_timestamp), TO_CHAR(:NEW.FOR_HIST_DT_INICIO, c_timestamp));
    audita('FOR_HIST_DT_FIM', TO_CHAR(:OLD.FOR_HIST_DT_FIM, c_timestamp), TO_CHAR(:NEW.FOR_HIST_DT_FIM, c_timestamp));
    audita('FOR_HIST_OPERACAO', :OLD.FOR_HIST_OPERACAO, :NEW.FOR_HIST_OPERACAO);
    audita('FOR_HIST_USUARIO', :OLD.FOR_HIST_USUARIO, :NEW.FOR_HIST_USUARIO);
END;
/
ALTER TRIGGER "TG_AUD_FORNECEDORES_HIST" ENABLE;

CREATE OR REPLACE NONEDITIONABLE TRIGGER "TG_AUD_CONDICOES_FRETE_HIST"
BEFORE UPDATE OR DELETE ON LAB."CONDICOES_FRETE_HIST"
FOR EACH ROW
DECLARE
    c_timestamp CONSTANT VARCHAR2(30) := 'YYYY-MM-DD HH24:MI:SS.FF6';
    v_agora     TIMESTAMP := SYSTIMESTAMP;
    v_operacao  CHAR(1) := CASE WHEN DELETING THEN 'D' ELSE 'U' END;
    v_registro  NUMBER(10,0) := :OLD.CON_FRE_HIST_ID;

    PROCEDURE audita(p_coluna VARCHAR2, p_antigo VARCHAR2, p_novo VARCHAR2) IS
    BEGIN
        PR_INSERE_AUDITORIA('CONDICOES_FRETE_HIST', v_registro, p_coluna, p_antigo, p_novo, v_operacao, v_agora);
    END;
BEGIN
    audita('CON_FRE_HIST_ID', :OLD.CON_FRE_HIST_ID, :NEW.CON_FRE_HIST_ID);
    audita('CON_FRE_ID', :OLD.CON_FRE_ID, :NEW.CON_FRE_ID);
    audita('CON_FRE_NOME', :OLD.CON_FRE_NOME, :NEW.CON_FRE_NOME);
    audita('CON_FRE_HIST_DT_INICIO', TO_CHAR(:OLD.CON_FRE_HIST_DT_INICIO, c_timestamp), TO_CHAR(:NEW.CON_FRE_HIST_DT_INICIO, c_timestamp));
    audita('CON_FRE_HIST_DT_FIM', TO_CHAR(:OLD.CON_FRE_HIST_DT_FIM, c_timestamp), TO_CHAR(:NEW.CON_FRE_HIST_DT_FIM, c_timestamp));
    audita('CON_FRE_HIST_OPERACAO', :OLD.CON_FRE_HIST_OPERACAO, :NEW.CON_FRE_HIST_OPERACAO);
    audita('CON_FRE_HIST_USUARIO', :OLD.CON_FRE_HIST_USUARIO, :NEW.CON_FRE_HIST_USUARIO);
END;
/
ALTER TRIGGER "TG_AUD_CONDICOES_FRETE_HIST" ENABLE;

CREATE OR REPLACE NONEDITIONABLE TRIGGER "TG_AUD_ORDENS_SERVICO_HIST"
BEFORE UPDATE OR DELETE ON LAB."ORDENS_SERVICO_HIST"
FOR EACH ROW
DECLARE
    c_timestamp CONSTANT VARCHAR2(30) := 'YYYY-MM-DD HH24:MI:SS.FF6';
    v_agora     TIMESTAMP := SYSTIMESTAMP;
    v_operacao  CHAR(1) := CASE WHEN DELETING THEN 'D' ELSE 'U' END;
    v_registro  NUMBER(10,0) := :OLD.OS_HIST_ID;

    PROCEDURE audita(p_coluna VARCHAR2, p_antigo VARCHAR2, p_novo VARCHAR2) IS
    BEGIN
        PR_INSERE_AUDITORIA('ORDENS_SERVICO_HIST', v_registro, p_coluna, p_antigo, p_novo, v_operacao, v_agora);
    END;
BEGIN
    audita('OS_HIST_ID', :OLD.OS_HIST_ID, :NEW.OS_HIST_ID);
    audita('OS_ID', :OLD.OS_ID, :NEW.OS_ID);
    audita('OS_NUMERO', :OLD.OS_NUMERO, :NEW.OS_NUMERO);
    audita('OS_SOLICITANTE', :OLD.OS_SOLICITANTE, :NEW.OS_SOLICITANTE);
    audita('OS_HIST_DT_INICIO', TO_CHAR(:OLD.OS_HIST_DT_INICIO, c_timestamp), TO_CHAR(:NEW.OS_HIST_DT_INICIO, c_timestamp));
    audita('OS_HIST_DT_FIM', TO_CHAR(:OLD.OS_HIST_DT_FIM, c_timestamp), TO_CHAR(:NEW.OS_HIST_DT_FIM, c_timestamp));
    audita('OS_HIST_OPERACAO', :OLD.OS_HIST_OPERACAO, :NEW.OS_HIST_OPERACAO);
    audita('OS_HIST_USUARIO', :OLD.OS_HIST_USUARIO, :NEW.OS_HIST_USUARIO);
END;
/
ALTER TRIGGER "TG_AUD_ORDENS_SERVICO_HIST" ENABLE;

CREATE OR REPLACE NONEDITIONABLE TRIGGER "TG_AUD_PERFIS_HIST"
BEFORE UPDATE OR DELETE ON LAB."PERFIS_HIST"
FOR EACH ROW
DECLARE
    c_timestamp CONSTANT VARCHAR2(30) := 'YYYY-MM-DD HH24:MI:SS.FF6';
    v_agora     TIMESTAMP := SYSTIMESTAMP;
    v_operacao  CHAR(1) := CASE WHEN DELETING THEN 'D' ELSE 'U' END;
    v_registro  NUMBER(10,0) := :OLD.PER_HIST_ID;

    PROCEDURE audita(p_coluna VARCHAR2, p_antigo VARCHAR2, p_novo VARCHAR2) IS
    BEGIN
        PR_INSERE_AUDITORIA('PERFIS_HIST', v_registro, p_coluna, p_antigo, p_novo, v_operacao, v_agora);
    END;
BEGIN
    audita('PER_HIST_ID', :OLD.PER_HIST_ID, :NEW.PER_HIST_ID);
    audita('PER_ID', :OLD.PER_ID, :NEW.PER_ID);
    audita('PER_NOME', :OLD.PER_NOME, :NEW.PER_NOME);
    audita('PER_HIST_DT_INICIO', TO_CHAR(:OLD.PER_HIST_DT_INICIO, c_timestamp), TO_CHAR(:NEW.PER_HIST_DT_INICIO, c_timestamp));
    audita('PER_HIST_DT_FIM', TO_CHAR(:OLD.PER_HIST_DT_FIM, c_timestamp), TO_CHAR(:NEW.PER_HIST_DT_FIM, c_timestamp));
    audita('PER_HIST_OPERACAO', :OLD.PER_HIST_OPERACAO, :NEW.PER_HIST_OPERACAO);
    audita('PER_HIST_USUARIO', :OLD.PER_HIST_USUARIO, :NEW.PER_HIST_USUARIO);
END;
/
ALTER TRIGGER "TG_AUD_PERFIS_HIST" ENABLE;

--------------------------------------------------------
--  Constraints for Tables
--------------------------------------------------------

ALTER TABLE "AUDITORIA" MODIFY ("AUD_ID" CONSTRAINT "CK_AUD_NN_01" NOT NULL ENABLE);
ALTER TABLE "AUDITORIA" MODIFY ("AUD_TABELA" CONSTRAINT "CK_AUD_NN_02" NOT NULL ENABLE);
ALTER TABLE "AUDITORIA" MODIFY ("AUD_REGISTRO" CONSTRAINT "CK_AUD_NN_03" NOT NULL ENABLE);
ALTER TABLE "AUDITORIA" MODIFY ("AUD_COLUNA" CONSTRAINT "CK_AUD_NN_04" NOT NULL ENABLE);
ALTER TABLE "AUDITORIA" MODIFY ("AUD_TP_OPERACAO" CONSTRAINT "CK_AUD_NN_05" NOT NULL ENABLE);
ALTER TABLE "AUDITORIA" MODIFY ("AUD_DATA_ENTRADA" CONSTRAINT "CK_AUD_NN_06" NOT NULL ENABLE);
ALTER TABLE "AUDITORIA" MODIFY ("AUD_BD_USER" CONSTRAINT "CK_AUD_NN_07" NOT NULL ENABLE);
ALTER TABLE "AUDITORIA" MODIFY ("AUD_SO_USER" CONSTRAINT "CK_AUD_NN_08" NOT NULL ENABLE);
ALTER TABLE "AUDITORIA" ADD CONSTRAINT "CK_AUD_TP_OPERACAO" CHECK ("AUD_TP_OPERACAO" IN ('U', 'D')) ENABLE;
ALTER TABLE "AUDITORIA" ADD CONSTRAINT "PK_AUDITORIA" PRIMARY KEY ("AUD_ID") USING INDEX ENABLE;
