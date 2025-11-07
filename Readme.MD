# Proyecto JE4: Mecanismo de Selección y Aprobación de las Ofertas Académicas de las IES

<p align="center">
  <img src="https://img.shields.io/badge/Hecho%20con-R-276DC3.svg?style=for-the-badge&logo=R&logoColor=white" alt="Hecho con R">
  <img src="https://img.shields.io/badge/Estado%20-Publicado-green.svg?style=for-the-badge" alt="Estado del Proyecto">
  <img src="https://img.shields.io/badge/Versión-2025.11.07-lightgrey.svg?style=for-the-badge" alt="Versión">
</p>

<br>

## Descripción

Este repositorio contiene el script en R (`JE4_Calculo_Ofertas_VF.R`) correspondiente al **Proyecto JE4**, cuyo objetivo es implementar el mecanismo de selección y aprobación de ofertas técnicas, asignando cupos (plazas) a programas académicos de Instituciones de Educación Superior (IES).

El algoritmo distribuye los cupos a partir de un presupuesto general y un conjunto de reglas de negocio que se estructuran en dos componentes principales:

1. **Mecanismo ISOES (90% del presupuesto):** Asigna recursos priorizando el *Índice de Sostenibilidad de la Oferta de Educación Superior* (ISOES) y la *Tasa Interna de Retorno* (TIR) de los programas.  
2. **Componente de Demanda Social (10% del presupuesto):** Asigna recursos a programas con alta demanda histórica que no obtuvieron cupos (o recibieron muy pocos) en el componente anterior.

---

## Flujo del Proceso

El script ejecuta una serie de pasos secuenciales para calcular los costos, distribuir el presupuesto y asignar los cupos de manera reproducible.

### 1. Cálculo de Costos Anuales

* **Preparación de Datos:** Carga las ofertas (`LISTADO_OFERTA_PROPUESTA`) y filtra los programas habilitados.  
* **Pivote de Semestres:** Convierte los costos de los 14 semestres de formato ancho a largo.  
* **Cálculo de Pagos:** Modela un calendario de pagos donde:  
  * Los semestres impares tienen un solo pago (`Pago1` = 100%).  
  * Los semestres pares tienen dos pagos: 80% en el período actual (`Pago1`) y 20% en el siguiente (`Pago2`).  
* **Costos Anuales:** Agrupa los pagos por año de ejecución para calcular el costo anualizado de cada programa (`OFERTA_COSTO_EJECUCION_ANUAL`).

---

### 2. Mecanismo ISOES (Paso 1, 2 y 3)

Este componente distribuye el 90% del presupuesto general (`PPTO_MecanismoActual`).

#### Paso 0: Distribución del Presupuesto

* El presupuesto del mecanismo se divide en `PPTO_UNIV` (95%) y `PPTO_TYT` (5%) para programas Universitarios y Técnicos/Tecnológicos, respectivamente.

#### Paso 1: Asignación de Bolsa de Recursos por IES

* Calcula la **TIR promedio ponderada** por IES y Nivel.  
* Las IES con TIR ponderada negativa son excluidas del proceso.  
* Distribuye el presupuesto (`PPTO_UNIV` y `PPTO_TYT`) entre las IES elegibles.

#### Paso 2: Asignación de Cupos dentro de la IES

* **Ordenamiento:** Los programas se ordenan dentro de cada IES según:  
  1. Mayor `ISOES_PROGRAMA` (descendente).  
  2. Menor `TOTAL_VALOR_COHORTE_ATENEA` (ascendente).  
  3. Mayor `CUPOS_SEGÚN_CAPACIDAD` (descendente).  
  4. Semilla aleatoria (`set.seed(20251010)`) para desempates.  
* **Iteración:** El script recorre los programas asignando cupos (`CUPO_ASIGNADO_IES`) mientras exista disponibilidad en la bolsa de la IES y en la bolsa anual (`BASE_ANUAL`).

#### Paso 3: Asignación del Excedente (Bolsa Común por Nivel)

* El presupuesto sobrante (`VALOR_SOBRANTE_IES_NIVEL`) se agrupa en una bolsa común por Nivel (TYT y UNIVERSITARIO).  
* **Cálculo de cupos pendientes:** Se calcula `CUPO_PENDIENTES`, definido como la diferencia entre `CUPOS_SEGÚN_CAPACIDAD` y `CUPO_ASIGNADO_NIVEL`.  
* Luego se recorre nuevamente la lista de programas (en el mismo orden) para asignar cupos adicionales (`CUPO_ASIGNADO_NIVEL`) a aquellos con `CUPO_PENDIENTES` aún disponibles.

---

### 3. Componente de Demanda Social

Este componente distribuye el 10% del presupuesto inicial (`PPTO_DemandaSocial`), más el excedente final del Mecanismo ISOES.

#### Filtrado de Programas

Se seleccionan los programas que cumplen todas las condiciones siguientes:

* Recibieron menos de **6 cupos en el paso anterior**, agrupado por `CINE` y `NIVEL`.  
* Aún tienen cupos pendientes (`CUPO_PENDIENTES > 0`), tras un **recalculo** de la variable con base en `CUPOS_SEGÚN_CAPACIDAD` y `CUPOS_ASIGNADOS_MECANISMO_ISOES`.  
* Tienen datos de demanda social histórica (`DH_INDICADOR_DEMANDA_SOCIAL`).  
* Se ubican por encima del percentil 50 en demanda (`DH_PERCENTIL_50_(POR_ENCIMA_/_POR_DEBAJO)`).

#### Asignación (similar al Paso 2 y 3)

* El presupuesto se distribuye inicialmente en bolsas por **CINE y Nivel** (según inscritos históricos).  
* Se asignan cupos (`CUPO_ASIGNADO_CINE`) a los programas elegibles.  
* El excedente se agrupa en una **bolsa común por Nivel** y se repite el proceso para asignar los cupos restantes (`CUPO_ASIGNADO_NIVEL_DH`).

---

### 4. Resultados

* **Consolidación:** Se genera el `data frame` final (`RESULT`) con el total de cupos asignados por programa.  
* **Exportación:** Los resultados se guardan en un archivo Excel (`.xlsx`) con las siguientes hojas:
  * `JE4_PROGRAMAS`: Resultado principal de asignación por programa.  
  * `EXCEDENTES_NIVEL`: Montos sobrantes finales.  
  * `BOLSA_ANUAL`: Estado final de la bolsa anual de presupuesto.  
  * `IES`: Cálculos de la bolsa por IES (Paso 1).  
  * `CINE`: Cálculos de la bolsa por CINE (Componente Demanda Social).

---

## Requisitos

### Dependencias de R

El script requiere las siguientes bibliotecas:

```r
sqldf
expss
readr
readxl
dplyr
tidyr
eeptools
openxlsx

Archivos de Entrada

El script depende de un único archivo de entrada en el directorio de trabajo:

JE4_Insumo_Oferta.RData


Este archivo debe incluir, como mínimo:

LISTADO_OFERTA_PROPUESTA: Ofertas académicas propuestas por las IES.

DemandaHistorica: Datos históricos de demanda (inscritos, cupos, etc.) por CINE y Nivel.

BASE_ANUAL: Presupuesto disponible por año (columna Escenario 1).



---

Cómo Ejecutar

1. Verifique que todas las bibliotecas estén instaladas.


2. Coloque el script JE4_Calculo_Ofertas_VF.R y el archivo JE4_Insumo_Oferta.RData en el mismo directorio.


3. Actualice la ruta de trabajo en el script:

# UBICAR LA CARPETA DE TRABAJO
setwd("D:/SU/RUTA/AL/PROYECTO/PUBLICAR")


4. Ejecute el script completo.


5. Los resultados se generarán en la carpeta RESULTADOS/ (cree la carpeta o ajuste la ruta de exportación si es necesario).
