-- Habilitar la extensión para generar UUIDs y pgcrypto si no estuvieran (usualmente ya están)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Tabla: users
-- Extiende auth.users
CREATE TABLE public.users (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  role TEXT NOT NULL DEFAULT 'jugador' CHECK (role IN ('admin', 'entrenador', 'jugador', 'familiar')),
  nombre TEXT NOT NULL,
  apellidos TEXT NOT NULL,
  foto_url TEXT,
  posicion TEXT,
  estatura NUMERIC,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- RLS para users
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public profiles are viewable by everyone." ON public.users FOR SELECT USING (true);
CREATE POLICY "Users can insert their own profile." ON public.users FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update own profile." ON public.users FOR UPDATE USING (auth.uid() = id);

-- 2. Tabla: competitions
CREATE TABLE public.competitions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  nombre TEXT NOT NULL,
  tipo TEXT NOT NULL CHECK (tipo IN ('fase_grupos', 'eliminatorias', 'velada')),
  fecha_inicio DATE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.competitions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Competitions are viewable by everyone." ON public.competitions FOR SELECT USING (true);
CREATE POLICY "Only admins can insert competitions" ON public.competitions FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.role = 'admin')
);
CREATE POLICY "Only admins can update competitions" ON public.competitions FOR UPDATE USING (
  EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.role = 'admin')
);

-- 3. Tabla: teams
CREATE TABLE public.teams (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  nombre TEXT NOT NULL,
  categoria TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Teams are viewable by everyone." ON public.teams FOR SELECT USING (true);
CREATE POLICY "Admins/Coaches can insert teams." ON public.teams FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.role IN ('admin', 'entrenador'))
);

-- 4. Tabla: team_members
CREATE TABLE public.team_members (
  team_id UUID REFERENCES public.teams(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  PRIMARY KEY (team_id, user_id)
);

ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Team members are viewable by everyone." ON public.team_members FOR SELECT USING (true);
CREATE POLICY "Admins/Coaches can modify team members" ON public.team_members FOR ALL USING (
  EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.role IN ('admin', 'entrenador'))
);

-- 5. Tabla: matches
CREATE TABLE public.matches (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  competition_id UUID REFERENCES public.competitions(id) ON DELETE CASCADE,
  team1_id UUID REFERENCES public.teams(id),
  team2_id UUID REFERENCES public.teams(id),
  resultado_1 INTEGER DEFAULT 0,
  resultado_2 INTEGER DEFAULT 0,
  estado TEXT DEFAULT 'programado' CHECK (estado IN ('programado', 'en_curso', 'finalizado')),
  mvp_user_id UUID REFERENCES public.users(id),
  fecha TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Matches are viewable by everyone." ON public.matches FOR SELECT USING (true);
CREATE POLICY "Admins/Coaches can manage matches" ON public.matches FOR ALL USING (
  EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.role IN ('admin', 'entrenador'))
);

-- 6. Tabla: statistics
CREATE TABLE public.statistics (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  match_id UUID REFERENCES public.matches(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  puntos INTEGER DEFAULT 0,
  rebotes INTEGER DEFAULT 0,
  asistencias INTEGER DEFAULT 0,
  robos INTEGER DEFAULT 0,
  tapones INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.statistics ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Stats are viewable by everyone." ON public.statistics FOR SELECT USING (true);
CREATE POLICY "Admins/Coaches can manage stats." ON public.statistics FOR ALL USING (
  EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.role IN ('admin', 'entrenador'))
);

-- 7. Tabla: trainings
CREATE TABLE public.trainings (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  titulo TEXT NOT NULL,
  descripcion TEXT,
  multimedia_url TEXT,
  fecha TIMESTAMP WITH TIME ZONE,
  team_id UUID REFERENCES public.teams(id) ON DELETE SET NULL,
  coach_id UUID REFERENCES public.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.trainings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Trainings are viewable by assigned team/coach or admin." ON public.trainings FOR SELECT USING (true);
CREATE POLICY "Admins/Coaches can manage trainings." ON public.trainings FOR ALL USING (
  EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.role IN ('admin', 'entrenador'))
);

-- 8. Tabla: posts (Blog)
CREATE TABLE public.posts (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  titulo TEXT NOT NULL,
  contenido TEXT,
  imagen_url TEXT,
  autor_id UUID REFERENCES public.users(id),
  fecha_publicacion TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Posts are viewable by everyone." ON public.posts FOR SELECT USING (true);
CREATE POLICY "Admins can manage posts." ON public.posts FOR ALL USING (
  EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.role = 'admin')
);

-- TRIGER para crear un public.user automáticamente cuando un usuario se registra en auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, role, nombre, apellidos)
  VALUES (
    new.id,
    'jugador', -- rol por defecto
    COALESCE(new.raw_user_meta_data->>'nombre', 'Sin nombre'),
    COALESCE(new.raw_user_meta_data->>'apellidos', '')
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- Crear bucket de storage si no existe (Requiere clave de servicio o se hace desde UI)
-- Se recomienda hacerlo desde la UI de Supabase:
-- 1. Crear bucket 'avatars' (Público)
-- 2. Crear bucket 'campus_media' (Público)

-- Activar subscripciones Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.matches;
ALTER PUBLICATION supabase_realtime ADD TABLE public.competitions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.statistics;
