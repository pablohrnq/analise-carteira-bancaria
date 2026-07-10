"""
Gerador de dados sintéticos - Projeto Análise de Carteira de Clientes (Banco)

Gera duas tabelas:
- clientes.csv       -> dados cadastrais (não mudam mês a mês)
- saldos_mensais.csv -> snapshots mensais de saldo e status (mudam mês a mês)
"""

import random
from datetime import date
from dateutil.relativedelta import relativedelta
from faker import Faker
import csv

fake = Faker("pt_BR")
random.seed(42)  # garante que o resultado é reproduzível (mesmo dataset toda vez que rodar)

N_CLIENTES = 500
DATA_INICIO_BASE = date(2023, 1, 1)   # cliente mais antigo possível
DATA_FIM = date(2026, 6, 1)            # "hoje" / último snapshot disponível

# ------------------------------------------------------------------
# 1) Gerar tabela CLIENTES
# ------------------------------------------------------------------
clientes = []
for id_cliente in range(1, N_CLIENTES + 1):
    # sorteia uma data de entrada aleatória entre 2023-01 e 2026-06
    dias_intervalo = (DATA_FIM - DATA_INICIO_BASE).days
    data_entrada = DATA_INICIO_BASE + relativedelta(days=random.randint(0, dias_intervalo))
    # arredonda pro dia 1 do mês (porque nossos snapshots são mensais)
    data_entrada = data_entrada.replace(day=1)

    # 20% Private, 80% Varejo (reflete proporção comum em bancos de varejo)
    tipo_cliente = random.choices(["Private", "Varejo"], weights=[0.2, 0.8])[0]

    clientes.append({
        "id_cliente": id_cliente,
        "nome_cliente": fake.name(),
        "data_entrada": data_entrada.isoformat(),
        "tipo_cliente": tipo_cliente,
    })

# ------------------------------------------------------------------
# 2) Gerar tabela SALDOS_MENSAIS
# ------------------------------------------------------------------
saldos = []

for c in clientes:
    data_entrada = date.fromisoformat(c["data_entrada"])
    tipo = c["tipo_cliente"]

    # saldo inicial depende do tipo de cliente
    if tipo == "Private":
        saldo = random.uniform(150_000, 400_000)
    else:
        saldo = random.uniform(5_000, 150_000)

    mes_atual = data_entrada
    encerrado = False

    while mes_atual <= DATA_FIM and not encerrado:
        # variação normal do saldo (aporte/resgate leve): -5% a +6%
        variacao = random.uniform(-0.05, 0.06)
        saldo = max(saldo * (1 + variacao), 0)

        # 5% de chance de um resgate grande em qualquer mês (exceto no 1º mês do cliente)
        if mes_atual != data_entrada and random.random() < 0.05:
            saldo = saldo * random.uniform(0.1, 0.3)  # perde 70-90% do saldo

        # 3% de chance, por mês, do cliente encerrar a conta
        if random.random() < 0.03:
            status = "Encerrado"
            encerrado = True
        else:
            status = "Ativo"

        saldos.append({
            "id_cliente": c["id_cliente"],
            "data": mes_atual.isoformat(),
            "valor_mes": round(saldo, 2),
            "status": status,
        })

        mes_atual = mes_atual + relativedelta(months=1)

# ------------------------------------------------------------------
# 3) Salvar em CSV
# ------------------------------------------------------------------
with open("/mnt/user-data/outputs/clientes.csv", "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=["id_cliente", "nome_cliente", "data_entrada", "tipo_cliente"])
    writer.writeheader()
    writer.writerows(clientes)

with open("/mnt/user-data/outputs/saldos_mensais.csv", "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=["id_cliente", "data", "valor_mes", "status"])
    writer.writeheader()
    writer.writerows(saldos)

print(f"Gerados {len(clientes)} clientes e {len(saldos)} registros de saldo mensal.")
