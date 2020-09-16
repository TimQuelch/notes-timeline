import git
import os
import re
import pandas as pd
import matplotlib.pyplot as plt

repo = git.Repo(os.path.join(os.getcwd(), "notes"))

exFiles = ["inbox", "todo", "setup"]
exSubdirs = ["calendars"]
exExtensions = []


def excludeFiles(blob):
    name, _ = os.path.splitext(blob.name)
    return name in exFiles


def excludeSubdirs(blob):
    directory = os.path.dirname(blob.path)
    return directory in exSubdirs


def excludeExtensions(blob):
    _, ext = os.path.splitext(blob.name)
    return ext in exExtensions


excluders = [excludeFiles, excludeSubdirs, excludeExtensions]


def processContents(s):
    # Remove backslashes (weird escapes)
    s = re.sub(r"\\", "", s)

    # Remove blocks
    blockRe = r"#\+begin_?([^ \n]+).*?#\+end_?\1"
    s = re.sub(blockRe, "", s, flags=(re.I | re.S))

    # Remove keywords
    keywordRe = r"#\+(.*):(.*)\n"
    s = re.sub(keywordRe, "", s, flags=(re.I))

    return s


def extractData(commit):
    blobs = [
        x
        for x in c.tree.traverse()
        if x.type == "blob" and not any(f(x) for f in excluders)
    ]
    words = [len(processContents(b.data_stream.read().decode()).split())
             for b in blobs]
    dateutc = pd.to_datetime(c.authored_date, unit="s", utc=True)
    date = dateutc.tz_convert('Australia/Melbourne')
    return {
        "date": date,
        "words": sum(words),
        "files": len(blobs),
        "commit": commit.hexsha,
    }


data = pd.DataFrame()
for c in repo.iter_commits():
    data = data.append(extractData(c), ignore_index=True)

data = data.set_index("date")

fig, ax = plt.subplots()
data["words"].plot(ax=ax)
data["files"].plot(ax=ax, secondary_y=True)
print(data.head())

fig, ax = plt.subplots()
ax2 = ax.twinx()
weekday = data.groupby(data.index.weekday).mean()
weekday["words"].plot.bar(ax=ax, position=0, width=0.4, color='blue')
weekday["files"].plot.bar(ax=ax2, position=1, width=0.4, color='red')

fig, ax = plt.subplots()
ax2 = ax.twinx()
hour = data.groupby(data.index.hour).mean()
hour["words"].plot.bar(ax=ax, position=0, width=0.4, color='blue')
hour["files"].plot.bar(ax=ax2, position=1, width=0.4, color='red')


plt.show()

print(data.iloc[data["words"].argmax()])
