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
    l1 = len(s)
    # Remove backslashes (weird escapes)
    s = re.sub(r"\\", "", s)
    l2 = len(s)

    # Remove blocks
    blockRe = r"#\+begin_?([^ \n]+).*?#\+end_?\1"
    s = re.sub(blockRe, "", s, flags=(re.I | re.S))
    l3 = len(s)

    # Remove keywords
    keywordRe = r"#\+(.*):(.*)\n"
    s = re.sub(keywordRe, "", s, flags=(re.I))
    l4 = len(s)

    print("len: {}, {}, {}, {}".format(l1, l2, l3, l4))
    return s


data = pd.DataFrame()


def extractData(commit):
    blobs = [
        x
        for x in c.tree.traverse()
        if x.type == "blob" and not any(f(x) for f in excluders)
    ]
    words = [len(processContents(b.data_stream.read().decode()).split())
             for b in blobs]
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
