-- =========================================================
--  PROTOTIPO EXPERIMENTAL
--  Sistema Integral de Gestión Contable y Facturación ISP
--  Estudiante: William Duban Arrieta Caldera
--  Universidad Nacional Abierta y a Distancia UNAD
--  Mayo - 2026
--  Compatible con Oracle Database y Oracle APEX
-- =========================================================

-- =========================================================
-- 1. PROCEDIMIENTO PARA GENERAR FACTURAS AUTOMÁTICAS
-- =========================================================

CREATE OR REPLACE PROCEDURE GENERAR_FACTURAS_AUTOMATICAS
AS
BEGIN

    INSERT INTO FACTURA (
        CLIENTE_ID,
        FECHA_GENERACION,
        PERIODO_CORTE,
        VALOR_FACTURA,
        ESTADO,
        NOTAS
    )
    SELECT
        CLIENTE_ID,
        SYSDATE,
        PERIODO_CORTE,
        VALOR_FACTURA,
        'PENDIENTE',
        'Factura generada automáticamente'
    FROM CLIENTE;

    COMMIT;

END;
/




-- =========================================================
-- 2. PROCEDIMIENTO PARA REGISTRAR PAGOS
-- =========================================================

CREATE OR REPLACE PROCEDURE REGISTRAR_PAGO (
    P_CLIENTE_ID       IN NUMBER,
    P_FACTURA_ID       IN NUMBER,
    P_VALOR_PAGO       IN NUMBER,
    P_MEDIO_PAGO       IN VARCHAR2
)
AS

    V_VALOR_FACTURA      NUMBER;
    V_SALDO_PENDIENTE    NUMBER;
    V_ESTADO_FACTURA     VARCHAR2(15);

BEGIN

    -- CONSULTAR VALOR DE FACTURA
    SELECT VALOR_FACTURA, ESTADO
    INTO V_VALOR_FACTURA, V_ESTADO_FACTURA
    FROM FACTURA
    WHERE FACTURA_ID = P_FACTURA_ID;

    -- CALCULAR SALDO
    V_SALDO_PENDIENTE := V_VALOR_FACTURA - P_VALOR_PAGO;

    -- REGISTRAR PAGO
    INSERT INTO PAGO (
        CLIENTE_ID,
        FACTURA_ID,
        FECHA_PAGO,
        VALOR_PAGO,
        MEDIO_PAGO,
        PAGO_PARCIAL,
        SALDO_PENDIENTE
    )
    VALUES (
        P_CLIENTE_ID,
        P_FACTURA_ID,
        SYSDATE,
        P_VALOR_PAGO,
        P_MEDIO_PAGO,

        CASE
            WHEN V_SALDO_PENDIENTE > 0 THEN 'S'
            ELSE 'N'
        END,

        CASE
            WHEN V_SALDO_PENDIENTE > 0 THEN V_SALDO_PENDIENTE
            ELSE 0
        END
    );

    -- ACTUALIZAR ESTADO FACTURA
    IF V_SALDO_PENDIENTE <= 0 THEN

        UPDATE FACTURA
        SET ESTADO = 'PAGADA'
        WHERE FACTURA_ID = P_FACTURA_ID;

        UPDATE CLIENTE
        SET ESTADO = 'AL_DIA',
            PERIODOS_ACUMULADOS = 0
        WHERE CLIENTE_ID = P_CLIENTE_ID;

    ELSE

        UPDATE FACTURA
        SET ESTADO = 'PENDIENTE'
        WHERE FACTURA_ID = P_FACTURA_ID;

        UPDATE CLIENTE
        SET ESTADO = 'PENDIENTE'
        WHERE CLIENTE_ID = P_CLIENTE_ID;

    END IF;

    COMMIT;

END;
/




-- =========================================================
-- 3. PROCEDIMIENTO PARA REGISTRAR TRANSACCIONES CONTABLES
-- =========================================================

CREATE OR REPLACE PROCEDURE REGISTRAR_TRANSACCION_CONTABLE (
    P_DESCRIPCION      IN VARCHAR2,
    P_TIPO             IN VARCHAR2,
    P_CUENTA_DEBITO    IN NUMBER,
    P_CUENTA_CREDITO   IN NUMBER,
    P_VALOR            IN NUMBER
)
AS

    V_TRANSACCION_ID NUMBER;

BEGIN

    -- CREAR TRANSACCIÓN
    INSERT INTO TRANSACCION (
        FECHA,
        DESCRIPCION,
        TIPO
    )
    VALUES (
        SYSDATE,
        P_DESCRIPCION,
        P_TIPO
    )
    RETURNING TRANSACCION_ID INTO V_TRANSACCION_ID;


    -- MOVIMIENTO DÉBITO
    INSERT INTO MOVIMIENTO (
        TRANSACCION_ID,
        CUENTA_ID,
        VALOR_DEBITO,
        VALOR_CREDITO
    )
    VALUES (
        V_TRANSACCION_ID,
        P_CUENTA_DEBITO,
        P_VALOR,
        0
    );


    -- MOVIMIENTO CRÉDITO
    INSERT INTO MOVIMIENTO (
        TRANSACCION_ID,
        CUENTA_ID,
        VALOR_DEBITO,
        VALOR_CREDITO
    )
    VALUES (
        V_TRANSACCION_ID,
        P_CUENTA_CREDITO,
        0,
        P_VALOR
    );

    COMMIT;

END;
/




-- =========================================================
-- 4. TRIGGER PARA CONTROLAR CLIENTES MOROSOS
-- =========================================================

CREATE OR REPLACE TRIGGER TRG_CONTROL_MOROSIDAD
AFTER INSERT ON FACTURA
FOR EACH ROW

BEGIN

    UPDATE CLIENTE
    SET PERIODOS_ACUMULADOS = PERIODOS_ACUMULADOS + 1,
        ESTADO = 'PENDIENTE'
    WHERE CLIENTE_ID = :NEW.CLIENTE_ID;

END;
/




-- =========================================================
-- 5. VISTA DE CARTERA
-- =========================================================

CREATE OR REPLACE VIEW VW_CARTERA_CLIENTES
AS

SELECT
    C.CLIENTE_ID,
    C.NOMBRE,
    C.IDENTIFICACION,
    C.TELEFONO,
    F.FACTURA_ID,
    F.FECHA_GENERACION,
    F.VALOR_FACTURA,
    F.ESTADO
FROM CLIENTE C
INNER JOIN FACTURA F
ON C.CLIENTE_ID = F.CLIENTE_ID
WHERE F.ESTADO = 'PENDIENTE';




-- =========================================================
-- 6. VISTA DE REPORTES CONTABLES
-- =========================================================

CREATE OR REPLACE VIEW VW_REPORTE_CONTABLE
AS

SELECT
    T.TRANSACCION_ID,
    T.FECHA,
    T.DESCRIPCION,
    T.TIPO,
    C.CODIGO_PUC,
    C.NOMBRE_CUENTA,
    M.VALOR_DEBITO,
    M.VALOR_CREDITO
FROM TRANSACCION T
INNER JOIN MOVIMIENTO M
ON T.TRANSACCION_ID = M.TRANSACCION_ID
INNER JOIN CUENTA_PUC C
ON M.CUENTA_ID = C.CUENTA_ID;




-- =========================================================
-- 7. CONSULTA DE CLIENTES MOROSOS
-- =========================================================

SELECT
    CLIENTE_ID,
    NOMBRE,
    TELEFONO,
    PERIODOS_ACUMULADOS,
    ESTADO
FROM CLIENTE
WHERE ESTADO = 'PENDIENTE';




-- =========================================================
-- 8. CONSULTA DE INGRESOS
-- =========================================================

SELECT
    SUM(VALOR_PAGO) AS TOTAL_INGRESOS
FROM PAGO;




-- =========================================================
-- 9. CONSULTA DE FACTURAS PAGADAS
-- =========================================================

SELECT
    FACTURA_ID,
    CLIENTE_ID,
    FECHA_GENERACION,
    VALOR_FACTURA
FROM FACTURA
WHERE ESTADO = 'PAGADA';




-- =========================================================
-- 10. CONSULTA DE INFRAESTRUCTURA
-- =========================================================

SELECT
    INFRAESTRUCTURA_ID,
    TIPO,
    NOMBRE,
    UBICACION,
    VALOR_ADQUISICION,
    VIDA_UTIL
FROM INFRAESTRUCTURA;