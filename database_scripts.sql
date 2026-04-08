CREATE EXTENSION IF NOT EXISTS google_ml_integration CASCADE;
CREATE EXTENSION IF NOT EXISTS vector;

DROP TABLE IF EXISTS shipments;
DROP TABLE IF EXISTS products;

-- 1. Product Inventory Table

CREATE TABLE products (
id SERIAL PRIMARY KEY,
name VARCHAR(255) NOT NULL,
category VARCHAR(100),
stock_level INTEGER,
distribution_center VARCHAR(100),
region VARCHAR(50),
embedding vector(768),
last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Logistics & Shipments
CREATE TABLE shipments (
shipment_id SERIAL PRIMARY KEY,
product_id INTEGER REFERENCES products(id),
status VARCHAR(50), -- 'In Transit', 'Delayed', 'Delivered', 'Pending'
estimated_arrival TIMESTAMP,
route_efficiency_score DECIMAL(3, 2)
);

-- We use a CROSS JOIN pattern with realistic naming segments to create meaningful variety
DO $$
DECLARE
brand_names TEXT[] := ARRAY['Black PF(Bakelite) Powder (SI-650)', 'Black Bakelite Powder(SI-610)', 
'Black Bakelite Powder (SI-750)', 'Black Bakelite Powder (SI-750)', 
'Color Bakelite Powder (SI-621)', 'Black Bakelite Powder (SI-911)', 
'Black Bakelite Powder (SI-630)', 'Natural Bakelite Powder(SI-163)', 
'Brown Bakelite Powder(SI-915)', 'Cotton Filled Reinforced Powder (SI-171)',
'Cotton Filled Reinforced Powder (SI-915)','Glass Filled Reinforced Powder(SI-042)',
'Mica Powder(SI-621)’,’Graphite Powder(SI-621)','Glass Filled Powder(SI-621)'];
product_types TEXT[] := ARRAY['SI-650', 'SI-610', 'SI-750', 'SI-750','SI-621', 'SI-911', 'SI-630', 'SI-163', 'SI-915', 'SI-171', 'SI-915','SI-042','SI-621','SI-621','SI-621'];
variants TEXT[] := ARRAY['Black PF(Bakelite) Powder (SI-650)', 'Black Bakelite Powder(SI-610)', 
'Black Bakelite Powder (SI-750)', 'Black Bakelite Powder (SI-750)', 
'Color Bakelite Powder (SI-621)', 'Black Bakelite Powder (SI-911)', 
'Black Bakelite Powder (SI-630)', 'Natural Bakelite Powder(SI-163)', 
'Brown Bakelite Powder(SI-915)', 'Cotton Filled Reinforced Powder (SI-171)',
'Cotton Filled Reinforced Powder (SI-915)','Glass Filled Reinforced Powder(SI-042)','Mica Powder(SI-621)',
'Graphite Powder(SI-621)','Glass Filled Powder(SI-621)'];
regions TEXT[] := ARRAY['EMEA', 'APAC', 'LATAM', 'NAMER'];
dcs TEXT[] := ARRAY['Gujarat', 'Maharashtra', 'Daman', 'Rajasthan', 'Delhi', 'Karnataka'];
BEGIN
INSERT INTO products (name, category, stock_level, distribution_center, region)
SELECT
b || ' ' || v || ' ' || t as name,
CASE
WHEN t IN ('Black PF(Bakelite) Powder (SI-650)', 'Black Bakelite Powder(SI-610)', 'Black Bakelite Powder (SI-750)', 'Black Bakelite Powder (SI-750)’,’Cotton Filled Reinforced Powder (SI-915)’,’Graphite Powder(SI-621)’) THEN ‘Wood Flour’
WHEN t IN ('Cotton Filled Reinforced Powder (SI-621)') THEN ‘Cotton’
ELSE 'Fiber Glass '
END as category,
floor(random() * 20000 + 100)::int as stock_level,
dcs[floor(random() * 6 + 1)] as distribution_center,
regions[floor(random() * 4 + 1)] as region
FROM
unnest(brand_names) b,
unnest(variants) v,
unnest(product_types) t,
generate_series(1, 50); -- 10 * 10 * 10 * 50 = 50,000 records
END $$;

-- These ensure you have predictable answers for specific "Executive" questions
INSERT INTO products (name, category, stock_level, distribution_center, region) VALUES
('Black PF(Bakelite) Powder (SI-650)', 'Wood Flour', 1000, 'Gujarat', 'EMEA'),
('Black Bakelite Powder (SI-750)', 'Wood Flour', 500, 'Maharashtra', 'APAC'),
('Cotton Filled Reinforced Powder (SI-621)', 'Cotton', 1000, 'Rajasthan', 'EMEA');

-- Shipments Generation (More shipments than products)
INSERT INTO shipments (product_id, status, estimated_arrival, route_efficiency_score)
SELECT
id,
CASE
WHEN random() > 0.8 THEN 'Delayed'
WHEN random() > 0.4 THEN 'In Transit'
ELSE 'Delivered'
END,
NOW() + (random() * 10 || ' days')::interval,
(random() * 0.5 + 0.5)::decimal(3,2)
FROM products
WHERE random() > 0.3; -- Create shipments for ~70% of products


-- Add duplicate shipments for some products to show complex logistics
INSERT INTO shipments (product_id, status, estimated_arrival, route_efficiency_score)
SELECT id, 'In Transit', NOW() + INTERVAL '12 days', 0.88
FROM products
LIMIT 5000;

-- Grant embedding execute permission for postgres user
GRANT EXECUTE ON FUNCTION embedding TO postgres;

-- Update embeddings
WITH
 rows_to_update AS (
 SELECT
   id
 FROM
   products
 WHERE
   embedding IS NULL
 LIMIT
   5000 )
UPDATE
 products
SET
 embedding = ai.embedding(text-embedding-005', name || ' ' || category || ' ' || distribution_center || ' ' || region)::vector
FROM
 rows_to_update
WHERE
 products.id = rows_to_update.id
 AND embedding IS null;
