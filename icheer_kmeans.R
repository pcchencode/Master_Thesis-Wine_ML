setwd("/home/wine2/new_data_20170425")
library(readstata13)
data=read.dta13("data_for_kmeans.dta")
data <- data[, -1] #因為第一個column是history_id，影響分群將其移除

# Elbow Method 應用在 K-Means
ratio <- rep(NA, times = 12)
for (k in 2:length(ratio)) {
  kmeans_fit <- kmeans(data, centers = k)
  ratio[k] <- kmeans_fit$tot.withinss / kmeans_fit$betweenss
}

plot(ratio, type="b", xlab="k", xaxt="n") # Plot the elbow, hence we know the optimal k=3
axis(1, at=2:12) # modify the x-axis
#abline(v=3, col="red", lwd=3, lty=2) # add the vetical line

# kmeans process
kmeans.cluster <- kmeans(data, centers=3) 
#data <- cbind(data, Group = kmeans.cluster$cluster) # attach cluster result in data.frame
center <- data.frame(kmeans.cluster$center) # Center for each group

# visualize the clustering process

# visualize the cluster via PCA dimension(first 2)
fviz_cluster(kmeans.cluster,           # 分群結果
             data = data,              # 資料
             geom = c("point"), # 點和標籤(point & label)
             frame.type = "norm")      # 框架型態

# visualize the cluster through all pair-combination of variables
plot(data, col = kmeans.cluster$cluster)

# attach the cluster result to the data
data <- cbind(data, kmeans.cluster$cluster)

# save cluster result to dta.file
library(rio)
colnames(data)[4] <- "cluster" # modify the variable name to suit stata.format
export(data, "kmeans_result.dta")


