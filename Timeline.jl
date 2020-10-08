module NotesTimeline

using LibGit2: GitCommit, GitRepo, GitRevWalker, GitTree, GitTreeEntry, GitBlob, with, filename, peel, treewalk, entrytype, isbinary, content
using LibGit2
using DataFrames
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
    filecontents = String[]
    treewalk(peel(c)) do path, te
        if entrytype(te) == GitBlob && !isbinary(GitBlob(te)) && !exclude(path, filename(te))
            push!(filecontents, content(GitBlob(te)))
        end
        return 0
    end
    return filecontents
end

function processCommit(id, repo)
    # @info "Processing commit" id repo
    contents = getFileContents(GitCommit(repo, id))
    # @info "blobs" blobs
    return mapreduce(length, +, contents)
end

function processRepo(path)
    r = GitRepo(path)
    @info "Created repo" r
    commitdata = with(walker -> LibGit2.map(processCommit, walker), GitRevWalker(r))

end

end
