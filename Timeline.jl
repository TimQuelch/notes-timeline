module NotesTimeline

using LibGit2
using LibGit2: GitCommit, GitRepo, GitRevWalker, GitTree, GitTreeEntry, GitBlob, with, filename, peel, treewalk, entrytype, isbinary, content
using DataFrames
using Dates
using Statistics
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

date(ids::AbstractVector{String}, repo) = [date(id, repo) for id in ids]

function processRepo(path)
    r = GitRepo(path)
    @info "Loading $path repo"
    files = with(walker -> LibGit2.map(processCommit, walker), GitRevWalker(r)) |> dfs -> vcat(dfs...)
    transform!(
        files,
        :content => (x -> x .|> split .|> length) => :words,
    )

    commits = combine(
        DataFrames.groupby(files, :commit),
        nrow => :files,
        :words => sum,
    )
    transform!(
        commits,
        :commit => (ids -> date(ids, r)) => :time,
    )

    sort!(commits, [:time])
    @info ("Loaded $path repo with $(size(commits, 1)) commits and $(size(files, 1))"
           * " total files ($(commits[end, :files]) files in the most recent commit)")
    return commits, files
end

end
