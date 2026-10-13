--------------------------------------------------------
--  Usuários do banco
--  Executar como SYS ou SYSTEM no PDB XEPDB1, antes dos outros scripts:
--    controle_compras_ddl.sql e controle_compras_temporal_ddl.sql como LAB,
--    controle_compras_auditoria_ddl.sql como LAB_AUDIT.
--
--  LAB é dono das tabelas. LAB_AUDIT é dono da auditoria, que o LAB não acessa;
--  CREATE ANY TRIGGER permite ao LAB_AUDIT criar os triggers de auditoria nas tabelas do LAB.
--------------------------------------------------------

CREATE USER LAB IDENTIFIED BY lab QUOTA UNLIMITED ON USERS;
GRANT CONNECT, RESOURCE TO LAB;

CREATE USER LAB_AUDIT IDENTIFIED BY lab_audit QUOTA UNLIMITED ON USERS;
GRANT CONNECT, RESOURCE TO LAB_AUDIT;
GRANT CREATE ANY TRIGGER TO LAB_AUDIT;
