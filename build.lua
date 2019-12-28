-- running with texlua
-- prepare a CTAN upload
-- reshaping the file tree

local lfs = require "lfs"


local function filecopy (source, dest)

end

local function build(t)

end


local function run_doc()
end
local function run_test()
end

local function write_filelist()
end





local map = {
    {
        version = "v0.0.9.2",
        date = "2019-12-28",
        rundoc = {
            {"lualatex", "doc/manual/barracuda.tex", 2},
            {"lualatex", "doc/ga-graphic-asm/barracuda-ga-asm.tex", 2}
        },
        runtest = {
            {"texlua", "test/"},
            {"lualatex", "test/kkkk"}
        },
        ignore = {".aux", ".log", ".gz", ".out",},
        files = {-- source --> destination
            {"tex/lualatex/barracuda.sty", "barracuda.sty"},
            {"INSTALL.txt", "INSTALL.txt"},
            {"LICENSE.txt", "LICENSE.txt"},
            {"README.md", "README.md"},
            {"PLANNER.txt", "PLANNER.txt"},
            {"test", "test"},
            {"src", "src"},
            {"doc/manual/image", "doc/image"},
            {"doc/manual/barracuda.pdf", "doc/barracuda.pdf"},
            {"doc/manual/barracuda.tex", "doc/barracuda.tex"},
            {"doc/ga-graphic-asm/barracuda-ga-asm.pdf", "doc/barracuda-ga-asm.pdf"},
            {"doc/ga-graphic-asm/barracuda-ga-asm.tex", "doc/barracuda-ga-asm.tex"},
            {"doc/manual/barracuda-manual-tool.tex", "doc/barracuda-manual-tool.tex"},
        },
    },
}

