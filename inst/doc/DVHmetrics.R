## ----setup, echo=FALSE, include=FALSE, cache=FALSE------------------
# set global chunk options
knitr::opts_chunk$set(fig.align='center', fig.show='hold')
knitr::opts_chunk$set(tidy=FALSE, message=FALSE, warning=FALSE, comment=NA)
options(replace.assign=TRUE, useFancyQuotes=FALSE, show.signif.stars=FALSE, digits=4, width=70)

## ----cIntro, eval=FALSE---------------------------------------------
#  # install DVHmetrics from the CRAN online package repository
#  install.packages("DVHmetrics")

## ----cCmdline-------------------------------------------------------
## load DVHmetrics package - required for all following tasks
library(DVHmetrics, verbose=FALSE)

## calculate a DVH metric for built-in data
getMetric(dataMZ, metric="DMEAN", structure="HEART")

## ----cWebApp, eval=FALSE--------------------------------------------
#  vignette("DVHshiny")

## ----cReadData1a, eval=FALSE----------------------------------------
#  res <- readDVH("c:/folder/dvhFile.txt", type="Eclipse")

## ----cReadData1b, echo=TRUE-----------------------------------------
print(dataMZ)

## ----cReadData1c, echo=TRUE-----------------------------------------
print(dataMZ, verbose=TRUE)

## ----cReadData2, eval=FALSE-----------------------------------------
#  res <- readDVH("c:/folder/dvhFile*.txt", type="Cadplan")

## ----cReadData4, eval=FALSE-----------------------------------------
#  res <- readDVH(type="Eclipse")      # opens interactive file picker

## ----cReadData5, eval=FALSE-----------------------------------------
#  res <- readDVH("c:/folder/*", type="Eclipse", planInfo="doseRx")

## ----cMetrics1------------------------------------------------------
getMetric(dataMZ, metric="DMEAN")

## ----cMetrics2------------------------------------------------------
getMetric(dataMZ, metric="D5cc", structure="HEART")

## ----cMetrics3------------------------------------------------------
getMetric(dataMZ, metric="D5cc", structure="HEART", sortBy="observed")

## ----cMetrics4------------------------------------------------------
getMetric(dataMZ, metric=c("D10%", "V5Gy"),
          structure=c("AMYOC", "VALVE"),
          patID="23",
          sortBy=c("metric", "observed"))

## ----cMetrics5------------------------------------------------------
getMetric(dataMZ, metric=c("DMEAN", "D5cc"), structure="HEART",
          sortBy="observed", splitBy="metric")

## ----cMetrics6------------------------------------------------------
met <- getMetric(dataMZ, metric=c("DMEAN", "D5cc"),
                 structure=c("HEART", "AOVALVE"),
                 sortBy="observed",
                 splitBy=c("structure", "metric"))
met                               # print the calculated results

## ----cMetricsSave1, eval=FALSE--------------------------------------
#  saveMetric(met, file="c:/folder/metrics.txt")

## ----cMetricsSave2, eval=FALSE--------------------------------------
#  saveMetric(met, file="c:/folder/metrics.txt", dec=",")

## ----cMetricsSave3, eval=FALSE--------------------------------------
#  saveMetric(met, file="c:/folder/metrics.txt", quote=TRUE)

## ----cPlots1, out.width='3in'---------------------------------------
showDVH(dataMZ, byPat=TRUE)

## ----cPlots2, out.width='3in'---------------------------------------
showDVH(dataMZ, byPat=FALSE, patID=c("P123", "P234"))

## ----cPlots3, out.width='3in'---------------------------------------
## match strcuture containing "VALVE" and "AMYOC"
showDVH(dataMZ, cumul=FALSE, rel=FALSE,
        structure=c("VALVE", "AMYOC"))

## ----cPlots4, out.width='3in'---------------------------------------
## just save the diagram but don't show it
dvhPlot <- showDVH(dataMZ, structure=c("HEART", "AOVALVE", "AVNODE"),
                   rel=FALSE, thresh=0.001, show=FALSE)

## ----cPlotsSave, eval=FALSE-----------------------------------------
#  saveDVH(dvhPlot, file="c:/folder/dvh.pdf", width=7, height=5)

## ----cConstrDef2, eval=FALSE----------------------------------------
#  dataConstr <- readConstraints("constraints.txt", dec=".", sep="\t")

## ----cConstrDef3, echo=TRUE-----------------------------------------
dataConstr     # show defined constraints and their scope

## ----cConstrCheck1, echo=TRUE---------------------------------------
## store result in object cc to save to file later
cc <- checkConstraint(dataMZ, constr=dataConstr)
print(cc, digits=2)            # show output with 2 decimal places

## ----cConstrCheck2, eval=FALSE--------------------------------------
#  saveConstraint(cc, file="c:/folder/constrCheck.txt")

## ----cConstrShow1, out.width='3in', echo=TRUE-----------------------
## plot relative volume
showConstraint(dataMZ, constr=dataConstr, byPat=TRUE)

## ----cConstrShow2, eval=FALSE---------------------------------------
#  ## plot absolute volume - store result in sc to save to file later
#  sc <- showConstraint(dataMZ, constr=dataConstr,
#                       byPat=FALSE, rel=FALSE)

## ----cConstrShow3, eval=FALSE---------------------------------------
#  saveDVH(sc, file="c:/folder/dvhConstraint.pdf")
