-- Crear tabla para las estadísticas de los jugadores por partido/evento
CREATE TABLE player_match_stats (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    match_name TEXT, -- Nombre del partido o evento, ej: "Final 3x3", "Entrenamiento martes", etc.
    points INT DEFAULT 0,
    rebounds INT DEFAULT 0,
    assists INT DEFAULT 0,
    steals INT DEFAULT 0,
    blocks INT DEFAULT 0,
    is_mvp BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Políticas de RLS para player_match_stats
ALTER TABLE player_match_stats ENABLE ROW LEVEL SECURITY;

-- Permitir lectura a todos (o se puede restringir si se desea)
CREATE POLICY "Lectura de estadisticas publica" 
ON player_match_stats FOR SELECT 
USING (true);

-- Permitir a admins y entrenadores insertar/editar/borrar estadísticas
CREATE POLICY "Staff puede gestionar estadisticas"
ON player_match_stats FOR ALL 
USING (
  EXISTS (
    SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin', 'entrenador')
  )
);
