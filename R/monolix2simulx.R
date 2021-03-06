#' Convert a Monolix Project  into an executable for the simulator  Simulx 
#' @param project : the name of a Monolix project 
#' @param parameter : string $(NameOfTypeOfParameter), the type of specific parameters to use 
#'                   example: "mode", "mean"...
#' @param group : a list with the number of subjects 
#' @param open : load the R script created if \code{open=TRUE}
#' @param r.data : read the data if \code{r.data=TRUE}
#' @param fim : Fisher information matrix
#' @return  creates a folder projectNameR  containing files : 
#' \itemize{
#'   \item \code{projectName.R} :  executable R code for the simulator,
#'   \item \code{treatment.txt} :  contains the treatment informations,
#'   \item \code{populationParameter.txt} : contains the  population parameters estimated from Monolix,
#'   \item \code{individualParameter.txt} : contains the  individual parameters (mode/mean) estimated from Monolix (if used for the simulation),
#'   \item \code{individualCovariate.txt} : contains the individual covariates,
#'   \item \code{originalId.txt} : contains the original id's when group is used with a different size than the original one,
#'   \item \code{outputi.txt} : contains the output number i informations (time, id),
#'   \item \code{$(NameOfTypeOfParameter)s.txt} : contains the specific parameter used.
#' }       
#' 
#' @examples
#' \dontrun{
#' project.file <- 'monolixRuns/theophylline1_project.mlxtran'  #relative path
#' monolix2simulx(project=project.file,open=TRUE)
#' monolix2simulx(project=project.file,parameter=list("mean",c(a=0, b=0)),open=TRUE)
#' }
#' @importFrom tools file_path_sans_ext
#' @export

monolix2simulx <-function(project,parameter=NULL,group=NULL,open=FALSE,r.data=TRUE,fim=NULL){ 
  
  # !! RETRO-COMPTATIBILITY ========================================================== !!
  if (!.useLixoftConnectors()) # < 2019R1
    myOldENVPATH = Sys.getenv('PATH')
  else if (!.checkLixoftConnectorsAvailibility()) # >= 2019R1
    return()
  # !! =============================================================================== !!
  
  if (!initMlxR()$status)
    return()
  
  # !! RETRO-COMPTATIBILITY ========================================================== !!
  if (!.useLixoftConnectors()){ # < 2019R1
    session = Sys.getenv("session.simulx")
    Sys.setenv(LIXOFT_HOME = session)
  }
  # !! =============================================================================== !!  
  
  
  
  #------- project to be converted into Simulx project
  # if (!is.null(names(group)))
  #   group <- list(group)
  ans <- processing_monolix(project=project,
                            model=NULL,
                            treatment=NULL,
                            parameter=parameter,
                            regressor=NULL,
                            output=NULL,
                            group=group,
                            r.data=r.data,
                            fim=fim,
                            error.iov=FALSE)
  model         <- ans$model
  treatment     <- ans$treatment
  parameter     <- ans$param
  output        <- ans$output
  #group         <- ans$group
  regressor     <- ans$regressor
  occasion      <- ans$occ
  fim           <- ans$fim
  catNames      <- ans$catNames
  catNames.iov      <- ans$catNames.iov
  mlxtranpath <- dirname(project)
  mlxtranfile = file_path_sans_ext(basename(project))
  mypath <- getwd()
  Rproject <- file.path(mypath,paste0(mlxtranfile,"_simulx"))
  if(file.exists(Rproject) )
    unlink(Rproject, recursive = TRUE, force = TRUE)
  modelname = basename(model)
  Sys.sleep(0.2)
  dir.create(Rproject, showWarnings = FALSE, recursive = FALSE, mode = "0777")
  file.copy(model, Rproject, overwrite = FALSE)
  file.remove(model)
  model<-file.path(Rproject,modelname)
  
  #configure and write output 
  RprojectPath <- dirname(model)
  mlxtranfile = file_path_sans_ext(basename(project))
  projectExe <- file.path(RprojectPath,paste0(mlxtranfile,".R"))
  cat(paste0("# File generated automatically on ", Sys.time(),"\n \n"), file =projectExe, fill = FALSE, labels = NULL,append = TRUE)
#  cat("library(mlxR)  \n \nsetwd(dirname(parent.frame(2)$ofile)) \n\n# model \n", file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
  cat(paste0("\nsetwd(\"",RprojectPath,"\")"),"\n\n# model \n", file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
  cat(paste0("model<-\"",modelname,"\"\n"), file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
  
  list.out <- list(path=Rproject, code=projectExe, model=model)
  
  # write  treatment 
  if(!(is.null(treatment)) && length(treatment)>0){ 
    if (!is.null(treatment$value)){
      treat2<-matrix(treatment$value,nrow=nrow(treatment$value),ncol=ncol(treatment$value))
      colnames(treat2)<-treatment$colNames
      treatment <- treat2
    }
    write.table(treatment,file=file.path(Rproject,"/treatment.txt"),row.names=FALSE,quote=FALSE, sep=",")
    cat("\n# treatment\n", file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
    cat("trt <- read.csv(\"treatment.txt\") \n", file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
list.out$treatment <- file.path(Rproject,"/treatment.txt")
      }
  
  param.list <- NULL
  # occasion    
  if(!(is.null(occasion))) {  
    cat("\n# occasion \n", file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
    outfile = file.path(Rproject,paste0("/occasion.txt"))      
    write.table(occasion,file=outfile,row.names=FALSE,quote=FALSE, sep=",")
    list.out$occasion <- outfile
    cat(paste0("occasion <-read.csv(\"occasion.txt\")\n"),file =projectExe, fill = FALSE, labels = NULL, append = TRUE)             
    
    # cat(paste0("cov.occ <- occasion\n"), file =projectExe, fill = FALSE, labels = NULL, append = TRUE)             
    # cat(paste0("names(cov.occ)[3] <- \"OCC\"\n"), file =projectExe, fill = FALSE, labels = NULL, append = TRUE)             
    # cat(paste0("cov.occ[,3]<- as.factor(cov.occ[,3])"), file =projectExe, fill = FALSE, labels = NULL, append = TRUE)             
    # param.list <- "cov.occ"
  }
  
  # write  parameters   
  if(!(is.null(parameter))){  
    cat("\n# parameters \n", file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
    
    if (!is.null(ans$id)){
      outfile = file.path(Rproject,paste0("/originalId.txt"))      
      write.table(ans$id,file=outfile,row.names=FALSE,quote=FALSE, sep=",")
      list.out$originalId <- outfile
      
      cat(paste0("originalId<- read.csv('originalId.txt') \n"), file =projectExe, fill = FALSE, labels = NULL, append = TRUE) 
    }
    
    populationParameter <- parameter[[1]]
    if (!is.null(populationParameter)){
      outfile = file.path(Rproject,paste0("/populationParameter.txt"))      
      cat(paste0("populationParameter <- read.vector('populationParameter.txt') \n"), file =projectExe, fill = FALSE, labels = NULL, append = TRUE) 
      list.out$populationParameter <- outfile
      write.table(populationParameter,file=outfile,col.names=FALSE,quote=FALSE, sep=",")
      
      if (!is.null(param.list))
        param.list <- paste(param.list,"populationParameter",sep=",")  
      else
        param.list <- "populationParameter"
    } 
    
    individualCovariate <- parameter[[2]]
    if (!is.null(individualCovariate)){
      indcov <- "individualCovariate"
      if (!is.null(occasion)) 
        indcov <- paste0(indcov, "IIV")
      
      outfile = file.path(Rproject,paste0("/",indcov,".txt"))  
      if(!is.null(catNames)){
        
        cat(paste0("colCatType <- rep(NA,",ncol(individualCovariate),")\n"),file =projectExe, fill = FALSE, labels = NULL, append = TRUE) 
        catNamesCols <-which(colnames(individualCovariate)%in%catNames)
        cat(paste0("catNamesCols <- c(",catNamesCols[1]),file =projectExe, fill = FALSE, labels = NULL, append = TRUE) 
        for(i in seq(2,length(catNames))){
          cat(paste0(",",catNamesCols[i]), file =projectExe, fill = FALSE, labels = NULL, append = TRUE) 
        }
        cat(")\n", file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
        cat(paste0("colCatType[catNamesCols] <- rep(\"character\",",length(catNames),")\n"),file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
        cat(paste0(indcov," <- lixoft.read.table(file='",indcov,".txt', header = TRUE, colClasses = colCatType, na.strings=NULL) \n"), file =projectExe, fill = FALSE, labels = NULL, append = TRUE) 
      }else{
        cat(paste0(indcov," <- read.csv(file='",indcov,".txt') \n"), file =projectExe, fill = FALSE, labels = NULL, append = TRUE) 
      }
      write.table(individualCovariate,file=outfile,row.names=FALSE,quote=FALSE, sep=",")
      list.out$covariate <- outfile
      if (!is.null(param.list))
        param.list <- paste(param.list,indcov,sep=",")  
      else
        param.list <- indcov
      i.factor <- which(sapply(individualCovariate[-1], is.factor))
      if (length(i.factor)>0)
        cat(paste0(indcov,"[,",i.factor+1,"] <- as.factor(",indcov,"[,",i.factor+1,"]) \n"), file =projectExe, fill = FALSE, labels = NULL, append = TRUE) 
    } 
    
    if (length(parameter)>=4) {
      individualCovariate.iov <- parameter[[4]]
      if (!is.null(individualCovariate.iov)){
        outfile = file.path(Rproject,paste0("/individualCovariateIOV.txt"))  
        if(!is.null(catNames.iov)){
          
          cat(paste0("colCatType <- rep(NA,",ncol(individualCovariate.iov),")\n"),file =projectExe, fill = FALSE, labels = NULL, append = TRUE) 
          catNamesCols.iov <-which(colnames(individualCovariate.iov)%in%catNames.iov)
          cat(paste0("catNamesCols <- c(",catNamesCols.iov[1]),file =projectExe, fill = FALSE, labels = NULL, append = TRUE) 
          for(i in seq(2,length(catNames.iov))){
            cat(paste0(",",catNamesCols.iov[i]), file =projectExe, fill = FALSE, labels = NULL, append = TRUE) 
          }
          cat(")\n", file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
          cat(paste0("colCatType[catNamesCols] <- rep(\"character\",",length(catNames.iov),")\n"),file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
          cat(paste0("individualCovariateIOV <- lixoft.read.table(file='individualCovariateIOV.txt', header = TRUE,colClasses = colCatType) \n"), file =projectExe, fill = FALSE, labels = NULL, append = TRUE) 
        }else{
          cat(paste0("individualCovariateIOV <- read.csv(file='individualCovariateIOV.txt') \n"), file =projectExe, fill = FALSE, labels = NULL, append = TRUE) 
        }
        write.table(individualCovariate.iov,file=outfile,row.names=FALSE,quote=FALSE, sep=",")
        list.out$covariate.iov <- outfile
        param.list <- paste(param.list,"individualCovariateIOV",sep=",")  
        i.factor <- which(sapply(individualCovariate.iov[-1], is.factor))
        if (length(i.factor)>0){
          cat(paste0("individualCovariateIOV[,",i.factor+1,"]<- as.factor(individualCovariateIOV[,",i.factor+1,"]) \n"), file =projectExe, fill = FALSE, labels = NULL, append = TRUE) 
        }
      }
    }
    
    individualParameter <- parameter[[3]]
    if (!is.null(individualParameter)){
      outfile = file.path(Rproject,paste0("/individualParameter.txt"))      
      cat(paste0("individualParameter <- read.csv('individualParameter.txt') \n"), file =projectExe, fill = FALSE, labels = NULL, append = TRUE) 
      write.table(individualParameter,file=outfile,row.names=FALSE,quote=FALSE, sep=",")
      list.out$individualParameter <- outfile
      if (!is.null(param.list))
        param.list <- paste(param.list,"individualParameter",sep=",")  
      else
        param.list <- "individualParameter"
    } 
    
    param.list <- paste(param.list,sep=",")
    param.str <- paste0("list.param <- list(",param.list,")")
    cat(param.str, file =projectExe, fill = FALSE, labels = NULL, append = TRUE)   
  }
  
  if (!is.null(group)) {
    cat("\n\n# group", file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
    cat(paste0("\ngrp =  list(size = ",group$size, ")\n"), file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
  }
  # write f.i.m
  if(!(is.null(fim))) {
    outfile <- file.path(Rproject,"/fim.txt")
    write.table(fim,file=outfile,row.names=FALSE,quote=FALSE, sep=",") 
    list.out$fim <- outfile
  }
  # write  requested output 
  if(!(is.null(output))) {  
    cat("\n# output \n", file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
    
    if(length(output)==1)
    {
      out1 <- output[[1]]
      out1.name <- out1$name 
      cat(paste0("name <- \"",out1.name,"\"\n"), file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
      cat(paste0("time <- read.csv(\"output.txt\",header=TRUE, sep=',')\n"),file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
      cat(paste0("out <- list(name=name,time=time) \n"), file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
      outfile = file.path(Rproject,"/output.txt")
      write.table(out1$time,file=outfile,row.names=FALSE,quote=FALSE, sep=",") 
      list.out$output <- outfile
    } else {    # many types of output could exist
      list.out$output <- NULL
      for(i in seq(1:length(output))) {
        outi <- output[[i]]
        outi.name <- outi$name
        cat(paste0("name <- \"",outi.name,"\"\n"), file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
        if(is.data.frame(outi$time)) {
          cat(paste0("time <- read.csv(\"output",i,".txt\",header=TRUE, sep=',')\n"),file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
          cat(paste0("out",i," <- list(name=name,time=time) \n"), file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
          outfile = paste0(file.path(Rproject,paste0("/output",i)),".txt")
          write.table(outi$time,file=outfile,row.names=FALSE,quote=FALSE, sep=",") 
          list.out$output <- c(list.out$output, outfile)
        } else {
          cat(paste0("out",i," <- list(name=name) \n"), file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
        }
      }
      
      cat("out<-list(out1", file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
      for(i in seq(2,length(output))) {
        cat(paste0(",out",i), file =projectExe, fill = FALSE, labels = NULL, append = TRUE)   
      }
      cat(")\n", file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
    }
  }
  
  # regressor    
  if(!(is.null(regressor))) {  
    cat("\n# regressor \n", file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
    outfile = file.path(Rproject,paste0("/regressor.txt"))    
    write.table(regressor,file=outfile,row.names=FALSE,quote=FALSE, sep=",")
    list.out$regressor <- outfile
    cat(paste0("regressor <- read.csv(\"regressor.txt\")\n"),file =projectExe, fill = FALSE, labels = NULL, append = TRUE)             
  }
  
  
  # call the simulator
  cat("\n# call the simulator \n", file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
  cat("res <- simulx(model=model", file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
  if(!(is.null(treatment))&& length(treatment)>0)  
    cat(",treatment=trt",file =projectExe, fill = FALSE, labels = NULL, append = TRUE) 
  
  if(!(is.null(parameter)))
    cat(",parameter=list.param",file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
  
  if(!(is.null(group))) 
    cat(",group=grp",file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
  
  if(!(is.null(output)))
    cat(",output=out",file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
  
  if(!(is.null(regressor)))
    cat(",regressor=regressor",file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
  
  if(!(is.null(occasion)))
    cat(",varlevel=occasion",file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
  
  cat(")\n",file =projectExe, fill = FALSE, labels = NULL, append = TRUE)
  
  
  # !! RETRO-COMPTATIBILITY - < 2019R1 =============================================== !!
  if (!.useLixoftConnectors())
    Sys.setenv('PATH' = myOldENVPATH)
  # !! =============================================================================== !!
  
  if ( (Sys.getenv("RSTUDIO")=="1") & (open==TRUE) ) {
    eval(parse(text='file.edit(projectExe)'))
    # file.edit(projectExe) 
    setwd(mypath)
  }
  
  return(list.out)
}

# ----------------------------------
clean.id <- function(x) {
  if (!is.null(x$id$oriId)) {
    if (length(grep(" ",levels(x$id$oriId)))>0) {
      x$id$oriId <- gsub(" ","_",x$id$oriId)
      for (k in (1:length(x))) {
        xk <- x[[k]]
        if (is.data.frame(xk) && !is.null(xk$id)) {
          x[[k]]$id <- gsub(" ","_",xk$id)
        } else {
          for (j in (1:length(xk))) {
            xkj <- xk[[j]]
            if (is.data.frame(xkj) && !is.null(xkj$id)) {
              x[[k]][[j]]$id <- gsub(" ","_",xkj$id)
            } else {
              for (l in (1:length(xkj))) {
                xkjl <- xkj[[l]]
                if (is.data.frame(xkjl) && !is.null(xkjl$id)) {
                  x[[k]][[j]][[l]]$id <- gsub(" ","_",xkjl$id)
                }
              }
            }
          }
        }
      }
    }
  }
  return(x)
}




