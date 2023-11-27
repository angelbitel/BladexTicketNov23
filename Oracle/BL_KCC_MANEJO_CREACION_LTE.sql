create or replace PROCEDURE "BL_KCC_MANEJO_CREACION_CLTE" 
(   IN_ID_SOLICITUD       IN VARCHAR2 DEFAULT NULL
  , IN_ACCION             IN VARCHAR2 DEFAULT NULL
  , IN_STATUS_FCC         IN VARCHAR2 DEFAULT NULL
  , IN_MSG_STATUS_FCC     IN VARCHAR2 DEFAULT NULL 
  , IN_ID_CUSTOMER_FCC    IN VARCHAR2 DEFAULT NULL 
  , out_resultado         OUT SYS_REFCURSOR
) AS

--// AHernandez - 00006793 - agregando control de ultima fecha KYC
--// AHernandez - 00010144 - Agregando el is PEP
--// AHernandez - 00013297 -  20190314 - Se agregan nuevos campos para las validaciones de AML Rating
TMP_GOVTYPE VARCHAR2(50) DEFAULT NULL;
--TMP_AML_RATING VARCHAR2(50) DEFAULT NULL;
TMP_RESIDENCELOCATION VARCHAR2(50) DEFAULT NULL;
TMP_CUSTOMER_NO_FCC VARCHAR2(50) DEFAULT NULL;
--TMP_CUSTOMER_USED_NY VARCHAR2(1) DEFAULT NULL;

V_NOMBREPROCESO VARCHAR2(50):='CONTADOR CREACION  KYC';
V_TIPOSECUENCIAL VARCHAR2(10):= 'CUS';
V_OUT_SEC VARCHAR2(20):=''; 
V_OUT_ALLCUST VARCHAR2(2000):='';
V_OUT_ALLGROUP VARCHAR2(2000):='';
V_OUT_CANTIDAD NUMBER:=0;

V_CUSTOMER_NO_KCC VARCHAR2(10);
V_CHK_COUNTERPART NUMBER:=0;
V_STR_COUNTERPART VARCHAR(2);

V_INDUSTRY VARCHAR(20);
V_CUSTOMER_TYPE VARCHAR(20);
V_CUSTOMER_CATEGORY VARCHAR(20);
V_CUSTOMER_TYPE_CODE VARCHAR(20);
V_PURPOSE_ID NUMBER:=0;  --Ticket 28073 bmg 2023.05.18

CURSOR AllGroupsCreated_Cursor IS 
      SELECT customer_name1 ||' / '||customer_no_fcc grupos
      FROM wf_kcc_customer_info
      WHERE ID_SOLICITUD = IN_ID_SOLICITUD
      AND NVL(ID_STATUS_FCC, 0) in (1,3)--Si se creo success
      AND LIMIT_EXP_DATE = '01-JAN-80'
      AND customer_no_fcc <> liab_id; --Se agregó este filtro para solo traer los grupos y no los garantes en esta consulta.

CURSOR AllCustCreated_Cursor IS
      SELECT customer_name1 ||' / '||customer_no_fcc clientes
      FROM wf_kcc_customer_info
      WHERE ID_SOLICITUD = IN_ID_SOLICITUD
      AND NVL(ID_STATUS_FCC, 0) IN (1,3)--Si se creo success
      AND (LIMIT_EXP_DATE <> '01-JAN-80' or LIMIT_EXP_DATE is null)
      UNION --El union se agregó para retornar los garantes con los clientes. 
      --Se dió esta situación debido a que en la notificación se tenían que enviar 
      --todos los clientes y garantes en el correo.
      SELECT customer_name1 ||' / '||customer_no_fcc grupos
      FROM wf_kcc_customer_info
      WHERE ID_SOLICITUD = IN_ID_SOLICITUD
      AND NVL(ID_STATUS_FCC, 0) in (1,3)--Si se creo success
      AND LIMIT_EXP_DATE = '01-JAN-80';
      --Aserrano 09 Septiembre 2010
      --Se comenta la linea AND customer_no_fcc <> liab_id; del cursor debido a que
      --es innecesaria
      --AND customer_no_fcc <> liab_id;
BEGIN

IF IN_ACCION = '1' THEN--Actualizamos cada registro de cliente con el msg de FCC

      UPDATE wf_kcc_customer_info
      SET ID_STATUS_FCC      = IN_STATUS_FCC, 
      MSG_ERROR_FCC          = IN_MSG_STATUS_FCC,
      -- Aserrano 3 En 2011. Se coloca la fecha en la que se creo el cliente.
      FECHA_CREACION_CLIENTE = SYSDATE,
      INCEPTION_DATE = SYSDATE
      WHERE ID_CUSTOMER_FCC = IN_ID_CUSTOMER_FCC;
      
          -- AEH - 2010 02 23 - Verificación de cliente para saber si realmente está creado en FCC
          -- En caso de que no exista entonces se le cambia el estado a 0 para que se cree nuevamente.
         
          --Aserrano 30Nov2015: Usando los ws de creacion de clientes de oracle ya no es necesario este segmento porque
          --para cuando llegue a este punto el cliente ya fue creado en FCC y su codigo actualizado en la tabla wf_kcc_customer_inifo
      /*    IF IN_STATUS_FCC = 1 THEN 

            SELECT COUNT(CUSTOMER_NO) INTO V_OUT_CANTIDAD 
            FROM STTM_CUSTOMER@LINK_BPMBLFCC
            WHERE CUSTOMER_NO  = 
            (SELECT CUSTOMER_NO_FCC FROM WF_KCC_CUSTOMER_INFO
                WHERE ID_CUSTOMER_FCC = IN_ID_CUSTOMER_FCC AND CUSTOMER_NO_FCC IS NOT NULL  AND ROWNUM <=1);
      
            IF V_OUT_CANTIDAD = 0  THEN 
                UPDATE WF_KCC_CUSTOMER_INFO
                SET ID_STATUS_FCC      = 0,
                MSG_ERROR_FCC          = 'BLX:Created but RollBack - ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
                CUSTOMER_NO_FCC        = NULL,
                FECHA_CREACION_CLIENTE = NULL,
                INCEPTION_DATE = NULL
                WHERE ID_CUSTOMER_FCC  = IN_ID_CUSTOMER_FCC;
            END IF ;
            
          END  IF; 
          
          IF IN_STATUS_FCC = 0  THEN 
                UPDATE WF_KCC_CUSTOMER_INFO
                SET ID_STATUS_FCC      = 0,
                CUSTOMER_NO_FCC        = NULL,
                FECHA_CREACION_CLIENTE = NULL,
                INCEPTION_DATE = NULL
                WHERE ID_CUSTOMER_FCC  = IN_ID_CUSTOMER_FCC;
          END IF;
      */
          OPEN out_RESULTADO FOR
            SELECT CUSTOMER_NO "IDCustUltimusTable" FROM wf_kcc_customer_info
            WHERE ID_CUSTOMER_FCC = IN_ID_CUSTOMER_FCC;
      COMMIT;
END IF;

IF IN_ACCION = '2' THEN--Validamos si algun cliente genero error al crearse.
      OPEN OUT_RESULTADO FOR
      SELECT 
      --Si hay registros con errores retornamos cero(0)
      CASE WHEN COUNT(*) > 0 THEN '0' ELSE '1'END RESULTADO  
      FROM WF_KCC_CUSTOMER_INFO
      WHERE ID_SOLICITUD = IN_ID_SOLICITUD
      AND ID_STATUS_FCC = 0 --Si generó error entonces este campo tendra un cero(0)
      --AH - 2010 02 11 - Modificacion realizada para que solo valide aquellos que fueron marcados para crearse en FCC
      AND CHK_CREATE_FCC = 1 --check en el formulario que indica si el usuario desea crearlo en FCC.
      ;      
END IF;

IF IN_ACCION = '3' THEN--Consultamos toda la info del cliente para poder crearlo.
  BEGIN 
      --Obtenemos el GOVERMENT_TYPE 
       BEGIN  
            --SELECT GOVERMENT_TYPE, AML_RATING, CUSTOMER_USED_NY INTO TMP_GOVTYPE , TMP_AML_RATING, TMP_CUSTOMER_USED_NY
            SELECT GOVERMENT_TYPE INTO TMP_GOVTYPE
            FROM WF_KCC_SOLICITUD
            WHERE ID_SOLICITUD = IN_ID_SOLICITUD;
             EXCEPTION when NO_DATA_FOUND then       
              TMP_GOVTYPE:='';              
      END;

       BEGIN  
          -- Busca el customer no del cliente principal para colocarlo en el UDF correspondiente
           SELECT CUSTOMER_NO_FCC INTO TMP_CUSTOMER_NO_FCC 
           FROM WF_KCC_CUSTOMER_INFO 
           WHERE  
           MAIN_CUSTOMER = 1
           AND ID_SOLICITUD = IN_ID_SOLICITUD
           AND RELACIONADO IS NULL
           AND ROWNUM <=1;
          EXCEPTION WHEN NO_DATA_FOUND THEN
          TMP_CUSTOMER_NO_FCC:=NULL;              
      END;      
      
      BEGIN
      
      V_CHK_COUNTERPART:=0;
      
      SELECT NVL(CHK_COUNTERPART, 0) INTO V_CHK_COUNTERPART FROM WF_LMT_CUSTOMER_INFO
      WHERE ID_SOLICITUD = IN_ID_SOLICITUD
      AND ROWNUM = 1;
      
      IF V_CHK_COUNTERPART = 1 THEN 
        V_STR_COUNTERPART := 'SI';
      ELSE 
        V_STR_COUNTERPART := 'NO';        
      END IF ;
      
      END ;
      
      --MS_BLX.Nov09: 
      --(1) Le colocamos ID_CUSTOMER_FCC a todos los clientes que no lo tengan. Esto ocurre solo la primera vez.
      UPDATE WF_KCC_CUSTOMER_INFO
      SET ID_CUSTOMER_FCC = FN_OBTENER_SECUENCIAL(V_NOMBREPROCESO,V_TIPOSECUENCIAL)--FCC solo soporta 16 caracteres
      WHERE ID_SOLICITUD = IN_ID_SOLICITUD--'UKC2009091121'
      AND ID_CUSTOMER_FCC IS NULL;
      
      --(2) Actualizamos ID_CUSTOMER_FCC a todos los clientes que han fallado en la creacion.
      UPDATE WF_KCC_CUSTOMER_INFO
      SET ID_CUSTOMER_FCC = FN_OBTENER_SECUENCIAL(V_NOMBREPROCESO,V_TIPOSECUENCIAL)--FCC solo soporta 16 caracteres
      WHERE ID_SOLICITUD = IN_ID_SOLICITUD--'UKC2009091121'
      AND ID_EXISTE_FCC = '0'-- 0=No existe en FCC.
      AND NVL(ID_STATUS_FCC, 0) = 0 --Indica si el cliente se intento crear en FCC y falló.
      AND CHK_CREATE_FCC = 1;--check en el formulario que indica si el usuario desea crearlo en FCC.
      COMMIT; 
      
      --Ticket 28073 bmg 2023.05.18
        SELECT NVL(PURPOSE_ID, 0) INTO V_PURPOSE_ID 
        FROM WF_LMT_CUSTOMER_INFO
        WHERE ID_SOLICITUD = IN_ID_SOLICITUD;
      
      OPEN out_resultado FOR
    SELECT 
        ID_SOLICITUD, 
        CUSTOMER_NO_FCC, 
        CTYPE.CUSTOMER_TYPE CUSTOMER_TYPE,
        CUSTOMER_NAME1, 
        FULLNAME ,
        SHORT_NAME,
        CUSTOMER_CATEGORY,
        POSTALALINE1,
        POSTALALINE2,
        POSTALALINE3,
        POSTALACITY,
        RESIDENCECOUNTRY,
        NATIONALITYID,
        LANGUAGEID,
        DEFAULT_MEDIA,
        NULL IDENT_NAME,--Hace referencia al ABA Code que ya no se envia a Flexcube
        NULL ABACODEVALUE ,
        EXPOSURE_COUNTRYID,
        RESIDENCELOCATIONID,
        RISK_RATING CRRATE,
        TO_CHAR(SYSDATE,'yyyymmdd')REVDT,
        NULL OVRLIM,
        LIAB_ID,
        RISK_RATING,
        -- Leyendo el 
        --2019.05.24 bmg Ticket 14383 -- si es null buscar en la tabla WF_LMT_EC_RC_LIMITS
        NVL((SELECT GROUP_CODE FROM WF_KCC_CUSTOMER_INFO CIAUX WHERE CIAUX.ID_SOLICITUD = IN_ID_SOLICITUD
                AND CIAUX.LIMIT_EXP_DATE = '01-JAN-80'
                AND CIAUX.LMT_CUSTOMER_TYPE = 'G'
                AND ROWNUM <= 1
            ),
            (select GROUP_CODE from WF_LMT_EC_RC_LIMITS where id_solicitud = IN_ID_SOLICITUD AND ROWNUM <= 1 )
           )
        GROUP_CODE,        
        WEBSITE,
        TELEPHONENUMBER,
        PHYSICALALINE1,
        PHYSICALALINE2,
        PHYSICALALINE3,
        CASE  WHEN INCORP_DATE IS NOT NULL 
          THEN TO_CHAR(INCORP_DATE,'yyyymmdd')
        END  INCORP_DATE,
        INCORP_COUNTRYID,
        NVL(NETWORTH, 0) NETWORTH,
        INDUSTRY INDUSTRY_CODE,  -- AH - 20100510 - Agregado para enviarlo a FCC
        FN_GET_CONTACT_SHOLDER_UDF(IN_ID_SOLICITUD,CUST.CUSTOMER_NO,'','D') DIREC_COMMITE,
        TAXIDNUMBER,
        --SWIFT_CODE,
        --Aserrano 15Jun2016 Ticket 3116: Se busca el SWIFT CODE solo para clientes tipo banco sino se envia nulo.
        CASE WHEN CUST.CUSTOMER_TYPE IN(2,5,7) THEN SWIFT_CODE ELSE NULL END SWIFT_CODE,
        ID_CUSTOMER_FCC,
            --Nos valores para los UDFs
            INTERNAL_CLASSIFICATION "INTERNAL_CLASSIFICAT",
            -- AH - 2010 02 25 - Modificación realizada para unificar los rating
            -- Se cambia el orden en que van a aparecer
            NVL(FN_SPLIT_STRING(FN_SPLIT_STRING(NAMEINTERNATIONALRISK,2),2,':'), 'NC') "S_AND_P_EXTERNAL_R_RAT", -- AH 2010 02 24 - Colocado temporalmente el upper para que no falle en flexcube 
            NVL(FN_SPLIT_STRING(FN_SPLIT_STRING(NAMEINTERNATIONALRISK,3),2,':'), 'NC') "FITCH_EXTERNAL_R_RAT",
            NVL(FN_SPLIT_STRING(FN_SPLIT_STRING(NAMEINTERNATIONALRISK,1),2,':'), 'NC') "MOODYS_EXTNL_R_RAT",
            ECONOMICGROUPRUC            "ECONOMIC_GROUP_RUC",
            -- Esta parte se agregó ya que lo que debe viajar a FCC es el código en vez de la descripcion
            NVL( CASE WHEN BANKTYPE = 'NA' THEN 
              BANKTYPE
            ELSE
              (SELECT LOV FROM UDTM_LOV@LINK_BPMBLFCC UDFD WHERE UDFD.LOV_DESC = BANKTYPE 
                AND  UDFD.FIELD_NAME = 'BANK TYPE' AND ROWNUM <=1) 
            END, 'NA') "BANK_TYPE",
            --RELATIONTYPE                                                  "RELATION_TYPE",
            CASE --Ticket 28073 bmg 2023.05.18
            WHEN V_PURPOSE_ID = 7  THEN 'NA' 
            ELSE RELATIONTYPE END "RELATION_TYPE",
            
            NVL(TYPEOFLICENCE, 'NA')                                      "TYPE_OF_LICENSE",
            SUBSTR(RTRIM(NVL(NAME_ADDRESS_LEGAL_ADVISOR, 'NA')), 1, 105)  "RESIDENT_AGENT",
            NVL(COMPLIANCEOFFICER, 'NA')                                  "COMPLIANCE_OFFICER",
            TMP_GOVTYPE                                                   "GOVERMENT_TYPE",
            SUBSTR(RTRIM(NVL(LEGALREPRESENTATIVE, 'NA')), 1, 105)         "LEGAL_REPRESENTATIVE",
            SUBSTR(RTRIM(NVL(NAMEEXTERNALAUDITORS, 'NA')), 1, 105)       "EXTERNAL_AUDITORS",
            SUB_ECOGR_CD                                                  "SUB_ECOGR_CD",
            SUBSTR(RTRIM(NVL(ADDRESSPROCESSAGENTINUSA, 'NA')),1,105)      "USA_PROCESS_AGENT",
            TO_CHAR(LIMIT_EXP_DATE, 'YYYYMMDD')                           LIMIT_EXP_DATE,
            DV                                                            "DIGITO_VERIFICADOR",
            TELEPHONENUMBER2                                              "TEL_2_PANAMA",
            CASE WHEN NY_AGENCY = 1 THEN AML_RATINGID_NY ELSE AML_RATINGID END AS "AML_RISK_RATING",--TMP_AML_RATING              "AML RISK RATING",

            FN_GET_CONTACT_SHOLDER_UDF(IN_ID_SOLICITUD,CUST.CUSTOMER_NO,1,'C') "CONTACT_1",
            FN_GET_CONTACT_SHOLDER_UDF(IN_ID_SOLICITUD,CUST.CUSTOMER_NO,2,'C') "CONTACT_2",
            FN_GET_CONTACT_SHOLDER_UDF(IN_ID_SOLICITUD,CUST.CUSTOMER_NO,3,'C') "CONTACT_3",
            FN_GET_CONTACT_SHOLDER_UDF(IN_ID_SOLICITUD,CUST.CUSTOMER_NO,1,'S') "SHAREHOLD_MORE_20_PCT_1",
            FN_GET_CONTACT_SHOLDER_UDF(IN_ID_SOLICITUD,CUST.CUSTOMER_NO,2,'S') "SHAREHOLD_MORE_20_PCT_2",
            FN_GET_CONTACT_SHOLDER_UDF(IN_ID_SOLICITUD,CUST.CUSTOMER_NO,3,'S') "SHAREHOLD_MORE_20_PCT_3",

        -- Si el cliente tiene por fecha 19800101 entonces no llega valor el cliente principal
        CASE WHEN TO_CHAR(LIMIT_EXP_DATE, 'YYYYMMDD') = '19800101' THEN NULL ELSE TMP_CUSTOMER_NO_FCC END "CLIENTE_PRINCIPAL",
        CUSTOMER_NO "SEC_UNICO_CUST_GRID",
        DECODE(CUST.NY_AGENCY, 1, 'YES', '0', 'NO', NULL) "CUST_CAN_BE_USE_NY_AGENCY", --DECODE(TMP_CUSTOMER_USED_NY, '1', 'Yes', '0', 'No', NULL) "CUST CAN BE USED BY NY AGENCY" -- AH - 20100507 - Creación del nuevo UDF
        ACCOUNT_OFFICERID "ACCOUNT_OFFICER",
        LOCATIONID "LOCATION",
        DECODE(SALES_MORE_30_PERCENT, 1, 'SI', '0', 'NO', 'NO') "CLIENTE_EXP_30PCT_VTAS_O_MAS", 
        EXPORT_SHARE "PORCENTAJE_DE_EXPORTACIONES",
        --MS.10jun15. Mojo:10165985. Se cambia el envio al nuevo UDF de vendor debido a error reportado en el mojo. 
        --CASE WHEN TMP_CUSTOMER_NO_FCC =  CUSTOMER_NO_FCC THEN V_STR_COUNTERPART ELSE 'NO' END  "CONTRAP VF APROB 1" -- Solo se agrega esta opción al principal
        --CASE WHEN TMP_CUSTOMER_NO_FCC =  CUSTOMER_NO_FCC THEN V_STR_COUNTERPART ELSE 'NO' END  "CONTR_APROB_VF_1", --2019.09.20 bmg ticket 16689 y 17569 -- nose usaraa -- se reemplaza por el udf 36 CONTR_APROB_VF_1
        /*Mojo:10165985*/
        CUST.FAXNUMBER,
        CUST.MAIN_CUSTOMER,
        CUST.EMAIL,
        CUST.LMT_CUSTOMER_TYPE,
        --Este cammpo es reemplazado por el usuario que crea el registro en FCC y se asigna en el VB del proyecto
        NULL USUARIO_ULT_CIF,
        TO_CHAR(CUST.FECHA_KYC, 'YYYYMMDD') as LAST_KYC_DATE, --// AHernandez - 00006793
        TO_CHAR(sysdate, 'YYYYMMDD') as  INCEPTION_DATE,   --// AHernandez - 00006793  
        CASE NVL(CUSTOMER_CLASSIFICATION_PEP,'0')  
        WHEN '0' THEN 'N'
        WHEN '1' THEN 'Y'
        ELSE 'N'
        END IS_PEP       --// AHernandez - 00010144  
        --// AHernandez - 00013297
       ,CUST.TIPO_DE_CLIENTE as "TIPO DE CLIENTE"
       ,CUST.INTERNAL_CONTROL     
       --// AHernandez - 00013297
       
       --2019.09.20 bmg ticket 16689 y 17569
       ,CUST.CO_COVENANTS as "COVENANTS CIF"         
       ,CUST.CO_DEUDOR_PRINCIPAL as RELATED_CUSTOMER          
        ,CASE CUST.CHK_CONTR_APROB_VF 
                        WHEN 1 THEN 'SI'                       
                        ELSE 'NO'
         END as CONTR_APROB_VF_1
       -- fin ticket 16689 y 17569
       ,cust.cinu as COD_ACTIVIDAD_CINU  --2019.12.04 bmg ticket 00016775-CINU
        --10Mar2021 oherrera Ticket#21170
        ,CUST.CO_ESG_RATING AS RATING_ESG
        ,TO_CHAR(DATE_ESG_RATING, 'YYYY-MM-DD') AS DATE_ESG
        -- fin Ticket#21170
        --OH 26Sep2022 Ticket 33103 -- Se agregan nuevos campos 
        , CUST.CO_CLIENT_BETTER_COUNTRY AS CTE_MEJOR_PAIS
        --, CUST.CO_RELATION_TYPE AS RELATION_TYPE
        , CUST.CO_RISK_CUST_TYPE AS TIPO_CLIENTE_RIESGO
        -- Fin Ticket 33103
        ,cust.CO_OFICINA_GESTION as OFICINA_DE_GESTION  -- ticket 32393 bmg 2023.04.05
        ,PROBABILITY_DEFAULT as PF_PD  -- hlee 31-07-23 Ticket 38841
        ,LOSS_GIVEN_DEFAULT as PF_LGD -- hlee 31-07-23 Ticket 38841 
		,CASE NVL(PROJECT_FINANCE,'0')  
        WHEN '0' THEN 'N'
        WHEN '1' THEN 'Y'
        ELSE 'N'
        END as PF_INDICATOR --hlee 31-07-23 Ticket 38841
        ,CASE WHEN GROUP_EXPIRATION_MONTH < 10 THEN '0'||TO_CHAR(GROUP_EXPIRATION_MONTH) else TO_CHAR(GROUP_EXPIRATION_MONTH) end KYC_REVISION_MONTH -- hlee 30-08-23 Ticket 38930
        FROM WF_KCC_CUSTOMER_INFO CUST,WF_KCC_CUSTOMER_TYPE CTYPE
        WHERE ID_SOLICITUD = IN_ID_SOLICITUD
        AND CUST.CUSTOMER_TYPE = CTYPE.CUSTOMER_ID
        AND (ID_EXISTE_FCC = '0' OR ID_EXISTE_FCC IS NULL)--1=Existe en FCC. 0=No existe en FCC.
        AND (NVL(ID_STATUS_FCC, 0) = 0 OR ID_STATUS_FCC IS NULL) --Indica si el cliente se creo en FCC y falló.
        AND CHK_CREATE_FCC = 1 --check en el formulario que indica si el usuario desea crearlo en FCC.
        AND CUST.LMT_CUSTOMER_TYPE <> 'G'
        ORDER BY CUST.MAIN_CUSTOMER DESC;
        
    EXCEPTION WHEN NO_DATA_FOUND THEN       
      OPEN OUT_RESULTADO FOR
      SELECT 'No Hay Registros' RESULTADO, '0' VALOR FROM DUAL;
  END;
END IF;  

--Consultamos toda la info del grupo para poder crearlo.
 IF IN_ACCION = '4' THEN
  BEGIN
    
--AH - 20180523 - Buscando los valos del cliente pral   

    SELECT  KCC.CUSTOMER_TYPE, CTYPE.CUSTOMER_TYPE, CUSTOMER_CATEGORY, INDUSTRY  
    INTO V_CUSTOMER_TYPE_CODE,  V_CUSTOMER_TYPE, V_CUSTOMER_CATEGORY, V_INDUSTRY
    FROM WF_KCC_CUSTOMER_INFO KCC JOIN  WF_KCC_CUSTOMER_TYPE CTYPE ON KCC.CUSTOMER_TYPE = CTYPE.CUSTOMER_ID
    WHERE ID_SOLICITUD = IN_ID_SOLICITUD AND MAIN_CUSTOMER = 1
    AND ROWNUM =1
    ;
    
    UPDATE WF_KCC_CUSTOMER_INFO
    SET CUSTOMER_TYPE = V_CUSTOMER_TYPE_CODE, 
    CUSTOMER_CATEGORY = V_CUSTOMER_CATEGORY,
    INDUSTRY = V_INDUSTRY,
    FECHA_KYC = to_date('19900101', 'YYYYMMDD')
    WHERE ID_SOLICITUD =IN_ID_SOLICITUD AND LMT_CUSTOMER_TYPE = 'G' ;
--AH - 20180523 -  Fin

    
    --Generamos el codigo unico del cliente para poder crearlo en FCC.
      --MS_BLX.Nov09: 
      --(1) Le colocamos ID_CUSTOMER_FCC a todos los clientes que no lo tengan. Esto ocurre solo la primera vez.
        UPDATE WF_KCC_CUSTOMER_INFO 
        SET ID_CUSTOMER_FCC = FN_OBTENER_SECUENCIAL(V_NOMBREPROCESO,V_TIPOSECUENCIAL)--FCC solo soporta 16 caracteres 
        WHERE ID_SOLICITUD = IN_ID_SOLICITUD--'UKC2009091121' 
        AND ID_CUSTOMER_FCC IS NULL; 
      
  --(2) Actualizamos ID_CUSTOMER_FCC a todos los clientes que han fallado en la creacion.
      UPDATE WF_KCC_CUSTOMER_INFO 
      SET ID_CUSTOMER_FCC = FN_OBTENER_SECUENCIAL(V_NOMBREPROCESO,V_TIPOSECUENCIAL)--FCC solo soporta 16 caracteres 
      WHERE ID_SOLICITUD = IN_ID_SOLICITUD--'UKC2009091121' 
      AND ID_EXISTE_FCC = '0'-- 0=No existe en FCC. 
      AND NVL(ID_STATUS_FCC, 0) = 0 --Indica si el cliente se intento crear en FCC y falló. 
      AND CHK_CREATE_FCC = 1;--check en el formulario que indica si el usuario desea crearlo en FCC. 
      COMMIT;  
      
      BEGIN
      SELECT RESIDENCELOCATIONID  INTO TMP_RESIDENCELOCATION 
       FROM WF_KCC_CUSTOMER_INFO
       WHERE ID_SOLICITUD = IN_ID_SOLICITUD
              AND MAIN_CUSTOMER = 1;
      EXCEPTION WHEN NO_DATA_FOUND THEN
       TMP_RESIDENCELOCATION := NULL;
      END ;
    
      OPEN out_resultado FOR
    SELECT 
        ID_SOLICITUD, 
        CUSTOMER_NO_FCC, 
        CTYPE.CUSTOMER_TYPE CUSTOMER_TYPE,
        CUSTOMER_NAME1,
        FULLNAME ,
        SHORT_NAME,
        CUSTOMER_CATEGORY,
        POSTALALINE1,
        POSTALALINE2,
        POSTALALINE3,
        POSTALACITY,
        RESIDENCECOUNTRY,
        NATIONALITYID,
        LANGUAGEID,
        'MAIL' AS DEFAULT_MEDIA,
        NULL IDENT_NAME, --Hace referencia al ABA Code que ya no se envia a Flexcube
        NULL ABACODEVALUE ,
        EXPOSURE_COUNTRYID,
        TMP_RESIDENCELOCATION RESIDENCELOCATIONID,
        NULL CRRATE,
        TO_CHAR(SYSDATE,'yyyymmdd')REVDT,
        NULL OVRLIM,
        LIAB_ID,
        RISK_RATING,
        NULL GROUP_CODE,
        'NA' WEBSITE,
        'NA' TELEPHONENUMBER,
        PHYSICALALINE1,
        PHYSICALALINE2,
        PHYSICALALINE3,
        CASE  WHEN INCORP_DATE IS NOT NULL
          THEN TO_CHAR(INCORP_DATE,'yyyymmdd')
        END  INCORP_DATE,
        INCORP_COUNTRYID,
        NVL(NETWORTH, 0) NETWORTH,
        INDUSTRY INDUSTRY_CODE,  -- AH - 20100510 - Agregado para enviarlo a FCC
        TAXIDNUMBER,
        --SWIFT_CODE,
        --Aserrano 15Jun2016 Ticket 3116: Se busca el SWIFT CODE solo para clientes tipo banco sino se envia nulo.
        CASE WHEN CUST.CUSTOMER_TYPE IN(2,5,7) THEN SWIFT_CODE ELSE NULL END SWIFT_CODE,
        ID_CUSTOMER_FCC,
        -- Valores para los UDFs
                'NA' "INTERNAL_CLASSIFICAT",
                'NC' "S_AND_P_EXTERNAL_R_RAT",  
                'NC' "FITCH_EXTERNAL_R_RAT",
                'NC' "MOODYS_EXTNL_R_RAT",
                'NA' "ECONOMIC_GROUP_RUC",
                'NA' "BANK_TYPE",
                'NA' "RELATION_TYPE",
                'NA' "TYPE_OF_LICENSE",
                'NA' "RESIDENT_AGENT",
                'NA' "COMPLIANCE_OFFICER",
                'NA' "GOVERMENT_TYPE",
                'NA' "LEGAL_REPRESENTATIVE",
                'NA' "EXTERNAL_AUDITORS",
                SUB_ECOGR_CD  "SUB_ECOGR_CD",
                'NA' "USA_PROCESS_AGENT",
                TO_CHAR(LIMIT_EXP_DATE, 'YYYYMMDD') LIMIT_EXP_DATE,
                '' "DIGITO_VERIFICADOR",
                '' "TEL_2_PANAMA",
                'NA' "AML_RISK_RATING",
                '' "CONTACT_1",
                '' "CONTACT_2",
                '' "CONTACT_3",
                '' "SHAREHOLD_MORE_20_PCT_1",
                '' "SHAREHOLD MORE_20_PCT_2",
                '' "SHAREHOLD MORE_20_PCT_3",
        -- Valores para los UDF
                CUSTOMER_NO "SEC_UNICO_CUST_GRID",
        (SELECT ACCOUNT_OFFICERID FROM WF_KCC_CUSTOMER_INFO WHERE ID_SOLICITUD = IN_ID_SOLICITUD AND MAIN_CUSTOMER = 1)"ACCOUNT_OFFICER",
        (SELECT LOCATIONID FROM WF_KCC_CUSTOMER_INFO WHERE ID_SOLICITUD = IN_ID_SOLICITUD AND MAIN_CUSTOMER = 1) "LOCATION",
        --LOCATIONID "LOCATION",
        
                --'' ACCOUNT_OFFICER,
                --'' "LOCATION",
                '' DIREC_COMMITE,
        NULL "CLIENTE_PRINCIPAL",        
        'NO' "CUST_CAN_BE_USE_NY_AGENCY",
        NULL "CLIENTE_EXP_30PCT_VTAS_O_MAS", 
        NULL "PORCENTAJE_DE_EXPORTACIONES",
        NULL "CONTR_APROB_VF_1",
        NULL FAXNUMBER,
        NULL MAIN_CUSTOMER,
        NULL EMAIL,
        CUST.LMT_CUSTOMER_TYPE,
        --Este cammpo es reemplazado por el usuario que crea el registro en FCC y se asigna en el VB del proyecto
        NULL USUARIO_ULT_CIF,
        TO_CHAR(FECHA_KYC, 'YYYYMMDD') as LAST_KYC_DATE, --// AHernandez - 00006793
        TO_CHAR(sysdate, 'YYYYMMDD') as  INCEPTION_DATE,   --// AHernandez - 00006793  
        CASE NVL(CUSTOMER_CLASSIFICATION_PEP,'0')  
        WHEN '0' THEN 'N'
        WHEN '1' THEN 'Y'
        ELSE 'N'
        END IS_PEP       --// AHernandez - 00010144 
--// AHernandez - 00013297
       --,CUST.TIPO_DE_CLIENTE
       --,CUST.INTERNAL_CONTROL
--// AHernandez - 00013297       
        
        FROM WF_KCC_CUSTOMER_INFO CUST,
             WF_KCC_CUSTOMER_TYPE CTYPE
        WHERE ID_SOLICITUD =IN_ID_SOLICITUD
        AND CUST.CUSTOMER_TYPE = CTYPE.CUSTOMER_ID
        AND NVL(ID_EXISTE_FCC, '0') = '0'--1=Existe en FCC. 0=No existe en FCC.
        AND (NVL(ID_STATUS_FCC, 0) = 0 OR ID_STATUS_FCC IS NULL)--Indica si el cliente se creo en FCC y falló.
        AND LIMIT_EXP_DATE = '01-JAN-80'
        AND CHK_CREATE_FCC = 1 
        AND CUST.LMT_CUSTOMER_TYPE = 'G' ;        
        
    EXCEPTION WHEN NO_DATA_FOUND THEN       
      OPEN out_resultado FOR
      SELECT 'No Hay Registros' resultado, '0' valor from dual;
      
  END;
END IF;   
IF IN_ACCION = '5' THEN--Validamos si todos los clientes se crearon sin errores.
      OPEN out_RESULTADO FOR
      SELECT 
      case when COUNT(*) > 0 then '1' else '0'end resultado  
      FROM wf_kcc_customer_info
      WHERE ID_SOLICITUD = IN_ID_SOLICITUD
      AND NVL(ID_STATUS_FCC, 0) = 0;--Si generó error entonces este campo tendra un cero(0)      
END IF;
/*
  Sección para autocompletar etapas en KCC para grupos y clientes.

IF IN_ACCION = '6' THEN--Validamos si completo los datos del cliente.
      OPEN out_RESULTADO FOR
       select  b.xref_numero_contrato, a.id_customer_fcc, 
       a.id_status_fcc, a.id_solicitud,c.CUSTOMER_NO,d.nu_incidente INCIDENTE
       from wf_kcc_customer_info a join wf_ci_creacion_contratos b
       on a.id_customer_fcc = B.XREF_NUMERO_CONTRATO--b.id_transaccion_incidente
        join STTM_CUSTOMER@LINK_BPMBLFCC  c
        on c.CUSTOMER_NO =  a.customer_no_fcc
         join wf_kcc_solicitud d
        on a.id_solicitud = d.id_solicitud       
        where b.xref_numero_contrato is not null
       and a.id_customer_fcc is not null 
       and (a.id_status_fcc <> 3 or a.id_status_fcc is null)
       --AND (a.LIMIT_EXP_DATE > '01-JAN-80' or a.LIMIT_EXP_DATE IS NULL)
       and a.lmt_customer_type <> 'G' --FJVR-- Se modificó este filtro para diferenciar los grupos de los garantes
       and c.auth_stat = 'U'--Buscamos los que hayan completado los datos pero que no esten autorizados.
       and c.fax_number is not null
       and c.risk_category is not null
       and a.id_status_fcc =1;--Buscamos solo si se creo exitoso en FCC.
END IF;*/

--FJVR. Se modificó para poder realizar el completado de la etapa Completion of FCC CIF con varios registros.
IF IN_ACCION = '6' THEN--Validamos si completo los datos del cliente.
     OPEN out_RESULTADO FOR
      SELECT  DISTINCT
        D.NU_INCIDENTE INCIDENTE,
       (
            SELECT COUNT(A1.ID_SOLICITUD) FROM WF_KCC_CUSTOMER_INFO A1 
            --JOIN WF_CI_CREACION_CONTRATOS B1 ON A1.ID_CUSTOMER_FCC = B1.XREF_NUMERO_CONTRATO--b1.id_transaccion_incidente
            JOIN STTM_CUSTOMER@LINK_BPMBLFCC  C1 ON C1.CUSTOMER_NO =  A1.CUSTOMER_NO_FCC
            JOIN WF_KCC_SOLICITUD D1 ON A1.ID_SOLICITUD = D1.ID_SOLICITUD       
            WHERE 
            --B1.XREF_NUMERO_CONTRATO IS NOT NULL AND 
            A1.ID_CUSTOMER_FCC IS NOT NULL 
            AND (A1.ID_STATUS_FCC <> 3 OR A1.ID_STATUS_FCC IS NULL)
            --AND (a1.LIMIT_EXP_DATE > '01-JAN-80' or a1.LIMIT_EXP_DATE IS NULL)
            AND A1.LMT_CUSTOMER_TYPE <> 'G' --FJVR-- Se modificó este filtro para diferenciar los grupos de los garantes
            AND C1.AUTH_STAT = 'A'--Buscamos los que hayan completado los datos pero que no esten autorizados.
            AND A1.ID_STATUS_FCC =1
            AND A1.ID_SOLICITUD = A.ID_SOLICITUD
       ) ULT_CANTIDAD,
       (
            SELECT  COUNT(A2.ID_SOLICITUD) FROM WF_KCC_CUSTOMER_INFO A2 
            --JOIN WF_CI_CREACION_CONTRATOS B2 ON A2.ID_CUSTOMER_FCC = B2.XREF_NUMERO_CONTRATO--b1.id_transaccion_incidente
            JOIN STTM_CUSTOMER@LINK_BPMBLFCC  C2 ON C2.CUSTOMER_NO =  A2.CUSTOMER_NO_FCC
            JOIN WF_KCC_SOLICITUD D2 ON A2.ID_SOLICITUD = D2.ID_SOLICITUD       
            WHERE 
            -- B2.XREF_NUMERO_CONTRATO IS NOT NULL AND 
            A2.ID_CUSTOMER_FCC IS NOT NULL 
            AND (A2.ID_STATUS_FCC <> 3 OR A2.ID_STATUS_FCC IS NULL)
            --AND (a2.LIMIT_EXP_DATE > '01-JAN-80' or a2.LIMIT_EXP_DATE IS NULL)
            AND A2.LMT_CUSTOMER_TYPE <> 'G' --FJVR-- Se modificó este filtro para diferenciar los grupos de los garantes
            AND C2.AUTH_STAT = 'A'--Buscamos los que hayan completado los datos pero que no esten autorizados.
            --AND c2.fax_number IS NOT NULL
            --and c2.risk_category is not null
            AND A2.ID_STATUS_FCC =1
            AND A2.ID_SOLICITUD = A.ID_SOLICITUD
       ) FCC_CANTIDAD
       
            FROM WF_KCC_CUSTOMER_INFO A 
            --JOIN wf_ci_creacion_contratos b ON A.id_customer_fcc = b.xref_numero_contrato--b.id_transaccion_incidente
            JOIN STTM_CUSTOMER@LINK_BPMBLFCC  C ON C.CUSTOMER_NO =  A.CUSTOMER_NO_FCC
            JOIN WF_KCC_SOLICITUD D ON A.ID_SOLICITUD = D.ID_SOLICITUD
            JOIN WF_HISTORIA_ETAPA HE on HE.NUMEROINCIDENTE = D.NU_INCIDENTE and HE.ID_PROCESO IN(1000,2200) and HE.ID_STEP IN(1012,2215) -- AH 20110921
            WHERE 
            --B.XREF_NUMERO_CONTRATO IS NOT NULL AND 
            A.ID_CUSTOMER_FCC IS NOT NULL 
            AND (A.ID_STATUS_FCC <> 3 OR A.ID_STATUS_FCC IS NULL)
            --AND (a.LIMIT_EXP_DATE > '01-JAN-80' or a.LIMIT_EXP_DATE IS NULL)
            AND A.LMT_CUSTOMER_TYPE <> 'G' --FJVR-- Se modificó este filtro para diferenciar los grupos de los garantes
            AND C.AUTH_STAT = 'A'--Buscamos los que hayan completado los datos pero que no esten autorizados.
            --AND c.fax_number IS NOT NULL
            --and c.risk_category is not null
            AND A.ID_STATUS_FCC =1
            AND D.NU_INCIDENTE NOT IN (SELECT INCIDENT FROM WF_KCC_COMPLETION_CIF)
            and HE.ESTADO_ETAPA = 1 -- AH 20110921
            GROUP BY 
            --B.XREF_NUMERO_CONTRATO, 
            A.ID_CUSTOMER_FCC, A.ID_STATUS_FCC, A.ID_SOLICITUD, C.CUSTOMER_NO, D.NU_INCIDENTE
            ORDER BY d.nu_incidente

       ;--Buscamos solo si se creo exitoso en FCC.
       -------------------
END IF;

IF IN_ACCION = '7' THEN--Validamos si se aprobo el cliente en FCC.
      OPEN OUT_RESULTADO FOR
        
SELECT  DISTINCT
        D.NU_INCIDENTE INCIDENTE,
       (
                SELECT COUNT(A1.ID_SOLICITUD) FROM WF_KCC_CUSTOMER_INFO A1 
                  JOIN WF_CI_CREACION_CONTRATOS B1 ON A1.ID_CUSTOMER_FCC = B1.XREF_NUMERO_CONTRATO--b1.id_transaccion_incidente
                  JOIN STTM_CUSTOMER@LINK_BPMBLFCC  C1 ON C1.CUSTOMER_NO =  A1.CUSTOMER_NO_FCC
                  JOIN WF_KCC_SOLICITUD D1 ON A1.ID_SOLICITUD = D1.ID_SOLICITUD       
                WHERE 
                B1.XREF_NUMERO_CONTRATO IS NOT NULL AND 
                A1.ID_CUSTOMER_FCC IS NOT NULL 
                 AND (A1.ID_STATUS_FCC <> 3 OR A1.ID_STATUS_FCC IS NULL)
                 --AND (a1.LIMIT_EXP_DATE > '01-JAN-80' or a1.LIMIT_EXP_DATE IS NULL)
                 AND A1.LMT_CUSTOMER_TYPE <> 'G' --FJVR-- Se modificó este filtro para diferenciar los grupos de los garantes
                 AND A1.ID_STATUS_FCC =1
                 AND A1.ID_SOLICITUD = A.ID_SOLICITUD
       ) ULT_CANTIDAD,
       -- Cantidad total de clientes que se deben crear
       (
          SELECT  COUNT(A2.ID_SOLICITUD) FROM WF_KCC_CUSTOMER_INFO A2 
          JOIN WF_CI_CREACION_CONTRATOS B2 ON A2.ID_CUSTOMER_FCC = B2.XREF_NUMERO_CONTRATO--b1.id_transaccion_incidente
          JOIN STTM_CUSTOMER@LINK_BPMBLFCC  C2 ON C2.CUSTOMER_NO =  A2.CUSTOMER_NO_FCC
          JOIN WF_KCC_SOLICITUD D2 ON A2.ID_SOLICITUD = D2.ID_SOLICITUD       
          WHERE 
          B2.XREF_NUMERO_CONTRATO IS NOT NULL AND 
            A2.ID_CUSTOMER_FCC IS NOT NULL 
             AND (A2.ID_STATUS_FCC <> 3 OR A2.ID_STATUS_FCC IS NULL)
             --AND (a2.LIMIT_EXP_DATE > '01-JAN-80' or a2.LIMIT_EXP_DATE IS NULL)
             AND A2.LMT_CUSTOMER_TYPE <> 'G' --FJVR-- Se modificó este filtro para diferenciar los grupos de los garantes
             AND C2.AUTH_STAT = 'A'--Buscamos los que hayan completado los datos pero que no esten autorizados.
             --and c2.fax_number is not null
             --and c2.risk_category is not null
             AND A2.ID_STATUS_FCC =1
             AND A2.ID_SOLICITUD = A.ID_SOLICITUD
       ) FCC_CANTIDAD
       -- Cantidad total de clientes que han sido completados
       FROM WF_KCC_CUSTOMER_INFO A 
       JOIN WF_CI_CREACION_CONTRATOS B ON A.ID_CUSTOMER_FCC = B.XREF_NUMERO_CONTRATO--b.id_transaccion_incidente
       JOIN STTM_CUSTOMER@LINK_BPMBLFCC  C ON C.CUSTOMER_NO =  A.CUSTOMER_NO_FCC
       JOIN WF_KCC_SOLICITUD D ON A.ID_SOLICITUD = D.ID_SOLICITUD 
       JOIN WF_HISTORIA_ETAPA HE on HE.NUMEROINCIDENTE = D.NU_INCIDENTE and HE.ID_PROCESO IN(1000,2200) and HE.ID_STEP IN(1012,2215,1013) -- AH 20110921
      
      WHERE 
      B.XREF_NUMERO_CONTRATO IS NOT NULL AND 
      A.ID_CUSTOMER_FCC IS NOT NULL 
       AND (A.ID_STATUS_FCC <> 3 OR A.ID_STATUS_FCC IS NULL)
       --AND (a.LIMIT_EXP_DATE > '01-JAN-80' or a.LIMIT_EXP_DATE IS NULL)
       AND A.LMT_CUSTOMER_TYPE <> 'G' --FJVR-- Se modificó este filtro para diferenciar los grupos de los garantes
       AND C.AUTH_STAT = 'A'--Buscamos los que hayan completado los datos pero que no esten autorizados.
       --and c.fax_number is not null
       --and c.risk_category is not null
       AND A.ID_STATUS_FCC =1 
       and HE.ESTADO_ETAPA = 1  -- AH 20110921
       GROUP BY 
       B.XREF_NUMERO_CONTRATO, 
       A.ID_CUSTOMER_FCC, A.ID_STATUS_FCC, A.ID_SOLICITUD, C.CUSTOMER_NO, D.NU_INCIDENTE  

       ;--Buscamos solo si se creo exitoso en FCC.
       -------------------
END IF;

IF IN_ACCION = '8' THEN--Validamos si se aprobo el Grupo en FCC.
      OPEN OUT_RESULTADO FOR
       SELECT  B.XREF_NUMERO_CONTRATO, A.ID_CUSTOMER_FCC, 
       A.ID_STATUS_FCC, A.ID_SOLICITUD,C.CUSTOMER_NO,D.NU_INCIDENTE INCIDENTE
       FROM WF_KCC_CUSTOMER_INFO A JOIN WF_CI_CREACION_CONTRATOS B
       ON A.ID_CUSTOMER_FCC = B.XREF_NUMERO_CONTRATO--B.ID_TRANSACCION_INCIDENTE
        JOIN STTM_CUSTOMER@LINK_BPMBLFCC  C
        ON C.CUSTOMER_NO =  A.CUSTOMER_NO_FCC
        JOIN WF_KCC_SOLICITUD D
        ON A.ID_SOLICITUD = D.ID_SOLICITUD
        WHERE B.XREF_NUMERO_CONTRATO IS NOT NULL
       AND A.ID_CUSTOMER_FCC IS NOT NULL 
       AND (A.ID_STATUS_FCC <> 3 OR A.ID_STATUS_FCC IS NULL)
       --AND (A.LIMIT_EXP_DATE = '01-JAN-80')
       AND a.LMT_CUSTOMER_TYPE = 'G' --FJVR-- Se modificó este filtro para diferenciar los grupos de los garantes
       AND C.AUTH_STAT = 'A'
       AND A.ID_STATUS_FCC =1;--Buscamos solo si se creo exitoso en FCC.
END IF;
--Cargamos dinamicamente los udfs creados por clientes
--luego los camparamos con los campos a enviar y le asignamos 
--valor dinamicamente en el webservices.
IF IN_ACCION = '9' THEN
      OPEN OUT_RESULTADO FOR
        SELECT FIELD_NAME FROM cstm_function_udf_fields_map@LINK_BPMBLFCC
        WHERE function_id = 'STDCIF'
        AND auth_stat = 'A';
END IF;

--Buscamos todos los clientes y grupos creados exitosamente para enviar
-- esta data por email.
 IF IN_ACCION = '10' THEN     
      FOR c1 in AllGroupsCreated_Cursor
      LOOP
        v_OUT_AllGroup := v_OUT_AllGroup || c1.grupos || '|';
      END LOOP;

      FOR c2 in AllCustCreated_Cursor
      LOOP
        v_OUT_AllCust := v_OUT_AllCust || c2.clientes || '|';
      END LOOP;
      
      OPEN out_RESULTADO FOR
      SELECT v_OUT_AllCust CLIENTES, v_OUT_AllGroup GRUPOS
      FROM dual;       

END IF;

--Buscamos los clientes que existen para comparar contra FCC si la data ha cambiado
--para notificarlo por correo.
IF IN_ACCION = '11' THEN
  begin 
     
      OPEN out_resultado FOR
        SELECT 
        CUSTOMER_NO_FCC, 
        CUSTOMER_NAME1,
        FULLNAME,
        TAXIDNUMBER,
        DV                          "DIGITO VERIFICADOR",
        null EMPTY1,
        FN_BUSCA_COUNTRY_DESCR(CUST.INCORP_COUNTRYID) INCORP_CNTRY_DESC,
        CASE  WHEN INCORP_DATE IS NOT NULL THEN to_char(INCORP_DATE,'dd/mm/yyyy') END  INCORP_DATE,
        NULL EMPTY2,
        FN_BUSCA_COUNTRY_DESCR(cUST.RESIDENCECOUNTRY) RESCTRY_DESC,
        null EMPTY3,
        FN_BUSCA_COUNTRY_DESCR(CUST.NATIONALITYID) NATIONALITYIDDESCR,        
        null EMPTY4,
        FN_BUSCA_RES_LOCATION(cUST.RESIDENCELOCATIONID) RESLOC_DESC,
        NULL EMPTY5,
        (SELECT LANG_NAME FROM SMTB_LANGUAGE@LINK_BPMBLFCC WHERE  LANG_CODE=  CUST.LANGUAGEID)LANGUAGEID_DESC,
        NULL EMPTY6,
        FN_BUSCA_COUNTRY_DESCR(EXPOSURE_COUNTRYID) EXPCTRY_DESC,
        LOCATIONID,
        PHYSICALALINE1,
        PHYSICALALINE2,
        PHYSICALALINE3,
        POSTALACITY,
        POSTALALINE1,
        POSTALALINE2,
        POSTALALINE3,
        TELEPHONENUMBER,
        TELEPHONENUMBER2            "TEL 2 PANAMA",
        FAXNUMBER,
        WEBSITE,
        DEFAULT_MEDIA,
        CUSTOMER_CATEGORY,
        RELATIONTYPE                "RELATION TYPE",
        ACCOUNT_OFFICERID           "ACCOUNT OFFICER",
        null EMPTY0,
        (SELECT CODE_DESC FROM GLTM_MIS_CODE@LINK_BPMBLFCC WHERE active= 'A' 
          and  mis_class=  'INDUSTRY' and MIS_CODE = CUST.INDUSTRY) Industry_DESC,
        SUBSTR(RTRIM(LEGALREPRESENTATIVE), 1, 105) "LEGAL REPRESENTATIVE",
        NAMEEXTERNALAUDITORS        "EXTERNAL AUDITORS",
        NAMEINTERNATIONALRISK,
        NAMEOFECONOMICGROUP,
        ECONOMICGROUPRUC  "ECONOMIC GROUP RUC",
        CASE WHEN BANKTYPE = 'Not aplicable' THEN 'NA' 
             WHEN BANKTYPE = 'NA' THEN 'NA' ELSE BANKTYPE END "BANK TYPE",
        --(SELECT lov FROM udtm_lov@link_bpmblfcc
        --     WHERE field_name = 'BANK TYPE' AND lov_desc = BANKTYPE) "BANK TYPE",
        TYPEOFLICENCE               "TYPE OF LICENSE",
        SWIFT_CODE,
        NULL ABACODEVALUE ,
        COMPLIANCEOFFICER           "COMPLIANCE OFFICER",
        ADDRESSPROCESSAGENTINUSA    "USA PROCESS AGENT",
        
        --Informacion de contactos
        FN_GET_CONTACT_SHOLDER_UDF(IN_ID_SOLICITUD,CUST.CUSTOMER_NO,1,'C') "CONTACT 1",
        FN_GET_CONTACT_SHOLDER_UDF(IN_ID_SOLICITUD,CUST.CUSTOMER_NO,2,'C') "CONTACT 2",
        FN_GET_CONTACT_SHOLDER_UDF(IN_ID_SOLICITUD,CUST.CUSTOMER_NO,3,'C') "CONTACT  3",
        
        --Estos son los campos que se modifican en la etapa Compliance Review
        SOl.GOVERMENT_TYPE,
        CUST.AML_RATINGID,
        CASE WHEN CUST.NY_AGENCY = 1 THEN 'YES'
             WHEN CUST.NY_AGENCY = 0 THEN 'NO' ELSE NULL END CUSTOMER_USED_NY,
        
        --Estos campos se llenan en la pantalla customer codes
        NETWORTH,
        LIAB_ID,
        SHORT_NAME,
        GROUP_CODE,
        null EMPTY8,
        NULL EMPTY9,
        NULL EMPTY10,
        UDFD2.lov_desc RELATIONTYPE_DESC,
        NULL EMPTY12
      FROM WF_KCC_CUSTOMER_INFO CUST, WF_KCC_CUSTOMER_TYPE CTYPE,
          UDTM_LOV@LINK_BPMBLFCC UDFD2, CSTMS_FUNCTION_USERDEF_FIELDS@LINK_BPMBLFCC UDF,
          MITM_CUSTOMER_DEFAULT@LINK_BPMBLFCC MITM, GLTM_MIS_CODE@LINK_BPMBLFCC IND ,
          WF_KCC_SOLICITUD SOL
        WHERE CUST.ID_SOLICITUD = IN_ID_SOLICITUD
        AND CUST.ID_SOLICITUD = SOL.ID_SOLICITUD
        AND CUST.CUSTOMER_TYPE = CTYPE.CUSTOMER_ID        
        AND ID_EXISTE_FCC = '1'
        and UDF.FIELD_VAL_8 = UDFD2.LOV 
        AND UDFD2.field_name = 'RELATION TYPE'
        and CUSTOMER_NO_FCC = SUBSTR (UDF.REC_KEY, 1, 9)
        and  CUSTOMER_NO_FCC = MITM.CUSTOMER
        and MITM.CUST_MIS_1 = IND.MIS_CODE;
    EXCEPTION WHEN NO_DATA_FOUND THEN       
      OPEN out_resultado FOR
      SELECT 'No Hay Registros' resultado, '0' valor from dual;
      
  END;
END IF;  
IF IN_ACCION = '12' THEN
  begin 
     
      open OUT_RESULTADO for
    SELECT  CUST.CUSTOMER_NO "Customer No",   
      CUST.CUSTOMER_NAME1 "Customer Name",  
      Cust.Full_name "Legal or Commercial Name", 
      CORP.C_NATIONAL_ID "Tax Identification Number",
      Udf.Field_val_18 "Dv", -- DV 
      CUST.CUSTOMER_CATEGORY "Customer Category",   
      UDF.FIELD_VAL_8 "Relation Type", -- Relation Type
      --DIMC.v_mis_code1 Industry_code, --industry
      MIT.CUST_MIS_1 Industry, --industry
      IND.CODE_DESC Industry,
      GRP.description "Name of Economic Group", -- Name of Economic Group
      UDF.FIELD_VAL_13 "Name Legal Advisors", -- Legal Representantive
      UDF.FIELD_VAL_14 "Name of External Auditors", -- Name of external auditors
      -- AH - 2010 02 25 - Modificación realizada para unificar la lecutra de los rating
      --'SP:' || UDF.FIELD_VAL_3 || ' FITCH:' || UDF.FIELD_VAL_4 || ' MOODYS:' || UDF.FIELD_VAL_5  "Name Intl. Risk Rating Agency",   
      'MOODYS:' || UDF.FIELD_VAL_5 || ' SP:' || UDF.FIELD_VAL_3 || ' FITCH:' || UDF.FIELD_VAL_4  "Name Intl. Risk Rating Agency",
      CUST.ADDRESS_LINE1 "Postal Address Line1", -- Postal Address
      CUST.ADDRESS_LINE2 "Postal Address Line2",   
      CUST.ADDRESS_LINE3 "Postal Address Line3",  
      CUST.ADDRESS_LINE4 "Postal Address City", -- Postal AddressCity
      CORP.R_ADDRESS1 "Physical Address Line1", --Physical Address
      CORP.R_ADDRESS2 "Physical Address Line2",   
      CORP.R_ADDRESS3 "Physical Address Line3",   
      CUST.UDF_2 "Telephone Number", -- Telephone Number
      UDF.FIELD_VAL_19 "2nd Telephone Number", --2nd Telephone Number
      CUST.FAX_NUMBER "Fax Number",    
      CUST.UDF_1 "WebSite", -- Web Site
      CUST.DEFAULT_MEDIA "Default Media", 
      CORP.INCORP_COUNTRY INCORP_CNTRY, 
      CNTR1.DESCRIPTION "Country of Incorporation" ,
      TO_CHAR(CORP.INCORP_DATE, 'dd/mm/yyyy') "Incorporation Date"
      ,   CUST.COUNTRY RESIDENCE_CNTRY , 
      CNTR2.DESCRIPTION "Residence Country",
      CUST.NATIONALITY NationalityCod,   
      CNTR3.DESCRIPTION Nationality,
      CUST.LOC_CODE ResidenceLocation, 
      LOC.DESCRIPTION  "Residence Location",-- RESIDENCE LOCALTION
      CUST.LANGUAGE Languageid,      
      LANG.LANG_NAME "Language",        
      UDF.FIELD_VAL_7 "Bank Type", -- BANK TYPE
      UDF.FIELD_VAL_9 "Type of License", -- TYPE OF LICENCE
      CUST.SWIFT_CODE "SWIFTCode",   
      CUST.unique_id_value "ABA Code Value",  
      UDF.FIELD_VAL_11 "Compliance Officer", -- COMPLIANCE OFFICER
      UDF.FIELD_VAL_16 "Name Process Agent In USA", -- NAME, ADDRESS OF PROCESS AGENT IN USA
      CORP.networth,   
      Cust.Exposure_country, 
      Cntr4.Description Exposure_country_desc,
      Udf.Field_val_21 "Contact1", 
      Udf.Field_val_22 "Contact2", 
      UDF.FIELD_VAL_23 "Contact3",
      CUST.LIABILITY_NO, 
      CUST.SHORT_NAME, 
      GRP.GROUP_CODE
      ,CUST.RISK_CATEGORY
      ,UDFD.LOV_DESC BANKTYPE_DESC
      ,DEM.description DEFAULT_MEDIA_DESC
      ,UDFD2.LOV_DESC RELATIONTYPE_DESC
      ,CCAT.CUST_CAT_DESC 
      ,UDF.FIELD_VAL_6 "Economic Group RUC" -- DV 
    FROM STTM_CUSTOMER@LINK_BPMBLFCC CUST
   LEFT JOIN STTMS_CUST_CORPORATE@LINK_BPMBLFCC CORP ON CUST.CUSTOMER_NO = CORP.CUSTOMER_NO
    LEFT JOIN CSTMS_FUNCTION_USERDEF_FIELDS@LINK_BPMBLFCC UDF ON CUST.CUSTOMER_NO = SUBSTR (UDF.REC_KEY, 1, 9)
    --LEFT JOIN DIM_CUSTOMER@LINK_BPMBLFCC DIMC ON CUST.customer_no = DIMC.V_CUSTOMER_CODE
    LEFT JOIN MITM_CUSTOMER_DEFAULT@LINK_BPMBLFCC MIT ON CUST.CUSTOMER_NO = MIT.CUSTOMER
    LEFT JOIN sttm_group_code@LINK_BPMBLFCC GRP ON  CUST.group_code = GRP.group_code
    LEFT JOIN SMTB_LANGUAGE@LINK_BPMBLFCC LANG ON CUST.LANGUAGE = LANG.LANG_CODE
    LEFT JOIN STTM_LOCATION@LINK_BPMBLFCC LOC  ON CUST.LOC_CODE = LOC.LOC_CODE   
    LEFT JOIN STTM_COUNTRY@LINK_BPMBLFCC CNTR1 ON CORP.INCORP_COUNTRY = CNTR1.COUNTRY_CODE
    LEFT JOIN STTM_COUNTRY@LINK_BPMBLFCC CNTR2 ON CUST.COUNTRY = CNTR2.COUNTRY_CODE
    LEFT JOIN STTM_COUNTRY@LINK_BPMBLFCC CNTR3 ON CUST.NATIONALITY = CNTR3.COUNTRY_CODE
    LEFT JOIN STTM_COUNTRY@LINK_BPMBLFCC CNTR4 ON CUST.EXPOSURE_COUNTRY = CNTR4.COUNTRY_CODE
    LEFT JOIN GLTM_MIS_CODE@LINK_BPMBLFCC IND ON MIT.CUST_MIS_1 = IND.MIS_CODE
    LEFT JOIN UDTM_LOV@LINK_BPMBLFCC UDFD ON UDF.FIELD_VAL_7 = UDFD.LOV AND  UDFD.FIELD_NAME = 'BANK TYPE'    
    LEFT JOIN WF_KCC_DFLT_MEDIA DEM ON CUST.DEFAULT_MEDIA = DEM.MEDIA
    LEFT JOIN UDTM_LOV@LINK_BPMBLFCC UDFD2 ON UDF.FIELD_VAL_8 = UDFD2.LOV AND UDFD2.FIELD_NAME = 'RELATION TYPE'
    LEFT JOIN STTM_CUSTOMER_CAT@link_bpmblfcc CCAT ON CUST.CUSTOMER_CATEGORY = CCAT.CUST_CAT AND CCAT.record_stat = 'O' AND CCAT.auth_stat = 'A'
 
    WHERE  CUST.auth_stat = 'A'  AND CUST.RECORD_STAT = 'O' 
    AND CUST.CUSTOMER_NO = IN_ID_CUSTOMER_FCC;
        
    EXCEPTION WHEN NO_DATA_FOUND THEN       
      OPEN out_resultado FOR
      SELECT 'No Hay Registros' resultado, '0' valor from dual;
      
  END;
END IF;

IF IN_ACCION = '13' THEN
  begin 
     
      open OUT_RESULTADO for
    SELECT  CUST.CUSTOMER_NO "Customer No",   
      CUST.CUSTOMER_NAME1 "Customer Name",  
      Cust.Full_name "Legal or Commercial Name",   
      CORP.C_NATIONAL_ID "Tax Identification Number",
      Udf.Field_val_18 "Dv", -- DV 
      CORP.INCORP_COUNTRY INCORP_CNTRY, 
      CNTR1.DESCRIPTION "Country of Incorporation" ,
      TO_CHAR(CORP.INCORP_DATE, 'dd/mm/yyyy') "Incorporation Date", 
      CUST.COUNTRY RESIDENCE_CNTRY , 
      CNTR2.DESCRIPTION "Residence Country",
      CUST.NATIONALITY NationalityCod,   
      CNTR3.DESCRIPTION "Nationality",      
      CUST.LOC_CODE "ResidenceLocation", 
      LOC.DESCRIPTION  "Residence Location",-- RESIDENCE LOCALTION
      CUST.LANGUAGE Languageid,      
      LANG.LANG_NAME "Language",       
      Cust.Exposure_country, 
      Cntr4.Description "Exposure_country_desc",      
      MITM.COMP_MIS_2 "Location",
      CORP.R_ADDRESS1 "Physical Address Line1", --Physical Address
      CORP.R_ADDRESS2 "Physical Address Line2",   
      CORP.R_ADDRESS3 "Physical Address Line3",
      CUST.ADDRESS_LINE4 "Postal Address City", -- Postal AddressCity 
      CUST.ADDRESS_LINE1 "Postal Address Line1", -- Postal Address
      CUST.ADDRESS_LINE2 "Postal Address Line2",   
      CUST.ADDRESS_LINE3 "Postal Address Line3",  
      CUST.UDF_2 "Telephone Number", -- Telephone Number
      UDF.FIELD_VAL_19 "2nd Telephone Number", --2nd Telephone Number
      CUST.FAX_NUMBER "Fax Number",    
      CUST.UDF_1 "WebSite", -- Web Site
      CUST.DEFAULT_MEDIA "Default Media",
      CUST.CUSTOMER_CATEGORY "Customer Category",   
      UDF.FIELD_VAL_8 "Relation Type", -- Relation Type
      (SELECT COMP_MIS_1  FROM   MITM_CUSTOMER_DEFAULT@LINK_BPMBLFCC WHERE CUSTOMER = CUST.CUSTOMER_NO) "Account Officer",
      MITM.CUST_MIS_1 "Industry_code", --industry
      IND.CODE_DESC "Industry",
      UDF.FIELD_VAL_13 "Legal Representative Name",
      UDF.FIELD_VAL_14 "Name of External Auditors", -- Name of external auditors
      'MOODYS:' || UDF.FIELD_VAL_5 || ' SP:' || UDF.FIELD_VAL_3 || ' FITCH:' || UDF.FIELD_VAL_4  "Name Intl. Risk Rating Agency",
      GRP.description "Name of Economic Group", -- Name of Economic Group
      UDF.FIELD_VAL_6 "Economic Group RUC", -- DV 
      UDF.FIELD_VAL_7 "Bank Type", -- BANK TYPE
      UDF.FIELD_VAL_9 "Type of License", -- TYPE OF LICENCE
      CUST.SWIFT_CODE "SWIFTCode",   
      CUST.unique_id_value "ABA Code Value",  
      UDF.FIELD_VAL_11 "Compliance Officer", -- COMPLIANCE OFFICER
      UDF.FIELD_VAL_16 "Name Process Agent In USA", -- NAME, ADDRESS OF PROCESS AGENT IN USA
  
      --Informacion de contactos
      Udf.Field_val_21 "Contact1", 
      Udf.Field_val_22 "Contact2", 
      UDF.FIELD_VAL_23 "Contact3",
      
      --Estos son los campos que se modifican en la etapa Compliance Review
      UDF.FIELD_VAL_12 "Goverment Type",
      UDF.FIELD_VAL_20 "Aml Rating",
      UDF.FIELD_VAL_32 "Can be used by NY Agency",
      
      --Estos campos se llenan en la pantalla customer codes
      CORP.networth,
      CUST.LIABILITY_NO, 
      CUST.SHORT_NAME2 "SHORT_NAME", 
      GRP.GROUP_CODE
      ,CUST.RISK_CATEGORY
      ,UDFD.LOV_DESC BANKTYPE_DESC
      ,DEM.description DEFAULT_MEDIA_DESC
      ,UDFD2.LOV_DESC RELATIONTYPE_DESC
      ,CCAT.CUST_CAT_DESC
      ,CUST.auth_stat
    FROM STTM_CUSTOMER@LINK_BPMBLFCC CUST
    LEFT JOIN STTMS_CUST_CORPORATE@LINK_BPMBLFCC CORP ON CUST.CUSTOMER_NO = CORP.CUSTOMER_NO
    LEFT JOIN CSTMS_FUNCTION_USERDEF_FIELDS@LINK_BPMBLFCC UDF ON CUST.CUSTOMER_NO = SUBSTR (UDF.REC_KEY, 1, 9)
    LEFT JOIN MITM_CUSTOMER_DEFAULT@LINK_BPMBLFCC MITM ON CUST.customer_no = MITM.CUSTOMER
    LEFT JOIN sttm_group_code@LINK_BPMBLFCC GRP ON  CUST.group_code = GRP.group_code
    LEFT JOIN SMTB_LANGUAGE@LINK_BPMBLFCC LANG ON CUST.LANGUAGE = LANG.LANG_CODE
    LEFT JOIN STTM_LOCATION@LINK_BPMBLFCC LOC  ON CUST.LOC_CODE = LOC.LOC_CODE   
    LEFT JOIN STTM_COUNTRY@LINK_BPMBLFCC CNTR1 ON CORP.INCORP_COUNTRY = CNTR1.COUNTRY_CODE
    LEFT JOIN STTM_COUNTRY@LINK_BPMBLFCC CNTR2 ON CUST.COUNTRY = CNTR2.COUNTRY_CODE
    LEFT JOIN STTM_COUNTRY@LINK_BPMBLFCC CNTR3 ON CUST.NATIONALITY = CNTR3.COUNTRY_CODE
    LEFT JOIN STTM_COUNTRY@LINK_BPMBLFCC CNTR4 ON CUST.EXPOSURE_COUNTRY = CNTR4.COUNTRY_CODE
    LEFT JOIN GLTM_MIS_CODE@LINK_BPMBLFCC IND ON MITM.CUST_MIS_1 = IND.MIS_CODE
    LEFT JOIN UDTM_LOV@LINK_BPMBLFCC UDFD ON UDF.FIELD_VAL_7 = UDFD.LOV AND  UDFD.FIELD_NAME = 'BANK TYPE'    
    LEFT JOIN WF_KCC_DFLT_MEDIA DEM ON CUST.DEFAULT_MEDIA = DEM.MEDIA
    LEFT JOIN UDTM_LOV@LINK_BPMBLFCC UDFD2 ON UDF.FIELD_VAL_8 = UDFD2.LOV AND UDFD2.FIELD_NAME = 'RELATION TYPE'
    LEFT JOIN STTM_CUSTOMER_CAT@link_bpmblfcc CCAT ON CUST.CUSTOMER_CATEGORY = CCAT.CUST_CAT AND CCAT.record_stat = 'O' AND CCAT.auth_stat = 'A'

    WHERE  (CUST.auth_stat = 'U'  OR CUST.auth_stat = 'A')
    AND CUST.RECORD_STAT = 'O' 
    AND CUST.CUSTOMER_NO = IN_ID_CUSTOMER_FCC;
        
    EXCEPTION WHEN NO_DATA_FOUND THEN       
      OPEN out_resultado FOR
      SELECT 'No Hay Registros' resultado, '0' valor from dual;
      
  END;
END IF; 

IF IN_ACCION = '14' THEN
  begin
  
    SELECT CUSTOMER_NO INTO V_CUSTOMER_NO_KCC FROM WF_KCC_CUSTOMER_INFO 
    WHERE ID_SOLICITUD = IN_ID_SOLICITUD AND CUSTOMER_NO_FCC = IN_ID_CUSTOMER_FCC;
    
    open OUT_RESULTADO for
    select TYPE, NAME, POSITION 
    from WF_KCC_DIRECTOR_MANAG_CONTACT 
    where id_solicitud = IN_ID_SOLICITUD 
    AND CUSTOMER_NO = V_CUSTOMER_NO_KCC
    AND TYPE <> 3
    ORDER BY TYPE, NAME, POSITION ASC;
    
    EXCEPTION WHEN NO_DATA_FOUND THEN       
      OPEN out_resultado FOR
      SELECT 'No Hay Registros' resultado, '0' valor from dual;    
  END;
END IF;

IF IN_ACCION = '15' THEN
  begin
    open OUT_RESULTADO for
    select DIR.DIRECTOR_NAME, CUST.AUTH_STAT
    from STTM_CORP_DIRECTORS@LINK_BPMBLFCC DIR
    inner join STTM_CUSTOMER@LINK_BPMBLFCC CUST on CUST.CUSTOMER_NO = DIR.CUSTOMER_NO
    where DIR.customer_no = IN_ID_CUSTOMER_FCC 
    AND (CUST.auth_stat = 'U'  OR CUST.auth_stat = 'A')
    AND DIR.DIRECTOR_NAME IS NOT NULL
    ORDER BY DIR.DIRECTOR_NAME ASC;
    
    EXCEPTION WHEN NO_DATA_FOUND THEN       
      OPEN out_resultado FOR
      SELECT 'No Hay Registros' resultado, '0' valor from dual;    
  END;
END IF;

IF IN_ACCION = '16' THEN
  begin
    open OUT_RESULTADO for
    SELECT  DISTINCT
        D.NU_INCIDENTE INCIDENTE,
       (
                SELECT COUNT(A1.ID_SOLICITUD) FROM WF_KCC_CUSTOMER_INFO A1 
                  JOIN STTM_CUSTOMER@LINK_BPMBLFCC  C1 ON C1.CUSTOMER_NO =  A1.CUSTOMER_NO_FCC
                  JOIN WF_KCC_SOLICITUD D1 ON A1.ID_SOLICITUD = D1.ID_SOLICITUD       
                WHERE 
                A1.ID_CUSTOMER_FCC IS NULL 
                AND MSG_ERROR_FCC IS NULL
                AND A1.ID_SOLICITUD_LM IS NULL
                AND A1.ID_EXISTE_FCC = 1
                AND A1.ID_SOLICITUD = A.ID_SOLICITUD
       ) ULT_CANTIDAD,
       -- Cantidad total de clientes que se deben crear
       (
          SELECT  COUNT(A2.ID_SOLICITUD) FROM WF_KCC_CUSTOMER_INFO A2 
          JOIN STTM_CUSTOMER@LINK_BPMBLFCC  C2 ON C2.CUSTOMER_NO =  A2.CUSTOMER_NO_FCC
          JOIN WF_KCC_SOLICITUD D2 ON A2.ID_SOLICITUD = D2.ID_SOLICITUD 
          WHERE 
            A2.ID_CUSTOMER_FCC IS NULL 
             AND C2.AUTH_STAT = 'A'--Buscamos los que hayan completado los datos pero que no esten autorizados.
             AND A2.ID_SOLICITUD_LM IS NULL
             AND A2.ID_EXISTE_FCC = 1
             AND A2.ID_SOLICITUD = A.ID_SOLICITUD
       ) FCC_CANTIDAD
       -- Cantidad total de clientes que han sido completados

       FROM WF_KCC_CUSTOMER_INFO A 
       JOIN STTM_CUSTOMER@LINK_BPMBLFCC  C ON C.CUSTOMER_NO =  A.CUSTOMER_NO_FCC
       JOIN WF_KCC_SOLICITUD D ON A.ID_SOLICITUD = D.ID_SOLICITUD 
       JOIN WF_HISTORIA_ETAPA HE ON HE.NUMEROINCIDENTE = D.NU_INCIDENTE AND HE.ID_PROCESO = 1000 AND HE.ID_STEP = 1013
      WHERE 
       A.ID_CUSTOMER_FCC IS NULL 
       AND C.AUTH_STAT = 'A'--Buscamos los que hayan completado los datos pero que no esten autorizados.
       AND A.MSG_ERROR_FCC IS NULL
       AND A.ID_SOLICITUD_LM IS NULL
       AND A.ID_EXISTE_FCC = 1
       AND HE.ESTADO_ETAPA = 1

       GROUP BY 
       A.ID_CUSTOMER_FCC, A.ID_STATUS_FCC, A.ID_SOLICITUD, C.CUSTOMER_NO, D.NU_INCIDENTE;
    
    EXCEPTION WHEN NO_DATA_FOUND THEN       
      OPEN out_resultado FOR
      SELECT 'No Hay Registros' resultado, '0' valor from dual;    
  END;
END IF;
--MS. 19ene17. Se crea para buscar los porcentaje de grupo economica y enviarlos en la actualizacion del cliente.
IF IN_ACCION = '17' THEN
  begin
    open OUT_RESULTADO for
      SELECT CUSTOMER_NO, SHAREHOLDER_ID, PERCENTAGE_HOLDING 
      FROM STTMS_CUST_SHAREHOLDER@link_bpmblfcc
      WHERE CUSTOMER_NO =IN_ID_CUSTOMER_FCC;
    
    EXCEPTION WHEN NO_DATA_FOUND THEN       
      OPEN out_resultado FOR
      SELECT 'No Hay Registros' resultado, '0' valor from dual;    
  END;
END IF;


END BL_KCC_MANEJO_CREACION_CLTE;