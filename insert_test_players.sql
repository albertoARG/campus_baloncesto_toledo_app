-- Script para insertar 30 jugadores de prueba con datos variados
-- Ejecuta esto en el Editor SQL de Supabase

DO $$
DECLARE
    new_user_id UUID;
    i INT;
    -- Listas de nombres y apellidos españoles para variedad
    nombres TEXT[] := ARRAY['Lucas', 'Mateo', 'Leo', 'Daniel', 'Hugo', 'Alvaro', 'Adrian', 'David', 'Diego', 'Javier', 'Mario', 'Sergio', 'Marcos', 'Manuel', 'Nicolas', 'Ivan', 'Pablo', 'Carlos', 'Jorge', 'Raul', 'Marc', 'Pau', 'Juan', 'Ricky', 'Santi', 'Usman', 'Willy', 'Juancho', 'Alex', 'Victor'];
    apellidos TEXT[] := ARRAY['Garcia', 'Martinez', 'Rodriguez', 'Sanchez', 'Perez', 'Gomez', 'Martin', 'Jimenez', 'Ruiz', 'Hernandez', 'Diaz', 'Moreno', 'Muñoz', 'Alvarez', 'Romero', 'Alonso', 'Gutierrez', 'Navarro', 'Torres', 'Domenech', 'Gasol', 'Hernangomez', 'Rubio', 'Aldama', 'Garuba', 'Llull', 'Fernandez', 'Abrines', 'Almansa', 'Mara'];
    posiciones TEXT[] := ARRAY['Base', 'Escolta', 'Alero', 'Ala-Pívot', 'Pívot'];
BEGIN
    FOR i IN 1..30 LOOP
        -- Generamos un nuevo UUID para el usuario
        new_user_id := uuid_generate_v4();
        
        -- 1. Insertamos en auth.users (necesario para la integridad referencial)
        -- Usamos una contraseña dummy 'password123'
        INSERT INTO auth.users (
            id, 
            instance_id, 
            email, 
            encrypted_password, 
            email_confirmed_at, 
            raw_app_meta_data, 
            raw_user_meta_data, 
            created_at, 
            updated_at, 
            role, 
            aud, 
            confirmation_token
        )
        VALUES (
            new_user_id,
            '00000000-0000-0000-0000-000000000000',
            'jugador' || i || '@campus.com',
            '$2a$10$7EQJZS8r9iZWhfIn9/O.9uH0.h3K.j9D.p8B.p8B.p8B.p8B.p8B.', -- hash dummy
            now(),
            '{"provider":"email","providers":["email"]}',
            jsonb_build_object('nombre', nombres[i], 'apellidos', apellidos[i]),
            now(),
            now(),
            'authenticated',
            'authenticated',
            ''
        );

        -- 2. El trigger 'handle_new_user' ya habrá creado la fila en public.users.
        -- Ahora la actualizamos con datos aleatorios (estatura, posición y rol fijo de jugador)
        UPDATE public.users 
        SET 
            role = 'jugador',
            posicion = posiciones[floor(random() * 5 + 1)],
            -- Estatura aleatoria entre 1.65 y 2.10 metros
            estatura = round((1.65 + (random() * 0.45))::numeric, 2)
        WHERE id = new_user_id;

    END LOOP;
    
    RAISE NOTICE 'Se han insertado 30 jugadores de prueba correctamente.';
END $$;
