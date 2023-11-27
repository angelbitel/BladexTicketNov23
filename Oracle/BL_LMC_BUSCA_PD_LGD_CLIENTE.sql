--------------------------------------------------------
--  File created - Wednesday-August-09-2023   
--------------------------------------------------------
--------------------------------------------------------
--  DDL for Procedure BL_LMC_BUSCA_PD_LGD_CLIENTE
--------------------------------------------------------
set define off;

  CREATE OR REPLACE PROCEDURE BL_LMC_BUSCA_PD_LGD_CLIENTE 
(
  IN_ID_SOLICITUD  IN VARCHAR2 DEFAULT NULL, 
  OUT_RESULTADO OUT SYS_REFCURSOR
)
AS 
BEGIN 

  OPEN out_resultado FOR
    SELECT  C.ID_SOLICITUD,  C.CUSTOMER_NO,  C.CUSTOMER_NO_FCC,  C.CUSTOMER_NAME1       
      , c.PROJECT_FINANCE
      ,COALESCE(c.PROBABILITY_DEFAULT,0) AS PROBABILITY_DEFAULT
      ,COALESCE(c.LOSS_GIVEN_DEFAULT,0) AS LOSS_GIVEN_DEFAULT
    FROM WF_KCC_CUSTOMER_INFO C
    WHERE ID_SOLICITUD = IN_ID_SOLICITUD
	AND C.LMT_CUSTOMER_TYPE <> 'G';

END BL_LMC_BUSCA_PD_LGD_CLIENTE;

/
