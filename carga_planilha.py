"""Carrega no banco Oracle as compras da planilha CONTROLE_COMPRAS.xlsx, uma carga por período.

Pré-requisito: controle_compras_ddl.sql e controle_compras_temporal_ddl.sql já executados.
Conecta como LAB no banco do docker-compose (localhost:1521/XEPDB1).

Uso: python carga_planilha.py <1|2|3|apagar>
  1, 2, 3  sobe as compras do período da carga
  apagar   remove todas as compras (as tabelas de domínio são cadastro e ficam)
"""
import sys
from datetime import datetime
from pathlib import Path

import openpyxl
import oracledb

PLANILHA = Path(__file__).with_name("CONTROLE_COMPRAS.xlsx")
ABA = "MATÉRIA PRIMA (2)"

# Períodos [início, fim) por COM_DT_PEDIDO: fev a ago/2026 em meses inteiros, o mais equilibrado possível.
CARGAS = {
    1: (datetime(2026, 2, 1), datetime(2026, 4, 1)),  # fev–mar: 155 compras
    2: (datetime(2026, 4, 1), datetime(2026, 7, 1)),  # abr–jun: 253 compras
    3: (datetime(2026, 7, 1), datetime(2026, 9, 1)),  # jul–ago: 165 compras
}
CABECALHO = (
    "PRIORIDADE", "Data", "Solicitante", "Desenho Nº", "O.S", "Material", "Descricao Material",
    "Quant.", "Perfil", "Diâmetro Interno", "Diâmetro Externo", "Espessura", "Largura", "Compr.:",
    "Prazo", "Status", "Fornecedor", "Data da Compra", "CIF", "FOB", "Nº NF-e",
    "Chegada M.P na 3D-O", "Informações adicionais",
)
OBRIGATORIOS = ("Data", "Solicitante", "Desenho Nº", "O.S", "Material", "Quant.", "Fornecedor")

# (campo do registro, tabela, coluna id, coluna nome)
DOMINIOS = (
    ("solicitante", "SOLICITANTES", "SOL_ID", "SOL_NOME"),
    ("desenho", "DESENHOS", "DES_ID", "DES_NOME"),
    ("material", "MATERIAIS", "MAT_ID", "MAT_NOME"),
    ("perfil", "PERFIS", "PER_ID", "PER_NOME"),
    ("status", "STATUS", "STA_ID", "STA_NOME"),
    ("fornecedor", "FORNECEDORES", "FOR_ID", "FOR_NOME"),
    ("frete", "CONDICOES_FRETE", "CON_FRE_ID", "CON_FRE_NOME"),
)

INSERT_COMPRA = """
    INSERT INTO COMPRAS (
        COM_DT_PEDIDO, COM_OS, COM_DESENHO, COM_MATERIAL, COM_DESCRICAO_MATERIAL, COM_QTD,
        COM_PERFIL, COM_DIAMETRO_INT, COM_DIAMETRO_EXT, COM_ESPESSURA, COM_LARGURA,
        COM_COMPRIMENTO, COM_DT_PRAZO, COM_STATUS, COM_FORNECEDOR, COM_DT_COMPRA_MATERIAL,
        COM_FRETE, COM_NFE, COM_DT_CHEGADA_MATERIAL, COM_INFO_ADICIONAIS
    ) VALUES (
        :dt_pedido, :os, :desenho, :material, :descricao, :qtd,
        :perfil, :diametro_int, :diametro_ext, :espessura, :largura,
        :comprimento, :dt_prazo, :status, :fornecedor, :dt_compra,
        :frete, :nfe, :dt_chegada, :info
    )"""


def texto(valor):
    if valor is None:
        return None
    return " ".join(str(valor).split()) or None


def medida(valor):
    # float em todas as linhas evita troca de tipo do bind (int/float) no executemany
    return None if valor is None else float(valor)


def ler_planilha(caminho):
    planilha = openpyxl.load_workbook(caminho, read_only=True, data_only=True)
    linhas = planilha[ABA].iter_rows(max_col=len(CABECALHO), values_only=True)
    cabecalho = tuple(texto(c) for c in next(linhas))
    if cabecalho != CABECALHO:
        sys.exit(f"Cabeçalho inesperado na aba '{ABA}': {cabecalho}")

    compras = []
    for numero, valores in enumerate(linhas, start=2):
        if all(texto(v) is None for v in valores):
            continue
        linha = dict(zip(CABECALHO, valores))
        faltando = [coluna for coluna in OBRIGATORIOS if texto(linha[coluna]) is None]
        if faltando:
            print(f"Linha {numero} ignorada, sem: {', '.join(faltando)}")
            continue
        compras.append({
            "dt_pedido": linha["Data"],
            "solicitante": texto(linha["Solicitante"]),
            "desenho": texto(linha["Desenho Nº"]),
            "os": texto(linha["O.S"]),
            "material": texto(linha["Material"]),
            "descricao": texto(linha["Descricao Material"]),
            "qtd": linha["Quant."],
            "perfil": texto(linha["Perfil"]),
            "diametro_int": medida(linha["Diâmetro Interno"]),
            "diametro_ext": medida(linha["Diâmetro Externo"]),
            "espessura": medida(linha["Espessura"]),
            "largura": medida(linha["Largura"]),
            "comprimento": medida(linha["Compr.:"]),
            "dt_prazo": linha["Prazo"],
            "status": texto(linha["Status"]),
            "fornecedor": texto(linha["Fornecedor"]),
            "dt_compra": linha["Data da Compra"],
            "frete": "CIF" if texto(linha["CIF"]) else "FOB" if texto(linha["FOB"]) else None,
            "nfe": texto(linha["Nº NF-e"]),
            "dt_chegada": linha["Chegada M.P na 3D-O"],
            "info": texto(linha["Informações adicionais"]),
        })
    return compras


def carregar_dominio(cursor, tabela, coluna_id, colunas, chaves):
    """Insere as chaves que ainda não existem na tabela e devolve o mapa chave -> id."""
    consulta = f"SELECT {', '.join(colunas)}, {coluna_id} FROM {tabela}"
    existentes = {linha[:-1]: linha[-1] for linha in cursor.execute(consulta)}
    novas = [chave for chave in dict.fromkeys(chaves) if chave not in existentes]
    if novas:
        binds = ", ".join(f":{i}" for i in range(1, len(colunas) + 1))
        cursor.executemany(f"INSERT INTO {tabela} ({', '.join(colunas)}) VALUES ({binds})", novas)
    print(f"{tabela}: {len(novas)} inseridos")
    return {linha[:-1]: linha[-1] for linha in cursor.execute(consulta)}


def conectar():
    return oracledb.connect(user="lab", password="lab", dsn="localhost:1521/XEPDB1")


def carregar(numero):
    inicio, fim = CARGAS[numero]
    compras = [c for c in ler_planilha(PLANILHA) if inicio <= c["dt_pedido"] < fim]
    print(f"Carga {numero}: {len(compras)} compras de {inicio:%d/%m/%Y} a {fim:%d/%m/%Y} (exclusive)")

    with conectar() as conexao, conexao.cursor() as cursor:
        existentes = cursor.execute("SELECT COUNT(*) FROM COMPRAS").fetchone()[0]
        if existentes:
            sys.exit(f"COMPRAS já tem {existentes} registros; rode 'apagar' antes da próxima carga.")

        for campo, tabela, coluna_id, coluna_nome in DOMINIOS:
            ids = carregar_dominio(cursor, tabela, coluna_id, (coluna_nome,),
                                   [(c[campo],) for c in compras if c[campo]])
            for c in compras:
                c[campo] = ids.get((c[campo],))

        # Na planilha a mesma O.S aparece com solicitantes diferentes: cada par vira uma ORDENS_SERVICO.
        ordens = carregar_dominio(cursor, "ORDENS_SERVICO", "OS_ID", ("OS_NUMERO", "OS_SOLICITANTE"),
                                  [(c["os"], c["solicitante"]) for c in compras])
        for c in compras:
            c["os"] = ordens[(c["os"], c.pop("solicitante"))]

        cursor.executemany(INSERT_COMPRA, compras)
        conexao.commit()
        print(f"COMPRAS: {len(compras)} inseridos")


def apagar():
    with conectar() as conexao, conexao.cursor() as cursor:
        cursor.execute("DELETE FROM COMPRAS")
        conexao.commit()
        print(f"COMPRAS: {cursor.rowcount} apagados")


def main():
    comando =sys.argv[1] if len(sys.argv) > 1 else None
    if comando == "apagar":
        apagar()
    elif comando in ("1", "2", "3"):
        carregar(int(comando))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
