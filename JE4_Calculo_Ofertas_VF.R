#==============================================================================================
# JE4
# Mecanismo de selección y aprobación de las ofertas técnicas
# 2025-10-29
#==============================================================================================

#==============================================================================================
# GUARDAR AREA DE TRABAJO
#==============================================================================================

#UBICAR LA CARPETA DE TRABAJO
setwd("D:/FUENTES_INFORMACION/JOVENES_U/Ofertas/OFERTA_SIMULACION/JE4_Algoritmo/PUBLICAR")
getwd()

#-----------------------------------------
# CARGAR INSUMOS PARA EL CALCULO DE OFERTA
#-----------------------------------------
load("JE4_Insumo_Oferta.RData")

library(sqldf)
library(expss)
library(readr)
library(readxl)
library(dplyr)
library(tidyr)
library(eeptools)
library(openxlsx)
options(scipen=999)

#------------------------------------------------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------------------------------------------------
# CALCULO COSTOS ANUAL
#------------------------------------------------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------------------------------------------------

OFERTA_COSTO <- LISTADO_OFERTA_PROPUESTA[LISTADO_OFERTA_PROPUESTA$PROGRAMA_HABILITADO=="Habilitado",c(1,4,22,37,23:36)]
names(OFERTA_COSTO)

OFERTA_COSTO <- pivot_longer(OFERTA_COSTO, cols = 5:18, names_to = "SEMESTRE", values_to = "COSTO_SEMESTRE")
# TRASFORMAR A SOLO NUMERICO
OFERTA_COSTO$SEMESTRE <- gsub("\\D", "", OFERTA_COSTO$SEMESTRE)
OFERTA_COSTO$SEMESTRE <- as.double(OFERTA_COSTO$SEMESTRE)

# CALCULO COSTO SEMESTRE ATENEA
#OFERTA_COSTO$COSTO_SEMESTRE_ATENEA <- OFERTA_COSTO$COSTO_SEMESTRE *.7

# CREACION VARIABLE DE ORDENAMIENTO POR PROGRAMA
OFERTA_COSTO <- OFERTA_COSTO %>% group_by(ID,CÓDIGO_SNIES_DEL_PROGRAMA_A_OFERTAR,TOTAL_VALOR_ATENEA) %>%  mutate(SECUENCIA_SEMESTRES = order(SEMESTRE))

# DEPURAR SEMESTRES QUE NO APLICAN PARA CALCULO

OFERTA_COSTO <- OFERTA_COSTO[OFERTA_COSTO$SECUENCIA_SEMESTRES <= OFERTA_COSTO$Periodos_Referencia, ]


#--------------------------------
# OFERTAS - CALCULO COSTOS-EJECUCION OFERTA 
#--------------------------------

OFERTA_COSTO_EJECUCION <- OFERTA_COSTO

OFERTA_COSTO_EJECUCION$ANIO_SEMESTRE_EJECUCION <- OFERTA_COSTO_EJECUCION$SEMESTRE

OFERTA_COSTO_EJECUCION$Pago1 <- 1
OFERTA_COSTO_EJECUCION$Pago2 <- .2

# PARA SEMESTRES PARES EL PAGO 1 ES EL 80%
OFERTA_COSTO_EJECUCION[OFERTA_COSTO_EJECUCION$SECUENCIA_SEMESTRES %in% c(2,4,6,8,10,12), "Pago1" ] <-.8
# PARA SEMESTRES IMPARES EL PAGO 2 ES EL 0%
OFERTA_COSTO_EJECUCION[!OFERTA_COSTO_EJECUCION$SECUENCIA_SEMESTRES %in% c(2,4,6,8,10,12), "Pago2" ] <-0

OFERTA_COSTO_EJECUCION <- pivot_longer(OFERTA_COSTO_EJECUCION, cols = 9:10, names_to = "NUMERO_PAGO", values_to = "PORCENTAJE_PAGO")

#SE DEPURAN LOS PORCENTAJES 0%
OFERTA_COSTO_EJECUCION <- OFERTA_COSTO_EJECUCION[OFERTA_COSTO_EJECUCION$PORCENTAJE_PAGO > 0,]

#CALCULAR COSTO SEMESTRE ATENEA - PAGO
OFERTA_COSTO_EJECUCION$COSTO_SEMESTRE_PAGO <- OFERTA_COSTO_EJECUCION$COSTO_SEMESTRE * OFERTA_COSTO_EJECUCION$PORCENTAJE_PAGO

# CALCULAR ANIO EJECUCION (PAGO2 pasa al siguiente periodo) es decir se le suma la constante = 9
cro(OFERTA_COSTO_EJECUCION$ANIO_SEMESTRE_EJECUCION, OFERTA_COSTO_EJECUCION$NUMERO_PAGO )
OFERTA_COSTO_EJECUCION[OFERTA_COSTO_EJECUCION$NUMERO_PAGO=="Pago2", "ANIO_SEMESTRE_EJECUCION" ] <- OFERTA_COSTO_EJECUCION[OFERTA_COSTO_EJECUCION$NUMERO_PAGO=="Pago2", "ANIO_SEMESTRE_EJECUCION" ] + 9
cro(OFERTA_COSTO_EJECUCION$ANIO_SEMESTRE_EJECUCION, OFERTA_COSTO_EJECUCION$NUMERO_PAGO )
OFERTA_COSTO_EJECUCION$ANIO_EJECUCION <- substr(OFERTA_COSTO_EJECUCION$ANIO_SEMESTRE_EJECUCION, 1,4)

# CREACION VARIABLE DE ORDENAMIENTO POR PROGRAMA
OFERTA_COSTO_EJECUCION <- OFERTA_COSTO_EJECUCION %>% group_by(ID,CÓDIGO_SNIES_DEL_PROGRAMA_A_OFERTAR,TOTAL_VALOR_ATENEA) %>%  mutate(ID_ORDEN = order(SEMESTRE,ANIO_SEMESTRE_EJECUCION))

#------------------------------------------------
#DATAFRAME FINAL PARA EL ANALISIS ANUAL
#------------------------------------------------
OFERTA_COSTO_EJECUCION_ANUAL <- OFERTA_COSTO_EJECUCION %>% group_by(ID,CÓDIGO_SNIES_DEL_PROGRAMA_A_OFERTAR,Periodos_Referencia,TOTAL_VALOR_ATENEA,ANIO_EJECUCION) %>%  summarise_at(vars(COSTO_SEMESTRE_PAGO), list(COSTO_ANIO = sum))

#------------------------------------------------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------------------------------------------------
# FIN CALCULO COSTOS ANUAL
#------------------------------------------------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------------------------------------------------




#===============================================================================
#-------------------------------------------------------------------------------
#===============================================================================
#                             CALCULO OFERTA GENERAL
#===============================================================================
#-------------------------------------------------------------------------------
#===============================================================================

OFERTA_GENERAL <- unique(LISTADO_OFERTA_PROPUESTA[LISTADO_OFERTA_PROPUESTA$PROGRAMA_HABILITADO=="Habilitado",])
sqldf("select CÓDIGO_SNIES_DEL_PROGRAMA_A_OFERTAR, count(1) from OFERTA_GENERAL group by CÓDIGO_SNIES_DEL_PROGRAMA_A_OFERTAR having count(1)>1")


#===============================================================================
#Paso 0: DISTRIBUCION PRESUPUESTO
#===============================================================================

PPTO_GENERAL <- 134411135364

# DISTRIBUCION PRESUPUESTO
PPTO_MecanismoActual <- PPTO_GENERAL * .9
PPTO_DemandaSocial <- PPTO_GENERAL * .1

# DATOS ESCENARIO 1
PPTO_UNIV <- PPTO_MecanismoActual * .95
PPTO_TYT <- PPTO_MecanismoActual * .05


OFERTA_GENERAL$PPTO_MecanismoISOES <- 0
OFERTA_GENERAL[OFERTA_GENERAL$NIVEL_PROGRAMA_SNIES_AJUSTE=="UNIVERSITARIO", "PPTO_MecanismoISOES"] <- PPTO_UNIV
OFERTA_GENERAL[OFERTA_GENERAL$NIVEL_PROGRAMA_SNIES_AJUSTE!="UNIVERSITARIO", "PPTO_MecanismoISOES"] <- PPTO_TYT

#===============================================================================
# VALOR DE LA COHORTE ATENEA
#===============================================================================
OFERTA_GENERAL$TOTAL_VALOR_COHORTE_ATENEA <- OFERTA_GENERAL$TOTAL_VALOR_ATENEA

#===============================================================================
#Paso 1: Asignación de una bolsa de recursos para cada una de las IES habilitadas
#===============================================================================

# CUPOs PARA ANALIZAR
colnames(OFERTA_GENERAL)[colnames(OFERTA_GENERAL)=="NÚMERO_DE_CUPOS_A_OFERTAR"] <- "NÚMERO_DE_CUPOS_A_OFERTAR_ORI"
OFERTA_GENERAL$NÚMERO_DE_CUPOS_A_OFERTAR <- OFERTA_GENERAL$CUPOS_SEGÚN_CAPACIDAD 

#----------------------
# TIR PONDERADA
#----------------------
TIR_PONDERADA <- OFERTA_GENERAL[,c("COD_IES","NIVEL_PROGRAMA_SNIES_AJUSTE","CÓDIGO_SNIES_DEL_PROGRAMA_A_OFERTAR","TIR_PROGRAMA")] %>% group_by(COD_IES,NIVEL_PROGRAMA_SNIES_AJUSTE) %>%  summarise_at(vars(TIR_PROGRAMA), list(TOTAL_TIR_IES_NIVEL = sum))
OFERTA_GENERAL <- merge(x=OFERTA_GENERAL, y=TIR_PONDERADA, by=c("COD_IES","NIVEL_PROGRAMA_SNIES_AJUSTE"), all = FALSE)
OFERTA_GENERAL$TIR_PARTICIPACION <- OFERTA_GENERAL$TIR_PROGRAMA/ OFERTA_GENERAL$TOTAL_TIR_IES_NIVEL

# DENOMINADOR TOTALCUPOS_IES_NIVEL
IES <- OFERTA_GENERAL %>% group_by(COD_IES,NIVEL_PROGRAMA_SNIES_AJUSTE,PPTO_MecanismoISOES) %>%  summarise_at(vars(NÚMERO_DE_CUPOS_A_OFERTAR), list(TOTALCUPOS_IES_NIVEL = sum))
NIVEL <- merge(x=OFERTA_GENERAL[,c("COD_IES","NIVEL_PROGRAMA_SNIES_AJUSTE","CÓDIGO_SNIES_DEL_PROGRAMA_A_OFERTAR","TIR_PROGRAMA","NÚMERO_DE_CUPOS_A_OFERTAR")], y=IES, by=c("COD_IES","NIVEL_PROGRAMA_SNIES_AJUSTE"), all = FALSE )

# DISTRIBUCION CUPOS
NIVEL$DISTRIBUCION_CUPOS <- NIVEL$NÚMERO_DE_CUPOS_A_OFERTAR / NIVEL$TOTALCUPOS_IES_NIVEL

# DISTRIBUCION CUPOS X TIR
NIVEL$DISTRIBUCION_CUPOS_X_TIR <-  NIVEL$DISTRIBUCION_CUPOS * NIVEL$TIR_PROGRAMA

#-------------------------------------------------------------------------------
#  TIR promedio ponderada por IES Y NIVEL
#-------------------------------------------------------------------------------
TMP <- NIVEL %>% group_by(COD_IES,NIVEL_PROGRAMA_SNIES_AJUSTE) %>%  summarise_at(vars(DISTRIBUCION_CUPOS_X_TIR), list(TOTAL_DISTRICUPOS_TIR_IES_NIVEL = sum))

#-------------------------------------------------------------------------------
# Nota 2. La fórmula presentada anteriormente, no implica que la totalidad de programas presentados por la IES deban tener una TIR positiva. 
# Lo que implica es que la sumatoria de la TIR ponderada si debe resultar en un número positivo. Las IES cuya TIR ponderada resulte negativa, 
# tendrá una asignación de recursos equivalente a cero. Es decir que no tendrá cupos asignados.
#-------------------------------------------------------------------------------
IES <- merge(x=IES, y=TMP[TMP$TOTAL_DISTRICUPOS_TIR_IES_NIVEL > 0 ,], by=c("COD_IES","NIVEL_PROGRAMA_SNIES_AJUSTE"), all = FALSE )
rm(TMP)

#-------------------------------------------------------------------------------
# TIR promedio ponderada total para toda la oferta por NIVEL
#-------------------------------------------------------------------------------
TMP <- IES %>% group_by(NIVEL_PROGRAMA_SNIES_AJUSTE) %>%  summarise_at(vars(TOTAL_DISTRICUPOS_TIR_IES_NIVEL), list(TOTAL_DISTRICUPOS_TIR_NIVEL = sum))
IES <- merge(x=IES, y=TMP, by=c("NIVEL_PROGRAMA_SNIES_AJUSTE"), all = FALSE )
rm(TMP)

#-------------------------------------------------------------------------------
# DISTRIBUCION BOLSA RECURSOS 
#-------------------------------------------------------------------------------
IES$DISTRIBUCION  <- IES$TOTAL_DISTRICUPOS_TIR_IES_NIVEL / IES$TOTAL_DISTRICUPOS_TIR_NIVEL
sum(IES[IES$NIVEL_PROGRAMA_SNIES_AJUSTE=="TYT","DISTRIBUCION"])
sum(IES[IES$NIVEL_PROGRAMA_SNIES_AJUSTE=="UNIVERSITARIO","DISTRIBUCION"])

#-------------------------------------------------------------------------------
# VALOR DISTRIBUCION
#-------------------------------------------------------------------------------
#Multiplicamos la distribución por el presupuesto 
IES$VALOR_DISTRIBUCION_IES_NIVEL <- IES$PPTO_MecanismoISOES * IES$DISTRIBUCION
sum(IES$VALOR_DISTRIBUCION_IES_NIVEL)

#===============================================================================
# Paso 2: Asignación de cupos por programa al interior de la IES
#===============================================================================

#-------------------------------------------------------------------------------
# i) Se ordenarán los programas presentados por la IES de mayor a menor según el ISOES de los programas
#-------------------------------------------------------------------------------

#Nota 1: En caso de que la IES presente programas que tengan un ISOES con el mismo valor, se seguirán las siguientes reglas para la aplicación del paso 2 del mecanismo de asignación:

#i)  Se priorizará en orden aquel programa que tenga el menor valor de matricula.
#ii) En caso de que tengan el mismo valor de matrícula, se priorizará en orden aquel en el cual se hayan ofertado más cupos.
#iii)En caso de los programas tengan el mismo valor de matrícula y los cupos ofertados sean iguales, se procederá a hacer la ordenación de manera aleatoria haciendo uso de una herramienta estadística.

set.seed(20251010)
OFERTA_GENERAL$SEMILLA <-  OFERTA_GENERAL$CÓDIGO_SNIES_DEL_PROGRAMA_A_OFERTAR[sample(length(OFERTA_GENERAL$CÓDIGO_SNIES_DEL_PROGRAMA_A_OFERTAR))]
sqldf("select SEMILLA FROM OFERTA_GENERAL GROUP BY SEMILLA HAVING COUNT(1)>1")

# VARIABLES PARA ORDENAMIENTO
TMP <- OFERTA_GENERAL[,c("ID","COD_IES","NOMBRE_IES","CÓDIGO_SNIES_DEL_PROGRAMA_A_OFERTAR","NOMBRE_PROGRAMA_SNIES","JORNADA_DEL_PROGRAMA", "NIVEL_DE_FORMACIÓN","NIVEL_PROGRAMA_SNIES_AJUSTE","CINE_F_2013_AC_CAMPO_DETALLADO", "ISOES_PROGRAMA","TIR_PROGRAMA","TOTAL_VALOR_COHORTE_ATENEA","CUPOS_SEGÚN_CAPACIDAD","SEMILLA")] 

ORDENAMIENTO_PROG <-TMP %>%  arrange(desc(ISOES_PROGRAMA),
                                TOTAL_VALOR_COHORTE_ATENEA,
                                desc(CUPOS_SEGÚN_CAPACIDAD),
                                SEMILLA, na.last=TRUE)

ORDENAMIENTO_PROG$ORDENAMIENTO_PROG <- as.double(row.names(ORDENAMIENTO_PROG)) 

#PEGAR DEMANDA HISTORICA
ORDENAMIENTO_PROG <- merge(x=ORDENAMIENTO_PROG, y=DemandaHistorica, by.x = c("CINE_F_2013_AC_CAMPO_DETALLADO","NIVEL_PROGRAMA_SNIES_AJUSTE"),
                           by.y = c("DH_CINE_DETALLADO","DH_NIVEL_PROGRAMA_SNIES_AJUSTE"), all.x = TRUE)


#PEGAR RESULTADO A DATAFRAME PERSONA UNICA
OFERTA_GENERAL <- merge(x=ORDENAMIENTO_PROG[,c("ORDENAMIENTO_PROG","ID","DH_INSCRITOS","DH_CUPOS","DH_INDICADOR_DEMANDA_SOCIAL","DH_PERCENTIL_50_(POR_ENCIMA_/_POR_DEBAJO)")],y=OFERTA_GENERAL,by="ID", all = FALSE)


# Creación identificar de registro IES NIVEL para recorridos
IES <- IES %>%  arrange(COD_IES,NIVEL_PROGRAMA_SNIES_AJUSTE) %>%  mutate(ID_IES_NIVEL = row_number())

TMP<- merge(x=IES, y= ORDENAMIENTO_PROG)

# CONSTRUCCION DE BOLSAS Recurso Excedente
IES$VALOR_SOBRANTE_IES_NIVEL <- IES$VALOR_DISTRIBUCION_IES_NIVEL
BASE_ANUAL$VALOR_GENERAL_SOBRANTE <- BASE_ANUAL$`Escenario 1` *.9
ORDENAMIENTO_PROG$CUPO_ASIGNADO_IES <- 0
ORDENAMIENTO_PROG$COSTO_CUPOS_ASIGNADO_IES <- 0

#-------------------------------------------------------------------------------
# CALCULO DE CUPOS
# SE RECORRE POR IES y nivel
#-------------------------------------------------------------------------------
for (ID_IES_NIVEL in unique(IES$ID_IES_NIVEL) ) {
  print(paste("ORDEN_IES_",ID_IES_NIVEL))
  
  # IES QUE SE VA A RECORRER SUS PROGRAMAS
  EVALUAR_IES <- IES[IES$ID_IES_NIVEL==ID_IES_NIVEL,]
  print(paste(EVALUAR_IES$COD_IES, EVALUAR_IES$NIVEL_PROGRAMA_SNIES_AJUSTE, EVALUAR_IES$VALOR_SOBRANTE_IES_NIVEL,sep = " "))
  
  ## SE LLENA LA SEMILLA UNICAMENTE LOS PROGRAMAS CORRESPONDIENTES A LA IES Y EL NIVEL
  SEMILLA_PROGRAMAS <- ORDENAMIENTO_PROG[ORDENAMIENTO_PROG$COD_IES==EVALUAR_IES$COD_IES & ORDENAMIENTO_PROG$NIVEL_PROGRAMA_SNIES_AJUSTE==EVALUAR_IES$NIVEL_PROGRAMA_SNIES_AJUSTE, ]
  
  #ORDENAR PROGRAMAS DE LA SEMILLA
  SEMILLA_PROGRAMAS <-SEMILLA_PROGRAMAS[order(SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG),]
  
  # SE RECORRE LA SEMILLA CON LOS PROGRAMAS DE LA IES POR NIVEL
  for (ID_PROGRAMA in SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG){
    
    EVALUAR_PROG <- SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG==ID_PROGRAMA,]
    
    # SE LLENA VARIABLE CON EL PRESUPUESTO DE LA IES - NIVEL (ojo el sobrante es el que se recalcula y tiene en cuenta)
    VALOR_IES <- IES[IES$ID_IES_NIVEL==ID_IES_NIVEL,"VALOR_SOBRANTE_IES_NIVEL"]
    
    #SE CREAN VARIABLES DE CALCULO DE CUPOS
    CUPO_OFERTADO <- EVALUAR_PROG$CUPOS_SEGÚN_CAPACIDAD
    CUPO_CALCULADO <- VALOR_IES/EVALUAR_PROG$TOTAL_VALOR_COHORTE_ATENEA
    TOTAL_COHORTE <- EVALUAR_PROG$TOTAL_VALOR_COHORTE_ATENEA
    
    #------------------------
    #CALCULO POR VIGENCIA
    #------------------------
    EVALUAR_PROG_ANIO <- OFERTA_COSTO_EJECUCION_ANUAL[OFERTA_COSTO_EJECUCION_ANUAL$ID==EVALUAR_PROG$ID,]
    #pegamos datos de la bolsa
    EVALUAR_PROG_ANIO <- merge(x=EVALUAR_PROG_ANIO, y=BASE_ANUAL[,c("ANIO","VALOR_GENERAL_SOBRANTE")],by.x = "ANIO_EJECUCION", by.y = "ANIO", all = FALSE )
    EVALUAR_PROG_ANIO$CUPO_OFERTADO <- CUPO_OFERTADO
    EVALUAR_PROG_ANIO$CUPO_CALCULADO <- as.integer(CUPO_CALCULADO)
    
    #CALCULO DE CUPOS POR ANIO
    EVALUAR_PROG_ANIO$CUPOS_ANIO <- EVALUAR_PROG_ANIO$VALOR_GENERAL_SOBRANTE / EVALUAR_PROG_ANIO$COSTO_ANIO 
    
    print(paste(" ORDEN_PROG_",ID_PROGRAMA,"MAXIMO",CUPO_OFERTADO,"CALCULADO",CUPO_CALCULADO,"VIGENCIA",min(EVALUAR_PROG_ANIO$CUPOS_ANIO)))
    
    #---------------------------
    # HAY CUPOS POR VIGENCIA   
    #---------------------------
    if(as.integer(min(EVALUAR_PROG_ANIO$CUPOS_ANIO)) > 0 ) {
      
      #------------------------------------------
      # REGLA_1 CUPO_CALCULADO supera CUPO_OFERTADO (NO APLICA PARA PROGRAMAS CON COSTOS EN LA VIGENCIA 2032)
      #------------------------------------------
      if(CUPO_CALCULADO >= CUPO_OFERTADO & min(EVALUAR_PROG_ANIO$CUPOS_ANIO) >= CUPO_OFERTADO){
        print("REGLA_1")
        ORDENAMIENTO_PROG[ORDENAMIENTO_PROG$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_IES"] <- CUPO_OFERTADO
        SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_IES"] <- CUPO_OFERTADO
        
        #COSTO A RESTAR EN EL PRESUPUESTO DE LA IES
        COSTO_CUPOS <- CUPO_OFERTADO * TOTAL_COHORTE
        ORDENAMIENTO_PROG[ORDENAMIENTO_PROG$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_IES"] <- COSTO_CUPOS
        SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_IES"] <- COSTO_CUPOS
        
        #RESTAR VALOR EN PRESUPUESTO IES-NIVEL
        VALOR_IES <- VALOR_IES - COSTO_CUPOS
        IES[IES$ID_IES_NIVEL==ID_IES_NIVEL,"VALOR_SOBRANTE_IES_NIVEL"] <- VALOR_IES
        
        #RESTAR VALOR EN PRESUPUESTO ANUAL
        for (anio in EVALUAR_PROG_ANIO$ANIO_EJECUCION) {
          VALOR_ANIO <- EVALUAR_PROG_ANIO[EVALUAR_PROG_ANIO$ANIO_EJECUCION==anio,"COSTO_ANIO"]
          #print(paste(anio,"cuesta",VALOR_ANIO, "X", CUPO_OFERTADO,"=",VALOR_ANIO * CUPO_OFERTADO))
          VALOR_GENERAL_SOBRANTE <- BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] 
          VALOR_GENERAL_SOBRANTE<-  VALOR_GENERAL_SOBRANTE - (VALOR_ANIO * CUPO_OFERTADO)
          BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] <- VALOR_GENERAL_SOBRANTE
        }
      }#FIN REGLA_1
      else
      #------------------------------------------
      # REGLA_2 CUPO_CALCULADO menor CUPO_OFERTADO (NO APLICA PARA PROGRAMAS CON COSTOS EN LA VIGENCIA 2032)
      #------------------------------------------
      if (CUPO_CALCULADO < CUPO_OFERTADO &  as.integer(CUPO_CALCULADO) > 0 ) {
        #------------------------------------------
        # REGLA_2.1 El cupo minimo por vigencia es mayor al cupo calculado
        #------------------------------------------
        if( min(EVALUAR_PROG_ANIO$CUPOS_ANIO) >= as.integer(CUPO_CALCULADO)) {
          print("REGLA_2")
          ORDENAMIENTO_PROG[ORDENAMIENTO_PROG$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_IES"] <- as.integer(CUPO_CALCULADO)
          SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_IES"] <- as.integer(CUPO_CALCULADO)
          
          #COSTO A RESTAR EN EL PRESUPUESTO DE LA IES
          COSTO_CUPOS <- as.integer(CUPO_CALCULADO) * TOTAL_COHORTE
          ORDENAMIENTO_PROG[ORDENAMIENTO_PROG$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_IES"] <- COSTO_CUPOS
          SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_IES"] <- COSTO_CUPOS
          
          #RESTAR VALOR EN PRESUPUESTO IES-NIVEL
          VALOR_IES <- VALOR_IES - COSTO_CUPOS
          IES[IES$ID_IES_NIVEL==ID_IES_NIVEL,"VALOR_SOBRANTE_IES_NIVEL"] <- VALOR_IES
          
          #RESTAR VALOR EN PRESUPUESTO ANUAL
          for (anio in EVALUAR_PROG_ANIO$ANIO_EJECUCION) {
            VALOR_ANIO <- EVALUAR_PROG_ANIO[EVALUAR_PROG_ANIO$ANIO_EJECUCION==anio,"COSTO_ANIO"]
            #print(paste(anio,"cuesta",VALOR_ANIO, "X", as.integer(CUPO_CALCULADO),"=",VALOR_ANIO * as.integer(CUPO_CALCULADO)))
            VALOR_GENERAL_SOBRANTE <- BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] 
            VALOR_GENERAL_SOBRANTE<-  VALOR_GENERAL_SOBRANTE - (VALOR_ANIO * as.integer(CUPO_CALCULADO))
            BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] <- VALOR_GENERAL_SOBRANTE
          }
        }else
          #------------------------------------------
          # REGLA_2.2 El cupo minimo por vigencia es el que se asigna
          #------------------------------------------
          if(as.integer(min(EVALUAR_PROG_ANIO$CUPOS_ANIO)) > 0){
            
            CUPO_CALCULADO <- min(EVALUAR_PROG_ANIO$CUPOS_ANIO)
            
            print("REGLA_3")
            ORDENAMIENTO_PROG[ORDENAMIENTO_PROG$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_IES"] <- as.integer(CUPO_CALCULADO)
            SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_IES"] <- as.integer(CUPO_CALCULADO)
            
            #COSTO A RESTAR EN EL PRESUPUESTO DE LA IES
            COSTO_CUPOS <- as.integer(CUPO_CALCULADO) * TOTAL_COHORTE
            ORDENAMIENTO_PROG[ORDENAMIENTO_PROG$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_IES"] <- COSTO_CUPOS
            SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_IES"] <- COSTO_CUPOS
            
            #RESTAR VALOR EN PRESUPUESTO IES-NIVEL
            VALOR_IES <- VALOR_IES - COSTO_CUPOS
            IES[IES$ID_IES_NIVEL==ID_IES_NIVEL,"VALOR_SOBRANTE_IES_NIVEL"] <- VALOR_IES
            
            #RESTAR VALOR EN PRESUPUESTO ANUAL
            for (anio in EVALUAR_PROG_ANIO$ANIO_EJECUCION) {
              VALOR_ANIO <- EVALUAR_PROG_ANIO[EVALUAR_PROG_ANIO$ANIO_EJECUCION==anio,"COSTO_ANIO"]
              #print(paste(anio,"cuesta",VALOR_ANIO, "X", as.integer(CUPO_CALCULADO),"=",VALOR_ANIO * as.integer(CUPO_CALCULADO)))
              VALOR_GENERAL_SOBRANTE <- BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] 
              VALOR_GENERAL_SOBRANTE<-  VALOR_GENERAL_SOBRANTE - (VALOR_ANIO * as.integer(CUPO_CALCULADO))
              BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] <- VALOR_GENERAL_SOBRANTE
            }
         }
      } else
      #------------------------------------------
      # REGLA_4 El cupo minimo por vigencia es el que se asigna
      #------------------------------------------
      if(as.integer(min(EVALUAR_PROG_ANIO$CUPOS_ANIO)) > 0 & as.integer(min(EVALUAR_PROG_ANIO$CUPOS_ANIO)) < CUPO_CALCULADO){
        
        CUPO_CALCULADO <- min(EVALUAR_PROG_ANIO$CUPOS_ANIO)
        
        print("REGLA_4")
        ORDENAMIENTO_PROG[ORDENAMIENTO_PROG$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_IES"] <- as.integer(CUPO_CALCULADO)
        SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_IES"] <- as.integer(CUPO_CALCULADO)
        
        #COSTO A RESTAR EN EL PRESUPUESTO DE LA IES
        COSTO_CUPOS <- as.integer(CUPO_CALCULADO) * TOTAL_COHORTE
        ORDENAMIENTO_PROG[ORDENAMIENTO_PROG$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_IES"] <- COSTO_CUPOS
        SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_IES"] <- COSTO_CUPOS
        
        #RESTAR VALOR EN PRESUPUESTO IES-NIVEL
        VALOR_IES <- VALOR_IES - COSTO_CUPOS
        IES[IES$ID_IES_NIVEL==ID_IES_NIVEL,"VALOR_SOBRANTE_IES_NIVEL"] <- VALOR_IES
        
        #RESTAR VALOR EN PRESUPUESTO ANUAL
        for (anio in EVALUAR_PROG_ANIO$ANIO_EJECUCION) {
          VALOR_ANIO <- EVALUAR_PROG_ANIO[EVALUAR_PROG_ANIO$ANIO_EJECUCION==anio,"COSTO_ANIO"]
          #print(paste(anio,"cuesta",VALOR_ANIO, "X", as.integer(CUPO_CALCULADO),"=",VALOR_ANIO * as.integer(CUPO_CALCULADO)))
          VALOR_GENERAL_SOBRANTE <- BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] 
          VALOR_GENERAL_SOBRANTE<-  VALOR_GENERAL_SOBRANTE - (VALOR_ANIO * as.integer(CUPO_CALCULADO))
          BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] <- VALOR_GENERAL_SOBRANTE
        }
      }
      else{
        print(paste("SIN PRESUPUESTO IES - cupo calculado=",CUPO_CALCULADO))
      }
      
    }else
    {
      print(paste("SIN PRESUPUESTO POR VIGENCIA",EVALUAR_PROG_ANIO[EVALUAR_PROG_ANIO$CUPOS_ANIO==min(EVALUAR_PROG_ANIO$CUPOS_ANIO),"ANIO_EJECUCION"],"CUPOS",min(EVALUAR_PROG_ANIO$CUPOS_ANIO))) 
    }
    
  } # CIERRE RECORRIDOS PROGRAMA
  
} # CIERRE RECORRIDO IES - NIVEL

#### PRUEBAS
sum(ORDENAMIENTO_PROG$CUPO_ASIGNADO_IES) #2923
sum(ORDENAMIENTO_PROG$COSTO_CUPOS_ASIGNADO_IES) #$ 101.121.368.129
sum(IES$VALOR_SOBRANTE_IES_NIVEL) # $ 19.848.653.699
sum(ORDENAMIENTO_PROG$COSTO_CUPOS_ASIGNADO_IES) + sum(IES$VALOR_SOBRANTE_IES_NIVEL)
PPTO_MecanismoActual

#===============================================================================
# Paso 3: Asignación del excedente
#===============================================================================

#-------------------------------------------------------------------------------
# SUMA VALOR_SOBRANTE_IES_NIVEL X NIVEL
#-------------------------------------------------------------------------------
EXCEDENTE_NIVEL <- IES %>% group_by(NIVEL_PROGRAMA_SNIES_AJUSTE) %>%  summarise_at(vars(VALOR_SOBRANTE_IES_NIVEL), list(VALOR_SOBRANTE_NIVEL = sum))
EXCEDENTE_NIVEL <- EXCEDENTE_NIVEL %>%  arrange(NIVEL_PROGRAMA_SNIES_AJUSTE) %>%  mutate(ID_NIVEL = row_number())
EXCEDENTE_NIVEL$VALOR_SOBRANTE_NIVEL_ORI <- EXCEDENTE_NIVEL$VALOR_SOBRANTE_NIVEL

#-------------------------------------------------------------------------------
# ELEGIR UNICAMENTE PROGRAMAS CON CUPOS 
#-------------------------------------------------------------------------------
ORDENAMIENTO_PROG$CUPO_PENDIENTES <- ORDENAMIENTO_PROG$CUPOS_SEGÚN_CAPACIDAD - ORDENAMIENTO_PROG$CUPO_ASIGNADO_IES 
ORDENAMIENTO_PROG$CUPO_ASIGNADO_NIVEL <- 0
ORDENAMIENTO_PROG$COSTO_CUPOS_ASIGNADO_NIVEL <- 0

ASIGNACION_NIVEL_PROG <- ORDENAMIENTO_PROG[ORDENAMIENTO_PROG$CUPO_PENDIENTES >0, ]
#UNICAMENTE PARA LOS PROGRAMAS EVALUADOS POR IES
ASIGNACION_NIVEL_PROG <- merge(x=ASIGNACION_NIVEL_PROG, y=IES[,c("COD_IES","NIVEL_PROGRAMA_SNIES_AJUSTE","ID_IES_NIVEL")], by=c("COD_IES","NIVEL_PROGRAMA_SNIES_AJUSTE"), all = FALSE )

#-------------------------------------------------------------------------------
# CALCULO DE CUPOS BOLSA COMUN
# SE RECORRE POR IES y NIVEL PARA PROGRAMAS CON CUPOS
#-------------------------------------------------------------------------------
for (ID_NIVEL in unique(EXCEDENTE_NIVEL$ID_NIVEL)) {
  print(paste("ORDEN_NIVEL ",ID_NIVEL))
  
  EVALUAR_NIVEL <- EXCEDENTE_NIVEL[EXCEDENTE_NIVEL$ID_NIVEL==ID_NIVEL,] 
  
  ## SE LLENA LA SEMILLA UNICAMENTE LOS PROGRAMAS CORRESPONDIENTES A LA IES Y EL NIVEL
  SEMILLA_PROGRAMAS <- ASIGNACION_NIVEL_PROG[ASIGNACION_NIVEL_PROG$NIVEL_PROGRAMA_SNIES_AJUSTE==EVALUAR_NIVEL$NIVEL_PROGRAMA_SNIES_AJUSTE, ]
  
  #ORDENAR PROGRAMAS DE LA SEMILLA
  SEMILLA_PROGRAMAS <-SEMILLA_PROGRAMAS[order(SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG),]
  
  # SE RECORRE LA SEMILLA CON LOS PROGRAMAS DE LA IES POR NIVEL
  for (ID_PROGRAMA in SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG){
   
    EVALUAR_PROG <- SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG==ID_PROGRAMA,]
    
    # SE LLENA VARIABLE CON EL PRESUPUESTO NIVEL (ojo el sobrante es el que se recalcula y tiene en cuenta)
    VALOR_NIVEL <- as.double(EXCEDENTE_NIVEL[EXCEDENTE_NIVEL$ID_NIVEL==ID_NIVEL,"VALOR_SOBRANTE_NIVEL"]) 
    
    #SE CREAN VARIABLES DE CALCULO DE CUPOS (OJO LO PENDIENTE)
    CUPO_OFERTADO <- EVALUAR_PROG$CUPO_PENDIENTES
    CUPO_CALCULADO <- VALOR_NIVEL/EVALUAR_PROG$TOTAL_VALOR_COHORTE_ATENEA
    TOTAL_COHORTE <- EVALUAR_PROG$TOTAL_VALOR_COHORTE_ATENEA
    
    #------------------------
    #CALCULO POR VIGENCIA
    #------------------------
    EVALUAR_PROG_ANIO <- OFERTA_COSTO_EJECUCION_ANUAL[OFERTA_COSTO_EJECUCION_ANUAL$ID==EVALUAR_PROG$ID,]
    #pegamos datos de la bolsa
    EVALUAR_PROG_ANIO <- merge(x=EVALUAR_PROG_ANIO, y=BASE_ANUAL[,c("ANIO","VALOR_GENERAL_SOBRANTE")],by.x = "ANIO_EJECUCION", by.y = "ANIO", all = FALSE )
    EVALUAR_PROG_ANIO$CUPO_OFERTADO <- CUPO_OFERTADO
    EVALUAR_PROG_ANIO$CUPO_CALCULADO <- as.integer(CUPO_CALCULADO)
    
    #CALCULO DE CUPOS POR ANIO
    EVALUAR_PROG_ANIO$CUPOS_ANIO <- EVALUAR_PROG_ANIO$VALOR_GENERAL_SOBRANTE / EVALUAR_PROG_ANIO$COSTO_ANIO 
    print(paste(" ORDEN_PROG_",ID_PROGRAMA,"MAXIMO",CUPO_OFERTADO,"CALCULADO",CUPO_CALCULADO,"VIGENCIA",min(EVALUAR_PROG_ANIO$CUPOS_ANIO)))
    
    #---------------------------
    # HAY CUPOS POR VIGENCIA   
    #---------------------------
    if(as.integer(min(EVALUAR_PROG_ANIO$CUPOS_ANIO)) > 0 ) {
      
      #------------------------------------------
      # REGLA_1 CUPO_CALCULADO supera CUPO_OFERTADO (NO APLICA PARA PROGRAMAS CON COSTOS EN LA VIGENCIA 2032)
      #------------------------------------------
      if(CUPO_CALCULADO >= CUPO_OFERTADO & min(EVALUAR_PROG_ANIO$CUPOS_ANIO) >= CUPO_OFERTADO){
        print("REGLA_1")
        ORDENAMIENTO_PROG[ORDENAMIENTO_PROG$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_NIVEL"] <- CUPO_OFERTADO
        SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_NIVEL"] <- CUPO_OFERTADO
        
        #COSTO A RESTAR EN EL PRESUPUESTO DE LA IES
        COSTO_CUPOS <- CUPO_OFERTADO * TOTAL_COHORTE
        ORDENAMIENTO_PROG[ORDENAMIENTO_PROG$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_NIVEL"] <- COSTO_CUPOS
        SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_NIVEL"] <- COSTO_CUPOS
        
        #RESTAR VALOR EN PRESUPUESTO IES-NIVEL
        VALOR_NIVEL <- VALOR_NIVEL - COSTO_CUPOS
        EXCEDENTE_NIVEL[EXCEDENTE_NIVEL$ID_NIVEL==ID_NIVEL,"VALOR_SOBRANTE_NIVEL"] <- VALOR_NIVEL
        
        #RESTAR VALOR EN PRESUPUESTO ANUAL
        for (anio in EVALUAR_PROG_ANIO$ANIO_EJECUCION) {
          VALOR_ANIO <- EVALUAR_PROG_ANIO[EVALUAR_PROG_ANIO$ANIO_EJECUCION==anio,"COSTO_ANIO"]
          #print(paste(anio,"cuesta",VALOR_ANIO, "X", CUPO_OFERTADO,"=",VALOR_ANIO * CUPO_OFERTADO))
          VALOR_GENERAL_SOBRANTE <- BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] 
          VALOR_GENERAL_SOBRANTE<-  VALOR_GENERAL_SOBRANTE - (VALOR_ANIO * CUPO_OFERTADO)
          BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] <- VALOR_GENERAL_SOBRANTE
        }
      }#FIN REGLA_1
      else
      #------------------------------------------
      # REGLA_2 CUPO_CALCULADO menor CUPO_OFERTADO (NO APLICA PARA PROGRAMAS CON COSTOS EN LA VIGENCIA 2032)
      #------------------------------------------
      if (CUPO_CALCULADO < CUPO_OFERTADO &  as.integer(CUPO_CALCULADO) > 0 ) {
        #------------------------------------------
        # REGLA_2.1 El cupo minimo por vigencia es mayor al cupo calculado
        #------------------------------------------
        if( min(EVALUAR_PROG_ANIO$CUPOS_ANIO) >= as.integer(CUPO_CALCULADO)) {
          print("REGLA_2")
          ORDENAMIENTO_PROG[ORDENAMIENTO_PROG$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_NIVEL"] <- as.integer(CUPO_CALCULADO)
          SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_NIVEL"] <- as.integer(CUPO_CALCULADO)
          
          #COSTO A RESTAR EN EL PRESUPUESTO DE LA IES
          COSTO_CUPOS <- as.integer(CUPO_CALCULADO) * TOTAL_COHORTE
          ORDENAMIENTO_PROG[ORDENAMIENTO_PROG$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_NIVEL"] <- COSTO_CUPOS
          SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_NIVEL"] <- COSTO_CUPOS
          
          #RESTAR VALOR EN PRESUPUESTO IES-NIVEL
          VALOR_NIVEL <- VALOR_NIVEL - COSTO_CUPOS
          EXCEDENTE_NIVEL[EXCEDENTE_NIVEL$ID_NIVEL==ID_NIVEL,"VALOR_SOBRANTE_NIVEL"] <- VALOR_NIVEL
          
          #RESTAR VALOR EN PRESUPUESTO ANUAL
          for (anio in EVALUAR_PROG_ANIO$ANIO_EJECUCION) {
            VALOR_ANIO <- EVALUAR_PROG_ANIO[EVALUAR_PROG_ANIO$ANIO_EJECUCION==anio,"COSTO_ANIO"]
            #print(paste(anio,"cuesta",VALOR_ANIO, "X", as.integer(CUPO_CALCULADO),"=",VALOR_ANIO * as.integer(CUPO_CALCULADO)))
            VALOR_GENERAL_SOBRANTE <- BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] 
            VALOR_GENERAL_SOBRANTE<-  VALOR_GENERAL_SOBRANTE - (VALOR_ANIO * as.integer(CUPO_CALCULADO))
            BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] <- VALOR_GENERAL_SOBRANTE
          }
        }else
          #------------------------------------------
        # REGLA_2.2 El cupo minimo por vigencia es el que se asigna
        #------------------------------------------
        if(as.integer(min(EVALUAR_PROG_ANIO$CUPOS_ANIO)) > 0){
          
          CUPO_CALCULADO <- min(EVALUAR_PROG_ANIO$CUPOS_ANIO)
          
          print("REGLA_3")
          ORDENAMIENTO_PROG[ORDENAMIENTO_PROG$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_NIVEL"] <- as.integer(CUPO_CALCULADO)
          SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_NIVEL"] <- as.integer(CUPO_CALCULADO)
          
          #COSTO A RESTAR EN EL PRESUPUESTO DE LA IES
          COSTO_CUPOS <- as.integer(CUPO_CALCULADO) * TOTAL_COHORTE
          ORDENAMIENTO_PROG[ORDENAMIENTO_PROG$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_NIVEL"] <- COSTO_CUPOS
          SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_NIVEL"] <- COSTO_CUPOS
          
          #RESTAR VALOR EN PRESUPUESTO IES-NIVEL
          VALOR_NIVEL <- VALOR_NIVEL - COSTO_CUPOS
          EXCEDENTE_NIVEL[EXCEDENTE_NIVEL$ID_NIVEL==ID_NIVEL,"VALOR_SOBRANTE_NIVEL"] <- VALOR_NIVEL
          
          #RESTAR VALOR EN PRESUPUESTO ANUAL
          for (anio in EVALUAR_PROG_ANIO$ANIO_EJECUCION) {
            VALOR_ANIO <- EVALUAR_PROG_ANIO[EVALUAR_PROG_ANIO$ANIO_EJECUCION==anio,"COSTO_ANIO"]
            #print(paste(anio,"cuesta",VALOR_ANIO, "X", as.integer(CUPO_CALCULADO),"=",VALOR_ANIO * as.integer(CUPO_CALCULADO)))
            VALOR_GENERAL_SOBRANTE <- BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] 
            VALOR_GENERAL_SOBRANTE<-  VALOR_GENERAL_SOBRANTE - (VALOR_ANIO * as.integer(CUPO_CALCULADO))
            BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] <- VALOR_GENERAL_SOBRANTE
          }
        }
      } else
        #------------------------------------------
      # REGLA_4 El cupo minimo por vigencia es el que se asigna
      #------------------------------------------
      if(as.integer(min(EVALUAR_PROG_ANIO$CUPOS_ANIO)) > 0 & as.integer(min(EVALUAR_PROG_ANIO$CUPOS_ANIO)) < CUPO_CALCULADO){
        
        CUPO_CALCULADO <- min(EVALUAR_PROG_ANIO$CUPOS_ANIO)
        
        print("REGLA_4")
        ORDENAMIENTO_PROG[ORDENAMIENTO_PROG$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_NIVEL"] <- as.integer(CUPO_CALCULADO)
        SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_NIVEL"] <- as.integer(CUPO_CALCULADO)
        
        #COSTO A RESTAR EN EL PRESUPUESTO DE LA IES
        COSTO_CUPOS <- as.integer(CUPO_CALCULADO) * TOTAL_COHORTE
        ORDENAMIENTO_PROG[ORDENAMIENTO_PROG$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_NIVEL"] <- COSTO_CUPOS
        SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_NIVEL"] <- COSTO_CUPOS
        
        #RESTAR VALOR EN PRESUPUESTO IES-NIVEL
        VALOR_NIVEL <- VALOR_NIVEL - COSTO_CUPOS
        EXCEDENTE_NIVEL[EXCEDENTE_NIVEL$ID_NIVEL==ID_NIVEL,"VALOR_SOBRANTE_NIVEL"] <- VALOR_NIVEL
        
        #RESTAR VALOR EN PRESUPUESTO ANUAL
        for (anio in EVALUAR_PROG_ANIO$ANIO_EJECUCION) {
          VALOR_ANIO <- EVALUAR_PROG_ANIO[EVALUAR_PROG_ANIO$ANIO_EJECUCION==anio,"COSTO_ANIO"]
          #print(paste(anio,"cuesta",VALOR_ANIO, "X", as.integer(CUPO_CALCULADO),"=",VALOR_ANIO * as.integer(CUPO_CALCULADO)))
          VALOR_GENERAL_SOBRANTE <- BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] 
          VALOR_GENERAL_SOBRANTE<-  VALOR_GENERAL_SOBRANTE - (VALOR_ANIO * as.integer(CUPO_CALCULADO))
          BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] <- VALOR_GENERAL_SOBRANTE
        }
      }
      else{
        print(paste("SIN PRESUPUESTO IES - cupo calculado=",CUPO_CALCULADO))
      }
      
    }
    else
      {
        print(paste("SIN PRESUPUESTO POR VIGENCIA",EVALUAR_PROG_ANIO[EVALUAR_PROG_ANIO$CUPOS_ANIO==min(EVALUAR_PROG_ANIO$CUPOS_ANIO),"ANIO_EJECUCION"],"CUPOS",min(EVALUAR_PROG_ANIO$CUPOS_ANIO))) 
      }
    
  } # CIERRE RECORRIDOS PROGRAMA
  
} # CIERRE RECORRIDO IES - NIVEL

sum(ORDENAMIENTO_PROG$CUPO_ASIGNADO_NIVEL) # 223
sum(ORDENAMIENTO_PROG$COSTO_CUPOS_ASIGNADO_NIVEL) # $9.633.740.134


#-------------------------------------------------------------------------------
# Resultado final Oferta General
# CALCULO FINAL DE CUPOS Y TOTALES
# SUMATORIA DE RESULTADO PASO 2 y PASO 3
#-------------------------------------------------------------------------------
ORDENAMIENTO_PROG$CUPOS_ASIGNADOS_MECANISMO_ISOES <- ORDENAMIENTO_PROG$CUPO_ASIGNADO_IES + ORDENAMIENTO_PROG$CUPO_ASIGNADO_NIVEL
ORDENAMIENTO_PROG$COSTO_CUPOS_ASIGNADOS_MECANISMO_ISOES <- ORDENAMIENTO_PROG$COSTO_CUPOS_ASIGNADO_IES + ORDENAMIENTO_PROG$COSTO_CUPOS_ASIGNADO_NIVEL

sum(ORDENAMIENTO_PROG$CUPO_ASIGNADO_IES)
sum(ORDENAMIENTO_PROG$COSTO_CUPOS_ASIGNADO_IES)

sum(ORDENAMIENTO_PROG$CUPOS_ASIGNADOS_MECANISMO_ISOES)
sum(ORDENAMIENTO_PROG$COSTO_CUPOS_ASIGNADOS_MECANISMO_ISOES)
sum(EXCEDENTE_NIVEL$VALOR_SOBRANTE_NIVEL)
sum(ORDENAMIENTO_PROG$COSTO_CUPOS_ASIGNADOS_MECANISMO_ISOES) + sum(EXCEDENTE_NIVEL$VALOR_SOBRANTE_NIVEL)
#PRUEBA
PPTO_MecanismoActual

# actualizar cupos pendiente
ORDENAMIENTO_PROG$CUPO_PENDIENTES <- ORDENAMIENTO_PROG$CUPOS_SEGÚN_CAPACIDAD - ORDENAMIENTO_PROG$CUPOS_ASIGNADOS_MECANISMO_ISOES


#===============================================================================
#-------------------------------------------------------------------------------
# COMPONENTE DEMANDA SOCIAL
#-------------------------------------------------------------------------------
#===============================================================================

EXCEDENTE_MECANISMO_ISOES <- sum(EXCEDENTE_NIVEL$VALOR_SOBRANTE_NIVEL)

# RECALCULO PRESUPUESTO DEMANDA SOCIAL
PPTO_DemandaSocial
EXCEDENTE_MECANISMO_ISOES
PPTO_DemandaSocial <- PPTO_DemandaSocial + EXCEDENTE_MECANISMO_ISOES
PPTO_DemandaSocial

BASE_ANUAL$SOBRANTE_MECANISMO_ISOES <- BASE_ANUAL$VALOR_GENERAL_SOBRANTE
BASE_ANUAL$VALOR_GENERAL_SOBRANTE <- BASE_ANUAL$`Escenario 1` *.1 + BASE_ANUAL$SOBRANTE_MECANISMO_ISOES 

# CREAR DATAFRAME CON PROGRAMAS PARA RECORRER POR DEMANDA SOCIAL
CONTEO_DEMANDA_SOCIAL <- ORDENAMIENTO_PROG %>% group_by(CINE_F_2013_AC_CAMPO_DETALLADO,NIVEL_PROGRAMA_SNIES_AJUSTE)  %>%  summarise_at(vars(CUPOS_ASIGNADOS_MECANISMO_ISOES), list(TOTAL_CUPOS_MECANISMO_ISOES= sum))

# 1.1 Valido programas sin cupos
# OJO SE AJUSTA A MENOR A 6 CUPOS
CONTEO_DEMANDA_SOCIAL <- CONTEO_DEMANDA_SOCIAL[CONTEO_DEMANDA_SOCIAL$TOTAL_CUPOS_MECANISMO_ISOES <6,]

# OJO DEBE TENER CUPOS PENDIENTES DE ACUERDO A SU CAPACIDAD
OFERTA_DEMANDA_SOCIAL <- merge(x=CONTEO_DEMANDA_SOCIAL, y=ORDENAMIENTO_PROG[ORDENAMIENTO_PROG$CUPO_PENDIENTES>0,], by =c("CINE_F_2013_AC_CAMPO_DETALLADO","NIVEL_PROGRAMA_SNIES_AJUSTE"), all = FALSE)


OFERTA_DEMANDA_SOCIAL <-OFERTA_DEMANDA_SOCIAL[OFERTA_DEMANDA_SOCIAL$CUPO_PENDIENTES > 0,]

# 1.2 Valido que registros tengan datos en demanda social
OFERTA_DEMANDA_SOCIAL <- OFERTA_DEMANDA_SOCIAL[!is.na(OFERTA_DEMANDA_SOCIAL$DH_INDICADOR_DEMANDA_SOCIAL),]
cro(OFERTA_DEMANDA_SOCIAL$`DH_PERCENTIL_50_(POR_ENCIMA_/_POR_DEBAJO)`)

# 1.3 programas por encima del percentil 50 de acuerdo al nivel
OFERTA_DEMANDA_SOCIAL <- OFERTA_DEMANDA_SOCIAL[OFERTA_DEMANDA_SOCIAL$`DH_PERCENTIL_50_(POR_ENCIMA_/_POR_DEBAJO)`=="POR ENCIMA PERCENTIL 50",]

# PRUEBA
OFERTA_DEMANDA_SOCIAL$PRUEBA <- OFERTA_DEMANDA_SOCIAL$CUPOS_SEGÚN_CAPACIDAD == (OFERTA_DEMANDA_SOCIAL$CUPOS_ASIGNADOS_MECANISMO_ISOES + OFERTA_DEMANDA_SOCIAL$CUPO_PENDIENTES)
cro(OFERTA_DEMANDA_SOCIAL$PRUEBA)

#===============================================================================
#Paso 1.1: Presupuesto CINE y Nivel (% según beneficiarios JE2)
#===============================================================================

#TOTAL DE BENEFICARIO POR CINE Y NIVEL
CINE_NIVEL <- unique(OFERTA_DEMANDA_SOCIAL[,c("CINE_F_2013_AC_CAMPO_DETALLADO","NIVEL_PROGRAMA_SNIES_AJUSTE","DH_INSCRITOS")])
sum(CINE_NIVEL$DH_INSCRITOS)


#TOTAL DE BENEFICARIO POR NIVEL
CINE <- CINE_NIVEL %>% group_by(NIVEL_PROGRAMA_SNIES_AJUSTE)  %>%  summarise_at(vars(DH_INSCRITOS), list(TOTAL_BENEF_NIVEL= sum))
sum(CINE$TOTAL_BENEF_NIVEL)

# PEGAR TOTAL POR NIVEL
CINE_NIVEL<- merge(x=CINE_NIVEL, y=CINE, by = "NIVEL_PROGRAMA_SNIES_AJUSTE", all = FALSE)
CINE_NIVEL$DISTRIBUCION_CINE_NIVEL  <- CINE_NIVEL$DH_INSCRITOS/ CINE_NIVEL$TOTAL_BENEF_NIVEL
sum(CINE_NIVEL$DISTRIBUCION_CINE_NIVEL)

#-------------------------------------------------------------------------------
# DISTRIBUCION BOLSA RECURSOS 
#-------------------------------------------------------------------------------
PPTO_DemandaSocial

#ESCENARIO_1
PPTO_DemandaSocial_TYT <- PPTO_DemandaSocial * .05
PPTO_DemandaSocial_UNI <- PPTO_DemandaSocial * .95
sum(PPTO_DemandaSocial_TYT+PPTO_DemandaSocial_UNI)

#CREAR PRESUPUESTO A DISTRIBUIR EN CINE_NIVEL
CINE_NIVEL$PPTO_DemandaSocial <- 0
CINE_NIVEL[CINE_NIVEL$NIVEL_PROGRAMA_SNIES_AJUSTE=="TYT", "PPTO_DemandaSocial"] <- PPTO_DemandaSocial_TYT
CINE_NIVEL[CINE_NIVEL$NIVEL_PROGRAMA_SNIES_AJUSTE=="UNIVERSITARIO", "PPTO_DemandaSocial"] <- PPTO_DemandaSocial_UNI


#-------------------------------------------------------------------------------
# VALOR DISTRIBUCION CINE X NIVEL
#-------------------------------------------------------------------------------

CINE_NIVEL$VALOR_DISTRIBUCION_CINE_NIVEL <- CINE_NIVEL$DISTRIBUCION_CINE_NIVEL * CINE_NIVEL$PPTO_DemandaSocial
sum(CINE_NIVEL$VALOR_DISTRIBUCION_CINE_NIVEL)
PPTO_DemandaSocial

# Creación identificar de registro CINE NIVEL para recorridos
#colnames(JE2_BENEF_IES_NIVEL)[colnames(JE2_BENEF_IES_NIVEL)=="CÓDIGO_INSTITUCIÓN_CORTE"] <-"SNIES_PADRE"
CINE_NIVEL <- CINE_NIVEL %>%  arrange(CINE_F_2013_AC_CAMPO_DETALLADO,NIVEL_PROGRAMA_SNIES_AJUSTE) %>%  mutate(ID_CINE_NIVEL = row_number())

sum(CINE_NIVEL$VALOR_DISTRIBUCION_CINE_NIVEL)
PPTO_DemandaSocial

# CONSTRUCCION DE BOLSAS Recurso Excedente
CINE_NIVEL$VALOR_SOBRANTE_CINE_NIVEL <- CINE_NIVEL$VALOR_DISTRIBUCION_CINE_NIVEL
OFERTA_DEMANDA_SOCIAL$CUPO_ASIGNADO_CINE <- 0
OFERTA_DEMANDA_SOCIAL$COSTO_CUPOS_ASIGNADO_CINE <- 0

#-------------------------------------------------------------------------------
# CALCULO DE CUPOS
# SE RECORRE POR CINE y nivel
#-------------------------------------------------------------------------------
for (ID_CINE_NIVEL in unique(CINE_NIVEL$ID_CINE_NIVEL)) {
  print(paste("ORDEN_CINE_",ID_CINE_NIVEL))
  
  # CINE QUE SE VA A RECORRER SUS PROGRAMAS
  EVALUAR_CINE <- CINE_NIVEL[CINE_NIVEL$ID_CINE_NIVEL==ID_CINE_NIVEL,]
  print(paste(EVALUAR_CINE$CINE_F_2013_AC_CAMPO_DETALLADO, EVALUAR_CINE$NIVEL_PROGRAMA_SNIES_AJUSTE, EVALUAR_CINE$VALOR_SOBRANTE_CINE_NIVEL,sep = "|"))
  
  ## SE LLENA LA SEMILLA UNICAMENTE LOS PROGRAMAS CORRESPONDIENTES AL CINE Y EL NIVEL
  SEMILLA_PROGRAMAS <- OFERTA_DEMANDA_SOCIAL[OFERTA_DEMANDA_SOCIAL$CINE_F_2013_AC_CAMPO_DETALLADO==EVALUAR_CINE$CINE_F_2013_AC_CAMPO_DETALLADO & OFERTA_DEMANDA_SOCIAL$NIVEL_PROGRAMA_SNIES_AJUSTE==EVALUAR_CINE$NIVEL_PROGRAMA_SNIES_AJUSTE, ]
  
  #ORDENAR PROGRAMAS DE LA SEMILLA
  SEMILLA_PROGRAMAS <-SEMILLA_PROGRAMAS[order(SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG),]
  
  # SE RECORRE LA SEMILLA CON LOS PROGRAMAS DE LA CINE POR NIVEL
  for (ID_PROGRAMA in SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG){
   
    EVALUAR_PROG <- SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG==ID_PROGRAMA,]
    
    # SE LLENA VARIABLE CON EL PRESUPUESTO DE LA CINE - NIVEL (ojo el sobrante es el que se recalcula y tiene en cuenta)
    VALOR_CINE <- CINE_NIVEL[CINE_NIVEL$ID_CINE_NIVEL==ID_CINE_NIVEL,"VALOR_SOBRANTE_CINE_NIVEL"]
    
    #SE CREAN VARIABLES DE CALCULO DE CUPOS
    CUPO_OFERTADO <- EVALUAR_PROG$CUPO_PENDIENTES
    CUPO_CALCULADO <- VALOR_CINE/EVALUAR_PROG$TOTAL_VALOR_COHORTE_ATENEA
    TOTAL_COHORTE <- EVALUAR_PROG$TOTAL_VALOR_COHORTE_ATENEA
    
    #------------------------
    #CALCULO POR VIGENCIA
    #------------------------
    EVALUAR_PROG_ANIO <- OFERTA_COSTO_EJECUCION_ANUAL[OFERTA_COSTO_EJECUCION_ANUAL$ID==EVALUAR_PROG$ID,]
    #pegamos datos de la bolsa
    EVALUAR_PROG_ANIO <- merge(x=EVALUAR_PROG_ANIO, y=BASE_ANUAL[,c("ANIO","VALOR_GENERAL_SOBRANTE")],by.x = "ANIO_EJECUCION", by.y = "ANIO", all = FALSE )
    EVALUAR_PROG_ANIO$CUPO_OFERTADO <- CUPO_OFERTADO
    EVALUAR_PROG_ANIO$CUPO_CALCULADO <- as.integer(CUPO_CALCULADO)
    
    #CALCULO DE CUPOS POR ANIO
    EVALUAR_PROG_ANIO$CUPOS_ANIO <- EVALUAR_PROG_ANIO$VALOR_GENERAL_SOBRANTE / EVALUAR_PROG_ANIO$COSTO_ANIO 
    
    print(paste(" ORDEN_PROG_",ID_PROGRAMA,"MAXIMO",CUPO_OFERTADO,"CALCULADO",CUPO_CALCULADO,"VIGENCIA",min(EVALUAR_PROG_ANIO$CUPOS_ANIO)))
    
    #---------------------------
    # HAY CUPOS POR VIGENCIA   
    #---------------------------
    if(as.integer(min(EVALUAR_PROG_ANIO$CUPOS_ANIO)) > 0 ) {
      
      #------------------------------------------
      # REGLA_1 CUPO_CALCULADO supera CUPO_OFERTADO (NO APLICA PARA PROGRAMAS CON COSTOS EN LA VIGENCIA 2032)
      #------------------------------------------
      if(CUPO_CALCULADO >= CUPO_OFERTADO & min(EVALUAR_PROG_ANIO$CUPOS_ANIO) >= CUPO_OFERTADO){
        print("REGLA_1")
        OFERTA_DEMANDA_SOCIAL[OFERTA_DEMANDA_SOCIAL$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_CINE"] <- CUPO_OFERTADO
        SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_CINE"] <- CUPO_OFERTADO
        
        #COSTO A RESTAR EN EL PRESUPUESTO DE LA IES
        COSTO_CUPOS <- CUPO_OFERTADO * TOTAL_COHORTE
        OFERTA_DEMANDA_SOCIAL[OFERTA_DEMANDA_SOCIAL$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_CINE"] <- COSTO_CUPOS
        SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_CINE"] <- COSTO_CUPOS
        
        #RESTAR VALOR EN PRESUPUESTO CINE-NIVEL
        VALOR_CINE <- VALOR_CINE - COSTO_CUPOS
        CINE_NIVEL[CINE_NIVEL$ID_CINE_NIVEL==ID_CINE_NIVEL,"VALOR_SOBRANTE_CINE_NIVEL"] <- VALOR_CINE
        
        #RESTAR VALOR EN PRESUPUESTO ANUAL
        for (anio in EVALUAR_PROG_ANIO$ANIO_EJECUCION) {
          VALOR_ANIO <- EVALUAR_PROG_ANIO[EVALUAR_PROG_ANIO$ANIO_EJECUCION==anio,"COSTO_ANIO"]
          #print(paste(anio,"cuesta",VALOR_ANIO, "X", CUPO_OFERTADO,"=",VALOR_ANIO * CUPO_OFERTADO))
          VALOR_GENERAL_SOBRANTE <- BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] 
          VALOR_GENERAL_SOBRANTE<-  VALOR_GENERAL_SOBRANTE - (VALOR_ANIO * CUPO_OFERTADO)
          BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] <- VALOR_GENERAL_SOBRANTE
        }
      }#FIN REGLA_1
      else
      #------------------------------------------
      # REGLA_2 CUPO_CALCULADO menor CUPO_OFERTADO (NO APLICA PARA PROGRAMAS CON COSTOS EN LA VIGENCIA 2032)
      #------------------------------------------
      if (CUPO_CALCULADO < CUPO_OFERTADO &  as.integer(CUPO_CALCULADO) > 0 ) {
        #------------------------------------------
        # REGLA_2.1 El cupo minimo por vigencia es mayor al cupo calculado
        #------------------------------------------
        if( min(EVALUAR_PROG_ANIO$CUPOS_ANIO) >= as.integer(CUPO_CALCULADO)) {
          print("REGLA_2")
          OFERTA_DEMANDA_SOCIAL[OFERTA_DEMANDA_SOCIAL$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_CINE"] <- as.integer(CUPO_CALCULADO)
          SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_CINE"] <- as.integer(CUPO_CALCULADO)
          
          #COSTO A RESTAR EN EL PRESUPUESTO DE LA IES
          COSTO_CUPOS <- as.integer(CUPO_CALCULADO) * TOTAL_COHORTE
          OFERTA_DEMANDA_SOCIAL[OFERTA_DEMANDA_SOCIAL$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_CINE"] <- COSTO_CUPOS
          SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_CINE"] <- COSTO_CUPOS
          
          #RESTAR VALOR EN PRESUPUESTO CINE-NIVEL
          VALOR_CINE <- VALOR_CINE - COSTO_CUPOS
          CINE_NIVEL[CINE_NIVEL$ID_CINE_NIVEL==ID_CINE_NIVEL,"VALOR_SOBRANTE_CINE_NIVEL"] <- VALOR_CINE
          
          #RESTAR VALOR EN PRESUPUESTO ANUAL
          for (anio in EVALUAR_PROG_ANIO$ANIO_EJECUCION) {
            VALOR_ANIO <- EVALUAR_PROG_ANIO[EVALUAR_PROG_ANIO$ANIO_EJECUCION==anio,"COSTO_ANIO"]
            #print(paste(anio,"cuesta",VALOR_ANIO, "X", as.integer(CUPO_CALCULADO),"=",VALOR_ANIO * as.integer(CUPO_CALCULADO)))
            VALOR_GENERAL_SOBRANTE <- BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] 
            VALOR_GENERAL_SOBRANTE<-  VALOR_GENERAL_SOBRANTE - (VALOR_ANIO * as.integer(CUPO_CALCULADO))
            BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] <- VALOR_GENERAL_SOBRANTE
          }
        }else
          #------------------------------------------
        # REGLA_2.2 El cupo minimo por vigencia es el que se asigna
        #------------------------------------------
        if(as.integer(min(EVALUAR_PROG_ANIO$CUPOS_ANIO)) > 0){
          
          CUPO_CALCULADO <- min(EVALUAR_PROG_ANIO$CUPOS_ANIO)
          
          print("REGLA_3")
          OFERTA_DEMANDA_SOCIAL[OFERTA_DEMANDA_SOCIAL$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_CINE"] <- as.integer(CUPO_CALCULADO)
          SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_CINE"] <- as.integer(CUPO_CALCULADO)
          
          #COSTO A RESTAR EN EL PRESUPUESTO DE LA IES
          COSTO_CUPOS <- as.integer(CUPO_CALCULADO) * TOTAL_COHORTE
          OFERTA_DEMANDA_SOCIAL[OFERTA_DEMANDA_SOCIAL$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_CINE"] <- COSTO_CUPOS
          SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_CINE"] <- COSTO_CUPOS
          
          #RESTAR VALOR EN PRESUPUESTO CINE-NIVEL
          VALOR_CINE <- VALOR_CINE - COSTO_CUPOS
          CINE_NIVEL[CINE_NIVEL$ID_CINE_NIVEL==ID_CINE_NIVEL,"VALOR_SOBRANTE_CINE_NIVEL"] <- VALOR_CINE
          
          #RESTAR VALOR EN PRESUPUESTO ANUAL
          for (anio in EVALUAR_PROG_ANIO$ANIO_EJECUCION) {
            VALOR_ANIO <- EVALUAR_PROG_ANIO[EVALUAR_PROG_ANIO$ANIO_EJECUCION==anio,"COSTO_ANIO"]
            #print(paste(anio,"cuesta",VALOR_ANIO, "X", as.integer(CUPO_CALCULADO),"=",VALOR_ANIO * as.integer(CUPO_CALCULADO)))
            VALOR_GENERAL_SOBRANTE <- BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] 
            VALOR_GENERAL_SOBRANTE<-  VALOR_GENERAL_SOBRANTE - (VALOR_ANIO * as.integer(CUPO_CALCULADO))
            BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] <- VALOR_GENERAL_SOBRANTE
          }
        }
      } else
        #------------------------------------------
      # REGLA_4 El cupo minimo por vigencia es el que se asigna
      #------------------------------------------
      if(as.integer(min(EVALUAR_PROG_ANIO$CUPOS_ANIO)) > 0 & as.integer(min(EVALUAR_PROG_ANIO$CUPOS_ANIO)) < CUPO_CALCULADO){
        
        CUPO_CALCULADO <- min(EVALUAR_PROG_ANIO$CUPOS_ANIO)
        
        print("REGLA_4")
        OFERTA_DEMANDA_SOCIAL[OFERTA_DEMANDA_SOCIAL$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_CINE"] <- as.integer(CUPO_CALCULADO)
        SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_CINE"] <- as.integer(CUPO_CALCULADO)
        
        #COSTO A RESTAR EN EL PRESUPUESTO DE LA IES
        COSTO_CUPOS <- as.integer(CUPO_CALCULADO) * TOTAL_COHORTE
        OFERTA_DEMANDA_SOCIAL[OFERTA_DEMANDA_SOCIAL$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_CINE"] <- COSTO_CUPOS
        SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_CINE"] <- COSTO_CUPOS
        
        #RESTAR VALOR EN PRESUPUESTO CINE-NIVEL
        VALOR_CINE <- VALOR_CINE - COSTO_CUPOS
        CINE_NIVEL[CINE_NIVEL$ID_CINE_NIVEL==ID_CINE_NIVEL,"VALOR_SOBRANTE_CINE_NIVEL"] <- VALOR_CINE
        
        #RESTAR VALOR EN PRESUPUESTO ANUAL
        for (anio in EVALUAR_PROG_ANIO$ANIO_EJECUCION) {
          VALOR_ANIO <- EVALUAR_PROG_ANIO[EVALUAR_PROG_ANIO$ANIO_EJECUCION==anio,"COSTO_ANIO"]
          #print(paste(anio,"cuesta",VALOR_ANIO, "X", as.integer(CUPO_CALCULADO),"=",VALOR_ANIO * as.integer(CUPO_CALCULADO)))
          VALOR_GENERAL_SOBRANTE <- BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] 
          VALOR_GENERAL_SOBRANTE<-  VALOR_GENERAL_SOBRANTE - (VALOR_ANIO * as.integer(CUPO_CALCULADO))
          BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] <- VALOR_GENERAL_SOBRANTE
        }
      }
      else{
        print(paste("SIN PRESUPUESTO IES - cupo calculado=",CUPO_CALCULADO))
      }
      
    }else
    {
      print(paste("SIN PRESUPUESTO POR VIGENCIA",EVALUAR_PROG_ANIO[EVALUAR_PROG_ANIO$CUPOS_ANIO==min(EVALUAR_PROG_ANIO$CUPOS_ANIO),"ANIO_EJECUCION"],"CUPOS",min(EVALUAR_PROG_ANIO$CUPOS_ANIO))) 
    }
    
  } # CIERRE RECORRIDOS PROGRAMA
  
} # CIERRE RECORRIDO CINE - NIVEL

#### PRUEBAS
sum(OFERTA_DEMANDA_SOCIAL$CUPO_ASIGNADO_CINE) #376
sum(OFERTA_DEMANDA_SOCIAL$COSTO_CUPOS_ASIGNADO_CINE) #$ 11.594.054.617
sum(CINE_NIVEL$VALOR_SOBRANTE_CINE_NIVEL) # $ 12.061.972.484
sum(OFERTA_DEMANDA_SOCIAL$COSTO_CUPOS_ASIGNADO_CINE) + sum(CINE_NIVEL$VALOR_SOBRANTE_CINE_NIVEL)
PPTO_DemandaSocial


#===============================================================================
# Paso 3: Asignación del excedente
#===============================================================================

#-------------------------------------------------------------------------------
# SUMA VALOR_SOBRANTE_CINE_NIVEL X NIVEL
#-------------------------------------------------------------------------------
EXCEDENTE_NIVEL <- CINE_NIVEL %>% group_by(NIVEL_PROGRAMA_SNIES_AJUSTE) %>%  summarise_at(vars(VALOR_SOBRANTE_CINE_NIVEL), list(VALOR_SOBRANTE_NIVEL = sum))
EXCEDENTE_NIVEL <- EXCEDENTE_NIVEL %>%  arrange(NIVEL_PROGRAMA_SNIES_AJUSTE) %>%  mutate(ID_NIVEL = row_number())
EXCEDENTE_NIVEL$VALOR_SOBRANTE_NIVEL_ORI <- EXCEDENTE_NIVEL$VALOR_SOBRANTE_NIVEL

#-------------------------------------------------------------------------------
# ELEGIR UNICAMENTE PROGRAMAS CON CUPOS 
#-------------------------------------------------------------------------------
OFERTA_DEMANDA_SOCIAL$CUPO_PENDIENTES <- OFERTA_DEMANDA_SOCIAL$CUPOS_SEGÚN_CAPACIDAD - ( OFERTA_DEMANDA_SOCIAL$CUPOS_ASIGNADOS_MECANISMO_ISOES + OFERTA_DEMANDA_SOCIAL$CUPO_ASIGNADO_CINE) 
OFERTA_DEMANDA_SOCIAL$CUPO_ASIGNADO_NIVEL_DH <- 0
OFERTA_DEMANDA_SOCIAL$COSTO_CUPOS_ASIGNADO_NIVEL_DH <- 0

ASIGNACION_NIVEL_PROG <- OFERTA_DEMANDA_SOCIAL[OFERTA_DEMANDA_SOCIAL$CUPO_PENDIENTES >0, ]

#-------------------------------------------------------------------------------
# CALCULO DE CUPOS BOLSA COMUN
# SE RECORRE POR IES y NIVEL PARA PROGRAMAS CON CUPOS
#-------------------------------------------------------------------------------
for (ID_NIVEL in unique(EXCEDENTE_NIVEL$ID_NIVEL)) {
  print(paste("ORDEN_NIVEL ",ID_NIVEL))
  
  EVALUAR_NIVEL <- EXCEDENTE_NIVEL[EXCEDENTE_NIVEL$ID_NIVEL==ID_NIVEL,] 
  
  ## SE LLENA LA SEMILLA UNICAMENTE LOS PROGRAMAS CORRESPONDIENTES A LA IES Y EL NIVEL
  SEMILLA_PROGRAMAS <- ASIGNACION_NIVEL_PROG[ASIGNACION_NIVEL_PROG$NIVEL_PROGRAMA_SNIES_AJUSTE==EVALUAR_NIVEL$NIVEL_PROGRAMA_SNIES_AJUSTE, ]
  
  #ORDENAR PROGRAMAS DE LA SEMILLA
  SEMILLA_PROGRAMAS <-SEMILLA_PROGRAMAS[order(SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG),]
  
  # SE RECORRE LA SEMILLA CON LOS PROGRAMAS DE LA IES POR NIVEL
  for (ID_PROGRAMA in SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG){
    print(paste(" ORDEN_PROG_",ID_PROGRAMA))
    EVALUAR_PROG <- SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG==ID_PROGRAMA,]
    
    # SE LLENA VARIABLE CON EL PRESUPUESTO NIVEL (ojo el sobrante es el que se recalcula y tiene en cuenta)
    VALOR_NIVEL <- as.double(EXCEDENTE_NIVEL[EXCEDENTE_NIVEL$ID_NIVEL==ID_NIVEL,"VALOR_SOBRANTE_NIVEL"]) 
    
    #SE CREAN VARIABLES DE CALCULO DE CUPOS (OJO LO PENDIENTE)
    CUPO_OFERTADO <- EVALUAR_PROG$CUPO_PENDIENTES
    CUPO_CALCULADO <- VALOR_NIVEL/EVALUAR_PROG$TOTAL_VALOR_COHORTE_ATENEA
    TOTAL_COHORTE <- EVALUAR_PROG$TOTAL_VALOR_COHORTE_ATENEA
    
    #------------------------
    #CALCULO POR VIGENCIA
    #------------------------
    EVALUAR_PROG_ANIO <- OFERTA_COSTO_EJECUCION_ANUAL[OFERTA_COSTO_EJECUCION_ANUAL$ID==EVALUAR_PROG$ID,]
    #pegamos datos de la bolsa
    EVALUAR_PROG_ANIO <- merge(x=EVALUAR_PROG_ANIO, y=BASE_ANUAL[,c("ANIO","VALOR_GENERAL_SOBRANTE")],by.x = "ANIO_EJECUCION", by.y = "ANIO", all = FALSE )
    EVALUAR_PROG_ANIO$CUPO_OFERTADO <- CUPO_OFERTADO
    EVALUAR_PROG_ANIO$CUPO_CALCULADO <- as.integer(CUPO_CALCULADO)
    
    #CALCULO DE CUPOS POR ANIO
    EVALUAR_PROG_ANIO$CUPOS_ANIO <- EVALUAR_PROG_ANIO$VALOR_GENERAL_SOBRANTE / EVALUAR_PROG_ANIO$COSTO_ANIO 
    
    print(paste(" ORDEN_PROG_",ID_PROGRAMA,"MAXIMO",CUPO_OFERTADO,"CALCULADO",CUPO_CALCULADO,"VIGENCIA",min(EVALUAR_PROG_ANIO$CUPOS_ANIO)))
    
    #---------------------------
    # HAY CUPOS POR VIGENCIA   
    #---------------------------
    if(as.integer(min(EVALUAR_PROG_ANIO$CUPOS_ANIO)) > 0 ) {
      
      #------------------------------------------
      # REGLA_1 CUPO_CALCULADO supera CUPO_OFERTADO (NO APLICA PARA PROGRAMAS CON COSTOS EN LA VIGENCIA 2032)
      #------------------------------------------
      if(CUPO_CALCULADO >= CUPO_OFERTADO & min(EVALUAR_PROG_ANIO$CUPOS_ANIO) >= CUPO_OFERTADO){
        print("REGLA_1")
        OFERTA_DEMANDA_SOCIAL[OFERTA_DEMANDA_SOCIAL$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_NIVEL_DH"] <- CUPO_OFERTADO
        SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_NIVEL_DH"] <- CUPO_OFERTADO
        
        #COSTO A RESTAR EN EL PRESUPUESTO DE LA IES
        COSTO_CUPOS <- CUPO_OFERTADO * TOTAL_COHORTE
        OFERTA_DEMANDA_SOCIAL[OFERTA_DEMANDA_SOCIAL$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_NIVEL_DH"] <- COSTO_CUPOS
        SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_NIVEL_DH"] <- COSTO_CUPOS
        
        #RESTAR VALOR EN PRESUPUESTO IES-NIVEL
        VALOR_NIVEL <- VALOR_NIVEL - COSTO_CUPOS
        EXCEDENTE_NIVEL[EXCEDENTE_NIVEL$ID_NIVEL==ID_NIVEL,"VALOR_SOBRANTE_NIVEL"] <- VALOR_NIVEL
        
        #RESTAR VALOR EN PRESUPUESTO ANUAL
        for (anio in EVALUAR_PROG_ANIO$ANIO_EJECUCION) {
          VALOR_ANIO <- EVALUAR_PROG_ANIO[EVALUAR_PROG_ANIO$ANIO_EJECUCION==anio,"COSTO_ANIO"]
          #print(paste(anio,"cuesta",VALOR_ANIO, "X", CUPO_OFERTADO,"=",VALOR_ANIO * CUPO_OFERTADO))
          VALOR_GENERAL_SOBRANTE <- BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] 
          VALOR_GENERAL_SOBRANTE<-  VALOR_GENERAL_SOBRANTE - (VALOR_ANIO * CUPO_OFERTADO)
          BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] <- VALOR_GENERAL_SOBRANTE
        }
      }#FIN REGLA_1
      else
      #------------------------------------------
      # REGLA_2 CUPO_CALCULADO menor CUPO_OFERTADO (NO APLICA PARA PROGRAMAS CON COSTOS EN LA VIGENCIA 2032)
      #------------------------------------------
      if (CUPO_CALCULADO < CUPO_OFERTADO &  as.integer(CUPO_CALCULADO) > 0 ) {
        #------------------------------------------
        # REGLA_2.1 El cupo minimo por vigencia es mayor al cupo calculado
        #------------------------------------------
        if( min(EVALUAR_PROG_ANIO$CUPOS_ANIO) >= as.integer(CUPO_CALCULADO)) {
          print("REGLA_2")
          OFERTA_DEMANDA_SOCIAL[OFERTA_DEMANDA_SOCIAL$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_NIVEL_DH"] <- as.integer(CUPO_CALCULADO)
          SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_NIVEL_DH"] <- as.integer(CUPO_CALCULADO)
          
          #COSTO A RESTAR EN EL PRESUPUESTO DE LA IES
          COSTO_CUPOS <- as.integer(CUPO_CALCULADO) * TOTAL_COHORTE
          OFERTA_DEMANDA_SOCIAL[OFERTA_DEMANDA_SOCIAL$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_NIVEL_DH"] <- COSTO_CUPOS
          SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_NIVEL_DH"] <- COSTO_CUPOS
          
          #RESTAR VALOR EN PRESUPUESTO IES-NIVEL
          VALOR_NIVEL <- VALOR_NIVEL - COSTO_CUPOS
          EXCEDENTE_NIVEL[EXCEDENTE_NIVEL$ID_NIVEL==ID_NIVEL,"VALOR_SOBRANTE_NIVEL"] <- VALOR_NIVEL
          
          #RESTAR VALOR EN PRESUPUESTO ANUAL
          for (anio in EVALUAR_PROG_ANIO$ANIO_EJECUCION) {
            VALOR_ANIO <- EVALUAR_PROG_ANIO[EVALUAR_PROG_ANIO$ANIO_EJECUCION==anio,"COSTO_ANIO"]
            #print(paste(anio,"cuesta",VALOR_ANIO, "X", as.integer(CUPO_CALCULADO),"=",VALOR_ANIO * as.integer(CUPO_CALCULADO)))
            VALOR_GENERAL_SOBRANTE <- BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] 
            VALOR_GENERAL_SOBRANTE<-  VALOR_GENERAL_SOBRANTE - (VALOR_ANIO * as.integer(CUPO_CALCULADO))
            BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] <- VALOR_GENERAL_SOBRANTE
          }
        }else
          #------------------------------------------
        # REGLA_2.2 El cupo minimo por vigencia es el que se asigna
        #------------------------------------------
        if(as.integer(min(EVALUAR_PROG_ANIO$CUPOS_ANIO)) > 0){
          
          CUPO_CALCULADO <- min(EVALUAR_PROG_ANIO$CUPOS_ANIO)
          
          print("REGLA_3")
          OFERTA_DEMANDA_SOCIAL[OFERTA_DEMANDA_SOCIAL$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_NIVEL_DH"] <- as.integer(CUPO_CALCULADO)
          SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_NIVEL_DH"] <- as.integer(CUPO_CALCULADO)
          
          #COSTO A RESTAR EN EL PRESUPUESTO DE LA IES
          COSTO_CUPOS <- as.integer(CUPO_CALCULADO) * TOTAL_COHORTE
          OFERTA_DEMANDA_SOCIAL[OFERTA_DEMANDA_SOCIAL$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_NIVEL_DH"] <- COSTO_CUPOS
          SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_NIVEL_DH"] <- COSTO_CUPOS
          
          #RESTAR VALOR EN PRESUPUESTO IES-NIVEL
          VALOR_NIVEL <- VALOR_NIVEL - COSTO_CUPOS
          EXCEDENTE_NIVEL[EXCEDENTE_NIVEL$ID_NIVEL==ID_NIVEL,"VALOR_SOBRANTE_NIVEL"] <- VALOR_NIVEL
          
          #RESTAR VALOR EN PRESUPUESTO ANUAL
          for (anio in EVALUAR_PROG_ANIO$ANIO_EJECUCION) {
            VALOR_ANIO <- EVALUAR_PROG_ANIO[EVALUAR_PROG_ANIO$ANIO_EJECUCION==anio,"COSTO_ANIO"]
            #print(paste(anio,"cuesta",VALOR_ANIO, "X", as.integer(CUPO_CALCULADO),"=",VALOR_ANIO * as.integer(CUPO_CALCULADO)))
            VALOR_GENERAL_SOBRANTE <- BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] 
            VALOR_GENERAL_SOBRANTE<-  VALOR_GENERAL_SOBRANTE - (VALOR_ANIO * as.integer(CUPO_CALCULADO))
            BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] <- VALOR_GENERAL_SOBRANTE
          }
        }
      } else
        #------------------------------------------
      # REGLA_4 El cupo minimo por vigencia es el que se asigna
      #------------------------------------------
      if(as.integer(min(EVALUAR_PROG_ANIO$CUPOS_ANIO)) > 0 & as.integer(min(EVALUAR_PROG_ANIO$CUPOS_ANIO)) < CUPO_CALCULADO){
        
        CUPO_CALCULADO <- min(EVALUAR_PROG_ANIO$CUPOS_ANIO)
        
        print("REGLA_4")
        OFERTA_DEMANDA_SOCIAL[OFERTA_DEMANDA_SOCIAL$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_NIVEL_DH"] <- as.integer(CUPO_CALCULADO)
        SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "CUPO_ASIGNADO_NIVEL_DH"] <- as.integer(CUPO_CALCULADO)
        
        #COSTO A RESTAR EN EL PRESUPUESTO DE LA IES
        COSTO_CUPOS <- as.integer(CUPO_CALCULADO) * TOTAL_COHORTE
        OFERTA_DEMANDA_SOCIAL[OFERTA_DEMANDA_SOCIAL$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_NIVEL_DH"] <- COSTO_CUPOS
        SEMILLA_PROGRAMAS[SEMILLA_PROGRAMAS$ORDENAMIENTO_PROG== ID_PROGRAMA, "COSTO_CUPOS_ASIGNADO_NIVEL_DH"] <- COSTO_CUPOS
        
        #RESTAR VALOR EN PRESUPUESTO IES-NIVEL
        VALOR_NIVEL <- VALOR_NIVEL - COSTO_CUPOS
        EXCEDENTE_NIVEL[EXCEDENTE_NIVEL$ID_NIVEL==ID_NIVEL,"VALOR_SOBRANTE_NIVEL"] <- VALOR_NIVEL
        
        #RESTAR VALOR EN PRESUPUESTO ANUAL
        for (anio in EVALUAR_PROG_ANIO$ANIO_EJECUCION) {
          VALOR_ANIO <- EVALUAR_PROG_ANIO[EVALUAR_PROG_ANIO$ANIO_EJECUCION==anio,"COSTO_ANIO"]
          #print(paste(anio,"cuesta",VALOR_ANIO, "X", as.integer(CUPO_CALCULADO),"=",VALOR_ANIO * as.integer(CUPO_CALCULADO)))
          VALOR_GENERAL_SOBRANTE <- BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] 
          VALOR_GENERAL_SOBRANTE<-  VALOR_GENERAL_SOBRANTE - (VALOR_ANIO * as.integer(CUPO_CALCULADO))
          BASE_ANUAL[BASE_ANUAL$ANIO==anio,"VALOR_GENERAL_SOBRANTE"] <- VALOR_GENERAL_SOBRANTE
        }
      }
      else{
        print(paste("SIN PRESUPUESTO IES - cupo calculado=",CUPO_CALCULADO))
      }
      
    }else
    {
      print(paste("SIN PRESUPUESTO POR VIGENCIA",EVALUAR_PROG_ANIO[EVALUAR_PROG_ANIO$CUPOS_ANIO==min(EVALUAR_PROG_ANIO$CUPOS_ANIO),"ANIO_EJECUCION"],"CUPOS",min(EVALUAR_PROG_ANIO$CUPOS_ANIO))) 
    }
    
  } # CIERRE RECORRIDOS PROGRAMA
  
} # CIERRE RECORRIDO IES - NIVEL

sum(OFERTA_DEMANDA_SOCIAL$CUPO_ASIGNADO_NIVEL_DH) # 44
sum(OFERTA_DEMANDA_SOCIAL$COSTO_CUPOS_ASIGNADO_NIVEL_DH) # $1.264.622.282

#-------------------------------------------------------------------------------
# Resultado
#-------------------------------------------------------------------------------
OFERTA_DEMANDA_SOCIAL$CUPOS_ASIGNADOS_DEMANDA_SOCIAL <- OFERTA_DEMANDA_SOCIAL$CUPO_ASIGNADO_CINE  + OFERTA_DEMANDA_SOCIAL$CUPO_ASIGNADO_NIVEL_DH
OFERTA_DEMANDA_SOCIAL$COSTO_CUPOS_DEMANDA_SOCIAL <- OFERTA_DEMANDA_SOCIAL$COSTO_CUPOS_ASIGNADO_CINE + OFERTA_DEMANDA_SOCIAL$COSTO_CUPOS_ASIGNADO_NIVEL_DH

OFERTA_DEMANDA_SOCIAL$EVALUADO_DEMANDA_SOCIAL <- "S"

#--------------------------------------------------------------------------------------------------------------

RESULT <- merge(x=ORDENAMIENTO_PROG, y=OFERTA_DEMANDA_SOCIAL[,c("ORDENAMIENTO_PROG","EVALUADO_DEMANDA_SOCIAL", "CUPO_ASIGNADO_CINE","COSTO_CUPOS_ASIGNADO_CINE",
                                                                "CUPO_ASIGNADO_NIVEL_DH","COSTO_CUPOS_ASIGNADO_NIVEL_DH",
                                                                "CUPOS_ASIGNADOS_DEMANDA_SOCIAL", "COSTO_CUPOS_DEMANDA_SOCIAL")], by="ORDENAMIENTO_PROG", all.x = TRUE )

RESULT[is.na(RESULT$EVALUADO_DEMANDA_SOCIAL), "EVALUADO_DEMANDA_SOCIAL"] <- "N"
RESULT[RESULT$EVALUADO_DEMANDA_SOCIAL=="N", "CUPO_ASIGNADO_CINE"] <- 0
RESULT[RESULT$EVALUADO_DEMANDA_SOCIAL=="N", "CUPO_ASIGNADO_NIVEL_DH"] <- 0
RESULT[RESULT$EVALUADO_DEMANDA_SOCIAL=="N", "COSTO_CUPOS_ASIGNADO_CINE"] <- 0
RESULT[RESULT$EVALUADO_DEMANDA_SOCIAL=="N", "COSTO_CUPOS_ASIGNADO_NIVEL_DH"] <- 0

RESULT[is.na(RESULT$CUPOS_ASIGNADOS_DEMANDA_SOCIAL), "CUPOS_ASIGNADOS_DEMANDA_SOCIAL"] <- 0
RESULT[is.na(RESULT$COSTO_CUPOS_DEMANDA_SOCIAL), "COSTO_CUPOS_DEMANDA_SOCIAL"] <- 0

sum(RESULT$CUPOS_ASIGNADOS_MECANISMO_ISOES)
sum(RESULT$CUPOS_ASIGNADOS_DEMANDA_SOCIAL)

RESULT$CUPOS_ASIGNADOS_TOTAL <- RESULT$CUPOS_ASIGNADOS_MECANISMO_ISOES + RESULT$CUPOS_ASIGNADOS_DEMANDA_SOCIAL
sum(RESULT$CUPOS_ASIGNADOS_TOTAL)

#--------------------------------------------
#### CALCULO CUPOS ASIGNADOS TOTALES
#--------------------------------------------
RESULT$COSTO_CUPOS_ASIGNADOS_TOTAL <- RESULT$CUPOS_ASIGNADOS_TOTAL * RESULT$TOTAL_VALOR_COHORTE_ATENEA

sum(RESULT$COSTO_CUPOS_ASIGNADOS_TOTAL)
sum(RESULT$COSTO_CUPOS_ASIGNADOS_MECANISMO_ISOES) + sum(RESULT$COSTO_CUPOS_DEMANDA_SOCIAL)

sum(EXCEDENTE_NIVEL$VALOR_SOBRANTE_NIVEL)
#PRUEBA DEL PRESUPUESTO
PPTO_GENERAL - (sum(RESULT$COSTO_CUPOS_ASIGNADOS_TOTAL) + sum(EXCEDENTE_NIVEL$VALOR_SOBRANTE_NIVEL))

sum(RESULT$COSTO_CUPOS_ASIGNADOS_TOTAL) + sum(EXCEDENTE_NIVEL$VALOR_SOBRANTE_NIVEL) 
PPTO_GENERAL 

#-------------------------------------------------------------------------------
# EXPORTAR RESULTADOS OFERTA GENERAL
#-------------------------------------------------------------------------------

write.xlsx(RESULT, "RESULTADOS/JE4_OFERTA_ESC3-1_20251104_V3.xlsx",sheetName="JE4_PROGRAMAS", append=TRUE)
wb <- loadWorkbook("RESULTADOS/JE4_OFERTA_ESC3-1_20251104_V3.xlsx")
addWorksheet(wb,"EXCEDENTES_NIVEL")
writeData(wb,"EXCEDENTES_NIVEL",EXCEDENTE_NIVEL)
addWorksheet(wb,"BOLSA_ANUAL")
writeData(wb,"BOLSA_ANUAL",BASE_ANUAL)
addWorksheet(wb,"IES")
writeData(wb,"IES",IES)
addWorksheet(wb,"CINE")
writeData(wb,"CINE",CINE_NIVEL)

saveWorkbook(wb,"RESULTADOS/JE4_OFERTA_ESC3-1_20251104_V3.xlsx",overwrite = TRUE)

#SUMATORIAS DE ASIGNACION DE CUPOS
sum(RESULT$CUPO_ASIGNADO_IES)
sum(RESULT$CUPO_ASIGNADO_NIVEL)
sum(RESULT$CUPO_ASIGNADO_CINE)
sum(RESULT$CUPO_ASIGNADO_NIVEL_DH)
sum(RESULT$CUPOS_ASIGNADOS_TOTAL)

#BORRAR VARIABLES Y DATOS QUE SE USARON EN LOS CALCULOS
rm("ASIGNACION_NIVEL_PROG","COSTO_CUPOS","CUPO_CALCULADO","CUPO_OFERTADO","EVALUAR_IES","EVALUAR_NIVEL","EVALUAR_PROG","EXCEDENTE_NIVEL",
   "ID_IES_NIVEL","ID_NIVEL","ID_PROGRAMA","IES","NIVEL","ORDENAMIENTO_PROG","PPTO_GENERAL","PPTO_TYT","PPTO_UNIV","SEMILLA_PROGRAMAS","TIR_PONDERADA",
   "TMP","TOTAL_COHORTE","VALOR_IES","VALOR_NIVEL","wb"  )
