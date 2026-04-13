-- 1. Actualizar la restricción CHECK de roles en la tabla de usuarios
-- Para PostgreSQL, añadir un valor a un CHECK requiere un pequeño truco (eliminar la vieja y crear otra)
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE public.users ADD CONSTRAINT users_role_check CHECK (role IN ('admin', 'entrenador', 'jugador', 'familiar', 'visitante'));

-- 2. Actualizar el valor por defecto de la columna role
ALTER TABLE public.users ALTER COLUMN role SET DEFAULT 'visitante';

-- 3. Actualizar el Trigger para que asigne visitante
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, role, nombre, apellidos)
  VALUES (
    new.id,
    'visitante', -- NUEVO ROL POR DEFECTO
    COALESCE(new.raw_user_meta_data->>'nombre', 'Sin nombre'),
    COALESCE(new.raw_user_meta_data->>'apellidos', '')
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
