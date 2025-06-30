# Tecan-data-processing

## What does it do?

Converts raw ouput of Tecan instruments such as Tecan SPARK into tidy long column format 

## Why?

Tecan instruments output plate measurements in excel files where the data is structured in the same way as the plate. This format makes it very tedious to further process the data and plot it

## How do I use this script?

1. Fill the config file with necessary info (data directory, output directory, etc.)
2. Put all your raw data files in the data directory and add the word "RAW" in their file name
3. Fill the Layout.xlsx (Layout-example.xlsx file is provided)
4. Run TECAN-ANALYSIS.R (TECAN-FUNCTIONS.R) must be in the same directory

### Important notes

- You can process as many raw data files as you want. If you gave the variables the same name in the TECAN software, they will be grouped together.
- The timestamp is imported from the raw data files, so if you have different files from measuring your plate multiple times, you do not need to add "timepoint" or "time" to the Layout file
- The above two comments are relevant if you *manually* sample the same plate or different plates. If you program a time loop with automatic regular measurements, TECAN will output the data in a completely different format.
- Do not forget step 2 or the script won't be able to detect your data files

## How do I fill the Layout file?

The first column of the file contain the well ID (e.g. A4) - do not modify this.

The second colum is named `well_used`. You should give it a value of `1` if the well contains any sample and `0` if it does not (it will then be excluded from the final data frame).

You can now add more column with your treatment factors. Let us see a small example of how this would work.

Imagine a experiment in which you with to test the effect of a drug at different concentrations (10, 100, 1000) in 2 bacterial strains (A, B). Crossing both factors gives 3x2=6 combinations. Assuming you use triplicates, then you will need 6x3=18 samples in total.

You arrange your plate so that the rows match with the strains and the columns with the concentrations in triplicates. Your layout thus looks like this: wells A1 to A3 will contain strain A treated with 10 units of drug, wells A4 to A6 contain strain A treated with 100 units, and well A7 to A9 contain strain A treated with 1000 units. The strain B samples are arranged similarly in row B (B1 to B9).

In this example, your layout file should look like this.

| Well | well_used | strain | drug |
|------|-----------|--------|------|
| A1   | 1         | A      | 10   |
| A2   | 1         | A      | 10   |
| A3   | 1         | A      | 10   |
| A4   | 1         | A      | 100  |
| A5   | 1         | A      | 100  |
| A6   | 1         | A      | 100  |
| A7   | 1         | A      | 1000 |
| A8   | 1         | A      | 1000 |
| A9   | 1         | A      | 1000 |
| A10  | 0         |        |      |
| A11  | 0         |        |      |
| A12  | 0         |        |      |
| B1   | 1         | B      | 10   |
| B2   | 1         | B      | 10   |
| B3   | 1         | B      | 10   |
| B4   | 1         | B      | 100  |
| B5   | 1         | B      | 100  |
| B6   | 1         | B      | 100  |
| B7   | 1         | B      | 1000 |
| B8   | 1         | B      | 1000 |
| B9   | 1         | B      | 1000 |
| ...  | ...       | ...    | ...  |

### A word of caution

Depending on the experimental design you may also need to add `replicate` as a column.
