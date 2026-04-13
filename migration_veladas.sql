-- Migración para añadir soporte de "Veladas" y edades en la APP

-- 1. Añadir edad a los usuarios
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS edad INTEGER DEFAULT 0;

-- 2. Crear tabla veladas
CREATE TABLE IF NOT EXISTS public.veladas (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  nombre TEXT NOT NULL,
  fecha DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.veladas ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Veladas viewable by everyone" ON public.veladas FOR SELECT USING (true);
CREATE POLICY "Veladas manageable by admins/coaches" ON public.veladas FOR ALL USING (
  EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.role IN ('admin', 'entrenador'))
);

-- 3. Crear tabla velada_groups
CREATE TABLE IF NOT EXISTS public.velada_groups (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  velada_id UUID REFERENCES public.veladas(id) ON DELETE CASCADE,
  nombre TEXT NOT NULL,
  is_winner BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.velada_groups ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Velada groups viewable by everyone" ON public.velada_groups FOR SELECT USING (true);
CREATE POLICY "Velada groups manageable by admins/coaches" ON public.velada_groups FOR ALL USING (
  EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.role IN ('admin', 'entrenador'))
);

-- 4. Crear tabla velada_group_members
CREATE TABLE IF NOT EXISTS public.velada_group_members (
  group_id UUID REFERENCES public.velada_groups(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  is_captain BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  PRIMARY KEY (group_id, user_id)
);

ALTER TABLE public.velada_group_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Velada group members viewable by everyone" ON public.velada_group_members FOR SELECT USING (true);
CREATE POLICY "Velada group members manageable by admins/coaches" ON public.velada_group_members FOR ALL USING (
  EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.role IN ('admin', 'entrenador'))
);
