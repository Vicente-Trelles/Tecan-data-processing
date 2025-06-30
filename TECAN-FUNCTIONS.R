# ==============================================================================
detect_raw_files <- function(path){
  # ----------------------------------------------------------------------------
  ## FUNCTION - Detect raw files in the given path by using the keyword RAW at
  # the beginning of the file name
  # ----------------------------------------------------------------------------
  file_list <- list.files(path = path)
  RAW_file_list <- file_list[grepl("RAW", file_list)]
  return(RAW_file_list)
}
# ==============================================================================


# ==============================================================================
get_plate_data_matrix <- function(file_data, row_data_location, no_wells){
  # ----------------------------------------------------------------------------
  ## FUNCTION - Given a location of the top left corner of plate data in an
  # excel file, extracts the data as matrix (size depends on number of wells).
  
  # Here, location refers to row. This is the row where the numbers of the plate
  # are. The column is column number 1, where the letters are. This means that
  # well A1 is one column right and one row low compared to the row location input
  # ----------------------------------------------------------------------------
  
  if (no_wells == 24){
    rows <- 4
    cols <- 5}
  else if (no_wells == 96){
    rows <- 8
    cols <- 12} else {
      stop("Warning from get_plate_data_matrix function: no_wells must be 96 or 24")}
  
  
  rows_data <- seq(row_data_location+1, row_data_location+rows)
  cols_data <- seq(2, cols+1)
  plate_data_matrix <- file_data[rows_data, cols_data]
  
  
  return(plate_data_matrix)
}
# ==============================================================================


# ==============================================================================
plate_to_vector <- function(plate_data_matrix){
  # ----------------------------------------------------------------------------
  ## FUNCTION - Convert plate matrix to vector format in the horizontal direction
  # (A1 -> A12 -> B1 -> ... etc)
  # ----------------------------------------------------------------------------
  return(c(t(plate_data_matrix))) 
}
# ==============================================================================

# ==============================================================================
combine_data_metadata <- function(plate_vectorized_data, plate_meausurement,
                                  layout_df, plate_timepoint, file_name){
  # ----------------------------------------------------------------------------
  ## FUNCTION - Attaches metadata to measurement)
  # ----------------------------------------------------------------------------
  processed_plate_data_df <- data.frame(values = plate_vectorized_data)
  
  processed_plate_data_df$measurement <- rep(plate_meausurement, nrow(processed_plate_data_df))
  processed_plate_data_df$timepoint <- rep(plate_timepoint, nrow(processed_plate_data_df))
  processed_plate_data_df$original_file <- rep(file_name, nrow(processed_plate_data_df))
  
  processed_plate_data_df$Well <- layout_df$Well
  processed_plate_data_df <- full_join(layout_df, processed_plate_data_df, by="Well")
  
  return(processed_plate_data_df) 
}
# ==============================================================================


# ==============================================================================
filterout_empty <- function(data){
  # ----------------------------------------------------------------------------
  ## FUNCTION - Filters out of the dataframe all rows for which the column
  # well_used is 0, keeping those where the value of well_used is 1
  # ----------------------------------------------------------------------------
  return(data[data$well_used == 1,])
}
# ==============================================================================

# ==============================================================================
compute_se <- function(values) {
  # ----------------------------------------------------------------------------
  ## FUNCTION - Computes the standard error of a set of values
  # ----------------------------------------------------------------------------
  return(sqrt(sum((values-mean(values))^2/(length(values)-1)))/sqrt(length(values)))
} 
# ==============================================================================

# ==============================================================================
SPARK_get_timepoint <- function(file_data){
  # ----------------------------------------------------------------------------
  ## FUNCTION - Detects the timepoint of measurement based on the POSIXct
  # function, which stores date and time in seconds with the number of seconds
  # beginning at 1 January 1970
  # ----------------------------------------------------------------------------
  date_val <- filter(file_data, file_data$...1=="Date:")[5]
  time_val <- filter(file_data, file_data$...1=="Time:")[5]
  return(as.POSIXct(paste(date_val, time_val)))
}
# ==============================================================================


# ==============================================================================
SPARK_detect_platedata_start <- function(file_data){
  # ----------------------------------------------------------------------------
  ## FUNCTION - Detects the start of plate measurement data in a SPARK excel
  # output file. This is done by searching for"<>", which is always located at
  # the top left corner of plates in the SPARK output files.
  
  # We skip the first position because that is simply the plate layout without 
  # any values
  # ----------------------------------------------------------------------------
  row_data_location_list <- which(file_data$...1 == "<>")
  #return(row_data_location_list[-1])
  return(row_data_location_list)
}
# ==============================================================================


# ==============================================================================
SPARK_get_plate_measurement <- function(file_data, ii){
  # ----------------------------------------------------------------------------
  ## FUNCTION - Extract the measurement name for a specific pate data (extracts
  # the measurement name of the iith plate in the file)
  # ----------------------------------------------------------------------------
  
  f_df <- filter(file_data, ...1 == "Name") # get all rows starting with "Name"
  f_df <- f_df[-1,] # eliminate first column (contains plate name)
  f_df <- f_df[[ii, 2]] # get iith measurement name
  
  return(f_df)
}
# ==============================================================================


# ==============================================================================
SPARK_data_extraction <- function(file_name, file_data, row_data_location_list,
                                  no_wells, layout_df, path){
  # ----------------------------------------------------------------------------
  ## FUNCTION - Loops over an open SPARK output file and collects all data, 
  # including metadata into a file_df
  
  # Calls other custom functions
  # ----------------------------------------------------------------------------
  
  # Get time point of file (from file name)
  plate_timepoint <- SPARK_get_timepoint(file_data)
  
  # Initialize file_df
  file_df <- data.frame()
  
  for (ii in 1:length(row_data_location_list)){ 
    
    # Loop through all plates in the file
    row_data_location <- row_data_location_list[ii]
    
    # Extract the data as matrix (matrix size depends on number of wells)
    plate_data_matrix <- get_plate_data_matrix(file_data, row_data_location,
                                               no_wells)
    
    # Extract the type of measurement
    plate_meausurement <- SPARK_get_plate_measurement(file_data, ii)
    
    # Convert plate matrix to vector format in the horizontal direction
    # (A1 -> A12 -> B1 -> ... etc)
    plate_vectorized_data <- plate_to_vector(plate_data_matrix)
    
    # Combine measurement results with metadata and Layout metadata
    processed_plate_data_df <- combine_data_metadata(plate_vectorized_data,
                                                     plate_meausurement,
                                                     layout_df,
                                                     plate_timepoint,
                                                     file_name)
    
    # Append to file_df
    file_df <- rbind(file_df, processed_plate_data_df)
    
  } # end loop within file
  
  file_df <- filterout_empty(file_df) # filter out empty wells
  file_df$values <- as.numeric(file_df$values) # make sure values are numbers
  
  return(file_df)
}
# ==============================================================================


# ==============================================================================
SPARK_data_normalization <- function(file_df, n_measurements){
  # ----------------------------------------------------------------------------
  ## FUNCTION - Normalizes by OD600
  # ----------------------------------------------------------------------------
  
  norm_vector <- filter(file_df, measurement %in% c("od600", "OD600"))$values
  norm_long_vector <- rep(norm_vector, n_measurements)
  file_df$norm_values <- file_df$values/norm_long_vector
  normalized_plate_data_df <- file_df
  return(normalized_plate_data_df)
}
# ==============================================================================



# ==============================================================================
SPARK_process_all_raw_files <- function(path, no_wells, plate_layout){
  # ----------------------------------------------------------------------------
  ## FUNCTION - Process raw SPARK Tecan plate reader and extracts measurement
  # data and metadata (time, what was measured, etc).
  
  # Calls other custom functions
  # ----------------------------------------------------------------------------
  
  
  # Detect raw files in the given path by using the keyword RAW at the beginning
  # of the file name. Calls custom function.
  RAW_file_list <- detect_raw_files(path)
  
  # Initialize master data frame to put all the results
  master_df <- data.frame()
  
  # Open layout file
  layout_df <- read_excel(paste0(path,"/",plate_layout), col_names=TRUE, skip = 0)
  
  file_name <- RAW_file_list[1]
  
  for (file_name in RAW_file_list){  # Loop through all raw files
    # Open file
    file_data <- read_excel(paste0(path,"/",file_name), col_names=FALSE, skip = 0)
    
    
    # Detect plate output by using the <> put in the top left corner of
    # plates in the SPARK output files
    row_data_location_list <- SPARK_detect_platedata_start(file_data)
    
    ## EXTRACT DATA
    file_df <- SPARK_data_extraction(file_name, file_data, row_data_location_list,
                                     no_wells, layout_df, path)
    
    ## NORMALIZE
    n_measurements <- length(row_data_location_list)
    norm_file_df <- SPARK_data_normalization(file_df, n_measurements)
    
    ## Append to master_df
    master_df <- rbind(norm_file_df, master_df)
    
  } # end loop over all files
  return(master_df)
} # end function
# ==============================================================================

# ==============================================================================
perform_pre_loop_checks <- function(RAW_file_list, layout_df){
  # ----------------------------------------------------------------------------
  ## FUNCTION - Checks for errors
  # ----------------------------------------------------------------------------
  
  # --- Check raw file list contains files
  if (identical(RAW_file_list, character(0))){stop("No raw files detected in data directory. Check data directory in config file and make sure that all raw data files contain the keyword `RAW` in their file name")}
  
  # --- Check layout does not contain forbidden column names
  forbidden = c("measurement", "timepoint", "values", "original_file")
  if (map(colnames(layout_df), ~ .x == forbidden) %>% Reduce(`+`, .) %>% sum() != 0){
    stop(paste0("Layout file is using forbidden column names. The following are forbidden:",
                forbidden |> sprintf(fmt = "'%s'") |> toString(), ". Please substitute in layout file"))}
  
  # --- Check cf file contains valid values for no_wells
  if (cf$no_wells %in% c(24, 96)){} else {
    stop("no_wells entry in config file must be either 24 or 96")}
  
  # --- Check cf file contains valid values for norm_by_OD
  if (cf$norm_by_OD %in% c("Y", "N")){} else {
    stop("norm_by_OD entry in config file must be either Y or N")}
}
# ==============================================================================

# ==============================================================================
check_for_OD <- function(RAW_file_list, layout_df){
  # ----------------------------------------------------------------------------
  ## FUNCTION - Checks for errors
  # ----------------------------------------------------------------------------
  
  if (file_df$measurement %in% c("od600", "OD600") %>% sum() == 0){
    stop("norm_by_OD entry in config file set to Y, but couldn't find OD values in layout file.
         OD values must be labelled either od600 or OD600")}
}
# ==============================================================================
