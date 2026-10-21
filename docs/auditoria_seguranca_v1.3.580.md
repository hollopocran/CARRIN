# Dossiê de Auditoria de Segurança e Desempenho - CARRIN v1.3.580

**Versão:** CARRIN v1.3.580  
**Data da Auditoria:** 21 de Outubro de 2026  
**Commit de Referência:** `4690d8f`  
**Escopo:** Endurecimento da infraestrutura Supabase (PostgreSQL / PostgREST) e cliente Flutter (`CommunityPriceService`).

---

## 1. Resumo Executivo e Parecer

A presente auditoria avaliou a camada de persistência de dados colaborativos (`public.community_prices`), o controle de acesso por linha (Row Level Security - RLS), as restrições de integridade relacional, o mecanismo de idempotência de rede e a otimização de busca textual por trigramas.

**Parecer:** **Aprovado com ressalvas operacionais documentadas**. A infraestrutura em produção está protegida contra injeção de recibos forjados, adulteração/exclusão de registros por agentes públicos, payloads inválidos e eventos duplicados, apresentando tempo de resposta sub-5ms em buscas textuais.

---

## 2. Matriz de Controles e Evidências Empíricas

### 2.1 Controle de Acesso e Privilégios (PostgreSQL Catalog)

Consulta executada em `information_schema.role_table_grants` para a tabela `public.community_prices`:

| Papel | Privilégios Concedidos | is_grantable | Status |
| :--- | :--- | :---: | :---: |
| `anon` | **`INSERT`, `SELECT`** | NO | ✅ Mínimo Privilégio |
| `authenticated` | **`INSERT`, `SELECT`** | NO | ✅ Mínimo Privilégio |
| `postgres` | `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `REFERENCES`, `TRIGGER` | YES | ✅ Superusuário |
| `service_role` | `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `REFERENCES`, `TRIGGER` | NO | ✅ Administrativo |

*Evidência:* Privilégios destrutivos (`UPDATE`, `DELETE`, `TRUNCATE`, `TRIGGER`, `REFERENCES`) foram expressamente revogados de `PUBLIC`, `anon` e `authenticated`.

#### 2.1.1 Privilégios Efetivos Reais (`has_table_privilege`)

Resultado da validação com o resolvedor nativo do PostgreSQL (considerando heranças, grupos e concessões a `PUBLIC`):

| Papel | can_select | can_insert | can_update | can_delete | can_truncate | Status Efetivo |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| `anon` | **true** | **true** | **false** | **false** | **false** | ✅ Protegido |
| `authenticated` | **true** | **true** | **false** | **false** | **false** | ✅ Protegido |

*Conclusão:* O motor do PostgreSQL certifica que `anon` e `authenticated` não possuem privilégios efetivos para modificar (`UPDATE`), excluir (`DELETE`) ou truncar (`TRUNCATE`) a tabela.

### 2.2 Sondas de Segurança (RLS e Imutabilidade)

Executadas via cliente HTTP público utilizando a chave anônima:

| Sonda | Operação Testada | Payload / Parâmetro | Código HTTP | Código SQLSTATE | Resultado |
| :---: | :--- | :--- | :---: | :---: | :---: |
| **01** | `SELECT` Legítimo | Leitura pública | 200 OK | - | Sucesso |
| **02** | `INSERT` Legítimo | `verified_receipt: false` | 201 Created | - | Sucesso |
| **03** | `INSERT` Forjado | `verified_receipt: true` | 403 Forbidden | `42501` | **Bloqueado por RLS** |
| **04** | `UPDATE` Público | Tentativa de alteração de preço | 403 Forbidden | `42501` | **Bloqueado por Permissão** |
| **05** | `DELETE` Público | Tentativa de exclusão de registro | 403 Forbidden | `42501` | **Bloqueado por Permissão** |

### 2.3 Sondas de Integridade e Constraints

Validação de integridade física no catálogo PostgreSQL:

| Sonda | Constraint Auditada | Regra Violada | Código HTTP | Código SQLSTATE | Resultado |
| :---: | :--- | :--- | :---: | :---: | :---: |
| **06** | `chk_community_price_positive` | Preço negativo (`price: -5.00`) | 400 Bad Request | `23514` | **Rejeitado** |
| **07** | `chk_community_price_positive` | Preço exorbitante (`price: 99999.00`) | 400 Bad Request | `23514` | **Rejeitado** |
| **08** | `chk_community_unit_valid` | Unidade ilegal (`unit: 'litro'`) | 400 Bad Request | `23514` | **Rejeitado** |
| **09** | `chk_community_coords_valid` | Latitude fora da faixa (`lat: 95.0`) | 400 Bad Request | `23514` | **Rejeitado** |
| **10** | `chk_community_name_length` | Nome de produto em branco | 400 Bad Request | `23514` | **Rejeitado** |
| **11** | `chk_community_market_length` | Nome de mercado em branco | 400 Bad Request | `23514` | **Rejeitado** |

### 2.4 Idempotência de Rede

- **Mecanismo:** Índice único B-Tree não parcial `idx_community_prices_event_id_unique` em `public.community_prices(event_id)`.
- **Cabeçalhos PostgREST:** `Prefer: resolution=ignore-duplicates` com query param `on_conflict=event_id`.
- **Sonda 12:** Envio duplicado do evento `test_idempotency_audit_001`.
  - 1º Envio: HTTP 201 Created.
  - 2º Envio: HTTP 201 Created (ignorado silenciosamente pelo motor ON CONFLICT DO NOTHING).
  - Verificação no banco: Exatamente **1 linha** persistida. Duplicação física prevenida com sucesso.

---

## 3. Desempenho do Otimizador de Consultas (GIN Trigram Index)

Execução do plano com rastreamento de buffers de memória:

```sql
EXPLAIN (ANALYZE, COSTS, BUFFERS)
SELECT id, product_name, price, market_name, created_at
FROM public.community_prices
WHERE product_name ILIKE '%Arroz%'
ORDER BY created_at DESC
LIMIT 50;
```

### Métricas Obtidas em Produção:

- **Plano de Execução:** `Bitmap Heap Scan` alimentado por `Bitmap Index Scan on idx_community_product_trgm`.
- **Tempo de Varredura do Índice:** **0,167 ms**.
- **Tempo Total de Execução:** **4,308 ms**.
- **Linhas Casadas / Retornadas:** 255 linhas filtradas sobre a base histórica.
- **Buffers de Memória:**
  - `Index Scan`: 8 shared hits, 0 leituras de disco (`read=0`).
  - `Heap Scan`: 160 shared hits, 0 leituras de disco (`read=0`).
  - **Total de Cache Hit:** 168 blocos lidos 100% da memória compartilhada do PostgreSQL.

---

## 4. Auditoria de Segredos e Superfície de Código

1. **Varredura Estática de Credenciais:**
   - Comando: `git grep -i "service_role"` -> **Zero ocorrências**.
   - Comando: `git grep -i "sb_secret"` -> **Zero ocorrências**.
   - Nenhuma chave mestra ou de bypass RLS está presente na árvore do repositório ou nos assets do cliente.
2. **Camada de Transporte do Cliente (`CommunityPriceService`):**
   - Headers utilizam estritamente o header `apikey` com o token público (`anon`), suportando tokens legados JWT e as novas chaves `sb_publishable_...`.
   - Serialização do campo `verified_receipt` travada em `false` na saída do cliente (`json['verified_receipt'] = false`).

---

## 5. Qualidade de Código e Cobertura de Testes

- **Analisador Estático Dart:**
  ```text
  $ dart analyze
  Analyzing CARRIN...
  No issues found!
  ```
- **Suíte de Testes Automatizados:**
  ```text
  $ flutter test
  00:04 +73: All tests passed!
  ```
  - Testes cobrem: Acessibilidade/Daltonismo, Background Update Checker, Community Price Service (SQL, contratos, validação prévia de batch, mitigação de falhas de rede), Parsers de cupom fiscal e NFC-e, Formatação de moeda e Navegação.

---

## 6. Ressalvas Técnicas e Recomendações

### 6.1 Tratamento do Comando `TRUNCATE` e Funções RPC
- **Camada REST (PostgREST):** O PostgREST não expõe nenhum verbo HTTP ou endpoint nativo capaz de invocar `TRUNCATE`. Além disso, a configuração padrão do PostgREST expõe estritamente o schema `public` (`pgrst.db_schemas = 'public'`).
- **Camada de Catálogo:** O comando `REVOKE ALL ON TABLE public.community_prices FROM PUBLIC, anon, authenticated;` revoga explicitamente o privilégio `TRUNCATE` para `PUBLIC`, `anon` e `authenticated`.
- **Auditoria de Rotinas RPC em `public` (`information_schema.routines`):**
  - Todas as 31 rotinas presentes no schema `public` pertencem exclusivamente à extensão oficial `pg_trgm` (operações matemáticas e de indexação GIN/GiST).
  - Todas possuem `is_security_definer = false` (`security_type: INVOKER`).
  - **Zero rotinas customizadas** e **zero funções `SECURITY DEFINER`** no schema público.
- **Validação de Privilégios Efetivos Concluída:**
  - A execução de `has_table_privilege()` retornou rigorosamente `false` para `can_update`, `can_delete` e `can_truncate` em ambos os papéis (`anon` e `authenticated`).
  - Isso encerra a ressalva de privilégios efetivos, certificando que não existem permissões residuais herdadas de papéis intermediários ou via concessões legadas a `PUBLIC`.

### 6.2 Chave `service_role`
- A chave `service_role` permanece protegida exclusivamente no painel administrativo do Supabase e em eventuais Edge Functions de manutenção. Não deve, sob nenhuma hipótese, ser adicionada a arquivos `.env` empacotados no APK.

### 6.3 Identidade Persistente de Itens (`item_uuid`) - Roadmap v1.3.581+
- A idempotência comprovada na sonda 12 protege contra retransmissões de rede de um mesmo envio de compra.
- No SQLite local, `DatabaseHelper.saveItems()` apaga e recria registros de itens, gerando novos `id` inteiros (autoincrement).
- **Ação Futura:** Na versão v1.3.581+, adicionar coluna `item_uuid TEXT NOT NULL` na tabela SQLite `items` gerada no momento da criação do item, tornando a identidade de eventos imune a reescritas de listas locais.

---

## 7. Verificação do Artefato Liberado

Para registrar a rastreabilidade do binário final distribuído na Google Play Store ou GitHub Releases, deve-se gerar e arquivar o hash SHA-256 do pacote:

```bash
# Para APK de distribuição direta:
sha256sum build/app/outputs/flutter-apk/app-release.apk

# Para Android App Bundle (Google Play):
sha256sum build/app/outputs/bundle/release/app-release.aab
```

O hash obtido deve ser anexado à release note junto à tag `v1.3.580`.
