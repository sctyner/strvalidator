################################################################################
# TODO LIST
# TODO: option to filter peaks below (LOD) or above a treshold. (e.g. <50 or >5000 rfu)
# TODO: Fix "NAs introduced by coercion"
# TODO: script cant handle if ref is not in data.
# TODO: Detect pull-ups and other nois within stutter range.

################################################################################
# CHANGE LOG
# 10: Roxygenized and changed name from stutterStatSlim to calculateStutter.
# 09: New function StutterStatSlim works with slimmed data.

#' @title Calculate stutter
#'
#' @description
#' \code{calculateStutter} calculates statistics for stutters.
#'
#' @details
#' Calculates stutter ratios based on the 'reference' data set.
#' NB! Be careful when there are pull-ups in stutter positions. 
#' 
#' @param data data frame with genotype data in 'slim' format.
#' Requires one or more allele columns 'Allele'.
#' @param ref data frame in slim format with the known profiles.
#' @param back integer for the maximal number of backward stutters
#'  (max size difference 2 = n-2 repeats).
#' @param forward integer for the maximal number of forward stutters
#'  (max size difference 1 = n+1 repeats).
#' @param interference integer specifying accepted level of interference between peaks.
#'  0 = no overlap between stutters and alleles is allowed.
#'  1 = stutter-stutter interference is allowed.
#'  2 = stutter-allele interference is allowed.
#' 
#' @return data.frame with extracted result.
#' 


calculateStutter <- function(data, ref, back=2, forward=1, interference=0){

  # Create an empty data frame to hold the result.
  stutterRatio <- data.frame(t(rep(NA,7)))
  # Add column names.
  names(stutterRatio ) <- c("Marker", "Allele",
                            "HeightA", "Stutter", "HeightS",
                            "Ratio", "Type")
  # Remove all NAs
  stutterRatio  <- stutterRatio [-1,]
  
  # Get columns.
  col.m <- grepl("Marker", names(data))
  col.a <- grepl("Allele", names(data))
  col.h <- grepl("Height", names(data))
  
  # Get column names.
  col.a.names <- names(data[,col.a])
  col.h.names <- names(data[,col.h])
  
  # Get sample and reference names.
  sample.names <- unique(data$Sample.Name)
  ref.sample.names <- unique(ref$Sample.Name)
  
  # Loop through all reference samples.
  for(s in seq(along=ref.sample.names)){
    # s<-1
    # Select current ref sample.
    selected.refs <- grepl(ref.sample.names[s], ref$Sample.Name)
    ref.subset <- ref[selected.refs, ]
    
    # Select samples from this ref.
    selected.samples <- grepl(ref.sample.names[s], data$Sample.Name)
    data.subset <- data[selected.samples, ]
    
    # Get subset sample names.
    ss.names <- unique(data.subset$Sample.Name)
    
    # Loop over all samples in subset.
    for(ss in seq(along=ss.names)){
      # ss<-1  ss<-ss+1
      
      # Select samples from this ref.
      selected.samples <- grepl(ss.names[ss], data.subset$Sample.Name)
      data.ss <- data.subset[selected.samples, ]
      
      # Get current marker names.
      marker.names <- unique(data.ss$Marker[data.ss$Sample.Name==ss.names[ss]])
      #m<-1  m<-m+1 m<-7
      # Loop over all markers in subset.
      for(m in seq(along=marker.names)){
        
        # Get reference alleles (true alleles).
        tA1 <- ref.subset$Allele.1[ref.subset$Marker==marker.names[m]]
        tA2 <- ref.subset$Allele.2[ref.subset$Marker==marker.names[m]]
        
        # Check zygosity.
        if(tA1==tA2 || is.na(tA2)) {
          heterozygote <- FALSE
        } else {
          heterozygote <- TRUE
        }
        
        # Get data for current marker.
        allele.v <- as.matrix(data.ss[data.ss$Marker==marker.names[m],col.a])
        height.v <- as.matrix(data.ss[data.ss$Marker==marker.names[m],col.h])
        
        # Remove NA
        sel <- !is.na(allele.v)
        allele.v <- allele.v[sel]
        height.v <- height.v[sel]
        
        # Identify possible stutters for allele 1 and 2.
        sA1 <- allele.v[as.numeric(allele.v)>=as.numeric(tA1)-back & 
                          as.numeric(allele.v)<=as.numeric(tA1)+forward]
        sA2 <- allele.v[as.numeric(allele.v)>=as.numeric(tA2)-back & 
                          as.numeric(allele.v)<=as.numeric(tA2)+forward]
        sA1 <- sA1[!is.na(sA1)]
        sA2 <- sA2[!is.na(sA2)]
        # Check if true allele exist!
        bolA1 <- tA1 %in% sA1
        bolA2 <- tA2 %in% sA2
        sA1 <- sA1[sA1 != tA1] # Remove true allele
        sA2 <- sA2[sA2 != tA2]
        
        # Get heights for alleles and stutters.
        hA1 <- height.v[match(tA1,allele.v)]
        hA2 <- height.v[match(tA2,allele.v)]
        shA1 <- height.v[match(sA1,allele.v)]
        shA2 <- height.v[match(sA2,allele.v)]
        
        currentAllele1<-NA
        currentAllele2<-NA
        
        # Calculate stutter ratio.
        if (interference==0){
          if(bolA1){
            
            #Calculate for all stutters.
            # Calculate for stutters smaller than A2 stutters/allele
            sel <- as.numeric(sA1) < min(as.numeric(sA2), as.numeric(tA2))
            
            if(all(sel)==FALSE){
              srA1 <- numeric()
            } else {
              srA1 <- as.numeric(shA1[sel]) / as.numeric(hA1)
            }
            
            if(length(srA1) > 0 && !tA1 %in% sA2){
              rp <- length(srA1)
              df.marker <- rep(marker.names[m],rp)
              df.allele <- rep(tA1,rp)
              df.height.a <- rep(hA1,rp)
              df.stutter <- sA1[sel]
              df.height.s <- shA1
              df.ratio <- srA1
              df.type <- as.numeric(sA1[sel])-as.numeric(tA1)
              
              currentAllele1 <- data.frame("Marker"=df.marker, "Allele"=df.allele,
                                           "HeightA"=df.height.a, "Stutter"=df.stutter, "HeightS"=df.height.s,
                                           "Ratio"=df.ratio,	"Type"=df.type)
              
              stutterRatio <- rbind(stutterRatio, currentAllele1)
            }
          }
          if (heterozygote && bolA2) {
            
            # Calculate for stutters bigger than A1 stutters/allele
            sel <- as.numeric(sA2) > max(as.numeric(sA1), as.numeric(tA1))
            
            if(all(sel)==FALSE){
              srA2 <- numeric()
            } else {
              srA2 <- as.numeric(shA2[sel]) / as.numeric(hA2)
            }
            
            if(length(srA2) > 0){
              rp <- length(srA2)
              df.marker <- rep(marker.names[m],rp)
              df.allele <- rep(tA2,rp)
              df.height.a <- rep(hA2,rp)
              df.stutter <- sA2[sel]
              df.height.s <- shA2
              df.ratio <- srA2
              df.type <- as.numeric(sA2[sel]) - as.numeric(tA2)
              
              currentAllele2 <- data.frame("Marker"=df.marker, "Allele"=df.allele,
                                           "HeightA"=df.height.a, "Stutter"=df.stutter, "HeightS"=df.height.s, 
                                           "Ratio"=df.ratio,	"Type"=df.type)
              
              stutterRatio <- rbind(stutterRatio, currentAllele2)
            }
          }
          
        } else if (interference == 1){
          if(bolA1){
            
            #Calculate for stutters even if stutter interference.
            # Calculate for stutters smaller than A2 allele
            sel <- as.numeric(sA1) < as.numeric(tA2)
            
            if(all(sel)==FALSE){
              srA1 <- numeric()
            } else {
              srA1 <- as.numeric(shA1[sel]) / as.numeric(hA1)
            }
            
            if(length(srA1) > 0){
              rp <- length(srA1)
              df.marker <- rep(marker.names[m], rp)
              df.allele <- rep(tA1, rp)
              df.height.a <- rep(hA1, rp)
              df.stutter <- sA1[sel]
              df.height.s <- shA1
              df.ratio <- srA1
              df.type <- as.numeric(sA1[sel]) - as.numeric(tA1)
              
              currentAllele1 <- data.frame("Marker"=df.marker, "Allele"=df.allele,
                                           "HeightA"=df.height.a, "Stutter"=df.stutter, "HeightS"=df.height.s,
                                           "Ratio"=df.ratio,	"Type"=df.type)
              
              stutterRatio <- rbind(stutterRatio, currentAllele1)
            }
          }
          if (heterozygote && bolA2) {
            
            # Calculate for stutters bigger than A1 allele
            sel <- as.numeric(sA2) > as.numeric(tA1)
            
            if(all(sel)==FALSE){
              srA2 <- numeric()
            } else {
              srA2 <- as.numeric(shA2[sel]) / as.numeric(hA2)
            }
            
            if(length(srA2) > 0){
              
              rp <- length(srA2)
              df.marker <- rep(marker.names[m], rp)
              df.allele <- rep(tA2, rp)
              df.height.a <- rep(hA2, rp)
              df.stutter <- sA2[sel]
              df.height.s <- shA2
              df.ratio <- srA2
              df.type <- as.numeric(sA2[sel]) - as.numeric(tA2)
              
              currentAllele2 <- data.frame("Marker"=df.marker, "Allele"=df.allele,
                                           "HeightA"=df.height.a, "Stutter"=df.stutter, "HeightS"=df.height.s,
                                           "Ratio"=df.ratio,	"Type"=df.type)
              
              stutterRatio <- rbind(stutterRatio, currentAllele2)
            }
          }
          
          
        } else if (interference == 2){
          if(bolA1){
            
            #Calculate for stutters even if allele interference.
            sel <- sA1 != tA2
            
            if(all(sel)==FALSE){
              srA1 <- numeric()
            } else {
              srA1 <- as.numeric(shA1[sel]) / as.numeric(hA1)
            }
            
            rp <- length(srA1)
            df.marker <- rep(marker.names[m], rp)
            df.allele <- rep(tA1, rp)
            df.height.a <- rep(hA1, rp)
            df.stutter <- sA1[sel]
            df.height.s <- shA1
            df.ratio <- srA1
            df.type <- as.numeric(sA1[sel]) - as.numeric(tA1)
            
            # Create data frame.
            currentAllele1 <- data.frame("Marker"=df.marker, "Allele"=df.allele,
                                         "HeightA"=df.height.a, "Stutter"=df.stutter, "HeightS"=df.height.s,
                                         "Ratio"=df.ratio, "Type"=df.type)
            
            stutterRatio <- rbind(stutterRatio, currentAllele1)
          }
          if (heterozygote && bolA2) {
            
            sel <- sA2 != tA1
            
            if(all(sel)==FALSE){
              srA2 <- numeric()
            } else {
              srA2 <- as.numeric(shA2[sel]) / as.numeric(hA2)
            }
            
            rp <- length(srA2)
            df.marker <- rep(marker.names[m], rp)
            df.allele <- rep(tA2, rp)
            df.height.a <- rep(hA2, rp)
            df.stutter <- sA2[sel]
            df.height.s <- shA2
            df.ratio <- srA2
            df.type <- as.numeric(sA2[sel]) - as.numeric(tA2)
            
            # Create data frame.
            currentAllele2 <- data.frame("Marker"=df.marker, "Allele"=df.allele,
                                         "HeightA"=df.height.a, "Stutter"=df.stutter, "HeightS"=df.height.s,
                                         "Ratio"=df.ratio,	"Type"=df.type)
            
            stutterRatio <- rbind(stutterRatio, currentAllele2)
          }
          
          
        } else{
          print("Stutter not calculated for:")
          print(data.subset[ref.subset$Marker==marker.names[m], 1:5])
        }
      }
    }
  }
  
  return(stutterRatio)
}