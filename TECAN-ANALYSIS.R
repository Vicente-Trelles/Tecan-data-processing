## ========= SETUP ===========

# Load packages
library(tidyverse)
library(config)
library(ggplot2)
library(readxl)
library(cowplot)

# Load custom-made functions
source("TECAN-FUNCTIONS.R")

# Load config file
cf <- config::get() #must be a yml file named "config" in the same location as the script. Check package config for details

## ========= RAW DATA PROCESSING ===========

# Pre-loop

path <- cf$data_dir; no_wells <- cf$no_wells; plate_layout <- cf$layout_file
RAW_file_list <- detect_raw_files(path) # Detect raw files in the given path by using the keyword RAW
layout_df <- read_excel(paste0(path,"/",plate_layout), col_names=TRUE, skip = 0) # Open layout file
master_df <- data.frame() # Initialize master data frame to put all the results
file_name <- RAW_file_list[1] # used for debugging

perform_pre_loop_checks(RAW_file_list, layout_df) # checks for errors

# Main loop

for (file_name in RAW_file_list){  # Loop through all raw files

  # EXTRACT DATA
  file_data <- read_excel(paste0(path,"/",file_name), col_names=FALSE, skip = 0) # Open file
  row_data_location_list <- SPARK_detect_platedata_start(file_data) # Detect plate output location in TECAN output file
  file_df <- SPARK_data_extraction(file_name, file_data, row_data_location_list,
                                   no_wells, layout_df, path) # EXTRACT DATA
  
  # NORMALIZE
  if (cf$norm_by_OD == "Y"){
    check_for_OD()
    n_measurements <- length(row_data_location_list)
    norm_file_df <- SPARK_data_normalization(file_df, n_measurements)

    # APPEND TO master_df
    master_df <- rbind(norm_file_df, master_df)
    } 

  # APPEND TO master_df
  else{
    master_df <- rbind(file_df, master_df)
  }
  
  

}

master_df$timepoint <- strptime(master_df$timepoint, "%Y-%m-%d %H:%M:%S")
master_df$time_from_start <- difftime(master_df$timepoint, min(master_df$timepoint), units = "hours") %>% as.numeric()


## ========= EXPORT PROCESSED DATA ===========

## Export data
write.csv(master_df, file = paste0(cf$output_dir, "/", cf$output_name, "_OUTPUT.csv"),
          row.names = FALSE) # export processed data

df <- data.frame(matrix(unlist(cf), nrow=length(cf), byrow=TRUE))

write.csv(df, file = paste0(cf$output_dir, "/", cf$output_name, "_CONFIG.csv"),
          row.names = FALSE) # export configuration used to process data

