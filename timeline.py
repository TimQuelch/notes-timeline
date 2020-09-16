import git
import os
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


data = pd.DataFrame()


def extractData(commit):
    blobs = [
        x
        for x in c.tree.traverse()
        if x.type == "blob" and not any(f(x) for f in excluders)
    ]
    words = [len(b.data_stream.read().split()) for b in blobs]
    return {
        "date": pd.to_datetime(c.authored_date, unit="s"),
        "size": sum(words),
        "files": len(blobs),
        "commit": commit.hexsha,
    }


for c in repo.iter_commits("master"):
    data = data.append(extractData(c), ignore_index=True)

data = data.set_index("date")

data["size"].plot()
data["files"].plot(secondary_y=True)
print(data.head())
plt.show()

print(data.iloc[data["size"].argmax()])
