# Pick out data from a set of CSV files with the columns: time, value, tag. Normlize and plot the data
  
import pandas as pd
import glob
import os
import importlib.util
from datetime import datetime

# Sjekk om matplotlib er installert én gang for hele skriptet
matplotlib_available = importlib.util.find_spec("matplotlib")

def normalize_series(series):
    return (series - series.min()) / (series.max() - series.min())

def filter_csv_files(folder_path, start_time, end_time, tags, output_file, normalized_output_file):
    all_files = glob.glob(folder_path + "/*.csv")
    filtered_data = []
    
    # Konverter start og sluttid til datetime
    start_dt = datetime.strptime(start_time, "%Y-%m-%d %H:%M:%S")
    end_dt = datetime.strptime(end_time, "%Y-%m-%d %H:%M:%S")
    
    for file in all_files:
        # Ekstraher tidsstempel fra filnavn
        filename = os.path.basename(file)
        file_timestamp_str = filename.split("_")[-1].split(".")[0]  # Henter tidsstempel fra filnavn
        file_dt = datetime.strptime(file_timestamp_str, "%Y%m%d%H%M%S")
        
        # Hopp over filer utenfor tidsintervallet
        if file_dt < start_dt or file_dt > end_dt:
            continue
        
        df = pd.read_csv(file, header=None, names=["timestamp", "value", "tag"], parse_dates=["timestamp"])
        df_filtered = df[(df["timestamp"] >= start_time) & (df["timestamp"] <= end_time) & (df["tag"].isin(tags))]
        filtered_data.append(df_filtered)
    
    if filtered_data:
        result_df = pd.concat(filtered_data, ignore_index=True)
        result_df.to_csv(output_file, index=False)
        print(f"Filtered data saved to {output_file}")
        
        # Lag en kopi for normalisering
        normalized_df = result_df.copy()
        for tag in tags:
            normalized_df.loc[normalized_df["tag"] == tag, "value"] = normalize_series(normalized_df[normalized_df["tag"] == tag]["value"])
        
        normalized_df.to_csv(normalized_output_file, index=False)
        print(f"Normalized data saved to {normalized_output_file}")
        
        # Plott kun hvis matplotlib er tilgjengelig
        if matplotlib_available:
            import matplotlib.pyplot as plt
            
            plt.figure(figsize=(12, 6))
            plt.tight_layout()
            for tag in tags:
                tag_data = result_df[result_df["tag"] == tag]
                normalized_tag_data = normalized_df[normalized_df["tag"] == tag]
                plt.plot(tag_data["timestamp"], tag_data["value"], label=f"Original {tag}", linestyle='dashed')
                plt.plot(normalized_tag_data["timestamp"], normalized_tag_data["value"], label=f"Normalized {tag}")
            
            plt.xlabel("Timestamp")
            plt.ylabel("Value")
            plt.title("Original and Normalized Data Plot")
            plt.legend()
            plt.xticks(rotation=45)
            plt.grid()
            plt.show()
        else:
            print("matplotlib is not installed. Skipping plot generation.")
    else:
        print("No matching data found in the selected files.")

# Brukseksempel
folder_path = "E:/Export"  # Plassering av datafiler
start_time = "2024-06-06 00:00:00"  # Start tidspunkt
end_time = "2024-06-09 00:00:00"    # Slutt tidspunkt
tags = ["tag1","tag2"]  # Liste over ønskede tags
output_file = "filtered_data.csv"    # Fil for lagring av original data
normalized_output_file = "normalized_data.csv"  # Fil for lagring av normalisert data

filter_csv_files(folder_path, start_time, end_time, tags, output_file, normalized_output_file)
