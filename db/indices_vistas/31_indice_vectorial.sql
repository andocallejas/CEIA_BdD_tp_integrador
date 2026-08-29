-- Índice HNSW para búsqueda por similitud (distancia coseno) sobre el
-- embedding. Acelera el "vecino más cercano". Se crea después de poblar
-- los embeddings (script 30).
CREATE INDEX IF NOT EXISTS idx_intervencion_embedding_hnsw
    ON plata.intervencion USING hnsw (embedding vector_cosine_ops);
