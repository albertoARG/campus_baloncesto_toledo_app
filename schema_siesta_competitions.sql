-- Esquema para Competiciones de Siesta (Ping pong, billar, bolos, etc.)

-- 1. Tabla: siesta_competitions
CREATE TABLE public.siesta_competitions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  nombre TEXT NOT NULL,
  juego TEXT NOT NULL, -- ej: 'Ping Pong', 'Billar', 'Tiro a canasta'
  formato TEXT NOT NULL CHECK (formato IN ('grupos_playoffs', 'liga', 'individual')),
  estado TEXT NOT NULL DEFAULT 'activa' CHECK (estado IN ('activa', 'finalizada')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.siesta_competitions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Siesta competitions viewable by everyone" ON public.siesta_competitions FOR SELECT USING (true);
CREATE POLICY "Admins/Coaches can manage siesta competitions" ON public.siesta_competitions FOR ALL USING (
  EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.role IN ('admin', 'entrenador'))
);

-- 2. Tabla: siesta_participants
-- Útil para ligas y grupos (para llevar el conteo de la clasificación de una liga, por ejemplo)
CREATE TABLE public.siesta_participants (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  competition_id UUID REFERENCES public.siesta_competitions(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  puntos_liga INTEGER DEFAULT 0,
  partidos_jugados INTEGER DEFAULT 0,
  partidos_ganados INTEGER DEFAULT 0,
  partidos_perdidos INTEGER DEFAULT 0,
  grupo TEXT, -- Ej: 'A', 'B' para formato 'grupos_playoffs'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(competition_id, user_id)
);

ALTER TABLE public.siesta_participants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Siesta participants viewable by everyone" ON public.siesta_participants FOR SELECT USING (true);
CREATE POLICY "Admins/Coaches can manage siesta participants" ON public.siesta_participants FOR ALL USING (
  EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.role IN ('admin', 'entrenador'))
);

-- 3. Tabla: siesta_matches
-- Enfrentamientos directos 1v1 para ligas o eliminatorias
CREATE TABLE public.siesta_matches (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  competition_id UUID REFERENCES public.siesta_competitions(id) ON DELETE CASCADE,
  participant1_id UUID REFERENCES public.siesta_participants(id) ON DELETE CASCADE,
  participant2_id UUID REFERENCES public.siesta_participants(id) ON DELETE CASCADE,
  score1 INTEGER DEFAULT 0,
  score2 INTEGER DEFAULT 0,
  ronda TEXT, -- Ej: 'Jornada 1', 'Cuartos de final'
  estado TEXT DEFAULT 'programado' CHECK (estado IN ('programado', 'finalizado')),
  fecha TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.siesta_matches ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Siesta matches viewable by everyone" ON public.siesta_matches FOR SELECT USING (true);
CREATE POLICY "Admins/Coaches can manage siesta matches" ON public.siesta_matches FOR ALL USING (
  EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.role IN ('admin', 'entrenador'))
);

-- 4. Tabla: siesta_daily_scores
-- Para el formato 'individual' donde cada día participan y acumulan puntos
CREATE TABLE public.siesta_daily_scores (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  competition_id UUID REFERENCES public.siesta_competitions(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  fecha DATE NOT NULL DEFAULT CURRENT_DATE,
  puntos INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.siesta_daily_scores ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Siesta daily scores viewable by everyone" ON public.siesta_daily_scores FOR SELECT USING (true);
CREATE POLICY "Admins/Coaches can manage siesta scores" ON public.siesta_daily_scores FOR ALL USING (
  EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.role IN ('admin', 'entrenador'))
);

-- 5. Activar Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.siesta_competitions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.siesta_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE public.siesta_matches;
ALTER PUBLICATION supabase_realtime ADD TABLE public.siesta_daily_scores;
