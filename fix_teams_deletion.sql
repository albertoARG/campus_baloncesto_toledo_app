-- Fix para permitir borrar y editar grupos (teams)
-- Además de corregir las claves foráneas en matches para que no bloqueen el borrado

-- 1. Añadir políticas que faltaban para la tabla teams
CREATE POLICY "Admins/Coaches can update teams." ON public.teams 
FOR UPDATE USING (
  EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.role IN ('admin', 'entrenador'))
);

CREATE POLICY "Admins/Coaches can delete teams." ON public.teams 
FOR DELETE USING (
  EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.role IN ('admin', 'entrenador'))
);

-- 2. Corregir claves foráneas en matches para que permitan borrar grupos
-- (Actualmente bloquean el borrado si hay un partido donde participó el equipo)
ALTER TABLE public.matches 
DROP CONSTRAINT matches_team1_id_fkey,
ADD CONSTRAINT matches_team1_id_fkey 
  FOREIGN KEY (team1_id) REFERENCES public.teams(id) ON DELETE SET NULL;

ALTER TABLE public.matches 
DROP CONSTRAINT matches_team2_id_fkey,
ADD CONSTRAINT matches_team2_id_fkey 
  FOREIGN KEY (team2_id) REFERENCES public.teams(id) ON DELETE SET NULL;
