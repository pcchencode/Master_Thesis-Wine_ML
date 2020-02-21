##### original method ####
setwd("/home/wine2/new_data_20170425")
library(readstata13)
data=read.dta13("data_for_kmeans.dta")
## change the sequence to DSS format and create the sequence data
#  reshape...takes lots of time
library(reshape)
seq.matrix <- reshape(data, idvar = "history_id", timevar = "j", direction = "wide")

seq.data <- seqdef(seq.matrix, 2:114) # create the sequence data, we just consider the pages <5000
rm(seq.matrix)
rm(data)
# Visualize the sequence
#mark the legend
seqlegend(seq.data)
# plot the first index 10 sequences
seqiplot(seq.data, withlegend = F, title = "Index plot (10 first sequences)")
# plot the top-10 frequent seq. in the data
seqfplot(seq.data, withlegend = F, title = "Sequence frequency plot", border = NA)
# plot the state distribution of each time point
seqdplot(seq.data, withlegend = F, title = "State distribution plot", border = NA)


## Cluster the sequence
#submat <- seqsubm(seq.data, method = "TRATE")
dist.lcp <- seqdist(seq.data, method = "LCP")
# find the optimal k for method 2
library(WeightedCluster)  
agnesRange <- wcKMedRange(dist.lcp, 2:10)
plot(agnesRange, stat = c("ASW", "HG", "PBC"), lwd = 5, norm = "zscore")

# cluster method 1
library(cluster)
clusterward1 <- agnes(dist.lcp, diss = TRUE, method = "ward")
plot(clusterward1)

# cluster method 2 
cl1.4 <- cutree(clusterward1, k = 4)
cl1.4fac <- factor(cl1.4, labels = paste("Type", 1:4))
seqdplot(seq.data, group = cl1.4fac, border = NA)
seqfplot(seq.data, group = cl1.4fac, border = NA)

# save cluster result to dta.file
library(rio)
names(seq.matrix2) <- gsub("\\.", "", names(seq.matrix2))
export(seq.matrix2, "tt.dta")


####################### Weighted Cluster (start from here)###############
library(WeightedCluster)
setwd("/home/wine2/new_data_20170425")
library(readstata13)
data=read.dta13("data_for_seq_cluster.dta")
library(reshape)
seq.matrix <- reshape(data, idvar = "history_id", timevar = "j", direction = "wide")
seq.data <- seqdef(seq.matrix, -1) 
seq.data[seq.data == "%"] <- NA # fill % as NA to let the state be clear
aggSeq <- wcAggregateCases(seq.data)
print(aggSeq)
uniqueSeq <- seq.data[aggSeq$aggIndex, ] # the unique sequence data
# weighted sequence data
wseq.data <- seqdef(uniqueSeq, weights = aggSeq$aggWeights)

# visualize the sequence data
#mark the legend
seqlegend(wseq.data)
# plot the first index 10 sequences
seqiplot(wseq.data, withlegend = F, title = "Index plot (10 first sequences)")
# plot the top-10 frequent seq. in the data
seqfplot(wseq.data, withlegend = F, title = "Sequence frequency plot", border = NA)
# plot the state distribution of each time point
seqdplot(wseq.data, withlegend = T, title = "State distribution plot", border = NA)


# construct the distance matrix
dist.lcp <- seqdist(wseq.data, method = "LCP", full.matrix = TRUE) # distance matrix

# cluster quality to find the optimal k and cluster it at the meant time
pamClustRange <- wcKMedRange(dist.lcp, kvals = 2:10, weights = aggSeq$aggWeights)
plot(pamClustRange, stat = c("HC", "PBC", "ASW"), norm ="zscore", legendpos="topright") # seems the optimal k=3
axis(1,at=seq(2,10,1)) # add the scale on x-axis
#Add vertical grid
axis(1, at = 2:10, tck = 1, lty = 2, col = "grey", labels = NA)

# plot the cluster result
seqdplot(wseq.data, group = pamClustRange$clustering$cluster3, border = NA)

# attach the cluster result to original data
uniqueCluster3 <- pamClustRange$clustering$cluster3
seq.matrix$cluster3 <- uniqueCluster3[aggSeq$disaggIndex]
cluster3 <- data.frame(seq.matrix$history_id, seq.matrix$cluster3) # cluster3 result with history_id
colnames(cluster3) <- c("history_id","cluster3") # rename the column

# export cluster result to dta.file so as to merge with original data
library(rio)
export(cluster3, "cluster3.dta")

# weighted Seq cluster for order sent history####
library(WeightedCluster)
setwd("/home/wine2/new_data_20170425")
library(readstata13)
data=read.dta13("data_for_seq_cluster_order.dta")
library(reshape)
seq.matrix <- reshape(data, idvar = "history_id", timevar = "j", direction = "wide")
seq.data <- seqdef(seq.matrix, -1) 
seq.data[seq.data == "%"] <- NA # fill % as NA to let the state be clear
aggSeq <- wcAggregateCases(seq.data)
print(aggSeq)
uniqueSeq <- seq.data[aggSeq$aggIndex, ] # the unique sequence data
# weighted sequence data
wseq.data <- seqdef(uniqueSeq, weights = aggSeq$aggWeights)

# visualize the sequence data
#mark the legend
seqlegend(wseq.data)
# plot the first index 10 sequences
seqiplot(wseq.data, withlegend = F, title = "Index plot (10 first sequences)")
# plot the top-10 frequent seq. in the data
seqfplot(wseq.data, withlegend = F, title = "Sequence frequency plot", border = NA)
# plot the state distribution of each time point
seqdplot(wseq.data, withlegend = T, title = "State distribution plot", border = NA)


# construct the distance matrix
dist.lcp <- seqdist(wseq.data, method = "LCP", full.matrix = TRUE) # distance matrix

# cluster quality to find the optimal k and cluster it at the meant time
pamClustRange <- wcKMedRange(dist.lcp, kvals = 2:10, weights = aggSeq$aggWeights)
plot(pamClustRange, stat = c("HC", "PBC", "ASW"), norm ="zscore") # seems the optimal k=3

# plot the cluster result
seqdplot(wseq.data, group = pamClustRange$clustering$cluster3, border = NA)

# attach the cluster result to original data
uniqueCluster3 <- pamClustRange$clustering$cluster3
seq.matrix$cluster3 <- uniqueCluster3[aggSeq$disaggIndex]
cluster3 <- data.frame(seq.matrix$history_id, seq.matrix$cluster3) # cluster3 result with history_id
colnames(cluster3) <- c("history_id","cluster3") # rename the column

