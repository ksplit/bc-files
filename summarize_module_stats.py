import os

dir_path = os.getcwd()
summary_file_path = os.path.join(dir_path, "table2_stats")
summary_file = open(summary_file_path, "w")
valid_file_num = 0

stats_file_name = "table2"
stats_len = 15
stats_arr = [[0.0, 0.0] for _ in range(15)]

def collectStats(word_dir_path):
	stats_file = os.path.join(work_dir_path, stats_file_name)
	print(stats_file)
	if os.path.isfile(stats_file):
		global valid_file_num
		valid_file_num += 1
		with open(stats_file) as f:
			content = f.readlines()
			lines = [c.strip() for c in content]
			if len(lines) != stats_len:
				return
			for idx, l in enumerate(lines):
				vals = l.split("/")
				stats_arr[idx][0] += float(vals[0])
				if len(vals) == 2:
					stats_arr[idx][1] += float(vals[1])
				else:
					stats_arr[idx][1] = -1;



for d in os.listdir(dir_path):
	if (not d.startswith(".")):
		work_dir_path = os.path.join(dir_path, d)
		collectStats(work_dir_path)

for arr in stats_arr:
    arr[0] /= valid_file_num
    arr[1] /= valid_file_num

with open(summary_file_path, "w") as f:
    for arr in stats_arr:
        f.write ("{0:.2f}".format(arr[0]))
        if arr[1] < 0.0:
            f.write("\n")
        else:
            f.write ("/{0:.2f}\n".format(arr[1]))
