# Racionalização de Índices e Engenharia de Performance no SQL Server

> Projeto de engenharia de performance em banco de dados focado na identificação e remoção de índices redundantes no SQL Server.

## 📌 Visão Geral

Ambientes enterprise de SQL Server podem acumular índices duplicados e sobrepostos ao longo do tempo, aumentando o consumo de armazenamento e o overhead de manutenção dos índices.

Este projeto analisa as definições dos índices, estatísticas de carga de trabalho (workload) e uso de armazenamento para identificar oportunidades seguras de **racionalização de índices**.

Todas as informações específicas do ambiente foram anonimizadas.

## 👨‍💻 Minha Contribuição

Responsável pela identificação, análise e validação de índices redundantes no SQL Server, incluindo:

- Desenvolvimento de consultas T-SQL para inventário e análise de uso de índices
- Identificação de índices exatamente duplicados
- Análise de índices sobrepostos com colunas de chave idênticas
- Avaliação da carga de trabalho de leitura/escrita (read/write)
- Análise de impacto no armazenamento
- Avaliação de risco antes da remoção dos índices
- Validação dos resultados de otimização

## 🎯 Objetivos

- Identificar índices exatamente duplicados
- Identificar índices com as mesmas colunas de chave e sobreposição de colunas `INCLUDE`
- Analisar a atividade de leitura e escrita
- Avaliar o consumo de armazenamento dos índices
- Identificar índices redundantes adequados para remoção
- Reduzir a manutenção desnecessária de índices e o uso de armazenamento

## 🔎 Análise

A análise combina metadados do SQL Server com estatísticas da carga de trabalho.

### Estrutura do Índice

- Colunas de chave (Key columns)
- Ordem de ordenação (Sort order)
- Colunas incluídas (`INCLUDE`)
- Tipo de índice
- Constraints primárias e únicas

### Carga de Trabalho (Workload)

- `user_seeks`
- `user_scans`
- `user_lookups`
- `user_updates`
- Leituras totais
- Relação leitura/escrita

### Armazenamento

- Espaço reservado pelo índice
- Economia potencial de armazenamento
- Prioridade de otimização

## 🏗️ Processo de Racionalização

```text
Inventário de Índices
          ↓
Detecção de Duplicados
          ↓
Análise de Chave + INCLUDE
          ↓
Análise de Uso
          ↓
Análise de Armazenamento
          ↓
Avaliação de Risco
          ↓
Validação de Candidatos
          ↓
Remoção do Índice
          ↓
Validação Pós-Mudança
```

## 🧪 Implementação Técnica

A análise foi implementada em T-SQL e automatizada em todos os bancos de dados de usuários online.

O script coleta:

- Metadados do índice
- Colunas de chave e ordem de ordenação
- Colunas `INCLUDE`
- Definições de filtro
- Tamanho do índice
- Contagem de linhas
- Atividade de leitura
- Atividade de escrita

Assinaturas de índice são geradas usando hashes `SHA2_256` para comparar as estruturas dos índices com eficiência.

A análise identifica três padrões:

1. **Duplicados exatos** — definições idênticas de KEY, INCLUDE e FILTER
2. **Mesma KEY + FILTER** — chaves de acesso idênticas com colunas INCLUDE potencialmente diferentes

A decisão final de remover um índice é baseada na carga de trabalho, impacto no armazenamento, propriedades do índice e avaliação de risco, em vez de focar apenas na similaridade estrutural.

## 1. Índices Exatamente Duplicados

O primeiro padrão envolve índices com colunas de chave e ordenação idênticas.

Exemplo:

```text
Índice A

KEY:
    CustomerID ASC
    ContractID ASC
```

```text
Índice B

KEY:
    CustomerID ASC
    ContractID ASC
```

Quando dois índices fornecem o mesmo caminho de acesso e nenhum oferece funcionalidade adicional, um deles se torna candidato à remoção.

A decisão foi validada contra estatísticas de uso, propriedades do índice e características da carga de trabalho.

---

## 2. Mesmas Colunas de Chave + Sobreposição de INCLUDE

Um cenário mais complexo ocorre quando dois índices contêm as mesmas colunas de chave, mas colunas incluídas diferentes.

Exemplo:

```text
Índice A

KEY:
    CustomerID
    ContractID

INCLUDE:
    CustomerType
    SourceID
    DueDate
    Status
```

```text
Índice B

KEY:
    CustomerID
    ContractID

INCLUDE:
    CustomerType
    SourceID
```

Nessa situação, os índices não são duplicados exatos.

Portanto, a análise avaliou se um dos índices já fornecia cobertura suficiente para a carga de trabalho relevante.

Os seguintes fatores foram considerados:

- Estrutura das colunas de chave
- Colunas `INCLUDE`
- Cobertura de consultas
- Atividade de leitura
- Atividade de escrita
- Key lookups
- Footprint de armazenamento
- Características da carga de trabalho

---

## 📊 Resultados

| Métrica | Resultado |
|---|---:|
| Bancos de dados SQL Server | Múltiplos |
| Padrões de redundância | **2** |
| Índices exatamente duplicados | Identificados |
| Mesma Chave + sobreposição de INCLUDE | Identificados |
| Armazenamento liberado | **~16,66 GB** |
| Maior otimização individual | **9.038,18 MB** |
| Maior volume de leituras observado | **319,5M+** |
| Maior volume de atualizações observado | **3,27M+** |

### Principais Impactos

# **~16,66 GB de Armazenamento de Índices Liberado**

Além da otimização de armazenamento, a remoção de índices redundantes pode reduzir o overhead de manutenção gerado por operações de `INSERT`, `UPDATE` e `DELETE`.

# 📈 Principais Descobertas

A análise identificou índices redundantes em múltiplos bancos de dados, schemas e tabelas.

Para preservar a confidencialidade, todos os nomes de objetos e identificadores específicos do ambiente foram anonimizados.

---

## 🥇 Maior Otimização Individual

```text
Descoberta:
Mesma Chave + Sobreposição de INCLUDE

Armazenamento Liberado:
9.038,18 MB

≈ 8,83 GB
```

Esta foi a maior otimização individual de armazenamento identificada durante a análise.

---

## 🥈 Grande Duplicado Exato

```text
Descoberta:
Duplicado Exato

Armazenamento Liberado:
3.230,41 MB

≈ 3,15 GB
```

O candidato representava um footprint significativo de índice redundante.

---

## 🥉 Outro Duplicado de Alto Impacto

```text
Descoberta:
Duplicado Exato

Armazenamento Liberado:
3.162,33 MB

≈ 3,09 GB
```

O índice apresentava um consumo de armazenamento significativo, enquanto não mostrava nenhuma atividade de leitura/escrita registrada na janela analisada das DMVs.

---

# ⚡ Exemplo de Alta Manutenção de Escrita

Um dos candidatos apresentou as seguintes características de carga de trabalho:

```text
Atualizações (Updates):
3.270.678

Leituras (Reads):
241

Armazenamento Liberado:
70,55 MB
```

Embora a economia de armazenamento tenha sido relativamente pequena, o índice representava uma atividade significativa de manutenção de escrita.

Isso demonstra que a racionalização de índices não é um exercício exclusivo de otimização de espaço.

A remoção de índices desnecessários também reduz o overhead de manutenção gerado por operações de:

```text
INSERT
UPDATE
DELETE
```

## 💡 Considerações de Engenharia

Um índice não foi considerado redundante com base apenas no baixo uso.

A análise considerou:

- Definição do índice
- Colunas de chave
- Colunas `INCLUDE`
- Atividade de leitura
- Atividade de escrita
- Cobertura de consultas
- Footprint de armazenamento
- Impacto potencial no plano de execução

Um índice com alto volume de leituras ainda pode ser redundante se outro índice fornecer o caminho de acesso necessário.

## 🧰 Tecnologias

- Microsoft SQL Server
- T-SQL
- SQL Server DMVs
- `sys.indexes`
- `sys.index_columns`
- `sys.dm_db_index_usage_stats`
- `sys.dm_db_partition_stats`
- Racionalização de Índices (Index Rationalization)
- Ajuste de Performance de Banco de Dados (Database Performance Tuning)
- Análise de Performance de Consultas (Query Performance Analysis)
- Otimização de Armazenamento (Storage Optimization)
- Análise de Carga de Trabalho (Workload Analysis)

## 📌 Conclusão

Este projeto demonstra uma abordagem prática para a **Racionalização de Índices no SQL Server**, combinando metadados de índices, estatísticas de carga de trabalho e análise de armazenamento para identificar estruturas redundantes.

A iniciativa resultou em aproximadamente:

# **16,66 GB de Armazenamento Liberado**

enquanto reduziu estruturas de índices redundantes e manutenções desnecessárias em um ambiente SQL Server contendo múltiplos bancos de dados.
