#!/bin/bash
# Rodado pelo container só na primeira inicialização do banco (volume vazio).
# Arquivos .sql nesta pasta rodariam como SYS no CDB; aqui cada script roda no XEPDB1 com o usuário dono dele.
# O marcador só é criado se todos os scripts rodarem sem erro; o healthcheck do compose depende dele.
sqlplus -s / as sysdba <<SQL &&
WHENEVER SQLERROR EXIT FAILURE
ALTER SESSION SET CONTAINER = XEPDB1;
@/ddl/controle_compras_usuarios.sql
SQL
sqlplus -s lab/lab@//localhost/XEPDB1 <<SQL &&
WHENEVER SQLERROR EXIT FAILURE
@/ddl/controle_compras_ddl.sql
@/ddl/controle_compras_temporal_ddl.sql
SQL
sqlplus -s lab_audit/lab_audit@//localhost/XEPDB1 <<SQL &&
WHENEVER SQLERROR EXIT FAILURE
@/ddl/controle_compras_auditoria_ddl.sql
SQL
touch /opt/oracle/oradata/.schema_criado
