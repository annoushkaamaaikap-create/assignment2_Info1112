#!/usr/bin/env python3
"""
Small plotting helper for INFO1112 Assignment 2.

AI acknowledgement:
The plotting code in this file was generated with assistance from OpenAI ChatGPT
(GPT-5.6 Sol).  The assignment explicitly permits AI-generated Python for the
population line plot.  The year/population data is extracted from the ABS CSV
by Bash in server.sh before this Python file is called.
"""

import csv
import sys

import matplotlib.pyplot as plt


if len(sys.argv) != 3:
    print("usage: python3 plot_population.py population_data.csv population.png")
    sys.exit(1)

input_file = sys.argv[1]
output_file = sys.argv[2]

years = []
populations = []

with open(input_file, "r", encoding="utf-8") as file:
    reader = csv.reader(file)
    for row in reader:
        if len(row) != 2:
            continue

        years.append(int(row[0]))
        populations.append(float(row[1]))

if not years:
    print("error: no population data was supplied to the plotting program")
    sys.exit(1)

plt.figure(figsize=(8, 5))
plt.plot(years, populations, marker="o")
plt.xlabel("Year")
plt.ylabel("Population")
plt.title("NSW Estimated Resident Population")
plt.grid(True)
plt.tight_layout()
plt.savefig(output_file)
plt.close()
