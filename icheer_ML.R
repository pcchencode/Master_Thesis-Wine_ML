setwd("/home/wine2/new_data_20170425")
library(readstata13)
DATA=read.dta13("data_for_ML.dta")
## Need some revision to do the ML model in R
DATA$order[DATA$order==1] <- "Yes"
DATA$order[DATA$order==0] <- "No"
DATA$reg_state[DATA$reg_state==1] <- "Yes"
DATA$reg_state[DATA$reg_state==0] <- "No"
DATA$cluster3[DATA$cluster3==1] <-"A"
DATA$cluster3[DATA$cluster3==2] <-"B"
DATA$cluster3[DATA$cluster3==3] <-"C"
DATA$cluster3[DATA$cluster3==4] <-"D"
names <- c("order", "reg_state", "cluster3", "month")
DATA[, names] <- lapply(DATA[, names], factor) # To change the new var as factor
rm(names)

## Split the data into training set and testing set
set.seed(30) #設定隨機種子的目的在於使之後的模擬結果一樣
train.index <- sample(x=1:nrow(DATA), size=ceiling(0.8*nrow(DATA) ))
train <- DATA[train.index, ]
test <- DATA[-train.index, ]
###############################
## Decision Tree Model
#install.packages("rpart") # rpart is the package of decision tree
#install.packages("rpart.plot") # rpart.plot is package to plot the tree
library(rpart)
set.seed(30)
Tree <- rpart(order ~ dur + pages + reg_state + Ffilter + Sfilter + Tfilter, data = train)

library(rpart.plot)
prp(Tree, extra=108 , type=3, fallen.leaves = TRUE)

pred <- predict(Tree, newdata=test, type="class")
table(real=test$purchase, predict=pred)
confus.matrix <- table(real=test$purchase, predict=pred)
sum(diag(confus.matrix))/sum(confus.matrix) # This represents the predictive power of model


## Random Forest Model
#install.packages("randomForest")
library(useful)
library(randomForest)

# decide the optimal mtry
n <- length(names(train[, c("DP", "VP", "MPP", "WLP", "WDP", "WIP", "member")]))
set.seed(30)
err <- c(1)
for (i in 1:(n-1)){
  test_model <- randomForest(y= train$purchase, x=train[, c("DP", "VP", "MPP", "WLP", "WDP", "WIP", "member")] ,
                             mtry=i)
  err[i]<- mean(test_model$err.rate)
  #print(err)
}
which.min(err) # min is the optinal mtry, which is 6 here
# decide the optimal ntree
set.seed(30)
tran_model <- randomForest(y= train$purchase, x=train[, c("DP", "VP", "MPP", "WLP", "WDP", "WIP", "member")],
                           mtry=6,ntree=1000)
plot(tran_model) # ntree=200 is suitable


set.seed(30)  

# Forest <- randomForest(purchase~ DP + VP + MPP + WLP + WDP + WIP + member , data=train, importance= TRUE, proximity= TRUE,
#                              ntree=1,mtry=7)
# Since using the formula of rf will create a huge matrix, which will crush Rstudio

Forest <- randomForest(y= train$purchase, x=train[, c("DP", "VP", "MPP", "WLP", "WDP", "WIP", "member")] ,
                       ytest= test$purchase, xtest= test[, c("DP", "VP", "MPP", "WLP", "WDP", "WIP", "member")],
                       importance= TRUE, ntree=200, mtry=6)

Forest
plot(Forest$err.rate[,1])cr
confus.matrix <- Forest$test$confusion
confus.matrix # evaluate the prediction power
sum(diag(confus.matrix))/sum(confus.matrix) # using test.data to show the prediction rate

round(importance(Forest), 2) # round函數為四捨五入，數字代表小數點以下進位
varImpPlot(Forest) # plot order of important variables

############### Packages from Jauer's model(start from here)##################
# Load all packages
library(caret)
library(rpart)
library(rpart.plot)
library(RColorBrewer)
library(randomForest)
library(neuralnet)
library(nnet)
library(ROCR)
# Split sample into training set and validation set with 80-20 split
# intrain <- createDataPartition(y=DATA$purchase, p=0.8, list=FALSE)
# train <- DATA[intrain,]
# test <- DATA[-intrain,]

## Decision Tree Model
set.seed(30)
treeFit <- train(y= train$order, 
                 x=train[, c("duration","pages","cluster3","reg_state", "month")], 
                 trControl=trainControl(method="cv", number=10, sampling="smote")
                 ,method="rpart", metric="Accuracy")
# here we'll use the non-formula method to keep the factor as factor.
# k-folds here will takes lots of time, and we've verified that the result 
# from k=2,5,non-spec is not significantly different, so we apply k=5 initially.
print(treeFit$finalModel)
print(treeFit) # print the quality result
plot(treeFit, xlab="Complexity Parameter (CP)") # plot the optimal parameter: CP
# Plot the decision tree
prp(treeFit$finalModel, extra=108 , type=3, fallen.leaves = TRUE)
# Claculate the confusion matrix
treePredict <- predict(treeFit, test)
confusionMatrix(treePredict, test$order, positive = "Yes", mode="everything")
# plot the roc curve
# method 1
#treepredict <- predict(treeFit, test, type="prob")
#prediction <- prediction(as.numeric(treepredict[,2]), as.numeric(test$order))
#roc <- performance(prediction, "tpr", "fpr")
#plot(roc)
# method 2: using ggplot to get better figure
prob.tree <- predict(treeFit, test, type="prob")
pred.tree <- prediction(as.numeric(prob.tree[,2]), as.numeric(test$order))
perf.tree <- performance(pred.tree, measure = "tpr", x.measure = "fpr")

auc.tree <- performance(pred.tree, measure = "auc")
auc.tree <- auc.tree@y.values[[1]]

# check the cutoff value, which is depend on the prob. of predicting positive
unique(prob.tree$Yes)
pred.tree@cutoffs

roc.data.tree <- data.frame(fpr=unlist(perf.tree@x.values),
                            tpr=unlist(perf.tree@y.values)
)
ggplot(roc.data.tree, aes(x=fpr, ymin=0, ymax=tpr)) +
  geom_ribbon(alpha=0.2, fill="#56B4E9") +
  geom_line(aes(y=tpr), colour="#56B4E9") + 
  ggtitle(paste0("ROC Curve with AUC=", auc.tree)) +
  theme(plot.title = element_text(hjust = 0.5)) +
  labs(y = "Sensitivity", x="False Positive Rate") +
  geom_abline(intercept = 0, slope = 1, linetype="dotted")

## Random Forest Model
set.seed(30)
forestFit <- train(y= train$order, 
                   x=train[, c("duration","pages", "cluster3","reg_state","month")]
                   , method="rf", importance = TRUE, ntree=800,
                   trControl=trainControl(method="cv", number=10, sampling="smote"))
print(forestFit)

plot(forestFit, xlab="# of Randomly Selected Predictors (mtry)") # plot the process of choosing mtry

# calculate the confusion matrix
forestPredict <- predict(forestFit, test)
confusionMatrix(forestPredict,test$order,positive="Yes", mode="everything")
# plot the table of importance
varImpPlot(forestFit$finalMode,main="Variable Importance")
importance(forestFit$finalMode, scale=FALSE) # print the value
importance= data.frame(forestFit$finalMode$importance)
sum(importance$MeanDecreaseAccuracy)

# plot the ROC curve
# method 1
#forestpredict <- predict(forestFit, test, type="prob")
#prediction <- prediction(as.numeric(forestpredict[,2]), as.numeric(test$order))
#roc <- performance(prediction, "tpr", "fpr")
#plot(roc)
# method 2: using ggplot to get better figure
prob.forest <- predict(forestFit, test, type="prob")
pred.forest <- prediction(as.numeric(prob.forest[,2]), as.numeric(test$order))
perf.forest <- performance(pred.forest, measure = "tpr", x.measure = "fpr")

auc.forest <- performance(pred.forest, measure = "auc")
auc.forest <- auc.forest@y.values[[1]]

roc.data.forest <- data.frame(fpr=unlist(perf.forest@x.values),
                              tpr=unlist(perf.forest@y.values)
)
ggplot(roc.data.forest, aes(x=fpr, ymin=0, ymax=tpr)) +
  geom_ribbon(alpha=0.2, fill="#E69F00") +
  geom_line(aes(y=tpr), colour="#E69F00") + 
  ggtitle(paste0("ROC Curve with AUC=", auc.forest)) +
  theme(plot.title = element_text(hjust = 0.5)) +
  labs(y = "Sensitivity", x="False Positive Rate") +
  geom_abline(intercept = 0, slope = 1, linetype="dotted")

# plot Learning Curve(incorrect scale on Y-axis, but more pretty)
plot(forestFit$finalModel$err.rate[,3], col="green", xlab="ntree", ylab="err.rate"
     , axes=FALSE, frame.plot=TRUE, type="l")
par(new=TRUE)
plot(forestFit$finalModel$err.rate[,2], col="red", xlab="", ylab="",
     axes=FALSE, frame.plot=TRUE, type="l")
par(new=TRUE)
plot(forestFit$finalModel$err.rate[,1], xlab="", ylab="", axes=FALSE, frame.plot=TRUE,type="l")
axis(1, at = seq(0, 1100, by = 100), las=2) # add correct grid on x-axis
axis(2, at = seq(0, 0.5, by = 0.5), las=2) # add correct grid on y-axis
legend("topright",
       pch=c(1,1,1),
       col=c("black","red","green"),
       legend=c("Total","No","Yes")
) #add legend in the plot


# drawing the learning curve(with correct scale on Y-axis, not so pretty...)
err.rate <- data.frame(forestFit$finalModel$err.rate)
err.rate$Index <- seq_len(nrow(err.rate)) 
library(ggplot2)
ggplot(data = err.rate, aes(x = Index)) + 
  geom_line(aes(y = OOB, colour="Total")) +
  geom_line(aes(y = No, colour="No")) +
  geom_line(aes(y = Yes, colour="Yes")) + 
  labs(y = "Error Rate", x="Number of Tree (ntree)") +
  scale_colour_manual("" , values=c("#FF6633", "#999999", "#99FF00")) +
  theme(legend.position = c(0.85, 0.85), legend.text=element_text(size=20))

# plot a sample tree to show an example
to.dendrogram <- function(dfrep,rownum=1,height.increment=0.1){
  
  if(dfrep[rownum,'status'] == -1){
    rval <- list()
    
    attr(rval,"members") <- 1
    attr(rval,"height") <- -1.5
    attr(rval,"label") <- dfrep[rownum,'prediction']
    attr(rval,"leaf") <- TRUE
    
  }else{##note the change "to.dendrogram" and not "to.dendogram"
    left <- to.dendrogram(dfrep,dfrep[rownum,'left daughter'],height.increment)
    right <- to.dendrogram(dfrep,dfrep[rownum,'right daughter'],height.increment)
    rval <- list(left,right)
    
    attr(rval,"members") <- attr(left,"members") + attr(right,"members")
    attr(rval,"height") <- max(attr(left,"height"),attr(right,"height")) + height.increment
    attr(rval,"leaf") <- FALSE
    attr(rval,"edgetext") <- dfrep[rownum,'split var']
  }
  
  class(rval) <- "dendrogram"
  
  return(rval)
}
sampletree=getTree(forestFit$finalModel , k=1,labelVar=TRUE)
d <- to.dendrogram(sampletree)
str(d)
plot(d,center=TRUE,leaflab='none',edgePar=list(t.cex=1,p.col=NA,p.lty=0))

# combine ROC curve from two models together
ggplot() +
  geom_line(data=roc.data.tree ,aes(y=tpr, x=fpr, colour="decision tree")) +
  geom_ribbon(data=roc.data.tree, alpha=0.3,aes(x=fpr, ymin=0, ymax=tpr, fill=paste0("AUC=", round(auc.tree, digit=2)))) +
  geom_line(data=roc.data.forest ,aes(y=tpr, x=fpr, colour="random forest")) +
  geom_ribbon(data=roc.data.forest, alpha=0.2,aes(x=fpr, ymin=0, ymax=tpr, fill=paste0("AUC=", round(auc.forest, digit=2)))) +
  ggtitle("ROC curve") +
  labs(y = "Sensitivity", x="False Positive Rate") +
  geom_abline(intercept = 0, slope = 1, linetype="dotted") +
  scale_colour_manual("",values=c("#56B4E9", "#E69F00")) +
  scale_fill_manual("",values=c("#56B4E9", "#E69F00")) +
  theme(plot.title = element_text(hjust = 0.5), legend.text=element_text(size=20), legend.position="bottom", legend.direction="vertical") 

