import getpass
import oracledb
import csv
from datetime import datetime

pw = getpass.getpass("Enter password: ")

connection = oracledb.connect(user="OSLGSK", password=pw,
                              host="glo-lnx-ora01.elkem.com", port=1521, service_name="carlabpr.glo.elkem")

print("Successfully connected to Oracle Database")

# Get today's date in the format "ddmmyy"
today_date = datetime.now().strftime("%d%m%y")

# List of queries and associated table names
queries = [
    ("""
    SELECT r.*
    FROM limsprod.s_request r
    WHERE r.securitydepartment = 'ElkemCarbon Battery'
    ORDER BY r.createdt ASC
    """, "s_request"),
    ("""
    SELECT s.*
    FROM limsprod.s_sample s
    WHERE s.securitydepartment = 'ElkemCarbon Battery'
    AND s.s_sampleid LIKE 'S%'
    ORDER BY s.createdt ASC
    """, "s_sample"),
    ("""
    SELECT d.*
    FROM limsprod.sdidataitem d
    JOIN limsprod.s_sample s ON s.s_sampleid = d.keyid1
    WHERE s.securitydepartment = 'ElkemCarbon Battery'
    AND s.s_sampleid LIKE 'S%'
    ORDER BY d.createdt ASC
    """, "sdidataitem"),
    ("""
    SELECT c.*
    FROM LIMSPROD.S_CHILDSAMPLE c
    JOIN limsprod.s_sample s ON s.s_sampleid = c.S_SAMPLEID
    WHERE s.securitydepartment = 'ElkemCarbon Battery'
    AND s.s_sampleid LIKE 'S%'
    ORDER BY s.CREATEDT ASC
    """, "s_childsample")
]

# Chunk size
chunk_size = 5000

def export_data_in_chunks(query, table_name, chunk_size):
    cursor = connection.cursor()
    try:
        # First, execute the ALTER SESSION statement
        cursor.execute("ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD'")

        # Now execute the main query
        cursor.execute(query)
        headers = [i[0] for i in cursor.description]
        file_index = 1
        while True:
            rows = cursor.fetchmany(chunk_size)
            if not rows:
                break
            filename = f"{today_date}_{table_name}_{file_index}.csv"
            with open(filename, 'w', newline='', encoding='utf-8') as file:
                csv_writer = csv.writer(file)
                if file_index == 1:  # Write headers only for the first file
                    csv_writer.writerow(headers)
                for row in rows:
                    csv_writer.writerow(row)
            print(f"Data written to {filename}")
            file_index += 1
    finally:
        cursor.close()

# Run the function for each query
for query, table_name in queries:
    export_data_in_chunks(query, table_name, chunk_size)

# Close the connection after all queries are processed
connection.close()
