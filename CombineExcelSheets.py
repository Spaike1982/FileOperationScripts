import pandas as pd
import os

# Filnavn
filnavn1 = "C:\\Temp\\GenerateFileImportFile\\PLCChartsReturkraft.xlsx"
filnavn2 = "C:\\Temp\\GenerateFileImportFile\\Tagtyperbesluttning.xlsx"

# Les inn dataene fra valgfri sheets.
df1 = pd.read_excel(filnavn1, sheet_name=None)  # Les alle sheets fra fil1
df2 = pd.read_excel(filnavn2, sheet_name="Tags plukket")

total_sheets = len(df1)
processed_sheets = 0

# Kombiner filene basert på kolonnene "Type:" og "BlockType"
for sheet_name, df_sheet in df1.items():
    processed_sheets += 1
    print(f"Processing sheet {processed_sheets}/{total_sheets} - {sheet_name}")

    # Filtrer df1 basert på "OCM possible" = 1
    df_filtered = df_sheet.query('`OCM possible` == 1')
    
    # Merge df_filtered with df2 directly based on the matching columns
    combined_df_sheet = pd.merge(df_filtered, df2, left_on='Block type', right_on='Type:', how='inner')
    
    # Skriv til Excel-fil
    output_file = f'C:\\Temp\\GenerateFileImportFile\\{sheet_name}.xlsx'
    combined_df_sheet.to_excel(output_file, index=False)
    print(f"File {output_file} generated.")

print("Script execution completed.")
