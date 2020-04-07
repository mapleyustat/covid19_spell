library(ade4)
library(ape)
library(dismo)
library(fields)
library(gbm)
library(lubridate)
library(mgcv)
library(raster)
library(RColorBrewer)
library(rgeos)
library(seraphim)
library(spdep)

writingFiles = FALSE
showingPlots = FALSE

zTransformation = function(x)
	{ 
		x = (x-mean(x))/sqrt(var(x))
	}

# 1. Analyses at the province levels

periods = c("16/03-22/03/2020","23/03-29/03/2020","30/03-05/04/2020")
selectedDays1 = ymd(c("2020-03-22","2020-03-29","2020-04-05"))
firstDay = ymd("2020-01-30"); D = 7 # time interval
selectedDays2 = as.numeric(selectedDays1-firstDay)
provinces = raster::getData("GADM", country="BEL", level=2)
provinces@data$NAME_3 = c("Brussels","Antwerpen","Limburg","OostVlaanderen","VlaamsBrabant",
				 "WestVlaanderen","BrabantWallon","Hainaut","Li\xe8ge","Luxembourg","Namur")
data = read.csv("Data_Sciensano_0604/COVID19BE_HOSP.csv")
data = data[!is.na(data[,"DATE"]),]; firstDay = ymd("2020-01-30")
data$DAYS = as.numeric(ymd(data[,"DATE"])-firstDay)
cumulatedHosCases = matrix(nrow=dim(provinces@data)[1], ncol=selectedDays2[length(selectedDays2)])
cumulatedICUCases = matrix(nrow=dim(provinces@data)[1], ncol=selectedDays2[length(selectedDays2)])
doublingTHosCases = matrix(nrow=dim(provinces@data)[1], ncol=selectedDays2[length(selectedDays2)])
doublingTICUCases = matrix(nrow=dim(provinces@data)[1], ncol=selectedDays2[length(selectedDays2)])
for (i in 1:dim(provinces@data)[1])
	{
		provincesID = provinces@data[i,"NAME_3"]
		lines = which(data[,"PROVINCE"] == provincesID)
		temp = data[lines,c("DAYS","TOTAL_IN","TOTAL_IN_ICU")]
		for (j in 1:length(selectedDays2))
			{
				if ((i == 1)&(j == 1)) provinces@data$DT1 = rep(NA,dim(provinces@data)[1])
				if ((i == 1)&(j == 2)) provinces@data$DT2 = rep(NA,dim(provinces@data)[1])
				if ((i == 1)&(j == 3)) provinces@data$DT3 = rep(NA,dim(provinces@data)[1])
				index1 = which(temp[,"DAYS"]==(selectedDays2[j]-D))
				index2 = which(temp[,"DAYS"]==selectedDays2[j])
				if (length(index1) == 0)	
					{
						QTD1 = 0
					}	else	{
						QTD1 = temp[index1,"TOTAL_IN"]
					}
				QTD2 = temp[index2,"TOTAL_IN"]
				DT = (D*log(2))/(log(QTD2/QTD1))
				provinces@data[i,paste0("DT",j)] = DT
			}
		for (j in 1:selectedDays2[length(selectedDays2)])
			{
				index = which(temp[,"DAYS"]==j)
				if (length(index) > 0)
					{
						cumulatedHosCases[i,j] = temp[index,"TOTAL_IN"]
						cumulatedICUCases[i,j] = temp[index,"TOTAL_IN_ICU"]
					}	else	{
						cumulatedHosCases[i,j] = 0
						cumulatedICUCases[i,j] = 0
					}
			}
	}

if (showingPlots)
	{
		DTmax = 30 # ceiling(max(provinces@data[,c("DT1","DT2","DT3")]))
		colourScale = colorRampPalette(brewer.pal(9,"YlGn"))(151)[1:101]; cols = list()
		dev.new(width=3.2,height=7); legendRast = raster(as.matrix(seq(0,DTmax,1)))
		par(mfrow=c(3,1), mar=c(0,0,0,0), oma=c(2,2,2,2), mgp=c(0,0.4,0), lwd=0.2, bty="o")
		for (i in 1:length(selectedDays2))
			{
				values = provinces@data[,paste0("DT",i)]
				values[which(values>DTmax)] = DTmax
				cols[[i]] = colourScale[1+((values/DTmax)*100)]
				plot(provinces, border="gray30", col=cols[[i]])
				mtext(paste0("Doubling time - ",periods[i]), cex=0.54, col="gray30", at=3.55, line=-14.2)
				plot(legendRast, legend.only=T, col=colourScale, legend.width=0.5, legend.shrink=0.3, smallplot=c(0.05,0.5,0.10,0.12),
	 				 alpha=1, horizontal=T, legend.args=list(text="", cex=0.7, line=0.5, col="gray30"), axis.args=list(cex.axis=0.7, lwd=0,
	 				 lwd.tick=0.2, tck=-1, col.axis="gray30", line=0, mgp=c(0,0.2,0), at=seq(0,DTmax,5), labels=c("0","5","10","15","20","25","30")))
			}
		DT_values = c(0,1,2,4,8,16,32); DTmax = max(DT_values); cols = list()
		colourScale1 = colorRampPalette(brewer.pal(9,"YlGn"))(12)[1:length(DT_values)]
		colourScale1 = colorRampPalette(brewer.pal(11,"RdYlGn"))(12)[3:(length(DT_values)+2)]
		colourScale2 = c("gray90",colourScale1)
		dev.new(width=9,height=2.7); legendRast = raster(as.matrix(seq(0,DTmax,1)))
		par(mfrow=c(1,3), mar=c(0,0,0,0), oma=c(2,2,2,2), mgp=c(0,0.4,0), lwd=0.2, bty="o")
		for (i in 1:length(selectedDays2))
			{
				values1 = provinces@data[,paste0("DT",i)]; values2 = provinces@data[,paste0("DT",i)]
				values2[values1[]>32] = 7; values2[values1[]<=32] = 6; values2[values1[]<=16] = 5
				values2[values1[]<=8] = 4; values2[values1[]<=4] = 3; values2[values1[]<=2] = 2
				values2[values1[]<=1] = 1; values2[is.na(values1)] = 0; cols[[i]] = colourScale2[values2+1]
				plot(provinces, border="gray30", col=cols[[i]])
				mtext(paste0("Doubling time hospitalisations"), cex=0.5, col="gray30", at=3.55, line=-14.2)
				mtext(paste0(periods[i]), cex=0.6, col="gray30", at=3.55, line=-15.2)
			}
		legend(6.3, 51.5, c("0 - 1 day","1 - 2 days","2 - 4 days","4 - 8 days","8 - 16 days","16 - 32 days",">32 days"),
			   col=colourScale1, text.col="gray30", pch=16, pt.cex=1.5, box.lty=0, cex=0.9, y.intersp=1.2)
	}
tab = provinces@data[,c("DT1","DT2","DT3")]; row.names(tab) = provinces@data$NAME_2; colnames(tab) = periods
if (writingFiles) write.csv(round(tab,2), "Doubling_times_provinces.csv", quote=F)

for (i in 1:dim(cumulatedHosCases)[1])
	{
		for (j in (D+1):dim(cumulatedHosCases)[2])
			{
				QTD1 = cumulatedHosCases[i,j-D]
				QTD2 = cumulatedHosCases[i,j]
				DT = (D*log(2))/(log(QTD2/QTD1))
				doublingTHosCases[i,j] = DT
				QTD1 = cumulatedICUCases[i,j-D]
				QTD2 = cumulatedICUCases[i,j]
				DT = (D*log(2))/(log(QTD2/QTD1))
				doublingTICUCases[i,j] = DT
			}
	}
row.names(cumulatedHosCases) = provinces@data$NAME_2
row.names(cumulatedICUCases) = provinces@data$NAME_2
colnames(cumulatedHosCases) = paste0("day_",seq(1,selectedDays2[length(selectedDays2)]))
colnames(cumulatedICUCases) = paste0("day_",seq(1,selectedDays2[length(selectedDays2)]))
cumulatedHosCases = cumulatedHosCases[,45:selectedDays2[length(selectedDays2)]]
cumulatedICUCases = cumulatedICUCases[,45:selectedDays2[length(selectedDays2)]]
row.names(doublingTHosCases) = provinces@data$NAME_2
row.names(doublingTICUCases) = provinces@data$NAME_2
colnames(doublingTHosCases) = paste0("day_",seq(1,selectedDays2[length(selectedDays2)]))
colnames(doublingTICUCases) = paste0("day_",seq(1,selectedDays2[length(selectedDays2)]))
doublingTHosCases = doublingTHosCases[,52:selectedDays2[length(selectedDays2)]]
doublingTICUCases = doublingTICUCases[,52:selectedDays2[length(selectedDays2)]]
if (writingFiles) write.csv(cumulatedHosCases, "Hospitalisations_provinces.csv")
if (writingFiles) write.csv(cumulatedICUCases, "SoinsIntensifs_provinces.csv")
if (writingFiles) write.csv(doublingTHosCases, "Hospitalisations_dT_provinces.csv")
if (writingFiles) write.csv(doublingTICUCases, "SoinsIntensifs_dT_provinces.csv")

if (showingPlots)
	{
		cols = c("#a6cee3","#1f78b4","#b2df8a","#33a02c","#fb9a99","#e31a1c","#fdbf6f","#ff7f00","#cab2d6","#6a3d9a","#d3d3d3")
		DTmax = ceiling(max(c(max(doublingTHosCases))))
		dev.new(width=7,height=5); legendRast = raster(as.matrix(seq(0,DTmax,1)))
		par(mfrow=c(1,1), mar=c(2.9,3.1,1,1), oma=c(0,0,0,0), mgp=c(0,0.4,0), lwd=0.2, bty="o")
		xLabels = c(paste0(c(22:31),"-03"),paste0("0",c(1:5),"-04")); dates = c(1:length(xLabels))
		for (i in 1:dim(doublingTHosCases)[1])
			{
				if (i == 1)
					{
						plot(dates,doublingTHosCases[i,], col=cols[i], lwd=1, ylim=c(1.8,33), axes=F, ann=F, type="l")
					}	else	{
						lines(dates,doublingTHosCases[i,], col=cols[i], lwd=1)
					}
				points(dates,doublingTHosCases[i,], col=cols[i], cex=0.7, pch=16)
			}
		axis(side=1, lwd.tick=0.2, cex.axis=0.6, lwd=0.2, tck=-0.013, col.axis="gray30", mgp=c(0,0.05,0), at=c(-1,dates), labels=c(-1,xLabels))
		axis(side=2, lwd.tick=0.2, cex.axis=0.6, lwd=0.2, tck=-0.015, col.axis="gray30", mgp=c(0,0.30,0), at=seq(-2,32,2))
		title(ylab="doubling time hospitalisation (time window = 7 days)", cex.lab=0.7, mgp=c(1.2,0,0), col.lab="gray30")
		title(xlab="day", cex.lab=0.7, mgp=c(0.8,0,0), col.lab="gray30")
		legend(1, 33, provinces@data$NAME_2, col=cols, text.col="gray30", pch=16, pt.cex=1.2, box.lty=0, cex=0.7, y.intersp=1.3)
	}

# 2. Analyses at the commune levels

communes = shapefile("Shapefile_communes/Shapefile_communes.shp")
communes_light = gSimplify(communes, 100)
equivalence = read.csv("Postal_codes_INS.csv", header=T)

	# 2.1. Computing positive cases doubling times for two time periods

periods = c("18-26/03/2020","27/03-04/04/2020")
selectedDays1 = ymd(c("2020-03-26","2020-04-04"))
firstDay = ymd("2020-01-30"); D = 9 # time interval
selectedDays2 = as.numeric(selectedDays1-firstDay)
data = read.csv("Google_Drive_N_Hens/Data_Hospit_1_05-04.csv", sep=";")
daysSinceTheFirstCase = seq(1,200,1)
cumulatedCases_list = list()
for (i in 1:dim(communes@data)[1])
	{
		cumulatedCases = rep(0, length(daysSinceTheFirstCase))
		NIS = communes@data[i,"NIS5"]
		indices1 = which(equivalence[,"code_INS"]==NIS)
		if (length(indices1) == 0)
			{
				# cat(1,i,"\n")
			}	else		{
				indices2 = c()
				for (j in 1:length(indices1))
					{
						postalCode = equivalence[indices1[j],"code_Postal"]
						indices2 = c(indices2, which(data[,"Postcode"]==postalCode))
					}
				if (length(indices2) == 0)
					{
						# cat(2,i,"\n")
					}	else	{
						temp = data[indices2,]
						temp = temp[which(temp[,"dateusedforstatistics"]!=""),]
						dates = temp[,"dateusedforstatistics"]
						dates = gsub("Jan","-01-",dates)
						dates = gsub("Feb","-02-",dates)
						dates = gsub("Mar","-03-",dates)
						dates = gsub("Apr","-03-",dates)
						days = as.numeric(dmy(dates)-firstDay)
						for (j in 1:length(daysSinceTheFirstCase))
							{
								cumulatedCases[j] = sum(days <= j) 
							}
					}
			}
		cumulatedCases_list[[i]] = cumulatedCases
	}
communes@data$cases18March = rep(NA, dim(communes@data)[1])
communes@data$cases26March = rep(NA, dim(communes@data)[1])
communes@data$cases27March = rep(NA, dim(communes@data)[1])
communes@data$cases04April = rep(NA, dim(communes@data)[1])
communes@data$DT1 = rep(NA,dim(communes@data)[1])
communes@data$DT2 = rep(NA,dim(communes@data)[1])
for (i in 1:dim(communes@data)[1])
	{
		temp = cumulatedCases_list[[i]]
		for (j in 1:length(selectedDays2))
			{
				QTD1 = temp[selectedDays2[j]-D]
				QTD2 = temp[selectedDays2[j]]
				if (j == 1)
					{
						communes@data[i,"cases18March"] = QTD1
						communes@data[i,"cases26March"] = QTD2
					}
				if (j == 2)
					{
						communes@data[i,"cases27March"] = QTD1
						communes@data[i,"cases04April"] = QTD2
					}
				if ((QTD1 >= 5)&(QTD2 >= 5)&(QTD1 != QTD2))
					{
						DT = (D*log(2))/(log(QTD2/QTD1))
					}	else	{
						DT = NA
					}
				communes@data[i,paste0("DT",j)] = DT
			}
	}
if (showingPlots)
	{
		DTmax = 32 # ceiling(max(communes@data[,c("DT1","DT2")], na.rm=T))
		colourScale1 = colorRampPalette(brewer.pal(9,"YlGn"))(151)[1:101]; cols = list()
		colourScale2 = c("gray90",colorRampPalette(brewer.pal(9,"YlGn"))(151)[1:101])
		dev.new(width=7,height=3); legendRast = raster(as.matrix(seq(0,DTmax,1)))
		par(mfrow=c(1,2), mar=c(0,0,0,0), oma=c(1,1,1,1), mgp=c(0,0.4,0), lwd=0.2, bty="o")
		for (i in 1:length(selectedDays2))
			{
				values = communes@data[,paste0("DT",i)]
				values[is.na(values)] = 0; values[values[]>30] = 30
				cols[[i]] = colourScale2[1+((values/DTmax)*100)]
				plot(communes_light, border="gray30", col=cols[[i]], lwd=0.1)
				mtext(paste0("Doubling time - ",periods[i]), cex=0.6, col="gray30", at=90000, line=-11.3)
				plot(legendRast, legend.only=T, col=colourScale1, legend.width=0.5, legend.shrink=0.3, smallplot=c(0.05,0.5,0.10,0.12),
			 		 alpha=1, horizontal=T, legend.args=list(text="", cex=0.7, line=0.5, col="gray30"), axis.args=list(cex.axis=0.55, lwd=0,
			 		 lwd.tick=0.2, tck=-1, col.axis="gray30", line=0, mgp=c(0,0.0,0)))
			}
		DT_values = c(0,1,2,4,8,16,32); DTmax = max(DT_values)
		colourScale1 = colorRampPalette(brewer.pal(9,"YlGn"))(12)[1:length(DT_values)]; colourScale2 = c("gray90",colourScale1)
		dev.new(width=7,height=3); par(mfrow=c(1,2), mar=c(0,0,0,0), oma=c(1,1,1,1), mgp=c(0,0.4,0), lwd=0.2, bty="o")
		for (i in 1:length(selectedDays2))
			{
				values1 = communes@data[,paste0("DT",i)]; values2 = communes@data[,paste0("DT",i)]
				values2[values1[]>32] = 7; values2[values1[]<=32] = 6; values2[values1[]<=16] = 5
				values2[values1[]<=8] = 4; values2[values1[]<=4] = 3; values2[values1[]<=2] = 2
				values2[values1[]<=1] = 1; values2[is.na(values1)] = 0; cols[[i]] = colourScale2[values2+1]
				plot(communes_light, border="gray30", col=cols[[i]], lwd=0.1)
				mtext(paste0("Doubling time"), cex=0.65, col="gray30", at=70000, line=-10.3)
				mtext(paste0(periods[i]), cex=0.65, col="gray30", at=70000, line=-11)
			}
		legend(290000, 250000, c("0 - 1 day","1 - 2 days","2 - 4 days","4 - 8 days","8 - 16 days","16 - 32 days",">32 days"),
			   col=colourScale1, text.col="gray30", pch=16, pt.cex=1.0, box.lty=0, cex=0.65, y.intersp=1.1)
	}

	# 2.2. Extracting and assigning covariate values to each commune

communes@data$xCentroid = rep(0,dim(communes@data)[1])
communes@data$yCentroid = rep(0,dim(communes@data)[1])
for (i in 1:dim(communes@data)[1])
	{
		maxArea = 0; polIndex = 0
		for (j in 1:length(communes@polygons[[i]]@Polygons))
			{
				if (maxArea < communes@polygons[[i]]@Polygons[[j]]@area)
					{
						maxArea = communes@polygons[[i]]@Polygons[[j]]@area; polIndex = j
					}
			}
		pol = communes@polygons[[i]]@Polygons[[polIndex]]
		p = Polygon(pol@coords); ps = Polygons(list(p),1); sps = SpatialPolygons(list(ps))
		pol = sps; proj4string(pol) = communes@proj4string
		centroidCoordinates = coordinates(pol)
		communes@data[i,"xCentroid"] = centroidCoordinates[1,1]
		communes@data[i,"yCentroid"] = centroidCoordinates[1,2]
	}
data = read.csv("Data_Sciensano_0404/COVID19BE_CASES_MUNI_CUM.csv")
communes@data$cases = rep(0,dim(communes@data)[1])
for (i in 1:dim(communes@data)[1])
	{
		index = which(data[,"NIS5"]==communes@data[i,"NIS5"])
		if (length(index) != 1)
			{
				# cat(i,"\n")
			}	else		{
				if (as.character(data[index,"CASES"]) != "<5")
					{
						communes@data[i,"cases"] = as.numeric(as.character(data[index,"CASES"]))
					}
			}
	}
data = read.csv("Data_SPF_Economie/SPF_total_population.csv")
communes@data$population = rep(0,dim(communes@data)[1])
for (i in 1:dim(communes@data)[1])
	{
		index = which(data[,"CD_REFNIS"]==communes@data[i,"NISCode"])
		if (length(index) != 1)
			{
				cat(i,"\n")
			}	else	{
				communes@data[i,"population"] = data[index,"TOTAL"]
			}
	}
communes@data$incidences = communes@data$cases/(communes@data$population/1000)
communes@data$popDensity = communes@data$population/(communes@data$Shape_Area/(10^6))
communes@data$populationLog = log(communes@data$population)
communes@data$popDensityLog = log(communes@data$popDensity)
data = read.csv("Data_SPF_Economie/SPF_pop_median_age.csv")
communes@data$medianAge = rep(0,dim(communes@data)[1])
for (i in 1:dim(communes@data)[1])
	{
		index = which(data[,"CD_REFNIS"]==communes@data[i,"NISCode"])
		if (length(index) != 1)
			{
				cat(i,"\n")
			}	else		{
				communes@data[i,"medianAge"] = data[index,"AGE_MEDIAN"]
			}
	}
data = read.csv("Data_SPF_Economie/SPF_more_than_65yrs.csv")
communes@data$moreThan65 = rep(0,dim(communes@data)[1])
for (i in 1:dim(communes@data)[1])
	{
		index = which((data[,"CD_REFNIS"]==communes@data[i,"NISCode"])&(data[,"MS_SEX"]=="TOTAL"))
		if (length(index) != 1)
			{
				cat(i,"\n")
			}	else		{
				communes@data[i,"moreThan65"] = data[index,"X..65year"]/data[index,"TOTAL"]
			}
	}
data = read.csv("Data_SPF_Economie/SPF_median_incomes.csv")
communes@data$medianIncome = rep(0,dim(communes@data)[1])
for (i in 1:dim(communes@data)[1])
	{
		index = which(data[,"CD_REFNIS"]==communes@data[i,"NISCode"])
		if (length(index) != 1)
			{
				cat(i,"\n")
			}	else		{
				communes@data[i,"medianIncome"] = data[index,"MEDIAN_DECL"]
			}
	}
data = read.csv("Data_SPF_Economie/SPF_working_sectors.csv")
communes_light = gSimplify(communes, 100)
communes@data$sectorP = rep(0,dim(communes@data)[1])
communes@data$sectorS = rep(0,dim(communes@data)[1])
communes@data$sectorT = rep(0,dim(communes@data)[1])
for (i in 1:dim(communes@data)[1])
	{
		index = which((data[,"CD_REFNIS"]==communes@data[i,"NISCode"])&(data[,"CD_SECT"]=="P"))
		if (length(index) == 1) communes@data[i,"sectorP"] = data[index,"MS_PROP"]*100
		index = which((data[,"CD_REFNIS"]==communes@data[i,"NISCode"])&(data[,"CD_SECT"]=="S"))
		if (length(index) == 1) communes@data[i,"sectorS"] = data[index,"MS_PROP"]*100
		index = which((data[,"CD_REFNIS"]==communes@data[i,"NISCode"])&(data[,"CD_SECT"]=="T"))
		if (length(index) == 1) communes@data[i,"sectorT"] = data[index,"MS_PROP"]*100
	}
if (!file.exists("PM10_anmean_2017.asc"))
	{
		pm10 = aggregate(raster("Rasters_de_irceline_be/PM10_anmean_2017_v564.tif"),100)
		pm25 = aggregate(raster("Rasters_de_irceline_be/PM25_anmean_2017_v564.tif"),100)
		writeRaster(pm10,"PM10_anmean_2017.asc"); writeRaster(pm25,"PM25_anmean_2017.asc")		
	}
pm10 = raster("PM10_anmean_2017.asc")
pm25 = raster("PM25_anmean_2017.asc")
communes@data$pm10 = rep(0,dim(communes@data)[1])
communes@data$pm25 = rep(0,dim(communes@data)[1])
for (i in 1:dim(communes@data)[1])
	{
		maxArea = 0; polIndex = 0
		for (j in 1:length(communes@polygons[[i]]@Polygons))
			{
				if (maxArea < communes@polygons[[i]]@Polygons[[j]]@area)
					{
						maxArea = communes@polygons[[i]]@Polygons[[j]]@area; polIndex = j
					}
			}
		pol = communes@polygons[[i]]@Polygons[[polIndex]]
		p = Polygon(pol@coords); ps = Polygons(list(p),1); sps = SpatialPolygons(list(ps))
		pol = sps; proj4string(pol) = communes@proj4string
		pol_light = gSimplify(pol, 100)
		communes@data[i,"pm10"] = mean(raster::extract(pm10,pol_light)[[1]], na.rm=T)
		communes@data[i,"pm25"] = mean(raster::extract(pm25,pol_light)[[1]], na.rm=T)
	}
if (!file.exists("CorineLandCover.asc"))
	{
		clc = crop(raster("CorineLandCover18.tif"), extent(3500000,4500000,2500000,4000000))
		clc_crs = clc@crs; communes_clc = spTransform(communes, clc_crs)
		clc = mask(crop(clc, communes_clc), communes_clc)
		clc@crs = clc_crs; writeRaster(clc, "CorineLandCover.asc")
	}
if (!file.exists("CLC_propUrbanArea.csv"))
	{
		clc = raster("CorineLandCover.asc")
		communes_clc = spTransform(communes, raster("CorineLandCover18.tif")@crs)
		propUrbanArea = matrix(nrow=dim(communes@data)[1], ncol=3)
		for (i in 1:dim(communes@data)[1])
			{
				maxArea = 0; polIndex = 0
				for (j in 1:length(communes_clc@polygons[[i]]@Polygons))
					{
						if (maxArea < communes_clc@polygons[[i]]@Polygons[[j]]@area)
							{
								maxArea = communes_clc@polygons[[i]]@Polygons[[j]]@area; polIndex = j
							}
					}
				pol = communes_clc@polygons[[i]]@Polygons[[polIndex]]
				p = Polygon(pol@coords); ps = Polygons(list(p),1); sps = SpatialPolygons(list(ps))
				pol = sps; proj4string(pol) = communes_clc@proj4string
				pol_light = gSimplify(pol, 100)
				rast = mask(crop(clc,pol_light),pol_light)
				greenAreas = sum(rast[]==141, na.rm=T)
				urbanAreas = sum(rast[]==111, na.rm=T)+sum(rast[]==112, na.rm=T)
				propUrbanArea[i,1] = communes@data[i,"NIS5"]
				if (greenAreas == 0)
					{
						propUrbanArea[i,2] = 0
					}	else	{
						propUrbanArea[i,2] = communes@data[i,"population"]/greenAreas
					}
				propUrbanArea[i,3] = urbanAreas/length(rast[!is.na(rast[])])
			}
		colnames(propUrbanArea) = c("NIS","popGreenArea","propUrbanArea")
		write.csv(propUrbanArea, "CLC_propUrbanArea.csv", row.names=F, quote=F)
	}
communes@data$propUrbanArea = read.csv("CLC_propUrbanArea.csv")[,3]

variables = c("popDensityLog","medianIncome","sectorP","sectorS","sectorT",
			  "medianAge","moreThan65","pm10","pm25","propUrbanArea"); dfs = list()
df1 = communes@data[,c("NIS5","xCentroid","yCentroid","DT1",variables)]; df1 = df1[!is.na(df1[,"DT1"]),]; dfs[[1]] = df1
df2 = communes@data[,c("NIS5","xCentroid","yCentroid","DT2",variables)]; df2 = df2[!is.na(df2[,"DT2"]),]; dfs[[2]] = df2
if (writingFiles == TRUE)
	{
		df = communes@data[,c("NIS5","xCentroid","yCentroid","cases18March","cases26March",
							  "cases27March","cases04April","DT1","DT2",variables)]
		write.csv(df, "Covariate_values_commune.csv", row.names=F, quote=F)		
	}

	# 2.3. Plotting the doubling time estimates and each covariate

if (showingPlots)
	{
		variables = c("incidences","DT1","DT2","medianIncome","propUrbanArea","popDensityLog",
					  "sectorP","sectorS","sectorT","moreThan65","pm10","pm25")
		variableNames = c("# cases per 1000 persons","Doubling times 1° period","Doubling times 2° period",
						  "Median declared income (€)","Urban area proportion","Population density (log)",
						  "% in primary sector","% in secundary sector","% in tertiary sector",
						  ">= 65 years (proportion)","PM 1.0 emission","PM 2.5 emission")
		communes_light = gSimplify(communes, 100); colourScales = list()
		colourScales[[1]] = c("#E5E5E5",colorRampPalette(brewer.pal(9,"YlOrRd"))(151)[1:101])
		colourScales[[2]] = c("#E5E5E5",colorRampPalette(brewer.pal(9,"YlGn"))(151)[1:101])
		colourScales[[3]] = c("#E5E5E5",colorRampPalette(brewer.pal(9,"YlGn"))(151)[1:101])
		colourScales[[4]] = c(colorRampPalette(brewer.pal(9,"RdPu"))(151)[1:101])
		colourScales[[5]] = c(colorRampPalette(brewer.pal(9,"Purples"))(151)[1:101])
		colourScales[[6]] = c(colorRampPalette(brewer.pal(9,"BuPu"))(151)[1:101])
		colourScales[[7]] = c(colorRampPalette(brewer.pal(9,"Greens"))(151)[1:101])
		colourScales[[8]] = c(colorRampPalette(brewer.pal(9,"Oranges"))(151)[1:101])
		colourScales[[9]] = c(colorRampPalette(brewer.pal(9,"Blues"))(151)[1:101])
		colourScales[[10]] = c(colorRampPalette(brewer.pal(9,"PuBuGn"))(151)[1:101])
		colourScales[[11]] = c(colorRampPalette(brewer.pal(9,"YlOrBr"))(151)[1:101])
		colourScales[[12]] = c(colorRampPalette(brewer.pal(9,"YlOrBr"))(151)[1:101])
		dev.new(width=7,height=8); par(mfrow=c(4,3), mar=c(0,0,0,0), oma=c(2,2,1,2), mgp=c(0,0.4,0), lwd=0.2, bty="o")
		for (i in 1:length(variables))
			{
				values = communes@data[,variables[i]]
				if ((i == 2)|(i == 3))
					{
						values[is.na(values)] = 0; values[values[]>30] = 30
					}
				minV = min(values); maxV = max(values)
				legendCols = colourScales[[i]][1:length(colourScales[[i]])]; legendRast = raster(as.matrix(c(minV,maxV)))		
				cols = colourScales[[i]][(((values-minV)/(maxV-minV))*100)+1]
				plot(communes_light, border="gray30", col=cols, lwd=0.1)
				mtext(variableNames[i], cex=0.54, col="gray30", at=92000, line=-12.4)
				plot(legendRast, legend.only=T, col=legendCols, legend.width=0.5, legend.shrink=0.3, smallplot=c(0.05,0.5,0.10,0.12),
			 		 alpha=1, horizontal=T, legend.args=list(text="", cex=0.7, line=0.5, col="gray30"), axis.args=list(cex.axis=0.7, lwd=0,
					 lwd.tick=0.2, tck=-1, col.axis="gray30", line=0, mgp=c(0,0.13,0)))
			}
	}

	# 2.4. Performing and plotting the first axes of an exploratory PCA

if (showingPlots)
	{
		pca = dudi.pca(df1[,variables], scannf=F, nf=length(variables)); lis = pca$li[,1:2]; cos = pca$co
		colourScale = colorRampPalette(brewer.pal(9,"YlGn"))(151)[1:101]
		DTmax = max(df1[,"DT1"]); legendRast = raster(as.matrix(seq(0,DTmax,1)))
		cols = colourScale[1+((df1[,"DT1"]/DTmax)*100)]
		dev.new(width=6, height=6); par(mar=c(3,3,1.5,1.5), lwd=0.2, col="gray30")
		plot(lis, col="gray50", cex=0.3, pch=16, ann=F, axes=F, xlim=c(-5.5,7.5), ylim=c(-5.5,4.0))
		points(lis, col="gray30", cex=0.75, pch=1, lwd=0.3); points(lis, col=cols, cex=0.70, pch=16); 
		s.corcircle(2*cos, xax=1, yax=2, box=F, sub="", csub=0.7, clabel=0.7, possub="topleft", grid=F, cgrid=1, full=F, add.plot=T)
		axis(side=1, lwd.tick=0.2, cex.axis=0.6, lwd=0.2, tck=-0.010, col.axis="gray30", mgp=c(0,0.05,0), at=seq(-9,9,1))
		axis(side=2, lwd.tick=0.2, cex.axis=0.6, lwd=0.2, tck=-0.010, col.axis="gray30", mgp=c(0,0.30,0), at=seq(-7,9,1))
		title(xlab="PCA axis 1", cex.lab=0.7, mgp=c(1.0,0,0), col.lab="gray30")
		title(ylab="PCA axis 2", cex.lab=0.7, mgp=c(1.3,0,0), col.lab="gray30")
		mtext(paste0("Doubling time - 18-26/03/2020"), cex=0.75, col="gray30", at=2.5, line=-1)
		plot(legendRast, legend.only=T, col=colourScale, legend.width=0.5, legend.shrink=0.3, smallplot=c(0.45,0.73,0.90,0.91),
			 alpha=1, horizontal=T, legend.args=list(text="", cex=0.7, line=0.5, col="gray30"), axis.args=list(cex.axis=0.55, lwd=0,
			 lwd.tick=0.2, tck=-0.8, col.axis="gray30", line=0, mgp=c(0,0.0,0)))
	}

	# 2.5. Assessing spatial autocorrelation with the Moran's I test

for (i in 1:length(dfs))
	{
		geoDists = as.matrix(dist(dfs[[i]][,c("xCentroid","yCentroid")]))
		weights = 1/geoDists; diag(weights) = 0
		print(Moran.I(dfs[[i]][,paste0("DT",i)], weights))
	}

	# 2.6. Univariate (LR) followed by multivariate regression (GLM) analyses

selectedVariables = list()
for (i in 1:length(dfs))
	{
		buffer = c()
		for (j in 1:length(variables))
			{
				formula = paste0("DT",i," ~ ",variables[j])
				lr = glm(formula, data=dfs[[i]])
				pValue = summary(lr)$coefficients[2,4]
				if (pValue < 0.05)
					{
						buffer = c(buffer, variables[j])
					}
			}
		selectedVariables[[i]] = buffer
	}
for (i in 1:length(dfs))
	{
		df_z = dfs[[i]]
		for (j in 1:dim(dfs[[i]])[2])
			{
				df_z[,j] = zTransformation(df_z[,j])
			}
		formula = paste0("DT",i," ~ ",selectedVariables[[i]][1])
		if (length(selectedVariables[[i]]) > 1)
			{
				for (j in 2:length(selectedVariables[[i]]))
					{
						formula = paste0(formula," + ",selectedVariables[[i]][j])
					}
			}
		glm = glm(formula, data=df_z); print(summary(glm))
	}

	# 2.7. GAM (generalised additive model) analyses

gams = list()
zTransformations = FALSE
for (i in 1:length(dfs))
	{
		df = dfs[[i]]; colnames(df) = gsub(paste0("DT",i),"DT",colnames(df))
		if (zTransformations == TRUE)
			{
				for (j in 1:dim(dfs[[i]])[2]) df[,j] = zTransformation(df[,j])
			}
		gam = gam(DT ~ s(popDensityLog) + s(propUrbanArea)+ s(medianIncome) + s(sectorP) + s(sectorS) + s(sectorT)
					 + s(medianAge) + s(moreThan65) + s(pm10) + s(pm25) + s(xCentroid,yCentroid), data=df, method="REML")
		print(summary(gam)); gams[[i]] = gam
		if (showingPlots)
			{
				dev.new(); plot(gam, pages=1)
			}
	}
if (showingPlots)
	{
		gam = gams[[1]]; responseCurves = list()
		curves = plot(gam, pages=1); dev.off()
		selectedVariables = c("popDensityLog","propUrbanArea")
		variableNames = c("population density (log)","urban area proportion")
		dev.new(width=6.5,height=3)
		par(mfrow=c(1,2), mar=c(3,3,1,1), oma=c(0,0,0,0), mgp=c(0,0.4,0), lwd=0.2, col="gray30", bty="o")
		for (i in 1:length(selectedVariables))
			{
				index = which(colnames(dfs[[1]])==selectedVariables[i])-4
				lower_l = curves[[index]]$fit-curves[[index]]$se
				upper_l = curves[[index]]$fit+curves[[index]]$se
				yLim = c(min(c(lower_l,upper_l)),max(c(lower_l,upper_l)))
				xx_l = c(curves[[index]]$x,rev(curves[[index]]$x)); yy_l = c(lower_l,rev(upper_l))
				plot(curves[[index]]$x, curves[[index]]$fit, ylim=yLim, ann=F, axes=F, type="l", col="gray30", lwd=1.0)
				polygon(xx_l, yy_l, col=rgb(100,100,100,100,maxColorValue=255), border=0)
				axis(side=1, pos=yLim[1], lwd.tick=0.2, cex.axis=0.6, mgp=c(0,0.1,0), lwd=0.2, tck=-0.025,
					 col.tick="gray30", col.axis="gray30", col="gray30")
				axis(side=2, pos=min(curves[[index]]$x), lwd.tick=0.2, cex.axis=0.6, mgp=c(0,0.25,0), lwd=0.2, tck=-0.025,
					 col.tick="gray30", col.axis="gray30", col="gray30")
				title(xlab=variableNames[i], cex.lab=0.7, mgp=c(0.5,0,0), col.lab="gray30")
				title(ylab=paste0("s(",variableNames[i],")"), cex.lab=0.7, mgp=c(0.6,0,0), col.lab="gray30")
			}
		dev.new(width=6.5,height=3)
		par(mfrow=c(1,2), mar=c(3,3,1,1), oma=c(0,0,0,0), mgp=c(0,0.4,0), lwd=0.2, col="gray30", bty="o")
		for (i in 1:length(selectedVariables))
			{				
				df = cbind(dfs[[1]][5:dim(dfs[[1]])[2]],dfs[[1]][,c("xCentroid","yCentroid")])
				for (j in 1:dim(df)[2])
					{
						if (colnames(df)[j] == selectedVariables[i])
							{
								df[,j] = seq(min(df[,j]),max(df[,j]),(max(df[,j])-min(df[,j]))/(dim(df)[1]-1))
							}	else	{
								df[,j] = median(df[,j])
							}
					}
				plot(df[,selectedVariables[i]], predict(gam, df), ann=F, axes=F, type="l", col="gray30", lwd=1.0)
				axis(side=1, lwd.tick=0.2, cex.axis=0.6, mgp=c(0,0.1,0), lwd=0.2, tck=-0.025,
					 col.tick="gray30", col.axis="gray30", col="gray30")
				axis(side=2, lwd.tick=0.2, cex.axis=0.6, mgp=c(0,0.25,0), lwd=0.2, tck=-0.025,
					 col.tick="gray30", col.axis="gray30", col="gray30")
				title(xlab=variableNames[i], cex.lab=0.7, mgp=c(0.8,0,0), col.lab="gray30")
				title(ylab=paste0("response"), cex.lab=0.7, mgp=c(1.0,0,0), col.lab="gray30")
			}
	}

# 3. Analyses of hospital catchment areas

	# 3.1. Establishing the link between catchment areas and communes

catchmentAreas = shapefile("Hosp_catchment_areas/Hospital_catchment_areas_070420.shp")
sharedAreas = matrix(nrow=dim(communes@data)[1], ncol=length(catchmentAreas@polygons))
row.names(sharedAreas) = communes@data[,"NIS5"]; totalArea1 = 0; totalArea2 = 0
for (i in 1:length(catchmentAreas@polygons))
	{
		pol = catchmentAreas@polygons[[i]]@Polygons[[1]]
		p = Polygon(pol@coords); ps = Polygons(list(p),1); sps = SpatialPolygons(list(ps))
		pol1 = sps; proj4string(pol1) = crs(catchmentAreas)
		totalArea1 = totalArea1 + pol1@polygons[[1]]@area; totalArea2 = 0
		for (j in 1:dim(communes@data)[1])
			{
				maxArea = 0; polIndex = 0
				for (k in 1:length(communes@polygons[[j]]@Polygons))
					{
						if (maxArea < communes@polygons[[j]]@Polygons[[k]]@area)
							{
								maxArea = communes@polygons[[j]]@Polygons[[k]]@area; polIndex = k
							}
					}
				pol = communes@polygons[[j]]@Polygons[[polIndex]]
				p = Polygon(pol@coords); ps = Polygons(list(p),1); sps = SpatialPolygons(list(ps))
				pol2 = sps; proj4string(pol2) = crs(communes)
				totalArea2 = totalArea2 + pol@area
				if (!is.null(raster::intersect(pol1, pol2)))
					{
						# plot(pol1); plot(pol2, border="red", add=T)
						# plot(raster::intersect(pol1, pol2), col="orange", add=T)
						pol3 = intersect(pol1, pol2); area = 0
						for (k in 1:length(pol3@polygons))
							{
								area = area + pol3@polygons[[k]]@area
							}
						sharedAreas[j,i] = area
					}	else	{
						sharedAreas[j,i] = 0
					}				
			}
	}
if (writingFiles) write.csv(sharedAreas, "CatchingAreas_vs_cummunes_shared_areas.csv", quote=F)
proportions = matrix(nrow=dim(communes@data)[1], ncol=length(catchmentAreas@polygons))
row.names(proportions) = communes@data[,"NIS5"]
for (i in 1:dim(proportions)[1])
	{
		proportions[i,] = sharedAreas
	}

	# 3.2. 	Extracting and assigning covariate values to each catchment area

catchmentAreas@data$xCentroid = rep(0,dim(catchmentAreas@data)[1])
catchmentAreas@data$yCentroid = rep(0,dim(catchmentAreas@data)[1])
for (i in 1:dim(catchmentAreas@data)[1])
	{
		maxArea = 0; polIndex = 0
		for (j in 1:length(catchmentAreas@polygons[[i]]@Polygons))
			{
				if (maxArea < catchmentAreas@polygons[[i]]@Polygons[[j]]@area)
					{
						maxArea = catchmentAreas@polygons[[i]]@Polygons[[j]]@area; polIndex = j
					}
			}
		pol = catchmentAreas@polygons[[i]]@Polygons[[polIndex]]
		p = Polygon(pol@coords); ps = Polygons(list(p),1); sps = SpatialPolygons(list(ps))
		pol = sps; proj4string(pol) = communes@proj4string
		centroidCoordinates = coordinates(pol)
		catchmentAreas@data[i,"xCentroid"] = centroidCoordinates[1,1]
		catchmentAreas@data[i,"yCentroid"] = centroidCoordinates[1,2]
	}
communes@data$area = rep(0,dim(communes@data)[1])
for (i in 1:dim(communes@data)[1])
	{
		maxArea = 0; polIndex = 0
		for (j in 1:length(communes@polygons[[i]]@Polygons))
			{
				if (maxArea < communes@polygons[[i]]@Polygons[[j]]@area)
					{
						maxArea = communes@polygons[[i]]@Polygons[[j]]@area
					}
			}
		communes@data[i,"area"] = maxArea
	}
catchmentAreas@data$population = rep(0,dim(catchmentAreas@data)[1])
for (i in 1:dim(catchmentAreas@data)[1])
	{
		catchmentArea = 0
		for (j in 1:length(catchmentAreas@polygons[[i]]@Polygons))
			{
				catchmentArea = catchmentArea + catchmentAreas@polygons[[i]]@Polygons[[j]]@area
			}
		catchmentAreas@data[i,"population"] = sum(communes@data[,"population"]*sharedAreas[,i])/catchmentArea
	}




communes@data$incidences = communes@data$cases/(communes@data$population/1000)
communes@data$popDensity = communes@data$population/(communes@data$Shape_Area/(10^6))
communes@data$populationLog = log(communes@data$population)
communes@data$popDensityLog = log(communes@data$popDensity)
data = read.csv("Data_SPF_Economie/SPF_pop_median_age.csv")
communes@data$medianAge = rep(0,dim(communes@data)[1])
for (i in 1:dim(communes@data)[1])
	{
		index = which(data[,"CD_REFNIS"]==communes@data[i,"NISCode"])
		if (length(index) != 1)
			{
				cat(i,"\n")
			}	else		{
				communes@data[i,"medianAge"] = data[index,"AGE_MEDIAN"]
			}
	}
data = read.csv("Data_SPF_Economie/SPF_more_than_65yrs.csv")
communes@data$moreThan65 = rep(0,dim(communes@data)[1])
for (i in 1:dim(communes@data)[1])
	{
		index = which((data[,"CD_REFNIS"]==communes@data[i,"NISCode"])&(data[,"MS_SEX"]=="TOTAL"))
		if (length(index) != 1)
			{
				cat(i,"\n")
			}	else		{
				communes@data[i,"moreThan65"] = data[index,"X..65year"]/data[index,"TOTAL"]
			}
	}
data = read.csv("Data_SPF_Economie/SPF_median_incomes.csv")
communes@data$medianIncome = rep(0,dim(communes@data)[1])
for (i in 1:dim(communes@data)[1])
	{
		index = which(data[,"CD_REFNIS"]==communes@data[i,"NISCode"])
		if (length(index) != 1)
			{
				cat(i,"\n")
			}	else		{
				communes@data[i,"medianIncome"] = data[index,"MEDIAN_DECL"]
			}
	}
data = read.csv("Data_SPF_Economie/SPF_working_sectors.csv")
communes_light = gSimplify(communes, 100)
communes@data$sectorP = rep(0,dim(communes@data)[1])
communes@data$sectorS = rep(0,dim(communes@data)[1])
communes@data$sectorT = rep(0,dim(communes@data)[1])
for (i in 1:dim(communes@data)[1])
	{
		index = which((data[,"CD_REFNIS"]==communes@data[i,"NISCode"])&(data[,"CD_SECT"]=="P"))
		if (length(index) == 1) communes@data[i,"sectorP"] = data[index,"MS_PROP"]*100
		index = which((data[,"CD_REFNIS"]==communes@data[i,"NISCode"])&(data[,"CD_SECT"]=="S"))
		if (length(index) == 1) communes@data[i,"sectorS"] = data[index,"MS_PROP"]*100
		index = which((data[,"CD_REFNIS"]==communes@data[i,"NISCode"])&(data[,"CD_SECT"]=="T"))
		if (length(index) == 1) communes@data[i,"sectorT"] = data[index,"MS_PROP"]*100
	}
if (!file.exists("PM10_anmean_2017.asc"))
	{
		pm10 = aggregate(raster("Rasters_de_irceline_be/PM10_anmean_2017_v564.tif"),100)
		pm25 = aggregate(raster("Rasters_de_irceline_be/PM25_anmean_2017_v564.tif"),100)
		writeRaster(pm10,"PM10_anmean_2017.asc"); writeRaster(pm25,"PM25_anmean_2017.asc")		
	}
pm10 = raster("PM10_anmean_2017.asc")
pm25 = raster("PM25_anmean_2017.asc")
communes@data$pm10 = rep(0,dim(communes@data)[1])
communes@data$pm25 = rep(0,dim(communes@data)[1])
for (i in 1:dim(communes@data)[1])
	{
		maxArea = 0; polIndex = 0
		for (j in 1:length(communes@polygons[[i]]@Polygons))
			{
				if (maxArea < communes@polygons[[i]]@Polygons[[j]]@area)
					{
						maxArea = communes@polygons[[i]]@Polygons[[j]]@area; polIndex = j
					}
			}
		pol = communes@polygons[[i]]@Polygons[[polIndex]]
		p = Polygon(pol@coords); ps = Polygons(list(p),1); sps = SpatialPolygons(list(ps))
		pol = sps; proj4string(pol) = communes@proj4string
		pol_light = gSimplify(pol, 100)
		communes@data[i,"pm10"] = mean(raster::extract(pm10,pol_light)[[1]], na.rm=T)
		communes@data[i,"pm25"] = mean(raster::extract(pm25,pol_light)[[1]], na.rm=T)
	}
if (!file.exists("CorineLandCover.asc"))
	{
		clc = crop(raster("CorineLandCover18.tif"), extent(3500000,4500000,2500000,4000000))
		clc_crs = clc@crs; communes_clc = spTransform(communes, clc_crs)
		clc = mask(crop(clc, communes_clc), communes_clc)
		clc@crs = clc_crs; writeRaster(clc, "CorineLandCover.asc")
	}
if (!file.exists("CLC_propUrbanArea.csv"))
	{
		clc = raster("CorineLandCover.asc")
		communes_clc = spTransform(communes, raster("CorineLandCover18.tif")@crs)
		propUrbanArea = matrix(nrow=dim(communes@data)[1], ncol=3)
		for (i in 1:dim(communes@data)[1])
			{
				maxArea = 0; polIndex = 0
				for (j in 1:length(communes_clc@polygons[[i]]@Polygons))
					{
						if (maxArea < communes_clc@polygons[[i]]@Polygons[[j]]@area)
							{
								maxArea = communes_clc@polygons[[i]]@Polygons[[j]]@area; polIndex = j
							}
					}
				pol = communes_clc@polygons[[i]]@Polygons[[polIndex]]
				p = Polygon(pol@coords); ps = Polygons(list(p),1); sps = SpatialPolygons(list(ps))
				pol = sps; proj4string(pol) = communes_clc@proj4string
				pol_light = gSimplify(pol, 100)
				rast = mask(crop(clc,pol_light),pol_light)
				greenAreas = sum(rast[]==141, na.rm=T)
				urbanAreas = sum(rast[]==111, na.rm=T)+sum(rast[]==112, na.rm=T)
				propUrbanArea[i,1] = communes@data[i,"NIS5"]
				if (greenAreas == 0)
					{
						propUrbanArea[i,2] = 0
					}	else	{
						propUrbanArea[i,2] = communes@data[i,"population"]/greenAreas
					}
				propUrbanArea[i,3] = urbanAreas/length(rast[!is.na(rast[])])
			}
		colnames(propUrbanArea) = c("NIS","popGreenArea","propUrbanArea")
		write.csv(propUrbanArea, "CLC_propUrbanArea.csv", row.names=F, quote=F)
	}
communes@data$propUrbanArea = read.csv("CLC_propUrbanArea.csv")[,3]






















# 4. Plotting time tree downloaded from Nextstrain

tree = read.tree("Nextstrain_070420.tree")
data = read.csv("Nextstrain_070420.csv", sep=";")
if (showingPlots)
	{
		dev.new(width=7, height=7); par(oma=c(0,0,0,0), mar=c(0,0,0,0.0), lwd=0.1)
		plot(tree, type="fan", show.tip.label=F, show.node.label=F, edge.width=0.5, cex=0.6, align.tip.label=3, col="gray30", edge.color="gray30")
		for (i in 1:dim(tree$edge)[1])
			{
				if ((!tree$edge[i,2]%in%tree$edge[,1]) & (grepl("Belgium",tree$tip.label[tree$edge[i,2]])))
					{
						nodelabels(node=tree$edge[i,2], pch=16, cex=0.6, col="chartreuse3")
						nodelabels(node=tree$edge[i,2], pch=1, cex=0.6, col="gray30", lwd=0.5)
					}
			}
		add.scale.bar(x=0.0, y=-0.01, length=NULL, ask=F, lwd=0.5 , lcol ="gray30", cex=0.7)
	}

txt = c(); tab1 = c(); tab2 = c()
for (i in 1:length(tree$tip.label))
	{
		index = which(data[,"Strain"]==tree$tip.label[i])
		date = as.character(data[index,"Collection.Data"])
		txt = c(txt, paste0(">",tree$tip.label[i]),"NNNN")
		location = unlist(strsplit(tree$tip.label[i],"\\/"))[1]
		tab1 = rbind(tab1, cbind(tree$tip.label[i],location, date))
		if (location != "Belgium") location = "other"
		tab2 = rbind(tab2, cbind(tree$tip.label[i],location, date))
	}
write(txt, "Nextstrain_070420.fasta")
colnames(tab1) = c("trait","location","collection_date")
colnames(tab2) = c("trait","location","collection_date")
write.table(tab1, "Nextstrain_070420_1.txt", row.names=F, quote=F, sep="\t")
write.table(tab2, "Nextstrain_070420_2.txt", row.names=F, quote=F, sep="\t")

tree = readAnnotatedNexus("Nextstrain_070420_MCC.tree")
if (showingPlots)
	{
		cols = rep("gray30",dim(tree$edge)[1]); lwds = rep(0.1,dim(tree$edge)[1])
		for (i in 1:dim(tree$edge)[1])
			{
				if (tree$edge[i,1]%in%tree$edge[,2])
					{
						index = which(tree$edge[,2]==tree$edge[i,1])
						if ((tree$annotations[[index]]$location=="Belgium") & (tree$annotations[[i]]$location=="Belgium"))
							{
								cols[i] = "chartreuse3"; lwds[i] = 0.4
							}
					}
			}
		dev.new(width=7, height=7); par(oma=c(0,0,0,0), mar=c(0,0,0,0.0), lwd=0.1)
		plot(tree, type="fan", show.tip.label=F, show.node.label=F, edge.width=lwds, cex=0.6, align.tip.label=3, col="gray30", edge.color=cols)
		for (i in 1:dim(tree$edge)[1])
			{
				if ((!tree$edge[i,2]%in%tree$edge[,1]) & (grepl("Belgium",tree$tip.label[tree$edge[i,2]])))
					{
						nodelabels(node=tree$edge[i,2], pch=16, cex=0.3, col="chartreuse3")
						nodelabels(node=tree$edge[i,2], pch=1, cex=0.3, col="gray30", lwd=0.5)
					}
				if ((tree$edge[i,2]%in%tree$edge[,1]) & (tree$annotations[[i]]$location=="Belgium"))
					{
						nodelabels(node=tree$edge[i,2], pch=16, cex=0.6, col="chartreuse3")
						nodelabels(node=tree$edge[i,2], pch=1, cex=0.6, col="gray30", lwd=0.5)
					}
			}
		add.scale.bar(x=0.0, y=-0.01, length=NULL, ask=F, lwd=0.5 , lcol ="gray30", cex=0.7)
	}
trees = readAnnotatedNexus("Nextstrain_070420.trees")
belgianBranches = c(); belgianIntroductions = c(); belgianTipBranches = c()
for (i in 1:dim(tree$edge)[1])
	{
		if (tree$annotations[[i]]$location == "Belgium")
			{
				belgianBranches = c(belgianBranches,i)
				index = which(tree$edge[,2]==tree$edge[i,1])
				if (tree$annotations[[index]]$location != "Belgium")
					{
						belgianIntroductions = c(belgianIntroductions, i)
					}
				if (!tree$edge[i,2]%in%tree$edge[,1])
					{
						belgianTipBranches = c(belgianTipBranches, i)
					}
			}
	}
length(belgianIntroductions) # 121
length(belgianTipBranches) # 253

