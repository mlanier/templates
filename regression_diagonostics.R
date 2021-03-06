data=read.csv(file="example_data.csv",header=TRUE)
attach(data)
data
fit = lm(y~x)
resi = fit$resi
n=100

plot(fit)
library(plotly)
p=ggplot(data = ratio_test, aes(x = Day, y = Ratio,colour=Ratio)) +
  stat_smooth(aes(colour = Ratio,fill= Ratio),size=.1)+
  geom_point(aes(text = paste("Ratio:", Ratio)), size = 1)


(gg <- ggplotly(p))

diagPlot<-function(model){
    p1<-ggplot(model, aes(.fitted, .resid))+geom_point()
    p1<-p1+stat_smooth(method="loess")+geom_hline(yintercept=0, col="red", linetype="dashed")
    p1<-p1+xlab("Fitted values")+ylab("Residuals")
    p1<-p1+ggtitle("Residual vs Fitted Plot")+theme_bw()
       
    p2<-ggplot(model, aes(qqnorm(.stdresid)[[1]], .stdresid))+geom_point(na.rm = TRUE)
    p2<-p2+geom_abline()+xlab("Theoretical Quantiles")+ylab("Standardized Residuals")
    p2<-p2+ggtitle("Normal Q-Q")+theme_bw()

    
    p3<-ggplot(model, aes(.fitted, sqrt(abs(.stdresid))))+geom_point(na.rm=TRUE)
    p3<-p3+stat_smooth(method="loess", na.rm = TRUE)+xlab("Fitted Value")
    p3<-p3+ylab(expression(sqrt("|Standardized residuals|")))
    p3<-p3+ggtitle("Scale-Location")+theme_bw()
    
    p4<-ggplot(model, aes(seq_along(.cooksd), .cooksd))+geom_bar(stat="identity", position="identity")
    p4<-p4+xlab("Obs. Number")+ylab("Cook's distance")
    p4<-p4+ggtitle("Cook's distance")+theme_bw()
    
    p5<-ggplot(model, aes(.hat, .stdresid))+geom_point(aes(size=.cooksd), na.rm=TRUE)
    p5<-p5+stat_smooth(method="loess", na.rm=TRUE)
    p5<-p5+xlab("Leverage")+ylab("Standardized Residuals")
    p5<-p5+ggtitle("Residual vs Leverage Plot")
    p5<-p5+scale_size_continuous("Cook's Distance", range=c(1,5))
    p5<-p5+theme_bw()+theme(legend.position="bottom")
    
    p6<-ggplot(model, aes(.hat, .cooksd))+geom_point(na.rm=TRUE)+stat_smooth(method="loess", na.rm=TRUE)
    p6<-p6+xlab("Leverage hii")+ylab("Cook's Distance")
    p6<-p6+ggtitle("Cook's dist vs Leverage hii/(1-hii)")
    p6<-p6+geom_abline(slope=seq(0,3,0.5), color="gray", linetype="dashed")
    p6<-p6+theme_bw()
    
    return(list(rvfPlot=p1, qqPlot=p2, sclLocPlot=p3, cdPlot=p4, rvlevPlot=p5, cvlPlot=p6))
}
diagPlts=diagPlot(fit)




lbry<-c("grid", "gridExtra")
lapply(lbry, require, character.only=TRUE, warn.conflicts = FALSE, quietly = TRUE)
do.call(grid.arrange, c(diagPlts, top="Diagnostic Plots", ncol=3))


####Correlation Test for Normality
resi = fit$resi
rank.k = rank(resi)
mse = sum(resi^2)/(n-2)
p = (rank.k - 0.375)/(n+0.25)
exp.resi = sqrt(mse)*qnorm(p)
cbind(resi,exp.resi)
cor(resi,exp.resi)
#table located here http://www1.cmc.edu/pages/faculty/MONeill/Math152/Handouts/filliben.pdf
#closer to 1 is better

# Evaluate Collinearity
library(fmsb)
require(fmsb)
VIF(fit) # variance inflation factors 

# Evaluate Nonlinearity
# component + residual plot 
library(car)
crPlots(fit)
# Ceres plots 
ceresPlots(fit)

# Test for Autocorrelated Errors
durbinWatsonTest(fit)

# Global test of model assumptions
library(gvlma)
gvmodel <- gvlma(fit) 
summary(gvmodel)
#graph y hat vs y
data2=cbind(data$y,fit$fitted.values)
print(data2)

q=ggplot(data = as.data.frame(data2), aes(x = y, y = fit$fitted.values,colour=fit$fitted.values)) +
  stat_smooth(aes(colour = fit$fitted.values,fill= fit$fitted.values),size=.1)+
  geom_point(aes(text = paste("fitted values", fit$fitted.values)), size = 1)


ggplotly(q)

