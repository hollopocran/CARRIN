-- ==============================================================================
-- CARRIN v1.3.580: Script SQL Completo de Configuração & RLS do Supabase
-- Executar no SQL Editor do painel do Supabase.
-- ==============================================================================

-- 1. Extensão para busca textual acelerada por trigramas
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 2. Tabela de preços da comunidade
CREATE TABLE IF NOT EXISTS public.community_prices (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id text,
  product_name text NOT NULL,
  category text,
  unit text DEFAULT 'un',
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

-- 3. Caso a tabela já exista de versões anteriores, assegura coluna e constraints:
ALTER TABLE public.community_prices ADD COLUMN IF NOT EXISTS event_id text;

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

-- 4. Índices de alta performance
CREATE INDEX IF NOT EXISTS idx_community_product ON public.community_prices(product_name);
CREATE INDEX IF NOT EXISTS idx_community_market ON public.community_prices(supermarket_name);
CREATE INDEX IF NOT EXISTS idx_community_created ON public.community_prices(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_community_product_trgm ON public.community_prices USING gin (product_name gin_trgm_ops);

-- 5. Substituição de índice parcial por UNIQUE padrão (não-parcial):
-- O PostgREST exige um índice/restrição UNIQUE não-parcial para inferir on_conflict=event_id.
-- Remove versão parcial anterior (se houver) e recria:
DROP INDEX IF EXISTS public.idx_community_prices_event_id_unique;
CREATE UNIQUE INDEX IF NOT EXISTS idx_community_prices_event_id_unique ON public.community_prices(event_id);

-- 6. Segurança em Nível de Linha (RLS) e Privilégios Mínimos
ALTER TABLE public.community_prices ENABLE ROW LEVEL SECURITY;

-- Revoga todos os privilégios públicos para fechar portas
REVOKE ALL ON TABLE public.community_prices FROM anon, authenticated;

-- Concede estritamente LEITURA (SELECT) e INSERÇÃO (INSERT)
GRANT SELECT, INSERT ON TABLE public.community_prices TO anon, authenticated;

-- Políticas RLS
DROP POLICY IF EXISTS "Permitir leitura pública" ON public.community_prices;
DROP POLICY IF EXISTS "Permitir inserção pública" ON public.community_prices;

-- Qualquer cliente pode consultar os preços para alimentar o comparador e mapa
CREATE POLICY "Permitir leitura pública" 
  ON public.community_prices 
  FOR SELECT TO anon, authenticated 
  USING (true);

-- Clientes anônimos podem inserir novos preços, MAS NÃO podem falsificar verified_receipt = true
CREATE POLICY "Permitir inserção pública" 
  ON public.community_prices 
  FOR INSERT TO anon, authenticated 
  WITH CHECK (verified_receipt IS NOT TRUE);
