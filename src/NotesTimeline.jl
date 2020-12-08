module NotesTimeline

using LibGit2
using LibGit2: GitCommit, GitRepo, GitRevWalker, GitTree, GitTreeEntry, GitBlob, with, filename, peel, treewalk, entrytype, isbinary, content
using DataFrames
using Dates
using Statistics
using StatsPlots
using OrgMode
using Lazy

const EXCLUDE_FILES = Set(["inbox", "todo", "setup"])
const EXCLUDE_DIRS = Set(["calendars"])
const EXCLUDE_EXTS = Set([])

function excludeFiles(::Any, name, files=EXCLUDE_FILES)
    (base, _) = splitext(name)
    return base in files
end

function excludeSubdirs(path, ::Any, dirs=EXCLUDE_DIRS)
    return path in dirs
end

function excludeExtensions(::Any, name, exts=EXCLUDE_EXTS)
    (_, ext) = splitext(name)
    return ext in exts
end

const EXCLUDERS = Set([excludeFiles, excludeSubdirs, excludeExtensions])
exclude(path, name, excluders=EXCLUDERS) = any(e -> e(path, name), excluders)

function getFileContents(c::GitCommit)
    filecontents = @NamedTuple{file::String, content::String}[]
    treewalk(peel(c)) do path, te
        if entrytype(te) == GitBlob && !isbinary(GitBlob(te)) && !exclude(path, filename(te))
            push!(filecontents, (file=joinpath(path, filename(te)),
                                 content=content(GitBlob(te))))
        end
        return 0
    end
    return filecontents
end

function processCommit(id, repo)
    c = GitCommit(repo, id)
    contents = getFileContents(c)
    d = DataFrame(contents)
    d.commit = sprint(print, LibGit2.GitHash(c))
    return d
end

function date(id, repo)
    c = GitCommit(repo, id)
    sig = LibGit2.author(c)
    time = unix2datetime(sig.time + sig.time_offset*60)
end

function loadRepo(path)
    r = GitRepo(path)
    @info "Loading $path repo"
    files = with(GitRevWalker(r)) do walker
        LibGit2.map(processCommit, walker)
    end |> dfs -> vcat(dfs...)

    commits = with(GitRevWalker(r)) do walker
        LibGit2.map(walker) do id, repo
            return (commit=sprint(print, id), time=date(id, repo))
        end
    end |> DataFrame
    commits.repo = path

    @info ("Loaded '$path repo' with $(size(commits, 1)) commits "
           * "and $(size(files, 1)) total files")
    return files, commits
end

function countPlainTextWords(s)
    @debug "parsing contents" s
    sum_or_zero(x) = isempty(x) ? 0 : reduce(+, x)
    @>>(
        OrgMode.parse(s),
        OrgMode.map(identity, OrgMode.PlainText),
        map(pt -> pt.contents),
        map(split),
        map(length),
        sum_or_zero,
    )
end

function processFileContents(files)
    commits = combine(
        DataFrames.groupby(files, :commit),
        nrow => :files,
        :content => (x -> countPlainTextWords.(x) |> sum) => :words,
    )
    return commits
end

function main()
    repos = map(r -> "data/" * r, ["notes", "thesis", "avoiding-circles", "global-toa"])
    files, commits = loadRepo.(repos) |> x -> (vcat(first.(x)...), vcat(last.(x))...)
    cdata = processFileContents(files)

    df = innerjoin(commits, cdata, on=:commit)
    @df df plot(
        plot(:time, :words, ylabel="words"),
        plot(:time, :files, ylabel="files"),
        xlabel="time",
        legend=false,
        layout=grid(2, 1),
        link=:x,
    )
end

end
