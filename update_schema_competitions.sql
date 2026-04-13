-- Esquema para Competiciones por Estaciones de Habilidades (Pruebas)

-- 1. Tabla: station_days (Ej: Día 1, Día 2)
CREATE TABLE public.station_days (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  nombre TEXT NOT NULL,
  fecha DATE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.station_days ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Station days viewable by everyone." ON public.station_days FOR SELECT USING (true);
CREATE POLICY "Admins/Coaches can manage station days" ON public.station_days FOR ALL USING (
  EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.role IN ('admin', 'entrenador'))
);

-- 2. Tabla: stations (Ej: Tiro, Bote, Pase)
CREATE TABLE public.stations (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  nombre TEXT NOT NULL,
  descripcion TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.stations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Stations viewable by everyone." ON public.stations FOR SELECT USING (true);
CREATE POLICY "Admins/Coaches can manage stations" ON public.stations FOR ALL USING (
  EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.role IN ('admin', 'entrenador'))
);

-- 3. Tabla: station_scores (Puntuaciones individuales)
CREATE TABLE public.station_scores (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  coach_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  station_id UUID REFERENCES public.stations(id) ON DELETE CASCADE,
  station_day_id UUID REFERENCES public.station_days(id) ON DELETE CASCADE,
  score INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.station_scores ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Scores viewable by everyone." ON public.station_scores FOR SELECT USING (true);
CREATE POLICY "Admins/Coaches can manage scores" ON public.station_scores FOR ALL USING (
  EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.role IN ('admin', 'entrenador'))
);

-- Activar Realtime para los marcadores
ALTER PUBLICATION supabase_realtime ADD TABLE public.station_scores;
