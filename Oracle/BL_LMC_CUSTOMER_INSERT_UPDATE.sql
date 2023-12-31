create or replace PROCEDURE                 "BL_LMC_CUSTOMER_INSERT_UPDATE"
(  --ULT_FArauz 12Octubre2011 - Se crea nuevo procedimiento almacenado para sea utilizado exclusivo en el nuevo proceso.
   --Limit and Custom Recomendation.. es una copia del SP "BL_KCC_CUSTOMER_INSERT_UPDATE2"
  IN_CUSTOMER_NO IN NUMBER DEFAULT NULL                   , IN_SHAREHOLDER IN NUMBER DEFAULT NULL
, IN_FULLNAME IN VARCHAR2 DEFAULT NULL                    , IN_TAXIDNUMBER IN VARCHAR2 DEFAULT NULL
, IN_CUSTOMER_TYPE  IN NUMBER DEFAULT NULL                , IN_CUSTOMER_NAME1 IN VARCHAR2 DEFAULT NULL
, IN_DV IN VARCHAR2 DEFAULT NULL                          , IN_CUSTOMER_CATEGORY IN VARCHAR2 DEFAULT NULL
, IN_RELATIONTYPE IN VARCHAR2 DEFAULT NULL                , IN_INDUSTRY IN VARCHAR2 DEFAULT NULL
, IN_NAMEOFECONOMICGROUP IN VARCHAR2 DEFAULT NULL         , IN_LEGALREPRESENTATIVE IN VARCHAR2 DEFAULT NULL
, IN_NAMEEXTERNALAUDITORS IN VARCHAR2 DEFAULT NULL        , IN_NAMEINTERNATIONALRISK IN VARCHAR2 DEFAULT NULL
, IN_POSTALALINE1 IN VARCHAR2 DEFAULT NULL                , IN_POSTALALINE2 IN VARCHAR2 DEFAULT NULL
, IN_POSTALALINE3 IN VARCHAR2 DEFAULT NULL                , IN_POSTALACITY IN VARCHAR2 DEFAULT NULL
, IN_PHYSICALALINE1 IN VARCHAR2 DEFAULT NULL              , IN_PHYSICALALINE2 IN VARCHAR2 DEFAULT NULL

, IN_PHYSICALALINE3 IN VARCHAR2 DEFAULT NULL              , IN_TELEPHONENUMBER IN VARCHAR2 DEFAULT NULL
, IN_TELEPHONENUMBER2 IN VARCHAR2 DEFAULT NULL            , IN_FAXNUMBER IN VARCHAR2 DEFAULT NULL
, IN_WEBSITE IN VARCHAR2 DEFAULT NULL                     , IN_DEFAULT_MEDIA IN VARCHAR2 DEFAULT NULL
, IN_INCORP_COUNTRYID IN VARCHAR2 DEFAULT NULL            , IN_INCORP_DATE IN VARCHAR2 DEFAULT NULL
, IN_RESIDENCECOUNTRY IN VARCHAR2 DEFAULT NULL            , IN_NATIONALITYID IN VARCHAR2 DEFAULT NULL
, IN_RESIDENCELOCATIONID IN VARCHAR2 DEFAULT NULL         , IN_LANGUAGEID IN VARCHAR2 DEFAULT NULL
, IN_BANKTYPE IN VARCHAR2 DEFAULT 'NA'                    , IN_TYPEOFLICENCE IN VARCHAR2 DEFAULT 'NA'
, IN_SWIFT_CODE IN VARCHAR2 DEFAULT NULL                  , IN_ABACODEVALUE IN VARCHAR2 DEFAULT NULL
, IN_COMPLIANCEOFFICER IN VARCHAR2 DEFAULT 'NA'           , IN_USA_PROCESS_AGENT IN VARCHAR2 DEFAULT 'NA'
, IN_NETWORTH IN VARCHAR2 DEFAULT 0                       , IN_EXPOSURE_COUNTRYID IN VARCHAR2 DEFAULT NULL
, IN_INCEPTION_DATE IN VARCHAR2 DEFAULT NULL              , IN_PRODUCT_SERVICE_OFFERED IN VARCHAR2 DEFAULT NULL
, IN_RELATEDCOMPANIES IN VARCHAR2 DEFAULT NULL
, IN_RELATEDACCOUNT  IN VARCHAR2 DEFAULT NULL             , IN_EMAIL IN VARCHAR2 DEFAULT NULL

, IN_NAME_ADDRESS_LEGAL_ADVISORS IN VARCHAR2 DEFAULT 'NA' , IN_REFERENCE_BANKING_COMME IN VARCHAR2 DEFAULT NULL
, IN_NAME_OF_STOCK IN VARCHAR2 DEFAULT NULL               , IN_COUNTRIES_WHERE_OFFERS IN VARCHAR2 DEFAULT NULL
, IN_REGULATORY_AUTHORITY IN VARCHAR2 DEFAULT NULL        , IN_MAIN_CUSTOMER IN NUMBER DEFAULT NULL
, IN_ID_SOLICITUD   IN VARCHAR2 DEFAULT NULL  			      , IN_CUSTOMER_NO_FCC IN VARCHAR2 DEFAULT NULL
, IN_SHORT_NAME  IN VARCHAR2 DEFAULT NULL  				        , IN_LIAB_ID	IN VARCHAR2 DEFAULT NULL
, IN_GROUP_CODE  IN VARCHAR2 DEFAULT NULL
, IN_ID_SOLICITUD_LM IN VARCHAR2 DEFAULT NULL             , IN_SUB_ECOGR_CD IN VARCHAR2 DEFAULT NULL
, IN_ECONOMICGROUPRUC IN VARCHAR2 DEFAULT NULL            , IN_CHK_CREATE_FCC IN VARCHAR2 DEFAULT NULL
, IN_CHK_SAMESHOLDERS_MAINCUST IN VARCHAR2 DEFAULT NULL   , IN_ACCOUNT_OFFICERID IN VARCHAR2 DEFAULT NULL
, IN_LOCATIONID IN VARCHAR2 DEFAULT NULL                  , IN_AML_RATINGID  IN VARCHAR2 DEFAULT NULL
, IN_NY_AGENCY IN VARCHAR2 DEFAULT NULL                   , IN_SBP_CATEGORYID IN NUMBER DEFAULT NULL
, IN_CUSTOMER_CLASSIFICATION_PEP IN VARCHAR2 DEFAULT NULL , IN_DESCRIPCION_PEP IN VARCHAR2 DEFAULT NULL
, IN_INCORPORATION_PURPOSE IN VARCHAR2 DEFAULT NULL       , IN_LEGALREPRESENTATIVE_INFO IN VARCHAR2 DEFAULT NULL

, IN_DIGNATARIES IN VARCHAR2 DEFAULT NULL                 , IN_POWER_DEES IN VARCHAR2 DEFAULT NULL
, IN_AUTHORIZED_SIGNATURES IN VARCHAR2 DEFAULT NULL       , IN_RELATION_CORRESPONSAL IN NUMBER DEFAULT NULL
, IN_SALES_MORE_30_PERCENT IN VARCHAR2 DEFAULT NULL       , IN_EXPORT_SHARE IN NUMBER DEFAULT NULL
--Ult_FArauz 12Octubre2011 - Se agregan nuevos parametros al SP para este proceso LMC, los campos CHK_CREATE_LIMIT y IN_RELACIONADO
--fueron creados antes de este cambio y no los habian agregado. Se estan incluyendo con estos cambios para enviar los parametros completos.
, IN_CHK_CREATE_LIMIT IN NUMBER DEFAULT NULL              , IN_RELACIONADO IN VARCHAR2 DEFAULT NULL
, IN_AML_RATINGID_NY IN VARCHAR2 DEFAULT NULL             , IN_FLAG_EXCEPTION IN VARCHAR2 DEFAULT NULL
, IN_PUBLIC_TRADE_COMP IN NUMBER DEFAULT NULL             , IN_PATRIOT_EXC_DATE IN VARCHAR2 DEFAULT NULL
, IN_AML_EXC_DATE IN VARCHAR2 DEFAULT NULL
--Fin Ult_FArauz 12Octubre2011

--Aserrano 22Abr2015
--Mojo 7643585 Se solicita agregar dos campos nuevos al formulario del KYC para indicar si el cliente cumple con la ley FATCA
, IN_GIIN_NUMBER IN VARCHAR2 DEFAULT NULL                 , IN_W8_FORM_DATE IN VARCHAR2 DEFAULT NULL
-- AHernandez -- Ticket - 00006793 
, IN_FECHA_KYC   IN VARCHAR2 DEFAULT NULL
--// AHernandez - 00013297
,IN_TIPO_DE_CLIENTE IN VARCHAR2 DEFAULT NULL
,IN_INTERNAL_CONTROL IN VARCHAR2 DEFAULT NULL
--,IN_NEGATIVE_NEWS IN VARCHAR2 DEFAULT NULL
--,IN_SANCTIONS IN VARCHAR2 DEFAULT NULL
--// AHernandez - 00013297

--2019.09.12 bmg ticket 16689 y 17569
,IN_CO_COVENANTS in VARCHAR2 DEFAULT NULL
,IN_CO_DEUDOR_PRINCIPAL in VARCHAR2 DEFAULT NULL
,IN_CHK_CONTR_APROB_VF IN NUMBER DEFAULT NULL
-- fin 16689 y 17569
,IN_CINU IN VARCHAR2 DEFAULT NULL -- 2019.11.26 bmg  ticket 00016775-CINU
,IN_CO_OFICINA_GESTION IN VARCHAR2 DEFAULT NULL --ticket 32393 bmg 2023.04.04
,IN_GROUP_EXPIRATION_MONTH IN NUMBER DEFAULT NULL -- HLEE - 30-08-2023 Ticket 38930
, out_RESULTADO OUT SYS_REFCURSOR
) AS


V_CANT_REG        NUMBER;
V_CUSTOMER_NO_ID  NUMBER;
V_IDENTITY        NUMBER;
V_EXISTE_FCC      CHAR(1):= '0';
V_OUT_CANTIDAD    NUMBER:=0;

BEGIN
  SELECT count(CUSTOMER_NO) into v_CANT_REG FROM WF_KCC_CUSTOMER_INFO WHERE
  (CUSTOMER_NO = IN_CUSTOMER_NO OR  customer_no_fcc = IN_CUSTOMER_NO_FCC ) AND
  ID_SOLICITUD = in_ID_SOLICITUD;

  -- EN CASO DE QUE SE HAYA SELECCIONADO COMO MAIN CUSTOMER ENTONCES SE DEBE COLOCAR TODOS LOS OTROS
  -- CLIENTES COMO CLIENTES SECUNDARIOS


  --INSERT INTO BORRAR (X, Y) VALUES ('CLIENTE '|| IN_CUSTOMER_NAME1, 'CLIENTE PRINCIPAL '||in_MAIN_CUSTOMER);
  --IF in_MAIN_CUSTOMER = 1 THEN

    --UPDATE WF_KCC_CUSTOMER_INFO
    --SET MAIN_CUSTOMER = 0
    --WHERE ID_SOLICITUD = in_ID_SOLICITUD AND MAIN_CUSTOMER IS NULL;

  --END IF;
 --MS.Validacion que indica si el cliente existe en FCC
   IF IN_CUSTOMER_NO_FCC IS NOT NULL THEN

        SELECT COUNT(CUSTOMER_NO) INTO V_OUT_CANTIDAD

        FROM STTM_CUSTOMER@LINK_BPMBLFCC
        WHERE CUSTOMER_NO  = IN_CUSTOMER_NO_FCC;

        IF V_OUT_CANTIDAD > 0 THEN
          V_EXISTE_FCC := '1';
        END IF ;

  END IF;

  IF V_CANT_REG = 0  THEN

  SELECT BL_SEQ_KCC_CUSTOMERS.NEXTVAL INTO v_CUSTOMER_NO_ID FROM DUAL;


    INSERT INTO WF_KCC_CUSTOMER_INFO
    (
      CUSTOMER_NO,            SHAREHOLDER,                  CUSTOMER_TYPE,          CUSTOMER_NAME1,
      FULLNAME,               TAXIDNUMBER,
      DV,                     CUSTOMER_CATEGORY,            RELATIONTYPE,           INDUSTRY,
      NAMEOFECONOMICGROUP,    LEGALREPRESENTATIVE,          NAMEEXTERNALAUDITORS,   NAMEINTERNATIONALRISK,
      POSTALALINE1,           POSTALALINE2,                 POSTALALINE3,           POSTALACITY,
      PHYSICALALINE1,         PHYSICALALINE2,               PHYSICALALINE3,         TELEPHONENUMBER,
      TELEPHONENUMBER2,       FAXNUMBER,                    WEBSITE,                DEFAULT_MEDIA,
      INCORP_COUNTRYID,       INCORP_DATE,
      RESIDENCECOUNTRY,       NATIONALITYID,
      RESIDENCELOCATIONID,    LANGUAGEID,                    BANKTYPE,               TYPEOFLICENCE,
      SWIFT_CODE,             ABACODEVALUE,                 COMPLIANCEOFFICER,      ADDRESSPROCESSAGENTINUSA,

      NETWORTH,               EXPOSURE_COUNTRYID,           INCEPTION_DATE,         PRODUCT_SERVICE_OFFERED,
      RELATEDCOMPANIES,       EMAIL,                        NAME_ADDRESS_LEGAL_ADVISOR,
      REFERENCE_BANKING_COMMERCIAL,                         NAME_OF_STOCK,          COUNTRIES_WHERE_OFFERS,
      REGULATORY_AUTHORITY,   RELATEDACCOUNT,               MAIN_CUSTOMER,          ID_SOLICITUD,
      CUSTOMER_NO_FCC,		    SHORT_NAME,					          LIAB_ID,				        GROUP_CODE,
      ID_SOLICITUD_LM,        SUB_ECOGR_CD,                 ECONOMICGROUPRUC,       LAST_CHANGE_DATE,
      CHK_CREATE_FCC,         CHK_SAMESHOLDERS_MAINCUST,    ID_EXISTE_FCC,          LIMIT_EXP_DATE,
      ACCOUNT_OFFICERID,      LOCATIONID,                   AML_RATINGID,           NY_AGENCY,
      SBP_CATEGORYID,         CUSTOMER_CLASSIFICATION_PEP,  DESCRIPCION_PEP,        INCORPORATION_PURPOSE,
      LEGALREPRESENTATIVE_INFO, DIGNATARIES,                POWER_DEES,             AUTHORIZED_SIGNATURES,
      RELATION_CORRESPONSAL,  LMT_CUSTOMER_TYPE,            SALES_MORE_30_PERCENT,  EXPORT_SHARE,
      PUBLIC_TRADE_COMP,      PATRIOT_EXC_DATE,             AML_EXC_DATE,           GIIN_NUMBER,
      W8_FORM_DATE, FECHA_KYC
      ,INTERNAL_CONTROL,CO_COVENANTS,CO_DEUDOR_PRINCIPAL,CHK_CONTR_APROB_VF  --2019.09.18 bmg ticket 16689 y 17569
      ,CINU --2019.1126 bmg ticket 00016775-CINU
      ,CO_OFICINA_GESTION --ticket 32393 bmg 2023.04.04
      ,GROUP_EXPIRATION_MONTH-- HLEE - 30-08-2023 Ticket 38930
    )

    VALUES
    (
      v_CUSTOMER_NO_ID              ,IN_SHAREHOLDER                 ,in_CUSTOMER_TYPE               ,UPPER(in_CUSTOMER_NAME1)
      ,UPPER(in_FULLNAME)           ,in_TAXIDNUMBER
      ,in_DV                        ,UPPER(in_CUSTOMER_CATEGORY)    ,in_RELATIONTYPE                ,in_INDUSTRY
      ,UPPER(in_NAMEOFECONOMICGROUP),UPPER(in_LEGALREPRESENTATIVE)  ,UPPER(in_NAMEEXTERNALAUDITORS) ,in_NAMEINTERNATIONALRISK
      ,UPPER(in_POSTALALINE1)       ,UPPER(in_POSTALALINE2)         ,UPPER(in_POSTALALINE3)         ,UPPER(in_POSTALACITY)
      ,UPPER(in_PHYSICALALINE1)     ,UPPER(in_PHYSICALALINE2)       ,in_PHYSICALALINE3              ,UPPER(in_TELEPHONENUMBER)
      ,in_TELEPHONENUMBER2          ,in_FAXNUMBER                   ,in_WEBSITE                     ,in_DEFAULT_MEDIA
      ,in_INCORP_COUNTRYID          ,TO_DATE(in_INCORP_DATE, 'dd/mm/yyyy')
      ,in_RESIDENCECOUNTRY          ,in_NATIONALITYID
      ,in_RESIDENCELOCATIONID       ,in_LANGUAGEID                  ,in_BANKTYPE             ,in_TYPEOFLICENCE
      ,in_SWIFT_CODE                ,in_ABACODEVALUE                ,UPPER(in_COMPLIANCEOFFICER)    ,in_USA_PROCESS_AGENT
      ,in_NETWORTH                  ,in_EXPOSURE_COUNTRYID          ,TO_DATE(in_INCEPTION_DATE, 'dd/mm/yyyy')
      ,UPPER(in_PRODUCT_SERVICE_OFFERED)
      ,UPPER(in_RELATEDCOMPANIES)   ,UPPER(in_EMAIL)                ,UPPER(in_NAME_ADDRESS_LEGAL_ADVISORS)
      ,UPPER(in_REFERENCE_BANKING_COMME)                            ,UPPER(in_NAME_OF_STOCK)        ,UPPER(in_COUNTRIES_WHERE_OFFERS)
      ,in_REGULATORY_AUTHORITY      ,UPPER(in_RELATEDACCOUNT)       ,in_MAIN_CUSTOMER               ,in_ID_SOLICITUD
      ,in_CUSTOMER_NO_FCC			      ,UPPER(in_SHORT_NAME)			      ,in_LIAB_ID			  		          ,in_GROUP_CODE
      ,IN_ID_SOLICITUD_LM           ,IN_SUB_ECOGR_CD                ,UPPER(IN_ECONOMICGROUPRUC)     ,SYSDATE
      ,IN_CHK_CREATE_FCC            ,IN_CHK_SAMESHOLDERS_MAINCUST   ,v_existe_fcc                   ,TO_DATE('19800101', 'yyyymmdd')
      ,UPPER(IN_ACCOUNT_OFFICERID)  ,IN_LOCATIONID                  ,IN_AML_RATINGID                ,IN_NY_AGENCY
      ,IN_SBP_CATEGORYID            ,IN_CUSTOMER_CLASSIFICATION_PEP ,UPPER(IN_DESCRIPCION_PEP)      ,UPPER(IN_INCORPORATION_PURPOSE)
      ,UPPER(IN_LEGALREPRESENTATIVE_INFO) ,UPPER(IN_DIGNATARIES)    ,UPPER(IN_POWER_DEES)           ,UPPER(IN_AUTHORIZED_SIGNATURES)
      ,UPPER(IN_RELATION_CORRESPONSAL),DECODE(IN_CUSTOMER_TYPE,'4','E','5','E','C'), IN_SALES_MORE_30_PERCENT, IN_EXPORT_SHARE
      ,IN_PUBLIC_TRADE_COMP         ,IN_PATRIOT_EXC_DATE            ,IN_AML_EXC_DATE                ,IN_GIIN_NUMBER
      ,TO_DATE(IN_W8_FORM_DATE, 'dd/mm/yyyy'), TO_DATE(IN_FECHA_KYC, 'dd/mm/yyyy') 
      ,IN_INTERNAL_CONTROL,IN_CO_COVENANTS,IN_CO_DEUDOR_PRINCIPAL,IN_CHK_CONTR_APROB_VF  --2019.09.18 bmg ticket 16689 y 17569
      ,IN_CINU --2019.1126 bmg ticket 00016775-CINU
      ,IN_CO_OFICINA_GESTION  --ticket 32932 bmg
      ,IN_GROUP_EXPIRATION_MONTH-- HLEE - 30-08-2023 Ticket 38930
    );

    OPEN out_RESULTADO FOR
    SELECT 'INSERTADO' RESULTADO, v_CUSTOMER_NO_ID CUSTOMER_NO  FROM DUAL;
  ELSE

/*
INSERT INTO aah_test2 (
    column1,
    column2,
    column3,
    column4
) VALUES (
    IN_CUSTOMER_NO,
    IN_ID_SOLICITUD,
    IN_FECHA_KYC,
    IN_W8_FORM_DATE
    --TO_DATE(IN_FECHA_KYC, 'dd/mm/yyyy')
);
*/

COMMIT;

  UPDATE WF_KCC_CUSTOMER_INFO
  SET
      SHAREHOLDER = IN_SHAREHOLDER
      ,CUSTOMER_TYPE = in_CUSTOMER_TYPE
      ,CUSTOMER_NAME1=  UPPER(in_CUSTOMER_NAME1)
      ,FULLNAME=  UPPER(in_FULLNAME)
      ,TAXIDNUMBER=  in_TAXIDNUMBER

      ,DV=  in_DV
      ,CUSTOMER_CATEGORY=  UPPER(in_CUSTOMER_CATEGORY)
      ,RELATIONTYPE=  in_RELATIONTYPE
      ,INDUSTRY=  in_INDUSTRY
      ,NAMEOFECONOMICGROUP=  UPPER(in_NAMEOFECONOMICGROUP)
      --ULT_FArauz 28Jun2012 - Se comenta la actualizacion de variables, se realizara desde los nuevos formularios.
      --,LEGALREPRESENTATIVE=  in_LEGALREPRESENTATIVE
      ,NAMEEXTERNALAUDITORS=  UPPER(in_NAMEEXTERNALAUDITORS)
      ,NAMEINTERNATIONALRISK=  in_NAMEINTERNATIONALRISK
      ,POSTALALINE1=  UPPER(in_POSTALALINE1)
      ,POSTALALINE2=  UPPER(in_POSTALALINE2)
      ,POSTALALINE3=  UPPER(in_POSTALALINE3)
      ,POSTALACITY=  UPPER(in_POSTALACITY)

      ,PHYSICALALINE1=  UPPER(in_PHYSICALALINE1)
      ,PHYSICALALINE2=  UPPER(in_PHYSICALALINE2)
      ,PHYSICALALINE3=  UPPER(in_PHYSICALALINE3)
      ,TELEPHONENUMBER=  in_TELEPHONENUMBER
      ,TELEPHONENUMBER2=  in_TELEPHONENUMBER2
      ,FAXNUMBER=  in_FAXNUMBER
      ,WEBSITE=  in_WEBSITE
      ,DEFAULT_MEDIA=  in_DEFAULT_MEDIA
      ,INCORP_COUNTRYID=  in_INCORP_COUNTRYID
      ,INCORP_DATE=  TO_DATE(in_INCORP_DATE, 'dd/mm/yyyy')
      ,RESIDENCECOUNTRY=  in_RESIDENCECOUNTRY
      ,NATIONALITYID=  in_NATIONALITYID
      ,RESIDENCELOCATIONID=  in_RESIDENCELOCATIONID

      ,LANGUAGEID=  in_LANGUAGEID
      ,BANKTYPE=  in_BANKTYPE
      ,TYPEOFLICENCE=  in_TYPEOFLICENCE
      ,SWIFT_CODE=  in_SWIFT_CODE
      ,ABACODEVALUE=  in_ABACODEVALUE
      ,COMPLIANCEOFFICER=  UPPER(in_COMPLIANCEOFFICER)
      ,ADDRESSPROCESSAGENTINUSA=  UPPER(in_USA_PROCESS_AGENT)
      ,NETWORTH=  in_NETWORTH
      ,EXPOSURE_COUNTRYID=  in_EXPOSURE_COUNTRYID
      ,INCEPTION_DATE=  TO_DATE(in_INCEPTION_DATE, 'dd/mm/yyyy')
      ,PRODUCT_SERVICE_OFFERED=  UPPER(in_PRODUCT_SERVICE_OFFERED)
      ,RELATEDCOMPANIES=  UPPER(in_RELATEDCOMPANIES)
      ,EMAIL=  UPPER(in_EMAIL)

      ,NAME_ADDRESS_LEGAL_ADVISOR=  UPPER(in_NAME_ADDRESS_LEGAL_ADVISORS)
      ,REFERENCE_BANKING_COMMERCIAL=  UPPER(in_REFERENCE_BANKING_COMME)
      ,NAME_OF_STOCK=  UPPER(in_NAME_OF_STOCK)
      ,COUNTRIES_WHERE_OFFERS=  UPPER(in_COUNTRIES_WHERE_OFFERS)
      ,REGULATORY_AUTHORITY=  UPPER(in_REGULATORY_AUTHORITY)
      ,RELATEDACCOUNT = UPPER(in_RELATEDACCOUNT)
      --,MAIN_CUSTOMER =  in_MAIN_CUSTOMER
	    ,CUSTOMER_NO_FCC  = IN_CUSTOMER_NO_FCC
	    ,SHORT_NAME	= NVL(UPPER(IN_SHORT_NAME), SHORT_NAME)
	    ,LIAB_ID = NVL(in_LIAB_ID, LIAB_ID)
	    ,GROUP_CODE = in_GROUP_CODE
	    ,ID_SOLICITUD_LM =IN_ID_SOLICITUD_LM
      ,SUB_ECOGR_CD = NVL(IN_SUB_ECOGR_CD,SUB_ECOGR_CD)

      ,ECONOMICGROUPRUC = UPPER(IN_ECONOMICGROUPRUC)
      ,LAST_CHANGE_DATE = SYSDATE
      ,CHK_CREATE_FCC = IN_CHK_CREATE_FCC
      ,CHK_SAMESHOLDERS_MAINCUST = IN_CHK_SAMESHOLDERS_MAINCUST
      ,ID_EXISTE_FCC = v_existe_fcc
      ,ACCOUNT_OFFICERID = UPPER(IN_ACCOUNT_OFFICERID)
      ,LOCATIONID = UPPER(IN_LOCATIONID)
      ,AML_RATINGID = IN_AML_RATINGID
      ,NY_AGENCY = IN_NY_AGENCY
      ,SBP_CATEGORYID = UPPER(IN_SBP_CATEGORYID)
      ,CUSTOMER_CLASSIFICATION_PEP = IN_CUSTOMER_CLASSIFICATION_PEP
      ,DESCRIPCION_PEP = UPPER(IN_DESCRIPCION_PEP)
      ,INCORPORATION_PURPOSE = UPPER(IN_INCORPORATION_PURPOSE)

      --ULT_FArauz 28Jun2012 - Se comenta la actualizacion de variables, se realizara desde los nuevos formularios.
      --,LEGALREPRESENTATIVE_INFO = IN_LEGALREPRESENTATIVE_INFO
      --,DIGNATARIES = IN_DIGNATARIES
      --,POWER_DEES = IN_POWER_DEES
      --,AUTHORIZED_SIGNATURES = IN_AUTHORIZED_SIGNATURES
      ,RELATION_CORRESPONSAL = UPPER(IN_RELATION_CORRESPONSAL)
      ,LMT_CUSTOMER_TYPE = DECODE(IN_CUSTOMER_TYPE,'4','E','5','E','C')
      ,SALES_MORE_30_PERCENT=IN_SALES_MORE_30_PERCENT
      ,EXPORT_SHARE= IN_EXPORT_SHARE
      ,AML_RATINGID_NY= IN_AML_RATINGID_NY
      ,PUBLIC_TRADE_COMP = IN_PUBLIC_TRADE_COMP
      ,PATRIOT_EXC_DATE = IN_PATRIOT_EXC_DATE
      ,AML_EXC_DATE = IN_AML_EXC_DATE
      ,GIIN_NUMBER = IN_GIIN_NUMBER
      ,W8_FORM_DATE = TO_DATE(IN_W8_FORM_DATE, 'dd/mm/yyyy')
      ,FECHA_KYC = TO_DATE(IN_FECHA_KYC, 'dd/mm/yyyy') 
      --// AHernandez - 00013297
      ,TIPO_DE_CLIENTE = IN_TIPO_DE_CLIENTE
      ,INTERNAL_CONTROL = IN_INTERNAL_CONTROL
      --// AHernandez - 00013297
      --2019.09.12 bmg ticket 16689 y 17569
      ,CO_COVENANTS = IN_CO_COVENANTS
      ,CO_DEUDOR_PRINCIPAL = IN_CO_DEUDOR_PRINCIPAL
      ,CHK_CONTR_APROB_VF = IN_CHK_CONTR_APROB_VF
      --fin 16689 y 17569
      ,CINU = IN_CINU  --2019.1126 bmg ticket 00016775-CINU
      ,CO_OFICINA_GESTION = IN_CO_OFICINA_GESTION   -- ticket 32393 bmg
      ,GROUP_EXPIRATION_MONTH = IN_GROUP_EXPIRATION_MONTH-- HLEE - 30-08-2023 Ticket 38930
  WHERE
    (CUSTOMER_NO = IN_CUSTOMER_NO OR CUSTOMER_NO_FCC = IN_CUSTOMER_NO_FCC )
  AND ID_SOLICITUD = in_ID_SOLICITUD;

  -- AH 20121212 - Actualiza el nombre modificado del cliente en la tabla de limites (clientes nuevos)
  UPDATE WF_LMT_CUSTOMER
  SET CUSTOMER_NAME = IN_CUSTOMER_NAME1
  WHERE CUSTOMER_ID = IN_CUSTOMER_NO AND ID_SOLICITUD = IN_ID_SOLICITUD;

  -- AH 20121212 - Actualiza el nombre modificado del cliente en la tabla de limites (clientes existentes)
  UPDATE WF_LMT_CUSTOMER
  SET CUSTOMER_NAME = IN_CUSTOMER_NAME1

  WHERE CUSTOMER_NO = IN_CUSTOMER_NO_FCC  AND ID_SOLICITUD = IN_ID_SOLICITUD AND CUSTOMER_TYPE <> 'G';

  -- CUSTOMER_NO_FCC  = IN_CUSTOMER_NO_FCC

  commit;

    OPEN out_RESULTADO FOR
    SELECT 'ACTUALIZADO' RESULTADO, in_CUSTOMER_NO CUSTOMER_NO FROM DUAL;

 END IF ;

END BL_LMC_CUSTOMER_INSERT_UPDATE;