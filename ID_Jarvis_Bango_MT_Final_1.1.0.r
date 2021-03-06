start_time <- Sys.time()
working_output <- getwd()
working_output <- setwd("C:/Users/goura/OneDrive/Desktop/UL_R_Projects/ID_Jarvis_Bango_1.1.0/ID_Jarvis_Bango_1.1.0")
source(paste0(working_output,"/ID_Jarvis_Generalised_template_1.1.0.r"))

############################################# ID Psales (MT Model) ###############################################
psales.mt.input <- merge.data.frame(x = id.psales.bango,y =psales.material.mt.mapping,by.x ="Material_Code",by.y = "Material Code")%>%
  merge.data.frame(x = .,y = customer.mapping,by.x = "Customer_Code_8D",by.y ="Customer Code")%>%
  merge.data.frame(x = .,y = conversion.mapping,by.x = "Material_Code",by.y = "MATNR")

#select the required columns i.e. Required Basepack fromo the material mapping , Account/Region from the Customer Mapping and Conversion rate from the Conversion mapping 

psales.mt <- psales.mt.input%>%
  select(-c(DIVCD:ncol(.),National:UMREN))
#filter out the observations for which the the Account is "MT" and the required basepack is not 0

psales.mt.filtered <- psales.mt%>%
  filter(`REQUIRED BASEPACK`!=0)
psales.mt.filtered <- psales.mt.filtered%>%
  filter(str_detect(`Account/Region`,"MT"))
psales.mt.filtered <- setnames(psales.mt.filtered,c("Material Desc.x","Customer Desc.x"),c("Material Desc","Customer Desc"))
psales.mt.filtered%<>%mutate(psales_KG=`Sales Quantity`*Conversion,psales_Tonns=psales_KG/1000)
#group the observations and aggregate the KPI's based on {Month,Required Basepack,Account}
psales.mt.aggregate <- psales.mt.filtered%>%
  group_by(`Fiscal year/period`,`REQUIRED BASEPACK`,`Account/Region`)%>%
  summarise(`Gross Sales Value (GSV)`=sum(`Gross Sales Value (GSV)`),`Sales Quantity`=sum(`Sales Quantity`),NIV=sum(NIV),psales_KG=sum(psales_KG),psales_Tonns=sum(psales_Tonns))
#calculate the unit price- GSV/Sales_Quantity(Kg)
psales.mt.aggregate%<>%mutate(unit_price= NIV/psales_KG)
#perform the month mapping for the Fiscal Period column 
psales.mt.aggregate <- merge.data.frame(psales.mt.aggregate,month.mapping,by.x = "Fiscal year/period",by.y ="Primary sales" )
psales.mt.aggregate%<>%select(-c(`Sec stock_DROO_Penetration`,TTS_BMI,`Secondary sales`,`Fiscal year/period`,Sellout))
psales.mt.aggregate%<>%select(c(Month,`REQUIRED BASEPACK`,`Account/Region`,`Gross Sales Value (GSV)`:unit_price))
psales.mt.aggregate.final <-  psales.mt.aggregate%>%
  select(-unit_price)

############################################# ID DROO (MT Model) ###############################################

droo.mt.input <- merge.data.frame(x = id.droo.bango,y =product.mapping,by.x ="Material_Code",by.y = "Material Code")%>%
  merge.data.frame(x = .,y = customer.mapping,by.x = "STP_Code",by.y ="Customer Code")%>%
  merge.data.frame(x = .,y = conversion.mapping,by.x = "Material_Code",by.y = "MATNR")
#select the required columns i.e. Required Basepack fromo the material mapping , Account/Region from the Customer Mapping and Conversion rate from the Conversion mapping 
droo.mt <- droo.mt.input%>%
  select(-c(DIVCD:ncol(.),National:UMREN))
##filter out the observations for which the the Account is "MT" and the required basepack is not 0

droo.mt.filtered <- droo.mt%>%
  filter(`REQUIRED BASEPACK`!=0)
droo.mt.filtered <- droo.mt.filtered%>%
  filter(str_detect(`Account/Region`,"MT"))
#perform the groupby and summarise the KPI's for the given observation
droo.mt.aggregate <- droo.mt.filtered%>%
  group_by(`Calendar Year/Month`,`REQUIRED BASEPACK`,`Account/Region`)%>%
  summarise(`OriginalOrder Qty`=sum(`OriginalOrder Qty`),`Final Customer Expected Order Qty`=sum(`Final Customer Expected Order Qty`),`Dispatched Qty`=sum(`Dispatched Qty`))
#calculate the DR and DROO for the aggregated months 
droo.mt.aggregate%<>%mutate(DR=(`Dispatched Qty`/`Final Customer Expected Order Qty`*100),DROO=(`Dispatched Qty`/`OriginalOrder Qty`*100))
droo.mt.aggregate <- merge.data.frame(droo.mt.aggregate,month.mapping,by.x = "Calendar Year/Month",by.y ="Sec stock_DROO_Penetration" )
droo.mt.aggregate%<>%select(-c(`Primary sales`,TTS_BMI,`Secondary sales`,`Calendar Year/Month`,Sellout))
droo.mt.aggregate[which(is.nan(droo.mt.aggregate$DR)),"DR"] <- 0
droo.mt.aggregate%<>%select(c(Month,`REQUIRED BASEPACK`:DROO))
####################################################### Sell out Data ( MT Model) ################################################################
sellout.mt.input.path <- "C:/Users/goura/OneDrive/Desktop/ID_Jarvis/Python ID KT/Input_files/Sellout"
sellout.files <- list.files(path = sellout.mt.input.path,pattern = "^Sell Out ID AF(.*)xlsx|XLSX$")
sellout.files <- paste0(sellout.mt.input.path,"/",sellout.files)
#read the Alfamart and Indomart data for the preprocessing 
sellout.alfamart.df1 <- read_xlsx(sellout.files,sheet = "SAT",guess_max = 1000,n_max = 2)
sellout.alfamart.df <- read_xlsx(sellout.files,sheet = "SAT",guess_max = 1000,skip = 2)
sellout.indomart.df1 <- read_xlsx(sellout.files,sheet = "IDM",guess_max = 1000,n_max = 2)
sellout.indomart.df <- read_xlsx(sellout.files,sheet = "IDM",guess_max = 1000,skip = 2)
#perform the preprocessing of the Input datasets "Indomart" and "Alfamart and store it in sellout.alfamart.pp and sellout.indomart.pp variable where pp stands for pre processed
sellout.alfamart.pp <- sellout_preprocessing(sellout.alfamart.df1,sellout.alfamart.df)
sellout.indomart.pp <- sellout_preprocessing(sellout.indomart.df1,sellout.indomart.df)
sellout.account.data <- rbind(sellout.alfamart.pp,sellout.indomart.pp)
#perform the mapping at various level as per the business logic - map with the psales data to fetch the Unit price for each required basepack
#map the material description of sellout Alfamart and Indomart with the sellout.product.mapping
sellout.account.basepack.mapped <- merge.data.frame(x = sellout.account.data,y =sellout.material.mapping,by.x ="MAP",by.y = "Material Code",all.x = T  )
sellout.account.basepack.mapped%<>%select(-`Material Desc`)
#perform the Unit price mapping for the alfamart and indomart : Create the Key using the variables {Month,Basepack,Customer}
sellout.account <- sellout.account.basepack.mapped%>%
  unite(col = "Key",c("Month","REQUIRED BASEPACK","Customer"),sep="",remove = F)

psales.mt.aggregate.key <- psales.mt.aggregate%>%
  unite(col="Key",c("Month","REQUIRED BASEPACK","Account/Region"),sep="",remove = F)
psales.mt.aggregate.key <- psales.mt.aggregate.key%>%
  select(c(Key,unit_price))
#fetch the unit price from the psales.mt.aggregate df using the key {Month,Basepack,Customer}
sellout.account.df <- merge.data.frame(sellout.account,psales.mt.aggregate.key,by = "Key",all.x = T)
# Calculate the sellout volumne based on the following logic as mentioned below 
#If unit price is #NA , replace NA's with 0 and Sell out Volume (Kg)= 0 If unit price=0, then sellout volume=0 else Sellout value/Unit Price
sellout.account.df[is.na(sellout.account.df$unit_price),"unit_price"] <- 0
#calculate the sellout volume using the condition ifelse(unit_price==0,sellout_volume=0,sellout_volume=sellout_value/unit_price)
sellout.account.df$Sellout_Volume <- ifelse(sellout.account.df$unit_price==0,0,(sellout.account.df$Sellout_Value/sellout.account.df$unit_price))
#remove the Required Basepack : Bango MT 1-2-3 and NA
sellout.account.df <- sellout.account.df%>%
  filter(!is.na(`REQUIRED BASEPACK`))
########################################################## sellout ( Basepack to Account level) #########################################
exclude_bp.list <- c("Bango Mat 1","Bango Mat 2","Bango Mat 3")
sellout.bp_account.df <- sellout.account.df%>%
  filter(!`REQUIRED BASEPACK` %in% exclude_bp.list)
#perform the grouping and aggregate for the KPI's ( sell out Volume and Sell out Value : sum() and Unit_price : mean())
sellout.bp_account.aggregate <- sellout.bp_account.df%>%
  group_by(Month,Customer,`REQUIRED BASEPACK`)%>%
  summarise(Sellout_Value=sum(Sellout_Value),Sellout_Volume=sum(Sellout_Volume),unit_price=mean(unit_price))

########################################################### sellout ( Bango to Account level) ############################################
sellout.bango_account.df <- sellout.account.df%>%
  filter(!`REQUIRED BASEPACK` %in% c("Bango Mat 3"))

sellout.bango_account.aggregate <- sellout.bango_account.df%>%
  group_by(Month,Customer)%>%
  summarise(Sellout_Value=sum(Sellout_Value),Sellout_Volume=sum(Sellout_Volume),unit_price=mean(unit_price))
sellout.bango_account.aggregate$Product <- "BANGO"
sellout.bango_account.aggregate%<>%select(c(Month,Customer,Product,Sellout_Value:unit_price))
################################################### ID TTS Mapped (MT Model) ######################################################################
tts.mapped.mt.input <- id.tts.mapped.bango
#perform the banner mapping to fetch the channel for the mapped banners
tts.account.mapping <- mapping(input=tts.mapped.mt.input,map =banner.mapping, map_key1 = "Banner",map_key2 = "Banner code")
#filter out the 9 basepacks and all the account for which it's "MT" and "All"
tts.mt.mapped <- tts.account.mapping%>%
  filter(`REQUIRED BASEPACK`!=0)
tts.mt.mapped %<>%filter(str_detect(`Account/Region`,"MT")|`Account/Region`=="ALL")
#perform the grouping of the tts.mt.mapped based on the {Fiscal Year/Period,Required Base Pack,Account/Region}
tts.mt.mapped.aggregate <- tts.mt.mapped%>%
  group_by(`Fiscal year/period`,`REQUIRED BASEPACK`,`Account/Region`)%>%
  summarise(TTS=sum(TTS),BBT=sum(BBT),`BBT - Place`=sum(`BBT - Place`),`BBT - Place on invoice`=sum(`BBT - Place on invoice`),`BBT - Place off invoice`=sum(`BBT - Place off invoice`),`BBT - Price`=sum(`BBT - Price`),`CPP on invoice`=sum(`CPP on invoice`),`CPP off invoice`=sum(`CPP off invoice`),`BBT - Product`=sum(`BBT - Product`),`BBT - Pack`=sum(`BBT - Pack`),`BBT - Proposition`=sum(`BBT - Proposition`),`BBT - Promotion`=sum(`BBT - Promotion`),EOT=sum(EOT))
#################################################### UNMAPPED (MT MODEL)##########################################################################
tts.unmapped.mt.input <- unmapped.material.tts.mapping
tts.unmapped.mt.df <- tts.unmapped.mt.input%>%
  unite(col = "key",c("Banner","Trade Format Level 2","Local Sales Force 2(m.d.)","Local Sales Force 3(m.d.)","Key Customer Level3"),sep="",remove = F)
tts.unmapped.account.mapping <- merge.data.frame(tts.unmapped.mt.df,unmapped.tts.mapping,by.x = "key",by.y = "Key")
tts.mt.unmapped <- tts.unmapped.account.mapping%>%
  filter(`REQUIRED BASEPACK`!=0)
tts.mt.unmapped%<>%filter(str_detect(`Account/Region`,"MT")|`Account/Region`=="ALL")
tts.mt.unmapped%<>%convert(num(TTS:EOT))
tts.mt.unmapped.aggregate <- tts.mt.unmapped%>%
  group_by(`Fiscal year/period`,`REQUIRED BASEPACK`,`Account/Region`)%>%
  summarise(TTS=sum(TTS),BBT=sum(BBT),`BBT - Place`=sum(`BBT - Place`),`BBT - Place on invoice`=sum(`BBT - Place on invoice`),`BBT - Place off invoice`=sum(`BBT - Place off invoice`),`BBT - Price`=sum(`BBT - Price`),`CPP on invoice`=sum(`CPP on invoice`),`CPP off invoice`=sum(`CPP off invoice`),`BBT - Product`=sum(`BBT - Product`),`BBT - Pack`=sum(`BBT - Pack`),`BBT - Proposition`=sum(`BBT - Proposition`),`BBT - Promotion`=sum(`BBT - Promotion`),EOT=sum(EOT))
#################################################### TTS Consolidation ( MT Model) ######################################################################
tts.mt.aggregate <-  rbind(tts.mt.mapped.aggregate,tts.mt.unmapped.aggregate)
#group by the Fiscal {Period,Account,Required Basepack} and summarise the KPI's
tts.mt.aggregate.final <- tts.mt.aggregate%>%
  group_by(`Fiscal year/period`,`REQUIRED BASEPACK`,`Account/Region`)%>%
  summarise(TTS=sum(TTS),BBT=sum(BBT),`BBT - Place`=sum(`BBT - Place`),`BBT - Place on invoice`=sum(`BBT - Place on invoice`),`BBT - Place off invoice`=sum(`BBT - Place off invoice`),`BBT - Price`=sum(`BBT - Price`),`CPP on invoice`=sum(`CPP on invoice`),`CPP off invoice`=sum(`CPP off invoice`),`BBT - Product`=sum(`BBT - Product`),`BBT - Pack`=sum(`BBT - Pack`),`BBT - Proposition`=sum(`BBT - Proposition`),`BBT - Promotion`=sum(`BBT - Promotion`),EOT=sum(EOT))
#perform the month mapping and format the data in non scientific notation 
tts.mt.aggregate.final.df <- merge.data.frame(x = tts.mt.aggregate.final,y = month.mapping,by.x = "Fiscal year/period" , by.y = "TTS_BMI")
tts.mt.aggregate.final.df%<>%select(-c(`Primary sales`:`Sec stock_DROO_Penetration`,Sellout,`Fiscal year/period`))
tts.mt.aggregate.final.df%<>%select(c(Month,`REQUIRED BASEPACK`:EOT))
#################################################### BMI Mapped (MT Model) ##############################################################################
bmi.mapped.mt.input <- id.bmi.mapped.df
#map the sub brands and fetch the required basepacks 
sub_brand_basepack <- subrand.mapping%>%
  select(c(`Sub brands`,Mapping_Basepack))
#drop the columns for which the col name is unnamed


bmi.mapped.mt.data <- merge.data.frame(x = bmi.mapped.mt.input,y = sub_brand_basepack,by.x = "Sub Brand (PH)" ,by.y = "Sub brands" )
#filter out the observations for which the Mapping Basepack != NA
bmi.mapped.mt.data <- subset(x = bmi.mapped.mt.data ,subset = Mapping_Basepack=="Bango")
#mapped the customers from the banner mapping file 
bmi.mapped.mt.cust <- merge.data.frame(bmi.mapped.mt.data,y = banner.mapping,by.x = "Banner",by.y ="Banner code")
#filter out the observations for MT and All
bmi.mapped.mt.cust.filtered <- bmi.mapped.mt.cust%>%
  filter(str_detect(`Account/Region`,"MT")|`Account/Region`=="ALL")
#aggregate the KPI's after grouping them

bmi.mapped.mt.filtered.aggregate <- bmi.mapped.mt.cust.filtered%>%
  group_by(`Fiscal year/period`,Mapping_Basepack,`Account/Region`)%>%
  summarise(X..Brand...Marketing.Investment=sum(X..Brand...Marketing.Investment),X..Brand...Marketing.Investment.Trade=sum(X..Brand...Marketing.Investment.Trade),X..Brand...Marketing.Investment.Consumer=sum(X..Brand...Marketing.Investment.Consumer),X..Promotional.Expenses=sum(X..Promotional.Expenses),X....Promotion.Packaging.Material.Cost=sum(X....Promotion.Packaging.Material.Cost),X......Promotion.Packaging.Material.Cost.Trade=sum(X......Promotion.Packaging.Material.Cost.Trade),X......Promotion.Packaging.Material.Cost.Consumer=sum(X......Promotion.Packaging.Material.Cost.Consumer),X....Promotion.Repacking.Cost=sum(X....Promotion.Repacking.Cost),X......Promotion.Repacking.Cost.Trade=sum(X....Promotion.Repacking.Cost),X......Promotion.Repacking.Cost.Trade=sum(X......Promotion.Repacking.Cost.Trade),X......Promotion.Repacking.Cost.Consumer=sum(X......Promotion.Repacking.Cost.Consumer),X....Promotion.Communication.Material.Cost=sum(X....Promotion.Communication.Material.Cost),X......Promotion.Communication.Material.Cost.Trade=sum(X......Promotion.Communication.Material.Cost.Trade),X......Promotion.Communication.Material.Cost.Consumer=sum(X......Promotion.Communication.Material.Cost.Consumer),X....Promo.Samples..Gifts.and.Incentive.Costs=sum(X....Promo.Samples..Gifts.and.Incentive.Costs),X......Promo.Samples..Gifts.and.Incentive.Costs.Consumer=sum(X......Promo.Samples..Gifts.and.Incentive.Costs.Consumer),X....Promotion.Team.Cost=sum(X....Promotion.Team.Cost),X......Promotion.Team.Cost.Trade=sum(X......Promotion.Team.Cost.Trade),X......Promotion.Team.Cost.Consumer=sum(X......Promotion.Team.Cost.Consumer),X....Promo.Agency.Remun.Fees...Commissions=sum(X....Promo.Agency.Remun.Fees...Commissions),X......Promo.Agency.Remuneration.Fees...Commissions.Trade=sum(X......Promo.Agency.Remuneration.Fees...Commissions.Trade),X......Promo.Agency.Remuneration.Fees...Commissions.Consumer=sum(X......Promo.Agency.Remuneration.Fees...Commissions.Consumer))
#rename the KPI's columns
bmi.mapped.mt.filtered.aggregate1 <- bmi.mapped.mt.filtered.aggregate%>%
  dplyr::rename(`Brand & Marketing Investment`=X..Brand...Marketing.Investment,`Brand & Marketing Investment Trade`=X..Brand...Marketing.Investment.Trade,`Brand & Marketing Investment Consumer`=X..Brand...Marketing.Investment.Consumer,`Promotional Expenses`=X..Promotional.Expenses,`Promotion Packaging Material Cost`=X....Promotion.Packaging.Material.Cost,`Promotion Communication Material Cost Trade`=X......Promotion.Communication.Material.Cost.Trade,`Promotion Packaging Material Cost Consumer`=X......Promotion.Packaging.Material.Cost.Consumer,`Promotion Repacking Cost`=X....Promotion.Repacking.Cost,`Promotion Repacking Cost Trade`=X......Promotion.Repacking.Cost.Trade,`Promotion Repacking Cost Consumer`=X......Promotion.Repacking.Cost.Consumer,`Promotion Communication Material Cost`=X....Promotion.Communication.Material.Cost,`Promotion Communication Material Cost Consumer`=X......Promotion.Communication.Material.Cost.Consumer,`Promo Samples, Gifts and Incentive Costs` =X....Promo.Samples..Gifts.and.Incentive.Costs,`Promo Samples, Gifts and Incentive Costs Consumer`=X......Promo.Samples..Gifts.and.Incentive.Costs.Consumer,`Promotion Team Cost`=X....Promotion.Team.Cost,`Promotion Team Cost Trade`=X......Promotion.Team.Cost.Trade,`Promotion Team Cost Consumer`=X......Promotion.Team.Cost.Consumer,`Promo Agency Remun Fees & Commissions`=X....Promo.Agency.Remun.Fees...Commissions,`Promo Agency Remuneration Fees & Commissions Trade`=X......Promo.Agency.Remuneration.Fees...Commissions.Trade,`Promo Agency Remuneration Fees & Commissions Consumer`=X......Promo.Agency.Remuneration.Fees...Commissions.Consumer)

bmi.mapped.mt.filtered.aggregate1%<>%dplyr::rename(`Promotion Packaging Material Cost Trade`=X......Promotion.Packaging.Material.Cost.Trade)

