## convert DVH to cumulative/differential DVH
## with linearly interpolating the cumulative DVH
convertDVH <-
function(x, toType=c("asis", "cumulative", "differential"),
         toDoseUnit=c("asis", "GY", "CGY"),
         interp=c("asis", "linear"),
         nodes=NULL, rangeD=NULL,
         perDose=TRUE) {
    UseMethod("convertDVH")
}

## for DVH matrix itself
convertDVH.matrix <-
function(x, toType=c("asis", "cumulative", "differential"),
         toDoseUnit=c("asis", "GY", "CGY"),
         interp=c("asis", "linear"),
         nodes=NULL, rangeD=NULL,
         perDose=TRUE) {
    toType     <- match.arg(toType)
    toDoseUnit <- match.arg(toDoseUnit)
    interp     <- match.arg(interp)

    if(!is.null(nodes)) { stopifnot(nodes > 2L) }

    ## matrix may include duplicate rows
    x <- unique(x)

    dose <- if(!all(is.na(x[ , "dose"]))) {
        x[ , "dose"]
    } else {
        x[ , "doseRel"]
    }

    ## when dose entries are duplicated with different volumes (cumulative DVH),
    ## pick row with max volume
    x <- if(any(duplicated(dose))) {
        ## split matrix into rows with unique dose
        ## preserve matrix class and keep col names with split.data.frame()
        xL <- split.data.frame(x, dose)
        
        ## function to keep row with max volume
        keepMaxVol <- function(xSub) {
            idx <- if(!all(is.na(xSub[ , "volume"]))) {
                xSub[ , "volume"] == max(xSub[ , "volume"])
            } else{
                xSub[ , "volumeRel"] == max(xSub[ , "volumeRel"])
            }
            
            xSub[idx, ]
        }
    
        ## apply keepMaxVol and re-bind to matrix
        x <- do.call("rbind", lapply(xL, keepMaxVol))
        rownames(x) <- NULL
        x
    } else {
        x
    }

    ## determine number of nodes for interpolation
    nodes <- if(!is.null(nodes)) {
        if(nodes < 2L) {
            warning("nodes is < 2 which is too few, - set to 2")
            2L
        } else {
            nodes
        }
    } else {
        nrow(x)
    }

    ## absolute and relative doses/volumes
    dose      <- x[ , "dose"]
    doseRel   <- x[ , "doseRel"]
    volume    <- x[ , "volume"]
    volumeRel <- x[ , "volumeRel"]
    
    ## convert dose unit
    doseConv <- if(toDoseUnit == "asis") {
        dose                          # nothing to do
    } else if(toDoseUnit == "GY") {   # assume dose is given in cGy
        dose / 100                    # cGy to Gy
    } else if(toDoseUnit == "CGY") {  # assume dose is given in Gy
        dose * 100                    # Gy to cGy
    }

    ## convert DVH type
    if(toType == "asis") {
        ## nothing to convert
        ## linear interpolation?
        if(interp == "linear") {
            ## if differential && perDose == FALSE
            ## normalize -> interpolate -> re-normalize 
            ## check if volume is already sorted -> cumulative DVH
            volumeSel <- if(!any(is.na(volumeRel))) {
                volumeRel
            } else {
                volume
            }
    
            DVHtype <- if(isTRUE(all.equal(volumeSel, sort(volumeSel, decreasing=TRUE)))) {
                "cumulative"
            } else {
                "differential"
            }
            
            if((DVHtype == "differential") && (perDose == FALSE)) {
                ## if perDose == FALSE: normalize -> interpolate -> re-normalize
                binW         <- diff(c(-doseConv[1], doseConv))
                volumeNew    <- -diff(volume)    / binW
                volumeRelNew <- -diff(volumeRel) / binW
            }
            
            ## linear interpolation
            sm <- getInterpLin(doseConv, doseRel, volume, volumeRel,
                               nodes=nodes, rangeD=rangeD)
            doseNew    <- sm[ , "dose"]
            doseRelNew <- sm[ , "doseRel"]

            if((DVHtype == "differential") && (perDose == FALSE)) {
                ## re-normalize to non-per-dose volume
                ## start bin at 0 because no out-of-range interpolation
                binW         <- diff(c(0, doseConv))
                volumeNew    <- sm[ , "volume"]    * binW
                volumeRelNew <- sm[ , "volumeRel"] * binW

            } else {
                volumeNew    <- sm[ , "volume"]
                volumeRelNew <- sm[ , "volumeRel"]
            }
        } else {
            doseNew      <- doseConv
            doseRelNew   <- doseRel
            volumeNew    <- volume
            volumeRelNew <- volumeRel
        }
    } else if(toType == "cumulative") {
        ## convert from differential to cumulative DVH
        ## dose category half-widths
        doseCatHW    <- diff(doseConv)/2
        doseRelCatHW <- diff(doseRel)/2

        ## dose category mid-points, starting at 0
        N <- nrow(x)
        doseMidPt    <- c(0, doseConv[-N] + doseCatHW)
        doseRelMidPt <- c(0, doseRel[-N]  + doseRelCatHW)
        
        ## add one more category beyond max dose
        doseNew    <- c(doseMidPt,    doseConv[N] + doseCatHW[N-1])
        doseRelNew <- c(doseRelMidPt, doseRel[N]  + doseRelCatHW[N-1])
        
        if(perDose == TRUE) {
            ## differential DVH -> volume is per Gy -> mult with bin-width
            binW         <- diff(c(-doseConv[1], doseConv))
            volumeBin    <- volume*binW
            volumeRelBin <- volumeRel*binW
        } else if(perDose == FALSE) {
            volumeBin    <- volume
            volumeRelBin <- volumeRel
        }

        ## volume "survival" curve starting at max volume
        volumeNew    <- sum(volumeBin)    - c(0, cumsum(volumeBin))
        volumeRelNew <- sum(volumeRelBin) - c(0, cumsum(volumeRelBin))

        ## linear interpolation?
        if(interp == "linear") {
            ## linear interpolation
            sm <- getInterpLin(doseNew, doseRelNew, volumeNew, volumeRelNew,
                               nodes=nodes, rangeD=rangeD)
            doseNew      <- sm[ , "dose"]
            doseRelNew   <- sm[ , "doseRel"]
            volumeNew    <- sm[ , "volume"]
            volumeRelNew <- sm[ , "volumeRel"]
        }
    } else if(toType == "differential") {
        ## convert from cumulative to differential DVH
        ## linear interpolation?
        if(interp != "asis") {
            ## linear interpolation
            sm <- getInterpLin(doseConv, doseRel, volume, volumeRel,
                               nodes=nodes, rangeD=rangeD)
            doseConv  <- sm[ , "dose"]
            doseRel   <- sm[ , "doseRel"]
            volume    <- sm[ , "volume"]
            volumeRel <- sm[ , "volumeRel"]
        }

        ## dose category half-widths
        doseCatHW    <- diff(doseConv)/2
        doseRelCatHW <- diff(doseRel)/2
        doseNew      <- doseConv[-length(doseConv)] + doseCatHW
        doseRelNew   <-  doseRel[-length(doseRel)]  + doseRelCatHW

        ## differential DVH -> volume is per Gy -> divide by bin-width
        binW <- 2*doseCatHW
        volumeNew <- if(perDose == TRUE) {
            -diff(volume) / binW
        } else if(perDose == FALSE) {
            -diff(volume)
        }

        volumeRelNew <- if(perDose == TRUE) {
            -diff(volumeRel) / binW
        } else if(perDose == FALSE) {
            -diff(volumeRel)
        }
    }

    cbind(dose=doseNew, doseRel=doseRelNew,
          volume=volumeNew, volumeRel=volumeRelNew)
}

## for 1 DVH object
convertDVH.DVHs <-
function(x, toType=c("asis", "cumulative", "differential"),
         toDoseUnit=c("asis", "GY", "CGY"),
         interp=c("asis", "linear"),
         nodes=NULL, rangeD=NULL,
         perDose=TRUE) {
    toType       <- match.arg(toType)
    toDoseUnit   <- match.arg(toDoseUnit)

    if(!is.null(nodes)) { stopifnot(nodes > 2) }

    ## copy old DVH structure and convert DVH as well as other dose info
    DVH <- x
    if((toType == "asis") && (toDoseUnit == "asis") && (interp != "asis")) {
        ## just interpolate existing DVHs
        ## cumulative
        DVH$dvh <- convertDVH(x$dvh, toType=toType,
                              toDoseUnit="asis", interp=interp,
                              nodes=nodes, rangeD=rangeD, perDose=perDose)
        ## differential
        if(!is.null(x$dvhDiff)) {
            DVH$dvhDiff <- convertDVH(x$dvhDiff, toType=toType,
                                      toDoseUnit="asis", interp=interp,
                                      nodes=nodes, rangeD=rangeD,
                                      perDose=perDose)
        }
    } else if((toType == "asis") && (toDoseUnit != "asis") && (interp == "asis")) {
        ## just change dose unit in DVH and remaining dose values
        cf <- getConvFac(paste0(x$doseUnit, "2", toDoseUnit))

        ## cumulative
        DVH$dvh <- convertDVH(x$dvh, toType=toType,
                              toDoseUnit="asis", interp=interp,
                              nodes=nodes, rangeD=rangeD,
                              perDose=perDose)
        ## differential
        if(!is.null(x$dvhDiff)) {
            DVH$dvhDiff <- convertDVH(x$dvhDiff, toType=toType,
                                      toDoseUnit="asis", interp=interp,
                                      nodes=nodes, rangeD=rangeD,
                                      perDose=perDose)
        }

        DVH$dvh[ , "dose"] <- cf*x$dvh[ , "dose"]
        DVH$doseMin   <- cf*x$doseMin
        DVH$doseMax   <- cf*x$doseMax
        DVH$doseRx    <- cf*x$doseRx
        DVH$isoDoseRx <- cf*x$isoDoseRx
        DVH$doseAvg   <- cf*x$doseAvg
        DVH$doseMed   <- cf*x$doseMed
        DVH$doseMode  <- cf*x$doseMode
        DVH$doseSD    <- cf*x$doseSD
        DVH$doseUnit  <- toDoseUnit
    } else if((toType == "asis") && (toDoseUnit != "asis") && (interp != "asis")) {
        ## change dose unit in DVH and remaining dose values
        ## and interpolate
        cf <- getConvFac(paste0(x$doseUnit, "2", toDoseUnit))

        DVH$dvh[ , "dose"] <- cf*x$dvh[ , "dose"]
        DVH$doseMin   <- cf*x$doseMin
        DVH$doseMax   <- cf*x$doseMax
        DVH$doseRx    <- cf*x$doseRx
        DVH$isoDoseRx <- cf*x$isoDoseRx
        DVH$doseAvg   <- cf*x$doseAvg
        DVH$doseMed   <- cf*x$doseMed
        DVH$doseMode  <- cf*x$doseMode
        DVH$doseSD    <- cf*x$doseSD
        DVH$doseUnit  <- toDoseUnit
    } else if((toType != "asis") && (toDoseUnit == "asis")) {
        ## just change DVH type
        if(toType == "differential") {
            ## from cumulative to differential
            DVH$dvhDiff <- convertDVH(x$dvh, toType=toType,
                                      toDoseUnit="asis", interp=interp,
                                      nodes=nodes, rangeD=rangeD,
                                      perDose=perDose)
        } else {
            ## from differential to cumulative
            if(!is.null(x$dvhDiff)) {
                DVH$dvh <- convertDVH(x$dvhDiff, toType=toType,
                                      toDoseUnit="asis", interp=interp,
                                      nodes=nodes, rangeD=rangeD,
                                      perDose=perDose)
            } else {
                warning("No differential DVH found. Left cumulative DVH as is.")
            }
        }
    } else if((toType != "asis") && (toDoseUnit != "asis")) {
        ## change DVH type and dose unit
        cf <- getConvFac(paste0(x$doseUnit, "2", toDoseUnit))

        if(toType == "differential") {
            ## from cumulative to differential
            DVH$dvhDiff <- convertDVH(x$dvh, toType=toType,
                                      toDoseUnit=toDoseUnit, interp=interp,
                                      nodes=nodes, rangeD=rangeD,
                                      perDose=perDose)
        } else {
            ## from differential to cumulative
            if(!is.null(x$dvhDiff)) {
                DVH$dvh <- convertDVH(x$dvhDiff, toType=toType,
                                      toDoseUnit=toDoseUnit, interp=interp,
                                      nodes=nodes, rangeD=rangeD,
                                      perDose=perDose)
            } else {
                warning("No differential DVH found. Left cumulative DVH as is.")
            }
        }

        DVH$doseMin   <- cf*x$doseMin
        DVH$doseMax   <- cf*x$doseMax
        DVH$doseRx    <- cf*x$doseRx
        DVH$isoDoseRx <- cf*x$isoDoseRx
        DVH$doseAvg   <- cf*x$doseAvg
        DVH$doseMed   <- cf*x$doseMed
        DVH$doseMode  <- cf*x$doseMode
        DVH$doseSD    <- cf*x$doseSD
        DVH$doseUnit  <- toDoseUnit
    }
    
    return(DVH)
}

## for list of DVH objects
convertDVH.DVHLst <-
function(x, toType=c("asis", "cumulative", "differential"),
         toDoseUnit=c("asis", "GY", "CGY"),
         interp=c("asis", "linear"),
         nodes=NULL, rangeD=NULL,
         perDose=TRUE) {
    toType     <- match.arg(toType)
    toDoseUnit <- match.arg(toDoseUnit)
    interp     <- match.arg(interp)

    if(!is.null(nodes)) { stopifnot(nodes > 2L) }

    dvhL <- Map(convertDVH, x, toType=toType,
                toDoseUnit=toDoseUnit, interp=interp, nodes=list(nodes),
                rangeD=list(rangeD), perDose=perDose)
    names(dvhL) <- names(x)
    class(dvhL) <- "DVHLst"
    attr(dvhL, which="byPat") <- attributes(x)$byPat

    return(dvhL)
}

## for list of list of DVH objects
convertDVH.DVHLstLst <-
function(x, toType=c("asis", "cumulative", "differential"),
         toDoseUnit=c("asis", "GY", "CGY"),
         interp=c("asis", "linear"),
         nodes=NULL, rangeD=NULL,
         perDose=TRUE) {
    toType     <- match.arg(toType)
    toDoseUnit <- match.arg(toDoseUnit)
    interp     <- match.arg(interp)
    
    if(!is.null(nodes)) { stopifnot(nodes > 2L) }

    dvhLL <- Map(convertDVH, x, toType=toType,
                 toDoseUnit=toDoseUnit, interp=interp, nodes=list(nodes),
                 rangeD=list(rangeD), perDose=perDose)
    names(dvhLL) <- names(x)
    class(dvhLL) <- "DVHLstLst"
    attr(dvhLL, which="byPat") <- attributes(x)$byPat

    return(dvhLL)
}
