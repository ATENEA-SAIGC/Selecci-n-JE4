# Proyecto JE4: Mecanismo de Selección de Ofertas

<p align="center">
  <img src="https://img.shields.io/badge/Hecho%20con-R-276DC3.svg?style=for-the-badge&logo=R&logoColor=white" alt="Hecho con R">
  <img src="https://img.shields.io/badge/Estado%20-Publicado-green.svg?style=for-the-badge" alt="Estado del Proyecto">
  <img src="https://img.shields.io/badge/Versión-2025.11.07-lightgrey.svg?style=for-the-badge" alt="Versión">
</p>

<br>

| <img src="https://www.agenciaatenea.gov.co/sites/default/files/inline-images/atenea520.png" alt="Logo Atenea" width="300"> |----------------------------------------------------------------------<br> **Código Publicado** <br> ----------------------------------------------------------------------| **Año:** 2025<br> **SAIGC** <br> *Subgerencia de Análisis de Información*<br>*y Gestión del Conocimiento* |
| :---: |:-----------------------: | ----------------: |



## Descripción

Este repositorio contiene el script de R (`JE4_Calculo_Ofertas_VF.R`) para el **Proyecto JE4**. El objetivo de este script es implementar el mecanismo de selección y aprobación de ofertas técnicas, asignando cupos (plazas) a programas académicos de Instituciones de Educación Superior (IES).

El algoritmo asigna cupos basado en un presupuesto general, un conjunto de reglas de negocio complejas, y dos componentes principales de asignación:

1.  **Mecanismo ISOES (90% del presupuesto):** Asigna recursos priorizando el *Índice de Sostenibilidad de la Oferta de Educación Superior* (ISOES) y la *Tasa Interna de Retorno* (TIR) de los programas.
2.  **Componente de Demanda Social (10% del presupuesto):** Asigna recursos a programas con alta demanda histórica que no recibieron cupos (o recibieron muy pocos) en el primer componente.

## Flujo del Proceso

El script ejecuta una serie de pasos secuenciales para calcular los costos, distribuir el presupuesto y asignar los cupos.

### 1\. Cálculo de Costos Anuales

  * **Preparación de Datos:** Carga las ofertas (`LISTADO_OFERTA_PROPUESTA`) y filtra los programas habilitados.
  * **Pivote de Semestres:** Transforma los costos de los 14 semestres (de formato ancho a largo).
  * **Cálculo de Pagos:** Modela un calendario de pagos complejo donde:
      * Los semestres impares tienen un solo pago (`Pago1` = 100%).
      * Los semestres pares tienen dos pagos: 80% en el período actual (`Pago1`) y 20% en el período siguiente (`Pago2`).
  * **Costos Anuales:** Agrupa estos pagos por año de ejecución para crear el costo anualizado por programa (`OFERTA_COSTO_EJECUCION_ANUAL`).

### 2\. Mecanismo ISOES (Paso 1, 2 y 3)

Este mecanismo distribuye el 90% del presupuesto general (`PPTO_MecanismoActual`).

  * **Paso 0: Distribución del Presupuesto:**

      * El presupuesto del mecanismo se divide en `PPTO_UNIV` (95%) y `PPTO_TYT` (5%) para programas Universitarios y Técnicos/Tecnológicos, respectivamente.

  * **Paso 1: Asignación de Bolsa de Recursos por IES:**

      * Calcula una **TIR promedio ponderada** por IES y Nivel.
      * Las IES con una TIR ponderada negativa son excluidas (asignación de cero).
      * Distribuye el presupuesto (`PPTO_UNIV` y `PPTO_TYT`) entre las IES elegibles.

  * **Paso 2: Asignación de Cupos dentro de la IES:**

      * **Ordenamiento:** Los programas de cada IES se ordenan con los siguientes criterios de prioridad:
        1.  Mayor `ISOES_PROGRAMA` (descendente).
        2.  Menor `TOTAL_VALOR_COHORTE_ATENEA` (ascendente).
        3.  Mayor `CUPOS_SEGÚN_CAPACIDAD` (descendente).
        4.  Semilla aleatoria (`set.seed(20251010)`) para desempates finales.
      * **Iteración:** El script recorre cada programa en orden y le asigna cupos (`CUPO_ASIGNADO_IES`) mientras tenga presupuesto en su bolsa de IES y haya presupuesto en la bolsa general anual (`BASE_ANUAL`).

  * **Paso 3: Asignación del Excedente (Bolsa Común por Nivel):**

      * El presupuesto sobrante (`VALOR_SOBRANTE_IES_NIVEL`) de todas las IES se agrupa en una bolsa común por Nivel (TYT y UNIVERSITARIO).
      * Se vuelve a recorrer la lista de programas (en el mismo orden) para asignar cupos adicionales (`CUPO_ASIGNADO_NIVEL`) a aquellos que aún tengan `CUPO_PENDIENTES`.

### 3\. Componente de Demanda Social

Este mecanismo distribuye el 10% del presupuesto inicial (`PPTO_DemandaSocial`) más el excedente final del Mecanismo ISOES.

  * **Filtrado de Programas:** Se seleccionan programas que cumplen todas estas condiciones:

      * Recibieron menos de 6 cupos en el paso anterior.
      * Aún tienen cupos pendientes (`CUPO_PENDIENTES > 0`).
      * Tienen datos de demanda social histórica (`DH_INDICADOR_DEMANDA_SOCIAL`).
      * Están por encima del percentil 50 en demanda (`DH_PERCENTIL_50_(POR_ENCIMA_/_POR_DEBAJO)`).

  * **Asignación (similar al Paso 2 y 3):**

      * El presupuesto se distribuye primero en bolsas por **CINE y Nivel** (basado en inscritos históricos).
      * Se asignan cupos (`CUPO_ASIGNADO_CINE`) recorriendo los programas elegibles.
      * El excedente de esta asignación se agrupa en una bolsa común por Nivel y se repite el proceso para asignar los últimos cupos (`CUPO_ASIGNADO_NIVEL_DH`).

### 4\. Resultados

  * **Consolidación:** Se genera un data frame final (`RESULT`) que contiene el total de cupos asignados por programa.
  * **Exportación:** Los resultados se guardan en un archivo Excel (`.xlsx`) con varias hojas:
      * `JE4_PROGRAMAS`: El resultado principal de asignación por programa.
      * `EXCEDENTES_NIVEL`: Los montos sobrantes finales.
      * `BOLSA_ANUAL`: El estado final de la bolsa de presupuesto anual.
      * `IES`: Los cálculos de la bolsa por IES (Paso 1).
      * `CINE`: Los cálculos de la bolsa por CINE (Componente Demanda Social).

## Requisitos

### Dependencias de R

El script requiere las siguientes bibliotecas de R:

  * `sqldf`
  * `expss`
  * `readr`
  * `readxl`
  * `dplyr`
  * `tidyr`
  * `eeptools`
  * `openxlsx`

### Archivos de Entrada

El script depende de un único archivo de entrada que debe estar en el directorio de trabajo:

  * `JE4_Insumo_Oferta.RData`

Este archivo RData debe contener, como mínimo, los siguientes objetos:

  * `LISTADO_OFERTA_PROPUESTA`: Data frame principal con las ofertas de programas de las IES.
  * `DemandaHistorica`: Data frame con datos históricos de demanda (inscritos, cupos, etc.) por CINE y Nivel.
  * `BASE_ANUAL`: Data frame con el presupuesto disponible por año (columna `Escenario 1`).

## Cómo Ejecutar

1.  Asegúrese de tener todas las bibliotecas de R listadas anteriormente instaladas.

2.  Coloque el script `JE4_Calculo_Ofertas_VF.R` y el archivo `JE4_Insumo_Oferta.RData` en el mismo directorio.

3.  Actualice la ruta de trabajo en el script R, modificando la línea `setwd(...)`:

    ```r
    # UBICAR LA CARPETA DE TRABAJO
    setwd("D:/SU/RUTA/AL/PROYECTO/PUBLICAR")
    ```

4.  Ejecute el script en su totalidad.

5.  Los resultados se generarán en la subcarpeta `RESULTADOS/` (esta carpeta debe existir o debe modificar la ruta de exportación).