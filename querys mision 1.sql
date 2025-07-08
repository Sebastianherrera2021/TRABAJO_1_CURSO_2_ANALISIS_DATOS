-- 1. Obtener todas las mascotas con el nombre de su propietario 
USE veterinaria;
SELECT m.nombre AS Nombre_Mascota,
       m.raza, 
       m.especie, 
       p.nombre AS Nombre_propietario, 
       p.telefono AS Contacto_Cliente, 
       p.email
FROM mascotas AS m
INNER JOIN propietarios AS p
ON m.id_propietario = p.id_propietario;

-- 2. Ver citas con nombre de mascota y veterinario
use veterinaria;
select c.id_cita, 
       m.nombre as nombre_mascota,
       v.nombre as nombre_veterinario,
       c.fecha_hora,
       c.motivo
from citas as c
join mascotas as m on c.id_mascota = m.id_mascota
join veterinarios as v on c.id_veterinario = v.id_veterinario;

-- 3. Medicamentos suministrados en cada cita
use veterinaria;
select 
case
when medicamentos_suministrados.id_cita is null then
citas.id_cita 
else medicamentos_suministrados.id_cita
end as cita,
case
when medicamentos_suministrados.id_medicamento is null then
'-- Ninguno --'
else medicamentos.nombre
end as medicamento_suministrado
from medicamentos_suministrados
join medicamentos
on medicamentos.id_medicamento = medicamentos_suministrados.id_medicamento
right join citas
on citas.id_cita = medicamentos_suministrados.id_cita
;

-- 4. Servicios agendados por cada mascota
USE veterinaria;
SELECT m.nombre AS Nombre_mascota,
       m.especie,
       m.sexo,
       m.peso_kg,
       sa.id_servicio,
       s.servicio,
       s.descripcion,
       sa.fecha_hora AS Agenda_Dia,
       sa.estado
FROM mascotas AS m
LEFT JOIN servicios_agendados AS sa
ON m.id_mascota = m.id_mascota
INNER JOIN servicios AS s
ON sa.id_servicio = s.id_servicio
ORDER BY fecha_hora ASC;

-- 5. Veterinarios que han atendido mascotas
USE veterinaria;
SELECT v.nombre AS Nombre_Veterinario,
       v.especialidad,
       m.nombre AS Nombre_Mascota,
       m.raza,
       c.fecha_hora
FROM veterinarios AS v
LEFT JOIN citas AS c
ON v.id_veterinario = c.id_veterinario 
INNER JOIN mascotas AS m
ON c.id_mascota = m.id_mascota
ORDER BY c.fecha_hora;

-- 6. Mascotas que tienen más de 2 citas
use veterinaria;
SELECT 
    m.id_mascota,
    m.nombre AS nombre_mascota,
    m.especie,
    m.raza,
    COUNT(c.id_cita) AS total_citas
FROM citas AS c
JOIN mascotas AS m ON c.id_mascota = m.id_mascota
GROUP BY m.id_mascota, m.nombre, m.especie, m.raza
HAVING COUNT(c.id_cita) > 2;

-- 7. Medicamentos sin stock
use veterinaria;
select id_medicamento, nombre
from medicamentos
where stock < 1;

-- 8. Facturas mayores al promedio
USE vetenerinarios;
SELECT f.id_propietario,
	   p.nombre,
       f.fecha_emision,
       f.estado,
	   ROUND(AVG(f.total) OVER(ORDER BY f.fecha_emision), 2) AS Promedio_total
FROM facturacion AS f
INNER JOIN propietarios AS p
ON f.id_propietario = p.id_propietario;

-- 9. Total acumulado de facturación por propietario
use veterinaria;
select p.nombre, 
sum(f.total) as total_acumulado,
sum(
case
when f.estado = 'Pendiente' then
f.total
else 0
end) as saldo_pendiente
from facturacion f
join propietarios p on f.id_propietario = p.id_propietario
group by p.nombre;

-- 10. Ranking de citas por mascota
use veterinaria;
SELECT 
    ROW_NUMBER() OVER (ORDER BY COUNT(c.id_cita) DESC) AS ranking,
    m.id_mascota,
    m.nombre AS nombre_mascota,
    COUNT(c.id_cita) AS total_citas
FROM citas AS c
JOIN mascotas AS m ON c.id_mascota = m.id_mascota
GROUP BY m.id_mascota, m.nombre
ORDER BY total_citas DESC;

-- 11. Crear vista de historial clínico extendido
USE veterinaria;
CREATE VIEW historial_medico_extendido  AS
SELECT h.id_historial,
       h.fecha_registro AS Fecha_Historial,
       m.nombre AS Nombre_Mascota,
       m.raza,
       m.especie,
       m.peso_kg,
       c.fecha_hora AS Ingreso_cita,
       c.motivo,
       c.estado,
       h.descripcion,
       s.servicio,
       sg.fecha_hora,
       sg.estado AS Estado_Servicio
FROM historial_clinico AS h
INNER JOIN mascotas AS m
ON h.id_mascota = m.id_mascota
LEFT JOIN citas AS c
ON h.id_cita = c.id_cita
LEFT JOIN servicios_agendados AS sg
ON m.id_mascota = sg.id_mascota
INNER JOIN servicios AS s
ON sg.id_servicio = s.id_servicio
ORDER BY h.fecha_registro;

-- 12. Vista de servicios realizados por mascota
USE veterinaria;
CREATE VIEW vista_servicios_realizados_por_mascota AS
SELECT
    m.id_mascota,
    m.nombre AS nombre_mascota,
    s.id_servicio,
    s.servicio AS servicio
FROM servicios_agendados AS sa
JOIN mascotas AS m ON sa.id_mascota = m.id_mascota
JOIN servicios AS s ON sa.id_servicio = s.id_servicio;

-- 13. Procedimiento almacenado para registrar nueva cita
DELIMITER //
CREATE PROCEDURE insertar_cita(
IN p_id_mascota INT,
IN p_id_veterinario INT,
IN p_fecha DATETIME,
IN p_motivo TEXT,
IN p_estado TEXT
)
BEGIN
DECLARE next_id INT;
SELECT IFNULL(MAX(id_cita), 0) + 1 INTO next_id FROM citas;
INSERT INTO citas (
id_cita,
id_mascota,
id_veterinario,
fecha_hora,
motivo,
estado
)
VALUES (
next_id,
p_id_mascota,
p_id_veterinario,
p_fecha,
p_motivo,
p_estado
);
END  //
DELIMITER ;

-- 14. Trigger para reducir stock de medicamento al suministrarlo
DELIMITER $$
CREATE TRIGGER reducir_stock_medicamento
AFTER INSERT ON medicamentos_suministrados
FOR EACH ROW
BEGIN
    UPDATE medicamentos
    SET stock = stock - 1
    WHERE id_medicamento = NEW.id_medicamento;
END;
$$
DELIMITER ;

-- 15. Trigger actualizar facturas
DELIMITER //
CREATE TRIGGER actualizar_total_factura
BEFORE UPDATE ON facturacion
FOR EACH ROW
BEGIN
DECLARE linea TEXT;
DECLARE nuevo_valor DOUBLE;
SET linea = TRIM(SUBSTRING_INDEX(NEW.descripcion, '//', -1));
SET nuevo_valor = TRIM(SUBSTRING_INDEX(linea, '...', -1));
SET NEW.total = OLD.total + CAST(nuevo_valor AS DOUBLE);
END;
//
DELIMITER ;