create or replace FUNCTION "FN_KCC_CALCULA_FVENCIMIENTO" (
p_mes_vencimiento       number,
p_fecha_firmaperfil     varchar2,
p_aml_rating            varchar2) 
RETURN DATE is p_fecha_vencimiento date;
--HLEE 30-08-2023: Ticket 38930 Función para calcular la fecha de vencimiento a partir de la fecha firma perfil y mes de vencimiento.
v_anios_renovacion number;
v_dia varchar2(10);
v_mes varchar2(10);
v_mes_firmaperfil varchar2(10);
v_fecha_firmaperfil date;
v_anio number;
v_fecha date;
v_dias_diferencia number;
v_fecha_final date;
REG VARCHAR(500);
-- HLEE - 20230830 - asociado a la mejora de cambio de fecha de vencimiento
begin
  --Obtener la cantidad de anios a renovar por el AML Rating
  BEGIN
  select TIEMPO_RENOVACION INTO v_anios_renovacion 
    FROM WF_LMC_RENOVACION_X_AML_RATING WHERE RATING = p_aml_rating;
  EXCEPTION WHEN NO_DATA_FOUND THEN
   v_anios_renovacion :=0;
   DBMS_OUTPUT.PUT_LINE('No encontro registro con el AML Rating'); 
  END;
  if p_mes_vencimiento is null then
      p_fecha_vencimiento := ADD_MONTHS(TO_DATE(p_fecha_firmaperfil, 'dd/mm/yyyy')+1, (v_anios_renovacion*12));
  else
      p_fecha_vencimiento := NULL;
      v_fecha_firmaperfil :=TO_DATE(p_fecha_firmaperfil, 'dd/mm/yyyy');
    
      --Obtener el mes de firma perfil
      v_mes_firmaperfil := EXTRACT(MONTH FROM v_fecha_firmaperfil);
      v_mes_firmaperfil := case when v_mes_firmaperfil < 10 then '0' || v_mes_firmaperfil else v_mes_firmaperfil end;
    
      --Obtener el anio desde fecha de firma perfil para armar la fecha vencimiento
      v_anio := EXTRACT(YEAR FROM v_fecha_firmaperfil);
      v_mes := case when p_mes_vencimiento < 10 then '0' || p_mes_vencimiento else to_char(p_mes_vencimiento) end;
      v_fecha := TO_date(to_char(v_anio) || v_mes || '01', 'YYYYMMDD'); 
    
      --Obtener el ultimo dia de la fecha vencimiento y asignarla
      v_dia := EXTRACT(DAY FROM LAST_DAY(v_fecha));
      v_fecha := TO_date(to_char(v_anio) || v_mes || v_dia, 'YYYYMMDD');
    
      -- Si son del mismo mes
      if v_mes_firmaperfil = v_mes then
        -- Apliar el anio segun AML Rating
        v_anio:= v_anio + v_anios_renovacion;
      else
        -- Tomar el anio por AML y retornar la fecha
        v_dias_diferencia := v_fecha - v_fecha_firmaperfil;
        if v_dias_diferencia > 90 then
        -- Aplicar el anio segun AML Rating y restarle un anio
        v_anio:= v_anio + v_anios_renovacion - 1;
        else
        -- Aplicar el anio segun AML Rating
        v_anio:= v_anio + v_anios_renovacion;
        end if;
      end if;
    
      v_fecha := TO_date(to_char(v_anio) || v_mes || '01', 'YYYYMMDD');
      --Obtener el ultimo dia de la nueva fecha vencimiento luego de darle el anio
      v_dia := EXTRACT(DAY FROM LAST_DAY(v_fecha));
    
      v_fecha_final := TO_date(to_char(v_anio) || v_mes || v_dia, 'YYYYMMDD');
      p_fecha_vencimiento := v_fecha_final;
    
      select (v_anios_renovacion || '|' || v_dia  || '|'  || v_mes  || '|'  ||v_mes_firmaperfil  || '|'  ||v_anio || '|'  ||v_fecha || '|'  || v_dias_diferencia  || '|'  || v_fecha_final)
      into reg FROM DUAL;
    
      --DBMS_OUTPUT.PUT_LINE(reg);
  end if;

  RETURN p_fecha_vencimiento;

end FN_KCC_CALCULA_FVENCIMIENTO;