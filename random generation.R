rm(list = ls())  # clear list
### Check the working directory
getwd()

library(xlsx) 
dat=read.xlsx("Book1.xlsx",sheetIndex=1)
m=dat[,3]

s=dat[,4]
b=dat[,5]

sample(s,10)
