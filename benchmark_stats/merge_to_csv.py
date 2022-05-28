import os
import glob
import csv

dirpath = os.getcwd()
output = dirpath 
csvout_lst = []
# files = glob.glob(os.path.join(dirpath, "*.csv"))
row_titles = [ "Drv.→kern", "Kern.→drv", "Functions", "Deep copy fields", "Access analysis", "Shared analysis", "Boundary opt analysis" , "Pointers", "Unions", "Critical sections", "RCU", "Seqlock", "Atomic Operations", "Container of", "Singleton", "Array", "String", "Void", "Wild"]
files = ["coretemp.csv","dummy.csv", "ixgbe.csv", "alx.csv", "can-raw.csv", "sb_edac.csv", "null_blk.csv", "dm-zero.csv", "msr.csv", "xhci-hcd.csv" ]

csvout_lst.append(row_titles)

for filename in files:
    #if "merged_stats.csv" in filename:
        #continue
    print("processing", filename)
    with open(filename) as f:
        lines = [line.rstrip() for line in f]
        csvout_lst.append(lines)

with open("merged_stats.csv", "w") as f:
    headers = files
    headers = [header[:-4] for header in headers]
    headers.insert(0, " ")
    writer = csv.writer(f)
    writer.writerow(headers)
    rows = zip(*csvout_lst)
    for row in rows:
        writer.writerow(row)

