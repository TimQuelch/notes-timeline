import git
import os
import pandas as pd
import matplotlib.pyplot as plt

repo = git.Repo(os.path.join(os.getcwd(), "notes"))

# for c in repo.iter_commits("master"):
#     print(c.authored_datetime)


cs = list(repo.iter_commits("master"))
c = cs[0]

print(c)
print(len(c.tree))
print(len([x for x in c.tree.traverse()]))
print(len([x for x in c.tree.traverse() if x.type == "blob"]))
print(len([x for x in c.tree.traverse() if x.type == "blob" and os.path.splitext(x.name)[-1] == ".org"]))
print([x.name for x in c.tree.traverse() if x.type == "blob" and not os.path.splitext(x.name)[-1] == ".org"])

data = pd.DataFrame(columns=["date", "size"])

for c in repo.iter_commits("master"):
    files = [x for x in c.tree.traverse() if x.type == "blob"]
    data = data.append({"date": c.authored_date, "size": len(files)}, ignore_index=True)

data["date"] = pd.to_datetime(data["date"], unit="s")
data = data.set_index("date")

data.plot()
print(data.head())
plt.show()
