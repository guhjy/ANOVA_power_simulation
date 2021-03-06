ANOVA_design<-function(string, n, mu, sd, r, p_adjust){
  ###############
  # 1. Specify Design and Simulation----
  ###############
  # String used to specify the design
  # Add numers for each factor with 2 levels, e.g., 2 for a factor with 2 levels
  # Add a w after the number for within factors, and a b for between factors
  # Seperate factors with a * (asteriks)
  # Thus "2b*3w) is a design with 2 between levels, and 3 within levels
  
  #Check if design an means match up - if not, throw an error and stop
  if(prod(as.numeric(strsplit(string, "\\D+")[[1]])) != length(mu)){stop("the length of the vector with means does not match the study design")}
  
  #Set correlation if there is no within subjects factors
  nowithin <- grepl("w", string)
  if(nowithin == "FALSE") {
    r=0
  }
  
  #Check to ensure sd is greater than the correlation
  if(r > sd) {
    error <- "Sorry, the correlation must be greater than the standard deviation"
    stop(error)
  }
  
  ###############
  # 2. Load libraries ----
  ###############
  
  library(mvtnorm)
  library(afex)
  library(lsmeans)
  library(ggplot2)
  library(gridExtra)
  library(reshape2)

  
  ###############
  # 2. Create Dataframe based on Design ----
  ###############
  #Set correlation if there is no within subjects factors
  nowithin <- grepl("w", string)
  if(nowithin == "FALSE") {
    r=0
  }
  
  #Count number of factors in design
  factors <- length(as.numeric(strsplit(string, "\\D+")[[1]]))
  
  
  #Specify within/between factors in design: Factors that are within are 1, between 0
  design <- strsplit(gsub("[^A-Za-z]","",string),"",fixed=TRUE)[[1]]
  design <- as.numeric(design == "w") #if within design, set value to 1, otherwise to 0
  
  ################################################################################################################################################
  sigmatrix <- matrix(r, length(mu),length(mu)) #create temp matrix filled with value of correlation, nrow and ncol set to length in mu
  diag(sigmatrix) <- sd # replace the diagonal with the sd
  ################################################################################################################################################
  

  
  ################################################################################################################################################
  #Create the data frame. This will be re-used in the simulation (y variable is overwritten) but created only once to save time in the simulation
  df <- as.data.frame(rmvnorm(n=n,
                              mean=mu,
                              sigma=sigmatrix))
  ################################################################################################################################################
  
  df$subject<-as.factor(c(1:n)) #create temp subject variable just for merging

  #Melt dataframe
  df <- melt(df, 
             id.vars = "subject", 
             variable.name = "cond",
             value.name = "y")
  
  # Let's break this down - it's a bit tricky. First, we want to create a list of a1 a2 b1 b2 that will indicate the factors. 
  # We are looping this over the number of factors.
  # This: as.numeric(strsplit(string, "\\D+")[[1]]) - takes the string used to specify the design and turn it in a list. 
  # we take the letters from the alfabet: paste(letters[[j]] and add numbers 1 to however many factors there as: 1:as.numeric(strsplit(string, "\\D+")[[1]])[j], sep="")
  # We this get e.g. ,a1 a2 - we repeat these each: n*(2^(factors-1)*2)/(2^j) and them times:  (2^j/2) to get a list for each factor
  # We then bind these together with the existing dataframe.
  for(j in 1:factors){
    df <- cbind(df, as.factor(unlist(rep(as.list(paste(letters[[j]], 
                                                       1:as.numeric(strsplit(string, "\\D+")[[1]])[j], 
                                                       sep="")), 
                                         each = n*prod(as.numeric(strsplit(string, "\\D+")[[1]]))/prod(as.numeric(strsplit(string, "\\D+")[[1]])[1:j]),
                                         times = prod(as.numeric(strsplit(string, "\\D+")[[1]]))/prod(as.numeric(strsplit(string, "\\D+")[[1]])[j:factors])
    ))))
  }
  #Rename the factor variables that were just created
  names(df)[4:(3+factors)] <- letters[1:factors]
  
  #Create subject colum (depends on design)
  subject <- 1:n #Set subject to 1 to the number of subjects collected
  
  for(j2 in length(design):1){ #for each factor in the design, from last to first
    #if w: repeat current string as often as the levels in the current factor (e.g., 3)
    #id b: repeat current string + max of current subject
    if(design[j2] == 1){subject <- rep(subject,as.numeric(strsplit(string, "\\D+")[[1]])[j2])}
    subject_length <- length(subject) #store current length - to append to string of this length below
    if(design[j2] == 0){
      for(j3 in 2:as.numeric(strsplit(string, "\\D+")[[1]])[j2]){
        subject <- append(subject,subject[1:subject_length]+max(subject))
      }
    }
  }
  
  #Overwrite subject columns in df
  df$subject <- subject
  
  ###############
  # 3. Specify factors for formula ----
  ###############
  
  #one factor
  if(factors == 1 & sum(design) == 1){frml1 <- as.formula("y ~ a + Error(subject/a)")}
  if(factors == 1 & sum(design) == 0){frml1 <- as.formula("y ~ a + Error(1 | subject)")}
  
  if(factors == 2){
    if(sum(design) == 2){frml1 <- as.formula("y ~ a*b + Error(subject/a*b)")}
    if(sum(design) == 0){frml1 <- as.formula("y ~ a*b  + Error(1 | subject)")}
    if(all(design == c(1, 0)) == TRUE){frml1 <- as.formula("y ~ a*b + Error(subject/a)")}
    if(all(design == c(0, 1)) == TRUE){frml1 <- as.formula("y ~ a*b + Error(subject/b)")}
  }
  
  if(factors == 3){
    if(sum(design) == 3){frml1 <- as.formula("y ~ a*b*c + Error(subject/a*b*c)")}
    if(sum(design) == 0){frml1 <- as.formula("y ~ a*b*c + Error(1 | subject)")}
    if(all(design == c(1, 0, 0)) == TRUE){frml1 <- as.formula("y ~ a*b*c + Error(subject/a)")}
    if(all(design == c(0, 1, 0)) == TRUE){frml1 <- as.formula("y ~ a*b*c + Error(subject/b)")}
    if(all(design == c(0, 0, 1)) == TRUE){frml1 <- as.formula("y ~ a*b*c + Error(subject/c)")}
    if(all(design == c(1, 1, 0)) == TRUE){frml1 <- as.formula("y ~ a*b*c + Error(subject/a*b)")}
    if(all(design == c(0, 1, 1)) == TRUE){frml1 <- as.formula("y ~ a*b*c + Error(subject/b*c)")}
    if(all(design == c(1, 0, 1)) == TRUE){frml1 <- as.formula("y ~ a*b*c + Error(subject/a*c)")}
  }
  
  #Specify second formula used for plotting
  if(factors == 1){frml2 <- as.formula("~a")}
  if(factors == 2){frml2 <- as.formula("~a+b")}
  if(factors == 3){frml2 <- as.formula("~a+b+c")}
  
  ############################################
  #Specify factors for formula ###############
  design_list <- unique(apply((df)[4:(3+factors)], 1, paste, collapse=""))
  
  ###############
  # 4. Create Covariance Matrix ----
  ###############
  
  
  ################################################################################################################################################
  
  #Create empty matrix
  sigmatrix <- data.frame(matrix(ncol=length(mu), nrow = length(mu)))
  
   #General approach: For each factor in the list of the design, save the first item (e.g., a1b1)
   #Then for each factor in the design, if 1, set number to wildcard
  
  
  for(i1 in 1:length(design_list)){
    current_factor <- design_list[i1]
    current_factor <- unlist(strsplit(current_factor,"[a-z]"))
    current_factor <- current_factor[2:length(current_factor)]
    for(i2 in 1:length(design)){
      #We set each number that is within to a wildcard, so that all within subject factors are matched
      
      
      if(design[i2]==1){current_factor[i2] <- "*"}
      
      #depracated
      #if(design[i2] == 1){substr(current_factor, i2*2,  i2*2) <- "*"} 
    }
    ifelse(factors == 1, current_factor <- paste0(c("a"),current_factor, collapse=""),
           ifelse(factors == 2, current_factor <- paste0(c("a","b"),current_factor, collapse=""),
                  current_factor <- paste0(c("a","b","c"),current_factor, collapse="")))
    
    sigmatrix[i1,]<-as.numeric(grepl(current_factor, design_list)) # compare factors that match with current factor, given wildcard, save list to sigmatrix
  }
  
  sigmatrix <- as.matrix(sigmatrix*r)
  diag(sigmatrix) <- sd # replace the diagonal with the sd
  ################################################################################################################################################

  
  # We perform the ANOVA using AFEX
  aov_result<-aov_car(frml1, #here we use frml1 to enter fromula 1 as designed above on the basis of the design 
                      data=df,
                      anova_table = list(es = "pes", p_adjust_method = p_adjust)) #This reports PES not GES
  
  # pairwise comparisons
  pc <- pairs(emmeans(aov_result, frml2), adjust = p_adjust)
  
  ###############
  # 6. Create plot of means to vizualize the design ----
  ###############
  
  df_means <- data.frame(mu, SE = sd / sqrt(n))
  for(j in 1:factors){
    df_means <- cbind(df_means, as.factor(unlist(rep(as.list(paste(letters[[j]], 
                                                                   1:as.numeric(strsplit(string, "\\D+")[[1]])[j], 
                                                                   sep="")), 
                                                     each = prod(as.numeric(strsplit(string, "\\D+")[[1]]))/prod(as.numeric(strsplit(string, "\\D+")[[1]])[1:j]),
                                                     times = prod(as.numeric(strsplit(string, "\\D+")[[1]]))/prod(as.numeric(strsplit(string, "\\D+")[[1]])[j:factors])
    ))))
  }
  
  if(factors == 1){names(df_means)<-c("mu","SE","a")}
  if(factors == 2){names(df_means)<-c("mu","SE","a","b")}
  if(factors == 3){names(df_means)<-c("mu","SE","a","b","c")}
  
  if(factors == 1){meansplot = ggplot(df_means, aes(y = mu, x = a))}
  if(factors == 2){meansplot = ggplot(df_means, aes(y = mu, x = a, fill=b))}
  if(factors == 3){meansplot = ggplot(df_means, aes(y = mu, x = a, fill=b)) + facet_wrap(  ~ c)}
  
  meansplot = meansplot +
    geom_bar(position = position_dodge(), stat="identity") +
    geom_errorbar(aes(ymin = mu-SE, ymax = mu+SE), 
                  position = position_dodge(width=0.9), size=.6, width=.3) +
    coord_cartesian(ylim=c((.7*min(mu)), 1.2*max(mu))) +
    theme_bw() + ggtitle("Means for each condition in the design")
  print(meansplot)  
  
  # Return results in list()
  invisible(list(df = df,
                 design = design,
                 design_list = design_list, 
                 factors = factors, 
                 frml1 = frml1, 
                 frml2 = frml2, 
                 mu = mu, 
                 n = n, 
                 p_adjust = p_adjust, 
                 sigmatrix = sigmatrix,
                 string = string,
                 meansplot = meansplot))
}
