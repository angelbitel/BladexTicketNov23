--------------------------------------------------------
--  File created - Wednesday-August-09-2023   
--------------------------------------------------------
--------------------------------------------------------
--  DDL for Procedure BL_LMC_CUST_INFO_INSERT
--------------------------------------------------------
set define off;

  CREATE OR REPLACE PROCEDURE BL_LMC_CUST_INFO_INSERT 
( --IN_CUSTOMER_NO_FCC IN VARCHAR2 DEFAULT NULL, 
    IN_GROUP_CODE       IN NUMBER DEFAULT NULL,
    IN_ID_SOLICITUD     IN VARCHAR2 DEFAULT NULL, 
    IN_USUARIO          IN VARCHAR2 DEFAULT NULL,
    IN_ID_PURPOSE       IN NUMBER DEFAULT NULL,
    IN_CUSTOMER_NO_FCC  IN VARCHAR2 DEFAULT NULL, 
    OUT_RESULTADO OUT SYS_REFCURSOR
) AS
--Renova
--ASerrano: Se coloca el formato en la fecha de expiracion del cliente y se extrae la direccion del nuevo modulo de direcciones
--cuando el cliente es banco con default media swift o default media fax.

--// AHernandez - 00006793 - agregando control de ultima fecha KYC
--// AHernandez - 00010144 - Agregando el is PEP
--// AHernandez - 00013297 -  20190314 - Se agregan nuevos campos para las validaciones de AML Rating

    V_LIABILITY_NO        VARCHAR2(9);
    V_CUSTOMER_NO_FCC     VARCHAR2(9);
    V_CUSTOMER_NAME1      VARCHAR2(105);
    V_GROUP_CODE          VARCHAR2(9);
    V_CUST_LIABILITY_NO   VARCHAR2(9);
    V_ID_CUSTOMER         NUMBER (10);
    V_ID_SOLICITUD        VARCHAR2(20);
    V_ID_TIPO_CHECK       VARCHAR2(20); 
    V_CUSTOMER_ID         VARCHAR2(20);
    V_ID_CUSTOMER_ANT     NUMBER (10);
    V_ID_SBP_CATEGORY     NUMBER (10);
    V_ID_MAIN_CUSTOMER    VARCHAR2(9);
    S_ERROR VARCHAR2(1000);
    V_OLD_ID_CUSTOMER     NUMBER;
    V_CANTIDAD_SOL_ANT    NUMBER; 
    V_COUNTRY_OFF_FUNC    VARCHAR2(900);
    V_ACTUALIZA NUMBER;

    V_OUT_RESULTADO  SYS_REFCURSOR;

    CURSOR V_CUST_CURSOR IS
    /***** Se buscan todos los clientes relacionados a un GROUP_CODE especifico y se guardan en un Cursor  *****/
    SELECT CUST.CUSTOMER_NO, CUST.CUSTOMER_NAME1, CUST.LIABILITY_NO, CUST.GROUP_CODE, UDF.FIELD_VAL_31
    FROM STTM_CUSTOMER@LINK_BPMBLFCC CUST 
    INNER JOIN  CSTMS_FUNCTION_USERDEF_FIELDS@LINK_BPMBLFCC UDF ON CUST.CUSTOMER_NO = SUBSTR (UDF.REC_KEY, 1, 9)
    WHERE UDF.FIELD_VAL_31 = IN_CUSTOMER_NO_FCC
    --CUST.LIABILITY_NO IN(SELECT DISTINCT LIABILITY_NO FROM STTM_CUSTOMER@LINK_BPMBLFCC WHERE LIABILITY_NO = V_LIABILITY_NO)
    AND UDF.FIELD_VAL_17 <> '1970-01-01';     


    CURSOR V_CUST_CURSOR_B IS
    /***** Se buscan todos los clientes relacionados a un GROUP_CODE especifico y se guardan en un Cursor  *****/
    SELECT CUST.CUSTOMER_NO, CUST.CUSTOMER_NAME1, CUST.LIABILITY_NO, CUST.GROUP_CODE, UDF.FIELD_VAL_31
    FROM STTM_CUSTOMER@LINK_BPMBLFCC CUST 
    INNER JOIN  CSTMS_FUNCTION_USERDEF_FIELDS@LINK_BPMBLFCC UDF ON CUST.CUSTOMER_NO = SUBSTR (UDF.REC_KEY, 1, 9)
    WHERE --CUST.LIABILITY_NO IN(SELECT DISTINCT LIABILITY_NO FROM STTM_CUSTOMER@LINK_BPMBLFCC WHERE GROUP_CODE = IN_GROUP_CODE)
    CUST.CUSTOMER_NO = IN_CUSTOMER_NO_FCC 
    AND UDF.FIELD_VAL_17 <> '1970-01-01'; 

    --HLEE 06092016 - Este cursor no se usa
    --CURSOR V_CUST_CURSOR_C IS
    /***** Se buscan todos los registros del check list de la ultima solicitud vigente para el cliente a modificar  *****/
    --SELECT ID_ITEM_CHECK FROM WF_CHECK_X_SOLICITUD   
    --WHERE ID_SOLICITUD = V_ID_SOLICITUD        --> ultima solicitud donde participo el cliente, completada y sin cancelar.
    --AND CUSTOMER_NO IS NOT NULL; 

    BEGIN 
        /*
        Aserrano 19 de Diciembre de 2011
        Se coloca este condicional cuando el proposito es 6 porque cuando se genera un incidente de actualizacion desde el monitoreo
        se insertan los clientes desde el WS de limites. 
        Con esto se borran los clientes y luego se buscan en BD.
        */
        --HLEE 16-07-2018 SS-UCP-01 Esto no permite el guardado masivo de varios clientes
       /* IF IN_ID_PURPOSE  <> 1 THEN
          BEGIN
            DELETE FROM WF_KCC_CUSTOMER_INFO WHERE ID_SOLICITUD = IN_ID_SOLICITUD;
            COMMIT;
          END;
        END IF;*/

        IF IN_ID_PURPOSE = 6 THEN 
            INSERT INTO BORRAR (x,y,FECHA) VALUES ('1. ES KYC UPDATE ',IN_CUSTOMER_NO_FCC,  systimestamp);
            /***** Se abre el Cursor Customer con los clientes relacionados y se empieza a recorrer el mismo.  *****/
            OPEN V_CUST_CURSOR_B;
                LOOP 
                    FETCH V_CUST_CURSOR_B INTO V_CUSTOMER_NO_FCC, V_CUSTOMER_NAME1, V_CUST_LIABILITY_NO, V_GROUP_CODE, V_ID_MAIN_CUSTOMER;
                    EXIT WHEN V_CUST_CURSOR_B%NOTFOUND;

                    SELECT BL_SEQ_KCC_CUSTOMERS.NEXTVAL INTO V_ID_CUSTOMER FROM DUAL;

                    --// AHernandez - 00010144 SE AGREGA EL CUSTOMER_CLASSIFICATION_PEP

                    --INSERT INTO BORRAR (x,y) VALUES ('ANTES DE INSERT '|| V_ID_CUSTOMER || '-' || V_CUSTOMER_NO_FCC, ' CUSTOMER ANT. '||V_ID_CUSTOMER_ANT);
                    --COMMIT;
                    /***** Se busca en Flexcube parte del perfil del cliente y se inserta en WF_KCC_CUSTOMER_INFO  *****/ 
                    INSERT INTO WF_KCC_CUSTOMER_INFO (CUSTOMER_NO,            CUSTOMER_NAME1,       FULLNAME,                   TAXIDNUMBER,
                                                      DV,                     INCORP_COUNTRYID,     INCORP_DATE,                RESIDENCECOUNTRY,
                                                      NATIONALITYID,          RESIDENCELOCATIONID,  LANGUAGEID,                 EXPOSURE_COUNTRYID,
                                                      LOCATIONID,             PHYSICALALINE1,       PHYSICALALINE2,             PHYSICALALINE3,
                                                      POSTALALINE1,           POSTALALINE2,         POSTALALINE3,               POSTALACITY, 
                                                      TELEPHONENUMBER,        TELEPHONENUMBER2,     FAXNUMBER,                  WEBSITE,                      
                                                      DEFAULT_MEDIA,          CUSTOMER_CATEGORY,    RELATIONTYPE,               ACCOUNT_OFFICERID,
                                                      INDUSTRY,               LEGALREPRESENTATIVE,  NAMEEXTERNALAUDITORS,       NAMEINTERNATIONALRISK,
                                                      NAMEOFECONOMICGROUP,    ECONOMICGROUPRUC,     BANKTYPE,                   TYPEOFLICENCE,
                                                      SWIFT_CODE,             COMPLIANCEOFFICER,    ADDRESSPROCESSAGENTINUSA,
                                                      --ASerrano: 19May2016. El Aba code ya no se guardara en ultimus. Desde ahora este campo campo guardara
                                                      --de manera oculta el AML Rating que tiene el cliente en Flexcube
                                                      ABACODEVALUE,      
                                                      NY_AGENCY,            NETWORTH,                   LIAB_ID,
                                                      SHORT_NAME,             GROUP_CODE,           ID_SOLICITUD,               CUSTOMER_NO_FCC,
                                                      RELACIONADO,            ID_MAIN_CUSTOMER,     MAIN_CUSTOMER,              EMAIL,
                                                      INTERNAL_CLASSIFICATION, 
                                                      --HLEE  16-08-2016
                                                      LIMIT_EXP_DATE, FECHA_KYC, INCEPTION_DATE, CUSTOMER_CLASSIFICATION_PEP, TIPO_DE_CLIENTE, 
                                                      MONITOREO_TRANSACCIONAL, INTERNAL_CONTROL
                                                      --, NEGATIVE_NEWS, SANCTIONS
                                                      ,CO_COVENANTS, CO_DEUDOR_PRINCIPAL,CHK_CONTR_APROB_VF,CUSTOMER_TYPE  --2019.09.18 bmg ticket 16689 y 17569 
                                                      ,CINU  --2019.12.03 bmg ticket 00016775-CINU
                                                      ,CO_ESG_RATING   --OH Mar2021 Ticket#21170
                                                      ,DATE_ESG_RATING   --OH Mar2021 Ticket#21170
                                                      ,CO_CLIENT_BETTER_COUNTRY   --OH 26Sep2022 Ticket 33103
                                                      ,CO_RISK_CUST_TYPE   --OH 26Sep2022 Ticket 33103
                                                      --,CO_RELATION_TYPE    --OH 26Sep2022 Ticket 33103
                                                      )
                    SELECT V_ID_CUSTOMER,   
                    CUST.CUSTOMER_NAME1, --"Customer Name",  
                    Cust.Full_name, --"Legal or Commercial Name",   
                    CORP.C_NATIONAL_ID, --"Tax Identification Number",
                    Udf.Field_val_18, -- DV 
                    CORP.INCORP_COUNTRY, --INCORP_CNTRY, 
                    CORP.INCORP_DATE, --"Incorporation Date", 
                    CUST.COUNTRY, --RESIDENCE_CNTRY, 
                    CUST.NATIONALITY, --NationalityCod,      
                    CUST.LOC_CODE, --"ResidenceLocation", 
                    'ENG' LANGUAGE, --Languageid siempre es ingles,
                    Cust.Exposure_country, 
                    MITM.COMP_MIS_2, --"Location",
                    CORP.R_ADDRESS1, --"Physical Address Line1", --Physical Address
                    CORP.R_ADDRESS2, --"Physical Address Line2",   
                    CORP.R_ADDRESS3, --"Physical Address Line3",

                    --CUST.ADDRESS_LINE1, --"Postal Address Line1", -- Postal Address
                    --CUST.ADDRESS_LINE2, --"Postal Address Line2",   
                    --CUST.ADDRESS_LINE3, --"Postal Address Line3",  
                    --CUST.ADDRESS_LINE4, --"Postal Address City", -- Postal AddressCity 

                    CASE WHEN CUST.DEFAULT_MEDIA = 'FAX' OR CUST.DEFAULT_MEDIA = 'SWIFT' THEN
                    (SELECT ADDRESS1 FROM MSTM_CUST_ADDRESS@LINK_BPMBLFCC 
                     WHERE CUSTOMER_NO = CUST.CUSTOMER_NO AND MEDIA = 'MAIL' AND LOCATION = 'CIF' AND RECORD_STAT = 'O' AND AUTH_STAT = 'A')
                    ELSE CUST.ADDRESS_LINE1 END "Postal Address Line1", -- Postal Address

                    CASE WHEN CUST.DEFAULT_MEDIA = 'FAX' OR CUST.DEFAULT_MEDIA = 'SWIFT' THEN
                    (SELECT ADDRESS2 FROM MSTM_CUST_ADDRESS@LINK_BPMBLFCC
                     WHERE CUSTOMER_NO = CUST.CUSTOMER_NO AND MEDIA = 'MAIL' AND LOCATION = 'CIF' AND RECORD_STAT = 'O' AND AUTH_STAT = 'A')
                    ELSE CUST.ADDRESS_LINE2 END "Postal Address Line2", -- Postal Address

                    CASE WHEN CUST.DEFAULT_MEDIA = 'FAX' OR CUST.DEFAULT_MEDIA = 'SWIFT' THEN
                    (SELECT ADDRESS3 FROM MSTM_CUST_ADDRESS@LINK_BPMBLFCC 
                     WHERE CUSTOMER_NO = CUST.CUSTOMER_NO AND MEDIA = 'MAIL' AND LOCATION = 'CIF' AND RECORD_STAT = 'O' AND AUTH_STAT = 'A')
                    ELSE CUST.ADDRESS_LINE3 END "Postal Address Line3", -- Postal Address

                    CASE WHEN CUST.DEFAULT_MEDIA = 'FAX' OR CUST.DEFAULT_MEDIA = 'SWIFT' THEN
                    (SELECT ADDRESS4 FROM MSTM_CUST_ADDRESS@LINK_BPMBLFCC 
                     WHERE CUSTOMER_NO = CUST.CUSTOMER_NO AND MEDIA = 'MAIL' AND LOCATION = 'CIF' AND RECORD_STAT = 'O' AND AUTH_STAT = 'A')
                    ELSE CUST.ADDRESS_LINE4 END "Postal Address City", -- Postal Address

                    --CUST.UDF_2, --"Telephone Number", -- Telephone Number
                    CP.TELEPHONE "Telephone Number",
                    UDF.FIELD_VAL_19, --"2nd Telephone Number", --2nd Telephone Number
                    --CUST.FAX_NUMBER, --"Fax Number", 
                    CP.FAX "Fax Number",
                    CUST.UDF_1, --"WebSite", -- Web Site
                    CUST.DEFAULT_MEDIA, --"Default Media",
                    CUST.CUSTOMER_CATEGORY, --"Customer Category",   
                    UDF.FIELD_VAL_8, --"Relation Type", -- Relation Type
                    (SELECT COMP_MIS_1  FROM   MITM_CUSTOMER_DEFAULT@LINK_BPMBLFCC WHERE CUSTOMER = CUST.CUSTOMER_NO), --"Account Officer",
                    MITM.CUST_MIS_1, --"Industry_code", --industry
                    UDF.FIELD_VAL_13, --"Legal Representative Name",
                    UDF.FIELD_VAL_14, --"Name of External Auditors", -- Name of external auditors
                    'MOODYS:' || UDF.FIELD_VAL_5 || ' SP:' || UDF.FIELD_VAL_3 || ' FITCH:' || UDF.FIELD_VAL_4,  --"Name Intl. Risk Rating Agency",
                    GRP.description, --"Name of Economic Group", -- Name of Economic Group
                    UDF.FIELD_VAL_6, --"Economic Group RUC", -- DV 
                    FN_LMC_BUSCA_BANKTYPE(UDF.FIELD_VAL_7),--UDF.FIELD_VAL_7, --"Bank Type", -- BANK TYPE
                    UDF.FIELD_VAL_9, --"Type of License", -- TYPE OF LICENCE
                    CUST.SWIFT_CODE, --"SWIFTCode", 
                   -- CUST.unique_id_value, --"ABA Code Value",  

                    UDF.FIELD_VAL_11, --"Compliance Officer", -- COMPLIANCE OFFICER
                    UDF.FIELD_VAL_16, --"Name Process Agent In USA", -- NAME, ADDRESS OF PROCESS AGENT IN USA
                    UDF.FIELD_VAL_20, --"Aml Rating",
                    CASE
                    WHEN UDF.FIELD_VAL_32='YES' THEN '1'
                    WHEN UDF.FIELD_VAL_32='NO'THEN '0'
                    ELSE CASE WHEN CORP.INCORP_COUNTRY ='BR' OR CORP.INCORP_COUNTRY = 'ARG' THEN '1' ELSE '0' END
                    END, --"Can be used by NY Agency",
                    CORP.networth,
                    V_CUST_LIABILITY_NO, --CUST.LIABILITY_NO, 
                    CUST.SHORT_NAME, --"SHORT_NAME", 
                    V_GROUP_CODE, --GRP.GROUP_CODE,
                    IN_ID_SOLICITUD,
                    V_CUSTOMER_NO_FCC,
                    '1',  
                    UDF.FIELD_VAL_31, -- ID_MAIN_CUSTOMER
                    (CASE WHEN CUST.CUSTOMER_NO = V_ID_MAIN_CUSTOMER THEN 1 ELSE 0 END),
                    CP.E_MAIL,
                    (SELECT FIELD_VAL_1 FROM CSTMS_FUNCTION_USERDEF_FIELDS@LINK_BPMBLFCC WHERE REC_KEY = (CUST.CUSTOMER_NO||'~')),
                    --HLEE  16-08-2016
                    TO_DATE(UDF.FIELD_VAL_17, 'YYYY-MM-DD'),
                    TO_DATE(UDF.FIELD_VAL_39, 'YYYY-MM-DD'), -- // AHernandez - 00006793
                    TO_DATE(UDF.FIELD_VAL_40, 'YYYY-MM-DD'),
                    CASE TRIM(NVL(UDF.FIELD_VAL_41, 'N')) WHEN 'N' THEN '0' WHEN 'Y' THEN '1' ELSE '0'  END, -- // AHernandez - 00010144
                    UDF.FIELD_VAL_42,--// AHernandez - 00013297 - TIPO DE CLIENTE
                    UDF.FIELD_VAL_43,--// AHernandez - 00013297 - MONITOREO TRANSACCIONAL
                    UDF.FIELD_VAL_45--// AHernandez - 00013297 - INTERNAL_CONTROL
                    --,UDF.FIELD_VAL_46,--// AHernandez - 00013297 - NEGATIVE_NEWS                     UDF.FIELD_VAL_47 --// AHernandez - 00013297 - SANCTIONS
                    --2019.09.18 bmg ticket 16689 y 17569
                     ,UDF.FIELD_VAL_46 --covenants
                     ,UDF.FIELD_VAL_48 --related customer
                     ,CASE UPPER(UDF.FIELD_VAL_36)
                        WHEN 'SI' THEN 1
                        WHEN 'NO' THEN 0
                        ELSE 0
                      END
                      ,case 
                        when UDF.FIELD_VAL_42 is null  then case upper(cust.customer_type)
                                                                 when 'C' then 1
                                                                 when 'B'  then 2
                                                            end
                        when UDF.FIELD_VAL_42 = '02'  then case upper(cust.customer_type)
                                                                 when 'C' then 4
                                                                 when 'B'  then 5
                                                            end
                        
                        when UDF.FIELD_VAL_42 = '07'  then  case upper(cust.customer_type)
                                                                 when 'C' then 6
                                                                 when 'B'  then 7
                                                            end                                                    
                        else  
                            -----
                            case upper(cust.customer_type)
                                     when 'C' then 1
                                     when 'B'  then 2
                            end
                            -----
                      end
                     
                    -- fin 16689 y 17569
                    ,UDF.FIELD_VAL_50  --2019.12.03 bmg ticket 00016775-CINU
                    -- OH Mar2021 Ticket#21170 - Campos para Rating ESG
                    ,UDF.FIELD_VAL_52    -- Código Rating ESG
                    ,TO_DATE(UDF.FIELD_VAL_53, 'YYYY-MM-DD')    -- Fecha de Rating ESG
                    -- OH 26Sep2022 Ticket#33103 - Campos nuevos para segmentación de clientes
                    ,UDF.FIELD_VAL_49    -- Cliente mejor que pais
                    ,UDF.FIELD_VAL_54    -- Tipo de Cliente Riesgo   
                    --,UDF.FIELD_VAL_8    -- Relation Type                     
                    -- Fin Ticket    
                    FROM STTM_CUSTOMER@LINK_BPMBLFCC CUST
                    LEFT JOIN STTMS_CUST_CORPORATE@LINK_BPMBLFCC CORP ON CUST.CUSTOMER_NO = CORP.CUSTOMER_NO
                    LEFT JOIN CSTMS_FUNCTION_USERDEF_FIELDS@LINK_BPMBLFCC UDF ON CUST.CUSTOMER_NO = SUBSTR (UDF.REC_KEY, 1, 9) 
                    LEFT JOIN MITM_CUSTOMER_DEFAULT@LINK_BPMBLFCC MITM ON CUST.customer_no = MITM.CUSTOMER
                    LEFT JOIN sttm_group_code@LINK_BPMBLFCC GRP ON  CUST.group_code = GRP.group_code
                    LEFT JOIN STTMS_CUST_PERSONAL@LINK_BPMBLFCC CP ON CP.CUSTOMER_NO = CUST.CUSTOMER_NO
                    LEFT JOIN SMTB_LANGUAGE@LINK_BPMBLFCC LANG ON CUST.LANGUAGE = LANG.LANG_CODE
                    LEFT JOIN STTM_LOCATION@LINK_BPMBLFCC LOC  ON CUST.LOC_CODE = LOC.LOC_CODE   
                    LEFT JOIN STTM_COUNTRY@LINK_BPMBLFCC CNTR1 ON CORP.INCORP_COUNTRY = CNTR1.COUNTRY_CODE
                    LEFT JOIN STTM_COUNTRY@LINK_BPMBLFCC CNTR2 ON CUST.COUNTRY = CNTR2.COUNTRY_CODE
                    LEFT JOIN STTM_COUNTRY@LINK_BPMBLFCC CNTR3 ON CUST.NATIONALITY = CNTR3.COUNTRY_CODE
                    LEFT JOIN STTM_COUNTRY@LINK_BPMBLFCC CNTR4 ON CUST.EXPOSURE_COUNTRY = CNTR4.COUNTRY_CODE
                    LEFT JOIN GLTM_MIS_CODE@LINK_BPMBLFCC IND ON MITM.CUST_MIS_1 = IND.MIS_CODE
                    LEFT JOIN UDTM_LOV@LINK_BPMBLFCC UDFD ON UDF.FIELD_VAL_7 = UDFD.LOV AND  UDFD.FIELD_NAME = 'BANK_TYPE'    
                    LEFT JOIN WF_KCC_DFLT_MEDIA DEM ON CUST.DEFAULT_MEDIA = DEM.MEDIA
                    LEFT JOIN UDTM_LOV@LINK_BPMBLFCC UDFD2 ON UDF.FIELD_VAL_8 = UDFD2.LOV AND UDFD2.FIELD_NAME = 'RELATION_TYPE'
                    LEFT JOIN STTM_CUSTOMER_CAT@link_bpmblfcc CCAT ON CUST.CUSTOMER_CATEGORY = CCAT.CUST_CAT AND CCAT.record_stat = 'O' AND CCAT.auth_stat = 'A'
                    WHERE  (CUST.auth_stat = 'U'  OR CUST.auth_stat = 'A')
                    AND CUST.RECORD_STAT = 'O' 
                    AND CUST.CUSTOMER_NO = V_CUSTOMER_NO_FCC;

                    COMMIT;

                    /***** Se busca la maxima Solicitud asociada al cliente por su CUSTOMER_NO_FCC.*****/
                    --SS-BUS-01  2018.07.18 bmg
                    SELECT COUNT(FN_LMC_LMT_ULTIMA_SOLICITUD(V_CUSTOMER_NO_FCC)) INTO V_CANTIDAD_SOL_ANT FROM DUAL;

                    IF V_CANTIDAD_SOL_ANT > 0 THEN
                      SELECT FN_LMC_LMT_ULTIMA_SOLICITUD(V_CUSTOMER_NO_FCC) INTO V_ID_SOLICITUD FROM DUAL;
                    ELSE
                      V_ID_SOLICITUD:=NULL;
                    END IF;

                    /***** Si se encuentra solicitud asociada al cliente, se extraen los campos restantes que no estaban en Flexcube y se actualiza el  *****/
                    /***** registro de la nueva solicitud para ese cliente con dichos campos. *****/
                    IF V_ID_SOLICITUD IS NOT NULL THEN
                        --SELECT CUSTOMER_NO INTO V_ID_CUSTOMER_ANT FROM WF_KCC_CUSTOMER_INFO WHERE ID_SOLICITUD = V_ID_SOLICITUD AND CUSTOMER_NO_FCC = V_CUSTOMER_NO_FCC;
                        SELECT CUSTOMER_NO, SBP_CATEGORYID INTO V_ID_CUSTOMER_ANT, V_ID_SBP_CATEGORY FROM WF_KCC_CUSTOMER_INFO WHERE ID_SOLICITUD = V_ID_SOLICITUD AND CUSTOMER_NO_FCC = V_CUSTOMER_NO_FCC;

                        INSERT INTO BORRAR (x,y,FECHA) VALUES ('2. DESPUES DE INSERT '|| V_ID_CUSTOMER || '-' || V_CUSTOMER_NO_FCC || '-' || V_ID_SOLICITUD, ' CUSTOMER ANT. '||V_ID_CUSTOMER_ANT, systimestamp);
                        --// AHernandez - 00010144 SE QUITA EL CUSTOMER_CLASSIFICATION_PEP
                        --// hlee - 12/10/2018 SE COLOCA NULL A ID_STATUS_FCC

                        UPDATE WF_KCC_CUSTOMER_INFO
                        SET (     SHAREHOLDER,                  
                        PRODUCT_SERVICE_OFFERED,      RELATEDCOMPANIES,               NAME_ADDRESS_LEGAL_ADVISOR,     REFERENCE_BANKING_COMMERCIAL,   
                        NAME_OF_STOCK,                COUNTRIES_WHERE_OFFERS,         REGULATORY_AUTHORITY,
                        RELATEDACCOUNT,               CHK_SAMESHOLDERS_MAINCUST,      ID_EXISTE_FCC,                  SBP_CATEGORYID, 
                        DESCRIPCION_PEP,                INCORPORATION_PURPOSE,          SUB_ECOGR_CD,           LEGALREPRESENTATIVE_INFO, 
                        LAST_CHANGE_DATE,             DIGNATARIES,                    POWER_DEES,                     CHK_CREATE_FCC,         AUTHORIZED_SIGNATURES, 
                        RELATION_CORRESPONSAL,                                        SALES_MORE_30_PERCENT,          EXPORT_SHARE,           CUSTOMER_NO_FCC,
                        --CUSTOMER_TYPE, 2019.10.09 bmg ticket ticket 16689 y 17569               
                        ID_CUSTOMER_FCC,                ID_SOLICITUD_LM,                ID_STATUS_FCC,          
                        AML_RATINGID_NY,
                        LIMIT_EXP_DATE,               LMT_CUSTOMER_TYPE,              RISK_RATING,                    PATRIOT_EXC_DATE,
                        NAMEOFECONOMICGROUP,          FAXNUMBER,                      FECHA_CREACION_CLIENTE,         PUBLIC_TRADE_COMP,      AML_EXC_DATE,
                        GIIN_NUMBER,                  W8_FORM_DATE,                   
                        AML_RATINGID,                 FECHA_KYC,                      INCEPTION_DATE,                 TIPO_DE_CLIENTE,        MONITOREO_TRANSACCIONAL,
                        INTERNAL_CONTROL,             NEGATIVE_NEWS,                  SANCTIONS
                        )= (SELECT  SHAREHOLDER,
                        PRODUCT_SERVICE_OFFERED,      RELATEDCOMPANIES,               NAME_ADDRESS_LEGAL_ADVISOR,     REFERENCE_BANKING_COMMERCIAL,   
                        NAME_OF_STOCK,                COUNTRIES_WHERE_OFFERS,         REGULATORY_AUTHORITY,
                        RELATEDACCOUNT,               CHK_SAMESHOLDERS_MAINCUST,      1,                              SBP_CATEGORYID, 
                        DESCRIPCION_PEP,                INCORPORATION_PURPOSE,          SUB_ECOGR_CD,           LEGALREPRESENTATIVE_INFO, 
                        LAST_CHANGE_DATE,             DIGNATARIES,                    POWER_DEES,                     0,                      AUTHORIZED_SIGNATURES, 
                        RELATION_CORRESPONSAL,                                        SALES_MORE_30_PERCENT,          EXPORT_SHARE,           CUSTOMER_NO_FCC, 
                        --CUSTOMER_TYPE, 2019.10.09 bmg ticket 16689 y 17569               
                        ID_CUSTOMER_FCC,                ID_SOLICITUD_LM,                NULL,                      
                        (SELECT CASE WHEN UDF.FIELD_VAL_32='YES' THEN UDF.FIELD_VAL_20 ELSE NULL END  FROM CSTMS_FUNCTION_USERDEF_FIELDS@LINK_BPMBLFCC UDF WHERE SUBSTR (UDF.REC_KEY, 1, 9) =  CUSTOMER_NO_FCC) AML_RATINGID_NY,
                        (SELECT TO_DATE(UDF.FIELD_VAL_17, 'YYYY-MM-DD') FROM CSTMS_FUNCTION_USERDEF_FIELDS@LINK_BPMBLFCC UDF WHERE SUBSTR (UDF.REC_KEY, 1, 9) =  CUSTOMER_NO_FCC) LIMIT_EXP_DATE,                 
                        LMT_CUSTOMER_TYPE,              RISK_RATING,            PATRIOT_EXC_DATE,
                        NAMEOFECONOMICGROUP,          FAXNUMBER,                      FECHA_CREACION_CLIENTE,         PUBLIC_TRADE_COMP,      AML_EXC_DATE,
                        --Aserrano 22Abr2015
                        --Mojo 7643585 Se solicita agregar dos campos nuevos al formulario del KYC 
                        --para indicar si el cliente cumple con la ley FATCA                        
                        GIIN_NUMBER,                  W8_FORM_DATE,                   
                        (SELECT CASE WHEN UDF.FIELD_VAL_32='NO' THEN UDF.FIELD_VAL_20 ELSE NULL END FROM CSTMS_FUNCTION_USERDEF_FIELDS@LINK_BPMBLFCC UDF WHERE SUBSTR (UDF.REC_KEY, 1, 9) =  CUSTOMER_NO_FCC) AML_RATINGID,
                        (SELECT TO_DATE(UDF.FIELD_VAL_39, 'YYYY-MM-DD') FROM CSTMS_FUNCTION_USERDEF_FIELDS@LINK_BPMBLFCC UDF WHERE UDF.REC_KEY =  CUSTOMER_NO_FCC || '~' AND function_id= 'STDCIF' ) KYC_DATE,  -- // AHernandez - 00006793
                        (SELECT TO_DATE(UDF.FIELD_VAL_40, 'YYYY-MM-DD') FROM CSTMS_FUNCTION_USERDEF_FIELDS@LINK_BPMBLFCC UDF WHERE UDF.REC_KEY =  CUSTOMER_NO_FCC || '~'  AND function_id= 'STDCIF' ) INCEPTION_DATE
                        
                        ,(SELECT UDF.FIELD_VAL_42 FROM CSTMS_FUNCTION_USERDEF_FIELDS@LINK_BPMBLFCC UDF WHERE UDF.REC_KEY =  CUSTOMER_NO_FCC || '~' AND function_id= 'STDCIF' ) TIPO_DE_CLIENTE  --// AHernandez - 00013297
                        ,(SELECT UDF.FIELD_VAL_43 FROM CSTMS_FUNCTION_USERDEF_FIELDS@LINK_BPMBLFCC UDF WHERE UDF.REC_KEY =  CUSTOMER_NO_FCC || '~' AND function_id= 'STDCIF' ) MONITOREO_TRANSACCIONAL  --// AHernandez - 00013297                        
                        ,(SELECT UDF.FIELD_VAL_45 FROM CSTMS_FUNCTION_USERDEF_FIELDS@LINK_BPMBLFCC UDF WHERE UDF.REC_KEY =  CUSTOMER_NO_FCC || '~' AND function_id= 'STDCIF' ) INTERNAL_CONTROL  --// AHernandez - 00013297
                        ,NEGATIVE_NEWS --(SELECT UDF.FIELD_VAL_46 FROM CSTMS_FUNCTION_USERDEF_FIELDS@LINK_BPMBLFCC UDF WHERE UDF.REC_KEY =  CUSTOMER_NO_FCC || '~' AND function_id= 'STDCIF' ) NEGATIVE_NEWS  --// AHernandez - 00013297
                        ,SANCTIONS --(SELECT UDF.FIELD_VAL_47 FROM CSTMS_FUNCTION_USERDEF_FIELDS@LINK_BPMBLFCC UDF WHERE UDF.REC_KEY =  CUSTOMER_NO_FCC || '~' AND function_id= 'STDCIF' ) SANCTIONS  --// AHernandez - 00013297
                        FROM WF_KCC_CUSTOMER_INFO 
                        WHERE ID_SOLICITUD = V_ID_SOLICITUD --V_ID_SOLICITUD = ultima solicitud donde participo el cliente, completada y sin cancelar.
                        AND CUSTOMER_NO_FCC = V_CUSTOMER_NO_FCC)
                        WHERE ID_SOLICITUD = IN_ID_SOLICITUD -- IN_ID_SOLICITUD = solicitud actual
                        AND CUSTOMER_NO_FCC = V_CUSTOMER_NO_FCC;

                        INSERT INTO BORRAR (x,y,FECHA) VALUES ('3. DESPUES DE UPDATE '|| V_ID_CUSTOMER || '-' || V_CUSTOMER_NO_FCC, ' CUSTOMER ANT. '||V_ID_CUSTOMER_ANT, systimestamp);

                        /***** Ult_FArauz 13Dic2011 - Se insertan los registros de los campos multiples de la ultima solicitud *****/
                        IF V_ID_CUSTOMER_ANT IS NOT NULL THEN
                            INSERT INTO WF_KCC_CAMPOS_MULTIPLES(ID_CAMPO, ID_TIPO_CAMPO, DESCRIPCION1, DESCRIPCION2, CUSTOMER_NO, ID_SOLICITUD)
                            SELECT ID_CAMPO, ID_TIPO_CAMPO, DESCRIPCION1, 
                            CASE WHEN ID_TIPO_CAMPO = 12 THEN (SELECT  COUNTRY_CODE  from STTM_COUNTRY@LINK_BPMBLFCC WHERE DESCRIPTION = DESCRIPCION1) ELSE
                            DESCRIPCION2 END, V_ID_CUSTOMER, IN_ID_SOLICITUD 
                            FROM WF_KCC_CAMPOS_MULTIPLES 
                            WHERE ID_SOLICITUD = V_ID_SOLICITUD AND 
                            CUSTOMER_NO = V_ID_CUSTOMER_ANT AND ID_TIPO_CAMPO <> 13;

                            --Eliminamos de la tabla campos multiples todos los paises que no tienen codigo.
                            DELETE WF_KCC_CAMPOS_MULTIPLES WHERE ID_TIPO_CAMPO = 12 AND ID_SOLICITUD = IN_ID_SOLICITUD AND CUSTOMER_NO = V_ID_CUSTOMER AND DESCRIPCION2 IS NULL;

                            SELECT REPLACE(FN_LMC_BUSCAR_COUN_WHERE_OFFER(IN_ID_SOLICITUD,V_ID_CUSTOMER),',',' ^ ') INTO V_COUNTRY_OFF_FUNC from dual;

                            UPDATE WF_KCC_CUSTOMER_INFO SET COUNTRIES_WHERE_OFFERS = substr(V_COUNTRY_OFF_FUNC,0,LENGTH(V_COUNTRY_OFF_FUNC)-3)
                            WHERE ID_SOLICITUD = IN_ID_SOLICITUD AND CUSTOMER_NO_FCC = V_CUSTOMER_NO_FCC;

                            --Llamamos el SP para insertar el checklist del cliente
                            BL_INSCHECKLIST_CUSTOMER(  
                            P_ID_SOLICITUD => IN_ID_SOLICITUD,
                            P_ID_PROCESO   => 2200,
                            P_CUSTOMER_NO  => V_ID_CUSTOMER,
                            P_TCHECK       => V_ID_SBP_CATEGORY,
                            OUT_RESULTADO  => V_OUT_RESULTADO
                            );

                            INSERT INTO BORRAR (x,y,FECHA) VALUES ('4. ANTES DE BUSCAR CLI ANT '|| V_ID_CUSTOMER || '-' || V_CUSTOMER_NO_FCC, ' CUSTOMER ANT. '||V_ID_CUSTOMER_ANT, systimestamp);

                            /***** Ult_FArauz 24Jul2012 - Se obtiene el ultimo customer no. del registro actual *****/  
                            SELECT CUSTOMER_NO INTO V_OLD_ID_CUSTOMER FROM WF_KCC_CUSTOMER_INFO 
                            WHERE CUSTOMER_NO_FCC = V_CUSTOMER_NO_FCC AND ID_SOLICITUD = V_ID_SOLICITUD;

                            INSERT INTO BORRAR (x,y,FECHA) VALUES ('5. ANTES DE CAMPOS MULT '|| V_ID_CUSTOMER || '-' || V_CUSTOMER_NO_FCC, ' CUSTOMER ANT. '||V_ID_CUSTOMER_ANT, systimestamp);

                            /*****Ult_FArauz 23Jul2012 - Se hace el llamado para insertar los campos multiples a las nuevas tablas *****/ 
                            BL_LMC_INSERT_CAMPOS_MULTIPLES(
                            IN_ID_SOLICITUD     =>  IN_ID_SOLICITUD,    --Solicitud actual
                            IN_ID_SOLICITUD_ANT =>  V_ID_SOLICITUD,     --Ultima solicitud del cliente actual
                            IN_CUSTOMER_NO      =>  V_ID_CUSTOMER,      --Customer no. del cliente actual
                            IN_CUSTOMER_NO_ANT  =>  V_OLD_ID_CUSTOMER,  --Customer no. del cliente en la ultima solicitud.
                            OUT_RESULTADO  => V_OUT_RESULTADO
                            );

                            --Se buscan las garantias que se ingresaron en la ultima solicitud valida del cliente
                            --INSERT INTO BORRAR (x,y,FECHA) VALUES ('6. SE BUSCAN LAS GARANTIAS '|| V_ID_SOLICITUD || '-' || V_CUSTOMER_NO_FCC, ' CUSTOMER ANT. '||V_ID_CUSTOMER_ANT, systimestamp);
                             
                             /*2019.07.30 bmg mejora 0000 -- se comenta esta seccion para cargar las garantias desde el maestro de garantias
                            INSERT INTO WF_LMT_GUARANTEES
                            ( ID_SOLICITUD, GUARANTEE_ID, NAME, TYPE_ID, EXP_DATE, MATRIXID, STATUS
                              ,CUSTOMER_ID, TRADE, NON_TRADE, LEASING
                              ,PRESTAMO, SINDICADO, VENDOR, TENOR, COVERAGE, NUEVA_ESTRUCTURA, CUSTOMER_NO_FCC
                            )
                            --Le colocamos status 4 para diferenciar que es una garantia que se esta cargando de la bd de ultimus
                            SELECT IN_ID_SOLICITUD, GUARANTEE_ID, NAME, TYPE_ID, EXP_DATE, MATRIXID, 1
                              ,CUSTOMER_ID, TRADE, NON_TRADE, LEASING
                              ,PRESTAMO, SINDICADO, VENDOR, TENOR, COVERAGE, 1, V_CUSTOMER_NO_FCC
                              FROM WF_LMT_GUARANTEES WHERE ID_SOLICITUD = V_ID_SOLICITUD AND STATUS <> 0 
                              AND NUEVA_ESTRUCTURA = 1 AND CUSTOMER_NO_FCC = V_CUSTOMER_NO_FCC;
                                */
                          
                            -- fin----
                            
                            INSERT INTO BORRAR (x,y,FECHA) VALUES ('7. DEPUES DE CAMPOS MULT '|| V_ID_CUSTOMER || '-' || V_CUSTOMER_NO_FCC, ' CUSTOMER ANT. '||V_ID_CUSTOMER_ANT, systimestamp);
                        END IF;
                    END IF;   
                    
                     begin   
                     INSERT INTO BORRAR (x,y,FECHA) VALUES('_sp_insert:BL_UPD_GUARANTEE_FROM_MASTER ' || '--' || IN_ID_SOLICITUD || '--' || V_CUSTOMER_NO_FCC, 'inicio:BL_UPD_GUARANTEE_FROM_MASTER' ,systimestamp);
                        -- inicio   ---Cargar Garantias desde el maestro
                        --2019.07.30 bmg mejora 000 --Cargar las garantias desde el maestro de garantias
                        BL_PK_GUARANTEE_MAINTENANCE.BL_UPD_GUARANTEE_FROM_MASTER(
                                IN_ID_PROCESO => 2200, --proceso de limit
                                IN_ID_SOLICITUD_NUEVO => IN_ID_SOLICITUD,
                                IN_CUSTOMER_NO_FCC => V_CUSTOMER_NO_FCC,
                                OUT_RESULTADO => V_OUT_RESULTADO
                              );
                     EXCEPTION 
                     WHEN OTHERS THEN
                              INSERT INTO BORRAR (x,y,FECHA) VALUES('EXCEPTION:BL_UPD_GUARANTEE_FROM_MASTER ' || '--' || IN_ID_SOLICITUD || '--' || V_CUSTOMER_NO_FCC, 'EXCEPTION:BL_UPD_GUARANTEE_FROM_MASTER' ,systimestamp);
                     end;

                END LOOP;
            CLOSE V_CUST_CURSOR_B;
          COMMIT;

        ELSE    
            --ULT_FArauz 11Nov2011 - Se valida para cuando el cliente a modificar no tiene un codigo de grupo economico.   
            --SELECT CUST.LIABILITY_NO INTO V_LIABILITY_NO FROM STTM_CUSTOMER@LINK_BPMBLFCC CUST WHERE CUST.CUSTOMER_NO = IN_CUSTOMER_NO_FCC; 

            INSERT INTO BORRAR (x,y,FECHA) VALUES ('1. NO ES KYC UPDATE ',NULL,  systimestamp);
            /*
            Aserrano 19 de Diciembre de 2011
            Se coloca este condicional cuando el proposito es 6 porque cuando se genera un incidente de actualizacion desde el monitoreo
            se insertan los clientes desde el WS de límites. 
            Con esto se borran los clientes y luego se buscan en BD.
            */
            IF IN_ID_PURPOSE  <> 1 THEN
              BEGIN
                DELETE FROM WF_KCC_CUSTOMER_INFO WHERE ID_SOLICITUD = IN_ID_SOLICITUD;
                COMMIT;
              END;
            END IF;      
            /***** Se abre el Cursor Customer con los clientes relacionados y se empieza a recorrer el mismo.  *****/
            OPEN V_CUST_CURSOR;
                LOOP   
                    FETCH V_CUST_CURSOR INTO V_CUSTOMER_NO_FCC, V_CUSTOMER_NAME1, V_CUST_LIABILITY_NO, V_GROUP_CODE, V_ID_MAIN_CUSTOMER;
                    EXIT WHEN V_CUST_CURSOR%NOTFOUND;

                    --INSERT INTO BORRAR (x,y,FECHA) VALUES ('2. ANTES DE INSERT '|| V_ID_CUSTOMER || '-' || V_CUSTOMER_NO_FCC, ' CUSTOMER ANT. '||V_ID_CUSTOMER_ANT,  systimestamp);

                    SELECT BL_SEQ_KCC_CUSTOMERS.NEXTVAL INTO V_ID_CUSTOMER FROM DUAL;

                    --// AHernandez - 00010144 SE AGREGA EL CUSTOMER_CLASSIFICATION_PEP

                    /***** Se busca en Flexcube parte del perfil del cliente y se inserta en WF_KCC_CUSTOMER_INFO  *****/ 
                    INSERT INTO WF_KCC_CUSTOMER_INFO (CUSTOMER_NO,         CUSTOMER_NAME1,       FULLNAME,               TAXIDNUMBER,
                    DV,                   INCORP_COUNTRYID,     INCORP_DATE,            RESIDENCECOUNTRY,
                    NATIONALITYID,        RESIDENCELOCATIONID,  LANGUAGEID,             EXPOSURE_COUNTRYID,
                    LOCATIONID,           PHYSICALALINE1,       PHYSICALALINE2,         PHYSICALALINE3,
                    POSTALALINE1,         POSTALALINE2,         POSTALALINE3,           POSTALACITY, 
                    TELEPHONENUMBER,      TELEPHONENUMBER2,     FAXNUMBER,              WEBSITE,                      
                    DEFAULT_MEDIA,        CUSTOMER_CATEGORY,    RELATIONTYPE,           ACCOUNT_OFFICERID,
                    INDUSTRY,             LEGALREPRESENTATIVE,  NAMEEXTERNALAUDITORS,   NAMEINTERNATIONALRISK,
                    NAMEOFECONOMICGROUP,  ECONOMICGROUPRUC,     BANKTYPE,               TYPEOFLICENCE,
                    SWIFT_CODE,           COMPLIANCEOFFICER,    ADDRESSPROCESSAGENTINUSA,
                    --ASerrano: 19May2016. El Aba code ya no se guardara en ultimus. Desde ahora este campo campo guardara
                    --de manera oculta el AML Rating que tiene el cliente en Flexcube
                    ABACODEVALUE, 
                    NY_AGENCY,            NETWORTH,               LIAB_ID,
                    SHORT_NAME,           GROUP_CODE,           ID_SOLICITUD,           CUSTOMER_NO_FCC,
                    RELACIONADO,          ID_MAIN_CUSTOMER,     MAIN_CUSTOMER,          EMAIL,
                    INTERNAL_CLASSIFICATION, CUSTOMER_TYPE, FECHA_KYC, INCEPTION_DATE, CUSTOMER_CLASSIFICATION_PEP, 
                    TIPO_DE_CLIENTE, MONITOREO_TRANSACCIONAL, INTERNAL_CONTROL
                    --, NEGATIVE_NEWS, SANCTIONS -- EStos valores no vienen de Flexcube
                    ,CO_COVENANTS           --2019.09.18 bmg ticket 16689 y 17569     
                    ,CO_DEUDOR_PRINCIPAL    --2019.09.18 bmg ticket 16689 y 17569
                    ,CHK_CONTR_APROB_VF     --2019.09.19 bmg ticket 16689 y 17569
                    ,CINU                   --2019.12.03 bmg ticket 00016775-CINU
                    ,CO_ESG_RATING   --OH Mar2021 Ticket#21170
                    ,DATE_ESG_RATING   --OH Mar2021 Ticket#21170    
                    ,CO_CLIENT_BETTER_COUNTRY   --OH 26Sep2022 Ticket 33103
                    ,CO_RISK_CUST_TYPE   --OH 26Sep2022 Ticket 33103
                    --,CO_RELATION_TYPE    --OH 26Sep2022 Ticket 33103   
                    ,CO_OFICINA_GESTION  -- ticket 32393 bmg 2023.04.10
                    ,PROBABILITY_DEFAULT -- hlee 31-07-23 Ticket 38841
                    ,LOSS_GIVEN_DEFAULT -- hlee 31-07-23 Ticket 38841
                    ,PROJECT_FINANCE -- hlee 31-07-23 Ticket 38841
                    )
                    SELECT V_ID_CUSTOMER,   
                    CUST.CUSTOMER_NAME1, --"Customer Name",  
                    Cust.Full_name, --"Legal or Commercial Name",   
                    CORP.C_NATIONAL_ID, --"Tax Identification Number",
                    Udf.Field_val_18, -- DV 
                    CORP.INCORP_COUNTRY, --INCORP_CNTRY, 
                    CORP.INCORP_DATE, --"Incorporation Date", 
                    CUST.COUNTRY, --RESIDENCE_CNTRY, 
                    CUST.NATIONALITY, --NationalityCod,      
                    CUST.LOC_CODE, --"ResidenceLocation", 
                    'ENG' LANGUAGE, --Languageid siempre es ingles,
                    Cust.Exposure_country, 
                    MITM.COMP_MIS_2, --"Location",
                    CORP.R_ADDRESS1, --"Physical Address Line1", --Physical Address
                    CORP.R_ADDRESS2, --"Physical Address Line2",   
                    CORP.R_ADDRESS3, --"Physical Address Line3",
                    --CUST.ADDRESS_LINE1, --"Postal Address Line1", -- Postal Address
                    --CUST.ADDRESS_LINE2, --"Postal Address Line2",   
                    --CUST.ADDRESS_LINE3, --"Postal Address Line3",  
                    --CUST.ADDRESS_LINE4, --"Postal Address City", -- Postal AddressCity 
                    CASE WHEN CUST.DEFAULT_MEDIA = 'FAX' OR CUST.DEFAULT_MEDIA = 'SWIFT' THEN
                    (SELECT ADDRESS1 FROM MSTM_CUST_ADDRESS@LINK_BPMBLFCC 
                     WHERE CUSTOMER_NO = CUST.CUSTOMER_NO AND MEDIA = 'MAIL' AND LOCATION = 'CIF' AND RECORD_STAT = 'O' AND AUTH_STAT = 'A')
                    ELSE CUST.ADDRESS_LINE1 END "Postal Address Line1", -- Postal Address

                    CASE WHEN CUST.DEFAULT_MEDIA = 'FAX' OR CUST.DEFAULT_MEDIA = 'SWIFT' THEN
                    (SELECT ADDRESS2 FROM MSTM_CUST_ADDRESS@LINK_BPMBLFCC
                     WHERE CUSTOMER_NO = CUST.CUSTOMER_NO AND MEDIA = 'MAIL' AND LOCATION = 'CIF' AND RECORD_STAT = 'O' AND AUTH_STAT = 'A')
                    ELSE CUST.ADDRESS_LINE2 END "Postal Address Line2", -- Postal Address

                    CASE WHEN CUST.DEFAULT_MEDIA = 'FAX' OR CUST.DEFAULT_MEDIA = 'SWIFT' THEN
                    (SELECT ADDRESS3 FROM MSTM_CUST_ADDRESS@LINK_BPMBLFCC 
                     WHERE CUSTOMER_NO = CUST.CUSTOMER_NO AND MEDIA = 'MAIL' AND LOCATION = 'CIF' AND RECORD_STAT = 'O' AND AUTH_STAT = 'A')
                    ELSE CUST.ADDRESS_LINE3 END "Postal Address Line3", -- Postal Address

                    CASE WHEN CUST.DEFAULT_MEDIA = 'FAX' OR CUST.DEFAULT_MEDIA = 'SWIFT' THEN
                    (SELECT ADDRESS4 FROM MSTM_CUST_ADDRESS@LINK_BPMBLFCC 
                     WHERE CUSTOMER_NO = CUST.CUSTOMER_NO AND MEDIA = 'MAIL' AND LOCATION = 'CIF' AND RECORD_STAT = 'O' AND AUTH_STAT = 'A')
                    ELSE CUST.ADDRESS_LINE4 END "Postal Address City", -- Postal Address

                    --CUST.UDF_2, --"Telephone Number", -- Telephone Number
                    CP.TELEPHONE "Telephone Number",
                    UDF.FIELD_VAL_19, --"2nd Telephone Number", --2nd Telephone Number
                    --CUST.FAX_NUMBER, --"Fax Number",
                    CP.FAX "Fax Number",
                    CUST.UDF_1, --"WebSite", -- Web Site
                    CUST.DEFAULT_MEDIA, --"Default Media",
                    CUST.CUSTOMER_CATEGORY, --"Customer Category",   
                    UDF.FIELD_VAL_8, --"Relation Type", -- Relation Type
                    (SELECT COMP_MIS_1  FROM   MITM_CUSTOMER_DEFAULT@LINK_BPMBLFCC WHERE CUSTOMER = CUST.CUSTOMER_NO), --"Account Officer",
                    MITM.CUST_MIS_1, --"Industry_code", --industry
                    UDF.FIELD_VAL_13, --"Legal Representative Name",
                    UDF.FIELD_VAL_14, --"Name of External Auditors", -- Name of external auditors
                    'MOODYS:' || UDF.FIELD_VAL_5 || ' SP:' || UDF.FIELD_VAL_3 || ' FITCH:' || UDF.FIELD_VAL_4,  --"Name Intl. Risk Rating Agency",
                    GRP.description, --"Name of Economic Group", -- Name of Economic Group
                    UDF.FIELD_VAL_6, --"Economic Group RUC", -- DV 
                    FN_LMC_BUSCA_BANKTYPE(UDF.FIELD_VAL_7),--UDF.FIELD_VAL_7, --"Bank Type", -- BANK TYPE                  
                    UDF.FIELD_VAL_9, --"Type of License", -- TYPE OF LICENCE
                    CUST.SWIFT_CODE, --"SWIFTCode", 
                    --CUST.unique_id_value, --"ABA Code Value",  
                    UDF.FIELD_VAL_11, --"Compliance Officer", -- COMPLIANCE OFFICER
                    UDF.FIELD_VAL_16, --"Name Process Agent In USA", -- NAME, ADDRESS OF PROCESS AGENT IN USA
                    UDF.FIELD_VAL_20, --"Aml Rating",
                    CASE
                    WHEN UDF.FIELD_VAL_32='YES' THEN '1'
                    WHEN UDF.FIELD_VAL_32='NO'THEN '0'
                    ELSE CASE WHEN CORP.INCORP_COUNTRY ='BR' OR CORP.INCORP_COUNTRY = 'ARG' THEN '1' ELSE '0' END
                    END, --"Can be used by NY Agency",
                    CORP.networth,
                    V_CUST_LIABILITY_NO, --CUST.LIABILITY_NO, 
                    CUST.SHORT_NAME, --"SHORT_NAME", 
                    V_GROUP_CODE, --GRP.GROUP_CODE,
                    IN_ID_SOLICITUD,
                    V_CUSTOMER_NO_FCC,
                    '1',  
                    UDF.FIELD_VAL_31, -- ID_MAIN_CUSTOMER
                    (CASE WHEN CUST.CUSTOMER_NO = V_ID_MAIN_CUSTOMER THEN 1 ELSE 0 END),
                    CP.E_MAIL,
                    (SELECT FIELD_VAL_1 FROM CSTMS_FUNCTION_USERDEF_FIELDS@LINK_BPMBLFCC WHERE REC_KEY = (CUST.CUSTOMER_NO||'~')),
                    /* --2019.10.09 bmg ticket 16689 y 17569
                    ( -- AH 20170809 - Agregado ya que para los clientes que no tienen solicitudes anterioes en el propósito de cancelación no se cargaba esta valor y fallaba la cancelación
                    SELECT 
                    case 
                        when cux.customer_segment = 'Companies' then 3
                        when cux.customer_segment = 'Corporate' then 1
                        when cux.customer_segment = 'FIN.INST' then 2
                        when cux.customer_segment = 'Individual' then 0
                        when cux.customer_segment = 'Soverign' then 2
                    end
                    FROM STTM_CUSTOMER_CAT_CU@LINK_BPMBLFCC CUX 
                    WHERE CUX.CUST_CAT =CUST.CUSTOMER_CATEGORY ),
                    */
                    ----- 2019.10.09 bmg ticket 16689 y 17569
                      case 
                        when UDF.FIELD_VAL_42 is null  then case upper(cust.customer_type)
                                                                 when 'C' then 1
                                                                 when 'B'  then 2
                                                            end
                        when UDF.FIELD_VAL_42 = '02'  then case upper(cust.customer_type)
                                                                 when 'C' then 4
                                                                 when 'B'  then 5
                                                            end
                        
                        when UDF.FIELD_VAL_42 = '07'  then  case upper(cust.customer_type)
                                                                 when 'C' then 6
                                                                 when 'B'  then 7
                                                            end                                                    
                        else  
                            -----
                            case upper(cust.customer_type)
                                     when 'C' then 1
                                     when 'B'  then 2
                            end
                            -----
                      end
                    ----- fin ticket 16689 y 17569
                    ,TO_DATE(UDF.FIELD_VAL_39, 'YYYY-MM-DD'), -- FECHA_KYC  -- // AHernandez - 00006793
	                TO_DATE(UDF.FIELD_VAL_40, 'YYYY-MM-DD'), -- INCEPTION_DATE  -- // AHernandez - 00006793
                    CASE TRIM(NVL(UDF.FIELD_VAL_41, 'N')) WHEN 'N' THEN '0' WHEN 'Y' THEN '1' ELSE '0'  END -- // AHernandez - 00010144
                    
                    ,UDF.FIELD_VAL_42--// AHernandez - 00013297
                    ,UDF.FIELD_VAL_43--// AHernandez - 00013297
                    ,UDF.FIELD_VAL_45--// AHernandez - 00013297
                    ,UDF.FIELD_VAL_46  --covenants 2019.09.18 bmg ticket 16689 y 17569
                    ,UDF.FIELD_VAL_48  --related customer 2019.09.18 bmg ticket 16689 y 17569
                    ,CASE UPPER(UDF.FIELD_VAL_36)
                        WHEN 'SI' THEN 1
                        WHEN 'NO' THEN 0
                        ELSE 0
                      END
                      ,UDF.FIELD_VAL_50  --2019.12.03 bmg ticket 00016775-CINU
                    -- OH Mar2021 Ticket#21170 - Campos para Rating ESG
                    ,UDF.FIELD_VAL_52    -- Código Rating ESG
                    ,TO_DATE(UDF.FIELD_VAL_53, 'YYYY-MM-DD')      -- Fecha de Rating ESG
                    -- OH 26Sep2022 Ticket#33103 - Campos nuevos para segmentación de clientes
                    ,UDF.FIELD_VAL_49    -- Cliente mejor que pais
                    ,UDF.FIELD_VAL_54    -- Tipo de Cliente Riesgo
                    --,UDF.FIELD_VAL_8    -- Relation Type                     
                    -- Fin Ticket
                    ,UDF.FIELD_VAL_47  -- ticket 32393 bmg 2023.04.10 OFICINA_DE_GESTION
                    ,UDF.FIELD_VAL_59  -- hlee 31-07-23 Ticket 38841
                    ,UDF.FIELD_VAL_60  -- hlee 31-07-23 Ticket 38841
                    ,CASE TRIM(NVL(UDF.FIELD_VAL_62, 'N')) WHEN 'N' THEN '0' WHEN 'Y' THEN '1' ELSE '0'  END-- hlee 31-07-23 Ticket 38841
                    FROM STTM_CUSTOMER@LINK_BPMBLFCC CUST
                    LEFT JOIN STTMS_CUST_CORPORATE@LINK_BPMBLFCC CORP ON CUST.CUSTOMER_NO = CORP.CUSTOMER_NO
                    LEFT JOIN CSTMS_FUNCTION_USERDEF_FIELDS@LINK_BPMBLFCC UDF ON CUST.CUSTOMER_NO = SUBSTR (UDF.REC_KEY, 1, 9) 
                    LEFT JOIN MITM_CUSTOMER_DEFAULT@LINK_BPMBLFCC MITM ON CUST.customer_no = MITM.CUSTOMER
                    LEFT JOIN sttm_group_code@LINK_BPMBLFCC GRP ON  CUST.group_code = GRP.group_code
                    LEFT JOIN STTMS_CUST_PERSONAL@LINK_BPMBLFCC CP ON CP.CUSTOMER_NO = CUST.CUSTOMER_NO
                    LEFT JOIN SMTB_LANGUAGE@LINK_BPMBLFCC LANG ON CUST.LANGUAGE = LANG.LANG_CODE
                    LEFT JOIN STTM_LOCATION@LINK_BPMBLFCC LOC  ON CUST.LOC_CODE = LOC.LOC_CODE   
                    LEFT JOIN STTM_COUNTRY@LINK_BPMBLFCC CNTR1 ON CORP.INCORP_COUNTRY = CNTR1.COUNTRY_CODE
                    LEFT JOIN STTM_COUNTRY@LINK_BPMBLFCC CNTR2 ON CUST.COUNTRY = CNTR2.COUNTRY_CODE
                    LEFT JOIN STTM_COUNTRY@LINK_BPMBLFCC CNTR3 ON CUST.NATIONALITY = CNTR3.COUNTRY_CODE
                    LEFT JOIN STTM_COUNTRY@LINK_BPMBLFCC CNTR4 ON CUST.EXPOSURE_COUNTRY = CNTR4.COUNTRY_CODE
                    LEFT JOIN GLTM_MIS_CODE@LINK_BPMBLFCC IND ON MITM.CUST_MIS_1 = IND.MIS_CODE
                    LEFT JOIN UDTM_LOV@LINK_BPMBLFCC UDFD ON UDF.FIELD_VAL_7 = UDFD.LOV AND  UDFD.FIELD_NAME = 'BANK_TYPE'    
                    LEFT JOIN WF_KCC_DFLT_MEDIA DEM ON CUST.DEFAULT_MEDIA = DEM.MEDIA
                    LEFT JOIN UDTM_LOV@LINK_BPMBLFCC UDFD2 ON UDF.FIELD_VAL_8 = UDFD2.LOV AND UDFD2.FIELD_NAME = 'RELATION_TYPE'
                    LEFT JOIN STTM_CUSTOMER_CAT@link_bpmblfcc CCAT ON CUST.CUSTOMER_CATEGORY = CCAT.CUST_CAT AND CCAT.record_stat = 'O' AND CCAT.auth_stat = 'A'
                    WHERE  (CUST.auth_stat = 'U'  OR CUST.auth_stat = 'A')
                    AND CUST.RECORD_STAT = 'O' 
                    AND CUST.CUSTOMER_NO = V_CUSTOMER_NO_FCC;

                    /***** Se busca la maxima Solicitud asociada al cliente por su CUSTOMER_NO_FCC.*****/
                    --SS-BUS-01  2018.07.18 bmg
                    SELECT COUNT(FN_LMC_LMT_ULTIMA_SOLICITUD(V_CUSTOMER_NO_FCC)) INTO V_CANTIDAD_SOL_ANT FROM DUAL;
                    IF V_CANTIDAD_SOL_ANT > 0 THEN
                      SELECT FN_LMC_LMT_ULTIMA_SOLICITUD(V_CUSTOMER_NO_FCC) INTO V_ID_SOLICITUD FROM DUAL;
                    ELSE
                      V_ID_SOLICITUD:=NULL;
                    END IF; 
                    
                    DBMS_OUTPUT.PUT_LINE(V_ID_SOLICITUD || '-' || V_CUSTOMER_NO_FCC);
                    /***** Si se encuentra solicitud asociada al cliente, se extraen los campos restantes que no estaban en Flexcube y se actualiza el  *****/
                    /***** registro de la nueva solicitud para ese cliente con dichos campos. *****/
                    IF V_ID_SOLICITUD IS NOT NULL THEN
                      DBMS_OUTPUT.PUT_LINE(V_ID_SOLICITUD || '-' || V_CUSTOMER_NO_FCC);
                        SELECT CUSTOMER_NO, SBP_CATEGORYID INTO V_ID_CUSTOMER_ANT, V_ID_SBP_CATEGORY FROM WF_KCC_CUSTOMER_INFO WHERE ID_SOLICITUD = V_ID_SOLICITUD AND CUSTOMER_NO_FCC = V_CUSTOMER_NO_FCC;

                        INSERT INTO BORRAR (x,y,FECHA) VALUES ('2. DESPUES DE INSERT '|| V_ID_CUSTOMER || '-' || V_CUSTOMER_NO_FCC || '-' || V_ID_SOLICITUD, ' CUSTOMER ANT. '||V_ID_CUSTOMER_ANT, systimestamp);                        

                         --// AHernandez - 00010144 SE QUITA EL CUSTOMER_CLASSIFICATION_PEP

                        UPDATE WF_KCC_CUSTOMER_INFO
                        SET (     SHAREHOLDER,               
                        PRODUCT_SERVICE_OFFERED,      RELATEDCOMPANIES,               NAME_ADDRESS_LEGAL_ADVISOR,     REFERENCE_BANKING_COMMERCIAL,   
                        NAME_OF_STOCK,                COUNTRIES_WHERE_OFFERS,         REGULATORY_AUTHORITY,
                        RELATEDACCOUNT,               CHK_SAMESHOLDERS_MAINCUST,      ID_EXISTE_FCC,                  SBP_CATEGORYID, 
                        DESCRIPCION_PEP,                INCORPORATION_PURPOSE,          SUB_ECOGR_CD,           LEGALREPRESENTATIVE_INFO, 
                        LAST_CHANGE_DATE,             DIGNATARIES,                    POWER_DEES,                     CHK_CREATE_FCC,         AUTHORIZED_SIGNATURES, 
                        RELATION_CORRESPONSAL,                                        SALES_MORE_30_PERCENT,          EXPORT_SHARE,           CUSTOMER_NO_FCC,
                        --CUSTOMER_TYPE, 2019.10.09 bmg ticket 16689 y 17569                
                        ID_CUSTOMER_FCC,                ID_SOLICITUD_LM,                ID_STATUS_FCC,          
                        AML_RATINGID_NY,
                        INTERNAL_CLASSIFICATION,      LIMIT_EXP_DATE,                 LMT_CUSTOMER_TYPE,              RISK_RATING,            PATRIOT_EXC_DATE,
                        NAMEOFECONOMICGROUP,          FAXNUMBER,                      FECHA_CREACION_CLIENTE,         PUBLIC_TRADE_COMP,       AML_EXC_DATE,
                        --Aserrano 22Abr2015
                        --Mojo 7643585 Se solicita agregar dos campos nuevos al formulario del KYC 
                        --para indicar si el cliente cumple con la ley FATCA                        
                        GIIN_NUMBER,                  W8_FORM_DATE,                   
                        AML_RATINGID
                        )= (SELECT  SHAREHOLDER,               
                        PRODUCT_SERVICE_OFFERED,      RELATEDCOMPANIES,               NAME_ADDRESS_LEGAL_ADVISOR,     REFERENCE_BANKING_COMMERCIAL,   
                        NAME_OF_STOCK,                COUNTRIES_WHERE_OFFERS,         REGULATORY_AUTHORITY,
                        RELATEDACCOUNT,               CHK_SAMESHOLDERS_MAINCUST,      1,                              SBP_CATEGORYID, 
                        DESCRIPCION_PEP,                INCORPORATION_PURPOSE,          SUB_ECOGR_CD,           LEGALREPRESENTATIVE_INFO, 
                        LAST_CHANGE_DATE,             DIGNATARIES,                    POWER_DEES,                     0,                      AUTHORIZED_SIGNATURES, 
                        RELATION_CORRESPONSAL,                                        SALES_MORE_30_PERCENT,          EXPORT_SHARE,           CUSTOMER_NO_FCC, 
                        --CUSTOMER_TYPE, 2019.10.09 bmg ticket 16689 y 17569               
                        ID_CUSTOMER_FCC,                ID_SOLICITUD_LM,                1,
                        (SELECT CASE WHEN UDF.FIELD_VAL_32='YES' THEN UDF.FIELD_VAL_20 ELSE NULL END 
                        FROM CSTMS_FUNCTION_USERDEF_FIELDS@LINK_BPMBLFCC UDF WHERE SUBSTR (UDF.REC_KEY, 1, 9) =  CUSTOMER_NO_FCC) AML_RATINGID_NY,
                        INTERNAL_CLASSIFICATION,      LIMIT_EXP_DATE,                 LMT_CUSTOMER_TYPE,              RISK_RATING,            PATRIOT_EXC_DATE,
                        NAMEOFECONOMICGROUP,          FAXNUMBER,                      FECHA_CREACION_CLIENTE,         PUBLIC_TRADE_COMP,      AML_EXC_DATE,
                        GIIN_NUMBER,                  W8_FORM_DATE,                   

                        (SELECT CASE WHEN UDF.FIELD_VAL_32='NO' THEN UDF.FIELD_VAL_20 ELSE NULL END 
                        FROM CSTMS_FUNCTION_USERDEF_FIELDS@LINK_BPMBLFCC UDF WHERE SUBSTR (UDF.REC_KEY, 1, 9) =  CUSTOMER_NO_FCC) AML_RATINGID

                        FROM WF_KCC_CUSTOMER_INFO 
                        WHERE ID_SOLICITUD = V_ID_SOLICITUD --V_ID_SOLICITUD = ultima solicitud donde participo el cliente, completada y sin cancelar.
                        AND CUSTOMER_NO_FCC = V_CUSTOMER_NO_FCC)
                        WHERE ID_SOLICITUD = IN_ID_SOLICITUD -- IN_ID_SOLICITUD = solicitud actual
                        AND CUSTOMER_NO_FCC = V_CUSTOMER_NO_FCC;

                        INSERT INTO BORRAR (x,y,FECHA) VALUES ('3. DESPUES DE UPDATE '|| V_ID_CUSTOMER || '-' || V_CUSTOMER_NO_FCC, ' CUSTOMER ANT. '||V_ID_CUSTOMER_ANT, systimestamp);

                        /***** Ult_FArauz 13Dic2011 - Se insertan los registros de los campos multiples de la ultima solicitud *****/
                        IF V_ID_CUSTOMER_ANT IS NOT NULL THEN
                            INSERT INTO WF_KCC_CAMPOS_MULTIPLES(ID_CAMPO, ID_TIPO_CAMPO, DESCRIPCION1, DESCRIPCION2, CUSTOMER_NO, ID_SOLICITUD)
                            SELECT ID_CAMPO, ID_TIPO_CAMPO, DESCRIPCION1, 
                            CASE WHEN ID_TIPO_CAMPO = 12 THEN (SELECT  COUNTRY_CODE  from STTM_COUNTRY@LINK_BPMBLFCC WHERE DESCRIPTION = DESCRIPCION1) ELSE
                            DESCRIPCION2 END, V_ID_CUSTOMER, IN_ID_SOLICITUD 
                            FROM WF_KCC_CAMPOS_MULTIPLES 
                            WHERE ID_SOLICITUD = V_ID_SOLICITUD AND 
                            CUSTOMER_NO = V_ID_CUSTOMER_ANT AND ID_TIPO_CAMPO <> 13;

                            --Eliminamos de la tabla campos multiples todos los paises que no tienen codigo.
                            DELETE WF_KCC_CAMPOS_MULTIPLES WHERE ID_TIPO_CAMPO = 12 AND ID_SOLICITUD = IN_ID_SOLICITUD AND CUSTOMER_NO = V_ID_CUSTOMER AND DESCRIPCION2 IS NULL;

                            SELECT REPLACE(FN_LMC_BUSCAR_COUN_WHERE_OFFER(IN_ID_SOLICITUD,V_ID_CUSTOMER),',',' ^ ') INTO V_COUNTRY_OFF_FUNC from dual;

                            UPDATE WF_KCC_CUSTOMER_INFO SET COUNTRIES_WHERE_OFFERS = substr(V_COUNTRY_OFF_FUNC,0,LENGTH(V_COUNTRY_OFF_FUNC)-3)
                            WHERE ID_SOLICITUD = IN_ID_SOLICITUD AND CUSTOMER_NO_FCC = V_CUSTOMER_NO_FCC;

                            --INSERT INTO BORRAR (x,y) VALUES ('ANTES DE CHECKLIST '|| V_ID_CUSTOMER || '-' || V_CUSTOMER_NO_FCC, ' CUSTOMER ANT. '||V_ID_CUSTOMER_ANT);
                            BL_INSCHECKLIST_CUSTOMER(  
                            P_ID_SOLICITUD => IN_ID_SOLICITUD,
                            P_ID_PROCESO   => 2200,
                            P_CUSTOMER_NO  => V_ID_CUSTOMER,
                            P_TCHECK       => V_ID_SBP_CATEGORY,
                            OUT_RESULTADO  => V_OUT_RESULTADO
                            );

                            INSERT INTO BORRAR (x,y,FECHA) VALUES ('4. ANTES DE BUSCAR CLI ANT '|| V_ID_CUSTOMER || '-' || V_CUSTOMER_NO_FCC, ' CUSTOMER ANT. '||V_ID_CUSTOMER_ANT, systimestamp);

                            /***** Ult_FArauz 24Jul2012 - Se obtiene el ultimo customer no. del registro actual *****/  
                            SELECT CUSTOMER_NO INTO V_OLD_ID_CUSTOMER FROM WF_KCC_CUSTOMER_INFO 
                            WHERE CUSTOMER_NO_FCC = V_CUSTOMER_NO_FCC AND ID_SOLICITUD = V_ID_SOLICITUD;

                            INSERT INTO BORRAR (x,y,FECHA) VALUES ('5. ANTES DE CAMPOS MULT '|| V_ID_CUSTOMER || '-' || V_CUSTOMER_NO_FCC, ' CUSTOMER ANT. '||V_ID_CUSTOMER_ANT, systimestamp);

                            /*****Ult_FArauz 23Jul2012 - Se hace el llamado para insertar los campos multiples a las nuevas tablas *****/ 
                            BL_LMC_INSERT_CAMPOS_MULTIPLES(
                            IN_ID_SOLICITUD     =>  IN_ID_SOLICITUD,    --Solicitud actual
                            IN_ID_SOLICITUD_ANT =>  V_ID_SOLICITUD,     --Ultima solicitud del cliente actual
                            IN_CUSTOMER_NO      =>  V_ID_CUSTOMER,      --Customer no. del cliente actual
                            IN_CUSTOMER_NO_ANT  =>  V_OLD_ID_CUSTOMER,  --Customer no. del cliente en la ultima solicitud.
                            OUT_RESULTADO  => V_OUT_RESULTADO
                            );
                            
                            /*2019.07.30 bmg mejora 0000 -- se comenta esta seccion para cargar las garantias desde el maestro de garantias
                            -- AH - 20170613 - agregado para limpiar la tabla antes de cargar las garantías
                            DELETE WF_LMT_GUARANTEES where ID_SOLICITUD = IN_ID_SOLICITUD and CUSTOMER_NO_FCC = V_CUSTOMER_NO_FCC;
                             */
                             
                            --Se buscan las garantias que se ingresaron en la ultima solicitud valida del cliente
                            --INSERT INTO BORRAR (x,y,FECHA) VALUES ('6. SE BUSCAN LAS GARANTIAS '|| V_ID_SOLICITUD || '-' || V_CUSTOMER_NO_FCC, ' CUSTOMER ANT. '||V_ID_CUSTOMER_ANT, systimestamp);
                             
                             /*2019.07.30 bmg mejora 0000 -- se comenta esta seccion para cargar las garantias desde el maestro de garantias
                            INSERT INTO WF_LMT_GUARANTEES
                            ( ID_SOLICITUD, GUARANTEE_ID, NAME, TYPE_ID, EXP_DATE, MATRIXID, STATUS
                              ,CUSTOMER_ID, TRADE, NON_TRADE, LEASING
                              ,PRESTAMO, SINDICADO, VENDOR, TENOR, COVERAGE, NUEVA_ESTRUCTURA, CUSTOMER_NO_FCC
                            )
                            --Le colocamos status 4 para diferenciar que es una garantia que se esta cargando de la bd de ultimus
                            SELECT IN_ID_SOLICITUD, GUARANTEE_ID, NAME, TYPE_ID, EXP_DATE, MATRIXID, 1
                              ,CUSTOMER_ID, TRADE, NON_TRADE, LEASING
                              ,PRESTAMO, SINDICADO, VENDOR, TENOR, COVERAGE, 1, V_CUSTOMER_NO_FCC
                              FROM WF_LMT_GUARANTEES WHERE ID_SOLICITUD = V_ID_SOLICITUD AND STATUS <> 0 
                              AND NUEVA_ESTRUCTURA = 1 AND CUSTOMER_NO_FCC = V_CUSTOMER_NO_FCC;
                            */
                           
                            
                            INSERT INTO BORRAR (x,y,FECHA) VALUES ('7. DEPUES DE CAMPOS MULT '|| V_ID_CUSTOMER || '-' || V_CUSTOMER_NO_FCC, ' CUSTOMER ANT. '||V_ID_CUSTOMER_ANT, systimestamp);

                        END IF;
                    END IF;
                    
                    -- inicio   ---Cargar Garantias desde el maestro
                    --2019.07.30 bmg mejora 000 --Cargar las garantias desde el maestro de garantias
                    begin
                    INSERT INTO BORRAR (x,y,FECHA) VALUES('_sp_insert:BL_UPD_GUARANTEE_FROM_MASTER ' || '--' || IN_ID_SOLICITUD || '--' || V_CUSTOMER_NO_FCC, 'inicio:BL_UPD_GUARANTEE_FROM_MASTER' ,systimestamp);
                            BL_PK_GUARANTEE_MAINTENANCE.BL_UPD_GUARANTEE_FROM_MASTER(
                                IN_ID_PROCESO => 2200, --proceso de limit
                                IN_ID_SOLICITUD_NUEVO => IN_ID_SOLICITUD,
                                IN_CUSTOMER_NO_FCC => V_CUSTOMER_NO_FCC,
                                OUT_RESULTADO => V_OUT_RESULTADO
                              );
                             DBMS_OUTPUT.PUT_LINE(V_ID_SOLICITUD || '-' || V_CUSTOMER_NO_FCC);
                        EXCEPTION 
                        WHEN OTHERS THEN
                            INSERT INTO BORRAR (x,y,FECHA) VALUES('EXCEPTION:BL_UPD_GUARANTEE_FROM_MASTER ' || '--' || IN_ID_SOLICITUD || '--' || V_CUSTOMER_NO_FCC, 'EXCEPTION:BL_UPD_GUARANTEE_FROM_MASTER' ,systimestamp);
                    end;
                            -- fin----
                END LOOP;
            CLOSE V_CUST_CURSOR;
          COMMIT;
    END IF;  

    /*Se buscan e ingresan los Share Holders, Directores, Alta Gerencia de la ultima solicitud completada*/
    INSERT INTO BORRAR (x,y,FECHA) VALUES ('8. ANTES DE LLAMAR ALTA GERENCIA '|| IN_ID_SOLICITUD || '-' || V_CUSTOMER_NO_FCC, ' CUSTOMER ANT. '||V_ID_CUSTOMER_ANT, systimestamp);
    BL_LMC_LLAMA_SH_TOP_MANAG_VAL(
    IN_ID_SOLICITUD => IN_ID_SOLICITUD,
    OUT_RESULTADO => V_OUT_RESULTADO
    );

    /*Se buscan e ingresan los documentos de la ultima solicitud completada */
    INSERT INTO BORRAR (x,y,FECHA) VALUES ('9. ANTES DE LLAMAR ADJUNTOS '|| IN_ID_SOLICITUD || '-' || IN_USUARIO, ' CUSTOMER ANT. '||V_ID_CUSTOMER_ANT, systimestamp);
    BL_LMC_LLAMA_BUSCA_ADJUNTOS_CL(
    IN_ID_SOLICITUD => IN_ID_SOLICITUD,
    IN_USUARIO => IN_USUARIO,
    OUT_RESULTADO => V_OUT_RESULTADO
    );

    --// AHernandez - 00010144
    BEGIN
      BL_LMC_QUITA_PEP(
        IN_ID_SOLICITUD => IN_ID_SOLICITUD,
        OUT_RESULTADO => OUT_RESULTADO
      );
        EXCEPTION WHEN OTHERS THEN
          S_ERROR := 'Error in BL_LMC_CUST_INFO_INSERT: '|| SQLERRM;
    END ;
    --// AHernandez - 00010144

    EXCEPTION WHEN OTHERS THEN
    S_ERROR := 'Error in BL_LMC_CUST_INFO_INSERT: '|| SQLERRM;
    INSERT INTO BORRAR (X,Y,fecha) VALUES ('10. COD CLIENTE: '|| V_ID_CUSTOMER || '-' || V_CUSTOMER_NO_FCC || ' SOLICITUD ANTERIOR: '|| V_ID_SOLICITUD || ' SOLICITUD ACTUAL: '||IN_ID_SOLICITUD, S_ERROR,  systimestamp);

    OPEN OUT_RESULTADO FOR
      --SELECT 'REGISTROS INSERTADOS' RESULTADO
      SELECT V_ID_SOLICITUD RESULTADO
      FROM DUAL;

END BL_LMC_CUST_INFO_INSERT;

/
