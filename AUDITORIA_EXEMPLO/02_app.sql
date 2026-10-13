--------------------------------------------------------
--  Arquivo criado - Sexta-feira-Outubro-02-2026   
--------------------------------------------------------
--------------------------------------------------------
--  DDL for Sequence SEQ_PRD
--------------------------------------------------------

   CREATE SEQUENCE  "APP"."SEQ_PRD"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 2 NOCACHE  ORDER  NOCYCLE  NOKEEP  NOSCALE  GLOBAL ;
--------------------------------------------------------
--  DDL for Table H_PRODUTOS
--------------------------------------------------------

  CREATE TABLE "APP"."H_PRODUTOS" 
   (	"HPRD_ID" NUMBER(3,0), 
	"HPRD_NOME" VARCHAR2(100), 
	"HPRD_PRECO" NUMBER(8,2), 
	"HPRD_DT_ENTRADA" DATE
   ) ;
--------------------------------------------------------
--  DDL for Table PRODUTOS
--------------------------------------------------------

  CREATE TABLE "APP"."PRODUTOS" 
   (	"PRD_ID" NUMBER(3,0), 
	"PRD_NOME" VARCHAR2(100), 
	"PRD_PRECO" NUMBER(8,2)
   ) ;
--------------------------------------------------------
--  DDL for Trigger TG_HPRD
--------------------------------------------------------

  CREATE OR REPLACE NONEDITIONABLE TRIGGER "APP"."TG_HPRD" BEFORE
    UPDATE OR DELETE ON produtos
    FOR EACH ROW
BEGIN
    insert into h_produtos values (:old.prd_id, :old.prd_nome, :old.prd_preco, sysdate);
END;
/
ALTER TRIGGER "APP"."TG_HPRD" ENABLE;
--------------------------------------------------------
--  DDL for Trigger TG_SEQ_PRD
--------------------------------------------------------

  CREATE OR REPLACE NONEDITIONABLE TRIGGER "APP"."TG_SEQ_PRD" BEFORE
    INSERT ON produtos
    FOR EACH ROW
BEGIN
    :new.prd_id := seq_prd.nextval;
END;

/
ALTER TRIGGER "APP"."TG_SEQ_PRD" ENABLE;
--------------------------------------------------------
--  DDL for Trigger TG_SEQ_PRD
--------------------------------------------------------

  CREATE OR REPLACE NONEDITIONABLE TRIGGER "APP"."TG_SEQ_PRD" BEFORE
    INSERT ON produtos
    FOR EACH ROW
BEGIN
    :new.prd_id := seq_prd.nextval;
END;

/
ALTER TRIGGER "APP"."TG_SEQ_PRD" ENABLE;
--------------------------------------------------------
--  DDL for Trigger TG_HPRD
--------------------------------------------------------

  CREATE OR REPLACE NONEDITIONABLE TRIGGER "APP"."TG_HPRD" BEFORE
    UPDATE OR DELETE ON produtos
    FOR EACH ROW
BEGIN
    insert into h_produtos values (:old.prd_id, :old.prd_nome, :old.prd_preco, sysdate);
END;
/
ALTER TRIGGER "APP"."TG_HPRD" ENABLE;
--------------------------------------------------------
--  Constraints for Table H_PRODUTOS
--------------------------------------------------------

  ALTER TABLE "APP"."H_PRODUTOS" MODIFY ("HPRD_ID" NOT NULL ENABLE);
  ALTER TABLE "APP"."H_PRODUTOS" MODIFY ("HPRD_NOME" NOT NULL ENABLE);
  ALTER TABLE "APP"."H_PRODUTOS" MODIFY ("HPRD_PRECO" NOT NULL ENABLE);
  ALTER TABLE "APP"."H_PRODUTOS" MODIFY ("HPRD_DT_ENTRADA" NOT NULL ENABLE);
  ALTER TABLE "APP"."H_PRODUTOS" ADD CONSTRAINT "PK_HPRD" PRIMARY KEY ("HPRD_ID", "HPRD_DT_ENTRADA")
  USING INDEX  ENABLE;
--------------------------------------------------------
--  Constraints for Table PRODUTOS
--------------------------------------------------------

  ALTER TABLE "APP"."PRODUTOS" MODIFY ("PRD_ID" NOT NULL ENABLE);
  ALTER TABLE "APP"."PRODUTOS" MODIFY ("PRD_NOME" NOT NULL ENABLE);
  ALTER TABLE "APP"."PRODUTOS" MODIFY ("PRD_PRECO" NOT NULL ENABLE);
  ALTER TABLE "APP"."PRODUTOS" ADD CONSTRAINT "PK_PRD" PRIMARY KEY ("PRD_ID")
  USING INDEX  ENABLE;
