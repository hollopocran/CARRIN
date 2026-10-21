-- ==============================================================================
-- CARRIN v1.3.580: Script SQL Completo de Configuração & RLS do Supabase
-- Executar no SQL Editor do painel do Supabase.
-- ==============================================================================

-- ==============================================================================
-- PASSO 0: CONSULTAS DE DIAGNÓSTICO (Opcional - executar antes para auditar)
-- ==============================================================================
-- 1. Verificar duplicatas em event_id antes de criar o índice único:
-- SELECT event_id, COUNT(*) FROM public.community_prices WHERE event_id IS NOT NULL GROUP BY event_id HAVING COUNT(*) > 1;
--
-- 2. Inspecionar todas as políticas RLS existentes para identificar políticas permissivas legadas:
-- SELECT policyname, permissive, roles, cmd, qual, with_check FROM pg_policies WHERE schemaname = 'public' AND tablename = 'community_prices';

-- ==============================================================================
-- PASSO 1: ESTRUTURA, EXTENSÕES E TABELA
-- ==============================================================================

-- Extensão para busca textual acelerada por trigramas
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Tabela de preços da comunidade
CREATE TABLE IF NOT EXISTS public.community_prices (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id text,
  product_name text NOT NULL,
  category text,
  unit text NOT NULL DEFAULT 'un',
  price numeric(10,2) NOT NULL,
  supermarket_name text NOT NULL,
  latitude double precision,
  longitude double precision,
  submitted_by text DEFAULT 'Cliente CARRIN',
  verified_receipt boolean DEFAULT false,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
  CONSTRAINT chk_community_price_positive CHECK (price > 0 AND price <= 50000),
  CONSTRAINT chk_community_coords_valid CHECK ((latitude IS NULL OR latitude BETWEEN -90.0 AND 90.0) AND (longitude IS NULL OR longitude BETWEEN -180.0 AND 180.0)),
  CONSTRAINT chk_community_name_length CHECK (length(trim(product_name)) BETWEEN 1 AND 200),
  CONSTRAINT chk_community_market_length CHECK (length(trim(supermarket_name)) BETWEEN 1 AND 200),
  CONSTRAINT chk_community_unit_valid CHECK (unit IN ('un', 'kg', 'g', 'l', 'ml', 'cx', 'pct', 'dz'))
);

-- ==============================================================================
-- PASSO 2: MIGRAÇÃO DE DADOS E CONSTRAINTS PARA TABELAS PRÉ-EXISTENTES
-- ==============================================================================

-- Coluna event_id
ALTER TABLE public.community_prices ADD COLUMN IF NOT EXISTS event_id text;

-- Saneamento e restrição NOT NULL na coluna unit
UPDATE public.community_prices SET unit = 'un' WHERE unit IS NULL;
ALTER TABLE public.community_prices ALTER COLUMN unit SET DEFAULT 'un';
ALTER TABLE public.community_prices ALTER COLUMN unit SET NOT NULL;

-- Restrições de domínio (idempotentes via DO blocks)
DO $$ BEGIN 
  ALTER TABLE public.community_prices ADD CONSTRAINT chk_community_price_positive CHECK (price > 0 AND price <= 50000); 
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN 
  ALTER TABLE public.community_prices ADD CONSTRAINT chk_community_coords_valid CHECK ((latitude IS NULL OR latitude BETWEEN -90.0 AND 90.0) AND (longitude IS NULL OR longitude BETWEEN -180.0 AND 180.0)); 
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN 
  ALTER TABLE public.community_prices ADD CONSTRAINT chk_community_name_length CHECK (length(trim(product_name)) BETWEEN 1 AND 200); 
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN 
  ALTER TABLE public.community_prices ADD CONSTRAINT chk_community_market_length CHECK (length(trim(supermarket_name)) BETWEEN 1 AND 200); 
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN 
  ALTER TABLE public.community_prices ADD CONSTRAINT chk_community_unit_valid CHECK (unit IN ('un', 'kg', 'g', 'l', 'ml', 'cx', 'pct', 'dz')); 
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ==============================================================================
-- PASSO 3: ÍNDICES DE PERFORMANCE E IDEMPOTÊNCIA
-- ==============================================================================

CREATE INDEX IF NOT EXISTS idx_community_product ON public.community_prices(product_name);
CREATE INDEX IF NOT EXISTS idx_community_market ON public.community_prices(supermarket_name);
CREATE INDEX IF NOT EXISTS idx_community_created ON public.community_prices(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_community_product_trgm ON public.community_prices USING gin (product_name gin_trgm_ops);

-- Remove qualquer índice parcial anterior e recria como UNIQUE padrão (não-parcial):
-- O PostgREST exige um índice/restrição UNIQUE não-parcial para inferir on_conflict=event_id.
DROP INDEX IF EXISTS public.idx_community_prices_event_id_unique;
CREATE UNIQUE INDEX IF NOT EXISTS idx_community_prices_event_id_unique ON public.community_prices(event_id);

-- ==============================================================================
-- PASSO 4: SEGURANÇA EM NÍVEL DE LINHA (RLS) E PRIVILÉGIOS MÍNIMOS
-- ==============================================================================

ALTER TABLE public.community_prices ENABLE ROW LEVEL SECURITY;

-- Revoga explicitamente de PUBLIC (todos os papéis herdados), além de anon e authenticated:
REVOKE ALL ON TABLE public.community_prices FROM PUBLIC, anon, authenticated;

-- Concede estritamente LEITURA (SELECT) e INSERÇÃO (INSERT) apenas a anon e authenticated
GRANT SELECT, INSERT ON TABLE public.community_prices TO anon, authenticated;

-- Limpeza de políticas RLS conhecidas
DROP POLICY IF EXISTS "Permitir leitura pública" ON public.community_prices;
DROP POLICY IF EXISTS "Permitir inserção pública" ON public.community_prices;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.community_prices;
DROP POLICY IF EXISTS "Enable insert for all users" ON public.community_prices;

-- Leitura pública para alimentar o feed comunitário, comparador e mapa
CREATE POLICY "Permitir leitura pública" 
  ON public.community_prices 
  FOR SELECT TO anon, authenticated 
  USING (true);

-- Inserção pública permitida, mas trava verified_receipt contra forjamento anônimo
CREATE POLICY "Permitir inserção pública" 
  ON public.community_prices 
  FOR INSERT TO anon, authenticated 
  WITH CHECK (verified_receipt IS NOT TRUE);
