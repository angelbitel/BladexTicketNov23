--------------------------------------------------------
--  File created - Wednesday-August-09-2023   
--------------------------------------------------------
--------------------------------------------------------
--  DDL for Procedure BL_LMC_UPD_PD_LGD_CLIENTE
--------------------------------------------------------
set define off;

  CREATE OR REPLACE PROCEDURE BL_LMC_UPD_PD_LGD_CLIENTE 
(
  IN_MODO IN NUMBER DEFAULT NULL,     -- 1 - Actualiza PF; 2 - Actualiza PD; 3 - Actualiza LGD
  IN_ID_SOLICITUD  IN VARCHAR2 DEFAULT NULL,
  IN_CUSTOMER_ID IN VARCHAR2 DEFAULT NULL,
  IN_PF  IN VARCHAR2 DEFAULT NULL, 
  IN_PD IN NUMBER DEFAULT NULL,
  IN_LGD IN NUMBER DEFAULT NULL,
  OUT_RESULTADO OUT SYS_REFCURSOR
)
AS 
v_filas_actualizadas number;
BEGIN
    IF IN_MODO = 1 THEN
        UPDATE WF_KCC_CUSTOMER_INFO 
        SET PROJECT_FINANCE = IN_PF
        WHERE  ID_SOLICITUD = IN_ID_SOLICITUD
        AND CUSTOMER_NO = IN_CUSTOMER_ID;        
    END IF;


    IF IN_MODO = 2 THEN
        UPDATE WF_KCC_CUSTOMER_INFO 
        SET probability_default = IN_PD
        WHERE  ID_SOLICITUD = IN_ID_SOLICITUD
        AND CUSTOMER_NO = IN_CUSTOMER_ID;        
    END IF;


    IF IN_MODO = 3 THEN
        UPDATE WF_KCC_CUSTOMER_INFO 
        SET loss_given_default = IN_LGD
        WHERE  ID_SOLICITUD = IN_ID_SOLICITUD
        AND CUSTOMER_NO = IN_CUSTOMER_ID;        
    END IF;

     v_filas_actualizadas := SQL%ROWCOUNT; 

    OPEN out_resultado FOR
    SELECT v_filas_actualizadas as filas FROM dual;  

END BL_LMC_UPD_PD_LGD_CLIENTE;

/
