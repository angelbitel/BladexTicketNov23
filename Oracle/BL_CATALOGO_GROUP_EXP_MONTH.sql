create or replace PROCEDURE "BL_CATALOGO_GROUP_EXP_MONTH" (
   in_criteriodebusqueda   IN       VARCHAR2 DEFAULT NULL,
   in_adicional1           IN       VARCHAR2 DEFAULT NULL,
   in_adicional2           IN       VARCHAR2 DEFAULT NULL,
   in_adicional3           IN       VARCHAR2 DEFAULT NULL,
   out_resultado           OUT      sys_refcursor
)
AS
BEGIN
   IF in_criteriodebusqueda IS NULL
   THEN
      BEGIN
         OPEN out_resultado FOR
            select level as codigo, to_char(date '2000-12-01' + numtoyminterval(level,'month'),'MONTH') as descripcion,
            '' AS adicional1, '' AS adicional2, '' AS adicional3 
            from dual
            connect by level <= 12;
      END;
   ELSE
      BEGIN
         OPEN out_resultado FOR
            SELECT codigo, descripcion
            FROM (select level as codigo, to_char(date '2000-12-01' + numtoyminterval(level,'month'),'MONTH') as descripcion,
            '' AS adicional1, '' AS adicional2, '' AS adicional3 
            from dual
            connect by level <= 12)
            WHERE descripcion LIKE '%' || in_criteriodebusqueda || '%';
      END;
   END IF;
END BL_CATALOGO_GROUP_EXP_MONTH;

