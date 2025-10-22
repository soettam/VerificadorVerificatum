project_root = normpath(joinpath(@__DIR__, ".."))
readme_main = joinpath(project_root, "README.md")

content = read(readme_main, String)
lines = split(content, '\n')

println("Buscando líneas que empiezan con '# ':")
for (i, line) in enumerate(lines[1:min(500, length(lines))])
    if startswith(line, "# ") && !startswith(line, "## ")
        println("$i: $(repr(line))")
    end
end
