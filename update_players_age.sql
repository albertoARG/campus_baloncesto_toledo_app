-- Actualizar a los jugadores actuales con edades aleatorias entre 8 y 18 años
UPDATE public.users 
SET edad = floor(random() * 11 + 8) 
WHERE role = 'jugador' AND (edad IS NULL OR edad = 0);
