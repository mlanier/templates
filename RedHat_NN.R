
# The following two commands remove any previously installed H2O packages for R.
if ("package:h2o" %in% search()) { detach("package:h2o", unload=TRUE) }
if ("h2o" %in% rownames(installed.packages())) { remove.packages("h2o") }

# Next, we download packages that H2O depends on.
pkgs <- c("methods","statmod","stats","graphics","RCurl","jsonlite","tools","utils")
for (pkg in pkgs) {
  if (! (pkg %in% rownames(installed.packages()))) { install.packages(pkg) }
}

# Now we download, install and initialize the H2O package for R.
install.packages("h2o", type="source", repos=(c("http://h2o-release.s3.amazonaws.com/h2o/rel-turing/3/R")))
library(h2o)

library(devtools)
#install_github("h2oai/h2o-3/h2o-r/ensemble/h2oEnsemble-package")
library(h2oEnsemble)

library(caret) #preprocessing
library(dplyr) # data manipulation
library(rpart) # rpart for imputation
setwd("C:\\Users\\Lanier\\Desktop\\Red")
#Load Data


# Read the data
train_master <-read.csv(file="act_train_preproccess.csv",header=T,stringsAsFactors = TRUE )
attach(train_master)
train_master=cbind(char_2,char_7,char_8,char_9,char_13,char_38,outcome=outcome)

#Start up h20 cluster for deep learning

h2o.shutdown(prompt = TRUE)

h2o.init(nthreads = -1, max_mem_size="10g")
dat_h2o = as.h2o(train_master) #Convert to h2o dataframe

train_master=dat_h2o

# Split up train and test data


splits = h2o.splitFrame(train_master, c(0.6,0.2), seed=1234) #split into train and test
train  = h2o.assign(splits[[1]], "train.hex") # 60%
valid  = h2o.assign(splits[[2]], "valid.hex") # 20%
test   = h2o.assign(splits[[3]], "test.hex")  # 20%


train$outcome=as.factor(train$outcome)
response <- "outcome"
predictors <- setdiff(names(train), outcome)
predictors
str(train)




#Try first model
m1 <- h2o.deeplearning(
  model_id="dl_model_first", 
  training_frame=train, 
  validation_frame=valid,   ## validation dataset: used for scoring and early stopping
  x=predictors,
  y=response,
  loss="CrossEntropy",
  activation="Rectifier",  ## default
  hidden=c(200,200),       ## default: 2 hidden layers with 200 neurons each
  epochs=1,
  variable_importances=T    ## not enabled by default
)


#examine model
plot(m1)
summary(m1)


#.83 accuracy
#.89 auc

Bayes=h2o.naiveBayes(  model_id="Bayes", 
 training_frame=train,  ignore_const_cols = TRUE,
  laplace = 0, threshold = 0.001, eps = 0, compute_metrics = TRUE,
  max_runtime_secs = 0,  x=predictors,
  y=response)
print(Bayes)

#auc .88
#.82 accuracy

mboost <- h2o.gbm(training_frame=train,   model_id="mboost",
 validation_frame=valid,   
x=predictors,   
  y=response,
seed=159
   , ntrees = 500, max_depth = 10, min_rows = 10,learn_rate=.0001,
  stopping_metric="misclassification",   stopping_tolerance=0.1)
print(mboost)
plot(mboost)
#AUC .91
#accuracy .85

#### Random Hyper-Parameter Search

hyper_params <- list(
  activation=c("Rectifier","Tanh","Maxout","RectifierWithDropout","TanhWithDropout","MaxoutWithDropout"),
  hidden=list(c(20,20),c(100,75,50),c(25,25,25,25),c(2,4,6,8,6,4,2),c(2000,1000,500)),
  input_dropout_ratio=seq(.4,.6,by=.01), #For ensemble effect see Hinton's work for explaination
  l1=seq(0,1e-4,1e-6),
  l2=seq(0,1e-4,1e-6),               
  rate=seq(0.001,.7,by=.001) ,
  rate_annealing=seq(0,2e-4,by= 1e-5)
  
)
hyper_params


## Stop once the top 5 models are within 1% of each other (i.e., the windowed average varies less than 1%)
search_criteria = list(strategy = "RandomDiscrete", max_runtime_secs = 360, max_models = 100, seed=1234567, stopping_rounds=10, stopping_tolerance=1e-2)
dl_random_grid <- h2o.grid(
  algorithm="deeplearning",
  grid_id = "dl_grid_random",
  training_frame=train,
  validation_frame=valid, 
  x=predictors, 
  y=response,
  epochs=5,
  loss="CrossEntropy",
  stopping_metric="misclassification",
  stopping_tolerance=1e-2,       
  stopping_rounds=4,
  score_validation_samples=500, ## downsample validation set for faster scoring
  score_duty_cycle=0.025,         ## don't score more than 2.5% of the wall time
  max_w2=5,                      ## can help improve stability for Rectifier
  hyper_params = hyper_params,
  search_criteria = search_criteria,
  variable_importances=T,
  standardize=TRUE
  #  ,
  #  pretrained_autoencoder="ae_model"
)            



#examine grid
grid <- h2o.getGrid("dl_grid_random",sort_by="accuracy",decreasing=TRUE)
grid

grid@summary_table[1,]
best_model <- h2o.getModel(grid@model_ids[[1]]) ## model with highest accuracy
plot(best_model)

#acccuracy .83
#auc .89



mboost <- h2o.gbm(training_frame=train,   model_id="mboost",
                  validation_frame=valid,   
                  x=predictors,   
                  y=response,
                  seed=159
                  , ntrees = 1000, max_depth = 10, min_rows = 10,learn_rate=.0001,
                  stopping_metric="misclassification",   stopping_tolerance=0.1)
print(mboost)
plot(mboost)
#.85
#auc .91


learner <- c("h2o.glm.wrapper", "h2o.randomForest.wrapper", 
             "h2o.gbm.wrapper", "h2o.deeplearning.wrapper")
metalearner <- "h2o.glm.wrapper"
fit <- h2o.ensemble(  x=predictors, 
                      y=response, 
                    training_frame = train, 
                    family = "binomial", 
                    learner = learner, 
                    metalearner = metalearner,
                    cvControl = list(V = 5))

pred <- predict(fit, test)
predictions <- as.data.frame(pred$pred)[,3]  #third column is P(Y==1)
labels <- as.data.frame(test[,response])[,1]
library(cvAUC)
cvAUC::AUC(predictions = predictions, labels = labels)

#AUC .93
L <- length(learner)
auc <- sapply(seq(L), function(l) cvAUC::AUC(predictions = as.data.frame(pred$basepred)[,l], labels = labels)) 
data.frame(learner, auc)

h2o.shutdown()


h2o_yhat_test_dl <- as.data.frame(h2o_yhat_test_dl) 
h2o_yhat_test_dl =test_agg [,-1]
h2o_yhat_test_dl =cbind(as.data.frame(test_id[,1]),h2o_yhat_test_dl )
colnames(h2o_yhat_test_dl)[1] <- "ID"
write.csv(h2o_yhat_test_dl,file="submission.csv", row.names=FALSE)


